defmodule Ztripwire.Mapping do
  import Ecto.Query

  alias Ztripwire.Accounts
  alias Ztripwire.Accounts.Character

  alias Ztripwire.Mapping.{
    Map,
    MapConnection,
    MapSystem,
    MapViewSystem,
    Signature,
    SystemActivity
  }

  alias Ztripwire.Repo
  alias Ztripwire.Signatures, as: SigParser
  alias Ztripwire.Systems

  def get_map!(id), do: Repo.get!(Map, id)

  def get_map(id), do: Repo.get(Map, id)

  def list_maps_for_mask(mask_id) do
    Repo.all(from(m in Map, where: m.mask_id == ^mask_id, order_by: [asc: m.id]))
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
  @jita_solar_system_id 30_000_142

  @welcome_shortcuts """
  # Shortcuts

  - <kbd>Escape</kbd> — toggle settings
  - <kbd>Ctrl</kbd> + <kbd>V</kbd> — paste scans
  """

  @welcome_markdown """
  **Bold**
  *italic* and _italic_
  __underline__
  ~~strike~~
  `code`
  # Header 1
  ## Header 2
  ### Header 3
  """

  def thera_solar_system_id, do: @thera_solar_system_id
  def thera_name, do: @thera_name

  def list_favorite_candidates(mask_id) do
    Repo.all(
      from(s in MapSystem,
        where: s.mask_id == ^mask_id and s.favorite == true,
        order_by: [asc: s.id]
      )
    )
  end

  def wormhole_link_target(mask_id, candidate_solar_id, chain_systems) do
    by_solar = Elixir.Map.new(chain_systems, &{&1.solar_system_id, &1})
    chain_set = Elixir.MapSet.new(Elixir.Map.keys(by_solar))

    links =
      Repo.all(
        from(c in MapConnection,
          where: c.mask_id == ^mask_id,
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

  def ensure_chain_system(%Map{} = view, attrs) do
    solar_id = attrs[:solar_system_id] || attrs["solar_system_id"]

    case Repo.get_by(MapSystem, mask_id: view.mask_id, solar_system_id: solar_id) do
      %MapSystem{} = system ->
        unhide_systems([system.id])
        ensure_view_position(view, system)
        {:ok, %{system | hidden_at: nil}, false}

      nil ->
        position = %{x: 460.0, y: 300.0}

        case add_system_to_map(view, Elixir.Map.merge(%{x: position.x, y: position.y}, attrs)) do
          {:ok, system} -> {:ok, system, true}
          error -> error
        end
    end
  end

  def list_systems(mask_id) do
    Repo.all(from(s in MapSystem, where: s.mask_id == ^mask_id, order_by: [asc: s.id]))
  end

  def list_visible_systems(mask_id) do
    Repo.all(
      from(s in MapSystem,
        where: s.mask_id == ^mask_id and is_nil(s.hidden_at),
        order_by: [asc: s.id]
      )
    )
  end

  def list_chain_systems(%Map{} = view, true) do
    view
    |> view_systems(false)
    |> with_view_positions(view)
  end

  def list_chain_systems(%Map{} = view, _show_all) do
    systems = view |> view_systems(true) |> with_view_positions(view)

    case home_system_id(view) do
      nil ->
        systems

      home_id ->
        reachable = reachable_system_ids(view.mask_id, home_id)
        Enum.filter(systems, &Elixir.MapSet.member?(reachable, &1.id))
    end
  end

  defp view_systems(%Map{} = view, visible_only?) do
    query =
      from(s in MapSystem,
        where: s.mask_id == ^view.mask_id,
        order_by: [asc: s.id]
      )

    query =
      if visible_only? do
        from(s in query, where: is_nil(s.hidden_at))
      else
        query
      end

    Repo.all(query)
  end

  defp with_view_positions(systems, %Map{} = view) do
    positions =
      Repo.all(
        from(p in MapViewSystem,
          where: p.map_id == ^view.id,
          select: {p.map_system_id, p.x, p.y}
        )
      )
      |> Elixir.Map.new(fn {id, x, y} -> {id, {x, y}} end)

    Enum.map(systems, fn system ->
      case Elixir.Map.get(positions, system.id) do
        {x, y} -> %{system | x: x, y: y}
        nil -> system
      end
    end)
  end

  def view_positions(%Map{} = view) do
    Repo.all(
      from(p in MapViewSystem,
        where: p.map_id == ^view.id,
        select: {p.map_system_id, p.x, p.y}
      )
    )
    |> Elixir.Map.new(fn {id, x, y} -> {id, {x, y}} end)
  end

  def put_view_positions(%Map{} = view, positions) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(positions, fn {system_id, %{x: x, y: y}} ->
      attrs = %{map_id: view.id, map_system_id: system_id, x: x, y: y}

      case Repo.get_by(MapViewSystem, map_id: view.id, map_system_id: system_id) do
        nil ->
          %MapViewSystem{}
          |> MapViewSystem.changeset(attrs)
          |> Repo.insert(on_conflict: :nothing, conflict_target: [:map_id, :map_system_id])

        %MapViewSystem{} = position ->
          position
          |> Ecto.Changeset.change(x: x, y: y, updated_at: now)
          |> Repo.update()
      end
    end)

    {:ok, nil}
  end

  defp ensure_view_position(%Map{} = view, %MapSystem{} = system) do
    if Repo.get_by(MapViewSystem, map_id: view.id, map_system_id: system.id) do
      :ok
    else
      %MapViewSystem{}
      |> MapViewSystem.changeset(%{
        map_id: view.id,
        map_system_id: system.id,
        x: system.x,
        y: system.y
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:map_id, :map_system_id])
    end

    :ok
  end

  def get_system!(id), do: Repo.get!(MapSystem, id)

  def get_system(id), do: Repo.get(MapSystem, id)

  def get_system_by_solar(mask_id, solar_system_id) do
    Repo.one(
      from(s in MapSystem,
        where: s.mask_id == ^mask_id and s.solar_system_id == ^solar_system_id
      )
    )
  end

  def list_connections(mask_id) do
    Repo.all(
      from(c in MapConnection,
        where: c.mask_id == ^mask_id,
        preload: [:from_system, :to_system],
        order_by: [asc: c.id]
      )
    )
  end

  def list_connections_with_endpoints(mask_id) do
    mask_id
    |> list_connections()
    |> Enum.map(fn conn -> {conn, conn.from_system, conn.to_system} end)
  end

  @pan_pad 40
  @node_w 156.0
  @node_h 88.0
  @view_w 1000.0
  @view_h 700.0
  @default_zoom 0.8

  def node_size, do: {@node_w, @node_h}

  def default_zoom, do: @default_zoom

  def view_size(zoom \\ @default_zoom), do: {@view_w / zoom, @view_h / zoom}

  def clamp_pan(systems, x, y, zoom \\ @default_zoom) do
    {view_w, view_h} = view_size(zoom)

    case system_bounds(systems) do
      nil ->
        {x, y}

      {min_x, min_y, max_x, max_y} ->
        {clamp_axis(x, min_x, max_x, view_w, :center),
         clamp_axis(y, min_y, max_y, view_h, :start)}
    end
  end

  def home_center(systems, map, zoom \\ @default_zoom) do
    with solar when is_integer(solar) <- map && map.home_solar_system_id,
         home when not is_nil(home) <- Enum.find(systems, &(&1.solar_system_id == solar)) do
      {view_w, _view_h} = view_size(zoom)
      clamp_pan(systems, home.x + @node_w / 2 - view_w / 2, top_pan(systems), zoom)
    else
      _ -> clamp_pan(systems, 0, 0, zoom)
    end
  end

  defp top_pan([]), do: 0

  defp top_pan(systems) do
    systems |> Enum.map(&(&1.y - @pan_pad)) |> Enum.min()
  end

  defp system_bounds([]), do: nil

  defp system_bounds(systems) do
    Enum.reduce(systems, nil, fn system, acc ->
      {min_x, min_y, max_x, max_y} = acc || {system.x, system.y, system.x, system.y}

      {min(min_x, system.x), min(min_y, system.y), max(max_x, system.x + @node_w),
       max(max_y, system.y + @node_h)}
    end)
  end

  defp clamp_axis(value, first, last, size, align) do
    low = first - @pan_pad
    high = last + @pan_pad - size

    if low <= high do
      value |> max(low) |> min(high)
    else
      case align do
        :start -> low
        :center -> (first + last - size) / 2
      end
    end
  end

  def tree_layout(systems, connections, orientation \\ "down", spacing \\ 1.0, opts \\ []) do
    ids = Enum.map(systems, & &1.id)

    if ids == [] do
      %{}
    else
      adj = undirected_adj(ids, connections)
      roots = tree_roots(ids, connections, opts)
      {parent, children, depths, roots} = spanning_tree(adj, roots, ids)
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

  def collapse_hidden_ids(systems, connections, collapsed_ids, opts \\ []) do
    ids = Enum.map(systems, & &1.id)

    if ids == [] do
      Elixir.MapSet.new()
    else
      adj = undirected_adj(ids, connections)
      roots = layout_roots(ids, connections, opts)

      collapsed =
        Elixir.MapSet.intersection(Elixir.MapSet.new(collapsed_ids), Elixir.MapSet.new(ids))

      {_parent, children, _depths, _roots} = spanning_tree(adj, roots, ids)

      Enum.reduce(collapsed, Elixir.MapSet.new(), fn id, hidden ->
        Elixir.MapSet.union(hidden, descendant_ids(children, id))
      end)
    end
  end

  def collapse_hidden_counts(systems, connections, collapsed_ids, opts \\ []) do
    collapsed =
      Elixir.MapSet.intersection(
        Elixir.MapSet.new(collapsed_ids),
        Elixir.MapSet.new(systems, & &1.id)
      )

    hidden = collapse_hidden_ids(systems, connections, collapsed, opts)

    Elixir.Map.new(collapsed, fn id ->
      revealed =
        collapse_hidden_ids(systems, connections, Elixir.MapSet.delete(collapsed, id), opts)

      {id, Elixir.MapSet.size(Elixir.MapSet.difference(hidden, revealed))}
    end)
  end

  def chain_home_id(systems, %Map{home_solar_system_id: solar}) when is_integer(solar) do
    case Enum.find(systems, &(&1.solar_system_id == solar)) do
      %MapSystem{id: id} -> id
      nil -> nil
    end
  end

  def chain_home_id(_systems, _map), do: nil

  defp layout_roots(ids, connections, opts) do
    adj = undirected_adj(ids, connections)
    seeds = tree_roots(ids, connections, opts)
    seen = bfs_reachable(:queue.from_list(seeds), adj, Elixir.MapSet.new(seeds))

    Enum.reduce(Enum.sort(ids), {seeds, seen}, fn id, {roots, seen} ->
      if Elixir.MapSet.member?(seen, id) do
        {roots, seen}
      else
        component = bfs_reachable(:queue.from_list([id]), adj, Elixir.MapSet.new([id]))
        {roots ++ [id], Elixir.MapSet.union(seen, component)}
      end
    end)
    |> elem(0)
  end

  defp descendant_ids(children, id) do
    collect_descendants(
      :queue.from_list(Elixir.Map.get(children, id, [])),
      children,
      Elixir.MapSet.new()
    )
  end

  defp collect_descendants(queue, children, seen) do
    case :queue.out(queue) do
      {:empty, _} ->
        seen

      {{:value, id}, rest} ->
        if Elixir.MapSet.member?(seen, id) do
          collect_descendants(rest, children, seen)
        else
          seen = Elixir.MapSet.put(seen, id)
          kids = :queue.from_list(Elixir.Map.get(children, id, []))
          collect_descendants(:queue.join(rest, kids), children, seen)
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
        component_roots(ids, connections)

      root_id ->
        if root_id in ids, do: [root_id], else: [ids |> Enum.sort() |> hd()]
    end
  end

  defp component_roots(ids, connections) do
    adj = undirected_adj(ids, connections)

    incoming =
      Enum.reduce(connections, Elixir.MapSet.new(), fn {_conn, _from, to}, acc ->
        Elixir.MapSet.put(acc, to.id)
      end)

    ids
    |> Enum.sort()
    |> Enum.reduce({[], Elixir.MapSet.new()}, fn id, {roots, seen} ->
      if Elixir.MapSet.member?(seen, id) do
        {roots, seen}
      else
        component = bfs_reachable(:queue.from_list([id]), adj, Elixir.MapSet.new([id]))

        root =
          component
          |> Enum.sort()
          |> Enum.find(id, &(!Elixir.MapSet.member?(incoming, &1)))

        {roots ++ [root], Elixir.MapSet.union(seen, component)}
      end
    end)
    |> elem(0)
  end

  defp spanning_tree(adj, roots, ids) do
    depths = Elixir.Map.new(roots, &{&1, 0})
    parent = Elixir.Map.new(roots, &{&1, nil})
    children = Elixir.Map.new(ids, &{&1, []})
    queue = :queue.from_list(roots)
    visited = Elixir.MapSet.new(roots)

    {depths, parent, children, visited} =
      bfs_fill(queue, adj, visited, depths, parent, children)

    {depths, parent, children, _visited, roots} =
      Enum.reduce(Enum.sort(ids), {depths, parent, children, visited, roots}, fn
        id, {dep, par, ch, vis, roots} ->
          if Elixir.MapSet.member?(vis, id) do
            {dep, par, ch, vis, roots}
          else
            dep = Elixir.Map.put(dep, id, 0)
            par = Elixir.Map.put(par, id, nil)
            vis = Elixir.MapSet.put(vis, id)

            {dep, par, ch, vis} = bfs_fill(:queue.from_list([id]), adj, vis, dep, par, ch)

            {dep, par, ch, vis, roots ++ [id]}
          end
      end)

    {parent, children, depths, roots}
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
    x = 460.0 + (xi - mid) * 186.0 * spacing

    case orientation do
      "up" ->
        {x, 590.0 - depth * 160.0 * spacing}

      "left" ->
        {860.0 - depth * 190.0 * spacing, 325.0 + (xi - mid) * 120.0 * spacing}

      "right" ->
        {60.0 + depth * 190.0 * spacing, 325.0 + (xi - mid) * 120.0 * spacing}

      _ ->
        {x, 60.0 + depth * 160.0 * spacing}
    end
  end

  def upsert_connection(mask_id, system_a_id, system_b_id, attrs \\ %{}) do
    case do_upsert_connection(mask_id, system_a_id, system_b_id, attrs) do
      {:ok, _, _} = ok ->
        unhide_systems([system_a_id, system_b_id])
        ok

      error ->
        error
    end
  end

  defp do_upsert_connection(mask_id, system_a_id, system_b_id, attrs) do
    connection =
      Repo.one(
        from(c in MapConnection,
          where:
            c.mask_id == ^mask_id and
              ((c.from_system_id == ^system_a_id and c.to_system_id == ^system_b_id) or
                 (c.from_system_id == ^system_b_id and c.to_system_id == ^system_a_id))
        )
      )

    case connection do
      %MapConnection{} = conn ->
        {:ok, conn} =
          conn
          |> MapConnection.changeset(merge_attrs(attrs, %{mask_id: conn.mask_id}))
          |> Repo.update()

        {:ok, conn, false}

      nil ->
        changeset =
          %MapConnection{}
          |> MapConnection.changeset(
            merge_attrs(attrs, %{
              mask_id: mask_id,
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

  def connection_between(mask_id, system_a_id, system_b_id) do
    Repo.one(
      from(c in MapConnection,
        where:
          c.mask_id == ^mask_id and
            ((c.from_system_id == ^system_a_id and c.to_system_id == ^system_b_id) or
               (c.from_system_id == ^system_b_id and c.to_system_id == ^system_a_id))
      )
    )
  end

  def unhide_systems(system_ids) do
    Repo.update_all(from(s in MapSystem, where: s.id in ^system_ids), set: [hidden_at: nil])
    :ok
  end

  def add_system_to_map(%Map{} = view, attrs, opts \\ []) do
    attrs = if Keyword.get(opts, :fill?, true), do: put_system_data(attrs), else: attrs
    solar_id = solar_system_id(attrs)
    unknown? = attrs[:unknown] == true or attrs["unknown"] in [true, "true"]

    case existing_system(view, solar_id, unknown?) do
      %MapSystem{} = system ->
        unhide_systems([system.id])
        ensure_view_position(view, system)
        {:ok, %{system | hidden_at: nil}}

      nil ->
        %MapSystem{mask_id: view.mask_id}
        |> MapSystem.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, system} = ok ->
            ensure_view_position(view, system)
            if jita?(system), do: ensure_welcome_notes(system)
            ok

          error ->
            error
        end
    end
  end

  defp existing_system(_view, nil, _unknown?), do: nil
  defp existing_system(_view, _solar_id, true), do: nil
  defp existing_system(_view, solar_id, _unknown?) when solar_id <= 0, do: nil

  defp existing_system(%Map{} = view, solar_id, _unknown?) do
    Repo.get_by(MapSystem, mask_id: view.mask_id, solar_system_id: solar_id)
  end

  def first_map_for_mask(mask_id) do
    Repo.one(from(m in Map, where: m.mask_id == ^mask_id, order_by: [asc: m.id], limit: 1))
  end

  defp jita?(%MapSystem{unknown: true}), do: false

  defp jita?(%MapSystem{} = system) do
    system.solar_system_id == @jita_solar_system_id or
      String.downcase(system.name || "") == "jita"
  end

  def add_jita_system(%Map{} = view) do
    add_system_to_map(view, %{
      solar_system_id: @jita_solar_system_id,
      name: "Jita",
      security: 0.9,
      x: 880.0,
      y: 380.0
    })
  end

  def seed_jita_systems do
    from(m in Map, order_by: [asc: m.id])
    |> Repo.all()
    |> Enum.uniq_by(& &1.mask_id)
    |> Enum.each(fn view ->
      if list_systems(view.mask_id) == [] do
        {:ok, _} = add_jita_system(view)
      end
    end)
  end

  def add_unknown_system(%Map{} = view, attrs \\ %{}) do
    add_system_to_map(
      view,
      Elixir.Map.merge(%{unknown: true, solar_system_id: 0, name: "unknown"}, attrs)
    )
  end

  def ensure_unknown_nodes(%MapSystem{} = system) do
    view = first_map_for_mask(system.mask_id)
    linked = connection_codes(system)

    system.id
    |> list_signatures()
    |> Enum.filter(&(&1.site_type == "wormhole"))
    |> Enum.map(&SigParser.wormhole_code(&1.type_name))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.reject(&Elixir.MapSet.member?(linked, &1))
    |> Enum.reduce(0, fn code, count ->
      case view && add_unknown_system(view) do
        {:ok, placeholder} ->
          case upsert_connection(system.mask_id, system.id, placeholder.id, %{hole_type: code}) do
            {:ok, _conn, _created?} -> count + 1
            _error -> count
          end

        _error ->
          count
      end
    end)
  end

  defp connection_codes(%MapSystem{} = system) do
    system.mask_id
    |> list_connections()
    |> Enum.filter(&(&1.from_system_id == system.id or &1.to_system_id == system.id))
    |> Enum.map(&(&1.hole_type || ""))
    |> Elixir.MapSet.new()
  end

  def delete_unlinked_unknowns(mask_id) do
    Repo.delete_all(
      from(s in MapSystem,
        where:
          s.mask_id == ^mask_id and s.unknown and
            s.id not in ^connected_system_ids(mask_id)
      )
    )

    :ok
  end

  def convert_unknown_system(%MapSystem{unknown: true} = system, attrs) do
    attrs = attrs |> fill_system_data() |> Elixir.Map.put(:unknown, false)
    solar_id = solar_system_id(attrs)

    existing =
      if is_integer(solar_id) and solar_id > 0 do
        Repo.get_by(MapSystem, mask_id: system.mask_id, solar_system_id: solar_id)
      end

    if is_struct(existing, MapSystem) and existing.id != system.id do
      merge_system(system, existing)
      broadcast_map_update(existing.mask_id)
      {:ok, existing}
    else
      system
      |> MapSystem.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, converted} = ok ->
          if jita?(converted), do: ensure_welcome_notes(converted)
          ok

        error ->
          error
      end
    end
  end

  defp merge_system(%MapSystem{} = source, %MapSystem{} = target) do
    merge_signatures(source, target)
    merge_comments_and_flares(source, target)
    merge_stats(source, target)
    merge_connections(source, target)
    merge_positions(source, target)
    delete_system(source)
    :ok
  end

  defp merge_signatures(source, target) do
    Repo.all(from(s in Signature, where: s.map_system_id == ^source.id))
    |> Enum.each(fn signature ->
      case Repo.get_by(Signature, map_system_id: target.id, sig_id: signature.sig_id) do
        nil -> Repo.update(Ecto.Changeset.change(signature, map_system_id: target.id))
        _ -> Repo.delete(signature)
      end
    end)
  end

  defp merge_comments_and_flares(source, target) do
    Repo.update_all(
      from(c in Ztripwire.Mapping.Comment, where: c.map_system_id == ^source.id),
      set: [map_system_id: target.id]
    )

    Repo.update_all(
      from(f in Ztripwire.Mapping.Flare, where: f.map_system_id == ^source.id),
      set: [map_system_id: target.id]
    )
  end

  defp merge_stats(source, target) do
    case Repo.get_by(Ztripwire.Mapping.SystemStat, map_system_id: source.id) do
      nil ->
        :ok

      source_stat ->
        case Repo.get_by(Ztripwire.Mapping.SystemStat, map_system_id: target.id) do
          nil ->
            source_stat
            |> Ecto.Changeset.change(map_system_id: target.id)
            |> Repo.update()

          target_stat ->
            target_stat
            |> Ecto.Changeset.change(
              jumps: (target_stat.jumps || 0) + (source_stat.jumps || 0),
              kills: (target_stat.kills || 0) + (source_stat.kills || 0),
              visits: (target_stat.visits || 0) + (source_stat.visits || 0),
              recorded_at: max_datetime(target_stat.recorded_at, source_stat.recorded_at)
            )
            |> Repo.update()

            Repo.delete(source_stat)
        end
    end
  end

  defp max_datetime(nil, other), do: other
  defp max_datetime(other, nil), do: other
  defp max_datetime(a, b), do: if(NaiveDateTime.compare(a, b) == :lt, do: b, else: a)

  defp merge_connections(source, target) do
    Repo.all(
      from(c in MapConnection,
        where:
          c.mask_id == ^source.mask_id and
            (c.from_system_id == ^source.id or c.to_system_id == ^source.id)
      )
    )
    |> Enum.each(fn conn ->
      from_id = if conn.from_system_id == source.id, do: target.id, else: conn.from_system_id
      to_id = if conn.to_system_id == source.id, do: target.id, else: conn.to_system_id

      cond do
        from_id == to_id ->
          Repo.delete(conn)

        true ->
          existing =
            Repo.one(
              from(c in MapConnection,
                where:
                  c.mask_id == ^source.mask_id and c.id != ^conn.id and
                    ((c.from_system_id == ^from_id and c.to_system_id == ^to_id) or
                       (c.from_system_id == ^to_id and c.to_system_id == ^from_id))
              )
            )

          case existing do
            nil ->
              conn
              |> MapConnection.changeset(%{from_system_id: from_id, to_system_id: to_id})
              |> Repo.update()

            %MapConnection{} = survivor ->
              Repo.update_all(
                from(j in Ztripwire.Mapping.ConnectionJump,
                  where: j.map_connection_id == ^conn.id
                ),
                set: [map_connection_id: survivor.id]
              )

              Repo.delete(conn)
          end
      end
    end)
  end

  defp merge_positions(source, target) do
    Repo.all(from(p in MapViewSystem, where: p.map_system_id == ^source.id))
    |> Enum.each(fn position ->
      %MapViewSystem{}
      |> MapViewSystem.changeset(%{
        map_id: position.map_id,
        map_system_id: target.id,
        x: position.x,
        y: position.y
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:map_id, :map_system_id])
    end)
  end

  defp fill_system_data(attrs), do: attrs |> drop_empty() |> put_system_data()

  defp drop_empty(attrs) do
    Elixir.Map.reject(attrs, fn {_key, value} -> is_nil(value) or value == "" or value == [] end)
  end

  defp put_system_data(attrs) do
    name = attrs[:name] || attrs["name"]

    attrs
    |> solar_system_id()
    |> Systems.sde_attrs(name)
    |> Enum.reduce(attrs, fn {key, value}, acc ->
      if Elixir.Map.has_key?(acc, key) or Elixir.Map.has_key?(acc, to_string(key)) do
        acc
      else
        Elixir.Map.put(acc, key, value)
      end
    end)
  end

  defp solar_system_id(attrs), do: attrs[:solar_system_id] || attrs["solar_system_id"]

  def update_system(%MapSystem{unknown: true} = system, attrs) do
    convert_unknown_system(system, attrs)
  end

  def update_system(%MapSystem{} = system, attrs) do
    attrs = if solar_changed?(system, attrs), do: fill_system_data(attrs), else: attrs

    system
    |> MapSystem.changeset(attrs)
    |> Repo.update()
  end

  defp solar_changed?(system, attrs) do
    solar = solar_system_id(attrs)
    is_integer(solar) and solar > 0 and solar != system.solar_system_id
  end

  def delete_system(%MapSystem{} = system) do
    Repo.delete_all(
      from(c in MapConnection,
        where: c.from_system_id == ^system.id or c.to_system_id == ^system.id
      )
    )

    Repo.delete(system)
  end

  def delete_map_full(%Map{} = map) do
    last? = length(list_maps_for_mask(map.mask_id)) <= 1

    if last? do
      delete_mask_chain(map.mask_id)
    end

    Repo.delete(map)
  end

  def delete_mask_chain(mask_id) do
    system_ids = from(s in MapSystem, where: s.mask_id == ^mask_id, select: s.id)

    connection_ids =
      from(c in MapConnection, where: c.mask_id == ^mask_id, select: c.id)

    Repo.delete_all(
      from(j in Ztripwire.Mapping.ConnectionJump,
        where: j.map_connection_id in subquery(connection_ids)
      )
    )

    Repo.delete_all(from(s in Signature, where: s.map_system_id in subquery(system_ids)))

    Repo.delete_all(
      from(c in Ztripwire.Mapping.Comment, where: c.map_system_id in subquery(system_ids))
    )

    Repo.delete_all(
      from(f in Ztripwire.Mapping.Flare, where: f.map_system_id in subquery(system_ids))
    )

    Repo.delete_all(
      from(s in Ztripwire.Mapping.SystemStat, where: s.map_system_id in subquery(system_ids))
    )

    Repo.delete_all(from(c in MapConnection, where: c.mask_id == ^mask_id))
    Repo.delete_all(from(s in MapSystem, where: s.mask_id == ^mask_id))
    :ok
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

  def sync_map_after_signature_change(%MapSystem{} = system, deleted_signatures)
      when is_list(deleted_signatures) do
    dropped = drop_connections_for_signatures(system, deleted_signatures)

    linked = auto_link_wormholes(system, dropped_pair_keys(dropped))

    _ = ensure_unknown_nodes(system)
    delete_unlinked_unknowns(system.mask_id)

    candidates =
      (dropped |> Enum.flat_map(fn {conn, _, _} -> [conn.from_system_id, conn.to_system_id] end)) ++
        (linked |> Enum.flat_map(fn conn -> [conn.from_system_id, conn.to_system_id] end))

    orphans = hide_orphan_systems(system.mask_id, Enum.uniq(candidates))
    hidden = orphans + hide_detached_systems(system.mask_id)

    {length(dropped), length(linked), hidden}
  end

  def drop_connections_for_signatures(%MapSystem{} = system, deleted_signatures) do
    codes = deleted_codes(deleted_signatures)

    if Elixir.MapSet.size(codes) == 0 do
      []
    else
      system.mask_id
      |> list_connections_with_endpoints()
      |> Enum.filter(fn {conn, from, to} ->
        (from.id == system.id or to.id == system.id) and
          Elixir.MapSet.member?(codes, String.upcase(to_string(conn.hole_type || "")))
      end)
      |> tap(fn dropping -> Enum.each(dropping, fn {conn, _, _} -> Repo.delete(conn) end) end)
    end
  end

  def auto_link_wormholes(%MapSystem{} = system, excluded_pairs \\ Elixir.MapSet.new()) do
    others =
      system.mask_id
      |> list_wormhole_signatures()
      |> Enum.reject(&(&1.map_system_id == system.id))

    system.id
    |> list_signatures()
    |> Enum.filter(&(&1.site_type == "wormhole"))
    |> Enum.flat_map(&link_targets(&1, others))
    |> Enum.uniq_by(& &1.map_system_id)
    |> Enum.reject(fn target ->
      Elixir.MapSet.member?(
        excluded_pairs,
        pair_key(system.id, target.map_system_id, SigParser.wormhole_code(target.type_name))
      )
    end)
    |> Enum.filter(fn target ->
      case connection_between(system.mask_id, system.id, target.map_system_id) do
        nil -> true
        conn -> conn.hole_type in [nil, ""]
      end
    end)
    |> Enum.map(fn target ->
      code = SigParser.wormhole_code(target.type_name)

      cond do
        connection_between(system.mask_id, system.id, target.map_system_id) != nil ->
          {:ok, conn, _created?} =
            upsert_connection(system.mask_id, system.id, target.map_system_id, %{hole_type: code})

          conn

        placeholder = placeholder_connection(system, code) ->
          {:ok, conn} = repoint_placeholder(placeholder, system, target)
          conn

        true ->
          {:ok, conn, _created?} =
            upsert_connection(system.mask_id, system.id, target.map_system_id, %{hole_type: code})

          conn
      end
    end)
  end

  defp placeholder_connection(%MapSystem{} = system, code) when is_binary(code) do
    system.mask_id
    |> list_connections()
    |> Enum.find(fn conn ->
      conn.hole_type == code and
        (conn.from_system_id == system.id or conn.to_system_id == system.id) and
        placeholder_endpoint?(conn, system.id)
    end)
  end

  defp placeholder_connection(_system, _code), do: nil

  defp placeholder_endpoint?(conn, system_id) do
    peer_id =
      if conn.from_system_id == system_id, do: conn.to_system_id, else: conn.from_system_id

    case get_system(peer_id) do
      %MapSystem{unknown: true} -> true
      _ -> false
    end
  end

  defp repoint_placeholder(conn, system, target) do
    conn
    |> MapConnection.changeset(%{from_system_id: system.id, to_system_id: target.map_system_id})
    |> Repo.update()
  end

  defp dropped_pair_keys(dropped) do
    Elixir.MapSet.new(dropped, fn {conn, _, _} ->
      pair_key(conn.from_system_id, conn.to_system_id, conn.hole_type)
    end)
  end

  defp pair_key(system_a_id, system_b_id, code) do
    Ztripwire.Mapping.Links.pair_key(system_a_id, system_b_id, code)
  end

  def hide_orphan_systems(mask_id, candidate_ids) do
    home_solars =
      Repo.all(
        from(m in Map,
          where: m.mask_id == ^mask_id and not is_nil(m.home_solar_system_id),
          select: m.home_solar_system_id
        )
      )

    query =
      from(s in MapSystem,
        where:
          s.mask_id == ^mask_id and is_nil(s.hidden_at) and
            s.id in ^candidate_ids and
            s.id not in ^connected_system_ids(mask_id)
      )

    query =
      if home_solars == [] do
        query
      else
        from(s in query, where: s.solar_system_id not in ^home_solars)
      end

    {count, _} =
      Repo.update_all(query, set: [hidden_at: DateTime.utc_now() |> DateTime.truncate(:second)])

    count
  end

  defp connected_system_ids(mask_id) do
    from_ids =
      Repo.all(from(c in MapConnection, where: c.mask_id == ^mask_id, select: c.from_system_id))

    to_ids =
      Repo.all(from(c in MapConnection, where: c.mask_id == ^mask_id, select: c.to_system_id))

    Elixir.MapSet.new(from_ids ++ to_ids) |> Elixir.MapSet.to_list()
  end

  def hide_detached_systems(mask_id) do
    homes =
      mask_id
      |> list_maps_for_mask()
      |> Enum.map(&home_system_id/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if homes == [] do
      0
    else
      reachable =
        Enum.reduce(homes, Elixir.MapSet.new(), fn home_id, acc ->
          Elixir.MapSet.union(acc, reachable_system_ids(mask_id, home_id))
        end)

      {count, _} =
        Repo.update_all(
          from(s in MapSystem,
            where:
              s.mask_id == ^mask_id and is_nil(s.hidden_at) and
                s.id not in ^Elixir.MapSet.to_list(reachable)
          ),
          set: [hidden_at: DateTime.utc_now() |> DateTime.truncate(:second)]
        )

      count
    end
  end

  defp home_system_id(%Map{home_solar_system_id: nil}), do: nil

  defp home_system_id(%Map{home_solar_system_id: solar, mask_id: mask_id}) do
    case Repo.one(
           from(s in MapSystem, where: s.mask_id == ^mask_id and s.solar_system_id == ^solar)
         ) do
      %MapSystem{id: id} -> id
      nil -> nil
    end
  end

  defp reachable_system_ids(mask_id, home_id) do
    adj =
      Repo.all(
        from(c in MapConnection,
          where: c.mask_id == ^mask_id,
          select: {c.from_system_id, c.to_system_id}
        )
      )
      |> Enum.reduce(%{}, fn {from_id, to_id}, acc ->
        acc
        |> Elixir.Map.update(from_id, [to_id], &[to_id | &1])
        |> Elixir.Map.update(to_id, [from_id], &[from_id | &1])
      end)

    bfs_reachable(:queue.from_list([home_id]), adj, Elixir.MapSet.new([home_id]))
  end

  defp bfs_reachable(queue, adj, seen) do
    case :queue.out(queue) do
      {:empty, _} ->
        seen

      {{:value, id}, rest} ->
        {queue, seen} =
          Enum.reduce(Elixir.Map.get(adj, id, []), {rest, seen}, fn neighbor, {q, s} ->
            if Elixir.MapSet.member?(s, neighbor) do
              {q, s}
            else
              {:queue.in(neighbor, q), Elixir.MapSet.put(s, neighbor)}
            end
          end)

        bfs_reachable(queue, adj, seen)
    end
  end

  def cycle_connection_ids(connections, _root_id \\ nil) do
    connections
    |> Enum.sort_by(fn {conn, _from, _to} -> conn.id end)
    |> Enum.reduce({%{}, Elixir.MapSet.new()}, fn {conn, from, to}, {parents, cycle} ->
      parents =
        parents
        |> Elixir.Map.put_new(from.id, from.id)
        |> Elixir.Map.put_new(to.id, to.id)

      if from.id == to.id or root_of(parents, from.id) == root_of(parents, to.id) do
        {parents, Elixir.MapSet.put(cycle, conn.id)}
      else
        {union(parents, from.id, to.id), cycle}
      end
    end)
    |> elem(1)
  end

  defp root_of(parents, id) do
    case Elixir.Map.get(parents, id, id) do
      ^id -> id
      parent -> root_of(parents, parent)
    end
  end

  defp union(parents, a, b) do
    root_a = root_of(parents, a)
    root_b = root_of(parents, b)
    Elixir.Map.put(parents, root_b, root_a)
  end

  defp deleted_codes(signatures) do
    Ztripwire.Mapping.Links.deleted_codes(signatures)
  end

  defp link_targets(signature, others) do
    Ztripwire.Mapping.Links.link_targets(signature, others)
  end

  def prune_expired_signatures(now \\ DateTime.utc_now()) do
    expired =
      Repo.all(from(s in Signature, where: not is_nil(s.expires_at) and s.expires_at < ^now))

    {count, _} =
      Repo.delete_all(
        from(s in Signature, where: not is_nil(s.expires_at) and s.expires_at < ^now)
      )

    expired
    |> Enum.filter(&(&1.site_type == "wormhole"))
    |> Enum.group_by(& &1.map_system_id)
    |> Enum.each(fn {system_id, signatures} ->
      system = get_system!(system_id)
      dropped = drop_connections_for_signatures(system, signatures)

      candidates =
        dropped
        |> Enum.flat_map(fn {conn, _, _} -> [conn.from_system_id, conn.to_system_id] end)
        |> Enum.uniq()

      hide_orphan_systems(system.mask_id, candidates)
      hide_detached_systems(system.mask_id)
      broadcast_map_update(system.mask_id)
    end)

    {:ok, count}
  end

  defp broadcast_map_update(mask_id) do
    Phoenix.PubSub.broadcast(
      Ztripwire.PubSub,
      Ztripwire.Tracking.mask_topic(mask_id),
      {:map_updated, mask_id}
    )
  end

  def list_signatures(system_id) do
    Repo.all(
      from(s in Signature,
        where: s.map_system_id == ^system_id,
        order_by: [asc: s.sig_id]
      )
    )
  end

  def upsert_signatures(%MapSystem{} = system, entries, %Character{id: character_id})
      when is_list(entries) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {added, updated, counts} =
      Enum.reduce(entries, {0, 0, %{}}, fn entry, {added, updated, counts} ->
        existing = Repo.get_by(Signature, map_system_id: system.id, sig_id: entry.sig_id)

        case existing do
          nil ->
            attrs =
              entry
              |> SigParser.scan_insert_attrs(now)
              |> Elixir.Map.merge(%{
                map_system_id: system.id,
                created_by_id: character_id,
                updated_by_id: character_id
              })

            case %Signature{} |> Signature.changeset(attrs) |> Repo.insert() do
              {:ok, signature} ->
                {added + 1, updated,
                 bump_counts(
                   counts,
                   :signatures_added,
                   :wormholes_added,
                   signature.site_type == "wormhole"
                 )}

              {:error, _} ->
                {added, updated, counts}
            end

          %Signature{} = signature ->
            case SigParser.scan_update_attrs(signature, entry, now) do
              :skip ->
                {added, updated, counts}

              attrs ->
                attrs = Elixir.Map.put(attrs, :updated_by_id, character_id)

                case signature |> Signature.changeset(attrs) |> Repo.update() do
                  {:ok, updated_signature} ->
                    {added, updated + 1,
                     bump_counts(
                       counts,
                       :signatures_updated,
                       :wormholes_updated,
                       updated_signature.site_type == "wormhole"
                     )}

                  {:error, _} ->
                    {added, updated, counts}
                end
            end
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

    scanned_at =
      attrs[:inserted_at] || attrs["inserted_at"] || (existing && existing.inserted_at) ||
        DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

    expires_at =
      attrs[:expires_at] || attrs["expires_at"] ||
        NaiveDateTime.add(scanned_at, life_length, :second)

    attrs |> Elixir.Map.put(:life_length, life_length) |> Elixir.Map.put(:expires_at, expires_at)
  end

  def delete_signature(%Signature{} = signature, character \\ nil) do
    signature
    |> paired_signatures()
    |> Enum.each(&delete_signature_row(&1, character))

    delete_signature_row(signature, character)
  end

  defp delete_signature_row(signature, character) do
    result = Repo.delete(signature)

    if match?({:ok, _}, result) and is_struct(character, Character) do
      Accounts.bump_stats(character.id, signature_deleted_stats(signature.site_type))
    end

    result
  end

  defp paired_signatures(%Signature{site_type: "wormhole"} = signature) do
    with code when not is_nil(code) <- SigParser.wormhole_code(signature.type_name),
         %MapSystem{} = system <- get_system(signature.map_system_id),
         %MapConnection{} = connection <- connection_for_code(system, code) do
      peer_id =
        if connection.from_system_id == system.id,
          do: connection.to_system_id,
          else: connection.from_system_id

      peer_id
      |> list_signatures()
      |> Enum.filter(
        &(&1.site_type == "wormhole" and SigParser.wormhole_code(&1.type_name) == code)
      )
    else
      _ -> []
    end
  end

  defp paired_signatures(_signature), do: []

  defp connection_for_code(system, code) do
    Repo.one(
      from(c in MapConnection,
        where:
          c.mask_id == ^system.mask_id and c.hole_type == ^code and
            (c.from_system_id == ^system.id or c.to_system_id == ^system.id)
      )
    )
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

  def list_wormhole_signatures(mask_id) do
    system_ids = from(s in MapSystem, where: s.mask_id == ^mask_id, select: s.id)

    Repo.all(
      from(sig in Signature,
        where: sig.map_system_id in subquery(system_ids) and sig.site_type == "wormhole",
        order_by: [asc: sig.sig_id]
      )
    )
  end

  def sync_connection_life(%MapConnection{} = connection) do
    with code when is_binary(code) and code != "" <- connection.hole_type,
         :update <- time_status_action(connection.time_status) do
      connection
      |> matching_wormhole_signatures(code)
      |> Enum.each(fn signature -> apply_time_status(signature, connection.time_status) end)
    else
      _ -> :ok
    end

    :ok
  end

  defp time_status_action("<1h"), do: :update
  defp time_status_action("critical"), do: :update
  defp time_status_action("stable"), do: :update
  defp time_status_action(_), do: :noop

  defp apply_time_status(%Signature{} = signature, time_status) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    expires_at =
      case time_status do
        "critical" -> DateTime.add(now, 4 * 3600, :second)
        "<1h" -> DateTime.add(now, 3600, :second)
        _stable -> DateTime.add(signature.inserted_at, signature.life_length || 259_200, :second)
      end

    signature
    |> Signature.changeset(%{expires_at: expires_at})
    |> Repo.update()
  end

  defp matching_wormhole_signatures(%MapConnection{} = connection, code) do
    ids = [connection.from_system_id, connection.to_system_id]

    Repo.all(
      from(s in Signature,
        where: s.map_system_id in ^ids and s.site_type == "wormhole"
      )
    )
    |> Enum.filter(&(Ztripwire.Signatures.wormhole_code(&1.type_name) == code))
  end

  def sync_signature_to_connections(%Map{} = map, %MapSystem{} = system, old_code, new_code)
      when is_binary(new_code) do
    map.mask_id
    |> list_connections_with_endpoints()
    |> Enum.filter(fn {conn, from, to} ->
      (from.id == system.id or to.id == system.id) and
        (conn.hole_type in [nil, ""] or (not is_nil(old_code) and conn.hole_type == old_code))
    end)
    |> Enum.each(fn {conn, _, _} -> update_connection(conn, %{hole_type: new_code}) end)

    :ok
  end

  def sync_signature_to_connections(_map, _system, _old_code, _new_code), do: :ok

  def list_comments(system_id) do
    Repo.all(
      from(c in Ztripwire.Mapping.Comment,
        where: c.map_system_id == ^system_id,
        order_by: [desc: c.sticky, asc: c.id],
        preload: [:character, :updated_by]
      )
    )
  end

  def welcome_notes, do: [@welcome_shortcuts, @welcome_markdown]

  def ensure_welcome_notes(%MapSystem{} = system) do
    mask_id = system.mask_id
    existing = system.id |> list_comments() |> Enum.map(& &1.body)

    welcome_notes()
    |> Enum.reject(&(&1 in existing))
    |> Enum.each(fn body ->
      {:ok, _} = create_comment(system, %{body: body, mask_id: mask_id})
    end)

    :ok
  end

  def refresh_welcome_shortcuts do
    from(c in Ztripwire.Mapping.Comment, where: like(c.body, "# Shortcuts%"))
    |> Repo.all()
    |> Enum.reject(&(&1.body == @welcome_shortcuts))
    |> Enum.each(fn comment ->
      {:ok, _} =
        comment
        |> Ztripwire.Mapping.Comment.changeset(%{body: @welcome_shortcuts})
        |> Repo.update()
    end)

    :ok
  end

  def seed_welcome_notes do
    from(s in MapSystem,
      where: not s.unknown and (s.solar_system_id == ^@jita_solar_system_id or s.name == "Jita")
    )
    |> Repo.all()
    |> Enum.each(&ensure_welcome_notes/1)
  end

  def create_comment(%MapSystem{} = system, attrs, character \\ nil) do
    character_id = if is_struct(character, Character), do: character.id, else: nil

    case %Ztripwire.Mapping.Comment{}
         |> Ztripwire.Mapping.Comment.changeset(
           merge_attrs(attrs, %{
             map_system_id: system.id,
             character_id: character_id,
             updated_by_id: character_id
           })
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

  def delete_comment(%Ztripwire.Mapping.Comment{} = comment, character \\ nil) do
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

  def get_comment!(id), do: Repo.get!(Ztripwire.Mapping.Comment, id)

  def update_comment(%Ztripwire.Mapping.Comment{} = comment, attrs, character \\ nil) do
    attrs =
      attrs
      |> then(fn attrs ->
        if is_struct(character, Character),
          do: Elixir.Map.put(attrs, :updated_by_id, character.id),
          else: attrs
      end)
      |> then(fn attrs ->
        if Elixir.Map.has_key?(attrs, :body) or Elixir.Map.has_key?(attrs, "body"),
          do: Elixir.Map.put(attrs, :edited, true),
          else: attrs
      end)

    case comment
         |> Ztripwire.Mapping.Comment.changeset(attrs)
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

  def move_comment(%Ztripwire.Mapping.Comment{} = comment, to_system_id, character \\ nil) do
    case comment
         |> Ztripwire.Mapping.Comment.changeset(%{map_system_id: to_system_id})
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

  def prune_expired_flares(now \\ DateTime.utc_now()) do
    {count, _} =
      Repo.delete_all(
        from(f in Ztripwire.Mapping.Flare,
          where: not is_nil(f.expires_at) and f.expires_at < ^now
        )
      )

    {:ok, count}
  end

  def upsert_system_stat(%MapSystem{} = system, attrs) do
    case Repo.get_by(Ztripwire.Mapping.SystemStat, map_system_id: system.id) do
      nil ->
        %Ztripwire.Mapping.SystemStat{}
        |> Ztripwire.Mapping.SystemStat.changeset(
          Elixir.Map.put(attrs, :map_system_id, system.id)
        )
        |> Repo.insert()

      %Ztripwire.Mapping.SystemStat{} = stat ->
        stat
        |> Ztripwire.Mapping.SystemStat.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_system_stat(system_id),
    do: Repo.get_by(Ztripwire.Mapping.SystemStat, map_system_id: system_id)

  def map_solar_ids do
    Repo.all(
      from(s in MapSystem,
        where: not is_nil(s.solar_system_id),
        select: s.solar_system_id,
        distinct: true
      )
    )
  end

  def record_system_activity(attrs) do
    %SystemActivity{}
    |> SystemActivity.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  def list_system_activity(solar_system_id, since) do
    Repo.all(
      from(a in SystemActivity,
        where: a.solar_system_id == ^solar_system_id and a.recorded_at >= ^since,
        order_by: [asc: a.recorded_at]
      )
    )
  end

  def prune_system_activity(before) do
    Repo.delete_all(from(a in SystemActivity, where: a.recorded_at < ^before))
  end

  def bucket_activity(rows, now, count, width_hours) do
    width_s = width_hours * 3600
    empty = List.duplicate(0, count)
    now = naive(now)

    {jumps, ships, pods, npcs} =
      Enum.reduce(rows, {empty, empty, empty, empty}, fn row, {jumps, ships, pods, npcs} ->
        age_s = NaiveDateTime.diff(now, naive(row.recorded_at))
        index = count - 1 - div(max(age_s, 0), width_s)

        if index >= 0 and index < count do
          {
            List.update_at(jumps, index, &(&1 + (row.ship_jumps || 0))),
            List.update_at(ships, index, &(&1 + (row.ship_kills || 0))),
            List.update_at(pods, index, &(&1 + (row.pod_kills || 0))),
            List.update_at(npcs, index, &(&1 + (row.npc_kills || 0)))
          }
        else
          {jumps, ships, pods, npcs}
        end
      end)

    {jumps, ships, pods, npcs}
  end

  defp naive(%NaiveDateTime{} = value), do: value
  defp naive(%DateTime{} = value), do: DateTime.to_naive(value)

  def list_system_stats(mask_id) do
    system_ids = from(s in MapSystem, where: s.mask_id == ^mask_id, select: s.id)

    Repo.all(
      from(st in Ztripwire.Mapping.SystemStat, where: st.map_system_id in subquery(system_ids))
    )
    |> Elixir.Map.new(&{&1.map_system_id, &1})
  end

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

  def map_statistics(mask_id) do
    systems = list_systems(mask_id)
    system_ids = Enum.map(systems, & &1.id)

    signatures =
      if system_ids == [],
        do: 0,
        else: Repo.aggregate(from(s in Signature, where: s.map_system_id in ^system_ids), :count)

    connections = length(list_connections(mask_id))

    comments =
      if system_ids == [],
        do: 0,
        else:
          Repo.aggregate(
            from(c in Ztripwire.Mapping.Comment, where: c.map_system_id in ^system_ids),
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

  defp merge_attrs(attrs, extra), do: Elixir.Map.merge(attrs, extra)
end
