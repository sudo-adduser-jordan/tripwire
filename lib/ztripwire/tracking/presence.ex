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

  def add_viewer(eve_id, pid \\ self(), target \\ nil)
      when is_integer(eve_id) and is_pid(pid),
      do: call({:add_viewer, eve_id, pid, target})

  def remove_viewer(eve_id, pid \\ self()) when is_integer(eve_id) and is_pid(pid),
    do: call({:remove_viewer, eve_id, pid})

  def set_target(eve_id, pid, target) when is_integer(eve_id) and is_pid(pid),
    do: call({:set_target, eve_id, pid, target})

  def targets(eve_id) when is_integer(eve_id) do
    if table?() do
      case :ets.lookup(@table, {:targets, eve_id}) do
        [{_key, targets}] -> targets |> Map.values() |> Enum.uniq()
        [] -> []
      end
    else
      []
    end
  end

  def sync, do: GenServer.call(__MODULE__, :sync)

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
    {:ok, %{monitors: %{}}}
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
      :ets.delete(@table, {:targets, eve_id})
    end

    {:reply, :ok, state}
  end

  def handle_call({:add_viewer, eve_id, pid, target}, _from, state) do
    if table?() do
      :ets.update_counter(@table, {:viewers, eve_id}, 1, {{:viewers, eve_id}, 0})

      watched =
        case :ets.lookup(@table, {:viewer_pids, pid}) do
          [{_key, set}] -> set
          [] -> MapSet.new()
        end

      :ets.insert(@table, {{:viewer_pids, pid}, MapSet.put(watched, eve_id)})
      put_target(eve_id, pid, target)
    end

    monitors =
      if Map.has_key?(state.monitors, pid) do
        state.monitors
      else
        Map.put(state.monitors, pid, Process.monitor(pid))
      end

    {:reply, :ok, %{state | monitors: monitors}}
  end

  def handle_call({:set_target, eve_id, pid, target}, _from, state) do
    put_target(eve_id, pid, target)
    {:reply, :ok, state}
  end

  def handle_call({:remove_viewer, eve_id, pid}, _from, state) do
    watched =
      if table?() do
        watched =
          case :ets.lookup(@table, {:viewer_pids, pid}) do
            [{_key, set}] -> set
            [] -> MapSet.new()
          end

        watched = MapSet.delete(watched, eve_id)

        if MapSet.size(watched) == 0 do
          :ets.delete(@table, {:viewer_pids, pid})
        else
          :ets.insert(@table, {{:viewer_pids, pid}, watched})
        end

        remove_target(eve_id, pid)
        decrement_viewer(eve_id)
        watched
      else
        MapSet.new()
      end

    monitors =
      case Map.fetch(state.monitors, pid) do
        {:ok, ref} ->
          if MapSet.size(watched) == 0 do
            Process.demonitor(ref, [:flush])
            Map.delete(state.monitors, pid)
          else
            state.monitors
          end

        :error ->
          state.monitors
      end

    {:reply, :ok, %{state | monitors: monitors}}
  end

  def handle_call(:sync, _from, state), do: {:reply, :ok, state}

  def handle_call(:clear, _from, state) do
    if table?(), do: :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    if table?() do
      case :ets.lookup(@table, {:viewer_pids, pid}) do
        [{_key, watched}] ->
          Enum.each(watched, fn eve_id ->
            remove_target(eve_id, pid)
            decrement_viewer(eve_id)
          end)

          :ets.delete(@table, {:viewer_pids, pid})

        [] ->
          :ok
      end
    end

    {:noreply, %{state | monitors: Map.delete(state.monitors, pid)}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep(now_ms())
    schedule_sweep()
    {:noreply, state}
  end

  defp put_target(_eve_id, _pid, nil), do: :ok

  defp put_target(eve_id, pid, target) when is_map(target) do
    targets =
      case :ets.lookup(@table, {:targets, eve_id}) do
        [{_key, targets}] -> targets
        [] -> %{}
      end

    :ets.insert(@table, {{:targets, eve_id}, Map.put(targets, pid, target)})
  end

  defp put_target(_eve_id, _pid, _target), do: :ok

  defp remove_target(eve_id, pid) do
    case :ets.lookup(@table, {:targets, eve_id}) do
      [{_key, targets}] ->
        targets = Map.delete(targets, pid)

        if map_size(targets) == 0 do
          :ets.delete(@table, {:targets, eve_id})
        else
          :ets.insert(@table, {{:targets, eve_id}, targets})
        end

      [] ->
        :ok
    end
  end

  defp decrement_viewer(eve_id) do
    case :ets.lookup(@table, {:viewers, eve_id}) do
      [{_key, count}] when count > 0 ->
        :ets.update_counter(@table, {:viewers, eve_id}, -1, {{:viewers, eve_id}, 0})

      _ ->
        :ok
    end
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
