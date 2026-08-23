defmodule Tripwire.ESI.TokenCache do
  @moduledoc """
  In-memory cache of ESI access tokens, keyed by character EVE id.
  """
  use GenServer

  @ttl_sweep 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(eve_id) do
    case :ets.lookup(__MODULE__, eve_id) do
      [{^eve_id, value}] -> value
      [] -> nil
    end
  end

  def put(eve_id, value) do
    :ets.insert(__MODULE__, {eve_id, value})
    :ok
  end

  def delete(eve_id) do
    :ets.delete(__MODULE__, eve_id)
    :ok
  end

  @impl true
  def init(_opts) do
    table = :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    schedule_sweep()
    {:ok, table}
  end

  @impl true
  def handle_info(:sweep, table) do
    now = DateTime.utc_now()

    :ets.foldl(
      fn {eve_id, %{expires_at: expires_at}}, acc ->
        if DateTime.compare(now, expires_at) == :gt do
          :ets.delete(table, eve_id)
        end

        acc
      end,
      :ok,
      table
    )

    schedule_sweep()
    {:noreply, table}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @ttl_sweep)
end
