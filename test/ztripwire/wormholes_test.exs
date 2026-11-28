defmodule Ztripwire.WormholesTest do
  use ExUnit.Case, async: true

  alias Ztripwire.Wormholes

  test "get/1 returns the raw data for a known type" do
    assert %{"from" => _, "leadsTo" => _, "mass" => _, "jump" => _} = Wormholes.get("B274")
    assert Wormholes.get("nope") == nil
    assert Wormholes.get(nil) == nil
  end

  test "from/1 and leads_to/1 normalise to short class labels" do
    assert Wormholes.from("B274") == ["C2"]
    assert Wormholes.leads_to("B274") == ["HS"]
  end

  test "mass/1 and jump/1 return integers" do
    assert is_integer(Wormholes.mass("B274"))
    assert is_integer(Wormholes.jump("B274"))
    assert Wormholes.mass("nope") == nil
    assert Wormholes.jump("nope") == nil
  end

  test "render/1 matches official Tripwire formatting" do
    assert Wormholes.render("B274") =~ "B274:"
    assert Wormholes.render("B274") =~ "➔"
    assert Wormholes.render("B274") =~ "kt"
  end

  test "render_mass/1 truncates to whole kilotons" do
    assert Wormholes.render_mass(375_000_000) == "375kt"
    assert Wormholes.render_mass(5_000_000) == "5kt"
    assert Wormholes.render_mass(nil) == nil
  end

  test "likely_wormhole/2 infers size from system classes" do
    assert Wormholes.likely_wormhole("C1", "C2") == "MED"
    assert Wormholes.likely_wormhole("C5", "C6") == "XLG"
    assert Wormholes.likely_wormhole("C3", "C4") == "LRG"
    assert Wormholes.likely_wormhole("HS", "C1") == "MED"
    assert Wormholes.likely_wormhole("C5", "HS") == "XLG"
  end

  test "eligible_types/2 returns matching types in each direction" do
    result = Wormholes.eligible_types("C2", "HS")

    assert "B274" in result.from
    refute Enum.empty?(result.from)
  end

  test "eligible_types/2 accepts system endpoints and specific destinations" do
    c3 = %{solar_system_id: 31_001_031, name: "J123405", sys_class: "C3"}
    turnur = %{solar_system_id: 30_002_086, name: "Turnur", security: 0.4}

    from = Wormholes.eligible_types(c3, turnur).from
    assert "J377" in from
  end

  test "eligible_types/2 matches Drifter and generic classes" do
    drifter = %{solar_system_id: 32_000_001, name: "J3200001", sys_class: "Drifter"}

    assert Wormholes.eligible_types(drifter, "C4").from != []
    assert Wormholes.eligible_types("Drifter", "C4").from != []
    assert Wormholes.eligible_types("C2", "Dangerous").from != []
    assert Wormholes.eligible_types("C2", "Unknown").from != []
    assert Wormholes.eligible_types("C2", "Unknown (small)").from != []
  end

  test "eligible_types/2 resolves Thera" do
    thera = %{solar_system_id: 31_000_005, name: "Thera", sys_class: "Thera"}

    assert Wormholes.eligible_types(thera, "HS").from != []
  end

  test "all_codes/0 is non-empty and sorted" do
    codes = Wormholes.all_codes()
    assert Enum.count(codes) >= 90
    assert codes == Enum.sort(codes)
  end
end
