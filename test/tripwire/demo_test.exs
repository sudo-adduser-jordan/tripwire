defmodule Tripwire.DemoTest do
  use ExUnit.Case, async: true

  alias Tripwire.Demo
  alias Tripwire.Demo.Fixture
  alias Tripwire.Layouts

  test "the fixture builds the demo chain in memory" do
    state = Demo.fixture()
    map = hd(state.maps)

    assert state.character.name == "Demo User"
    assert state.mask.kind == "demo"
    assert map.home_solar_system_id == 31_000_001
    assert map.home_name == "J150321"

    systems = Demo.list_systems(state, map.id)
    assert length(systems) == 27
    assert length(Demo.list_chain_systems(state, map, false)) == 27
    assert Enum.count(systems, & &1.unknown) == 2

    jita = Enum.find(systems, &(&1.name == "Jita"))
    notes = Demo.list_comments(state, jita.id)
    assert Enum.any?(notes, &(&1.body == Fixture.paste()))
    assert Enum.map(notes, & &1.body) |> Enum.any?(&String.starts_with?(&1, "# Shortcuts"))
  end

  test "the fixture loops one hole between the C6 and Amarr" do
    state = Demo.fixture()
    map = hd(state.maps)
    connections = Demo.list_connections_with_endpoints(state, map.id)

    assert length(connections) == 27

    cycle = Tripwire.Mapping.cycle_connection_ids(connections)
    assert MapSet.size(cycle) == 1

    {_conn, from, to} =
      Enum.find(connections, fn {conn, _from, _to} -> MapSet.member?(cycle, conn.id) end)

    assert Enum.sort([from.name, to.name]) == ["Amarr", "J150325"]
  end

  test "the loop does not flatten the Jita C1 exit" do
    state = Demo.fixture()
    map = hd(state.maps)
    systems = Demo.list_chain_systems(state, map, false)
    connections = Demo.list_connections_with_endpoints(state, map.id)
    home = Enum.find(systems, &(&1.alias == "Home"))

    positions =
      Tripwire.Mapping.tree_layout(systems, connections, "down", 1.0, root_id: home.id)

    jita = Enum.find(systems, &(&1.name == "Jita"))
    c1 = Enum.find(systems, &(&1.name == "J150326"))

    assert positions[jita.id].y > positions[c1.id].y
  end

  test "demo occupants stack at home and the trade hubs and spread through the chain" do
    state = Demo.fixture()
    map = hd(state.maps)
    occupants = Demo.occupants(state, map.id)

    assert length(occupants) == 11

    per_system = Enum.frequencies_by(occupants, & &1.system_name)
    assert per_system["J150321"] == 4
    assert per_system["Jita"] == 2
    assert per_system["Amarr"] == 1
    assert per_system["Dodixie"] == 1
    assert per_system["Rens"] == 1
    assert per_system["J150323"] == 1
    assert per_system["J150334"] == 1

    assert Enum.any?(
             occupants,
             &(&1.character_name == "Demo User" and &1.ship_name == "Cenotaph")
           )

    assert Enum.any?(
             occupants,
             &(&1.character_name == "Vexa Dural" and &1.ship_type_name == "Loki")
           )

    assert Enum.all?(occupants, &(&1.system_id && &1.solar_system_id))
  end

  test "demo mates follow tracking but not the demo character visibility" do
    state = Demo.fixture()
    map = hd(state.maps)

    {{:ok, _}, state} =
      Demo.update_character(state, state.character.id, fn _ -> %{character_on_chain: false} end)

    occupants = Demo.occupants(state, map.id)
    assert length(occupants) == 10
    refute Enum.any?(occupants, &(&1.character_name == "Demo User"))

    {_result, state} = Demo.set_tracking(state, false)
    assert Demo.occupants(state, map.id) == []

    {_result, state} = Demo.set_tracking(state, true)
    assert Demo.occupants(state, map.id + 1) == []
  end

  test "paste sync updates signatures and hides detached branches" do
    state = Demo.fixture()
    map = hd(state.maps)
    system = Enum.find(state.systems, &(&1.name == "Jita"))
    entries = Tripwire.Signatures.parse_paste(Fixture.paste())

    {{added, _updated}, state} =
      Demo.upsert_signatures(state, system, entries, state.character)

    assert added > 0

    {{_dropped, _linked, _hidden}, state} =
      Demo.sync_map_after_signature_change(state, system, [])

    assert length(Demo.list_chain_systems(state, map, false)) == 27
  end

  test "dropping a leaf wormhole hides its detached branch" do
    state = Demo.fixture()
    map = hd(state.maps)
    signature = Enum.find(state.signatures, &(&1.sig_id == "TUV-680"))
    system = Demo.get_system(state, signature.map_system_id)

    {{:ok, _}, state} = Demo.delete_signature(state, signature, state.character)

    {{dropped, _linked, hidden}, state} =
      Demo.sync_map_after_signature_change(state, system, [signature])

    assert dropped == 1
    assert hidden > 0
    assert length(Demo.list_chain_systems(state, map, false)) < 27
  end

  test "deleting a wormhole signature removes its pair" do
    state = Demo.fixture()
    signature = Enum.find(state.signatures, &(&1.sig_id == "ABC-123"))

    {{:ok, _}, state} = Demo.delete_signature(state, signature, state.character)

    refute Enum.any?(state.signatures, &(&1.sig_id == "ABC-123"))
    refute Enum.any?(state.signatures, &(&1.sig_id == "JKL-012"))
  end

  test "deleting the only map reseeds it" do
    state = Demo.fixture()
    map = hd(state.maps)

    {{:ok, _}, state} = Demo.delete_map_full(state, map)
    assert state.maps == []

    state = Demo.reset_map(state)
    [fresh] = state.maps

    assert fresh.name == "Demo"
    assert length(Demo.list_systems(state, fresh.id)) == 27
  end

  test "saved demo layouts apply and delete" do
    state = Demo.fixture()
    widgets = Layouts.default_widgets()

    {{:ok, layout}, state} = Demo.save_layout(state, "Mine", widgets)
    assert Demo.get_layout(state, "saved:#{layout.id}").name == "Mine"

    {{:ok, _}, state} = Demo.delete_layout(state, "saved:#{layout.id}")
    assert Demo.get_layout(state, "saved:#{layout.id}") == nil

    {{:error, :core}, state} = Demo.delete_layout(state, "core:default")
    assert Demo.get_layout(state, "core:default")
  end

  test "demo edits stay in the state" do
    state = Demo.fixture()
    map = hd(state.maps)
    system = Enum.find(state.systems, &(&1.name == "Jita"))

    {{:ok, _}, state} = Demo.update_system(state, system, %{favorite: true})
    assert Demo.get_system(state, system.id).favorite

    {{:ok, comment}, state} =
      Demo.create_comment(state, system, %{body: "new note"}, state.character)

    assert Enum.any?(Demo.list_comments(state, system.id), &(&1.id == comment.id))

    {{:ok, _}, state} = Demo.update_map(state, map, %{name: "Renamed"})
    assert Demo.get_map(state, map.id).name == "Renamed"
  end

  test "demo converts an unknown node and fills its system data" do
    state = Demo.fixture()
    unknown = Enum.find(state.systems, & &1.unknown)

    {{:ok, converted}, state} =
      Demo.update_system(state, unknown, %{
        solar_system_id: 31_001_663,
        name: "J231710",
        sys_class: nil
      })

    refute converted.unknown
    assert Demo.get_system(state, unknown.id).unknown == false
    assert converted.sys_class == "C4"
    assert converted.effect == "Magnetar"
    assert converted.statics == ["C247", "H900"]
    assert length(Demo.list_systems(state, unknown.map_id)) == 27
  end
end
