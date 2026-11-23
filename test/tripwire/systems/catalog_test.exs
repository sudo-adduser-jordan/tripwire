defmodule Tripwire.Systems.CatalogTest do
  use ExUnit.Case, async: false

  alias Tripwire.Systems.Catalog

  setup do
    Catalog.clear()
    on_exit(fn -> Catalog.clear() end)
    :ok
  end

  test "search matches partial names with prefix matches first" do
    Catalog.put_systems([
      %{solar_system_id: 1, name: "Amarr", security: 1.0},
      %{solar_system_id: 2, name: "Rancer", security: 0.3},
      %{solar_system_id: 3, name: "Marran", security: -0.2}
    ])

    assert [%{name: "Marran"}, %{name: "Amarr"}] = Catalog.search("mar")
    assert [%{name: "Rancer", solar_system_id: 2}] = Catalog.search("ranc")
    assert Catalog.search("mar", 1) == [%{name: "Marran", solar_system_id: 3, security: -0.2}]
    assert Catalog.search("") == []
    assert Catalog.search("missing") == []
  end

  test "find matches exact names case-insensitively" do
    Catalog.put_systems([%{solar_system_id: 30_000_142, name: "Jita", security: 0.9}])

    assert %{solar_system_id: 30_000_142, name: "Jita"} = Catalog.find("jita")
    assert Catalog.find("Jit") == nil
    assert Catalog.find("") == nil
  end

  test "get looks a system up by solar id" do
    Catalog.put_systems([%{solar_system_id: 30_000_142, name: "Jita", security: 0.9}])

    assert %{solar_system_id: 30_000_142, name: "Jita", security: 0.9} = Catalog.get(30_000_142)
    assert Catalog.get(30_000_144) == nil
    assert Catalog.get(nil) == nil
  end

  test "an empty catalog returns no matches" do
    assert Catalog.search("jita") == []
    assert Catalog.find("Jita") == nil
    assert Catalog.get(30_000_142) == nil
  end
end
