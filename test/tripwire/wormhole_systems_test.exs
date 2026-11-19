defmodule Tripwire.WormholeSystemsTest do
  use ExUnit.Case, async: true

  alias Tripwire.Systems
  alias Tripwire.WormholeSystems

  test "get/1 returns the name, class, effect and statics for a known system" do
    assert WormholeSystems.get(31_001_663) == %{
             name: "J231710",
             class: "C4",
             effect: "Magnetar",
             statics: ["C247", "H900"]
           }
  end

  test "get/1 returns special classes and class-only systems" do
    assert %{name: "Thera", class: "Thera", statics: ["E587", "Q063", "V898"]} =
             WormholeSystems.get(31_000_005)

    assert %{name: "J000895", class: "C13", effect: "Wolf Rayet"} =
             WormholeSystems.get(31_002_580)

    assert %{class: "Trig"} = WormholeSystems.get(30_000_021)

    assert WormholeSystems.get(32_000_001) == %{
             name: "AD001",
             class: "Drifter",
             effect: nil,
             statics: []
           }
  end

  test "get/1 is nil outside the dataset" do
    assert WormholeSystems.get(30_000_142) == nil
    assert WormholeSystems.get(0) == nil
    assert WormholeSystems.get(nil) == nil
  end

  test "attrs/1 maps the data to map_systems fields" do
    assert WormholeSystems.attrs(31_001_663) == %{
             sys_class: "C4",
             effect: "Magnetar",
             statics: ["C247", "H900"]
           }

    assert WormholeSystems.attrs(32_000_001) == %{sys_class: "Drifter"}
    assert WormholeSystems.attrs(30_000_142) == %{}
  end

  test "attrs/2 keeps synthetic systems that reuse a real solar id" do
    assert WormholeSystems.attrs(31_001_663, "J231710") == %{
             sys_class: "C4",
             effect: "Magnetar",
             statics: ["C247", "H900"]
           }

    assert WormholeSystems.attrs(31_001_663, "J150321") == %{}
  end

  test "every entry carries a class the system editor understands" do
    classes = Systems.classes()

    assert Enum.all?(WormholeSystems.system_ids(), fn id ->
             WormholeSystems.get(id).class in classes
           end)
  end

  test "every effect matches the editor's effect list" do
    effects = Systems.effects()

    assert Enum.all?(WormholeSystems.system_ids(), fn id ->
             case WormholeSystems.get(id).effect do
               nil -> true
               effect -> effect in effects
             end
           end)
  end
end
