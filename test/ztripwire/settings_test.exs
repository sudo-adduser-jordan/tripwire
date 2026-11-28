defmodule Ztripwire.SettingsTest do
  use Ztripwire.DataCase, async: false

  alias Ztripwire.Accounts
  alias Ztripwire.Settings
  alias Ztripwire.Settings.UserSettings

  setup do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 9_100, name: "Settings Tester"})
    {:ok, other} = Accounts.upsert_character(%{eve_id: 9_101, name: "Other Tester"})
    %{character: character, other: other}
  end

  test "get/1 inserts defaults for the character", %{character: character} do
    settings = Settings.get(character)

    assert settings.character_id == character.id
    assert settings.map_layout == "top"
    assert settings.line_weight == 2
    assert settings.node_spacing == 100
    assert settings.node_roundness == "oval"
    assert settings.map_scale == 100
    assert settings.grid_locked
    assert settings.widget_system
    assert settings.widget_notes
    assert settings.widget_signatures
    assert settings.widget_map
    assert settings.angled_lines
    assert settings.show_jump_lines
    assert settings.show_line_glow
    assert settings.show_node_badges
    assert settings.show_row_guides
    assert settings.show_row_counts
    refute settings.include_thera
    refute settings.show_all
    assert settings.chart_range == "24h"
    assert settings.chart_hidden == []
  end

  test "get/1 keeps a single row per character", %{character: character, other: other} do
    before = Repo.aggregate(UserSettings, :count)

    assert Settings.get(character).id == Settings.get(character).id
    assert Repo.aggregate(UserSettings, :count) == before + 1

    assert Settings.get(other).id != Settings.get(character).id
    assert Repo.aggregate(UserSettings, :count) == before + 2
  end

  test "update/2 persists preferences for one character only", %{
    character: character,
    other: other
  } do
    assert {:ok, _} =
             Settings.update(character, %{
               map_layout: "left",
               map_scale: 150,
               node_spacing: 130,
               node_roundness: "square",
               show_all: true,
               widget_map: false
             })

    settings = Settings.get(character)
    assert settings.map_layout == "left"
    assert settings.map_scale == 150
    assert settings.node_spacing == 130
    assert settings.node_roundness == "square"
    assert settings.show_all
    refute settings.widget_map

    other_settings = Settings.get(other)
    assert other_settings.map_layout == "top"
    assert other_settings.map_scale == 100
    assert other_settings.widget_map
    refute other_settings.show_all
  end

  test "update/2 stores chart_hidden MapSets as lists", %{character: character} do
    assert {:ok, _} =
             Settings.update(character, %{chart_hidden: MapSet.new(["jumps", "npc_kills"])})

    assert Enum.sort(Settings.get(character).chart_hidden) == ["jumps", "npc_kills"]
  end

  test "assigns/1 returns live view keys with a chart_hidden MapSet", %{character: character} do
    assigns = Settings.assigns(character)

    assert assigns.map_layout == "top"
    assert assigns.chart_range == "24h"
    assert assigns.chart_hidden == MapSet.new()
    refute Map.has_key?(assigns, :id)
    refute Map.has_key?(assigns, :character_id)
    refute Map.has_key?(assigns, :inserted_at)
  end

  test "update/2 accepts an https map background and rejects other URLs", %{character: character} do
    assert {:ok, _} =
             Settings.update(character, %{map_background: "https://example.com/map-bg.jpg"})

    assert Settings.get(character).map_background == "https://example.com/map-bg.jpg"

    assert {:error, changeset} =
             Settings.update(character, %{map_background: "http://example.com/map-bg.jpg"})

    assert %{map_background: [_]} = errors_on(changeset)
    assert {:error, _} = Settings.update(character, %{map_background: "javascript:alert(1)"})
  end

  test "update/2 rejects invalid preferences", %{character: character} do
    assert {:error, changeset} = Settings.update(character, %{map_layout: "sideways"})
    assert %{map_layout: [_]} = errors_on(changeset)
    assert {:error, _} = Settings.update(character, %{map_scale: 10})
    assert {:error, _} = Settings.update(character, %{line_weight: 9})
    assert {:error, _} = Settings.update(character, %{node_spacing: 500})
    assert {:error, _} = Settings.update(character, %{node_roundness: "pill"})
    assert {:error, _} = Settings.update(character, %{chart_range: "year"})

    settings = Settings.get(character)
    assert settings.map_layout == "top"
    assert settings.map_scale == 100
  end
end
