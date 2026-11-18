defmodule Tripwire.MappingTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.{Accounts, Mapping, Masks}

  setup do
    {:ok, mask} = Masks.ensure_demo_mask()
    {:ok, _map} = Mapping.ensure_demo_map(mask.id)
    %{mask: mask}
  end

  test "clamp_pan/3 only clamps to the top edge" do
    systems =
      for x <- [0.0, 500.0, 1000.0], y <- [100.0, 400.0] do
        %Mapping.MapSystem{x: x, y: y}
      end

    assert Mapping.clamp_pan(systems, 0.0, 0.0) == {0.0, 60.0}
    assert Mapping.clamp_pan(systems, -10_000.0, -10_000.0) == {-10_000.0, 60.0}
    assert Mapping.clamp_pan(systems, 10_000.0, 10_000.0) == {10_000.0, 10_000.0}
    assert Mapping.clamp_pan([], 10_000.0, -10_000.0) == {10_000.0, -10_000.0}

    small = [%Mapping.MapSystem{x: 100.0, y: 100.0}]
    assert Mapping.clamp_pan(small, 999.0, 999.0) == {999.0, 999.0}
  end

  test "reset_demo_maps/1 clears custom content and restores the seed", %{mask: mask} do
    [map] = Mapping.list_maps_for_mask(mask.id)
    systems = Mapping.list_systems(map.id)
    assert length(systems) == 23

    {:ok, extra} =
      Mapping.add_system_to_map(map, %{solar_system_id: 99, name: "J999999"})

    {:ok, _conn, _new?} =
      Mapping.upsert_connection(map.id, hd(systems).id, extra.id, %{hole_type: "K162"})

    assert length(Mapping.list_systems(map.id)) == 24

    {:ok, _map} = Mapping.reset_demo_maps(mask.id)

    [fresh] = Mapping.list_maps_for_mask(mask.id)
    assert length(Mapping.list_systems(fresh.id)) == 23

    links = Mapping.list_connections(fresh.id)
    assert length(links) == 22

    assert Enum.map(links, & &1.hole_type) |> Enum.sort() == [
             "A641",
             "B041",
             "B274",
             "B274",
             "D364",
             "E175",
             "F216",
             "H900",
             "K329",
             "M555",
             "N062",
             "N110",
             "N290",
             "N766",
             "N770",
             "O128",
             "O477",
             "Q317",
             "R081",
             "V753",
             "Y683",
             "Y790"
           ]

    assert Enum.map(links, & &1.mass_status) |> Enum.sort() == [
             "critical",
             "destab",
             "destab",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable"
           ]

    assert Enum.map(links, & &1.time_status) |> Enum.sort() == [
             "eol",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable",
             "stable"
           ]

    systems = Mapping.list_systems(fresh.id)

    assert Enum.map(systems, &Tripwire.Systems.display_class/1) |> Enum.sort() == [
             "C1",
             "C1",
             "C2",
             "C2",
             "C2",
             "C3",
             "C4",
             "C4",
             "C4",
             "C4",
             "C5",
             "C5",
             "C5",
             "C5",
             "C6",
             "C6",
             "HS",
             "HS",
             "HS",
             "HS",
             "LS",
             "NS",
             "Trig"
           ]

    assert hd(systems).alias == "Home"

    [home | _] = Mapping.list_systems(fresh.id)

    jita = Enum.find(Mapping.list_systems(fresh.id), &(&1.name == "Jita"))

    assert [%{body: first_body}, %{body: second_body}, %{body: third_body}] =
             Mapping.list_comments(jita.id)

    assert first_body =~ "# Shortcuts"
    assert first_body =~ "<kbd>Ctrl</kbd>"
    assert second_body =~ "**Bold**"
    assert third_body =~ "TUV-679"
    assert home.id != jita.id
  end

  test "character stat counters track signature and comment lifecycles", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_001, name: "Stat Tracker"})
    {:ok, map} = Mapping.create_map(%{name: "Stats", mask_id: mask.id})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_099, name: "J999999"})

    {:ok, sig} =
      Mapping.create_signature(
        system,
        %{sig_id: "AAA-111", kind: "signature", site_type: "wormhole"},
        character
      )

    {:ok, _} = Mapping.update_signature(sig, %{type_name: "Unstable Wormhole (K162)"}, character)

    {:ok, plain} =
      Mapping.create_signature(
        system,
        %{sig_id: "BBB-222", kind: "signature", site_type: "combat"},
        character
      )

    {:ok, _} = Mapping.delete_signature(sig, character)
    {:ok, _} = Mapping.delete_signature(plain, character)

    {:ok, comment} = Mapping.create_comment(system, %{body: "hello"}, character)
    {:ok, _} = Mapping.move_comment(comment, system.id, character)
    {:ok, _} = Mapping.delete_comment(Mapping.get_comment!(comment.id), character)

    stats = Mapping.character_statistics(character)

    assert stats.signatures_added == 2
    assert stats.signatures_updated == 1
    assert stats.signatures_deleted == 2
    assert stats.wormholes_added == 1
    assert stats.wormholes_updated == 1
    assert stats.wormholes_deleted == 1
    assert stats.comments_added == 1
    assert stats.comments_updated == 1
    assert stats.comments_deleted == 1
  end

  test "upsert_signatures counts pasted signatures and wormholes", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_002, name: "Paste Tracker"})
    {:ok, map} = Mapping.create_map(%{name: "Paste", mask_id: mask.id})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_098, name: "J999998"})

    entries = [
      %{
        sig_id: "CCC-333",
        kind: :signature,
        category: :wormhole,
        name: nil,
        wormhole_type: "K162"
      },
      %{sig_id: "DDD-444", kind: :signature, category: :combat, name: "Site", wormhole_type: nil}
    ]

    assert {2, 0} = Mapping.upsert_signatures(system, entries, character)
    assert {0, 2} = Mapping.upsert_signatures(system, entries, character)

    stats = Mapping.character_statistics(character)

    assert stats.signatures_added == 2
    assert stats.signatures_updated == 2
    assert stats.wormholes_added == 1
    assert stats.wormholes_updated == 1
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
