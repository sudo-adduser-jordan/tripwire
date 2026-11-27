defmodule Ztripwire.TrackingTest do
  use Ztripwire.DataCase, async: false

  alias Ztripwire.{Accounts, Mapping, Masks, Tracking}

  setup do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 777, name: "Tracker"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Home", mask_id: mask.id})

    %{character: character, map: map}
  end

  defp name_fetcher(id), do: "SYS-#{id}"
  defp nf, do: &name_fetcher/1

  test "apply_location_change/4 adds the first system without a connection", %{
    map: map,
    character: character
  } do
    {:ok, %{system: system, connection: connection}} =
      Tracking.apply_location_change(map, character.name, nil, 30_000_014, name_fetcher: nf())

    assert system.name == "SYS-30000014"
    refute connection
    assert [%Mapping.MapSystem{}] = Mapping.list_systems(map.mask_id)
  end

  test "apply_location_change/4 links consecutive systems with a connection", %{
    map: map,
    character: character
  } do
    opts = [name_fetcher: nf()]

    {:ok, %{system: first}} =
      Tracking.apply_location_change(map, character.name, nil, 31_000_001, opts)

    {:ok, %{system: second, connection: connection}} =
      Tracking.apply_location_change(map, character.name, first, 32_000_002, opts)

    assert connection.from_system_id == first.id
    assert connection.to_system_id == second.id

    {:ok, %{connection: reversed}} =
      Tracking.apply_location_change(map, character.name, second, first.solar_system_id, opts)

    assert reversed.id == connection.id

    systems = Mapping.list_systems(map.mask_id)
    assert length(systems) == 2
    assert length(Mapping.list_connections(map.mask_id)) == 1
  end

  test "a jump converts the unknown placeholder for the scanned hole in place", %{
    map: map,
    character: character
  } do
    from = hole_system(map, 31_000_431, "C3")

    {:ok, _sig} =
      Mapping.create_signature(
        from,
        %{
          sig_id: "AAA-431",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    assert 1 = Mapping.ensure_unknown_nodes(from)
    [placeholder] = Enum.filter(Mapping.list_systems(map.mask_id), & &1.unknown)
    [connection] = Mapping.list_connections(map.mask_id)

    {:ok, %{system: system, connection: jumped}} =
      Tracking.apply_location_change(map, character.name, from, 32_000_431, name_fetcher: nf())

    assert system.id == placeholder.id
    refute system.unknown
    assert system.name == "SYS-32000431"
    assert system.solar_system_id == 32_000_431
    assert jumped.id == connection.id
    assert length(Mapping.list_systems(map.mask_id)) == 2
    assert length(Mapping.list_connections(map.mask_id)) == 1
  end

  defp hole_system(map, solar, class) do
    {:ok, system} =
      Mapping.add_system_to_map(map, %{
        solar_system_id: solar,
        name: "J#{solar}",
        sys_class: class
      })

    system
  end

  defp hole_signature(system, character, sig_id, code) do
    type_name = if code, do: "Unstable Wormhole (#{code})", else: "Unstable Wormhole"

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{sig_id: sig_id, kind: "signature", site_type: "wormhole", type_name: type_name},
        character
      )
  end

  test "a scanned hole leading to the jumped-to class labels the connection", %{
    map: map,
    character: character
  } do
    from = hole_system(map, 31_000_421, "C4")
    to = hole_system(map, 31_000_422, "C2")
    hole_signature(from, character, "ABC-101", "N766")

    {:ok, %{connection: connection}} =
      Tracking.apply_location_change(map, character.name, from, to.solar_system_id,
        name_fetcher: nf()
      )

    assert connection.hole_type == "N766"
  end

  test "a scan leading to another class does not label the connection", %{
    map: map,
    character: character
  } do
    from = hole_system(map, 31_000_423, "C4")
    to = hole_system(map, 31_000_424, "C2")
    hole_signature(from, character, "ABC-102", "P060")

    {:ok, %{connection: connection}} =
      Tracking.apply_location_change(map, character.name, from, to.solar_system_id,
        name_fetcher: nf()
      )

    assert connection.hole_type in [nil, ""]
  end

  test "several eligible scans leave the connection unlabeled", %{map: map, character: character} do
    from = hole_system(map, 31_000_425, "C4")
    to = hole_system(map, 31_000_426, "C2")
    hole_signature(from, character, "ABC-103", "N766")
    hole_signature(from, character, "ABC-104", "L005")

    {:ok, %{connection: connection}} =
      Tracking.apply_location_change(map, character.name, from, to.solar_system_id,
        name_fetcher: nf()
      )

    assert connection.hole_type in [nil, ""]
  end

  test "an existing hole type is not relabeled by a jump", %{map: map, character: character} do
    from = hole_system(map, 31_000_427, "C4")
    to = hole_system(map, 31_000_428, "C2")

    {:ok, _conn, true} =
      Mapping.upsert_connection(map.mask_id, from.id, to.id, %{hole_type: "B274"})

    hole_signature(from, character, "ABC-105", "N766")

    {:ok, %{connection: connection}} =
      Tracking.apply_location_change(map, character.name, from, to.solar_system_id,
        name_fetcher: nf()
      )

    assert connection.hole_type == "B274"
  end

  test "an untyped hole signature does not label the connection", %{
    map: map,
    character: character
  } do
    from = hole_system(map, 31_000_429, "C4")
    to = hole_system(map, 31_000_430, "C2")
    hole_signature(from, character, "ABC-106", nil)

    {:ok, %{connection: connection}} =
      Tracking.apply_location_change(map, character.name, from, to.solar_system_id,
        name_fetcher: nf()
      )

    assert connection.hole_type in [nil, ""]
  end

  test "new systems are placed on the map instead of the origin", %{
    map: map,
    character: character
  } do
    opts = [name_fetcher: nf()]

    {:ok, %{system: first}} =
      Tracking.apply_location_change(map, character.name, nil, 31_000_001, opts)

    assert {first.x, first.y} == {460.0, 300.0}

    {:ok, %{system: second}} =
      Tracking.apply_location_change(map, character.name, first, 32_000_002, opts)

    assert {second.x, second.y} != {460.0, 300.0}
    assert second.x >= 0.0 and second.x <= 920.0
    assert second.y >= 0.0 and second.y <= 650.0
  end

  test "broadcasts map updates to subscribers", %{map: map, character: character} do
    Phoenix.PubSub.subscribe(Ztripwire.PubSub, Tracking.mask_topic(map.mask_id))

    Tracking.apply_location_change(map, character.name, nil, 33_000_003, name_fetcher: nf())

    assert_receive {:system_changed, %{character: "Tracker"}}, 500

    mask_id = map.mask_id
    assert_receive {:map_updated, ^mask_id}, 500
  end

  test "apply_location_change/4 counts a system visit for the character", %{
    map: map,
    character: character
  } do
    assert Mapping.character_statistics(character).systems_visited == 0

    {:ok, %{system: first}} =
      Tracking.apply_location_change(map, character.name, nil, 34_000_001, name_fetcher: nf())

    {:ok, _} =
      Tracking.apply_location_change(map, character.name, first, 34_000_002, name_fetcher: nf())

    assert Mapping.character_statistics(character).systems_visited == 2
  end

  test "tracking?/1 reports whether a poller is registered" do
    assert Tracking.tracking?(%{eve_id: 999_999}) == false
    assert Tracking.tracking?(nil) == false
    assert Tracking.tracking?(%{}) == false
  end

  test "list_tracked_characters/0 and list_occupants/1 read demo presence", %{map: map} do
    on_exit(fn -> Tracking.stop_poller(%{eve_id: 9_900_001}) end)

    {:ok, character} = Accounts.upsert_character(%{eve_id: 9_900_001, name: "Presence"})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_001, name: "J150321"})

    {:ok, _} =
      Tracking.TestPresence.ensure_started(character, map, system,
        ship_name: "Cenotaph",
        ship_type_id: 58_716
      )

    assert Tracking.list_tracked_characters()
           |> Enum.any?(&(&1.name == "Presence" and &1.online == true))

    assert [
             %{
               character_name: "Presence",
               system_name: "J150321",
               ship_name: "Cenotaph",
               ship_type_id: 58_716
             }
           ] = Tracking.list_occupants(map.id)

    assert [%{system_id: system_id}] = Tracking.list_occupants(map.id)
    assert system_id == system.id
  end

  test "list_occupants/1 hides characters hidden on chain", %{map: map} do
    on_exit(fn -> Tracking.stop_poller(%{eve_id: 9_900_002}) end)

    {:ok, character} = Accounts.upsert_character(%{eve_id: 9_900_002, name: "Hider"})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_002, name: "J150322"})

    {:ok, _} = Tracking.TestPresence.ensure_started(character, map, system)
    {:ok, _} = Accounts.update_character(character, %{character_on_chain: false})

    assert [] = Tracking.list_occupants(map.id)
  end

  test "list_occupants/1 hides ships hidden on chain", %{map: map} do
    on_exit(fn -> Tracking.stop_poller(%{eve_id: 9_900_003}) end)

    {:ok, character} = Accounts.upsert_character(%{eve_id: 9_900_003, name: "Sneaky"})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_003, name: "J150323"})

    {:ok, _} =
      Tracking.TestPresence.ensure_started(character, map, system,
        ship_name: "Cenotaph",
        ship_type_id: 58_716
      )

    {:ok, _} = Accounts.update_character(character, %{ship_on_chain: false})

    assert [%{character_name: "Sneaky", ship_name: nil, ship_type_id: nil}] =
             Tracking.list_occupants(map.id)
  end
end
