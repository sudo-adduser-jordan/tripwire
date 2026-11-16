defmodule Tripwire.Mapping do
  import Ecto.Query

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping.{Map, MapConnection, MapSystem, Signature}
  alias Tripwire.Repo

  def get_map!(id), do: Repo.get!(Map, id)

  def list_maps_for_mask(mask_id) do
    Repo.all(from(m in Map, where: m.mask_id == ^mask_id))
  end

  def create_map(attrs) do
    %Map{}
    |> Map.changeset(attrs)
    |> Repo.insert()
  end

  def list_systems(map_id) do
    Repo.all(from(s in MapSystem, where: s.map_id == ^map_id, order_by: [asc: s.id]))
  end

  def get_system!(id), do: Repo.get!(MapSystem, id)

  def get_system(id), do: Repo.get(MapSystem, id)

  def list_connections(map_id) do
    Repo.all(
      from(c in MapConnection,
        where: c.map_id == ^map_id,
        preload: [:from_system, :to_system],
        order_by: [asc: c.id]
      )
    )
  end

  @doc """
  Lists connections as `{connection, from_system, to_system}` tuples for
  direct use by the chain-map renderer.
  """
  def list_connections_with_endpoints(map_id) do
    map_id
    |> list_connections()
    |> Enum.map(fn conn -> {conn, conn.from_system, conn.to_system} end)
  end

  # ViewBox is 1000x700 and nodes are 80x50, so origins clamp to 920x650.
  @layout_max_x 920.0
  @layout_max_y 650.0

  @doc """
  Groups system ids into `{depth, [id]}` layers, sorted by depth. Depths
  come from breadth-first search over the undirected graph, seeded at
  systems with no incoming links so disconnected components each form
  their own subtree.
  """
  def depth_layers(systems, connections) do
    ids = Enum.map(systems, & &1.id)

    {adj, incoming} =
      Enum.reduce(connections, {%{}, Elixir.MapSet.new()}, fn {_conn, from, to}, {adj, inc} ->
        adj =
          adj
          |> Elixir.Map.update(from.id, [to.id], &[to.id | &1])
          |> Elixir.Map.update(to.id, [from.id], &[from.id | &1])

        {adj, Elixir.MapSet.put(inc, to.id)}
      end)

    adj = Enum.reduce(ids, adj, &Elixir.Map.put_new(&2, &1, []))
    seeds = Enum.filter(ids, &(!Elixir.MapSet.member?(incoming, &1)))
    seeds = if seeds == [], do: ids, else: seeds ++ (ids -- seeds)

    depths =
      Enum.reduce(seeds, %{}, fn seed, depths ->
        if Elixir.Map.has_key?(depths, seed), do: depths, else: bfs_depths(adj, depths, seed)
      end)

    ids
    |> Enum.group_by(&Elixir.Map.fetch!(depths, &1))
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {depth, members} -> {depth, Enum.sort(members)} end)
  end

  @doc """
  Arranges `systems` radially around the root: depth-0 systems sit at the
  center and each deeper layer spreads evenly over a wider ring.
  `connections` are `{conn, from, to}` endpoint tuples. Returns
  `%{system_id => %{x: float, y: float}}`.
  """
  def radial_layout(systems, connections) do
    systems
    |> depth_layers(connections)
    |> Enum.flat_map(fn {depth, members} ->
      n = length(members)
      radius = if depth == 0 and n == 1, do: 0.0, else: min(150.0 * max(depth, 1), 330.0)

      Enum.with_index(members, fn id, i ->
        angle = 2 * :math.pi() * i / max(n, 1) + depth * 0.5

        {id,
         {clamp_x(460.0 + radius * :math.cos(angle)), clamp_y(325.0 + radius * :math.sin(angle))}}
      end)
    end)
    |> Elixir.Map.new(fn {id, {x, y}} -> {id, %{x: x, y: y}} end)
  end

  @doc """
  Arranges `systems` as a tree for the given `orientation`:

  - `"down"` — root at the top, leaves grow down (default)
  - `"up"` — root at the bottom, leaves grow up
  - `"right"` — root at the left, leaves grow right
  - `"left"` — root at the right, leaves grow left

  `connections` are `{conn, from, to}` endpoint tuples. Returns
  `%{system_id => %{x: float, y: float}}`.
  """
  def tree_layout(systems, connections, orientation \\ "down") do
    systems
    |> depth_layers(connections)
    |> Enum.flat_map(fn {depth, members} ->
      n = length(members)

      Enum.with_index(members, fn id, i ->
        {id, orient_position(orientation, depth, n, i)}
      end)
    end)
    |> Elixir.Map.new(fn {id, {x, y}} -> {id, %{x: x, y: y}} end)
  end

  defp bfs_depths(adj, depths, seed) do
    base = depths |> Elixir.Map.values() |> Enum.max(fn -> -1 end)
    bfs_loop(adj, :queue.from_list([seed]), Elixir.Map.put(depths, seed, base + 1))
  end

  defp bfs_loop(adj, queue, depths) do
    case :queue.out(queue) do
      {:empty, _} ->
        depths

      {{:value, id}, rest} ->
        depth = Elixir.Map.fetch!(depths, id)

        {queue, depths} =
          Enum.reduce(adj[id] || [], {rest, depths}, fn neighbor, {q, d} ->
            if Elixir.Map.has_key?(d, neighbor),
              do: {q, d},
              else: {:queue.in(neighbor, q), Elixir.Map.put(d, neighbor, depth + 1)}
          end)

        bfs_loop(adj, queue, depths)
    end
  end

  defp orient_position(orientation, depth, n, i) do
    mid = (n - 1) / 2

    case orientation do
      "up" ->
        {clamp_x(460.0 + (i - mid) * 150.0), clamp_y(590.0 - depth * 160.0)}

      "left" ->
        {clamp_x(860.0 - depth * 170.0), clamp_y(325.0 + (i - mid) * 120.0)}

      "right" ->
        {clamp_x(60.0 + depth * 170.0), clamp_y(325.0 + (i - mid) * 120.0)}

      _ ->
        {clamp_x(460.0 + (i - mid) * 150.0), clamp_y(60.0 + depth * 160.0)}
    end
  end

  defp clamp_x(value), do: value |> max(0.0) |> min(@layout_max_x)
  defp clamp_y(value), do: value |> max(0.0) |> min(@layout_max_y)

  @doc """
  Finds a connection between two systems in either direction and updates it,
  or creates it if none exists. Returns {:ok, connection} and whether it is new.
  """
  def upsert_connection(map_id, system_a_id, system_b_id, attrs \\ %{}) do
    connection =
      Repo.one(
        from(c in MapConnection,
          where:
            c.map_id == ^map_id and
              ((c.from_system_id == ^system_a_id and c.to_system_id == ^system_b_id) or
                 (c.from_system_id == ^system_b_id and c.to_system_id == ^system_a_id))
        )
      )

    case connection do
      %MapConnection{} = conn ->
        {:ok, conn} =
          conn
          |> MapConnection.changeset(merge_attrs(attrs, %{map_id: conn.map_id}))
          |> Repo.update()

        {:ok, conn, false}

      nil ->
        changeset =
          %MapConnection{}
          |> MapConnection.changeset(
            merge_attrs(attrs, %{
              map_id: map_id,
              from_system_id: system_a_id,
              to_system_id: system_b_id
            })
          )

        case Repo.insert(changeset) do
          {:ok, conn} -> {:ok, Repo.preload(conn, [:from_system, :to_system]), true}
          error -> error
        end
    end
  end

  def add_system_to_map(%Map{} = map, attrs) do
    %MapSystem{map_id: map.id}
    |> MapSystem.changeset(attrs)
    |> Repo.insert()
  end

  def update_system_position(%MapSystem{} = system, x, y) do
    system
    |> Ecto.Changeset.change(x: x, y: y)
    |> Repo.update()
  end

  def list_signatures(system_id) do
    Repo.all(
      from(s in Signature,
        where: s.map_system_id == ^system_id,
        order_by: [asc: s.sig_id]
      )
    )
  end

  @doc """
  Inserts or updates signatures for a system from parsed scan results.

  Returns `{inserted, updated}` counts.
  """
  def upsert_signatures(%MapSystem{} = system, entries, %Character{id: character_id})
      when is_list(entries) do
    Enum.reduce(entries, {0, 0}, fn entry, {added, updated} ->
      attrs = %{
        map_system_id: system.id,
        sig_id: entry.sig_id,
        kind: to_string(entry.kind),
        type_name: entry.name || entry.wormhole_type,
        updated_by_id: character_id
      }

      existing = Repo.get_by(Signature, map_system_id: system.id, sig_id: entry.sig_id)

      result =
        case existing do
          %Signature{} = signature ->
            signature
            |> Signature.changeset(merge_attrs(attrs, %{created_by_id: signature.created_by_id}))
            |> Repo.update()

          nil ->
            %Signature{}
            |> Signature.changeset(merge_attrs(attrs, %{created_by_id: character_id}))
            |> Repo.insert()
        end

      case {result, existing} do
        {{:ok, _}, nil} -> {added + 1, updated}
        {{:ok, _}, _signature} -> {added, updated + 1}
        {{:error, _}, _} -> {added, updated}
      end
    end)
  end

  def create_signature(%MapSystem{} = system, attrs, %Character{id: character_id}) do
    %Signature{}
    |> Signature.changeset(
      merge_attrs(attrs, %{
        map_system_id: system.id,
        created_by_id: character_id,
        updated_by_id: character_id
      })
    )
    |> Repo.insert()
  end

  def update_signature(%Signature{} = signature, attrs, %Character{id: character_id}) do
    signature
    |> Signature.changeset(merge_attrs(attrs, %{updated_by_id: character_id}))
    |> Repo.update()
  end

  def delete_signature(%Signature{} = signature), do: Repo.delete(signature)

  def get_signature!(id), do: Repo.get!(Signature, id)

  def list_comments(system_id) do
    Repo.all(
      from(c in Tripwire.Mapping.Comment,
        where: c.map_system_id == ^system_id,
        order_by: [asc: c.id],
        preload: [:character]
      )
    )
  end

  def create_comment(%MapSystem{} = system, attrs, character \\ nil) do
    character_id = if is_struct(character, Character), do: character.id, else: nil

    %Tripwire.Mapping.Comment{}
    |> Tripwire.Mapping.Comment.changeset(
      merge_attrs(attrs, %{map_system_id: system.id, character_id: character_id})
    )
    |> Repo.insert()
  end

  def delete_comment(%Tripwire.Mapping.Comment{} = comment), do: Repo.delete(comment)

  def get_comment!(id), do: Repo.get!(Tripwire.Mapping.Comment, id)

  @demo_systems [
    %{solar_system_id: 31_000_001, name: "J150321", x: 120.0, y: 120.0},
    %{solar_system_id: 31_000_002, name: "J150322", x: 360.0, y: 260.0},
    %{solar_system_id: 31_000_003, name: "J150323", x: 600.0, y: 140.0},
    %{solar_system_id: 31_000_004, name: "J150324", x: 780.0, y: 330.0},
    %{solar_system_id: 31_000_005, name: "J150325", x: 480.0, y: 470.0}
  ]

  @demo_links [
    {0, 1, "C3", "stable"},
    {1, 2, "K162", "stable"},
    {2, 3, "EOL", "eol"},
    {2, 4, "C2", "stable"}
  ]

  def ensure_demo_map(mask_id) do
    map =
      case list_maps_for_mask(mask_id) do
        [map | _] -> map
        [] -> elem(create_map(%{name: "Demo", mask_id: mask_id}), 1)
      end

    if list_systems(map.id) == [] do
      systems =
        Enum.map(@demo_systems, fn attrs ->
          {:ok, system} = add_system_to_map(map, attrs)
          system
        end)

      Enum.each(@demo_links, fn {from_idx, to_idx, hole_type, time_status} ->
        {:ok, _, _} =
          upsert_connection(
            map.id,
            Enum.at(systems, from_idx).id,
            Enum.at(systems, to_idx).id,
            %{hole_type: hole_type, time_status: time_status}
          )
      end)
    end

    {:ok, get_map!(map.id)}
  end

  defp merge_attrs(attrs, extra), do: Elixir.Map.merge(attrs, extra)
end
