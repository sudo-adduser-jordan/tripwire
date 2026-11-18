defmodule Tripwire.Mapping do
  import Ecto.Query

  alias Tripwire.Accounts
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

  def update_map(%Map{} = map, attrs) do
    map
    |> Map.changeset(attrs)
    |> Repo.update()
  end

  @thera_solar_system_id 31_000_005
  @thera_name "Thera"

  def thera_solar_system_id, do: @thera_solar_system_id
  def thera_name, do: @thera_name

  @doc """
  Favorite systems on other maps of the same mask, excluding `exclude_map_id`.
  """
  def list_favorite_candidates(mask_id, exclude_map_id) do
    map_ids =
      from(m in Map, where: m.mask_id == ^mask_id and m.id != ^exclude_map_id, select: m.id)

    Repo.all(
      from(s in MapSystem,
        where: s.map_id in subquery(map_ids) and s.favorite == true,
        order_by: [asc: s.id]
      )
    )
  end

  @doc """
  True when a recorded wormhole connection on any same-mask map links
  `candidate_solar_id` to one of `chain_solar_ids`.
  """
  def recorded_wormhole_link?(mask_id, candidate_solar_id, chain_solar_ids) do
    chain_set = Elixir.MapSet.new(chain_solar_ids)

    if Elixir.MapSet.member?(chain_set, candidate_solar_id) do
      false
    else
      map_ids = from(m in Map, where: m.mask_id == ^mask_id, select: m.id)

      links =
        Repo.all(
          from(c in MapConnection,
            where: c.map_id in subquery(map_ids),
            preload: [:from_system, :to_system]
          )
        )

      Enum.any?(links, fn conn ->
        from_solar = conn.from_system && conn.from_system.solar_system_id
        to_solar = conn.to_system && conn.to_system.solar_system_id

        (from_solar == candidate_solar_id and Elixir.MapSet.member?(chain_set, to_solar)) or
          (to_solar == candidate_solar_id and Elixir.MapSet.member?(chain_set, from_solar))
      end)
    end
  end

  @doc """
  Finds the chain system (from `chain_systems`) that a recorded connection
  links `candidate_solar_id` to, or nil.
  """
  def wormhole_link_target(mask_id, candidate_solar_id, chain_systems) do
    by_solar = Elixir.Map.new(chain_systems, &{&1.solar_system_id, &1})
    chain_set = Elixir.MapSet.new(Elixir.Map.keys(by_solar))
    map_ids = from(m in Map, where: m.mask_id == ^mask_id, select: m.id)

    links =
      Repo.all(
        from(c in MapConnection,
          where: c.map_id in subquery(map_ids),
          preload: [:from_system, :to_system]
        )
      )

    Enum.find_value(links, fn conn ->
      from_solar = conn.from_system && conn.from_system.solar_system_id
      to_solar = conn.to_system && conn.to_system.solar_system_id

      cond do
        from_solar == candidate_solar_id and Elixir.MapSet.member?(chain_set, to_solar) ->
          {by_solar[to_solar], conn.hole_type}

        to_solar == candidate_solar_id and Elixir.MapSet.member?(chain_set, from_solar) ->
          {by_solar[from_solar], conn.hole_type}

        true ->
          nil
      end
    end)
  end

  @doc """
  Ensures a system with `solar_system_id` exists on `map`, creating it when
  missing. Returns `{:ok, system, created?}`.
  """
  def ensure_chain_system(%Map{} = map, attrs) do
    solar_id = attrs[:solar_system_id] || attrs["solar_system_id"]

    case Repo.get_by(MapSystem, map_id: map.id, solar_system_id: solar_id) do
      %MapSystem{} = system ->
        {:ok, system, false}

      nil ->
        position = %{x: 460.0, y: 300.0}

        case add_system_to_map(map, Elixir.Map.merge(%{x: position.x, y: position.y}, attrs)) do
          {:ok, system} -> {:ok, system, true}
          error -> error
        end
    end
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

  @pan_pad_y 40

  @doc """
  Clamps a chain-map pan origin only to the top edge: the viewport never
  pans above the topmost node, keeping a small margin above it. All other
  directions pan freely. Returns `{x, y}` floats.
  """
  def clamp_pan(systems, x, y) do
    {x, clamp_top(systems, y)}
  end

  defp clamp_top([], value), do: value

  defp clamp_top(systems, value) do
    top = systems |> Enum.map(&(&1.y - @pan_pad_y)) |> Enum.min()
    max(value, top)
  end

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
  def radial_layout(systems, connections, spacing \\ 1.0) do
    systems
    |> depth_layers(connections)
    |> Enum.flat_map(fn {depth, members} ->
      n = length(members)
      radius = if depth == 0 and n == 1, do: 0.0, else: 150.0 * spacing * max(depth, 1)

      Enum.with_index(members, fn id, i ->
        angle = 2 * :math.pi() * i / max(n, 1) + depth * 0.5

        {id, {460.0 + radius * :math.cos(angle), 325.0 + radius * :math.sin(angle)}}
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

  Children are centered beneath their parent (tidy tree) at their
  breadth-first depth from the root, mirroring the Tripwire chain
  tree: each jump lands one level down and siblings share a row.
  """
  def tree_layout(systems, connections, orientation \\ "down", spacing \\ 1.0, opts \\ []) do
    ids = Enum.map(systems, & &1.id)

    if ids == [] do
      %{}
    else
      adj = undirected_adj(ids, connections)
      roots = tree_roots(ids, connections, opts)
      {parent, children, depths} = spanning_tree(adj, roots, ids)
      _ = parent
      x_index = assign_x_index(roots, children)

      leaf_count =
        case Elixir.Map.values(x_index) do
          [] -> 1
          values -> values |> Enum.max() |> Kernel.+(1)
        end

      mid = (leaf_count - 1) / 2

      Elixir.Map.new(ids, fn id ->
        xi = Elixir.Map.get(x_index, id, mid)
        depth = Elixir.Map.get(depths, id, 0)
        {x, y} = orient_tidy_position(orientation, depth, xi, mid, spacing)
        {id, %{x: x, y: y}}
      end)
    end
  end

  @doc """
  Returns the ids of systems that sit on a loop (cycle), including
  self-loops, as a `MapSet`. `connections` are `{conn, from, to}`
  endpoint tuples.
  """
  def loop_system_ids(connections) do
    {degree, neighbors, self_loops} =
      Enum.reduce(connections, {%{}, %{}, Elixir.MapSet.new()}, fn
        {_conn, from, to}, {deg, nbrs, loops} when from.id == to.id ->
          {deg, nbrs, Elixir.MapSet.put(loops, from.id)}

        {_conn, from, to}, {deg, nbrs, loops} ->
          deg =
            deg
            |> Elixir.Map.update(from.id, 1, &(&1 + 1))
            |> Elixir.Map.update(to.id, 1, &(&1 + 1))

          nbrs =
            nbrs
            |> Elixir.Map.update(from.id, [to.id], &[to.id | &1])
            |> Elixir.Map.update(to.id, [from.id], &[from.id | &1])

          {deg, nbrs, loops}
      end)

    queue =
      degree
      |> Enum.filter(fn {_id, d} -> d <= 1 end)
      |> Enum.map(&elem(&1, 0))
      |> :queue.from_list()

    pruned = prune_leaves(queue, degree, neighbors, Elixir.MapSet.new())

    cycle_ids =
      degree
      |> Elixir.Map.keys()
      |> Enum.reject(&Elixir.MapSet.member?(pruned, &1))

    Enum.reduce(cycle_ids, self_loops, &Elixir.MapSet.put(&2, &1))
  end

  defp prune_leaves(queue, degree, neighbors, pruned) do
    case :queue.out(queue) do
      {:empty, _} ->
        pruned

      {{:value, id}, rest} ->
        if Elixir.MapSet.member?(pruned, id) do
          prune_leaves(rest, degree, neighbors, pruned)
        else
          pruned = Elixir.MapSet.put(pruned, id)

          {queue, degree} =
            Enum.reduce(Elixir.Map.get(neighbors, id, []), {rest, degree}, fn nbr, {q, deg} ->
              if Elixir.MapSet.member?(pruned, nbr) do
                {q, deg}
              else
                new_deg = Elixir.Map.get(deg, nbr, 1) - 1
                deg = Elixir.Map.put(deg, nbr, new_deg)

                if new_deg <= 1 do
                  {:queue.in(nbr, q), deg}
                else
                  {q, deg}
                end
              end
            end)

          prune_leaves(queue, degree, neighbors, pruned)
        end
    end
  end

  defp undirected_adj(ids, connections) do
    base =
      Enum.reduce(connections, %{}, fn {_conn, from, to}, acc ->
        if from.id == to.id do
          Elixir.Map.put_new(acc, from.id, [])
        else
          acc
          |> Elixir.Map.update(from.id, [to.id], &[to.id | &1])
          |> Elixir.Map.update(to.id, [from.id], &[from.id | &1])
        end
      end)

    Enum.reduce(ids, base, fn id, acc ->
      acc
      |> Elixir.Map.put_new(id, [])
      |> Elixir.Map.update!(id, &(&1 |> Enum.uniq() |> Enum.sort()))
    end)
  end

  defp tree_roots(ids, connections, opts) do
    case Keyword.get(opts, :root_id) do
      nil ->
        incoming =
          Enum.reduce(connections, Elixir.MapSet.new(), fn {_conn, _from, to}, acc ->
            Elixir.MapSet.put(acc, to.id)
          end)

        roots = Enum.filter(ids, &(!Elixir.MapSet.member?(incoming, &1)))
        if roots == [], do: [ids |> Enum.sort() |> hd()], else: Enum.sort(roots)

      root_id ->
        if root_id in ids, do: [root_id], else: [ids |> Enum.sort() |> hd()]
    end
  end

  defp spanning_tree(adj, roots, ids) do
    depths = Elixir.Map.new(roots, &{&1, 0})
    parent = Elixir.Map.new(roots, &{&1, nil})
    children = Elixir.Map.new(ids, &{&1, []})
    queue = :queue.from_list(roots)
    visited = Elixir.MapSet.new(roots)
    {depths, parent, children, visited} = bfs_fill(queue, adj, visited, depths, parent, children)

    Enum.reduce(Enum.sort(ids), {parent, children, depths, visited}, fn
      id, {par, ch, dep, vis} ->
        if Elixir.MapSet.member?(vis, id) do
          {par, ch, dep, vis}
        else
          max_depth = dep |> Elixir.Map.values() |> Enum.max(fn -> -1 end)
          dep = Elixir.Map.put(dep, id, max_depth + 1)
          par = Elixir.Map.put(par, id, nil)
          vis = Elixir.MapSet.put(vis, id)
          bfs_fill(:queue.from_list([id]), adj, vis, dep, par, ch)
        end
    end)
    |> then(fn {par, ch, dep, _vis} -> {par, ch, dep} end)
  end

  defp bfs_fill(queue, adj, visited, depths, parent, children) do
    case :queue.out(queue) do
      {:empty, _} ->
        {depths, parent, children, visited}

      {{:value, id}, rest} ->
        depth = Elixir.Map.fetch!(depths, id)

        {queue, visited, depths, parent, children} =
          Enum.reduce(Elixir.Map.get(adj, id, []), {rest, visited, depths, parent, children}, fn
            neighbor, {q, vis, dep, par, ch} ->
              if Elixir.MapSet.member?(vis, neighbor) do
                {q, vis, dep, par, ch}
              else
                vis = Elixir.MapSet.put(vis, neighbor)
                dep = Elixir.Map.put(dep, neighbor, depth + 1)
                par = Elixir.Map.put(par, neighbor, id)
                ch = Elixir.Map.update!(ch, id, &(&1 ++ [neighbor]))
                {:queue.in(neighbor, q), vis, dep, par, ch}
              end
          end)

        bfs_fill(queue, adj, visited, depths, parent, children)
    end
  end

  defp assign_x_index(roots, children) do
    {positions, _} =
      Enum.reduce(roots, {%{}, 0}, fn root, {pos, counter} ->
        assign_subtree(root, children, pos, counter)
      end)

    positions
  end

  defp assign_subtree(id, children, positions, counter) do
    case Elixir.Map.get(children, id, []) do
      [] ->
        {Elixir.Map.put(positions, id, counter * 1.0), counter + 1}

      kids ->
        {positions, counter} =
          Enum.reduce(kids, {positions, counter}, fn kid, {pos, c} ->
            assign_subtree(kid, children, pos, c)
          end)

        mean =
          kids
          |> Enum.map(&Elixir.Map.fetch!(positions, &1))
          |> Enum.sum()
          |> Kernel./(length(kids))

        {Elixir.Map.put(positions, id, mean), counter}
    end
  end

  defp orient_tidy_position(orientation, depth, xi, mid, spacing) do
    x = 460.0 + (xi - mid) * 150.0 * spacing

    case orientation do
      "up" ->
        {x, 590.0 - depth * 160.0 * spacing}

      "left" ->
        {860.0 - depth * 170.0 * spacing, 325.0 + (xi - mid) * 120.0 * spacing}

      "right" ->
        {60.0 + depth * 170.0 * spacing, 325.0 + (xi - mid) * 120.0 * spacing}

      _ ->
        {x, 60.0 + depth * 160.0 * spacing}
    end
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

  def update_system(%MapSystem{} = system, attrs) do
    system
    |> MapSystem.changeset(attrs)
    |> Repo.update()
  end

  def delete_system(%MapSystem{} = system) do
    Repo.delete_all(
      from(c in MapConnection,
        where: c.from_system_id == ^system.id or c.to_system_id == ^system.id
      )
    )

    Repo.delete(system)
  end

  @doc """
  Deletes a map with all of its systems, connections, signatures, and
  related rows.
  """
  def delete_map_full(%Map{id: map_id} = map) do
    system_ids = from(s in MapSystem, where: s.map_id == ^map_id, select: s.id)

    connection_ids =
      from(c in MapConnection, where: c.map_id == ^map_id, select: c.id)

    Repo.delete_all(
      from(j in Tripwire.Mapping.ConnectionJump,
        where: j.map_connection_id in subquery(connection_ids)
      )
    )

    Repo.delete_all(from(s in Signature, where: s.map_system_id in subquery(system_ids)))

    Repo.delete_all(
      from(c in Tripwire.Mapping.Comment, where: c.map_system_id in subquery(system_ids))
    )

    Repo.delete_all(
      from(f in Tripwire.Mapping.Flare, where: f.map_system_id in subquery(system_ids))
    )

    Repo.delete_all(
      from(s in Tripwire.Mapping.SystemStat, where: s.map_system_id in subquery(system_ids))
    )

    Repo.delete_all(from(c in MapConnection, where: c.map_id == ^map_id))
    Repo.delete_all(from(s in MapSystem, where: s.map_id == ^map_id))
    Repo.delete(map)
  end

  @doc """
  Deletes every map on a mask and rebuilds the demo seed from scratch.
  """
  def reset_demo_maps(mask_id) do
    mask_id
    |> list_maps_for_mask()
    |> Enum.each(&delete_map_full/1)

    ensure_demo_map(mask_id)
  end

  def get_connection!(id),
    do: Repo.get!(MapConnection, id) |> Repo.preload([:from_system, :to_system])

  def get_connection(id),
    do:
      (case Repo.get(MapConnection, id) do
         nil -> nil
         conn -> Repo.preload(conn, [:from_system, :to_system])
       end)

  def update_connection(%MapConnection{} = connection, attrs) do
    connection
    |> MapConnection.changeset(attrs)
    |> Repo.update()
  end

  def delete_connection(%MapConnection{} = connection), do: Repo.delete(connection)

  def prune_expired_signatures(now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.delete_all(
        from(s in Signature, where: not is_nil(s.expires_at) and s.expires_at < ^now)
      )

    {:ok, count}
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
    {added, updated, counts} =
      Enum.reduce(entries, {0, 0, %{}}, fn entry, {added, updated, counts} ->
        life_length = 259_200

        attrs = %{
          map_system_id: system.id,
          sig_id: entry.sig_id,
          kind: to_string(entry.kind),
          type_name: entry.name || entry.wormhole_type,
          site_type: to_string(entry.category || :unknown),
          life_length: life_length,
          expires_at:
            DateTime.add(DateTime.utc_now(), life_length, :second) |> DateTime.truncate(:second),
          updated_by_id: character_id
        }

        existing = Repo.get_by(Signature, map_system_id: system.id, sig_id: entry.sig_id)

        result =
          case existing do
            %Signature{} = signature ->
              signature
              |> Signature.changeset(
                merge_attrs(attrs, %{created_by_id: signature.created_by_id})
              )
              |> Repo.update()

            nil ->
              %Signature{}
              |> Signature.changeset(merge_attrs(attrs, %{created_by_id: character_id}))
              |> Repo.insert()
          end

        wormhole? = to_string(entry.category || :unknown) == "wormhole"

        case {result, existing} do
          {{:ok, _}, nil} ->
            {added + 1, updated,
             bump_counts(counts, :signatures_added, :wormholes_added, wormhole?)}

          {{:ok, _}, _signature} ->
            {added, updated + 1,
             bump_counts(counts, :signatures_updated, :wormholes_updated, wormhole?)}

          {{:error, _}, _} ->
            {added, updated, counts}
        end
      end)

    Accounts.bump_stats(character_id, Elixir.Map.to_list(counts))
    {added, updated}
  end

  def create_signature(%MapSystem{} = system, attrs, %Character{id: character_id}) do
    attrs = with_expires_at(attrs)

    case %Signature{}
         |> Signature.changeset(
           merge_attrs(attrs, %{
             map_system_id: system.id,
             created_by_id: character_id,
             updated_by_id: character_id
           })
         )
         |> Repo.insert() do
      {:ok, signature} = ok ->
        Accounts.bump_stats(character_id, signature_added_stats(signature.site_type))
        ok

      error ->
        error
    end
  end

  def update_signature(%Signature{} = signature, attrs, %Character{id: character_id}) do
    attrs = with_expires_at(attrs, signature)

    case signature
         |> Signature.changeset(merge_attrs(attrs, %{updated_by_id: character_id}))
         |> Repo.update() do
      {:ok, updated} = ok ->
        Accounts.bump_stats(character_id, signature_updated_stats(updated.site_type))
        ok

      error ->
        error
    end
  end

  defp with_expires_at(attrs, existing \\ nil) do
    life_length =
      attrs[:life_length] || attrs["life_length"] || (existing && existing.life_length) || 259_200

    life_length =
      if is_binary(life_length),
        do:
          (case Integer.parse(life_length) do
             {n, ""} -> n
             _ -> 259_200
           end),
        else: life_length

    expires_at =
      attrs[:expires_at] || attrs["expires_at"] ||
        DateTime.add(DateTime.utc_now(), life_length, :second) |> DateTime.truncate(:second)

    attrs |> Elixir.Map.put(:life_length, life_length) |> Elixir.Map.put(:expires_at, expires_at)
  end

  def delete_signature(%Signature{} = signature, character \\ nil) do
    case Repo.delete(signature) do
      {:ok, _} = ok ->
        if is_struct(character, Character) do
          Accounts.bump_stats(character.id, signature_deleted_stats(signature.site_type))
        end

        ok

      error ->
        error
    end
  end

  defp signature_added_stats("wormhole"), do: [signatures_added: 1, wormholes_added: 1]
  defp signature_added_stats(_), do: [signatures_added: 1]

  defp signature_updated_stats("wormhole"), do: [signatures_updated: 1, wormholes_updated: 1]
  defp signature_updated_stats(_), do: [signatures_updated: 1]

  defp signature_deleted_stats("wormhole"), do: [signatures_deleted: 1, wormholes_deleted: 1]
  defp signature_deleted_stats(_), do: [signatures_deleted: 1]

  defp bump_counts(counts, key, _wormhole_key, false) do
    Elixir.Map.update(counts, key, 1, &(&1 + 1))
  end

  defp bump_counts(counts, key, wormhole_key, true) do
    counts
    |> Elixir.Map.update(key, 1, &(&1 + 1))
    |> Elixir.Map.update(wormhole_key, 1, &(&1 + 1))
  end

  def get_signature!(id), do: Repo.get!(Signature, id)

  def get_signature(id), do: Repo.get(Signature, id)

  @doc """
  Wormhole signatures for every system on a map, ordered by signature id.
  The chain map labels each node with the scanned signature code recorded
  on that system instead of the raw connection type.
  """
  def list_wormhole_signatures(map_id) do
    system_ids = from(s in MapSystem, where: s.map_id == ^map_id, select: s.id)

    Repo.all(
      from(sig in Signature,
        where: sig.map_system_id in subquery(system_ids) and sig.site_type == "wormhole",
        order_by: [asc: sig.sig_id]
      )
    )
  end

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

    case %Tripwire.Mapping.Comment{}
         |> Tripwire.Mapping.Comment.changeset(
           merge_attrs(attrs, %{map_system_id: system.id, character_id: character_id})
         )
         |> Repo.insert() do
      {:ok, _} = ok ->
        if is_struct(character, Character) do
          Accounts.bump_stats(character.id, comments_added: 1)
        end

        ok

      error ->
        error
    end
  end

  def delete_comment(%Tripwire.Mapping.Comment{} = comment, character \\ nil) do
    case Repo.delete(comment) do
      {:ok, _} = ok ->
        if is_struct(character, Character) do
          Accounts.bump_stats(character.id, comments_deleted: 1)
        end

        ok

      error ->
        error
    end
  end

  def get_comment!(id), do: Repo.get!(Tripwire.Mapping.Comment, id)

  def move_comment(%Tripwire.Mapping.Comment{} = comment, to_system_id, character \\ nil) do
    case comment
         |> Tripwire.Mapping.Comment.changeset(%{map_system_id: to_system_id})
         |> Repo.update() do
      {:ok, _} = ok ->
        if is_struct(character, Character) do
          Accounts.bump_stats(character.id, comments_updated: 1)
        end

        ok

      error ->
        error
    end
  end

  def list_flares(system_id) do
    Repo.all(
      from(f in Tripwire.Mapping.Flare,
        where: f.map_system_id == ^system_id,
        order_by: [desc: f.id],
        preload: [:created_by]
      )
    )
  end

  def create_flare(%MapSystem{} = system, attrs, character \\ nil, mask_id \\ nil) do
    character_id = if is_struct(character, Character), do: character.id, else: nil
    life_length = attrs[:life_length] || attrs["life_length"] || 3600

    attrs =
      attrs
      |> Elixir.Map.put(:life_length, life_length)
      |> Elixir.Map.put(
        :expires_at,
        DateTime.add(DateTime.utc_now(), life_length, :second) |> DateTime.truncate(:second)
      )

    %Tripwire.Mapping.Flare{}
    |> Tripwire.Mapping.Flare.changeset(
      merge_attrs(attrs, %{
        map_system_id: system.id,
        created_by_id: character_id,
        mask_id: mask_id
      })
    )
    |> Repo.insert()
  end

  def delete_flare(%Tripwire.Mapping.Flare{} = flare), do: Repo.delete(flare)

  def prune_expired_flares(now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.delete_all(
        from(f in Tripwire.Mapping.Flare, where: not is_nil(f.expires_at) and f.expires_at < ^now)
      )

    {:ok, count}
  end

  def upsert_system_stat(%MapSystem{} = system, attrs) do
    case Repo.get_by(Tripwire.Mapping.SystemStat, map_system_id: system.id) do
      nil ->
        %Tripwire.Mapping.SystemStat{}
        |> Tripwire.Mapping.SystemStat.changeset(Elixir.Map.put(attrs, :map_system_id, system.id))
        |> Repo.insert()

      %Tripwire.Mapping.SystemStat{} = stat ->
        stat
        |> Tripwire.Mapping.SystemStat.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_system_stat(system_id),
    do: Repo.get_by(Tripwire.Mapping.SystemStat, map_system_id: system_id)

  def record_visit(%MapSystem{} = system) do
    case get_system_stat(system.id) do
      nil ->
        upsert_system_stat(system, %{
          visits: 1,
          recorded_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      stat ->
        upsert_system_stat(system, %{
          visits: (stat.visits || 0) + 1,
          recorded_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
    end
  end

  def log_connection_jump(
        %MapConnection{} = connection,
        character_name,
        to_system_id \\ nil,
        ship_type \\ nil
      ) do
    %Tripwire.Mapping.ConnectionJump{}
    |> Tripwire.Mapping.ConnectionJump.changeset(%{
      map_connection_id: connection.id,
      character_name: character_name,
      to_system_id: to_system_id,
      ship_type: ship_type
    })
    |> Repo.insert()
  end

  def list_connection_jumps(connection_id) do
    Repo.all(
      from(j in Tripwire.Mapping.ConnectionJump,
        where: j.map_connection_id == ^connection_id,
        order_by: [desc: j.id],
        limit: 50
      )
    )
  end

  def map_statistics(map_id) do
    systems = list_systems(map_id)
    system_ids = Enum.map(systems, & &1.id)

    signatures =
      if system_ids == [],
        do: 0,
        else: Repo.aggregate(from(s in Signature, where: s.map_system_id in ^system_ids), :count)

    connections = length(list_connections(map_id))

    comments =
      if system_ids == [],
        do: 0,
        else:
          Repo.aggregate(
            from(c in Tripwire.Mapping.Comment, where: c.map_system_id in ^system_ids),
            :count
          )

    %{
      systems: length(systems),
      connections: connections,
      signatures: signatures,
      comments: comments
    }
  end

  def character_statistics(nil) do
    %{
      signatures_added: 0,
      signatures_updated: 0,
      signatures_deleted: 0,
      wormholes_added: 0,
      wormholes_updated: 0,
      wormholes_deleted: 0,
      comments_added: 0,
      comments_updated: 0,
      comments_deleted: 0,
      systems_visited: 0,
      logins: 0,
      last_login: nil
    }
  end

  def character_statistics(%{id: id}) do
    case Repo.get(Character, id) do
      nil ->
        character_statistics(nil)

      character ->
        %{
          signatures_added: character.signatures_added || 0,
          signatures_updated: character.signatures_updated || 0,
          signatures_deleted: character.signatures_deleted || 0,
          wormholes_added: character.wormholes_added || 0,
          wormholes_updated: character.wormholes_updated || 0,
          wormholes_deleted: character.wormholes_deleted || 0,
          comments_added: character.comments_added || 0,
          comments_updated: character.comments_updated || 0,
          comments_deleted: character.comments_deleted || 0,
          systems_visited: character.systems_visited || 0,
          logins: character.login_count || 0,
          last_login: character.last_login_at
        }
    end
  end

  @demo_systems [
    %{
      solar_system_id: 31_000_001,
      name: "J150321",
      alias: "Home",
      sys_class: "C2",
      favorite: true,
      x: 120.0,
      y: 120.0
    },
    %{solar_system_id: 31_000_002, name: "J150322", sys_class: "C3", x: 360.0, y: 260.0},
    %{solar_system_id: 31_000_003, name: "J150323", sys_class: "C5", x: 600.0, y: 140.0},
    %{
      solar_system_id: 31_000_004,
      name: "J150324",
      sys_class: "C4",
      x: 780.0,
      y: 330.0,
      effect: "Magnetar"
    },
    %{solar_system_id: 31_000_005, name: "J150325", sys_class: "C6", x: 480.0, y: 470.0},
    %{solar_system_id: 31_000_006, name: "J150326", sys_class: "C1", x: 880.0, y: 200.0},
    %{solar_system_id: 30_000_142, name: "Jita", security: 0.9, x: 880.0, y: 380.0},
    %{solar_system_id: 30_000_201, name: "Tama", security: 0.2, x: 700.0, y: 540.0},
    %{solar_system_id: 30_000_301, name: "1DQ1-A", security: -1.0, x: 450.0, y: 560.0},
    %{
      solar_system_id: 31_000_010,
      name: "Raravoss",
      alias: "Pochven",
      sys_class: "Trig",
      x: 200.0,
      y: 540.0
    },
    %{solar_system_id: 31_000_011, name: "J150327", sys_class: "C4", x: 240.0, y: 300.0},
    %{solar_system_id: 31_000_012, name: "J150328", sys_class: "C2", x: 120.0, y: 460.0},
    %{solar_system_id: 30_000_216, name: "Dodixie", security: 0.9, x: 240.0, y: 620.0},
    %{solar_system_id: 31_000_013, name: "J150329", sys_class: "C5", x: 300.0, y: 30.0},
    %{solar_system_id: 31_000_014, name: "J150330", sys_class: "C2", x: 500.0, y: 20.0},
    %{solar_system_id: 30_002_187, name: "Amarr", security: 1.0, x: 700.0, y: 40.0},
    %{solar_system_id: 31_000_015, name: "J150331", sys_class: "C5", x: 980.0, y: 480.0},
    %{
      solar_system_id: 31_000_016,
      name: "J150332",
      sys_class: "C4",
      effect: "Red Giant",
      x: 620.0,
      y: 660.0
    },
    %{solar_system_id: 31_000_017, name: "J150333", sys_class: "C4", x: 60.0, y: 620.0},
    %{solar_system_id: 31_000_018, name: "J150334", sys_class: "C1", x: 620.0, y: 300.0},
    %{solar_system_id: 30_002_537, name: "Rens", security: 0.9, x: 460.0, y: 120.0},
    %{solar_system_id: 31_000_019, name: "J150335", sys_class: "C6", x: 830.0, y: 90.0},
    %{solar_system_id: 31_000_020, name: "J150336", sys_class: "C5", x: 950.0, y: 280.0}
  ]

  @demo_shortcuts """
  # Shortcuts

  - <kbd>Ctrl</kbd> + <kbd>V</kbd> anywhere — paste probe scans
  - <kbd>Escape</kbd> — close settings
  - <kbd>Enter</kbd> in Search — jump to a system
  """

  @demo_note """
  **Bold**
  *italic* and _italic_
  __underline__
  ~~strike~~
  `code`
  # Header 1
  ## Header 2
  ### Header 3
  """

  @demo_paste Enum.join(
                [
                  "TUV-679\tCosmic Signature\tUnstable Wormhole (M555)\t100.00%\t1.21 AU",
                  "KLM-791\tCosmic Signature\tUnstable Wormhole (N110)\t100.00%\t0.42 AU",
                  "TUV-678\tCosmic Anomaly\tForsaken Hub\t100.00%\t1.05 AU",
                  "WXY-901\tCosmic Signature\tCentral Data Site\t87.50%\t2.40 AU",
                  "AAA-111\tCosmic Signature\t100.00%\t3.10 AU",
                  "QWE-111\tCosmic Signature\t12.50%\t4.20 AU",
                  "RTY-222"
                ],
                "\n"
              )

  @demo_links [
    {0, 1, "O477", "stable", "stable"},
    {1, 2, "N770", "destab", "stable"},
    {2, 3, "E175", "stable", "eol"},
    {2, 4, "V753", "critical", "stable"},
    {4, 5, "Q317", "stable", "stable"},
    {5, 6, "N110", "stable", "stable"},
    {3, 7, "N290", "stable", "stable"},
    {3, 8, "K329", "stable", "stable"},
    {4, 9, "F216", "stable", "stable"},
    {0, 10, "Y683", "stable", "stable"},
    {10, 11, "N766", "stable", "stable"},
    {11, 12, "B274", "stable", "stable"},
    {0, 13, "N062", "stable", "stable"},
    {13, 14, "D364", "stable", "stable"},
    {14, 15, "B274", "stable", "stable"},
    {6, 16, "M555", "stable", "stable"},
    {8, 17, "O128", "destab", "stable"},
    {9, 18, "R081", "stable", "stable"},
    {2, 19, "Y790", "stable", "stable"},
    {15, 20, "A641", "stable", "stable"},
    {15, 21, "B041", "stable", "stable"},
    {3, 22, "H900", "stable", "stable"}
  ]

  @demo_signatures %{
    0 => [
      %{
        sig_id: "ABC-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O477)"
      },
      %{
        sig_id: "ABC-124",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y683)"
      },
      %{
        sig_id: "ABC-125",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N062)"
      },
      %{
        sig_id: "DEF-456",
        kind: "signature",
        site_type: "combat",
        type_name: "Serpentis Frigate Den"
      },
      %{sig_id: "GHI-789", kind: "signature", site_type: "data", type_name: "Ruined Data Site"}
    ],
    1 => [
      %{
        sig_id: "JKL-012",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O477)"
      },
      %{
        sig_id: "BCD-124",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N770)"
      },
      %{sig_id: "MNO-345", kind: "signature", site_type: "relic", type_name: "Ruined Relic Site"},
      %{sig_id: "PQR-678", kind: "anomaly", site_type: "combat", type_name: "Forsaken Hub"}
    ],
    2 => [
      %{
        sig_id: "STU-902",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N770)"
      },
      %{
        sig_id: "VWX-234",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (E175)"
      },
      %{
        sig_id: "TUV-681",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (V753)"
      },
      %{
        sig_id: "TUV-682",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y790)"
      },
      %{
        sig_id: "STU-901",
        kind: "signature",
        site_type: "gas",
        type_name: "Sizeable Perimeter Withdrawal"
      },
      %{
        sig_id: "YZA-567",
        kind: "signature",
        site_type: "ore",
        type_name: "Rarified Core Deposit"
      }
    ],
    3 => [
      %{
        sig_id: "EFG-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (E175)"
      },
      %{
        sig_id: "FGH-892",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N290)"
      },
      %{
        sig_id: "FGH-893",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K329)"
      },
      %{
        sig_id: "FGH-894",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (H900)"
      },
      %{sig_id: "BCD-890", kind: "anomaly", site_type: "combat", type_name: "Sanctum"}
    ],
    4 => [
      %{
        sig_id: "HIJ-457",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (V753)"
      },
      %{
        sig_id: "HIJ-458",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Q317)"
      },
      %{
        sig_id: "IJK-124",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (F216)"
      },
      %{sig_id: "HIJ-456", kind: "signature", site_type: "data", type_name: "Central Data Site"},
      %{
        sig_id: "KLM-789",
        kind: "signature",
        site_type: "combat",
        type_name: "Blood Raider Naval Shipyard"
      }
    ],
    5 => [
      %{
        sig_id: "NOP-012",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Q317)"
      },
      %{
        sig_id: "IJK-125",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N110)"
      },
      %{sig_id: "QRS-345", kind: "signature", site_type: "relic", type_name: "Ruined Relic Site"}
    ],
    6 => [
      %{
        sig_id: "KLM-791",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N110)"
      },
      %{
        sig_id: "TUV-679",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (M555)"
      },
      %{sig_id: "TUV-678", kind: "anomaly", site_type: "combat", type_name: "Forsaken Hub"},
      %{sig_id: "WXY-901", kind: "signature", site_type: "data", type_name: "Central Data Site"},
      %{sig_id: "AAA-111", kind: "signature", site_type: "unknown"},
      %{sig_id: "BBB-222", kind: "signature", site_type: "unknown"}
    ],
    7 => [
      %{
        sig_id: "ZAB-235",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N290)"
      },
      %{
        sig_id: "ZAB-234",
        kind: "signature",
        site_type: "combat",
        type_name: "Serpentis Rally Point"
      },
      %{
        sig_id: "CDE-567",
        kind: "signature",
        site_type: "gas",
        type_name: "Vast Frontier Reservoir"
      },
      %{sig_id: "CCC-333", kind: "signature", site_type: "unknown"}
    ],
    8 => [
      %{
        sig_id: "IJK-123",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (K329)"
      },
      %{
        sig_id: "FGH-891",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O128)"
      },
      %{sig_id: "FGH-890", kind: "anomaly", site_type: "combat", type_name: "Sanctum"}
    ],
    9 => [
      %{
        sig_id: "LMN-456",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (F216)"
      },
      %{
        sig_id: "LMN-458",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (R081)"
      }
    ],
    10 => [
      %{
        sig_id: "OPQ-789",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y683)"
      },
      %{
        sig_id: "OPQ-790",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N766)"
      },
      %{sig_id: "RST-012", kind: "signature", site_type: "combat", type_name: "Guristas Hub"}
    ],
    11 => [
      %{
        sig_id: "UVW-345",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N766)"
      },
      %{
        sig_id: "UVW-347",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      }
    ],
    12 => [
      %{
        sig_id: "XYZ-679",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      },
      %{sig_id: "XYZ-678", kind: "anomaly", site_type: "combat", type_name: "Forsaken Hub"}
    ],
    13 => [
      %{
        sig_id: "KLM-790",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (N062)"
      },
      %{
        sig_id: "KLM-792",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (D364)"
      }
    ],
    14 => [
      %{
        sig_id: "NOP-013",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (D364)"
      },
      %{
        sig_id: "NOP-014",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      }
    ],
    15 => [
      %{
        sig_id: "QRS-346",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B274)"
      },
      %{
        sig_id: "QRS-347",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (A641)"
      },
      %{
        sig_id: "RST-015",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B041)"
      }
    ],
    16 => [
      %{
        sig_id: "RST-013",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (M555)"
      }
    ],
    17 => [
      %{
        sig_id: "TUV-680",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (O128)"
      }
    ],
    18 => [
      %{
        sig_id: "UVW-346",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (R081)"
      }
    ],
    19 => [
      %{
        sig_id: "VWX-235",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (Y790)"
      }
    ],
    20 => [
      %{
        sig_id: "WXY-902",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (A641)"
      }
    ],
    21 => [
      %{
        sig_id: "XYZ-680",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (B041)"
      }
    ],
    22 => [
      %{
        sig_id: "YZA-568",
        kind: "signature",
        site_type: "wormhole",
        type_name: "Unstable Wormhole (H900)"
      }
    ]
  }

  def ensure_demo_map(mask_id) do
    map =
      case list_maps_for_mask(mask_id) do
        [map | _] -> map
        [] -> elem(create_map(%{name: "Demo", mask_id: mask_id}), 1)
      end

    systems =
      if list_systems(map.id) == [] do
        created =
          Enum.map(@demo_systems, fn attrs ->
            {:ok, system} = add_system_to_map(map, attrs)
            system
          end)

        Enum.each(@demo_links, fn {from_idx, to_idx, hole_type, mass_status, time_status} ->
          {:ok, _, _} =
            upsert_connection(
              map.id,
              Enum.at(created, from_idx).id,
              Enum.at(created, to_idx).id,
              %{hole_type: hole_type, mass_status: mass_status, time_status: time_status}
            )
        end)

        created
      else
        list_systems(map.id)
      end

    ensure_demo_signatures(systems)
    ensure_demo_notes(systems, mask_id)

    {:ok, get_map!(map.id)}
  end

  defp ensure_demo_signatures(systems) do
    systems
    |> Enum.sort_by(& &1.id)
    |> Enum.with_index()
    |> Enum.each(fn {system, idx} ->
      if list_signatures(system.id) == [] do
        Enum.each(Elixir.Map.get(@demo_signatures, idx, []), fn attrs ->
          %Signature{}
          |> Signature.changeset(Elixir.Map.put(attrs, :map_system_id, system.id))
          |> Repo.insert(on_conflict: :nothing)
        end)
      end
    end)
  end

  defp ensure_demo_notes(systems, mask_id) do
    jita =
      Enum.find(systems, &(&1.name == "Jita")) ||
        systems |> Enum.sort_by(& &1.id) |> List.first()

    case jita do
      nil ->
        :ok

      system ->
        system_ids = Enum.map(systems, & &1.id)

        Tripwire.Repo.update_all(
          from(c in Tripwire.Mapping.Comment,
            where: c.map_system_id in ^system_ids and c.map_system_id != ^system.id
          ),
          set: [map_system_id: system.id]
        )

        if list_comments(system.id) == [] do
          {:ok, _} = create_comment(system, %{body: @demo_shortcuts, mask_id: mask_id})
          {:ok, _} = create_comment(system, %{body: @demo_note, mask_id: mask_id})
          {:ok, _} = create_comment(system, %{body: @demo_paste, mask_id: mask_id})
        end

        :ok
    end
  end

  defp merge_attrs(attrs, extra), do: Elixir.Map.merge(attrs, extra)
end
