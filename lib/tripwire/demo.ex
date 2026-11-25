defmodule Tripwire.Demo do
  alias Tripwire.Accounts.Character
  alias Tripwire.Demo.{Fixture, State}
  alias Tripwire.Layouts
  alias Tripwire.Layouts.Layout
  alias Tripwire.Mapping
  alias Tripwire.Mapping.{Comment, MapConnection, MapSystem, Signature}
  alias Tripwire.Mapping.Links
  alias Tripwire.Mapping.Map, as: ChainMap
  alias Tripwire.Settings
  alias Tripwire.Signatures, as: SigParser

  @character_eve_id 9_000_002
  @character_name "Demo User"
  @ship_name "Cenotaph"
  @ship_type_id 85_086
  @home_alias "Home"

  def character_eve_id, do: @character_eve_id

  def character_name, do: @character_name

  def ship_name, do: @ship_name

  def ship_type_id, do: @ship_type_id

  def fixture, do: Fixture.build()

  def reset_map(%State{mask: mask} = state) do
    fresh = Fixture.build()
    map = hd(fresh.maps)

    %{
      state
      | maps: [%{map | mask_id: mask.id}],
        systems: fresh.systems,
        connections: fresh.connections,
        signatures: fresh.signatures,
        comments: fresh.comments,
        next_id: max(state.next_id, fresh.next_id)
    }
  end

  def list_maps_for_mask(%State{} = state, mask_id) do
    Enum.filter(state.maps, &(&1.mask_id == mask_id))
  end

  def get_map(%State{} = state, id), do: Enum.find(state.maps, &(&1.id == id))

  def get_map!(%State{} = state, id) do
    get_map(state, id) || raise ArgumentError, "map not found"
  end

  def list_systems(%State{} = state, map_id) do
    state.systems
    |> Enum.filter(&(&1.map_id == map_id))
    |> Enum.sort_by(& &1.id)
  end

  def list_visible_systems(%State{} = state, map_id) do
    state.systems
    |> Enum.filter(&(&1.map_id == map_id and is_nil(&1.hidden_at)))
    |> Enum.sort_by(& &1.id)
  end

  def list_chain_systems(%State{} = state, %ChainMap{} = map, true) do
    list_systems(state, map.id)
  end

  def list_chain_systems(%State{} = state, %ChainMap{} = map, _show_all) do
    systems = list_visible_systems(state, map.id)

    case home_system_id(state, map) do
      nil ->
        systems

      home_id ->
        reachable = reachable_ids(state, map.id, home_id)
        Enum.filter(systems, &MapSet.member?(reachable, &1.id))
    end
  end

  def get_system(%State{} = state, id), do: Enum.find(state.systems, &(&1.id == id))

  def get_system!(%State{} = state, id) do
    get_system(state, id) || raise ArgumentError, "system not found"
  end

  def get_system_by_solar(%State{} = state, map_id, solar) do
    Enum.find(state.systems, &(&1.map_id == map_id and &1.solar_system_id == solar))
  end

  def list_connections(%State{} = state, map_id) do
    state.connections
    |> Enum.filter(&(&1.map_id == map_id))
    |> Enum.sort_by(& &1.id)
  end

  def list_connections_with_endpoints(%State{} = state, map_id) do
    state
    |> list_connections(map_id)
    |> Enum.map(fn conn ->
      {conn, get_system(state, conn.from_system_id), get_system(state, conn.to_system_id)}
    end)
  end

  def connection_between(%State{} = state, map_id, from_id, to_id) do
    Enum.find(state.connections, fn conn ->
      conn.map_id == map_id and
        ((conn.from_system_id == from_id and conn.to_system_id == to_id) or
           (conn.from_system_id == to_id and conn.to_system_id == from_id))
    end)
  end

  def list_signatures(%State{} = state, system_id) do
    state.signatures
    |> Enum.filter(&(&1.map_system_id == system_id))
    |> Enum.sort_by(& &1.sig_id)
  end

  def list_wormhole_signatures(%State{} = state, map_id) do
    ids =
      state.systems |> Enum.filter(&(&1.map_id == map_id)) |> Enum.map(& &1.id) |> MapSet.new()

    state.signatures
    |> Enum.filter(&(&1.site_type == "wormhole" and MapSet.member?(ids, &1.map_system_id)))
    |> Enum.sort_by(& &1.sig_id)
  end

  def get_signature(%State{} = state, id), do: Enum.find(state.signatures, &(&1.id == id))

  def get_signature!(%State{} = state, id) do
    get_signature(state, id) || raise ArgumentError, "signature not found"
  end

  def list_comments(%State{} = state, system_id) do
    state.comments
    |> Enum.filter(&(&1.map_system_id == system_id))
    |> Enum.sort_by(& &1.id)
  end

  def get_comment(%State{} = state, id), do: Enum.find(state.comments, &(&1.id == id))

  def get_comment!(%State{} = state, id) do
    get_comment(state, id) || raise ArgumentError, "comment not found"
  end

  def list_system_stats(%State{} = state, map_id) do
    ids =
      state.systems |> Enum.filter(&(&1.map_id == map_id)) |> Enum.map(& &1.id) |> MapSet.new()

    state.stats
    |> Enum.filter(&MapSet.member?(ids, &1.map_system_id))
    |> Map.new(&{&1.map_system_id, &1})
  end

  def character_statistics(%State{character: nil}) do
    character_statistics(%State{character: %Character{}})
  end

  def character_statistics(%State{character: character}) do
    %{
      signatures_added: character.signatures_added || 0,
      signatures_updated: character.signatures_updated || 0,
      signatures_deleted: character.signatures_deleted || 0,
      wormholes_added: character.wormholes_added || 0,
      wormholes_updated: character.wormholes_updated || 0,
      wormholes_deleted: character.wormholes_deleted || 0,
      comments_added: character.comments_added || 0,
      comments_updated: character.comments_updated || 0,
      comments_deleted: character.comments_deleted || 0,
      systems_visited: character.systems_visited || 0,
      logins: character.login_count || 0,
      last_login: character.last_login_at
    }
  end

  def list_favorite_candidates(%State{} = state, mask_id, exclude_map_id) do
    map_ids =
      state.maps
      |> Enum.filter(&(&1.mask_id == mask_id and &1.id != exclude_map_id))
      |> Enum.map(& &1.id)
      |> MapSet.new()

    state.systems
    |> Enum.filter(&(&1.favorite and MapSet.member?(map_ids, &1.map_id)))
    |> Enum.sort_by(& &1.id)
  end

  def wormhole_link_target(%State{} = state, mask_id, candidate_solar_id, chain_systems) do
    by_solar = Map.new(chain_systems, &{&1.solar_system_id, &1})
    chain_set = MapSet.new(Map.keys(by_solar))
    map_ids = state.maps |> Enum.filter(&(&1.mask_id == mask_id)) |> Enum.map(& &1.id)
    id_set = MapSet.new(map_ids)

    state.connections
    |> Enum.filter(&MapSet.member?(id_set, &1.map_id))
    |> Enum.find_value(fn conn ->
      from_solar = system_solar(state, conn.from_system_id)
      to_solar = system_solar(state, conn.to_system_id)

      cond do
        from_solar == candidate_solar_id and MapSet.member?(chain_set, to_solar) ->
          {by_solar[to_solar], conn.hole_type}

        to_solar == candidate_solar_id and MapSet.member?(chain_set, from_solar) ->
          {by_solar[from_solar], conn.hole_type}

        true ->
          nil
      end
    end)
  end

  def occupants(%State{} = state) do
    character = state.character
    home = Enum.find(state.systems, &(&1.alias == @home_alias))

    if character && character.character_on_chain && state.tracking? && home do
      ship? = character.ship_on_chain

      [
        %{
          character_name: character.name,
          eve_id: character.eve_id,
          corporation_id: character.corporation_id,
          alliance_id: character.alliance_id,
          solar_system_id: home.solar_system_id,
          system_id: home.id,
          system_name: home.name,
          ship_name: if(ship?, do: @ship_name),
          ship_type_id: if(ship?, do: @ship_type_id)
        }
      ]
    else
      []
    end
  end

  def set_tracking(%State{} = state, tracking?),
    do: {{:ok, state}, %{state | tracking?: tracking?}}

  def settings_assigns(%State{settings: settings}), do: Settings.assigns(settings)

  def put_setting(%State{} = state, key, value) do
    case Settings.change(state.settings, %{key => value}) do
      {:ok, settings} -> {{:ok, settings}, %{state | settings: settings}}
      {:error, changeset} -> {{:error, changeset}, state}
    end
  end

  def list_layouts(%State{} = state) do
    Layouts.core_layouts() ++ Enum.map(state.layouts, &normalize_layout/1)
  end

  def get_layout(%State{}, nil), do: nil

  def get_layout(%State{}, "core:" <> _ = id), do: Layouts.get_layout(id)

  def get_layout(%State{} = state, "saved:" <> raw_id) do
    with {id, ""} <- Integer.parse(raw_id),
         %Layout{} = layout <- Enum.find(state.layouts, &(&1.id == id)) do
      normalize_layout(layout)
    else
      _ -> nil
    end
  end

  def get_layout(%State{}, _id), do: nil

  def arrangement(%State{settings: settings}) do
    case settings.widget_layout do
      %{} = widgets -> Layouts.normalize_widgets(widgets)
      _ -> Layouts.default_widgets()
    end
  end

  def resolve_active(%State{settings: settings} = state),
    do: get_layout(state, settings.active_layout)

  def put_arrangement(%State{} = state, widgets, active_id \\ nil) do
    current = arrangement(state)

    merged =
      Map.new(Layouts.widget_ids(), fn key ->
        base = Map.get(current, key) || %{}
        patch = Map.get(widgets, key) || Map.get(widgets, String.to_atom(key)) || %{}
        {key, Map.merge(base, patch)}
      end)
      |> Layouts.normalize_widgets()

    case Settings.change(state.settings, %{widget_layout: merged, active_layout: active_id}) do
      {:ok, settings} -> {{:ok, settings}, %{state | settings: settings}}
      {:error, changeset} -> {{:error, changeset}, state}
    end
  end

  def reset_arrangement(%State{} = state) do
    case Settings.change(state.settings, %{widget_layout: nil, active_layout: nil}) do
      {:ok, settings} -> {{:ok, settings}, %{state | settings: settings}}
      {:error, changeset} -> {{:error, changeset}, state}
    end
  end

  def save_layout(%State{} = state, name, widgets) do
    changeset = Layout.changeset(%Layout{}, %{name: name, widgets: widgets})

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, layout} ->
        {id, state} = State.take_id(state)
        now = now()

        layout = %{
          layout
          | id: id,
            widgets: Layouts.normalize_widgets(layout.widgets),
            inserted_at: now,
            updated_at: now
        }

        {{:ok, layout}, %{state | layouts: state.layouts ++ [layout]}}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def delete_layout(%State{} = state, "core:" <> _), do: {{:error, :core}, state}

  def delete_layout(%State{} = state, "saved:" <> raw_id) do
    with {id, ""} <- Integer.parse(raw_id),
         %Layout{} = layout <- Enum.find(state.layouts, &(&1.id == id)) do
      {{:ok, layout}, %{state | layouts: Enum.reject(state.layouts, &(&1.id == id))}}
    else
      _ -> {{:error, :not_found}, state}
    end
  end

  def delete_layout(%State{} = state, _id), do: {{:error, :not_found}, state}

  def update_character(%State{} = state, id, attrs_fn) do
    case Enum.find(state.members |> Map.values() |> List.flatten(), &(&1.id == id)) do
      nil ->
        {{:error, :not_found}, state}

      character ->
        case Ecto.Changeset.change(character, attrs_fn.(character))
             |> Ecto.Changeset.apply_action(:update) do
          {:ok, updated} ->
            state = replace_character(state, updated)
            {{:ok, updated}, state}

          {:error, changeset} ->
            {{:error, changeset}, state}
        end
    end
  end

  def members(%State{} = state, mask_id), do: Map.get(state.members, mask_id, [])

  def add_member(%State{mask: mask} = state, mask_id, eve_id, name)
      when mask_id == mask.id and is_integer(eve_id) do
    {id, state} = State.take_id(state)
    now = now()

    character = %Character{
      id: id,
      eve_id: eve_id,
      name: name,
      is_admin: false,
      ship_on_chain: true,
      character_on_chain: true,
      inserted_at: now,
      updated_at: now
    }

    members = Map.update(state.members, mask_id, [character], &(&1 ++ [character]))
    {{:ok, character}, %{state | members: members}}
  end

  def add_member(%State{} = state, _mask_id, _eve_id, _name), do: {{:error, :forbidden}, state}

  def remove_member(%State{} = state, mask_id, member_id) do
    members = Map.get(state.members, mask_id, [])

    case Enum.find(members, &(&1.id == member_id)) do
      nil ->
        {{:error, :not_found}, state}

      member ->
        updated = Enum.reject(members, &(&1.id == member_id))
        {{:ok, member}, %{state | members: Map.put(state.members, mask_id, updated)}}
    end
  end

  def create_map(%State{} = state, attrs) do
    case Ecto.Changeset.apply_action(ChainMap.changeset(%ChainMap{}, attrs), :insert) do
      {:ok, map} ->
        {map, state} = add_map(state, map)
        {{:ok, map}, state}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  defp add_map(%State{} = state, %ChainMap{} = map) do
    {id, state} = State.take_id(state)
    now = now()
    map = %{map | id: id, inserted_at: now, updated_at: now}
    {map, %{state | maps: state.maps ++ [map]}}
  end

  def update_map(%State{} = state, %ChainMap{} = map, attrs) do
    case Ecto.Changeset.apply_action(ChainMap.changeset(map, attrs), :update) do
      {:ok, updated} ->
        updated = %{updated | updated_at: now()}

        {{:ok, updated},
         %{state | maps: Enum.map(state.maps, &if(&1.id == map.id, do: updated, else: &1))}}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def delete_map_full(%State{} = state, %ChainMap{} = map) do
    system_ids =
      state.systems |> Enum.filter(&(&1.map_id == map.id)) |> Enum.map(& &1.id) |> MapSet.new()

    connection_ids =
      state.connections
      |> Enum.filter(&(&1.map_id == map.id))
      |> Enum.map(& &1.id)
      |> MapSet.new()

    %{
      state
      | maps: Enum.reject(state.maps, &(&1.id == map.id)),
        systems: Enum.reject(state.systems, &MapSet.member?(system_ids, &1.id)),
        connections: Enum.reject(state.connections, &MapSet.member?(connection_ids, &1.id)),
        signatures: Enum.reject(state.signatures, &MapSet.member?(system_ids, &1.map_system_id)),
        comments: Enum.reject(state.comments, &MapSet.member?(system_ids, &1.map_system_id)),
        stats: Enum.reject(state.stats, &MapSet.member?(system_ids, &1.map_system_id))
    }
    |> then(&{{:ok, map}, &1})
  end

  def add_system_to_map(%State{} = state, %ChainMap{} = map, attrs, opts \\ []) do
    attrs =
      if Keyword.get(opts, :fill?, true) do
        put_system_data(attrs)
      else
        attrs
      end

    case Ecto.Changeset.apply_action(
           MapSystem.changeset(%MapSystem{map_id: map.id}, attrs),
           :insert
         ) do
      {:ok, system} ->
        {id, state} = State.take_id(state)
        now = now()
        system = %{system | id: id, inserted_at: now, updated_at: now}
        {state, system} = ensure_jita_notes(state, system)
        {{:ok, system}, %{state | systems: state.systems ++ [system]}}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def ensure_chain_system(%State{} = state, %ChainMap{} = map, attrs) do
    solar = attrs[:solar_system_id] || attrs["solar_system_id"]

    case get_system_by_solar(state, map.id, solar) do
      %MapSystem{} = system ->
        {{:ok, system, false}, state}

      nil ->
        attrs = Map.merge(%{x: 460.0, y: 300.0}, attrs)

        case add_system_to_map(state, map, attrs) do
          {{:ok, system}, state} -> {{:ok, system, true}, state}
          error -> error
        end
    end
  end

  def update_system(%State{} = state, %MapSystem{} = system, attrs) do
    case Ecto.Changeset.apply_action(MapSystem.changeset(system, attrs), :update) do
      {:ok, updated} ->
        updated = %{updated | updated_at: now()}
        {{:ok, updated}, replace_system(state, updated)}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def update_system_position(%State{} = state, %MapSystem{} = system, x, y) do
    updated = %{system | x: x, y: y, updated_at: now()}
    {{:ok, updated}, replace_system(state, updated)}
  end

  def unhide_systems(%State{} = state, ids) do
    id_set = MapSet.new(ids)
    now = now()

    systems =
      Enum.map(state.systems, fn system ->
        if MapSet.member?(id_set, system.id) and system.hidden_at do
          %{system | hidden_at: nil, updated_at: now}
        else
          system
        end
      end)

    {{:ok, state}, %{state | systems: systems}}
  end

  def delete_system(%State{} = state, %MapSystem{} = system) do
    state = %{
      state
      | systems: Enum.reject(state.systems, &(&1.id == system.id)),
        connections:
          Enum.reject(
            state.connections,
            &(&1.from_system_id == system.id or &1.to_system_id == system.id)
          ),
        signatures: Enum.reject(state.signatures, &(&1.map_system_id == system.id)),
        comments: Enum.reject(state.comments, &(&1.map_system_id == system.id)),
        stats: Enum.reject(state.stats, &(&1.map_system_id == system.id))
    }

    {{:ok, system}, state}
  end

  def upsert_connection(%State{} = state, map_id, system_a_id, system_b_id, attrs \\ %{}) do
    case connection_between(state, map_id, system_a_id, system_b_id) do
      %MapConnection{} = conn ->
        attrs = Map.merge(attrs, %{map_id: map_id})

        case Ecto.Changeset.apply_action(MapConnection.changeset(conn, attrs), :update) do
          {:ok, updated} ->
            updated = %{updated | updated_at: now()}
            {_, state} = unhide_systems(state, [system_a_id, system_b_id])
            {{:ok, updated, false}, replace_connection(state, updated)}

          {:error, changeset} ->
            {{:error, changeset}, state}
        end

      nil ->
        attrs =
          Map.merge(attrs, %{
            map_id: map_id,
            from_system_id: system_a_id,
            to_system_id: system_b_id
          })

        case Ecto.Changeset.apply_action(
               MapConnection.changeset(%MapConnection{}, attrs),
               :insert
             ) do
          {:ok, conn} ->
            {id, state} = State.take_id(state)
            now = now()

            conn = %{
              conn
              | id: id,
                from_system: get_system(state, system_a_id),
                to_system: get_system(state, system_b_id),
                inserted_at: now,
                updated_at: now
            }

            {_, state} = unhide_systems(state, [system_a_id, system_b_id])
            {{:ok, conn, true}, %{state | connections: state.connections ++ [conn]}}

          {:error, changeset} ->
            {{:error, changeset}, state}
        end
    end
  end

  def sync_signature_to_connections(
        %State{} = state,
        %ChainMap{} = map,
        %MapSystem{} = system,
        old_code,
        new_code
      )
      when is_binary(new_code) do
    now = now()

    connections =
      Enum.map(state.connections, fn conn ->
        if conn.map_id == map.id and
             (conn.from_system_id == system.id or conn.to_system_id == system.id) and
             (conn.hole_type in [nil, ""] or (not is_nil(old_code) and conn.hole_type == old_code)) do
          %{conn | hole_type: new_code, updated_at: now}
        else
          conn
        end
      end)

    {{:ok, state}, %{state | connections: connections}}
  end

  def sync_signature_to_connections(%State{} = state, _map, _system, _old_code, _new_code) do
    {{:ok, state}, state}
  end

  def upsert_signatures(
        %State{} = state,
        %MapSystem{} = system,
        entries,
        %Character{} = character
      ) do
    Enum.reduce(entries, {0, 0, state}, fn entry, {added, updated, state} ->
      life_length = 259_200
      now = now()

      attrs = %{
        map_system_id: system.id,
        sig_id: entry.sig_id,
        kind: to_string(entry.kind),
        type_name: entry.name || entry.wormhole_type,
        site_type: to_string(entry.category || :unknown),
        life_length: life_length,
        expires_at: DateTime.add(now, life_length, :second),
        updated_by_id: character.id
      }

      case Enum.find(
             state.signatures,
             &(&1.map_system_id == system.id and &1.sig_id == entry.sig_id)
           ) do
        nil ->
          case build_signature(state, attrs, character) do
            {{:ok, signature}, state} ->
              {added + 1, updated, add_signature(state, signature)}

            {_error, state} ->
              {added, updated, state}
          end

        signature ->
          case Ecto.Changeset.apply_action(Signature.changeset(signature, attrs), :update) do
            {:ok, updated_signature} ->
              {added, updated + 1,
               replace_signature(state, %{updated_signature | updated_at: now})}

            {:error, _changeset} ->
              {added, updated, state}
          end
      end
    end)
    |> then(fn {added, updated, state} -> {{added, updated}, state} end)
  end

  def create_signature(%State{} = state, %MapSystem{} = system, attrs, %Character{} = character) do
    attrs =
      attrs
      |> with_expires_at()
      |> Map.merge(%{
        map_system_id: system.id,
        created_by_id: character.id,
        updated_by_id: character.id
      })

    case build_signature(state, attrs, character) do
      {{:ok, signature}, state} ->
        {{:ok, signature}, add_signature(state, signature)}

      {{:error, changeset}, state} ->
        {{:error, changeset}, state}
    end
  end

  def update_signature(
        %State{} = state,
        %Signature{} = signature,
        attrs,
        %Character{} = character
      ) do
    attrs = with_expires_at(attrs, signature)

    case Ecto.Changeset.apply_action(
           Signature.changeset(signature, Map.put(attrs, :updated_by_id, character.id)),
           :update
         ) do
      {:ok, updated} ->
        updated = %{updated | updated_at: now()}
        {{:ok, updated}, replace_signature(state, updated)}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def delete_signature(%State{} = state, %Signature{} = signature, _character \\ nil) do
    paired =
      signature
      |> paired_signatures(state)

    ids = MapSet.new([signature.id | Enum.map(paired, & &1.id)])

    {{:ok, signature},
     %{state | signatures: Enum.reject(state.signatures, &MapSet.member?(ids, &1.id))}}
  end

  def sync_map_after_signature_change(%State{} = state, %MapSystem{} = system, deleted_signatures)
      when is_list(deleted_signatures) do
    codes = Links.deleted_codes(deleted_signatures)
    {dropped, state} = drop_connections_for_codes(state, system, codes)
    {linked, state} = auto_link_wormholes(state, system, dropped_pair_keys(dropped))
    {state, _} = ensure_unknown_nodes(state, system)
    state = delete_unlinked_unknowns(state, system.map_id)

    candidates =
      (dropped |> Enum.flat_map(fn {conn, _, _} -> [conn.from_system_id, conn.to_system_id] end)) ++
        (linked |> Enum.flat_map(fn conn -> [conn.from_system_id, conn.to_system_id] end))

    {orphans, state} = hide_orphan_systems(state, system.map_id, Enum.uniq(candidates))
    {detached, state} = hide_detached_systems(state, system.map_id)

    {{length(dropped), length(linked), orphans + detached}, state}
  end

  def create_comment(%State{} = state, %MapSystem{} = system, attrs, character \\ nil) do
    character_id = if is_struct(character, Character), do: character.id, else: nil

    attrs =
      attrs
      |> normalize_attrs()
      |> Map.merge(%{
        map_system_id: system.id,
        character_id: character_id,
        mask_id: state.mask.id
      })

    case Ecto.Changeset.apply_action(Comment.changeset(%Comment{}, attrs), :insert) do
      {:ok, comment} ->
        {id, state} = State.take_id(state)
        now = now()

        comment = %{
          comment
          | id: id,
            character: if(is_struct(character, Character), do: character),
            mask: state.mask,
            inserted_at: now,
            updated_at: now
        }

        {{:ok, comment}, %{state | comments: state.comments ++ [comment]}}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def update_comment(%State{} = state, %Comment{} = comment, attrs, _character \\ nil) do
    case Ecto.Changeset.apply_action(Comment.changeset(comment, attrs), :update) do
      {:ok, updated} ->
        updated = %{updated | updated_at: now()}
        {{:ok, updated}, replace_comment(state, updated)}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  def delete_comment(%State{} = state, %Comment{} = comment, _character \\ nil) do
    {{:ok, comment}, %{state | comments: Enum.reject(state.comments, &(&1.id == comment.id))}}
  end

  defp build_signature(state, attrs, character) do
    attrs = Map.merge(attrs, %{created_by_id: character.id})

    case Ecto.Changeset.apply_action(Signature.changeset(%Signature{}, attrs), :insert) do
      {:ok, signature} ->
        {id, state} = State.take_id(state)
        now = now()

        signature = %{
          signature
          | id: id,
            created_by: character,
            updated_by: character,
            inserted_at: signature.inserted_at || now,
            updated_at: now
        }

        {{:ok, signature}, state}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  defp add_signature(state, signature), do: %{state | signatures: state.signatures ++ [signature]}

  defp replace_signature(state, signature),
    do: %{
      state
      | signatures:
          Enum.map(state.signatures, &if(&1.id == signature.id, do: signature, else: &1))
    }

  defp replace_comment(state, comment),
    do: %{
      state
      | comments: Enum.map(state.comments, &if(&1.id == comment.id, do: comment, else: &1))
    }

  defp replace_system(state, system),
    do: %{state | systems: Enum.map(state.systems, &if(&1.id == system.id, do: system, else: &1))}

  defp replace_connection(state, conn),
    do: %{
      state
      | connections: Enum.map(state.connections, &if(&1.id == conn.id, do: conn, else: &1))
    }

  defp replace_character(state, character) do
    members =
      Map.new(state.members, fn {mask_id, members} ->
        {mask_id, Enum.map(members, &if(&1.id == character.id, do: character, else: &1))}
      end)

    %{
      state
      | character: if(state.character && state.character.id == character.id, do: character),
        members: members
    }
  end

  defp paired_signatures(%Signature{site_type: "wormhole"} = signature, state) do
    with code when not is_nil(code) <- SigParser.wormhole_code(signature.type_name),
         %MapSystem{} = system <- get_system(state, signature.map_system_id),
         %MapConnection{} = connection <- connection_for_code(state, system, code) do
      peer_id =
        if connection.from_system_id == system.id,
          do: connection.to_system_id,
          else: connection.from_system_id

      state.signatures
      |> Enum.filter(
        &(&1.map_system_id == peer_id and &1.site_type == "wormhole" and
            SigParser.wormhole_code(&1.type_name) == code)
      )
    else
      _ -> []
    end
  end

  defp paired_signatures(_signature, _state), do: []

  defp connection_for_code(state, system, code) do
    Enum.find(state.connections, fn conn ->
      conn.map_id == system.map_id and conn.hole_type == code and
        (conn.from_system_id == system.id or conn.to_system_id == system.id)
    end)
  end

  defp drop_connections_for_codes(state, system, codes) do
    if MapSet.size(codes) == 0 do
      {[], state}
    else
      dropped =
        state.connections
        |> Enum.filter(fn conn ->
          conn.map_id == system.map_id and
            (conn.from_system_id == system.id or conn.to_system_id == system.id) and
            MapSet.member?(codes, String.upcase(to_string(conn.hole_type || "")))
        end)
        |> Enum.map(fn conn ->
          {conn, get_system(state, conn.from_system_id), get_system(state, conn.to_system_id)}
        end)

      ids = MapSet.new(Enum.map(dropped, fn {conn, _, _} -> conn.id end))

      {dropped,
       %{state | connections: Enum.reject(state.connections, &MapSet.member?(ids, &1.id))}}
    end
  end

  defp auto_link_wormholes(state, system, excluded_pairs) do
    others =
      state.signatures
      |> Enum.filter(
        &(&1.site_type == "wormhole" and
            &1.map_system_id != system.id and
            (get_system(state, &1.map_system_id) || %{map_id: nil}).map_id == system.map_id)
      )

    targets =
      state.signatures
      |> Enum.filter(&(&1.map_system_id == system.id and &1.site_type == "wormhole"))
      |> Enum.flat_map(&Links.link_targets(&1, others))
      |> Enum.uniq_by(& &1.map_system_id)
      |> Enum.reject(fn target ->
        MapSet.member?(
          excluded_pairs,
          Links.pair_key(
            system.id,
            target.map_system_id,
            SigParser.wormhole_code(target.type_name)
          )
        )
      end)
      |> Enum.filter(fn target ->
        case connection_between(state, system.map_id, system.id, target.map_system_id) do
          nil -> true
          conn -> conn.hole_type in [nil, ""]
        end
      end)

    Enum.reduce(targets, {[], state}, fn target, {linked, state} ->
      code = SigParser.wormhole_code(target.type_name)

      cond do
        connection_between(state, system.map_id, system.id, target.map_system_id) != nil ->
          {{:ok, conn, _created?}, state} =
            upsert_connection(state, system.map_id, system.id, target.map_system_id, %{
              hole_type: code
            })

          {[conn | linked], state}

        placeholder = placeholder_connection(state, system, code) ->
          now = now()

          repointed = %{
            placeholder
            | from_system_id: system.id,
              to_system_id: target.map_system_id,
              updated_at: now
          }

          {[repointed | linked], replace_connection(state, repointed)}

        true ->
          {{:ok, conn, _created?}, state} =
            upsert_connection(state, system.map_id, system.id, target.map_system_id, %{
              hole_type: code
            })

          {[conn | linked], state}
      end
    end)
    |> then(fn {linked, state} -> {Enum.reverse(linked), state} end)
  end

  defp placeholder_connection(state, system, code) when is_binary(code) do
    Enum.find(state.connections, fn conn ->
      conn.hole_type == code and
        (conn.from_system_id == system.id or conn.to_system_id == system.id) and
        placeholder_endpoint?(state, conn, system.id)
    end)
  end

  defp placeholder_connection(_state, _system, _code), do: nil

  defp placeholder_endpoint?(state, conn, system_id) do
    peer_id =
      if conn.from_system_id == system_id, do: conn.to_system_id, else: conn.from_system_id

    case get_system(state, peer_id) do
      %MapSystem{unknown: true} -> true
      _ -> false
    end
  end

  defp dropped_pair_keys(dropped) do
    MapSet.new(dropped, fn {conn, _, _} ->
      Links.pair_key(conn.from_system_id, conn.to_system_id, conn.hole_type)
    end)
  end

  defp ensure_unknown_nodes(state, %MapSystem{} = system) do
    linked = connection_codes(state, system)

    codes =
      state.signatures
      |> Enum.filter(&(&1.map_system_id == system.id and &1.site_type == "wormhole"))
      |> Enum.map(&SigParser.wormhole_code(&1.type_name))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(linked, &1))

    Enum.reduce(codes, {state, 0}, fn code, {state, count} ->
      {placeholder, state} = add_unknown_system(state, system.map_id)

      {{:ok, _conn, _created?}, state} =
        upsert_connection(state, system.map_id, system.id, placeholder.id, %{hole_type: code})

      {state, count + 1}
    end)
  end

  defp connection_codes(state, system) do
    state.connections
    |> Enum.filter(
      &(&1.map_id == system.map_id and
          (&1.from_system_id == system.id or &1.to_system_id == system.id))
    )
    |> Enum.map(&(&1.hole_type || ""))
    |> MapSet.new()
  end

  defp add_unknown_system(state, map_id) do
    map = get_map(state, map_id)

    add_system_to_map(
      state,
      map,
      %{unknown: true, solar_system_id: 0, name: "unknown", x: 460.0, y: 300.0},
      fill?: false
    )
    |> case do
      {{:ok, system}, state} -> {system, state}
      {_error, state} -> {nil, state}
    end
  end

  defp delete_unlinked_unknowns(state, map_id) do
    connected = connected_system_ids(state, map_id)

    %{
      state
      | systems:
          Enum.reject(
            state.systems,
            &(&1.map_id == map_id and &1.unknown and not MapSet.member?(connected, &1.id))
          )
    }
  end

  defp hide_orphan_systems(state, map_id, candidate_ids) do
    connected = connected_system_ids(state, map_id)
    map = get_map(state, map_id)
    home = home_system_id(state, map)

    hide =
      state.systems
      |> Enum.filter(
        &(&1.map_id == map_id and is_nil(&1.hidden_at) and &1.id in candidate_ids and
            not MapSet.member?(connected, &1.id) and &1.id != home)
      )

    ids = MapSet.new(hide, & &1.id)
    now = now()

    systems =
      Enum.map(state.systems, fn system ->
        if MapSet.member?(ids, system.id),
          do: %{system | hidden_at: now, updated_at: now},
          else: system
      end)

    {length(hide), %{state | systems: systems}}
  end

  defp hide_detached_systems(state, map_id) do
    case get_map(state, map_id) do
      nil ->
        {0, state}

      map ->
        case home_system_id(state, map) do
          nil ->
            {0, state}

          home_id ->
            reachable = reachable_ids(state, map_id, home_id)
            now = now()

            hide =
              state.systems
              |> Enum.filter(
                &(&1.map_id == map_id and is_nil(&1.hidden_at) and
                    not MapSet.member?(reachable, &1.id))
              )

            ids = MapSet.new(hide, & &1.id)

            systems =
              Enum.map(state.systems, fn system ->
                if MapSet.member?(ids, system.id),
                  do: %{system | hidden_at: now, updated_at: now},
                  else: system
              end)

            {length(hide), %{state | systems: systems}}
        end
    end
  end

  defp connected_system_ids(state, map_id) do
    state.connections
    |> Enum.filter(&(&1.map_id == map_id))
    |> Enum.flat_map(fn conn -> [conn.from_system_id, conn.to_system_id] end)
    |> MapSet.new()
  end

  defp reachable_ids(state, map_id, home_id) do
    adjacency =
      state.connections
      |> Enum.filter(&(&1.map_id == map_id))
      |> Enum.reduce(%{}, fn conn, acc ->
        acc
        |> Map.update(conn.from_system_id, [conn.to_system_id], &[conn.to_system_id | &1])
        |> Map.update(conn.to_system_id, [conn.from_system_id], &[conn.from_system_id | &1])
      end)

    bfs(:queue.from_list([home_id]), adjacency, MapSet.new([home_id]))
  end

  defp bfs(queue, adjacency, seen) do
    case :queue.out(queue) do
      {:empty, _} ->
        seen

      {{:value, id}, rest} ->
        {queue, seen} =
          Enum.reduce(Map.get(adjacency, id, []), {rest, seen}, fn neighbor, {q, s} ->
            if MapSet.member?(s, neighbor) do
              {q, s}
            else
              {:queue.in(neighbor, q), MapSet.put(s, neighbor)}
            end
          end)

        bfs(queue, adjacency, seen)
    end
  end

  defp home_system_id(_state, %ChainMap{home_solar_system_id: nil}), do: nil

  defp home_system_id(%State{} = state, %ChainMap{home_solar_system_id: solar} = map) do
    case get_system_by_solar(state, map.id, solar) do
      %MapSystem{id: id} -> id
      nil -> nil
    end
  end

  defp system_solar(_state, nil), do: nil

  defp system_solar(state, id),
    do: (get_system(state, id) || %{solar_system_id: nil}).solar_system_id

  defp put_system_data(attrs) do
    name = attrs[:name] || attrs["name"]
    solar = attrs[:solar_system_id] || attrs["solar_system_id"]

    solar
    |> Tripwire.WormholeSystems.attrs(name)
    |> Enum.reduce(attrs, fn {key, value}, acc ->
      if Map.has_key?(acc, key) or Map.has_key?(acc, to_string(key)),
        do: acc,
        else: Map.put(acc, key, value)
    end)
  end

  defp ensure_jita_notes(state, %MapSystem{unknown: true} = system), do: {state, system}

  defp ensure_jita_notes(state, %MapSystem{} = system) do
    jita? =
      system.solar_system_id == 30_000_142 or
        String.downcase(system.name || "") == "jita"

    if jita? do
      existing =
        state.comments |> Enum.filter(&(&1.map_system_id == system.id)) |> Enum.map(& &1.body)

      bodies = Mapping.welcome_notes() |> Enum.reject(&(&1 in existing))
      now = now()

      {comments, state} =
        Enum.map_reduce(bodies, state, fn body, state ->
          {id, state} = State.take_id(state)

          comment = %Comment{
            id: id,
            map_system_id: system.id,
            character_id: state.character && state.character.id,
            character: state.character,
            mask_id: state.mask.id,
            mask: state.mask,
            body: body,
            inserted_at: now,
            updated_at: now
          }

          {comment, state}
        end)

      {%{state | comments: state.comments ++ comments}, system}
    else
      {state, system}
    end
  end

  defp normalize_layout(%Layout{} = layout) do
    %{
      id: "saved:#{layout.id}",
      name: layout.name,
      description: nil,
      core?: false,
      widgets: Layouts.normalize_widgets(layout.widgets)
    }
  end

  defp with_expires_at(attrs, existing \\ nil) do
    life_length =
      attrs[:life_length] || attrs["life_length"] || (existing && existing.life_length) || 259_200

    life_length =
      if is_binary(life_length) do
        case Integer.parse(life_length) do
          {number, ""} -> number
          _ -> 259_200
        end
      else
        life_length
      end

    scanned_at =
      attrs[:inserted_at] || attrs["inserted_at"] || (existing && existing.inserted_at) ||
        DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

    expires_at =
      attrs[:expires_at] || attrs["expires_at"] ||
        NaiveDateTime.add(scanned_at, life_length, :second)

    attrs |> Map.put(:life_length, life_length) |> Map.put(:expires_at, expires_at)
  end

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
