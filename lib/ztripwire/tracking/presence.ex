defmodule Ztripwire.Tracking.Presence do
  use GenServer

  @table __MODULE__
  @sweep_interval 60_000
  @stale_after 900_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(eve_id, presence) when is_integer(eve_id) and is_map(presence) do
    if table?() do
      entry = Map.put(presence, :updated_at, now_ms())
      :ets.insert(@table, {{:presence, eve_id}, entry})
    end

    :ok
  end

  def get(eve_id) when is_integer(eve_id) do
    if table?() do
      case :ets.lookup(@table, {:presence, eve_id}) do
        [{_key, presence}] -> presence
        [] -> nil
      end
    end
  end

  def delete(eve_id) when is_integer(eve_id) do
    if table?() do
      :ets.delete(@table, {:presence, eve_id})
      :ets.delete(@table, {:viewers, eve_id})
    end

    :ok
  end

  def all do
    if table?() do
      :ets.select(@table, [{{{:presence, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    else
      []
    end
  end

  def add_viewer(eve_id) when is_integer(eve_id) do
    if table?() do
      :ets.update_counter(@table, {:viewers, eve_id}, 1, {{:viewers, eve_id}, 0})
    end

    :ok
  end

  def remove_viewer(eve_id) when is_integer(eve_id) do
    if table?() do
      :ets.update_counter(@table, {:viewers, eve_id}, -1, {{:viewers, eve_id}, 0})
    end

    :ok
  end

  def viewers(eve_id) when is_integer(eve_id) do
    if table?() do
      case :ets.lookup(@table, {:viewers, eve_id}) do
        [{_key, count}] -> max(count, 0)
        [] -> 0
      end
    else
      0
    end
  end

  def clear do
    if table?(), do: :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep(now_ms())
    schedule_sweep()
    {:noreply, state}
  end

  defp sweep(now) do
    :ets.foldl(
      fn
        {{:presence, eve_id}, presence}, acc ->
          if presence.updated_at <= now - @stale_after do
            :ets.delete(@table, {:presence, eve_id})
            :ets.delete(@table, {:viewers, eve_id})
          end

          acc

        _, acc ->
          acc
      end,
      :ok,
      @table
    )
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)

  defp table?, do: :ets.whereis(@table) != :undefined

  defp now_ms, do: System.system_time(:millisecond)
end
