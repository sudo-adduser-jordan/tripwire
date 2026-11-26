defmodule Ztripwire.Sde.Sync do
  alias Ztripwire.Log
  alias Ztripwire.Repo
  alias Ztripwire.Sde.{Constellation, Faction, Gate, Region, Station, Type, Version}
  alias Ztripwire.Sde.System, as: SdeSystem

  @default_sde Path.expand("../../../priv/sde/eve-online-static-data-latest-jsonl.zip", __DIR__)

  @files [
    "_sde.jsonl",
    "mapRegions.jsonl",
    "mapConstellations.jsonl",
    "mapSolarSystems.jsonl",
    "mapStars.jsonl",
    "mapSecondarySuns.jsonl",
    "mapStargates.jsonl",
    "npcStations.jsonl",
    "npcCorporations.jsonl",
    "stationOperations.jsonl",
    "stationServices.jsonl",
    "types.jsonl",
    "groups.jsonl",
    "categories.jsonl",
    "mapPlanets.jsonl",
    "mapMoons.jsonl",
    "mapAsteroidBelts.jsonl",
    "factions.jsonl"
  ]

  @required [
    "_sde.jsonl",
    "mapRegions.jsonl",
    "mapConstellations.jsonl",
    "mapSolarSystems.jsonl",
    "mapStars.jsonl",
    "mapSecondarySuns.jsonl",
    "mapStargates.jsonl",
    "npcStations.jsonl",
    "npcCorporations.jsonl",
    "stationOperations.jsonl",
    "stationServices.jsonl",
    "types.jsonl",
    "groups.jsonl",
    "categories.jsonl"
  ]

  @ship_categories [2, 3, 6, 65]
  @batch 100

  def run(opts \\ []) do
    path = Keyword.get(opts, :sde) || @default_sde
    force? = Keyword.get(opts, :force, false)

    with :ok <- require_file(path),
         {:ok, version} <- read_version(path) do
      if current?(version) and not force? do
        Log.emit(:info, %{event: "sde_sync_skipped", build_number: version.build_number})
        :skipped
      else
        sync(path, version)
      end
    end
  end

  def parse_regions(entries) do
    Enum.flat_map(entries, fn entry ->
      with id when is_integer(id) <- entry["_key"],
           name when is_binary(name) <- name(entry) do
        [%{region_id: id, name: name, faction_id: entry["factionID"]}]
      else
        _ -> []
      end
    end)
  end

  def parse_constellations(entries) do
    Enum.flat_map(entries, fn entry ->
      with id when is_integer(id) <- entry["_key"],
           name when is_binary(name) <- name(entry) do
        [
          %{
            constellation_id: id,
            region_id: entry["regionID"],
            name: name,
            faction_id: entry["factionID"],
            wormhole_class_id: entry["wormholeClassID"]
          }
        ]
      else
        _ -> []
      end
    end)
  end

  def parse_factions(entries) do
    Enum.flat_map(entries, fn entry ->
      with id when is_integer(id) <- entry["_key"],
           name when is_binary(name) <- name(entry) do
        [%{faction_id: id, name: name}]
      else
        _ -> []
      end
    end)
  end

  def parse_gates(entries) do
    entries
    |> Enum.reduce(MapSet.new(), fn entry, acc ->
      from = entry["solarSystemID"]
      to = get_in(entry, ["destination", "solarSystemID"])

      if is_integer(from) and is_integer(to) and from != to do
        acc |> MapSet.put({from, to}) |> MapSet.put({to, from})
      else
        acc
      end
    end)
    |> Enum.map(fn {from, to} -> %{from_id: from, to_id: to} end)
    |> Enum.sort()
  end

  def parse_types(entries, groups, categories, referenced) do
    Enum.flat_map(entries, fn entry ->
      id = entry["_key"]
      group = Map.get(groups, entry["groupID"])
      keep? = MapSet.member?(referenced, id) or (group && group.category_id in @ship_categories)

      with true <- keep?,
           name when is_binary(name) <- name(entry) do
        [
          %{
            type_id: id,
            name: name,
            group_id: entry["groupID"],
            group_name: group && group.name,
            category_id: group && group.category_id,
            category_name: group && Map.get(categories, group.category_id)
          }
        ]
      else
        _ -> []
      end
    end)
  end

  def parse_stations(entries, operations, services, corporations, type_names) do
    Enum.flat_map(entries, fn entry ->
      station_id = entry["_key"]
      system = entry["solarSystemID"]

      if is_integer(station_id) and is_integer(system) do
        operation = Map.get(operations, entry["operationID"])

        [
          %{
            station_id: station_id,
            solar_system_id: system,
            owner_id: entry["ownerID"],
            owner_name: Map.get(corporations, entry["ownerID"]),
            operation: operation && operation.name,
            type_id: entry["typeID"],
            type_name: Map.get(type_names, entry["typeID"]),
            services: service_names(operation, services)
          }
        ]
      else
        []
      end
    end)
  end

  def parse_systems(entries, context) do
    Enum.flat_map(entries, fn entry ->
      with id when is_integer(id) <- entry["_key"],
           name when is_binary(name) <- name(entry) do
        star = Map.get(context.stars, id) || %{}

        [
          %{
            solar_system_id: id,
            name: name,
            security: as_float(entry["securityStatus"]),
            security_class: entry["securityClass"],
            region_id: entry["regionID"],
            constellation_id: entry["constellationID"],
            star_class: star[:spectral_class],
            temperature: as_float(star[:temperature]),
            luminosity: as_float(star[:luminosity]),
            radius: as_float(star[:radius]),
            planet_count: Map.get(context.planet_counts, id, 0),
            moon_count: Map.get(context.moon_counts, id, 0),
            belt_count: Map.get(context.belt_counts, id, 0),
            station_count: Map.get(context.station_counts, id, 0),
            effect: effect_name(Map.get(context.suns, id), context.effect_names),
            hub: entry["hub"] == true,
            border: entry["border"] == true,
            corridor: entry["corridor"] == true,
            regional: entry["regional"] == true,
            international: entry["international"] == true,
            position_x: as_float(get_in(entry, ["position2D", "x"])),
            position_y: as_float(get_in(entry, ["position2D", "y"]))
          }
        ]
      else
        _ -> []
      end
    end)
  end

  def system_counts(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      case entry["solarSystemID"] do
        id when is_integer(id) -> Map.update(acc, id, 1, &(&1 + 1))
        _ -> acc
      end
    end)
  end

  defp sync(path, version) do
    started = System.monotonic_time(:millisecond)

    with {:ok, dir} <- extract(path) do
      try do
        rows = build(dir)

        case write(rows, version) do
          :ok ->
            Log.emit(:info, %{
              event: "sde_sync",
              build_number: version.build_number,
              systems: length(rows.systems),
              gates: length(rows.gates),
              stations: length(rows.stations),
              types: length(rows.types),
              duration_ms: System.monotonic_time(:millisecond) - started
            })

            :ok

          {:error, reason} ->
            {:error, reason}
        end
      after
        File.rm_rf(dir)
      end
    end
  end

  defp build(dir) do
    categories = name_map(entries(dir, "categories.jsonl"))
    groups = group_map(entries(dir, "groups.jsonl"))

    regions = parse_regions(entries(dir, "mapRegions.jsonl"))
    constellations = parse_constellations(entries(dir, "mapConstellations.jsonl"))
    factions = parse_factions(entries(dir, "factions.jsonl"))

    planet_counts = system_counts(entries(dir, "mapPlanets.jsonl"))
    moon_counts = system_counts(entries(dir, "mapMoons.jsonl"))
    belt_counts = system_counts(entries(dir, "mapAsteroidBelts.jsonl"))

    suns = sun_map(entries(dir, "mapSecondarySuns.jsonl"))
    station_entries = Enum.to_list(entries(dir, "npcStations.jsonl"))
    operations = operation_map(entries(dir, "stationOperations.jsonl"))
    services = name_map(entries(dir, "stationServices.jsonl"), "serviceName")
    corporations = name_map(entries(dir, "npcCorporations.jsonl"))

    types =
      entries(dir, "types.jsonl")
      |> parse_types(groups, categories, referenced_type_ids(station_entries, suns))

    type_names = Map.new(types, &{&1.type_id, &1.name})
    stations = parse_stations(station_entries, operations, services, corporations, type_names)

    stars = star_map(entries(dir, "mapStars.jsonl"))

    systems =
      parse_systems(entries(dir, "mapSolarSystems.jsonl"), %{
        stars: stars,
        suns: suns,
        effect_names: type_names,
        planet_counts: planet_counts,
        moon_counts: moon_counts,
        belt_counts: belt_counts,
        station_counts: Enum.frequencies_by(stations, & &1.solar_system_id)
      })

    %{
      regions: regions,
      constellations: constellations,
      factions: factions,
      types: types,
      systems: systems,
      gates: parse_gates(entries(dir, "mapStargates.jsonl")),
      stations: stations
    }
  end

  defp write(rows, version) do
    result =
      Repo.transaction(fn ->
        Repo.delete_all(Version, log: false)
        Repo.delete_all(SdeSystem, log: false)
        Repo.delete_all(Gate, log: false)
        Repo.delete_all(Station, log: false)
        Repo.delete_all(Type, log: false)
        Repo.delete_all(Region, log: false)
        Repo.delete_all(Constellation, log: false)
        Repo.delete_all(Faction, log: false)

        insert_all(Region, rows.regions)
        insert_all(Constellation, rows.constellations)
        insert_all(Faction, rows.factions)
        insert_all(Type, rows.types)
        insert_all(SdeSystem, rows.systems)
        insert_all(Gate, rows.gates)
        insert_all(Station, rows.stations)

        Repo.insert_all(
          Version,
          [
            %{
              id: 1,
              build_number: version.build_number,
              release_date: version.release_date,
              synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
            }
          ],
          log: false
        )
      end)

    case result do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:write, reason}}
    end
  end

  defp insert_all(schema, rows) do
    rows
    |> Enum.chunk_every(@batch)
    |> Enum.each(fn chunk -> Repo.insert_all(schema, chunk, log: false) end)
  end

  defp entries(dir, file) do
    path = Path.join(dir, file)

    if File.exists?(path) do
      path
      |> File.stream!(:line, [])
      |> Stream.flat_map(&decode/1)
    else
      []
    end
  end

  defp decode(line) do
    case Jason.decode(line) do
      {:ok, map} when is_map(map) -> [map]
      _ -> []
    end
  end

  defp name_map(entries, field \\ "name") do
    Enum.reduce(entries, %{}, fn entry, acc ->
      value = get_in(entry, [field, "en"])

      if is_integer(entry["_key"]) and is_binary(value) do
        Map.put(acc, entry["_key"], value)
      else
        acc
      end
    end)
  end

  defp group_map(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      if is_integer(entry["_key"]) do
        Map.put(acc, entry["_key"], %{
          name: name(entry),
          category_id: entry["categoryID"]
        })
      else
        acc
      end
    end)
  end

  defp operation_map(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      if is_integer(entry["_key"]) do
        Map.put(acc, entry["_key"], %{
          name: get_in(entry, ["operationName", "en"]),
          services: entry["services"] || []
        })
      else
        acc
      end
    end)
  end

  defp sun_map(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      system = entry["solarSystemID"]

      if is_integer(system) and not Map.has_key?(acc, system) do
        Map.put(acc, system, %{
          type_id: entry["typeID"],
          beacon_id: entry["effectBeaconTypeID"]
        })
      else
        acc
      end
    end)
  end

  defp star_map(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      case entry["solarSystemID"] do
        id when is_integer(id) ->
          statistics = entry["statistics"] || %{}

          Map.put(acc, id, %{
            spectral_class: statistics["spectralClass"],
            temperature: as_float(statistics["temperature"]),
            luminosity: as_float(statistics["luminosity"]),
            radius: as_float(entry["radius"])
          })

        _ ->
          acc
      end
    end)
  end

  defp referenced_type_ids(stations, suns) do
    station_ids = Enum.map(stations, & &1["typeID"])
    sun_ids = Enum.map(suns, fn {_system, sun} -> sun.type_id end)

    (station_ids ++ sun_ids)
    |> Enum.filter(&is_integer/1)
    |> MapSet.new()
  end

  defp effect_name(%{type_id: type_id}, names) when is_integer(type_id),
    do: Map.get(names, type_id)

  defp effect_name(_sun, _names), do: nil

  defp service_names(nil, _services), do: []

  defp service_names(%{services: ids}, services) do
    ids
    |> List.wrap()
    |> Enum.map(&Map.get(services, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defp name(entry), do: get_in(entry, ["name", "en"])

  defp as_float(value) when is_number(value), do: value * 1.0
  defp as_float(_value), do: nil

  defp require_file(path) do
    if File.regular?(path), do: :ok, else: {:error, {:missing_sde, path}}
  end

  defp read_version(path) do
    case :zip.unzip(String.to_charlist(path), [:memory, {:file_list, [~c"_sde.jsonl"]}]) do
      {:ok, [{_name, data}]} ->
        case Jason.decode(data) do
          {:ok, %{"buildNumber" => build} = entry} when is_integer(build) ->
            {:ok, %{build_number: build, release_date: entry["releaseDate"]}}

          _ ->
            {:error, :invalid_version}
        end

      _ ->
        {:error, :invalid_version}
    end
  end

  defp current?(version) do
    case Repo.get(Version, 1, log: false) do
      %Version{build_number: build} -> build == version.build_number
      _ -> false
    end
  rescue
    _ -> false
  end

  defp extract(path) do
    with {:ok, names} <- archive_names(path) do
      case Enum.reject(@required, &(&1 in names)) do
        [] ->
          dir = Path.join("tmp", "sde-sync-#{System.unique_integer([:positive, :monotonic])}")
          File.mkdir_p!(dir)
          wanted = Enum.filter(@files, &(&1 in names))

          options = [
            {:file_list, Enum.map(wanted, &String.to_charlist/1)},
            {:cwd, String.to_charlist(dir)}
          ]

          case :zip.extract(String.to_charlist(path), options) do
            {:ok, _} ->
              {:ok, dir}

            error ->
              File.rm_rf(dir)
              {:error, {:extract, error}}
          end

        missing ->
          {:error, {:missing_files, missing}}
      end
    end
  end

  defp archive_names(path) do
    case :zip.list_dir(String.to_charlist(path)) do
      {:ok, listing} ->
        {:ok,
         Enum.flat_map(listing, fn
           {:zip_file, name, _, _, _, _} -> [to_string(name)]
           _ -> []
         end)}

      error ->
        {:error, {:list, error}}
    end
  end
end
