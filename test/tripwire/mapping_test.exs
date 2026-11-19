defmodule Tripwire.MappingTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.{Accounts, Mapping, Masks}
  alias Tripwire.Mapping.SystemData
  alias Tripwire.Repo

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

  test "home_center/2 centers the home system horizontally" do
    assert Mapping.default_zoom() == 0.8
    assert Mapping.view_size() == {1250.0, 875.0}

    home = %Mapping.MapSystem{solar_system_id: 1, x: 460.0, y: 60.0}
    other = %Mapping.MapSystem{solar_system_id: 2, x: 1000.0, y: 220.0}
    map = %Mapping.Map{home_solar_system_id: 1}

    {node_w, _node_h} = Mapping.node_size()

    {x, y} = Mapping.home_center([home, other], map)
    assert_in_delta x, 460.0 + node_w / 2 - 625.0, 0.001
    assert y == 20.0

    {x, y} = Mapping.home_center([other, %{home | x: 0.0}], map)
    assert_in_delta x, node_w / 2 - 625.0, 0.001
    assert y == 20.0

    assert Mapping.home_center([home, other], %Mapping.Map{home_solar_system_id: 99}) ==
             {0, 20.0}

    assert Mapping.home_center([], nil) == {0, 0}
  end

  test "add_system_to_map/2 fills wormhole class, effect and statics", %{mask: mask} do
    [map | _] = Mapping.list_maps_for_mask(mask.id)

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_001_663, name: "J231710"})

    assert system.sys_class == "C4"
    assert system.effect == "Magnetar"
    assert system.statics == ["C247", "H900"]
  end

  test "add_system_to_map/2 keeps explicit system data", %{mask: mask} do
    [map | _] = Mapping.list_maps_for_mask(mask.id)

    {:ok, system} =
      Mapping.add_system_to_map(map, %{
        solar_system_id: 31_001_663,
        name: "J231710",
        sys_class: "C5",
        effect: "Pulsar",
        statics: ["ABC"]
      })

    assert system.sys_class == "C5"
    assert system.effect == "Pulsar"
    assert system.statics == ["ABC"]
  end

  test "add_system_to_map/2 leaves catalog systems untouched when asked", %{mask: mask} do
    [map | _] = Mapping.list_maps_for_mask(mask.id)

    {:ok, system} =
      Mapping.add_system_to_map(
        map,
        %{solar_system_id: 31_001_663, name: "J231710"},
        fill?: false
      )

    assert system.sys_class == nil
    assert system.effect == nil
    assert system.statics == []
  end

  test "add_system_to_map/2 ignores data for a mismatched name", %{mask: mask} do
    [map | _] = Mapping.list_maps_for_mask(mask.id)

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_001_663, name: "J150321"})

    assert system.sys_class == nil
    assert system.effect == nil
    assert system.statics == []
  end

  test "convert_unknown_system/2 fills wormhole system data", %{mask: mask} do
    [map | _] = Mapping.list_maps_for_mask(mask.id)
    {:ok, unknown} = Mapping.add_unknown_system(map)

    {:ok, system} =
      Mapping.convert_unknown_system(unknown, %{solar_system_id: 31_001_663, name: "J231710"})

    assert system.sys_class == "C4"
    assert system.effect == "Magnetar"
    assert system.statics == ["C247", "H900"]
  end

  test "SystemData.backfill/1 fills existing rows and keeps explicit values", %{mask: mask} do
    [map | _] = Mapping.list_maps_for_mask(mask.id)

    legacy =
      Repo.insert!(%Mapping.MapSystem{
        map_id: map.id,
        solar_system_id: 31_001_663,
        name: "J231710"
      })

    overridden =
      Repo.insert!(%Mapping.MapSystem{
        map_id: map.id,
        solar_system_id: 31_002_580,
        name: "J000895",
        sys_class: "C5",
        effect: "Pulsar"
      })

    assert SystemData.backfill() >= 1

    filled = Repo.get!(Mapping.MapSystem, legacy.id)
    assert filled.sys_class == "C4"
    assert filled.effect == "Magnetar"
    assert filled.statics == ["C247", "H900"]

    kept = Repo.get!(Mapping.MapSystem, overridden.id)
    assert kept.sys_class == "C5"
    assert kept.effect == "Pulsar"
    assert kept.statics == ["C008", "Q003"]

    SystemData.backfill(true)

    refreshed = Repo.get!(Mapping.MapSystem, overridden.id)
    assert refreshed.sys_class == "C13"
    assert refreshed.effect == "Wolf Rayet"
  end

  test "reset_demo_maps/1 clears custom content and restores the seed", %{mask: mask} do
    [map] = Mapping.list_maps_for_mask(mask.id)
    systems = Mapping.list_systems(map.id)
    assert length(systems) == 27

    {:ok, extra} =
      Mapping.add_system_to_map(map, %{solar_system_id: 99, name: "J999999"})

    {:ok, _conn, _new?} =
      Mapping.upsert_connection(map.id, hd(systems).id, extra.id, %{hole_type: "K162"})

    assert length(Mapping.list_systems(map.id)) == 28

    {:ok, _map} = Mapping.reset_demo_maps(mask.id)

    [fresh] = Mapping.list_maps_for_mask(mask.id)
    assert length(Mapping.list_systems(fresh.id)) == 27

    links = Mapping.list_connections(fresh.id)
    assert length(links) == 26

    assert Enum.map(links, & &1.hole_type) |> Enum.sort() == [
             "A641",
             "B041",
             "B274",
             "B274",
             "B274",
             "D364",
             "E175",
             "F216",
             "H900",
             "K162",
             "K162",
             "K329",
             "M555",
             "N062",
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

    assert Enum.frequencies(Enum.map(links, & &1.mass_status)) == %{
             "critical" => 1,
             "destab" => 2,
             "stable" => 23
           }

    assert Enum.frequencies(Enum.map(links, & &1.time_status)) == %{
             "critical" => 1,
             "stable" => 25
           }

    systems = Mapping.list_systems(fresh.id)

    assert Enum.map(systems, &Tripwire.Systems.display_class/1) |> Enum.sort() == [
             nil,
             nil,
             "C1",
             "C1",
             "C2",
             "C2",
             "C2",
             "C3",
             "C3",
             "C4",
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

  test "update_comment/3 rewrites the body and counts the edit", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_003, name: "Note Editor"})
    {:ok, map} = Mapping.create_map(%{name: "Edit", mask_id: mask.id})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_098, name: "J999998"})

    {:ok, comment} = Mapping.create_comment(system, %{body: "draft"}, character)

    assert {:ok, updated} = Mapping.update_comment(comment, %{body: "final"}, character)
    assert updated.body == "final"
    assert updated.map_system_id == system.id
    assert Mapping.character_statistics(character).comments_updated == 1
    assert {:error, _} = Mapping.update_comment(updated, %{body: ""}, character)
  end

  test "sync_connection_life/1 rewrites matching wormhole signature expiry" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_010, name: "Life Sync"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Life", mask_id: mask.id})

    {:ok, from} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_101, name: "J100101"})

    {:ok, to} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_102, name: "J100102"})

    {:ok, sig} =
      Mapping.create_signature(
        from,
        %{
          sig_id: "XYZ-999",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (B274)"
        },
        character
      )

    {:ok, conn, _new?} =
      Mapping.upsert_connection(map.id, from.id, to.id, %{hole_type: "B274"})

    {:ok, conn} = Mapping.update_connection(conn, %{time_status: "critical"})
    :ok = Mapping.sync_connection_life(conn)

    assert DateTime.diff(Mapping.get_signature!(sig.id).expires_at, DateTime.utc_now(), :second) in 14_390..14_400

    {:ok, conn} = Mapping.update_connection(conn, %{time_status: "<1h"})
    :ok = Mapping.sync_connection_life(conn)

    assert DateTime.diff(Mapping.get_signature!(sig.id).expires_at, DateTime.utc_now(), :second) in 3_590..3_600

    {:ok, conn} = Mapping.update_connection(conn, %{time_status: "stable"})
    :ok = Mapping.sync_connection_life(conn)

    assert DateTime.diff(
             Mapping.get_signature!(sig.id).expires_at,
             Mapping.get_signature!(sig.id).inserted_at,
             :second
           ) == 259_200
  end

  test "sync_connection_life/1 ignores signatures whose code does not match" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_011, name: "Life Noop"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Life", mask_id: mask.id})

    {:ok, from} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_111, name: "J100111"})

    {:ok, to} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_112, name: "J100112"})

    {:ok, sig} =
      Mapping.create_signature(
        from,
        %{
          sig_id: "XYZ-998",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (K162)"
        },
        character
      )

    {:ok, conn, _new?} =
      Mapping.upsert_connection(map.id, from.id, to.id, %{hole_type: "B274"})

    original = Mapping.get_signature!(sig.id).expires_at

    {:ok, conn} = Mapping.update_connection(conn, %{time_status: "critical"})
    :ok = Mapping.sync_connection_life(conn)

    assert Mapping.get_signature!(sig.id).expires_at == original
  end

  test "sync_signature_to_connections/4 adopts a blank or previous hole code" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_020, name: "Hole Sync"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Sync", mask_id: mask.id})

    {:ok, a} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_201, name: "J100201"})

    {:ok, b} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_202, name: "J100202"})

    {:ok, conn, _new?} = Mapping.upsert_connection(map.id, a.id, b.id, %{})
    assert conn.hole_type in [nil, ""]

    :ok = Mapping.sync_signature_to_connections(map, a, nil, "B274")
    assert Mapping.get_connection!(conn.id).hole_type == "B274"

    :ok = Mapping.sync_signature_to_connections(map, a, "B274", "N110")
    assert Mapping.get_connection!(conn.id).hole_type == "N110"

    {:ok, c} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_203, name: "J100203"})

    {:ok, other, _new?} =
      Mapping.upsert_connection(map.id, a.id, c.id, %{hole_type: "K162"})

    :ok = Mapping.sync_signature_to_connections(map, a, nil, "B274")
    assert Mapping.get_connection!(other.id).hole_type == "K162"
  end

  test "list_system_stats/1 returns activity keyed by system id" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_030, name: "Stat Map"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Stats", mask_id: mask.id})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_301, name: "J100301"})

    {:ok, _} = Mapping.upsert_system_stat(system, %{jumps: 12, kills: 3, visits: 0})

    stats = Mapping.list_system_stats(map.id)
    assert stats[system.id].jumps == 12
    assert stats[system.id].kills == 3
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

  test "sync_map_after_signature_change/2 drops connections whose wormhole signature is gone", %{
    mask: mask
  } do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_101, name: "Map Sync"})
    {:ok, map} = Mapping.create_map(%{name: "Sync", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_501, name: "J500001"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_502, name: "J500002"})
    {:ok, _c} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_503, name: "J500003"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "N770"})

    {:ok, _} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-001",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    deleted = Enum.filter(Mapping.list_signatures(a.id), &(&1.sig_id == "AAA-001"))
    Enum.each(deleted, &Mapping.delete_signature/1)

    assert {1, 0, 2} = Mapping.sync_map_after_signature_change(a, deleted)

    assert Mapping.connection_between(map.id, a.id, b.id) == nil
    assert length(Mapping.list_systems(map.id)) == 3
    assert Enum.map(Mapping.list_visible_systems(map.id), & &1.name) == ["J500003"]
  end

  test "sync_map_after_signature_change/2 hides chains detached from the home system", %{
    mask: mask
  } do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_106, name: "Detached"})
    {:ok, map} = Mapping.create_map(%{name: "Detached", mask_id: mask.id})

    {:ok, home} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_531, name: "J500031"})
    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_532, name: "J500032"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_533, name: "J500033"})

    {:ok, map} =
      Mapping.update_map(map, %{
        home_solar_system_id: home.solar_system_id,
        home_name: home.name
      })

    {:ok, _, _} = Mapping.upsert_connection(map.id, home.id, a.id, %{hole_type: "N770"})
    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "B274"})

    {:ok, sig} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-777",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, _deleted} = Mapping.delete_signature(sig, character)
    assert {1, 0, 2} = Mapping.sync_map_after_signature_change(a, [sig])

    assert Enum.map(Mapping.list_visible_systems(map.id), & &1.name) == ["J500031"]
    assert is_nil(Mapping.get_system!(home.id).hidden_at)

    {:ok, map} = Mapping.update_map(map, %{show_all: true})

    assert Enum.map(Mapping.list_chain_systems(map), & &1.name) |> Enum.sort() ==
             ["J500031", "J500032", "J500033"]
  end

  test "ensure_demo_map/1 configures the demo home chain root", %{mask: mask} do
    {:ok, map} = Mapping.ensure_demo_map(mask.id)

    assert map.home_name == "J150321"
    assert map.home_solar_system_id == 31_000_001

    home =
      Enum.find(
        Mapping.list_systems(map.id),
        &(&1.solar_system_id == map.home_solar_system_id)
      )

    assert home.alias == "Home"
  end

  test "delete_signature/2 removes the paired wormhole signature on the other system", %{
    mask: mask
  } do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_107, name: "Paired"})
    {:ok, map} = Mapping.create_map(%{name: "Paired", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_541, name: "J500041"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_542, name: "J500042"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "N770"})

    {:ok, sig_a} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-401",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, _sig_b} =
      Mapping.create_signature(
        b,
        %{
          sig_id: "BBB-402",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    assert {:ok, _} = Mapping.delete_signature(sig_a, character)
    assert Mapping.list_signatures(a.id) == []
    assert Mapping.list_signatures(b.id) == []
  end

  test "ensure_unknown_nodes/1 creates an empty node for an unmapped wormhole", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_108, name: "Unknowns"})
    {:ok, map} = Mapping.create_map(%{name: "Unknowns", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_551, name: "J500051"})

    {:ok, _sig} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-551",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    assert 1 = Mapping.ensure_unknown_nodes(a)
    assert 0 = Mapping.ensure_unknown_nodes(a)

    assert [%{id: a_id}, placeholder] = Mapping.list_systems(map.id)
    assert a_id == a.id
    assert placeholder.unknown
    assert placeholder.name == "unknown"
    assert placeholder.solar_system_id == 0
    assert is_nil(placeholder.sys_class)
    assert is_nil(Tripwire.Systems.display_class(placeholder))

    assert [conn] = Mapping.list_connections(map.id)
    assert conn.hole_type == "N770"
    assert conn.from_system_id in [a.id, placeholder.id]
    assert conn.to_system_id in [a.id, placeholder.id]
    refute conn.from_system_id == conn.to_system_id
  end

  test "delete_unlinked_unknowns/1 drops placeholders without a connection", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_109, name: "Cleanup"})
    {:ok, map} = Mapping.create_map(%{name: "Cleanup", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_552, name: "J500052"})

    {:ok, _sig} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-552",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    assert 1 = Mapping.ensure_unknown_nodes(a)
    [conn] = Mapping.list_connections(map.id)

    {:ok, _} = Mapping.delete_connection(conn)
    assert :ok = Mapping.delete_unlinked_unknowns(map.id)

    assert Enum.map(Mapping.list_systems(map.id), & &1.name) == ["J500052"]
  end

  test "auto_link_wormholes/2 reuses the placeholder connection for a real target", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_110, name: "Reuse"})
    {:ok, map} = Mapping.create_map(%{name: "Reuse", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_553, name: "J500053"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_554, name: "J500054"})

    {:ok, _sig_a} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-553",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    assert 1 = Mapping.ensure_unknown_nodes(a)
    [placeholder] = Enum.filter(Mapping.list_systems(map.id), & &1.unknown)

    {:ok, _sig_b} =
      Mapping.create_signature(
        b,
        %{
          sig_id: "BBB-554",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    Mapping.sync_map_after_signature_change(a, [])

    assert Mapping.get_system(placeholder.id) == nil

    assert %Mapping.MapConnection{hole_type: "N770"} =
             Mapping.connection_between(map.id, a.id, b.id)

    assert length(Mapping.list_connections(map.id)) == 1
  end

  test "tree_layout/5 roots detached chains at level 0 beside the home tree" do
    systems = Enum.map(1..6, &%Mapping.MapSystem{id: &1})

    connections = [
      {nil, %Mapping.MapSystem{id: 1}, %Mapping.MapSystem{id: 2}},
      {nil, %Mapping.MapSystem{id: 3}, %Mapping.MapSystem{id: 4}}
    ]

    positions = Mapping.tree_layout(systems, connections, "down", 1.0, root_id: 1)

    assert positions[1].y == 60.0
    assert positions[2].y == 220.0
    assert positions[3].y == 60.0
    assert positions[4].y == 220.0
    assert positions[5].y == 60.0
    assert positions[6].y == 60.0

    xs = Enum.map([1, 3, 5, 6], &positions[&1].x)
    assert xs == Enum.uniq(xs)
    assert positions[3].x > positions[1].x
  end

  test "list_chain_systems/1 includes hidden systems only when the map shows all", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_105, name: "Show All"})
    {:ok, map} = Mapping.create_map(%{name: "Show All", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_521, name: "J500021"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_522, name: "J500022"})
    {:ok, c} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_523, name: "J500023"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "N770"})

    {:ok, sig} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-003",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, _deleted} = Mapping.delete_signature(sig, character)
    assert {1, 0, 2} = Mapping.sync_map_after_signature_change(a, [sig])
    assert Enum.map(Mapping.list_visible_systems(map.id), & &1.name) == ["J500023"]
    assert Enum.map(Mapping.list_chain_systems(map), & &1.name) == ["J500023"]

    {:ok, map} = Mapping.update_map(map, %{show_all: true})

    assert Enum.map(Mapping.list_chain_systems(map), & &1.name) |> Enum.sort() ==
             ["J500021", "J500022", "J500023"]

    assert c.id in Enum.map(Mapping.list_chain_systems(map), & &1.id)
  end

  test "cycle_connection_ids/2 returns the edge that closes a loop" do
    connections = [
      {%Mapping.MapConnection{id: 1}, %Mapping.MapSystem{id: 10}, %Mapping.MapSystem{id: 11}},
      {%Mapping.MapConnection{id: 2}, %Mapping.MapSystem{id: 11}, %Mapping.MapSystem{id: 12}},
      {%Mapping.MapConnection{id: 3}, %Mapping.MapSystem{id: 10}, %Mapping.MapSystem{id: 12}}
    ]

    assert Mapping.cycle_connection_ids(connections, 10) == MapSet.new([3])
    assert Mapping.cycle_connection_ids(connections) == MapSet.new([3])
    assert Mapping.cycle_connection_ids(Enum.take(connections, 2), 10) == MapSet.new()
  end

  test "upsert_connection/4 unhides systems that regain a connection", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_104, name: "Reveal"})
    {:ok, map} = Mapping.create_map(%{name: "Reveal", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_511, name: "J500011"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_512, name: "J500012"})
    {:ok, c} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_513, name: "J500013"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "N770"})

    {:ok, sig} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "AAA-002",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, _deleted} = Mapping.delete_signature(sig, character)
    {1, 0, 2} = Mapping.sync_map_after_signature_change(a, [sig])

    {:ok, _, true} = Mapping.upsert_connection(map.id, a.id, c.id, %{})

    names = Mapping.list_visible_systems(map.id) |> Enum.map(& &1.name) |> Enum.sort()
    assert names == ["J500011", "J500013"]
  end

  test "auto_link_wormholes/2 links by signature id, unique code, and skips ambiguous codes", %{
    mask: mask
  } do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_102, name: "Auto Link"})
    {:ok, map} = Mapping.create_map(%{name: "Link", mask_id: mask.id})

    {:ok, p} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_601, name: "J600001"})
    {:ok, q} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_602, name: "J600002"})
    {:ok, r} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_603, name: "J600003"})
    {:ok, _s} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_604, name: "J600004"})

    {:ok, _} =
      Mapping.create_signature(
        p,
        %{
          sig_id: "UNI-001",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (Z123)"
        },
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        q,
        %{
          sig_id: "OTH-009",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (Z123)"
        },
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        p,
        %{
          sig_id: "AMB-001",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (Y987)"
        },
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        q,
        %{
          sig_id: "AMB-002",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (Y987)"
        },
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        r,
        %{
          sig_id: "AMB-003",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (Y987)"
        },
        character
      )

    assert {0, 1, 0} = Mapping.sync_map_after_signature_change(p, [])

    assert %Mapping.MapConnection{hole_type: "Z123"} =
             Mapping.connection_between(map.id, p.id, q.id)

    assert Mapping.connection_between(map.id, p.id, r.id) == nil
  end

  test "prune_expired_signatures/1 drops connections backed by expired wormholes", %{mask: mask} do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 99_103, name: "Expiry"})
    {:ok, map} = Mapping.create_map(%{name: "Expiry", mask_id: mask.id})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_701, name: "J700001"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 31_000_702, name: "J700002"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "E175"})

    {:ok, sig} =
      Mapping.create_signature(
        a,
        %{
          sig_id: "EXP-001",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (E175)"
        },
        character
      )

    past = DateTime.add(DateTime.utc_now(), -3600, :second)
    {:ok, _} = Mapping.update_signature(sig, %{expires_at: past}, character)

    assert {:ok, 1} = Mapping.prune_expired_signatures()

    assert Mapping.connection_between(map.id, a.id, b.id) == nil
    assert Mapping.list_visible_systems(map.id) == []
    assert length(Mapping.list_systems(map.id)) == 2
  end
end
