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
    assert Systems.color(%{sys_class: nil, security: nil}) == "#6b7280"
  end

  test "classes/0 lists every assignable class" do
    assert Systems.classes() == ~w(C1 C2 C3 C4 C5 C6 HS LS NS Trig)
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
end
