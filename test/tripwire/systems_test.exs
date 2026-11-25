defmodule Tripwire.SystemsTest do
  use ExUnit.Case, async: true

  alias Tripwire.Systems

  test "display_class/1 prefers an explicit sys_class" do
    assert Systems.display_class(%{sys_class: "C3", security: 0.9}) == "C3"
  end

  test "display_class/1 derives HS/LS/NS from security" do
    assert Systems.display_class(%{sys_class: nil, security: 0.9}) == "HS"
    assert Systems.display_class(%{sys_class: nil, security: 0.45}) == "HS"
    assert Systems.display_class(%{sys_class: nil, security: 0.2}) == "LS"
    assert Systems.display_class(%{sys_class: nil, security: 0.0}) == "NS"
  end

  test "display_class/1 is nil for wormhole-like systems without a class" do
    assert Systems.display_class(%{sys_class: nil, security: nil}) == nil
    assert Systems.display_class(%{}) == nil
  end

  test "display_class/1 treats negative security as nullsec" do
    assert Systems.display_class(%{sys_class: nil, security: -1.0}) == "NS"
  end

  test "display_class/1 falls back to W-space for unknown wormhole ids" do
    system = %{sys_class: nil, solar_system_id: 31_999_999, security: -1.0}

    assert Systems.display_class(system) == "W"
    assert Systems.color(system) == "#6b7280"
    assert Systems.security_label(system) == "W-Space"
  end

  test "display_class/1 reads the class data for known wormhole systems" do
    assert Systems.display_class(%{sys_class: nil, solar_system_id: 31_001_663}) == "C4"
    assert Systems.display_class(%{sys_class: nil, solar_system_id: 31_000_005}) == "Thera"
    assert Systems.display_class(%{sys_class: nil, solar_system_id: 31_002_580}) == "C13"
    assert Systems.display_class(%{sys_class: nil, solar_system_id: 30_000_021}) == "Trig"
    assert Systems.display_class(%{sys_class: nil, solar_system_id: 32_000_001}) == "Drifter"
  end

  test "display_effect/1 uses the stored effect" do
    assert Systems.display_effect(%{effect: "Pulsar", solar_system_id: 31_001_663}) == "Pulsar"
    assert Systems.display_effect(%{effect: nil, solar_system_id: 31_001_663}) == nil
    assert Systems.display_effect(%{effect: ""}) == nil
    assert Systems.display_effect(%{sys_class: "C1"}) == nil
  end

  test "effect_color/1 mirrors official Tripwire effect colors" do
    assert Systems.effect_color("Black Hole") == "#f0f0f0"
    assert Systems.effect_color("Cataclysmic Variable") == "#ffffbb"
    assert Systems.effect_color("Magnetar") == "#e06fdf"
    assert Systems.effect_color("Pulsar") == "#428bca"
    assert Systems.effect_color("Red Giant") == "#ff0000"
    assert Systems.effect_color("Wolf Rayet") == "#e28a0d"
    assert Systems.effect_color("Wolf-Rayet Star") == "#e28a0d"
    assert Systems.effect_color(nil) == nil
    assert Systems.effect_color("Unknown") == nil
  end

  test "system_statics/1 uses stored statics with a class fallback" do
    assert Systems.system_statics(%{statics: ["C247", "H900"]}) == ["C247", "H900"]
    assert Systems.system_statics(%{sys_class: "C1", statics: []}) == ["HS"]
    assert Systems.system_statics(%{sys_class: "C4", statics: []}) == []
  end

  test "display_class/1 keeps an explicit class on wormhole systems" do
    assert Systems.display_class(%{sys_class: "C5", solar_system_id: 31_001_663}) == "C5"
  end

  test "display_class/1 still treats k-space ids with negative security as nullsec" do
    assert Systems.display_class(%{sys_class: nil, solar_system_id: 30_000_301, security: -1.0}) ==
             "NS"
  end

  test "esi_resolvable?/1 keeps wormhole and abyssal systems out of ESI lookups" do
    assert Systems.esi_resolvable?(%{solar_system_id: 30_000_142})
    refute Systems.esi_resolvable?(%{solar_system_id: 31_001_663})
    refute Systems.esi_resolvable?(%{solar_system_id: 32_000_001})
  end

  test "color/1 mirrors official Tripwire class colors" do
    assert Systems.color(%{sys_class: "C3", security: nil}) == "#4399F0"
    assert Systems.color(%{sys_class: "C1", security: nil}) == "#4399F0"
    assert Systems.color(%{sys_class: "C4", security: nil}) == "#A855F7"
    assert Systems.color(%{sys_class: "C5", security: nil}) == "#A855F7"
    assert Systems.color(%{sys_class: "C6", security: nil}) == "#EC4899"
    assert Systems.color(%{sys_class: nil, security: 0.9}) == "#50D25A"
    assert Systems.color(%{sys_class: nil, security: 0.2}) == "#F5B544"
    assert Systems.color(%{sys_class: nil, security: 0.0}) == "#FF4747"
    assert Systems.color(%{sys_class: nil, security: -1.0}) == "#FF4747"
    assert Systems.color(%{sys_class: "Trig", security: nil}) == "#FF4747"
    assert Systems.color(%{sys_class: "Thera", security: nil}) == "#FF4747"
    assert Systems.color(%{sys_class: "C13", security: nil}) == "#6b7280"
    assert Systems.color(%{sys_class: "Drifter", security: nil}) == "#8B5CF6"
    assert Systems.color(%{sys_class: nil, security: nil}) == "#6b7280"
  end

  test "classes/0 lists every assignable class" do
    assert Systems.classes() ==
             ~w(C1 C2 C3 C4 C5 C6 C13 Thera Drifter HS LS NS Trig)
  end

  test "effects/0 lists the wormhole system effects" do
    assert Systems.effects() == [
             "Black Hole",
             "Cataclysmic Variable",
             "Magnetar",
             "Pulsar",
             "Red Giant",
             "Wolf Rayet"
           ]
  end

  test "statics/1 maps wormhole classes to static destinations" do
    assert Systems.statics("C1") == ["HS"]
    assert Systems.statics("C2") == []
    assert Systems.statics("C3") == []
    assert Systems.statics("C4") == []
    assert Systems.statics("C5") == []
    assert Systems.statics("C6") == ["C6"]
    assert Systems.statics("HS") == []
    assert Systems.statics(nil) == []
  end

  test "attrs_from_esi/1 keeps name and security" do
    assert Systems.attrs_from_esi(%{"name" => "Jita", "security_status" => 0.9}) == %{
             name: "Jita",
             security: 0.9
           }
  end

  test "sde_attrs/2 merges the dataset with the catalog security" do
    Systems.Catalog.put_systems([%{solar_system_id: 31_001_663, name: "J231710", security: 0.4}])
    on_exit(fn -> Systems.Catalog.clear() end)

    assert %{sys_class: "C4", effect: "Magnetar", statics: ["C247", "H900"], security: 0.4} =
             Systems.sde_attrs(31_001_663)

    assert Systems.sde_attrs(31_001_663, "J150321") == %{security: 0.4}
    assert Systems.sde_attrs(30_000_142) == %{}
  end
end
