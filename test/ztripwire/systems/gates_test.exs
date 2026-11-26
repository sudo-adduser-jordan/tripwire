defmodule Ztripwire.Systems.GatesTest do
  use ExUnit.Case, async: false

  alias Ztripwire.Systems.Gates

  setup do
    Gates.clear()
    on_exit(fn -> Gates.clear() end)
    :ok
  end

  test "links are stored in both directions without duplicates" do
    Gates.put_stargates([{30_000_142, 30_000_144}, {30_000_144, 30_000_146}])

    assert Gates.neighbors(30_000_142) == [30_000_144]
    assert Gates.neighbors(30_000_144) == [30_000_142, 30_000_146]
    assert Gates.neighbors(30_000_146) == [30_000_144]
  end

  test "unknown systems and empty data have no neighbours" do
    assert Gates.neighbors(30_000_142) == []

    Gates.put_stargates([{30_000_142, 30_000_144}])

    assert Gates.neighbors(31_000_005) == []
    assert Gates.neighbors(nil) == []
    assert Gates.neighbors("30000142") == []
  end

  test "loaded reflects injected data" do
    refute Gates.loaded?()
    Gates.put_stargates([{1, 2}])
    assert Gates.loaded?()
    Gates.clear()
    refute Gates.loaded?()
  end
end
