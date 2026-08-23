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
end
