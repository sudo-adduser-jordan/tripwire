defmodule Tripwire.Sde.SyncTest do
  use ExUnit.Case, async: true

  alias Tripwire.Sde.Sync

  defp named(id, name), do: %{"_key" => id, "name" => %{"en" => name}}

  describe "parse_regions/1" do
    test "keeps named regions and skips entries without an id or name" do
      rows =
        Sync.parse_regions([
          Map.put(named(10_000_002, "The Forge"), "factionID", 500_001),
          %{"_key" => 1},
          %{"name" => %{"en" => "Nameless"}}
        ])

      assert rows == [%{region_id: 10_000_002, name: "The Forge", faction_id: 500_001}]
    end
  end

  describe "parse_constellations/1" do
    test "carries the region, faction and wormhole class" do
      rows =
        Sync.parse_constellations([
          named(20_000_020, "Kimotoro")
          |> Map.merge(%{
            "regionID" => 10_000_002,
            "factionID" => 500_001,
            "wormholeClassID" => 12
          })
        ])

      assert [
               %{
                 constellation_id: 20_000_020,
                 region_id: 10_000_002,
                 name: "Kimotoro",
                 faction_id: 500_001,
                 wormhole_class_id: 12
               }
             ] = rows
    end
  end

  describe "parse_gates/1" do
    test "stores both directions without duplicates" do
      rows =
        Sync.parse_gates([
          %{"solarSystemID" => 1, "destination" => %{"solarSystemID" => 2}},
          %{"solarSystemID" => 2, "destination" => %{"solarSystemID" => 1}},
          %{"solarSystemID" => 2, "destination" => %{"solarSystemID" => 3}},
          %{"solarSystemID" => 4, "destination" => %{"solarSystemID" => 4}}
        ])

      assert rows == [
               %{from_id: 1, to_id: 2},
               %{from_id: 2, to_id: 1},
               %{from_id: 2, to_id: 3},
               %{from_id: 3, to_id: 2}
             ]
    end
  end

  describe "parse_types/1" do
    test "keeps referenced types and ships, with group and category names" do
      groups = %{
        25 => %{name: "Frigate", category_id: 6},
        995 => %{name: "Effect Beacon", category_id: 53},
        88 => %{name: "Other", category_id: 7}
      }

      categories = %{6 => "Ship", 53 => "Effects", 7 => "Module"}

      rows =
        Sync.parse_types(
          [
            named(582, "Bantam") |> Map.put("groupID", 25),
            named(30574, "Magnetar") |> Map.put("groupID", 995),
            named(1201, "Armor Plating") |> Map.put("groupID", 88)
          ],
          groups,
          categories,
          MapSet.new([30574])
        )

      assert [
               %{
                 type_id: 582,
                 name: "Bantam",
                 group_id: 25,
                 group_name: "Frigate",
                 category_id: 6,
                 category_name: "Ship"
               },
               %{
                 type_id: 30574,
                 name: "Magnetar",
                 group_id: 995,
                 group_name: "Effect Beacon",
                 category_id: 53,
                 category_name: "Effects"
               }
             ] = rows
    end
  end

  describe "parse_stations/1" do
    test "resolves owner, operation, type and services" do
      operations = %{26 => %{name: "Assembly Plant", services: [25, 3]}}
      services = %{3 => "Repair", 25 => "Market"}
      corporations = %{1_000_002 => "Caldari Navy"}
      type_names = %{1531 => "Caldari Control Tower"}

      rows =
        Sync.parse_stations(
          [
            %{
              "_key" => 60_000_004,
              "solarSystemID" => 30_000_142,
              "ownerID" => 1_000_002,
              "operationID" => 26,
              "typeID" => 1531
            },
            %{"_key" => 60_000_005, "solarSystemID" => nil}
          ],
          operations,
          services,
          corporations,
          type_names
        )

      assert [
               %{
                 station_id: 60_000_004,
                 solar_system_id: 30_000_142,
                 owner_id: 1_000_002,
                 owner_name: "Caldari Navy",
                 operation: "Assembly Plant",
                 type_id: 1531,
                 type_name: "Caldari Control Tower",
                 services: ["Market", "Repair"]
               }
             ] = rows
    end
  end

  describe "parse_systems/2" do
    test "merges geography, star, counts, effect and flags" do
      context = %{
        stars: %{
          30_000_142 => %{
            spectral_class: "G2 V",
            temperature: 5705.0,
            luminosity: 0.62,
            radius: 1.0
          }
        },
        suns: %{31_000_001 => %{type_id: 30574, beacon_id: nil}},
        effect_names: %{30574 => "Magnetar"},
        planet_counts: %{30_000_142 => 9},
        moon_counts: %{30_000_142 => 70},
        belt_counts: %{30_000_142 => 5},
        station_counts: %{30_000_142 => 3}
      }

      rows =
        Sync.parse_systems(
          [
            named(30_000_142, "Jita")
            |> Map.merge(%{
              "securityStatus" => 0.946,
              "securityClass" => "B",
              "regionID" => 10_000_002,
              "constellationID" => 20_000_020,
              "hub" => true,
              "position2D" => %{"x" => 1.0, "y" => 2.0}
            }),
            named(31_000_001, "J100001") |> Map.put("securityStatus", -1.0),
            %{"_key" => 3}
          ],
          context
        )

      assert [
               %{
                 solar_system_id: 30_000_142,
                 name: "Jita",
                 security: 0.946,
                 security_class: "B",
                 region_id: 10_000_002,
                 constellation_id: 20_000_020,
                 star_class: "G2 V",
                 temperature: 5705.0,
                 luminosity: 0.62,
                 planet_count: 9,
                 moon_count: 70,
                 belt_count: 5,
                 station_count: 3,
                 effect: nil,
                 hub: true,
                 border: false,
                 position_x: 1.0,
                 position_y: 2.0
               },
               %{
                 solar_system_id: 31_000_001,
                 name: "J100001",
                 effect: "Magnetar",
                 planet_count: 0,
                 station_count: 0
               }
             ] = rows
    end
  end

  describe "system_counts/1" do
    test "counts entries per solar system and skips malformed rows" do
      assert Sync.system_counts([
               %{"solarSystemID" => 1},
               %{"solarSystemID" => 1},
               %{"solarSystemID" => 2},
               %{}
             ]) == %{1 => 2, 2 => 1}
    end
  end
end
