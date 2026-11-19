defmodule Tripwire.Tracking do
  import Ecto.Query, only: [from: 2]

  alias Tripwire.{ESI, Mapping}
  alias Tripwire.Accounts
  alias Tripwire.Mapping.MapSystem
  alias Tripwire.Repo
  alias Tripwire.Signatures, as: SigParser
  alias Tripwire.Tracking.Poller
  alias Tripwire.Wormholes
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

  def tracking?(%{eve_id: eve_id}) when is_integer(eve_id) do
    case Registry.lookup(Tripwire.TrackingRegistry, eve_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  def tracking?(_), do: false

  def apply_location_change(map, character_name, prev_system, solar_system_id, opts \\ []) do
    name_fetcher = Keyword.get(opts, :name_fetcher, &fetch_system_info/1)
    route_fn = Keyword.get(opts, :route_fn, fn o, d -> ESI.get_route(o, d) end)
    position = next_position(map, prev_system)

    with {:ok, system} <-
           ensure_system(map, solar_system_id, name_fetcher, position, prev_system) do
      connection_result =
        if is_struct(prev_system, MapSystem) and prev_system.id != system.id do
          jumps = jump_count(prev_system, system, route_fn)
          attrs = jump_connection_attrs(map.id, prev_system, system, jumps)

          case Mapping.upsert_connection(map.id, prev_system.id, system.id, attrs) do
            {:ok, conn, _new?} -> conn
            _other -> nil
          end
        else
          nil
        end

      _ = Mapping.record_visit(system)

      if is_binary(character_name) and character_name != "" do
        case Accounts.get_character_by_name(character_name) do
          %{} = visitor -> Accounts.bump_stats(visitor.id, systems_visited: 1)
          nil -> :ok
        end
      end

      broadcast_system_change(map.id, character_name, system)
      broadcast_map_update(map.id)

      {:ok, %{system: system, connection: connection_result}}
    end
  end

  def wormholes_for_jump(from_system, to_system, signatures) do
    to_class = Tripwire.Systems.display_class(to_system)
    eligible = eligible_jump_codes(from_system, to_system)

    Enum.filter(signatures, fn signature ->
      case SigParser.wormhole_code(signature.type_name) do
        nil -> blank_wormhole?(signature)
        code -> to_class in (Wormholes.leads_to(code) || []) or code in eligible
      end
    end)
  end

  defp jump_connection_attrs(map_id, from_system, to_system, jumps) do
    attrs = %{jumps: jumps}

    unlabeled? =
      case Mapping.connection_between(map_id, from_system.id, to_system.id) do
        nil -> true
        conn -> conn.hole_type in [nil, ""]
      end

    coded =
      if unlabeled? do
        from_system.id
        |> Mapping.list_signatures()
        |> then(&wormholes_for_jump(from_system, to_system, &1))
        |> Enum.map(&SigParser.wormhole_code(&1.type_name))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    case coded do
      [code] -> Map.put(attrs, :hole_type, code)
      _ -> attrs
    end
  end

  defp eligible_jump_codes(from_system, to_system) do
    from = Tripwire.Systems.display_class(from_system)
    to = Tripwire.Systems.display_class(to_system)
    Wormholes.eligible_types(from, to).from
  end

  defp blank_wormhole?(%{site_type: "wormhole", type_name: name}),
    do: name in [nil, ""] or SigParser.wormhole_code(name) == nil

  defp blank_wormhole?(_), do: false

  def broadcast_map_update(map_id) do
    PubSub.broadcast(Tripwire.PubSub, map_topic(map_id), {:map_updated, map_id})
  end

  def list_occupants(map_id) do
    Registry.select(Tripwire.TrackingRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.flat_map(fn {_eve_id, pid} ->
      case GenServer.call(pid, :state) do
        %{character: character, map: %{id: ^map_id}, last_system_row: system} = state
        when not is_nil(system) ->
          case Accounts.get_character_by_eve_id(character.eve_id) do
            %{character_on_chain: true} = character ->
              [
                %{
                  character_name: character.name,
                  eve_id: character.eve_id,
                  system_id: system.id,
                  system_name: system.name,
                  solar_system_id: system.solar_system_id,
                  ship_name: occupant_ship_name(character, state)
                }
              ]

            _ ->
              []
          end

        _ ->
          []
      end
    end)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp occupant_ship_name(%{ship_on_chain: false}, _state), do: nil
  defp occupant_ship_name(_character, state), do: Map.get(state, :ship_name)

  def list_tracked_characters do
    Registry.select(Tripwire.TrackingRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.flat_map(fn {_eve_id, pid} ->
      case GenServer.call(pid, :state) do
        %{character: %Tripwire.Accounts.Character{} = character, online: online} ->
          [%{eve_id: character.eve_id, name: character.name, online: online}]

        _ ->
          []
      end
    end)
    |> Enum.sort_by(& &1.name)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp broadcast_system_change(map_id, character_name, system) do
    PubSub.broadcast(
      Tripwire.PubSub,
      map_topic(map_id),
      {:system_changed, %{character: character_name, system: system}}
    )
  end

  defp ensure_system(map, solar_system_id, name_fetcher, position, prev_system) do
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
        {name, security} =
          case name_fetcher.(solar_system_id) do
            {fetched_name, fetched_security} -> {fetched_name, fetched_security}
            fetched_name when is_binary(fetched_name) -> {fetched_name, nil}
          end

        attrs = %{solar_system_id: solar_system_id, name: name, security: security}

        case unknown_placeholder(prev_system) do
          %MapSystem{} = placeholder ->
            Mapping.convert_unknown_system(placeholder, attrs)

          nil ->
            Mapping.add_system_to_map(
              map,
              Elixir.Map.merge(attrs, %{x: position.x, y: position.y})
            )
        end
    end
  end

  defp unknown_placeholder(%MapSystem{id: id, map_id: map_id}) do
    map_id
    |> then(&Mapping.list_connections/1)
    |> Enum.filter(&(&1.from_system_id == id or &1.to_system_id == id))
    |> Enum.map(fn conn ->
      if conn.from_system_id == id, do: conn.to_system, else: conn.from_system
    end)
    |> Enum.filter(&(&1 && &1.unknown))
    |> case do
      [placeholder] -> placeholder
      _ -> nil
    end
  end

  defp unknown_placeholder(_prev_system), do: nil

  @map_center %{x: 460.0, y: 300.0}
  @placement_radius 170.0

  defp next_position(map, prev_system) do
    count = Repo.aggregate(from(s in MapSystem, where: s.map_id == ^map.id), :count)

    case prev_system do
      %MapSystem{x: x, y: y} ->
        angle = :math.pi() * (3 - :math.sqrt(5)) * count

        %{
          x: x * 1.0 + @placement_radius * :math.cos(angle),
          y: y * 1.0 + @placement_radius * :math.sin(angle)
        }

      _ ->
        @map_center
    end
  end

  defp fetch_system_info(solar_system_id) do
    case ESI.get_system(solar_system_id) do
      {:ok, %{"name" => name} = body} -> {name, body["security_status"]}
      _ -> {"System ##{solar_system_id}", nil}
    end
  end

  defp jump_count(%MapSystem{solar_system_id: from}, %MapSystem{solar_system_id: to}, route_fn)
       when is_integer(from) and is_integer(to) do
    cond do
      from == to ->
        0

      from < 31_000_000 and to < 31_000_000 ->
        case route_fn.(from, to) do
          {:ok, route} when is_list(route) and length(route) > 0 -> max(length(route) - 1, 1)
          _ -> 1
        end

      true ->
        1
    end
  end

  defp jump_count(_, _, _), do: 1
end
