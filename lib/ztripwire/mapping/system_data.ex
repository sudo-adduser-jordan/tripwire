defmodule Ztripwire.Mapping.SystemData do
  import Ecto.Query

  alias Ztripwire.Mapping.MapSystem
  alias Ztripwire.Repo
  alias Ztripwire.WormholeSystems

  @doc "Fills missing class, effect and statics on map systems. Returns the row count."
  def backfill(force? \\ false) when is_boolean(force?) do
    from(s in MapSystem,
      where: s.solar_system_id > 0,
      select: %{
        id: s.id,
        solar_system_id: s.solar_system_id,
        name: s.name,
        sys_class: s.sys_class,
        effect: s.effect,
        statics: s.statics
      }
    )
    |> Repo.all()
    |> Enum.reduce(0, fn row, updated ->
      case changes(row, force?) do
        attrs when map_size(attrs) == 0 ->
          updated

        attrs ->
          Repo.update_all(from(s in MapSystem, where: s.id == ^row.id),
            set: Enum.to_list(attrs)
          )

          updated + 1
      end
    end)
  end

  defp changes(row, force?) do
    row.solar_system_id
    |> WormholeSystems.attrs(row.name)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if force? or empty?(Map.get(row, key)) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?([]), do: true
  defp empty?(_value), do: false
end
