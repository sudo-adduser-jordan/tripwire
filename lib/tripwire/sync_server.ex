defmodule Tripwire.SyncServer do
  @moduledoc """
  Periodic background jobs replacing the original Tripwire PHP crons:

  - every ~3 minutes: refresh corporation/alliance ids for known characters
  - hourly: ping zKillboard for system activity data (stored in a later phase)
  """
  use GenServer

  require Logger

  alias Tripwire.{Accounts, ESI, Repo}

  @corp_sync_interval 3 * 60 * 1000
  @activity_interval 60 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    corp_sync_interval = Keyword.get(opts, :corp_sync_interval, @corp_sync_interval)
    activity_interval = Keyword.get(opts, :activity_interval, @activity_interval)

    schedule(:corp_sync, corp_sync_interval)
    schedule(:activity, activity_interval)

    {:ok, %{corp_sync_interval: corp_sync_interval, activity_interval: activity_interval}}
  end

  @impl true
  def handle_info({:run, :corp_sync}, state) do
    run_corp_sync()
    schedule(:corp_sync, state.corp_sync_interval)
    {:noreply, state}
  end

  def handle_info({:run, :activity}, state) do
    run_activity_sync()
    schedule(:activity, state.activity_interval)
    {:noreply, state}
  end

  defp run_corp_sync do
    for character <- Accounts.list_characters() do
      case ESI.get_character(character.eve_id) do
        {:ok, %{"corporation_id" => corporation_id} = body} ->
          character
          |> Ecto.Changeset.change(%{
            corporation_id: corporation_id,
            alliance_id: body["alliance_id"]
          })
          |> Repo.update()

        {:error, reason} ->
          Logger.debug("Corp sync skipped for #{character.name}: #{inspect(reason)}")
      end
    end
  end

  defp run_activity_sync do
    Logger.debug("zKillboard activity sync tick")
    :ok
  end

  defp schedule(job, interval), do: Process.send_after(self(), {:run, job}, interval)
end
