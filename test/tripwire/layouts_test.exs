defmodule Tripwire.LayoutsTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.Layouts
  alias Tripwire.Settings

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

  test "save_layout/2 stores a normalized layout after the core layouts" do
    widgets =
      Map.new(Layouts.default_widgets(), fn {key, widget} ->
        {key, Map.merge(widget, %{"x" => 0, "w" => 12, "h" => 4})}
      end)

    assert {:ok, layout} = Layouts.save_layout("Wide", widgets)
    assert layout.name == "Wide"

    layouts = Layouts.list_layouts()
    assert length(layouts) == 5
    assert List.last(layouts).id == "saved:#{layout.id}"
    refute List.last(layouts).core?
    assert Layouts.valid_widgets?(List.last(layouts).widgets)
  end

  test "save_layout/2 rejects blank and duplicate names" do
    assert {:error, changeset} = Layouts.save_layout("   ", Layouts.default_widgets())
    assert %{name: [_]} = errors_on(changeset)

    assert {:ok, _} = Layouts.save_layout("Wide", Layouts.default_widgets())
    assert {:error, changeset} = Layouts.save_layout("Wide", Layouts.default_widgets())
    assert %{name: [_]} = errors_on(changeset)
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

  test "delete_layout/1 only removes saved layouts" do
    assert {:error, :core} = Layouts.delete_layout("core:default")
    assert {:error, :not_found} = Layouts.delete_layout("saved:999")

    assert {:ok, layout} = Layouts.save_layout("Wide", Layouts.default_widgets())
    assert {:ok, deleted} = Layouts.delete_layout("saved:#{layout.id}")
    assert deleted.id == layout.id
    assert Layouts.list_saved() == []
  end

  test "set_active/1 and resolve_active/0 persist the applied layout" do
    assert Layouts.active_layout() == nil
    assert Layouts.resolve_active() == nil

    assert {:ok, _} = Layouts.set_active("core:map-focus")
    assert Layouts.active_layout() == "core:map-focus"
    assert Layouts.resolve_active().name == "Map Focus"

    assert {:ok, _} = Layouts.set_active("saved:999")
    assert Layouts.resolve_active() == nil

    assert {:ok, layout} = Layouts.save_layout("Wide", Layouts.default_widgets())
    assert {:ok, _} = Layouts.set_active("saved:#{layout.id}")
    assert Layouts.resolve_active().id == "saved:#{layout.id}"

    assert {:ok, _} = Layouts.clear_active()
    assert Layouts.active_layout() == nil
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

  test "settings expose the active layout key" do
    assert Map.has_key?(Settings.assigns(), :active_layout)
    assert Map.fetch!(Settings.assigns(), :active_layout) == nil
  end

  test "put_arrangement/2 stores the arrangement and active layout" do
    widgets =
      Map.put(Layouts.default_widgets(), "system", %{
        "x" => 2,
        "y" => 3,
        "w" => 4,
        "h" => 5,
        "visible" => true
      })

    assert {:ok, _} = Layouts.put_arrangement(widgets, "core:compact")

    assert Layouts.arrangement()["system"] == %{
             "x" => 2,
             "y" => 3,
             "w" => 4,
             "h" => 5,
             "visible" => true
           }

    assert Layouts.active_layout() == "core:compact"

    assert {:ok, _} = Layouts.reset_arrangement()
    assert Settings.get().widget_layout == nil
    assert Layouts.active_layout() == nil
    assert Layouts.arrangement() == Layouts.default_widgets()
  end

  test "put_arrangement/2 merges partial snapshots over the stored arrangement" do
    widgets = %{
      "system" => %{"x" => 0, "y" => 1, "w" => 6, "h" => 5},
      "map" => %{"x" => 0, "y" => 10, "w" => 12}
    }

    assert {:ok, _} = Layouts.put_arrangement(widgets, nil)
    stored = Layouts.arrangement()

    assert stored["system"]["h"] == 5
    assert stored["map"]["h"] == Layouts.default_widgets()["map"]["h"]
    assert stored["notes"]["x"] == Layouts.default_widgets()["notes"]["x"]
    assert Layouts.valid_widgets?(stored)
  end

  test "arrangement/0 normalizes a stored arrangement" do
    {:ok, _} =
      Settings.update(%{
        widget_layout: %{"system" => %{"x" => 20, "w" => 20, "visible" => "nope"}}
      })

    widgets = Layouts.arrangement()

    assert widgets["system"] == %{
             "x" => 11,
             "y" => 0,
             "w" => 1,
             "h" => 6,
             "visible" => false
           }

    assert Layouts.valid_widgets?(widgets)
  end
end
