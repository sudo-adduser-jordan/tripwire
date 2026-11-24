defmodule Tripwire.Data do
  alias Tripwire.Accounts
  alias Tripwire.Demo
  alias Tripwire.Demo.State
  alias Tripwire.Layouts
  alias Tripwire.Mapping
  alias Tripwire.Settings

  def list_maps_for_mask(:db, mask_id), do: Mapping.list_maps_for_mask(mask_id)
  def list_maps_for_mask(%State{} = state, mask_id), do: Demo.list_maps_for_mask(state, mask_id)

  def get_map(:db, id), do: Tripwire.Repo.get(Tripwire.Mapping.Map, id)
  def get_map(%State{} = state, id), do: Demo.get_map(state, id)

  def get_map!(:db, id), do: Mapping.get_map!(id)
  def get_map!(%State{} = state, id), do: Demo.get_map!(state, id)

  def list_systems(:db, map_id), do: Mapping.list_systems(map_id)
  def list_systems(%State{} = state, map_id), do: Demo.list_systems(state, map_id)

  def list_visible_systems(:db, map_id), do: Mapping.list_visible_systems(map_id)
  def list_visible_systems(%State{} = state, map_id), do: Demo.list_visible_systems(state, map_id)

  def list_chain_systems(:db, map, show_all), do: Mapping.list_chain_systems(map, show_all)

  def list_chain_systems(%State{} = state, map, show_all),
    do: Demo.list_chain_systems(state, map, show_all)

  def get_system(:db, id), do: Mapping.get_system(id)
  def get_system(%State{} = state, id), do: Demo.get_system(state, id)

  def get_system!(:db, id), do: Mapping.get_system!(id)
  def get_system!(%State{} = state, id), do: Demo.get_system!(state, id)

  def list_connections_with_endpoints(:db, map_id),
    do: Mapping.list_connections_with_endpoints(map_id)

  def list_connections_with_endpoints(%State{} = state, map_id),
    do: Demo.list_connections_with_endpoints(state, map_id)

  def get_connection(:db, id), do: Mapping.get_connection(id)
  def get_connection(%State{} = state, id), do: Demo.get_connection(state, id)

  def list_signatures(:db, system_id), do: Mapping.list_signatures(system_id)
  def list_signatures(%State{} = state, system_id), do: Demo.list_signatures(state, system_id)

  def list_wormhole_signatures(:db, map_id), do: Mapping.list_wormhole_signatures(map_id)

  def list_wormhole_signatures(%State{} = state, map_id),
    do: Demo.list_wormhole_signatures(state, map_id)

  def get_signature(:db, id), do: Mapping.get_signature(id)
  def get_signature(%State{} = state, id), do: Demo.get_signature(state, id)

  def get_signature!(:db, id), do: Mapping.get_signature!(id)
  def get_signature!(%State{} = state, id), do: Demo.get_signature!(state, id)

  def list_comments(:db, system_id), do: Mapping.list_comments(system_id)
  def list_comments(%State{} = state, system_id), do: Demo.list_comments(state, system_id)

  def get_comment!(:db, id), do: Mapping.get_comment!(id)
  def get_comment!(%State{} = state, id), do: Demo.get_comment!(state, id)

  def list_flares(:db, system_id), do: Mapping.list_flares(system_id)
  def list_flares(%State{} = state, system_id), do: Demo.list_flares(state, system_id)

  def get_flare(:db, id), do: Tripwire.Repo.get(Tripwire.Mapping.Flare, id)
  def get_flare(%State{} = state, id), do: Demo.get_flare(state, id)

  def get_system_stat(:db, system_id), do: Mapping.get_system_stat(system_id)
  def get_system_stat(%State{} = state, system_id), do: Demo.get_system_stat(state, system_id)

  def list_system_stats(:db, map_id), do: Mapping.list_system_stats(map_id)
  def list_system_stats(%State{} = state, map_id), do: Demo.list_system_stats(state, map_id)

  def character_statistics(:db, character), do: Mapping.character_statistics(character)
  def character_statistics(%State{} = state, _character), do: Demo.character_statistics(state)

  def list_favorite_candidates(:db, mask_id, exclude_map_id),
    do: Mapping.list_favorite_candidates(mask_id, exclude_map_id)

  def list_favorite_candidates(%State{} = state, mask_id, exclude_map_id),
    do: Demo.list_favorite_candidates(state, mask_id, exclude_map_id)

  def wormhole_link_target(:db, mask_id, solar, chain),
    do: Mapping.wormhole_link_target(mask_id, solar, chain)

  def wormhole_link_target(%State{} = state, mask_id, solar, chain),
    do: Demo.wormhole_link_target(state, mask_id, solar, chain)

  def welcome_notes, do: Mapping.welcome_notes()

  def occupants(:db, map_id, mask), do: db_occupants(map_id, mask)

  def occupants(%State{} = state, _map_id, _mask), do: Demo.occupants(state)

  defp db_occupants(map_id, mask) do
    map_id
    |> Tripwire.Tracking.list_occupants()
    |> Enum.filter(fn occupant ->
      case mask do
        %{kind: "corporation", eve_owner_id: corp_id} when is_integer(corp_id) ->
          occupant.corporation_id == corp_id

        %{kind: "alliance", eve_owner_id: alliance_id} when is_integer(alliance_id) ->
          occupant.alliance_id == alliance_id

        _ ->
          true
      end
    end)
  end

  def settings_assigns(:db), do: Settings.assigns()
  def settings_assigns(%State{} = state), do: Demo.settings_assigns(state)

  def put_setting(:db, key, value), do: {Settings.update(%{key => value}), :db}

  def put_setting(%State{} = state, key, value), do: Demo.put_setting(state, key, value)

  def list_layouts(:db), do: Layouts.list_layouts()
  def list_layouts(%State{} = state), do: Demo.list_layouts(state)

  def get_layout(:db, id), do: Layouts.get_layout(id)
  def get_layout(%State{} = state, id), do: Demo.get_layout(state, id)

  def arrangement(:db), do: Layouts.arrangement()
  def arrangement(%State{} = state), do: Demo.arrangement(state)

  def resolve_active(:db), do: Layouts.resolve_active()
  def resolve_active(%State{} = state), do: Demo.resolve_active(state)

  def put_arrangement(:db, widgets, active_id),
    do: {Layouts.put_arrangement(widgets, active_id), :db}

  def put_arrangement(%State{} = state, widgets, active_id),
    do: Demo.put_arrangement(state, widgets, active_id)

  def reset_arrangement(:db), do: {Layouts.reset_arrangement(), :db}
  def reset_arrangement(%State{} = state), do: Demo.reset_arrangement(state)

  def clear_active(:db), do: {Layouts.clear_active(), :db}

  def clear_active(%State{} = state), do: Demo.put_setting(state, :active_layout, nil)

  def reset_layout(:db, visibility) do
    {Settings.update(Map.merge(%{widget_layout: nil, active_layout: nil}, visibility)), :db}
  end

  def reset_layout(%State{} = state, visibility) do
    attrs = Map.merge(%{widget_layout: nil, active_layout: nil}, visibility)

    Enum.reduce(attrs, {{:ok, nil}, state}, fn {key, value}, {_result, state} ->
      Demo.put_setting(state, key, value)
    end)
  end

  def save_layout(:db, name, widgets), do: {Layouts.save_layout(name, widgets), :db}
  def save_layout(%State{} = state, name, widgets), do: Demo.save_layout(state, name, widgets)

  def delete_layout(:db, id), do: {Layouts.delete_layout(id), :db}
  def delete_layout(%State{} = state, id), do: Demo.delete_layout(state, id)

  def update_character(:db, id, attrs_fn) do
    result =
      with %{} = character <- Accounts.get_character(id),
           {:ok, updated} <- Accounts.update_character(character, attrs_fn.(character)) do
        {:ok, updated}
      else
        nil -> {:error, :not_found}
        {:error, changeset} -> {:error, changeset}
      end

    {result, :db}
  end

  def update_character(%State{} = state, id, attrs_fn) do
    Demo.update_character(state, id, attrs_fn)
  end

  def create_map(:db, attrs), do: {Mapping.create_map(attrs), :db}
  def create_map(%State{} = state, attrs), do: Demo.create_map(state, attrs)

  def update_map(:db, map, attrs), do: {Mapping.update_map(map, attrs), :db}
  def update_map(%State{} = state, map, attrs), do: Demo.update_map(state, map, attrs)

  def delete_map_full(:db, map), do: {Mapping.delete_map_full(map), :db}
  def delete_map_full(%State{} = state, map), do: Demo.delete_map_full(state, map)

  def reset_map(%State{} = state), do: Demo.reset_map(state)

  def add_system_to_map(data, map, attrs, opts \\ [])

  def add_system_to_map(:db, map, attrs, opts),
    do: {Mapping.add_system_to_map(map, attrs, opts), :db}

  def add_system_to_map(%State{} = state, map, attrs, opts),
    do: Demo.add_system_to_map(state, map, attrs, opts)

  def ensure_chain_system(:db, map, attrs), do: {Mapping.ensure_chain_system(map, attrs), :db}

  def ensure_chain_system(%State{} = state, map, attrs),
    do: Demo.ensure_chain_system(state, map, attrs)

  def update_system(:db, system, attrs), do: {Mapping.update_system(system, attrs), :db}
  def update_system(%State{} = state, system, attrs), do: Demo.update_system(state, system, attrs)

  def update_system_position(:db, system, x, y),
    do: {Mapping.update_system_position(system, x, y), :db}

  def update_system_position(%State{} = state, system, x, y),
    do: Demo.update_system_position(state, system, x, y)

  def delete_system(:db, system), do: {Mapping.delete_system(system), :db}
  def delete_system(%State{} = state, system), do: Demo.delete_system(state, system)

  def unhide_systems(:db, ids) do
    Mapping.unhide_systems(ids)
    {{:ok, nil}, :db}
  end

  def unhide_systems(%State{} = state, ids), do: Demo.unhide_systems(state, ids)

  def upsert_connection(data, map_id, a, b, attrs \\ %{})

  def upsert_connection(:db, map_id, a, b, attrs),
    do: {Mapping.upsert_connection(map_id, a, b, attrs), :db}

  def upsert_connection(%State{} = state, map_id, a, b, attrs),
    do: Demo.upsert_connection(state, map_id, a, b, attrs)

  def update_connection(:db, conn, attrs), do: {Mapping.update_connection(conn, attrs), :db}

  def update_connection(%State{} = state, conn, attrs),
    do: Demo.update_connection(state, conn, attrs)

  def delete_connection(:db, conn), do: {Mapping.delete_connection(conn), :db}
  def delete_connection(%State{} = state, conn), do: Demo.delete_connection(state, conn)

  def sync_connection_life(:db, conn), do: {Mapping.sync_connection_life(conn), :db}

  def sync_connection_life(%State{} = state, conn),
    do: Demo.sync_connection_life(state, conn)

  def sync_signature_to_connections(:db, map, system, old_code, new_code),
    do: {Mapping.sync_signature_to_connections(map, system, old_code, new_code), :db}

  def sync_signature_to_connections(%State{} = state, map, system, old_code, new_code),
    do: Demo.sync_signature_to_connections(state, map, system, old_code, new_code)

  def upsert_signatures(:db, system, entries, character),
    do: {Mapping.upsert_signatures(system, entries, character), :db}

  def upsert_signatures(%State{} = state, system, entries, character),
    do: Demo.upsert_signatures(state, system, entries, character)

  def create_signature(:db, system, attrs, character),
    do: {Mapping.create_signature(system, attrs, character), :db}

  def create_signature(%State{} = state, system, attrs, character),
    do: Demo.create_signature(state, system, attrs, character)

  def update_signature(:db, signature, attrs, character),
    do: {Mapping.update_signature(signature, attrs, character), :db}

  def update_signature(%State{} = state, signature, attrs, character),
    do: Demo.update_signature(state, signature, attrs, character)

  def delete_signature(:db, signature, character),
    do: {Mapping.delete_signature(signature, character), :db}

  def delete_signature(%State{} = state, signature, character),
    do: Demo.delete_signature(state, signature, character)

  def sync_map_after_signature_change(:db, system, deleted),
    do: {Mapping.sync_map_after_signature_change(system, deleted), :db}

  def sync_map_after_signature_change(%State{} = state, system, deleted),
    do: Demo.sync_map_after_signature_change(state, system, deleted)

  def create_comment(:db, system, attrs, character),
    do: {Mapping.create_comment(system, attrs, character), :db}

  def create_comment(%State{} = state, system, attrs, character),
    do: Demo.create_comment(state, system, attrs, character)

  def update_comment(:db, comment, attrs, character),
    do: {Mapping.update_comment(comment, attrs, character), :db}

  def update_comment(%State{} = state, comment, attrs, character),
    do: Demo.update_comment(state, comment, attrs, character)

  def delete_comment(:db, comment, character),
    do: {Mapping.delete_comment(comment, character), :db}

  def delete_comment(%State{} = state, comment, character),
    do: Demo.delete_comment(state, comment, character)

  def move_comment(:db, comment, to_system_id, character),
    do: {Mapping.move_comment(comment, to_system_id, character), :db}

  def move_comment(%State{} = state, comment, to_system_id, character),
    do: Demo.move_comment(state, comment, to_system_id, character)

  def create_flare(:db, system, attrs, character, mask_id),
    do: {Mapping.create_flare(system, attrs, character, mask_id), :db}

  def create_flare(%State{} = state, system, attrs, character, mask_id),
    do: Demo.create_flare(state, system, attrs, character, mask_id)

  def delete_flare(:db, flare), do: {Mapping.delete_flare(flare), :db}
  def delete_flare(%State{} = state, flare), do: Demo.delete_flare(state, flare)

  def log_connection_jump(:db, conn, name, to_system_id, ship),
    do: {Mapping.log_connection_jump(conn, name, to_system_id, ship), :db}

  def log_connection_jump(%State{} = state, conn, name, to_system_id, ship),
    do: Demo.log_connection_jump(state, conn, name, to_system_id, ship)
end
