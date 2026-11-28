defmodule Ztripwire.Tracking do
  import Ecto.Query, only: [from: 2]

  alias Ztripwire.{ESI, Mapping}
  alias Ztripwire.Accounts
  alias Ztripwire.Mapping.MapSystem
  alias Ztripwire.Repo
  alias Ztripwire.Signatures, as: SigParser
  alias Ztripwire.Tracking.{Poller, Presence}
  alias Ztripwire.Wormholes
  alias Phoenix.PubSub

  @topic_prefix "mask"
  @no_map_systems [30_000_142, 30_002_187]
  @pod_type_ids [670, 33_328]

  def mask_topic(mask_id), do: "#{@topic_prefix}:#{mask_id}"

  def ensure_poller(character, opts \\ []) do
    if Application.get_env(:ztripwire, :pollers_enabled, true) do
      do_ensure_poller(character, opts)
    else
      {:ok, :disabled}
    end
  end

  defp do_ensure_poller(character, opts) do
    case Registry.lookup(Ztripwire.TrackingRegistry, character.eve_id) do
      [{pid, _}] ->
        _ = safe_update_character(pid, character)
        {:ok, pid}

      [] ->
        child = {Poller, Keyword.put(opts, :character, character)}

        case DynamicSupervisor.start_child(Ztripwire.Tracking.PollerSupervisor, child) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end
    end
  end

  defp safe_update_character(pid, character) do
    GenServer.call(pid, {:update_character, character}, 5_000)
  catch
    :exit, _ -> :ok
  end

  def presence(eve_id), do: Presence.get(eve_id)

  def presences(characters) when is_list(characters) do
    Map.new(characters, fn character -> {character.eve_id, presence(character.eve_id) || %{}} end)
  end

  def add_viewer(%{eve_id: eve_id}, pid \\ self(), target \\ nil) do
    Presence.add_viewer(eve_id, pid, target)
  end

  def remove_viewer(%{eve_id: eve_id}, pid \\ self()), do: Presence.remove_viewer(eve_id, pid)

  def set_viewer_target(%{eve_id: eve_id}, target, pid \\ self()) do
    Presence.set_target(eve_id, pid, target)
  end

  def targets(eve_id) when is_integer(eve_id), do: Presence.targets(eve_id)

  def stop_poller(%{eve_id: eve_id}) do
    case Registry.lookup(Ztripwire.TrackingRegistry, eve_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Ztripwire.Tracking.PollerSupervisor, pid)
      [] -> :ok
    end
  end

  def stop_all_pollers do
    Registry.select(Ztripwire.TrackingRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.each(fn {_eve_id, pid} ->
      DynamicSupervisor.terminate_child(Ztripwire.Tracking.PollerSupervisor, pid)
    end)

    :ok
  end

  def tracking?(%{eve_id: eve_id}) when is_integer(eve_id) do
    case Registry.lookup(Ztripwire.TrackingRegistry, eve_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  def tracking?(_), do: false

  def apply_location_change(map, character_name, prev_system, solar_system_id, opts \\ []) do
    name_fetcher = Keyword.get(opts, :name_fetcher, &fetch_system_info/1)
    route_fn = Keyword.get(opts, :route_fn, fn o, d -> ESI.get_route(o, d) end)
    record_stats? = Keyword.get(opts, :record_stats, true)
    position = next_position(map, prev_system)

    with {:ok, system} <-
           ensure_system(map, solar_system_id, name_fetcher, position, prev_system) do
      connection_result =
        if is_struct(prev_system, MapSystem) and prev_system.id != system.id do
          jumps = jump_count(prev_system, system, route_fn)
          attrs = jump_connection_attrs(map.mask_id, prev_system, system, jumps)

          case Mapping.upsert_connection(map.mask_id, prev_system.id, system.id, attrs) do
            {:ok, conn, _new?} -> conn
            _other -> nil
          end
        else
          nil
        end

      if record_stats? do
        _ = Mapping.record_visit(system)

        if is_binary(character_name) and character_name != "" do
          case Accounts.get_character_by_name(character_name) do
            %{} = visitor -> Accounts.bump_stats(visitor.id, systems_visited: 1)
            nil -> :ok
          end
        end
      end

      broadcast_system_change(map.mask_id, character_name, system)
      broadcast_map_update(map.mask_id)

      {:ok, %{system: system, connection: connection_result}}
    end
  end

  def automap_allowed?(map, from, to_solar, opts \\ [])

  def automap_allowed?(map, %MapSystem{} = from, to_solar, opts)
      when is_integer(to_solar) do
    to_row = Mapping.get_system_by_solar(map.mask_id, to_solar)
    target_in_chain? = to_row != nil and is_nil(to_row.hidden_at)

    cond do
      not automapper?(Keyword.get(opts, :character)) ->
        false

      Keyword.get(opts, :docked, false) ->
        false

      Keyword.get(opts, :ship_type_id) in @pod_type_ids ->
        false

      from.solar_system_id == to_solar ->
        false

      from.solar_system_id in @no_map_systems or to_solar in @no_map_systems ->
        false

      Ztripwire.Systems.special_region?(from.solar_system_id) or
          Ztripwire.Systems.special_region?(to_solar) ->
        false

      kspace?(from.solar_system_id) and kspace?(to_solar) ->
        false

      target_in_chain? ->
        false

      to_row != nil and
          Mapping.connection_between(map.mask_id, from.id, to_row.id) != nil ->
        false

      true ->
        true
    end
  end

  def automap_allowed?(_map, _from, _to_solar, _opts), do: false

  def automapper?(nil), do: true
  def automapper?(%{automapper: false}), do: false
  def automapper?(_character), do: true

  def system_name(solar_system_id), do: Ztripwire.Systems.name_for(solar_system_id)

  defp kspace?(id) when is_integer(id), do: id < 31_000_000
  defp kspace?(_), do: false

  def wormholes_for_jump(from_system, to_system, signatures) do
    to_class = Ztripwire.Systems.display_class(to_system)
    eligible = eligible_jump_codes(from_system, to_system)

    Enum.filter(signatures, fn signature ->
      case SigParser.wormhole_code(signature.type_name) do
        nil -> blank_wormhole?(signature)
        code -> to_class in (Wormholes.leads_to(code) || []) or code in eligible
      end
    end)
  end

  defp jump_connection_attrs(mask_id, from_system, to_system, jumps) do
    attrs = %{jumps: jumps}

    unlabeled? =
      case Mapping.connection_between(mask_id, from_system.id, to_system.id) do
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
    Wormholes.eligible_types(from_system, to_system).from
  end

  defp blank_wormhole?(%{site_type: "wormhole", type_name: name}),
    do: name in [nil, ""] or SigParser.wormhole_code(name) == nil

  defp blank_wormhole?(_), do: false

  def broadcast_map_update(mask_id) do
    PubSub.broadcast(Ztripwire.PubSub, mask_topic(mask_id), {:map_updated, mask_id})
  end

  def list_occupants(mask_id) do
    systems =
      Repo.all(
        from(s in MapSystem,
          where: s.mask_id == ^mask_id,
          select: {s.solar_system_id, s.id, s.name}
        )
      )
      |> Map.new(fn {solar_system_id, id, name} -> {solar_system_id, {id, name}} end)

    characters =
      Accounts.list_characters()
      |> Map.new(fn character -> {character.eve_id, character} end)

    Presence.all()
    |> Enum.flat_map(fn {eve_id, presence} ->
      with %{character_on_chain: true} = character <- Map.get(characters, eve_id),
           solar when is_integer(solar) <- Map.get(presence, :solar_system_id),
           {system_id, system_name} <- Map.get(systems, solar) do
        [
          %{
            character_name: character.name,
            eve_id: character.eve_id,
            corporation_id: character.corporation_id,
            alliance_id: character.alliance_id,
            solar_system_id: solar,
            system_id: system_id,
            system_name: system_name,
            ship_name: occupant_ship_name(character, presence),
            ship_type_id: occupant_ship_type_id(character, presence)
          }
        ]
      else
        _ -> []
      end
    end)
  end

  defp occupant_ship_name(%{ship_on_chain: false}, _presence), do: nil
  defp occupant_ship_name(_character, presence), do: Map.get(presence, :ship_name)

  defp occupant_ship_type_id(%{ship_on_chain: false}, _presence), do: nil
  defp occupant_ship_type_id(_character, presence), do: Map.get(presence, :ship_type_id)

  def list_tracked_characters do
    characters =
      Accounts.list_characters()
      |> Map.new(fn character -> {character.eve_id, character} end)

    Presence.all()
    |> Enum.flat_map(fn {eve_id, presence} ->
      case Map.get(characters, eve_id) do
        %{name: name} -> [%{eve_id: eve_id, name: name, online: Map.get(presence, :online)}]
        _ -> []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp broadcast_system_change(mask_id, character_name, system) do
    PubSub.broadcast(
      Ztripwire.PubSub,
      mask_topic(mask_id),
      {:system_changed, %{character: character_name, system: system}}
    )
  end

  defp ensure_system(map, solar_system_id, name_fetcher, position, prev_system) do
    existing =
      Repo.one(
        from(s in MapSystem,
          where: s.mask_id == ^map.mask_id and s.solar_system_id == ^solar_system_id
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

  defp unknown_placeholder(%MapSystem{id: id, mask_id: mask_id}) do
    mask_id
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
    count = Repo.aggregate(from(s in MapSystem, where: s.mask_id == ^map.mask_id), :count)

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
    case Ztripwire.Sde.system(solar_system_id) do
      %{name: name, security: security} ->
        {name, security}

      _ ->
        case ESI.get_system(solar_system_id) do
          {:ok, %{"name" => name} = body} -> {name, body["security_status"]}
          _ -> {"System ##{solar_system_id}", nil}
        end
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
