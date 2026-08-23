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

  test "broadcasts map updates to subscribers", %{map: map, character: character} do
    Phoenix.PubSub.subscribe(Tripwire.PubSub, Tracking.map_topic(map.id))

    Tracking.apply_location_change(map, character.name, nil, 33_000_003, name_fetcher: nf())

    assert_receive {:system_changed, %{character: "Tracker"}}, 500

    map_id = map.id
    assert_receive {:map_updated, ^map_id}, 500
  end
end
