defmodule Tripwire.Tracking.TestPresence do
  use GenServer

  def start_link(opts) do
    character = Keyword.fetch!(opts, :character)
    map = Keyword.fetch!(opts, :map)
    system = Keyword.fetch!(opts, :system)
    ship_name = Keyword.get(opts, :ship_name)
    ship_type_id = Keyword.get(opts, :ship_type_id)

    GenServer.start_link(
      __MODULE__,
      %{
        character: character,
        map: map,
        system: system,
        ship_name: ship_name,
        ship_type_id: ship_type_id
      },
      name: {:via, Registry, {Tripwire.TrackingRegistry, character.eve_id}}
    )
  end

  def ensure_started(character, map, system, opts \\ []) do
    ship_name = Keyword.get(opts, :ship_name)
    ship_type_id = Keyword.get(opts, :ship_type_id)

    case Registry.lookup(Tripwire.TrackingRegistry, character.eve_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:set_state, map, system, ship_name, ship_type_id})
        {:ok, pid}

      [] ->
        child =
          {__MODULE__,
           character: character,
           map: map,
           system: system,
           ship_name: ship_name,
           ship_type_id: ship_type_id}

        case DynamicSupervisor.start_child(Tripwire.Tracking.PollerSupervisor, child) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, {:already_started, pid}} ->
            GenServer.call(pid, {:set_state, map, system, ship_name, ship_type_id})
            {:ok, pid}

          error ->
            error
        end
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:state, _from, state) do
    %{character: character, map: map, system: system} = state

    {:reply,
     %{
       character: character,
       map: map,
       interval: nil,
       online: true,
       ship_name: state.ship_name,
       ship_type_id: state.ship_type_id,
       last_solar_system_id: system && system.solar_system_id,
       last_system_row: system
     }, state}
  end

  @impl true
  def handle_call({:set_state, map, system, ship_name, ship_type_id}, _from, state) do
    {:reply, :ok,
     %{state | map: map, system: system, ship_name: ship_name, ship_type_id: ship_type_id}}
  end
end
