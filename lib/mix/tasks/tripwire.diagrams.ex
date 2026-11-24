defmodule Mix.Tasks.Tripwire.Diagrams do
  use Mix.Task

  @shortdoc "Generate the database and architecture diagrams"

  @db_path "docs/db-schema.md"
  @arch_path "docs/architecture.md"
  @xref_path "tmp/xref-graph.json"

  @layers [
    {"Presentation", ["web/"]},
    {"Tooling", ["lib/mix/"]},
    {"Data Access", ["lib/tripwire/data.ex"]},
    {"Demo", ["lib/tripwire/demo.ex", "lib/tripwire/demo/"]},
    {"Persistence", ["lib/repo.ex", "lib/tripwire/ecto_types/"]},
    {"Integrations",
     [
       "lib/mailer.ex",
       "lib/tripwire/esi.ex",
       "lib/tripwire/esi/",
       "lib/tripwire/notifier.ex",
       "lib/tripwire/sso.ex",
       "lib/tripwire/systems/catalog.ex",
       "lib/tripwire/systems/gates.ex",
       "lib/tripwire/vault.ex",
       "lib/tripwire/zkill.ex"
     ]},
    {"Background",
     [
       "lib/application.ex",
       "lib/tripwire/sync_server.ex",
       "lib/tripwire/tracking/poller.ex",
       "lib/tripwire/tracking/poller_supervisor.ex"
     ]},
    {"Contexts", ["lib/"]}
  ]

  @external [
    {"EVE SSO", "ueberauth and `Tripwire.SSO` token refresh over HTTPS"},
    {"EVE ESI", "`Tripwire.ESI` location, ship, online, corporation and alliance endpoints"},
    {"zKillboard", "`Tripwire.ZKill` system activity statistics"},
    {"SDE archive",
     "`priv/sde` JSONL zip read into `Systems.Catalog` / `Systems.Gates` ETS tables"},
    {"Discord webhook", "`Tripwire.Notifier`"},
    {"SMTP", "`Tripwire.Mailer` through Swoosh"},
    {"EVE image CDN", "`Tripwire.EveImages` portrait, render and logo URLs"}
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    case :application.load(:tripwire) do
      :ok -> :ok
      {:error, {:already_loaded, :tripwire}} -> :ok
    end

    schemas = schemas()
    schema_paths = MapSet.new(schemas, fn {_source, module} -> source_path(module) end)
    relationships = relationships(schemas)
    unmodelled = unmodelled_tables(schemas)

    File.mkdir_p!("docs")
    File.write!(@db_path, db_markdown(schemas, relationships, unmodelled))
    File.write!(@arch_path, arch_markdown(schema_paths))

    Mix.shell().info(
      "#{length(schemas)} tables, #{length(relationships)} relationships -> #{@db_path}"
    )

    Mix.shell().info("architecture -> #{@arch_path}")

    if unmodelled != [] do
      Mix.shell().info("unmodelled tables: #{Enum.join(unmodelled, ", ")}")
    end
  end

  defp schemas do
    {:ok, modules} = :application.get_key(:tripwire, :modules)

    modules
    |> Enum.filter(fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
    end)
    |> Enum.map(fn module -> {module.__schema__(:source), module} end)
    |> Enum.sort()
  end

  defp source_path(module) do
    case module.module_info(:compile)[:source] do
      nil -> nil
      source -> source |> to_string() |> Path.relative_to_cwd()
    end
  end

  defp relationships(schemas) do
    for {source, module} <- schemas,
        name <- module.__schema__(:associations),
        %Ecto.Association.BelongsTo{} = association <- [module.__schema__(:association, name)],
        related = source_of(association.related),
        related != nil do
      {related, source, to_string(association.owner_key)}
    end
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp source_of(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1) do
      module.__schema__(:source)
    end
  end

  defp foreign_keys(module) do
    for name <- module.__schema__(:associations),
        %Ecto.Association.BelongsTo{} = association <- [module.__schema__(:association, name)],
        into: MapSet.new() do
      association.owner_key
    end
  end

  defp er_type({:array, _type}), do: "array"
  defp er_type({:map, _type}), do: "map"
  defp er_type({:parameterized, _module, _value}), do: "string"
  defp er_type(:id), do: "integer"
  defp er_type(:string), do: "string"
  defp er_type(:binary), do: "string"
  defp er_type(:integer), do: "integer"
  defp er_type(:float), do: "float"
  defp er_type(:boolean), do: "boolean"
  defp er_type(:decimal), do: "decimal"
  defp er_type(type) when type in [:utc_datetime, :utc_datetime_usec], do: "datetime"
  defp er_type(type) when type in [:naive_datetime, :naive_datetime_usec], do: "datetime"
  defp er_type(type) when type in [:date, :time], do: "datetime"
  defp er_type(type) when is_atom(type), do: "string"
  defp er_type(_type), do: "string"

  defp db_markdown(schemas, relationships, unmodelled) do
    entities =
      Enum.map(schemas, fn {source, module} ->
        primary_key = module.__schema__(:primary_key)
        foreign_keys = foreign_keys(module)

        fields =
          Enum.map(module.__schema__(:fields), fn field ->
            keys =
              cond do
                field in primary_key -> " PK"
                MapSet.member?(foreign_keys, field) -> " FK"
                true -> ""
              end

            "    #{er_type(module.__schema__(:type, field))} #{field}#{keys}"
          end)

        ["  #{source} {"] ++ fields ++ ["  }"]
      end)
      |> Enum.map(&Enum.join(&1, "\n"))

    edges =
      Enum.map(relationships, fn {parent, child, key} ->
        "  #{parent} ||--o{ #{child} : \"#{key}\""
      end)

    unmodelled_note =
      case unmodelled do
        [] ->
          "Every table created by the migrations has an Ecto schema."

        tables ->
          "Created by the migrations but missing from this diagram because they have no Ecto " <>
            "schema: " <>
            Enum.map_join(tables, ", ", &"`#{&1}`") <> "."
      end

    """
    # Database Schema

    Generated by `mix tripwire.diagrams` (`task diagram`). #{length(schemas)} tables and
    #{length(relationships)} relationships, reflected from the Ecto schemas; primary keys are
    marked `PK` and foreign keys `FK`.

    ```mermaid
    erDiagram
    #{Enum.join(entities, "\n")}
    #{Enum.join(edges, "\n")}
    ```

    ## Not modelled

    #{unmodelled_note}
    """
  end

  defp arch_markdown(schema_paths) do
    {graph, failure} =
      try do
        {xref_graph!(), nil}
      rescue
        error -> {%{}, Exception.message(error)}
      end

    assignments =
      Map.new(Map.keys(graph), fn path -> {path, layer_of(path, schema_paths)} end)

    counts =
      Enum.frequencies_by(
        for {source, targets} <- graph,
            {target, _label} <- targets,
            from = assignments[source],
            to = assignments[target],
            from != nil and to != nil and from != to do
          {from, to}
        end,
        & &1
      )

    files =
      Enum.reduce(assignments, %{}, fn {_path, layer}, acc ->
        Map.update(acc, layer, 1, &(&1 + 1))
      end)

    unassigned =
      assignments
      |> Enum.filter(fn {path, layer} ->
        layer == nil and String.starts_with?(path, ["lib/", "web/"])
      end)
      |> Enum.map(fn {path, _layer} -> path end)
      |> Enum.sort()

    order = Enum.map(@layers, fn {name, _prefixes} -> name end)

    nodes =
      Enum.map(order, fn name ->
        id = node_id(name)

        case Map.fetch(files, name) do
          {:ok, count} ->
            unit = if count == 1, do: "file", else: "files"
            "  #{id}[\"#{name}<br/>#{count} #{unit}\"]"

          :error ->
            "  #{id}[\"#{name}\"]"
        end
      end)

    edges =
      counts
      |> Enum.sort_by(fn {{from, to}, _count} -> {index(order, from), index(order, to)} end)
      |> Enum.map(fn {{from, to}, count} -> "  #{node_id(from)} -->|#{count}| #{node_id(to)}" end)

    table =
      Enum.map(@layers, fn {name, prefixes} ->
        paths = Enum.map_join(prefixes, ", ", &"`#{&1}`")
        count = Map.get(files, name) || "-"
        "| #{name} | #{count} | #{paths} |"
      end)

    external =
      Enum.map(@external, fn {name, description} -> "- **#{name}**: #{description}" end)

    drift =
      case {failure, unassigned} do
        {nil, []} ->
          "Every module under `lib/` and `web/` belongs to a layer."

        {message, []} ->
          "`mix xref graph` failed (`#{String.split(message, "\n") |> hd()}`), so the layer " <>
            "edges are missing from this run."

        {nil, paths} ->
          "Not assigned to a layer: " <> Enum.map_join(paths, ", ", &"`#{&1}`") <> "."

        {message, paths} ->
          "`mix xref graph` failed (`#{String.split(message, "\n") |> hd()}`) and these modules " <>
            "are not assigned to a layer: " <> Enum.map_join(paths, ", ", &"`#{&1}`") <> "."
      end

    """
    # Architecture

    Generated by `mix tripwire.diagrams` (`task diagram`). The layers are declared by path in
    `Mix.Tasks.Tripwire.Diagrams`; each arrow is drawn only when `mix xref graph` sees at least
    one reference from the source layer to the target layer, and is labelled with the number of
    references. `Data Access` is `Tripwire.Data`, which resolves every read and write to either
    the database (`Persistence`) or the in-memory demo (`Demo`), so both arrows leave that layer.

    ```mermaid
    flowchart TD
    #{Enum.join(nodes, "\n")}
    #{Enum.join(edges, "\n")}
    ```

    ## Layers

    | Layer | Files | Paths |
    |---|---|---|
    #{Enum.join(table, "\n")}

    ## External services

    #{Enum.join(external, "\n")}

    ## Coverage

    #{drift}
    """
  end

  defp xref_graph! do
    File.mkdir_p!("tmp")
    Mix.Task.run("xref", ["graph", "--format", "json", "--output", @xref_path])
    graph = @xref_path |> File.read!() |> Jason.decode!()
    File.rm(@xref_path)
    graph
  end

  defp layer_of(path, schema_paths) do
    cond do
      MapSet.member?(schema_paths, path) ->
        "Persistence"

      true ->
        Enum.find_value(@layers, fn {name, prefixes} ->
          if Enum.any?(prefixes, &prefix_match?(path, &1)), do: name
        end)
    end
  end

  defp prefix_match?(path, prefix) do
    path == prefix or String.starts_with?(path, prefix)
  end

  defp node_id(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
  end

  defp index(order, name), do: Enum.find_index(order, &(&1 == name)) || 0

  defp unmodelled_tables(schemas) do
    modelled = MapSet.new(schemas, fn {source, _module} -> source end)

    "priv/repo/migrations/*.exs"
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      Regex.scan(~r/create table\(:([a-z_]+)/, File.read!(path), capture: :all_but_first)
    end)
    |> Enum.map(fn [table] -> table end)
    |> Enum.uniq()
    |> Enum.reject(&MapSet.member?(modelled, &1))
    |> Enum.sort()
  end
end
