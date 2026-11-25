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

  @stack [
    "Presentation",
    "Tooling",
    "Data Access",
    "Demo",
    "Background",
    "Contexts",
    "Persistence",
    "Integrations"
  ]

  @fills %{
    "Presentation" => "#e7f5ff",
    "Tooling" => "#f1f3f5",
    "Data Access" => "#ffe3e3",
    "Demo" => "#f3f0ff",
    "Background" => "#ffe8cc",
    "Contexts" => "#d0ebff",
    "Persistence" => "#fff3bf",
    "Integrations" => "#d3f9d8"
  }

  @classes %{
    "#e7f5ff" => "blue",
    "#f1f3f5" => "gray",
    "#ffe3e3" => "rose",
    "#f3f0ff" => "violet",
    "#ffe8cc" => "orange",
    "#d0ebff" => "cyan",
    "#fff3bf" => "yellow",
    "#d3f9d8" => "green"
  }

  @children [
    {"TripwireWeb.Telemetry", ["Supervisor · logger + metrics", "polls every 60s"], "#e7f5ff"},
    {"Tripwire.Repo", ["Ecto repo · SQLite", "priv/db · serialized writes"], "#fff3bf"},
    {"Tripwire.Vault", ["Cloak vault", "field encryption at rest"], "#f3f0ff"},
    {"Tripwire.ESI.TokenCache", ["GenServer · public ETS", "access + rotated refresh tokens"],
     "#d3f9d8"},
    {"Tripwire.Systems.Catalog", ["GenServer · ETS", "mapSolarSystems from priv/sde"], "#d3f9d8"},
    {"Tripwire.Systems.Gates", ["GenServer · bag ETS", "mapStargates in both directions"],
     "#d3f9d8"},
    {"Phoenix.PubSub", ["name: Tripwire.PubSub", "map_updated topics"], "#e7f5ff"},
    {"Tracking.PollerSupervisor", ["DynamicSupervisor, :one_for_one", "one poller per character"],
     "#e7f5ff"},
    {"Registry", ["name: Tripwire.TrackingRegistry", "keys: :unique"], "#e7f5ff"},
    {"Tripwire.SyncServer",
     ["GenServer · corp sync every 3 min", "prune_orphan_masks · hourly zKill"], "#e7f5ff"},
    {"DNSCluster", ["query from :dns_cluster_query", ":ignore when unset"], "#f1f3f5"},
    {"TripwireWeb.Endpoint", ["Phoenix endpoint · Bandit", "LiveView · port 4000"], "#e7f5ff"}
  ]

  @grandchildren [
    {"Tripwire.Repo", "DBConnection pool", ["SQLite connection", "one writer at a time"],
     "#fff3bf"},
    {"Tracking.PollerSupervisor", "Tracking.Poller x N",
     ["GenServer, :permanent", "via {:poller, eve_id} · 10s ESI tick", "reports → PubSub"],
     "#d3f9d8"},
    {"TripwireWeb.Endpoint", "Bandit listener", [":http · port 4000"], "#e7f5ff"},
    {"TripwireWeb.Endpoint", "LiveView processes x N",
     ["one per dashboard socket", "DashboardLive · demo"], "#e7f5ff"}
  ]

  @relations [
    {"Tracking.Poller x N", "Registry", "via {:poller, eve_id}"},
    {"Tracking.Poller x N", "Phoenix.PubSub", "broadcast {:map_updated, map_id}"},
    {"LiveView processes x N", "Tracking.PollerSupervisor", "start_child"}
  ]

  @external [
    {"EVE SSO", "ueberauth and `Tripwire.SSO` token refresh over HTTPS"},
    {"EVE ESI", "`Tripwire.ESI` location, ship, online, corporation and alliance endpoints"},
    {"zKillboard", "`Tripwire.ZKill` system activity statistics"},
    {"SDE archive",
     "`priv/sde` JSONL zip read into `Systems.Catalog` / `Systems.Gates` ETS tables"},
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

    table =
      Enum.map(@stack, fn name ->
        {^name, prefixes} = Enum.find(@layers, fn {layer, _prefixes} -> layer == name end)
        paths = Enum.map_join(prefixes, ", ", &"`#{&1}`")
        count = Map.get(files, name) || "-"
        "| #{name} | #{count} | #{paths} |"
      end)

    drift =
      case {failure, unassigned} do
        {nil, []} ->
          "Every module under `lib/` and `web/` belongs to a layer."

        {message, []} ->
          "`mix xref graph` failed (`#{String.split(message, "\n") |> hd()}`), so the layer " <>
            "arrows are missing from this run."

        {nil, paths} ->
          "Not assigned to a layer: " <> Enum.map_join(paths, ", ", &"`#{&1}`") <> "."

        {message, paths} ->
          "`mix xref graph` failed (`#{String.split(message, "\n") |> hd()}`) and these modules " <>
            "are not assigned to a layer: " <> Enum.map_join(paths, ", ", &"`#{&1}`") <> "."
      end

    """
    # Architecture

    Generated by `mix tripwire.diagrams` (`task diagram`). Both diagrams are Mermaid flowcharts,
    so GitHub renders them as SVG. The supervision tree covers every child `Tripwire.Application`
    starts and its descendants: solid arrows are child specs, dashed arrows are the runtime
    relations that are not child specs. The layer map declares its layers by path in
    `Mix.Tasks.Tripwire.Diagrams`; an arrow is drawn only when `mix xref graph` sees at least one
    reference from the source layer to the target layer, labelled with that count, solid for a
    forward reference and dashed for a back reference. `Data Access` is `Tripwire.Data`, which
    resolves every read and write to either the database (`Persistence`) or the in-memory demo
    (`Demo`), so both arrows leave that layer.

    ## Supervision tree

    #{String.trim_trailing(supervision_mermaid())}

    ## Layers

    #{String.trim_trailing(layer_mermaid(counts, files))}

    | Layer | Files | Paths |
    |---|---|---|
    #{Enum.join(table, "\n")}

    ## External services

    #{Enum.map_join(@external, "\n", fn {name, description} -> "- **#{name}**: #{description}" end)}

    ## Coverage

    #{drift}
    """
  end

  defp supervision_mermaid do
    root = "Tripwire.Supervisor"

    root_node =
      node(
        root,
        ["Supervisor, :one_for_one", "lib/application.ex"],
        "#ffe3e3"
      )

    children =
      Enum.map(@children, fn {title, lines, fill} -> node(title, lines, fill) end)

    grandchildren =
      Enum.map(@grandchildren, fn {_parent, title, lines, fill} -> node(title, lines, fill) end)

    supervision_edges =
      Enum.map(@children, fn {title, _lines, _fill} ->
        "  #{node_id(root)} --> #{node_id(title)}"
      end) ++
        Enum.map(@grandchildren, fn {parent, title, _lines, _fill} ->
          "  #{node_id(parent)} --> #{node_id(title)}"
        end)

    relation_edges =
      Enum.map(@relations, fn {from, to, label} ->
        "  #{node_id(from)} -.->|\"#{escape(label)}\"| #{node_id(to)}"
      end)

    used =
      ["#ffe3e3"] ++
        Enum.map(@children, fn {_title, _lines, fill} -> fill end) ++
        Enum.map(@grandchildren, fn {_parent, _title, _lines, fill} -> fill end)

    """
    ```mermaid
    %%{init: {"theme": "base", "flowchart": {"curve": "basis", "nodeSpacing": 60, "rankSpacing": 100, "wrappingWidth": 200}, "themeVariables": {"fontFamily": "sans-serif", "lineColor": "#1e1e1e", "primaryTextColor": "#1e1e1e"}}}%%
    flowchart LR
      subgraph root_column["root"]
        #{root_node}
      end
      subgraph child_column["children of Tripwire.Supervisor"]
    #{Enum.map_join(children, "\n", &"    #{&1}")}
      end
      subgraph grandchild_column["grandchildren"]
    #{Enum.map_join(grandchildren, "\n", &"    #{&1}")}
      end
    #{Enum.join(supervision_edges, "\n")}
    #{Enum.join(relation_edges, "\n")}
    #{class_defs(used)}
    ```
    """
  end

  defp layer_mermaid(counts, files) do
    nodes =
      Enum.map(@stack, fn name ->
        count = Map.get(files, name) || 0

        node(
          name,
          ["#{count} #{if count == 1, do: "file", else: "files"}"],
          Map.get(@fills, name)
        )
      end)

    index = Map.new(Enum.with_index(@stack))

    edges =
      counts
      |> Enum.sort_by(fn {{from, to}, _count} -> {index[from], index[to]} end)
      |> Enum.map(fn {{from, to}, count} ->
        if index[to] > index[from] do
          "  #{node_id(from)} -->|#{count}| #{node_id(to)}"
        else
          "  #{node_id(from)} -.->|#{count}| #{node_id(to)}"
        end
      end)

    used = Enum.map(@stack, &Map.get(@fills, &1))

    """
    ```mermaid
    %%{init: {"theme": "base", "flowchart": {"curve": "basis", "nodeSpacing": 60, "rankSpacing": 100, "wrappingWidth": 200}, "themeVariables": {"fontFamily": "sans-serif", "lineColor": "#1e1e1e", "primaryTextColor": "#1e1e1e"}}}%%
    flowchart TD
    #{Enum.map_join(nodes, "\n", &"  #{&1}")}
    #{Enum.join(edges, "\n")}
    #{class_defs(used)}
    ```
    """
  end

  defp node(title, lines, fill) do
    label = ["<b>#{escape(title)}</b>" | Enum.map(lines, &escape/1)] |> Enum.join("<br/>")

    ~s(#{node_id(title)}["#{label}"]:::#{Map.get(@classes, fill, "gray")})
  end

  defp class_defs(fills) do
    fills
    |> Enum.uniq()
    |> Enum.map(fn fill ->
      "  classDef #{Map.get(@classes, fill, "gray")} fill:#{fill},stroke:#1e1e1e,stroke-width:2px,color:#1e1e1e"
    end)
    |> Enum.join("\n")
  end

  defp node_id(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  defp escape(value) when is_binary(value) do
    String.replace(value, "\"", "&quot;")
  end

  defp escape(value), do: value |> to_string() |> escape()

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
