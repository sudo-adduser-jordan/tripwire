defmodule Ztripwire.SyncServer do
  use GenServer

  require Logger

  alias Ztripwire.{Accounts, ESI, Mapping, Masks, Repo}

  @corp_sync_interval 6 * 60 * 60 * 1000

  @activity_interval 60 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    corp_sync_interval = Keyword.get(opts, :corp_sync_interval, @corp_sync_interval)
    activity_interval = Keyword.get(opts, :activity_interval, @activity_interval)

    if Application.get_env(:ztripwire, __MODULE__, []) |> Keyword.get(:prune_on_start, true) do
      prune_orphan_masks(" on startup")
    end

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
      _ = sync_character(character, source: :poller)
    end

    prune_orphan_masks()
  end

  def sync_character(%Ztripwire.Accounts.Character{} = character, opts \\ []) do
    esi_opts = Keyword.merge([refresh: true], opts)

    case ESI.get_character(character.eve_id, esi_opts) do
      {:ok, %{"corporation_id" => corporation_id} = body} ->
        corporation_name =
          case ESI.get_corporation(corporation_id, esi_opts) do
            {:ok, %{"name" => name}} -> name
            _ -> character.corporation_name
          end

        character
        |> Ecto.Changeset.change(%{
          corporation_id: corporation_id,
          corporation_name: corporation_name,
          alliance_id: body["alliance_id"]
        })
        |> Repo.update()

      {:error, reason} ->
        Logger.debug("Corp sync skipped for #{character.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp prune_orphan_masks(context \\ "") do
    case Masks.prune_orphan_masks() do
      [] ->
        :ok

      masks ->
        Logger.info(
          "Pruned #{length(masks)} orphaned masks#{context}: #{Enum.map_join(masks, ", ", & &1.name)}"
        )
    end
  end

  defp run_activity_sync do
    case Mapping.prune_expired_signatures() do
      {:ok, 0} -> :ok
      {:ok, count} -> Logger.info("Pruned #{count} expired signatures")
    end

    case Mapping.prune_expired_flares() do
      {:ok, 0} -> :ok
      {:ok, count} -> Logger.info("Pruned #{count} expired flares")
    end

    case ESI.get_system_jumps() do
      {:ok, jumps} -> apply_system_activity(jumps, :jumps)
      {:error, reason} -> Logger.debug("System jumps sync skipped: #{inspect(reason)}")
    end

    case ESI.get_system_kills() do
      {:ok, kills} -> apply_system_activity(kills, :kills)
      {:error, reason} -> Logger.debug("System kills sync skipped: #{inspect(reason)}")
    end

    :ok
  end

  defp apply_system_activity(rows, field) when is_list(rows) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for row <- rows do
      esi_id = row["solar_system_id"] || row["system_id"]
      value = row["ship_jumps"] || row["ship_kills"] || row["kills"] || 0

      if esi_id do
        case Repo.get_by(Ztripwire.Mapping.MapSystem, solar_system_id: esi_id) do
          nil ->
            :ok

          system ->
            attrs = %{field => value, recorded_at: now}

            case Mapping.get_system_stat(system.id) do
              nil ->
                Mapping.upsert_system_stat(system, Map.put(attrs, :visits, 0))

              stat ->
                Mapping.upsert_system_stat(system, Map.put(attrs, :visits, stat.visits || 0))
            end
        end
      end
    end
  end

  defp apply_system_activity(_, _), do: :ok

  defp schedule(job, interval), do: Process.send_after(self(), {:run, job}, interval)
end
