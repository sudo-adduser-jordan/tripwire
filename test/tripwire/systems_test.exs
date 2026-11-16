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
    assert Systems.display_class(%{sys_class: nil, security: -1.0}) == nil
    assert Systems.display_class(%{sys_class: nil, security: nil}) == nil
    assert Systems.display_class(%{}) == nil
  end

  test "color/1 mirrors official Tripwire class colors" do
    assert Systems.color(%{sys_class: "C3", security: nil}) == "#4399F0"
    assert Systems.color(%{sys_class: "C6", security: nil}) == "#4399F0"
    assert Systems.color(%{sys_class: nil, security: 0.9}) == "#50D25A"
    assert Systems.color(%{sys_class: nil, security: 0.2}) == "#F5B544"
    assert Systems.color(%{sys_class: nil, security: 0.0}) == "#FF4747"
    assert Systems.color(%{sys_class: nil, security: -1.0}) == "#6b7280"
  end

  test "classes/0 lists every assignable class" do
    assert Systems.classes() == ~w(C1 C2 C3 C4 C5 C6 HS LS NS)
  end

  test "attrs_from_esi/1 keeps name and security" do
    assert Systems.attrs_from_esi(%{"name" => "Jita", "security_status" => 0.9}) == %{
             name: "Jita",
             security: 0.9
           }
  end
end
