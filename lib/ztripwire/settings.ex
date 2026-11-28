defmodule Ztripwire.Settings do
  alias Ztripwire.Accounts.Character
  alias Ztripwire.Repo
  alias Ztripwire.Settings.UserSettings

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
    :node_roundness,
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

  def get(%Character{id: id}), do: get(id)

  def get(id) when is_integer(id) do
    case Repo.get_by(UserSettings, character_id: id) do
      %UserSettings{} = settings ->
        settings

      nil ->
        %UserSettings{character_id: id}
        |> Repo.insert(on_conflict: :nothing)
        |> case do
          {:ok, settings} -> settings
          {:error, _changeset} -> Repo.get_by!(UserSettings, character_id: id)
        end
    end
  end

  def update(%UserSettings{} = settings, attrs) do
    settings
    |> UserSettings.changeset(normalize(attrs))
    |> Repo.update()
  end

  def update(%Character{} = character, attrs), do: update(get(character), attrs)

  def update(id, attrs) when is_integer(id), do: update(get(id), attrs)

  def assigns(%Character{} = character), do: assigns(get(character))

  def assigns(id) when is_integer(id), do: assigns(get(id))

  def assigns(%UserSettings{} = settings) do
    settings
    |> Map.from_struct()
    |> Map.take(@assign_keys)
    |> Map.put(:chart_hidden, MapSet.new(settings.chart_hidden || []))
  end

  def change(%UserSettings{} = settings, attrs) do
    settings
    |> UserSettings.changeset(normalize(attrs))
    |> Ecto.Changeset.apply_action(:update)
  end

  def change(%Character{} = character, attrs), do: change(get(character), attrs)

  defp normalize(%{chart_hidden: %MapSet{} = hidden} = attrs),
    do: Map.put(attrs, :chart_hidden, MapSet.to_list(hidden))

  defp normalize(attrs), do: attrs
end
