defmodule Tripwire.Tracking.DemoPresence do
  @moduledoc """
  Stands in for a location poller in demo mode.

  The demo character has no SSO tokens, so a poller can never track it. This
  GenServer holds a static tracked state in the tracking registry that powers
  the topbar presence, the tracked badge and occupant badges with no ESI
  access.
  """

  use GenServer

  def start_link(opts) do
    character = Keyword.fetch!(opts, :character)
    map = Keyword.fetch!(opts, :map)
    system = Keyword.fetch!(opts, :system)

    GenServer.start_link(
      __MODULE__,
      %{character: character, map: map, system: system},
      name: {:via, Registry, {Tripwire.TrackingRegistry, character.eve_id}}
    )
  end

  def ensure_started(character, map, system) do
    case Registry.lookup(Tripwire.TrackingRegistry, character.eve_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:set_state, map, system})
        {:ok, pid}

      [] ->
        child = {__MODULE__, character: character, map: map, system: system}

        case DynamicSupervisor.start_child(Tripwire.Tracking.PollerSupervisor, child) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, {:already_started, pid}} ->
            GenServer.call(pid, {:set_state, map, system})
            {:ok, pid}

          error ->
            error
        end
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:state, _from, %{character: character, map: map, system: system}) do
    {:reply,
     %{
       character: character,
       map: map,
       interval: nil,
       online: true,
       last_solar_system_id: system && system.solar_system_id,
       last_system_row: system
     }, %{character: character, map: map, system: system}}
  end

  @impl true
  def handle_call({:set_state, map, system}, _from, state) do
    {:reply, :ok, %{state | map: map, system: system}}
  end
end
