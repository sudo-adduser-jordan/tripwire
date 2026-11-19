defmodule Tripwire.Settings do
  alias Tripwire.Repo
  alias Tripwire.Settings.UserSettings

  @id 1
  @assign_keys [
    :map_layout,
    :show_row_guides,
    :show_row_counts,
    :angled_lines,
    :show_jump_lines,
    :show_line_glow,
    :show_node_badges,
    :line_weight,
    :node_spacing,
    :map_scale,
    :map_background,
    :grid_locked,
    :widget_system,
    :widget_notes,
    :widget_signatures,
    :widget_map,
    :include_thera,
    :show_all,
    :chart_range,
    :active_layout
  ]

  def get do
    case Repo.get(UserSettings, @id) do
      %UserSettings{} = settings ->
        settings

      nil ->
        Repo.insert!(%UserSettings{id: @id}, on_conflict: :nothing)
        Repo.get!(UserSettings, @id)
    end
  end

  def update(%UserSettings{} = settings, attrs) do
    settings
    |> UserSettings.changeset(normalize(attrs))
    |> Repo.update()
  end

  def update(attrs) when is_map(attrs), do: update(get(), attrs)

  def assigns do
    settings = get()

    settings
    |> Map.from_struct()
    |> Map.take(@assign_keys)
    |> Map.put(:chart_hidden, MapSet.new(settings.chart_hidden || []))
  end

  defp normalize(%{chart_hidden: %MapSet{} = hidden} = attrs),
    do: Map.put(attrs, :chart_hidden, MapSet.to_list(hidden))

  defp normalize(attrs), do: attrs
end
