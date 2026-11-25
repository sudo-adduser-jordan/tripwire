defmodule Tripwire.SignaturesTest do
  use ExUnit.Case, async: true

  doctest Tripwire.Signatures

  alias Tripwire.Signatures

  describe "parse_line/1" do
    test "parses a full tab-separated scan result" do
      {:ok, parsed} =
        Signatures.parse_line(
          "ABC-123\tCosmic Signature\t\tCombat Site - Rogue Serpentis Frigate Den\t100.0%\t2.84 AU"
        )

      assert parsed.sig_id == "ABC-123"
      assert parsed.kind == :signature
      assert parsed.name == "Combat Site - Rogue Serpentis Frigate Den"
      assert parsed.category == :combat
      refute parsed.wormhole_type
    end

    test "upcases lowercase ids" do
      {:ok, parsed} = Signatures.parse_line("abc-123")
      assert parsed.sig_id == "ABC-123"
      assert parsed.name == nil
      assert parsed.category == :unknown
    end

    test "detects anomalies by scan group" do
      {:ok, parsed} = Signatures.parse_line("DEF-456\tCosmic Anomaly\tForsaken Hub\t\t100%")
      assert parsed.kind == :anomaly
      assert parsed.name == "Forsaken Hub"
      assert parsed.category == :combat
    end

    test "extracts wormhole type codes and sets category" do
      {:ok, parsed} = Signatures.parse_line("GHI-789\tCosmic Signature\tUnstable Wormhole (Z647)")
      assert parsed.wormhole_type == "Z647"
      assert parsed.category == :wormhole
    end

    test "detects data, relic, gas and ore sites by keyword" do
      for {name, expected} <- [
            {"Ruined Data Site", :data},
            {"Relic Site", :relic},
            {"Sizeable Perimeter Withdrawal", :gas},
            {"Ore Site - Rarified Core Deposit", :ore}
          ] do
        {:ok, parsed} = Signatures.parse_line("ZZZ-999\tCosmic Signature\t#{name}")
        assert parsed.category == expected
      end
    end

    test "rejects lines without a signature id" do
      assert Signatures.parse_line("nothing to see") == :error
      assert Signatures.parse_line("") == :error
      assert Signatures.parse_line(nil) == :error
    end

    test "handles space separated columns" do
      {:ok, parsed} = Signatures.parse_line("XYZ-010   Cosmic Signature   Serpentis Frigate Den")
      assert parsed.sig_id == "XYZ-010"
      assert parsed.name == "Serpentis Frigate Den"
    end
  end

  describe "parse_paste/1" do
    test "parses multi-line pastes skipping junk lines" do
      paste = """
      Signature ID	Scan Group	Type	Signal	Distance
      ABC-123	Cosmic Signature	Unstable Wormhole		4.55 AU
      some random line
      DEF-456	Cosmic Anomaly	Forsaken Hub		
      """

      parsed = Signatures.parse_paste(paste)

      assert [%{sig_id: "ABC-123"}, %{sig_id: "DEF-456"}] = parsed
      assert hd(tl(parsed)).kind == :anomaly
    end

    test "returns empty list for non-binary input" do
      assert Signatures.parse_paste(42) == []
    end
  end

  describe "form_from/1 and attrs_from_params/1" do
    test "round-trips the type id and scan time" do
      signature = %Tripwire.Mapping.Signature{
        sig_id: "ABC-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K162)",
        type_id: 30_744,
        life_length: 259_200,
        bookmark: "Two",
        inserted_at: ~N[2026-01-01 08:00:00]
      }

      form = Signatures.form_from(signature)
      assert form["type_id"] == "30744"
      assert form["scanned_at"] == "2026-01-01T08:00"

      attrs = Signatures.attrs_from_params(form)
      assert attrs.type_id == 30_744
      assert attrs.inserted_at == ~N[2026-01-01 08:00:00]
      assert attrs.bookmark == "Two"
    end

    test "keeps a blank scan time out of the attrs so inserts keep the current time" do
      attrs = Signatures.attrs_from_params(Signatures.default_form())
      refute Map.has_key?(attrs, :inserted_at)
      assert attrs.type_id == nil
    end

    test "ignores an invalid scan time and type id" do
      attrs = Signatures.attrs_from_params(%{"scanned_at" => "nope", "type_id" => "abc"})
      refute Map.has_key?(attrs, :inserted_at)
      assert attrs.type_id == nil
    end
  end

  describe "external_link/1" do
    test "returns an eve-survival URL for a known site" do
      assert Signatures.external_link("Core Garrison") ==
               "https://eve-survival.org/wikka.php?wakka=CoreGarrison"
    end

    test "falls back to the EVE University wiki for unknown sites" do
      assert Signatures.external_link("Forsaken Hub") ==
               "https://wiki.eveuniversity.org/Forsaken_Hub"
    end

    test "percent-encodes unsafe characters in wiki titles" do
      assert Signatures.external_link("Combat Site: Rogue's Den") ==
               "https://wiki.eveuniversity.org/Combat_Site%3A_Rogue%27s_Den"
    end

    test "returns nil for blank names" do
      assert Signatures.external_link(nil) == nil
      assert Signatures.external_link("") == nil
    end
  end

  describe "life_status/1" do
    test "labels remaining lifetime like official Tripwire" do
      assert Signatures.life_status(4 * 3600) == :stable
      assert Signatures.life_status(3600) == :eol
      assert Signatures.life_status(3599) == :critical
      assert Signatures.life_status(0) == :expired
    end
  end

  describe "age_seconds/2" do
    test "returns zero for signatures scanned in the future" do
      now = ~U[2026-01-01 00:00:00Z]
      assert Signatures.age_seconds(DateTime.add(now, 60, :second), now) == 0
    end
  end
end
