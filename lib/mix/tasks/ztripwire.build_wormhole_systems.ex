defmodule Mix.Tasks.Ztripwire.BuildWormholeSystems do
  use Mix.Task

  @shortdoc "Build priv/data/wormhole_systems.json from the SDE and vendored statics"

  @default_sde "priv/sde/eve-online-static-data-latest-jsonl.zip"
  @default_statics "priv/data/wormhole_statics.json"
  @default_output "priv/data/wormhole_systems.json"

  @w_space_file "mapSolarSystems.jsonl"
  @constellation_file "mapConstellations.jsonl"
  @secondary_sun_file "mapSecondarySuns.jsonl"
  @types_file "types.jsonl"

  @effect_group_id 995

  @class_labels %{
    1 => "C1",
    2 => "C2",
    3 => "C3",
    4 => "C4",
    5 => "C5",
    6 => "C6",
    12 => "Thera",
    13 => "C13",
    25 => "Trig",
    19 => "Drifter",
    20 => "Drifter",
    21 => "Drifter",
    22 => "Drifter",
    23 => "Drifter"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [sde: :string, statics: :string, output: :string]
      )

    sde = Keyword.get(opts, :sde, @default_sde)
    statics_path = Keyword.get(opts, :statics, @default_statics)
    output = Keyword.get(opts, :output, @default_output)

    files = read_sde(sde)
    statics = read_statics(statics_path)

    systems =
      files
      |> build_systems(statics)

    write(output, systems)
    Mix.shell().info("Wrote #{map_size(systems)} wormhole systems to #{output}")
  end

  defp read_sde(path) do
    files =
      Enum.map(
        [@w_space_file, @constellation_file, @secondary_sun_file, @types_file],
        &String.to_charlist/1
      )

    case :zip.unzip(String.to_charlist(path), [:memory, {:file_list, files}]) do
      {:ok, entries} ->
        Map.new(entries, fn {name, data} -> {Path.basename(to_string(name)), data} end)

      error ->
        Mix.raise("Cannot read SDE #{path}: #{inspect(error)}")
    end
  end

  defp read_statics(path) do
    case File.read(path) do
      {:ok, data} ->
        case Jason.decode(data) do
          {:ok, statics} when is_map(statics) -> statics
          _ -> Mix.raise("Invalid statics JSON in #{path}")
        end

      error ->
        Mix.raise("Cannot read statics #{path}: #{inspect(error)}")
    end
  end

  defp build_systems(files, statics) do
    classes =
      files
      |> lines(@constellation_file)
      |> Enum.flat_map(fn constellation ->
        case Map.get(constellation, "wormholeClassID") do
          id when is_integer(id) ->
            case Map.get(@class_labels, id) do
              nil -> []
              class -> Enum.map(constellation["solarSystemIDs"] || [], &{&1, class})
            end

          _ ->
            []
        end
      end)
      |> Map.new()

    effects =
      files
      |> lines(@secondary_sun_file)
      |> Enum.reduce(%{}, fn sun, acc ->
        case Map.fetch(acc, sun["solarSystemID"]) do
          {:ok, _effect} -> acc
          :error -> Map.put(acc, sun["solarSystemID"], sun["typeID"])
        end
      end)
      |> effect_names(files)

    files
    |> lines(@w_space_file)
    |> Enum.reduce(%{}, fn system, acc ->
      id = system["_key"]
      name = get_in(system, ["name", "en"])

      case Map.get(classes, id) do
        nil ->
          acc

        class ->
          entry =
            %{"class" => class}
            |> put_present("name", name)
            |> put_present("effect", Map.get(effects, id))
            |> put_present("statics", static_codes(statics, name))

          Map.put(acc, id, entry)
      end
    end)
  end

  defp effect_names(type_ids, files) do
    names =
      files
      |> lines(@types_file)
      |> Enum.reduce(%{}, fn type, acc ->
        if type["groupID"] == @effect_group_id do
          Map.put(acc, type["_key"], effect_label(get_in(type, ["name", "en"])))
        else
          acc
        end
      end)

    Map.new(type_ids, fn {solar_id, type_id} -> {solar_id, Map.get(names, type_id)} end)
  end

  defp effect_label("Wolf-Rayet Star"), do: "Wolf Rayet"
  defp effect_label(name), do: name

  defp static_codes(statics, name) when is_binary(name) do
    case Map.get(statics, name) do
      codes when is_list(codes) -> Enum.sort(codes)
      _ -> []
    end
  end

  defp static_codes(_statics, _name), do: []

  defp put_present(entry, _key, nil), do: entry
  defp put_present(entry, _key, []), do: entry
  defp put_present(entry, key, value), do: Map.put(entry, key, value)

  defp lines(files, name) do
    files
    |> Map.fetch!(name)
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, map} when is_map(map) -> [map]
        _ -> []
      end
    end)
  end

  defp write(path, systems) do
    body =
      systems
      |> Enum.sort_by(fn {id, _entry} -> id end)
      |> Enum.map_join(",\n", fn {id, entry} ->
        Jason.encode!(Integer.to_string(id)) <> ":" <> Jason.encode!(entry)
      end)

    File.write!(path, "{\n" <> body <> "\n}\n")
  end
end
