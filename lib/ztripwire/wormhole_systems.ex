defmodule Ztripwire.WormholeSystems do
  @path Path.expand("../../priv/data/wormhole_systems.json", __DIR__)
  @external_resource @path

  @systems @path |> File.read!() |> Jason.decode!()

  @doc "Returns the class, effect and statics for a solar system id, or nil."
  def get(solar_system_id) when is_integer(solar_system_id) do
    case Map.get(@systems, Integer.to_string(solar_system_id)) do
      nil ->
        nil

      entry ->
        %{
          name: entry["name"],
          class: entry["class"],
          effect: entry["effect"],
          statics: entry["statics"] || []
        }
    end
  end

  def get(_solar_system_id), do: nil

  @doc """
  Returns map_systems attrs for the known data, skipping missing fields.

  When a name is given, it must match the dataset name, so synthetic systems
  that reuse a real solar id (the demo seed) keep their own data.
  """
  def attrs(solar_system_id, name \\ nil) do
    case get(solar_system_id) do
      nil ->
        %{}

      entry ->
        if name_matches?(entry.name, name) do
          %{}
          |> put_present(:sys_class, entry.class)
          |> put_present(:effect, entry.effect)
          |> put_present(:statics, entry.statics)
        else
          %{}
        end
    end
  end

  def system_ids, do: @systems |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.sort()

  defp name_matches?(_dataset_name, nil), do: true
  defp name_matches?(nil, _name), do: true

  defp name_matches?(dataset_name, name),
    do: String.downcase(dataset_name) == String.downcase(to_string(name))

  defp put_present(attrs, _key, nil), do: attrs
  defp put_present(attrs, _key, []), do: attrs
  defp put_present(attrs, key, value), do: Map.put(attrs, key, value)
end
