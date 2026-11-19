defmodule Tripwire.SettingsTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.Settings
  alias Tripwire.Settings.UserSettings

  test "get/0 inserts the single settings row with defaults" do
    settings = Settings.get()

    assert settings.id == 1
    assert settings.map_layout == "top"
    assert settings.line_weight == 2
    assert settings.node_spacing == 100
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
    refute settings.show_row_guides
    refute settings.show_row_counts
    refute settings.include_thera
    refute settings.show_all
    assert settings.chart_range == "24h"
    assert settings.chart_hidden == []
  end

  test "get/0 keeps a single row" do
    assert Settings.get().id == Settings.get().id
    assert Repo.aggregate(UserSettings, :count) == 1
  end

  test "update/1 persists preferences for every caller" do
    assert {:ok, _} =
             Settings.update(%{
               map_layout: "radial",
               map_scale: 150,
               node_spacing: 130,
               show_all: true,
               widget_map: false
             })

    settings = Settings.get()
    assert settings.map_layout == "radial"
    assert settings.map_scale == 150
    assert settings.node_spacing == 130
    assert settings.show_all
    refute settings.widget_map
  end

  test "update/1 stores chart_hidden MapSets as lists" do
    assert {:ok, _} = Settings.update(%{chart_hidden: MapSet.new(["jumps", "npc_kills"])})
    assert Enum.sort(Settings.get().chart_hidden) == ["jumps", "npc_kills"]
  end

  test "assigns/0 returns live view keys with a chart_hidden MapSet" do
    assigns = Settings.assigns()

    assert assigns.map_layout == "top"
    assert assigns.chart_range == "24h"
    assert assigns.chart_hidden == MapSet.new()
    refute Map.has_key?(assigns, :id)
    refute Map.has_key?(assigns, :inserted_at)
  end

  test "update/1 rejects invalid preferences" do
    assert {:error, changeset} = Settings.update(%{map_layout: "sideways"})
    assert %{map_layout: [_]} = errors_on(changeset)
    assert {:error, _} = Settings.update(%{map_scale: 10})
    assert {:error, _} = Settings.update(%{line_weight: 9})
    assert {:error, _} = Settings.update(%{node_spacing: 500})
    assert {:error, _} = Settings.update(%{chart_range: "year"})

    settings = Settings.get()
    assert settings.map_layout == "top"
    assert settings.map_scale == 100
  end
end
