defmodule Tripwire.Tracking.Poller do
  @moduledoc """
  Polls a character's location via ESI while they are tracked and applies
  changes to their personal map.
  """
  use GenServer

  require Logger

  alias Tripwire.{ESI, Mapping, Tracking}

  @default_interval 10_000

  def start_link(opts) do
    character = Keyword.fetch!(opts, :character)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Tripwire.TrackingRegistry, character.eve_id}
    )
  end

  @impl true
  def init(opts) do
    character = Keyword.fetch!(opts, :character)

    map =
      Keyword.get_lazy(opts, :map, fn ->
        {:ok, mask} = Tripwire.Masks.ensure_personal_mask(character)

        case Mapping.list_maps_for_mask(mask.id) do
          [] -> elem(Mapping.create_map(%{name: "Home", mask_id: mask.id}), 1)
          [map | _] -> map
        end
      end)

    interval = Keyword.get(opts, :interval, @default_interval)
    schedule_tick(interval)

    {:ok,
     %{
       character: character,
       map: map,
       interval: interval,
       last_solar_system_id: nil,
       last_system_row: nil
     }}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state =
      state.character
      |> fetch_current_system()
      |> apply_change(state)

    schedule_tick(state.interval)

    {:noreply, new_state}
  end

  defp fetch_current_system(character) do
    with {:ok, token} <- ESI.valid_access_token(character),
         {:ok, %{"solar_system_id" => solar_system_id}} <-
           ESI.get_character_location(character.eve_id, token) do
      {:ok, solar_system_id}
    else
      {:error, :no_refresh_token} ->
        :untracked

      {:error, reason} ->
        Logger.debug("ESI location poll failed for #{character.name}: #{inspect(reason)}")
        :error
    end
  end

  defp apply_change(:untracked, state), do: state
  defp apply_change(:error, state), do: state

  defp apply_change({:ok, solar_system_id}, state)
       when solar_system_id == state.last_solar_system_id do
    state
  end

  defp apply_change({:ok, solar_system_id}, state) do
    case Tracking.apply_location_change(
           state.map,
           state.character.name,
           state.last_system_row,
           solar_system_id
         ) do
      {:ok, %{system: system}} ->
        %{state | last_solar_system_id: solar_system_id, last_system_row: system}

      error ->
        Logger.warning("Failed to apply location change: #{inspect(error)}")
        state
    end
  end

  defp schedule_tick(interval), do: Process.send_after(self(), :tick, interval)
end
