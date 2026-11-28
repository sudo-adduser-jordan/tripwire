defmodule Ztripwire.LayoutsTest do
  use Ztripwire.DataCase, async: false

  alias Ztripwire.Accounts
  alias Ztripwire.Layouts
  alias Ztripwire.Settings

  setup do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 9_200, name: "Layout Tester"})
    {:ok, other} = Accounts.upsert_character(%{eve_id: 9_201, name: "Other Layout Tester"})
    %{character: character, other: other}
  end

  test "core layouts ship with a valid widget arrangement" do
    layouts = Layouts.core_layouts()

    assert Enum.map(layouts, & &1.id) == [
             "core:default",
             "core:map-focus",
             "core:signatures-focus",
             "core:compact"
           ]

    assert Enum.all?(layouts, & &1.core?)
    assert Enum.all?(layouts, &Layouts.valid_widgets?(&1.widgets))
    assert Layouts.default_widgets() == hd(layouts).widgets
    assert Layouts.default_widgets()["map"]["visible"]
  end

  test "save_layout/3 stores a normalized layout after the core layouts", %{character: character} do
    widgets =
      Map.new(Layouts.default_widgets(), fn {key, widget} ->
        {key, Map.merge(widget, %{"x" => 0, "w" => 12, "h" => 4})}
      end)

    assert {:ok, layout} = Layouts.save_layout(character, "Wide", widgets)
    assert layout.name == "Wide"
    assert layout.owner_character_id == character.id

    layouts = Layouts.list_layouts(character)
    assert length(layouts) == 5
    assert List.last(layouts).id == "saved:#{layout.id}"
    refute List.last(layouts).core?
    assert Layouts.valid_widgets?(List.last(layouts).widgets)
  end

  test "save_layout/3 rejects blank and duplicate names", %{character: character, other: other} do
    assert {:error, changeset} = Layouts.save_layout(character, "   ", Layouts.default_widgets())
    assert %{name: [_]} = errors_on(changeset)

    assert {:ok, _} = Layouts.save_layout(character, "Wide", Layouts.default_widgets())
    assert {:error, changeset} = Layouts.save_layout(character, "Wide", Layouts.default_widgets())
    assert %{name: [_]} = errors_on(changeset)

    assert {:ok, _} = Layouts.save_layout(other, "Wide", Layouts.default_widgets())
  end

  test "normalize_widgets/1 clamps invalid values and fills missing widgets" do
    widgets =
      Layouts.normalize_widgets(%{
        "system" => %{"x" => 20, "y" => -5, "w" => 20, "h" => 0, "visible" => "true"},
        "map" => %{"x" => 11, "w" => 12, "visible" => false}
      })

    assert widgets["system"] == %{"x" => 11, "y" => 0, "w" => 1, "h" => 1, "visible" => true}
    assert widgets["map"]["x"] == 11
    assert widgets["map"]["w"] == 1
    refute widgets["map"]["visible"]
    assert Layouts.valid_widgets?(widgets)
  end

  test "delete_layout/2 only removes the character's saved layouts", %{
    character: character,
    other: other
  } do
    assert {:error, :core} = Layouts.delete_layout(character, "core:default")
    assert {:error, :not_found} = Layouts.delete_layout(character, "saved:999")

    assert {:ok, layout} = Layouts.save_layout(character, "Wide", Layouts.default_widgets())
    assert {:error, :not_found} = Layouts.delete_layout(other, "saved:#{layout.id}")
    assert {:ok, deleted} = Layouts.delete_layout(character, "saved:#{layout.id}")
    assert deleted.id == layout.id
    assert Layouts.list_saved(character) == []
  end

  test "set_active/2 and resolve_active/1 persist the applied layout", %{
    character: character,
    other: other
  } do
    assert Layouts.active_layout(character) == nil
    assert Layouts.resolve_active(character) == nil

    assert {:ok, _} = Layouts.set_active(character, "core:map-focus")
    assert Layouts.active_layout(character) == "core:map-focus"
    assert Layouts.resolve_active(character).name == "Map Focus"
    assert Layouts.active_layout(other) == nil

    assert {:ok, _} = Layouts.set_active(character, "saved:999")
    assert Layouts.resolve_active(character) == nil

    assert {:ok, layout} = Layouts.save_layout(character, "Wide", Layouts.default_widgets())
    assert {:ok, _} = Layouts.set_active(character, "saved:#{layout.id}")
    assert Layouts.resolve_active(character).id == "saved:#{layout.id}"

    assert {:ok, _} = Layouts.clear_active(character)
    assert Layouts.active_layout(character) == nil
  end

  test "with_visibility/2 keeps layout positions and uses current widget flags" do
    assigns = %{
      widget_positions: Layouts.default_widgets(),
      widget_map: false,
      widget_notes: false
    }

    widgets = Layouts.with_visibility(%{}, assigns)

    assert widgets["map"]["x"] == Layouts.default_widgets()["map"]["x"]
    refute widgets["map"]["visible"]
    refute widgets["notes"]["visible"]
    assert widgets["system"]["visible"]
  end

  test "settings expose the active layout key", %{character: character} do
    assert Map.has_key?(Settings.assigns(character), :active_layout)
    assert Map.fetch!(Settings.assigns(character), :active_layout) == nil
  end

  test "put_arrangement/3 stores the arrangement and active layout", %{character: character} do
    widgets =
      Map.put(Layouts.default_widgets(), "system", %{
        "x" => 2,
        "y" => 3,
        "w" => 4,
        "h" => 5,
        "visible" => true
      })

    assert {:ok, _} = Layouts.put_arrangement(character, widgets, "core:compact")

    assert Layouts.arrangement(character)["system"] == %{
             "x" => 2,
             "y" => 3,
             "w" => 4,
             "h" => 5,
             "visible" => true
           }

    assert Layouts.active_layout(character) == "core:compact"

    assert {:ok, _} = Layouts.reset_arrangement(character)
    assert Settings.get(character).widget_layout == nil
    assert Layouts.active_layout(character) == nil
    assert Layouts.arrangement(character) == Layouts.default_widgets()
  end

  test "put_arrangement/3 merges partial snapshots over the stored arrangement", %{
    character: character
  } do
    widgets = %{
      "system" => %{"x" => 0, "y" => 1, "w" => 6, "h" => 5},
      "map" => %{"x" => 0, "y" => 10, "w" => 12}
    }

    assert {:ok, _} = Layouts.put_arrangement(character, widgets, nil)
    stored = Layouts.arrangement(character)

    assert stored["system"]["h"] == 5
    assert stored["map"]["h"] == Layouts.default_widgets()["map"]["h"]
    assert stored["notes"]["x"] == Layouts.default_widgets()["notes"]["x"]
    assert Layouts.valid_widgets?(stored)
  end

  test "arrangement/1 normalizes a stored arrangement", %{character: character} do
    {:ok, _} =
      Settings.update(character, %{
        widget_layout: %{"system" => %{"x" => 20, "w" => 20, "visible" => "nope"}}
      })

    widgets = Layouts.arrangement(character)

    assert widgets["system"] == %{
             "x" => 11,
             "y" => 0,
             "w" => 1,
             "h" => 6,
             "visible" => false
           }

    assert Layouts.valid_widgets?(widgets)
  end

  test "layouts are isolated per character", %{character: character, other: other} do
    {:ok, layout} = Layouts.save_layout(character, "Private Layout", Layouts.default_widgets())

    assert Enum.any?(Layouts.list_layouts(character), &(&1.id == "saved:#{layout.id}"))
    refute Enum.any?(Layouts.list_layouts(other), &(&1.id == "saved:#{layout.id}"))

    assert Layouts.get_layout(other, "saved:#{layout.id}") == nil
  end
end
