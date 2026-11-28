defmodule Ztripwire.Tracking.Presence do
  use GenServer

  @table __MODULE__
  @sweep_interval 60_000
  @stale_after 900_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(eve_id, presence) when is_integer(eve_id) and is_map(presence) do
    call({:put, eve_id, presence})
  end

  def get(eve_id) when is_integer(eve_id) do
    if table?() do
      case :ets.lookup(@table, {:presence, eve_id}) do
        [{_key, presence}] -> presence
        [] -> nil
      end
    end
  end

  def delete(eve_id) when is_integer(eve_id), do: call({:delete, eve_id})

  def all do
    if table?() do
      :ets.select(@table, [{{{:presence, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    else
      []
    end
  end

  def add_viewer(eve_id) when is_integer(eve_id), do: call({:viewer, eve_id, 1})

  def remove_viewer(eve_id) when is_integer(eve_id), do: call({:viewer, eve_id, -1})

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
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, :clear), else: :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :protected,
      :set,
      read_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, eve_id, presence}, _from, state) do
    if table?() do
      :ets.insert(@table, {{:presence, eve_id}, Map.put(presence, :updated_at, now_ms())})
    end

    {:reply, :ok, state}
  end

  def handle_call({:delete, eve_id}, _from, state) do
    if table?() do
      :ets.delete(@table, {:presence, eve_id})
      :ets.delete(@table, {:viewers, eve_id})
    end

    {:reply, :ok, state}
  end

  def handle_call({:viewer, eve_id, delta}, _from, state) do
    if table?() do
      :ets.update_counter(@table, {:viewers, eve_id}, delta, {{:viewers, eve_id}, 0})
    end

    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    if table?(), do: :ets.delete_all_objects(@table)
    {:reply, :ok, state}
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

  defp call(message) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, message), else: :ok
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)

  defp table?, do: :ets.whereis(@table) != :undefined

  defp now_ms, do: System.system_time(:millisecond)
end
