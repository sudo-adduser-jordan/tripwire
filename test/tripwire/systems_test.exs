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

  test "attrs_from_esi/1 keeps name and security" do
    assert Systems.attrs_from_esi(%{"name" => "Jita", "security_status" => 0.9}) == %{
             name: "Jita",
             security: 0.9
           }
  end
end
