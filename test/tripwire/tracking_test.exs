defmodule Tripwire.TrackingTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.{Accounts, Mapping, Masks, Tracking}

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
    assert [%Mapping.MapSystem{}] = Mapping.list_systems(map.id)
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

    systems = Mapping.list_systems(map.id)
    assert length(systems) == 2
    assert length(Mapping.list_connections(map.id)) == 1
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
    {:ok, _conn, true} = Mapping.upsert_connection(map.id, from.id, to.id, %{hole_type: "B274"})
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
    Phoenix.PubSub.subscribe(Tripwire.PubSub, Tracking.map_topic(map.id))

    Tracking.apply_location_change(map, character.name, nil, 33_000_003, name_fetcher: nf())

    assert_receive {:system_changed, %{character: "Tracker"}}, 500

    map_id = map.id
    assert_receive {:map_updated, ^map_id}, 500
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
end
