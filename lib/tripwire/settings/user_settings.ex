defmodule Tripwire.Settings.UserSettings do
  use Ecto.Schema
  import Ecto.Changeset

  @layouts ~w(top bottom left right radial)
  @chart_ranges ~w(24h 48h week)

  schema "user_settings" do
    field :map_layout, :string, default: "top"
    field :show_row_guides, :boolean, default: false
    field :show_row_counts, :boolean, default: false
    field :angled_lines, :boolean, default: true
    field :show_jump_lines, :boolean, default: true
    field :show_line_glow, :boolean, default: true
    field :show_node_badges, :boolean, default: true
    field :line_weight, :integer, default: 2
    field :node_spacing, :integer, default: 100
    field :map_scale, :integer, default: 100
    field :map_background, :string
    field :grid_locked, :boolean, default: true
    field :widget_system, :boolean, default: true
    field :widget_notes, :boolean, default: true
    field :widget_signatures, :boolean, default: true
    field :widget_map, :boolean, default: true
    field :include_thera, :boolean, default: false
    field :show_all, :boolean, default: false
    field :chart_range, :string, default: "24h"
    field :chart_hidden, {:array, :string}, default: []

    timestamps(type: :utc_datetime)
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [
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
      :chart_hidden
    ])
    |> validate_inclusion(:map_layout, @layouts)
    |> validate_inclusion(:chart_range, @chart_ranges)
    |> validate_number(:line_weight, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:node_spacing, greater_than_or_equal_to: 50, less_than_or_equal_to: 200)
    |> validate_number(:map_scale, greater_than_or_equal_to: 50, less_than_or_equal_to: 200)
    |> validate_length(:map_background, max: 2048)
  end
end
