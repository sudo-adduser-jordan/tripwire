defmodule Ztripwire.SignaturesTest do
  use ExUnit.Case, async: true

  doctest Ztripwire.Signatures

  alias Ztripwire.Signatures

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

    test "keeps the EVE type column out of the name" do
      {:ok, parsed} =
        Signatures.parse_line("ABC-123\tCosmic Signature\tWormhole\t\t100.00%\t1.21 AU")

      assert parsed.name == nil
      assert parsed.category == :wormhole
      assert parsed.kind == :signature
    end

    test "parses a typed non-wormhole site" do
      {:ok, parsed} =
        Signatures.parse_line("ABC-123\tCosmic Signature\tCombat Site\tSerpentis Frigate Den")

      assert parsed.name == "Serpentis Frigate Den"
      assert parsed.category == :combat
    end

    test "recognizes localized scan groups and site types" do
      cases = [
        {"DEF-456\tAnomalie cosmique\tSystème abandonné", :anomaly, :combat, "Système abandonné"},
        {"DEF-457\tKosmische Anomalie\tVerlassenes System", :anomaly, :combat,
         "Verlassenes System"},
        {"DEF-458\t宇宙の特異点\t放棄された施設", :anomaly, :combat, "放棄された施設"},
        {"DEF-459\t코즈믹 어노말리\t버려진 시설", :anomaly, :combat, "버려진 시설"},
        {"DEF-460\tКосмическая аномалия\tЗаброшенное сооружение", :anomaly, :combat,
         "Заброшенное сооружение"},
        {"GHI-461\tSignature cosmique\tTrou de ver\t\t100%\t1,21 AU", :signature, :wormhole, nil},
        {"GHI-462\tKosmische Signatur\tWurmloch\t\t100%\t1,21 AU", :signature, :wormhole, nil},
        {"GHI-463\t宇宙のシグネチャ\tワームホール\t\t100%\t1.21 AU", :signature, :wormhole, nil},
        {"GHI-464\t코즈믹 시그니처\t웜홀\t\t100%\t1.21 AU", :signature, :wormhole, nil},
        {"GHI-465\tСкрытый сигнал\tЧервоточина\t\t100%\t1,21 AU", :signature, :wormhole, nil}
      ]

      for {line, kind, category, name} <- cases do
        assert {:ok, parsed} = Signatures.parse_line(line)
        assert parsed.kind == kind
        assert parsed.category == category
        assert parsed.name == name
      end
    end

    test "excludes localized distances from the name" do
      {:ok, parsed} =
        Signatures.parse_line(
          "ABC-123\tCosmic Signature\tSerpentis Frigate Den\t100.0%\t1,21 а.е."
        )

      assert parsed.name == "Serpentis Frigate Den"
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
      signature = %Ztripwire.Mapping.Signature{
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

  describe "scan attrs" do
    test "an existing wormhole keeps its identified type and life" do
      existing = %Ztripwire.Mapping.Signature{
        sig_id: "ABC-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K162)",
        life_length: 86_400,
        expires_at: ~N[2026-01-02 00:00:00]
      }

      parsed = %Ztripwire.Signatures.Parsed{
        sig_id: "ABC-123",
        kind: :signature,
        name: nil,
        wormhole_type: nil,
        category: :wormhole
      }

      assert Signatures.scan_update_attrs(existing, parsed, ~N[2026-01-01 12:00:00]) == :skip
    end

    test "an unchanged non-wormhole is not rewritten" do
      existing = %Ztripwire.Mapping.Signature{
        sig_id: "ABC-123",
        kind: "signature",
        site_type: "combat",
        type_name: "Serpentis Frigate Den"
      }

      parsed = %Ztripwire.Signatures.Parsed{
        sig_id: "ABC-123",
        kind: :signature,
        name: "Serpentis Frigate Den",
        wormhole_type: nil,
        category: :combat
      }

      assert Signatures.scan_update_attrs(existing, parsed, ~N[2026-01-01 12:00:00]) == :skip
    end

    test "a changed non-wormhole is refreshed" do
      existing = %Ztripwire.Mapping.Signature{
        sig_id: "ABC-123",
        kind: "signature",
        site_type: "combat",
        type_name: "Old Name"
      }

      parsed = %Ztripwire.Signatures.Parsed{
        sig_id: "ABC-123",
        kind: :signature,
        name: "New Name",
        wormhole_type: nil,
        category: :combat
      }

      attrs = Signatures.scan_update_attrs(existing, parsed, ~N[2026-01-01 12:00:00])
      assert attrs.type_name == "New Name"
      assert attrs.life_length == 259_200
      assert attrs.expires_at == ~N[2026-01-04 12:00:00]
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
