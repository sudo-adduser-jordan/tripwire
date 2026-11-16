defmodule Tripwire.Tracking do
  @moduledoc """
  Tracks authenticated characters through New Eden and maintains the map graph.
  """

  import Ecto.Query, only: [from: 2]

  alias Tripwire.{ESI, Mapping}
  alias Tripwire.Mapping.MapSystem
  alias Tripwire.Repo
  alias Tripwire.Tracking.Poller
  alias Phoenix.PubSub

  @topic_prefix "map"

  def map_topic(map_id), do: "#{@topic_prefix}:#{map_id}"

  def ensure_poller(character, opts \\ []) do
    case Registry.lookup(Tripwire.TrackingRegistry, character.eve_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        child = {Poller, Keyword.put(opts, :character, character)}

        case DynamicSupervisor.start_child(Tripwire.Tracking.PollerSupervisor, child) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end
    end
  end

  def stop_poller(%{eve_id: eve_id}) do
    case Registry.lookup(Tripwire.TrackingRegistry, eve_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Tripwire.Tracking.PollerSupervisor, pid)
      [] -> :ok
    end
  end

  @doc """
  Records a location change onto the map: adds the system when missing,
  links it to the previous system and broadcasts the map update.

  The previous system row is passed in by the poller so this stays a pure
  data operation that can be exercised without ESI access.
  """
  def apply_location_change(map, character_name, prev_system, solar_system_id, opts \\ []) do
    name_fetcher = Keyword.get(opts, :name_fetcher, &fetch_system_name/1)
    position = next_position(map, prev_system)

    with {:ok, system} <- ensure_system(map, solar_system_id, name_fetcher, position) do
      connection_result =
        if is_struct(prev_system, MapSystem) and prev_system.id != system.id do
          case Mapping.upsert_connection(map.id, prev_system.id, system.id) do
            {:ok, conn, _new?} -> conn
            _other -> nil
          end
        else
          nil
        end

      broadcast_system_change(map.id, character_name, system)
      broadcast_map_update(map.id)

      {:ok, %{system: system, connection: connection_result}}
    end
  end

  def broadcast_map_update(map_id) do
    PubSub.broadcast(Tripwire.PubSub, map_topic(map_id), {:map_updated, map_id})
  end

  defp broadcast_system_change(map_id, character_name, system) do
    PubSub.broadcast(
      Tripwire.PubSub,
      map_topic(map_id),
      {:system_changed, %{character: character_name, system: system}}
    )
  end

  defp ensure_system(map, solar_system_id, name_fetcher, position) do
    existing =
      Repo.one(
        from(s in MapSystem,
          where: s.map_id == ^map.id and s.solar_system_id == ^solar_system_id
        )
      )

    case existing do
      %MapSystem{} = system ->
        {:ok, system}

      nil ->
        attrs = %{
          solar_system_id: solar_system_id,
          name: name_fetcher.(solar_system_id),
          x: position.x,
          y: position.y
        }

        Mapping.add_system_to_map(map, attrs)
    end
  end

  # ViewBox is 1000x700 and nodes are 80x50, so origins clamp to 920x650.
  @map_max_x 920.0
  @map_max_y 650.0
  @map_center %{x: 460.0, y: 300.0}
  @placement_radius 170.0

  # New systems spawn on a golden-angle spiral around the previous system so
  # tracked jumps lay out a readable chain instead of piling at the origin.
  # Positions are only assigned on creation; user drags are never touched.
  defp next_position(map, prev_system) do
    count = Repo.aggregate(from(s in MapSystem, where: s.map_id == ^map.id), :count)

    case prev_system do
      %MapSystem{x: x, y: y} ->
        angle = :math.pi() * (3 - :math.sqrt(5)) * count

        %{
          x: clamp(x * 1.0 + @placement_radius * :math.cos(angle), @map_max_x),
          y: clamp(y * 1.0 + @placement_radius * :math.sin(angle), @map_max_y)
        }

      _ ->
        @map_center
    end
  end

  defp clamp(value, max), do: value |> max(0.0) |> min(max)

  defp fetch_system_name(solar_system_id) do
    case ESI.get_system(solar_system_id) do
      {:ok, %{"name" => name}} -> name
      _ -> "System ##{solar_system_id}"
    end
  end
end
