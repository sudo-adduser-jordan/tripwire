defmodule Tripwire.MappingTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.{Mapping, Masks}

  setup do
    {:ok, mask} = Masks.ensure_demo_mask()
    {:ok, _map} = Mapping.ensure_demo_map(mask.id)
    %{mask: mask}
  end

  test "clamp_pan/3 keeps the viewport within the outermost nodes" do
    systems =
      for x <- [0.0, 500.0, 1000.0], y <- [100.0, 400.0] do
        %Mapping.MapSystem{x: x, y: y}
      end

    assert Mapping.clamp_pan(systems, 0.0, 0.0) == {0.0, 0.0}
    assert Mapping.clamp_pan(systems, -10_000.0, -10_000.0) == {-160.0, -172.0}
    assert Mapping.clamp_pan(systems, 10_000.0, 10_000.0) == {280.0, 60.0}
    assert Mapping.clamp_pan([], 10_000.0, -10_000.0) == {800.0, -800.0}

    small = [%Mapping.MapSystem{x: 100.0, y: 100.0}]
    assert Mapping.clamp_pan(small, 999.0, 999.0) == {-60.0, 60.0}
  end

  test "reset_demo_maps/1 clears custom content and restores the seed", %{mask: mask} do
    [map] = Mapping.list_maps_for_mask(mask.id)
    systems = Mapping.list_systems(map.id)
    assert length(systems) == 5

    {:ok, extra} =
      Mapping.add_system_to_map(map, %{solar_system_id: 99, name: "J999999"})

    {:ok, _conn, _new?} =
      Mapping.upsert_connection(map.id, hd(systems).id, extra.id, %{hole_type: "K162"})

    assert length(Mapping.list_systems(map.id)) == 6

    {:ok, _map} = Mapping.reset_demo_maps(mask.id)

    [fresh] = Mapping.list_maps_for_mask(mask.id)
    assert length(Mapping.list_systems(fresh.id)) == 5

    links = Mapping.list_connections(fresh.id)
    assert length(links) == 4

    assert Enum.map(links, & &1.hole_type) |> Enum.sort() == [
             "B274",
             "C247",
             "K162",
             "N968"
           ]

    assert Enum.map(links, & &1.mass_status) |> Enum.sort() == [
             "critical",
             "destab",
             "stable",
             "stable"
           ]

    assert Enum.map(links, & &1.time_status) |> Enum.sort() == [
             "eol",
             "stable",
             "stable",
             "stable"
           ]

    assert hd(Mapping.list_systems(fresh.id)).alias == "Home"

    [home | _] = Mapping.list_systems(fresh.id)

    assert [%{body: body}] = Mapping.list_comments(home.id)
    assert body =~ "**Bold**"
    assert body =~ "__underline__"
    assert body =~ "# Header 1"
    assert body =~ "[EVE University](https://wiki.eveuniversity.org)"
  end

  test "delete_map_full/1 removes systems, connections, and signatures", %{mask: mask} do
    [map] = Mapping.list_maps_for_mask(mask.id)
    [system | _] = Mapping.list_systems(map.id)
    assert Mapping.list_signatures(system.id) != []

    {:ok, deleted} = Mapping.delete_map_full(map)

    assert Mapping.list_maps_for_mask(mask.id) == []
    assert Mapping.list_systems(deleted.id) == []
    assert Mapping.list_connections(deleted.id) == []
    assert Mapping.list_signatures(system.id) == []
  end
end
