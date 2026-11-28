defmodule Ztripwire.Layouts do
  import Ecto.Query

  alias Ztripwire.Accounts.Character
  alias Ztripwire.Layouts.Layout
  alias Ztripwire.Repo
  alias Ztripwire.Settings

  @widget_ids ~w(system notes signatures map)

  @core_layouts [
    %{
      id: "core:default",
      name: "Default",
      description: "System and notes on top, signatures below, map underneath.",
      core?: true,
      widgets: %{
        "system" => %{"x" => 1, "y" => 0, "w" => 5, "h" => 6, "visible" => true},
        "notes" => %{"x" => 6, "y" => 0, "w" => 5, "h" => 6, "visible" => true},
        "signatures" => %{"x" => 1, "y" => 6, "w" => 10, "h" => 6, "visible" => true},
        "map" => %{"x" => 1, "y" => 12, "w" => 10, "h" => 12, "visible" => true}
      }
    },
    %{
      id: "core:map-focus",
      name: "Map Focus",
      description: "The chain fills the top of the dashboard; signatures are hidden.",
      core?: true,
      widgets: %{
        "map" => %{"x" => 1, "y" => 0, "w" => 10, "h" => 12, "visible" => true},
        "system" => %{"x" => 1, "y" => 12, "w" => 5, "h" => 6, "visible" => true},
        "notes" => %{"x" => 6, "y" => 12, "w" => 5, "h" => 6, "visible" => true},
        "signatures" => %{"x" => 1, "y" => 18, "w" => 10, "h" => 6, "visible" => false}
      }
    },
    %{
      id: "core:signatures-focus",
      name: "Signatures Focus",
      description: "The signature table is full width on top; the map is hidden.",
      core?: true,
      widgets: %{
        "signatures" => %{"x" => 1, "y" => 0, "w" => 10, "h" => 8, "visible" => true},
        "system" => %{"x" => 1, "y" => 8, "w" => 5, "h" => 6, "visible" => true},
        "notes" => %{"x" => 6, "y" => 8, "w" => 5, "h" => 6, "visible" => true},
        "map" => %{"x" => 1, "y" => 14, "w" => 10, "h" => 12, "visible" => false}
      }
    },
    %{
      id: "core:compact",
      name: "Compact",
      description: "System and signatures only; notes and the map are hidden.",
      core?: true,
      widgets: %{
        "system" => %{"x" => 1, "y" => 0, "w" => 5, "h" => 4, "visible" => true},
        "signatures" => %{"x" => 1, "y" => 4, "w" => 10, "h" => 6, "visible" => true},
        "notes" => %{"x" => 6, "y" => 0, "w" => 5, "h" => 4, "visible" => false},
        "map" => %{"x" => 1, "y" => 10, "w" => 10, "h" => 12, "visible" => false}
      }
    }
  ]

  def widget_ids, do: @widget_ids

  def core_layouts, do: @core_layouts

  def default_widgets, do: hd(@core_layouts).widgets

  def list_layouts(%Character{} = character) do
    @core_layouts ++ Enum.map(list_saved(character), &normalize_layout/1)
  end

  def list_saved(%Character{id: owner_id}) do
    Repo.all(
      from(l in Layout,
        where: l.owner_character_id == ^owner_id,
        order_by: [desc: l.id]
      )
    )
  end

  def get_layout(%Character{}, nil), do: nil

  def get_layout(%Character{}, "core:" <> _ = id) do
    Enum.find(@core_layouts, &(&1.id == id))
  end

  def get_layout(%Character{id: owner_id}, "saved:" <> raw_id) do
    with {id, ""} <- Integer.parse(raw_id),
         %Layout{owner_character_id: ^owner_id} = layout <- Repo.get(Layout, id) do
      normalize_layout(layout)
    else
      _ -> nil
    end
  end

  def get_layout(%Character{}, _id), do: nil

  def save_layout(%Character{id: owner_id}, name, widgets) do
    %Layout{}
    |> Layout.changeset(%{
      name: name,
      widgets: normalize_widgets(widgets),
      owner_character_id: owner_id
    })
    |> Repo.insert()
  end

  def delete_layout(%Character{}, "core:" <> _), do: {:error, :core}

  def delete_layout(%Character{id: owner_id}, "saved:" <> raw_id) do
    with {id, ""} <- Integer.parse(raw_id),
         %Layout{owner_character_id: ^owner_id} = layout <- Repo.get(Layout, id) do
      Repo.delete(layout)
    else
      _ -> {:error, :not_found}
    end
  end

  def delete_layout(%Character{}, _id), do: {:error, :not_found}

  def active_layout(%Character{} = character), do: Settings.get(character).active_layout

  def set_active(%Character{} = character, id),
    do: Settings.update(character, %{active_layout: id})

  def clear_active(%Character{} = character), do: set_active(character, nil)

  def resolve_active(%Character{} = character),
    do: get_layout(character, active_layout(character))

  def arrangement(%Character{} = character) do
    case Settings.get(character).widget_layout do
      %{} = widgets -> normalize_widgets(widgets)
      _ -> default_widgets()
    end
  end

  def put_arrangement(%Character{} = character, widgets, active_id \\ nil) do
    Settings.update(character, %{
      widget_layout: merge_arrangement(character, widgets),
      active_layout: active_id
    })
  end

  def reset_arrangement(%Character{} = character) do
    Settings.update(character, %{widget_layout: nil, active_layout: nil})
  end

  def with_visibility(widgets, assigns) do
    positions = Map.get(assigns, :widget_positions) || %{}

    Map.new(@widget_ids, fn key ->
      base = Map.get(positions, key) || %{}
      widget = Map.merge(base, Map.get(widgets || %{}, key) || %{})
      visible = Map.get(assigns, :"widget_#{key}", true)
      {key, Map.put(widget, "visible", visible)}
    end)
    |> normalize_widgets()
  end

  def normalize_widgets(widgets) when is_map(widgets) do
    Map.new(@widget_ids, fn key ->
      source = Map.get(widgets, key) || Map.get(widgets, String.to_atom(key)) || %{}
      x = clamp_int(fetch(source, "x"), 0, 0, 11)
      y = clamp_int(fetch(source, "y"), 0, 0, 1000)
      w = clamp_int(fetch(source, "w"), 12, 1, 12 - x)
      h = clamp_int(fetch(source, "h"), 6, 1, 24)
      visible = fetch(source, "visible")

      visible =
        case visible do
          nil -> true
          true -> true
          "true" -> true
          _ -> false
        end

      {key, %{"x" => x, "y" => y, "w" => w, "h" => h, "visible" => visible}}
    end)
  end

  def normalize_widgets(_widgets), do: default_widgets()

  def valid_widgets?(widgets) when is_map(widgets) do
    map_size(widgets) == length(@widget_ids) and
      Enum.all?(@widget_ids, fn key ->
        case widgets[key] do
          %{} = widget ->
            valid_int?(widget["x"], 0, 11) and
              valid_int?(widget["y"], 0, 1000) and
              valid_int?(widget["w"], 1, 12) and
              valid_int?(widget["h"], 1, 24) and
              widget["x"] + widget["w"] <= 12 and
              is_boolean(widget["visible"])

          _ ->
            false
        end
      end)
  end

  def valid_widgets?(_widgets), do: false

  defp merge_arrangement(%Character{} = character, widgets) when is_map(widgets) do
    current = arrangement(character)
    defaults = default_widgets()

    Map.new(@widget_ids, fn key ->
      base = Map.get(current, key) || defaults[key]
      patch = Map.get(widgets, key) || Map.get(widgets, String.to_atom(key)) || %{}
      {key, Map.merge(base, patch)}
    end)
    |> normalize_widgets()
  end

  defp merge_arrangement(_character, _widgets), do: default_widgets()

  defp normalize_layout(%Layout{} = layout) do
    %{
      id: "saved:#{layout.id}",
      name: layout.name,
      description: nil,
      core?: false,
      widgets: normalize_widgets(layout.widgets)
    }
  end

  defp fetch(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, String.to_atom(key))
    end
  end

  defp clamp_int(value, default, min, max) do
    case Integer.parse(to_string(value || "")) do
      {n, ""} -> n |> max(min) |> min(max)
      _ -> default
    end
  end

  defp valid_int?(value, min, max), do: is_integer(value) and value >= min and value <= max
end
