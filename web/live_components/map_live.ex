defmodule TripwireWeb.LiveComponents.MapLive do
  use TripwireWeb, :live_component

  alias Tripwire.Data
  alias Tripwire.EveImages
  alias Tripwire.Mapping
  alias Tripwire.Signatures, as: SigParser
  alias Tripwire.Wormholes

  import TripwireWeb.FormHelpers, only: [present: 1]

  @occupant_tip_w 280
  @occupant_tip_max_w 560
  @occupant_char_w 7.0
  @occupant_tip_chrome 88
  @occupant_row_h 28
  @occupant_row_gap 4
  @occupant_tip_pad 8
  @occupant_badge_inset 6
  @map_width 1000.0

  def update(assigns, socket) do
    map_id = Map.get(assigns, :map_id)
    data = Map.get(assigns, :demo_state) || :db
    systems = Map.get_lazy(assigns, :systems, fn -> Data.list_visible_systems(data, map_id) end)

    connections =
      Map.get_lazy(assigns, :connections, fn ->
        Data.list_connections_with_endpoints(data, map_id)
      end)

    stats = Map.get_lazy(assigns, :stats, fn -> Data.list_system_stats(data, map_id) end)
    occupants = Map.get(assigns, :occupants, [])
    zoom = map_zoom(Map.get(assigns, :map_scale))
    {pan_x, pan_y} = Mapping.home_center(systems, Map.get(assigns, :map), zoom)
    {view_w, view_h} = Mapping.view_size(zoom)
    {node_w, node_h} = Mapping.node_size()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:systems, systems)
     |> assign(:connections, connections)
     |> assign(:stats, stats)
     |> assign(:occupants, occupants)
     |> assign(:node_w, node_w)
     |> assign(:node_h, node_h)
     |> assign(:node_radius, node_radius(Map.get(assigns, :node_roundness), node_h))
     |> assign(:wh_sigs, wormhole_sigs(data, map_id))
     |> assign_new(:pan_x, fn -> pan_x end)
     |> assign_new(:pan_y, fn -> pan_y end)
     |> assign_new(:view_w, fn -> view_w end)
     |> assign_new(:view_h, fn -> view_h end)
     |> assign_new(:map_locked, fn -> false end)
     |> assign_new(:show_row_guides, fn -> false end)
     |> assign_new(:show_row_counts, fn -> false end)
     |> assign_new(:angled_lines, fn -> true end)
     |> assign_new(:show_jump_lines, fn -> true end)
     |> assign_new(:show_line_glow, fn -> true end)
     |> assign_new(:show_node_badges, fn -> true end)
     |> assign_new(:line_weight, fn -> 2 end)
     |> assign_new(:node_roundness, fn -> "oval" end)
     |> assign_new(:map_background, fn -> nil end)}
  end

  defp node_radius("square", _node_h), do: 0.0
  defp node_radius("rounded", node_h), do: node_h / 4
  defp node_radius(_roundness, node_h), do: node_h / 2

  defp node_icon_x(radius), do: 4.0 + Float.round(radius * 0.55, 1)
  defp node_icon_y(radius), do: 4.0 + Float.round(radius * 0.09, 1)

  defp node_text_offset("", node_h), do: node_h / 2 - 25.25
  defp node_text_offset(_footer, node_h), do: node_h / 2 - 35.25

  defp node_badge_inset(radius), do: max(4, round(radius * 0.45))

  defp node_dot_x(node_w, radius), do: node_w - max(radius, 18.0) - 4.0

  defp map_zoom(scale) when is_number(scale), do: Mapping.default_zoom() * scale / 100
  defp map_zoom(_), do: Mapping.default_zoom()

  def handle_event("select-system", %{"id" => id}, socket) do
    send(self(), {:select_system, String.to_integer(id)})
    {:noreply, socket}
  end

  def handle_event("open-system", %{"id" => id}, socket) do
    send(self(), {:open_system, String.to_integer(id)})
    {:noreply, socket}
  end

  def handle_event("show-favorites", _params, socket) do
    send(self(), :show_favorites)
    {:noreply, socket}
  end

  def handle_event("toggle-map-lock", _params, socket) do
    send(self(), :toggle_map_lock)
    {:noreply, socket}
  end

  def handle_event("open-map-modal", _params, socket) do
    send(self(), :open_map_modal)
    {:noreply, socket}
  end

  def handle_event("new-map", _params, socket) do
    send(self(), {:new_map})
    {:noreply, socket}
  end

  def handle_event("switch-map", %{"id" => id}, socket) do
    send(self(), {:switch_map, String.to_integer(id)})
    {:noreply, socket}
  end

  def handle_event("add-viewing", _params, socket) do
    send(self(), {:add_viewing})
    {:noreply, socket}
  end

  def handle_event("map-layout", %{"layout" => layout}, socket) do
    send(self(), {:map_layout, layout})
    {:noreply, socket}
  end

  attr :position, :map, default: %{"x" => 0, "y" => 12, "w" => 12, "h" => 12}

  def render(assigns) do
    visible = visible_connections(assigns)
    cycle = Mapping.cycle_connection_ids(visible)

    assigns =
      assigns
      |> assign(:visible_connections, visible)
      |> assign(:map_bottom, map_bottom(assigns))
      |> assign(
        :drawn_connections,
        Enum.reject(visible, fn {conn, _from, _to} -> Elixir.MapSet.member?(cycle, conn.id) end)
      )
      |> assign(:loop_hint_ids, loop_hint_ids(visible, cycle))

    ~H"""
    <div
      id="map"
      class="grid-stack-item"
      gs-w={@position["w"]}
      gs-h={@position["h"] || 12}
      gs-x={@position["x"]}
      gs-y={@position["y"]}
      tabindex="0"
      phx-hook="GridWidget"
    >
      <div class="grid-stack-item-content bg-base-100 flex min-h-0 flex-col overflow-hidden">
        <ul class="list rounded-box shadow-md shrink-0">
          <li class="widget-header">
            <span id="chainTabs" class="join widget-header-tabs">
              <button
                :for={tab <- Map.get(assigns, :maps, [])}
                class={[
                  "join-item btn btn-xs",
                  if(@map_id == tab.id, do: "btn-primary", else: "btn-ghost")
                ]}
                title={tab.name}
                phx-click="switch-map"
                phx-value-id={tab.id}
                phx-target={@myself}
                disabled={@map_locked}
              >
                {tab.name}
              </button>
            </span>
            <button
              id="newTab"
              class="btn btn-ghost btn-xs"
              title="New tab"
              phx-click="new-map"
              phx-target={@myself}
              disabled={@map_locked}
            >
              <.icon name="hero-plus" class="size-4" />
            </button>
            <span class="opacity-30">|</span>
            <button
              id="map-edit"
              class="btn btn-ghost btn-xs"
              title="Edit map settings"
              phx-click="open-map-modal"
              phx-target={@myself}
              disabled={@map_locked}
            >
              <.icon name="hero-pencil" class="size-4" />
            </button>
            <button
              id="show-favorite"
              class="btn btn-ghost btn-xs"
              title="Add connected favorites to chain"
              phx-click="show-favorites"
              phx-target={@myself}
              disabled={@map_locked}
            >
              <.icon name="hero-star" class="size-4" />
            </button>
            <button
              id="show-viewing"
              class="btn btn-ghost btn-xs"
              title="Add viewing system to chain"
              phx-click="add-viewing"
              phx-target={@myself}
              disabled={@map_locked}
            >
              <.icon name="hero-eye" class="size-4" />
            </button>
            <button
              id="toggle-lock"
              class="btn btn-ghost btn-xs"
              title={if @map_locked, do: "Unlock map", else: "Lock map"}
              phx-click="toggle-map-lock"
              phx-target={@myself}
              data-locked={to_string(@map_locked)}
            >
              <.icon
                name={if @map_locked, do: "hero-lock-closed", else: "hero-lock-open"}
                class={if @map_locked, do: "size-4 text-active-accent", else: "size-4"}
              />
            </button>
            <details id="show-chainLegend" class="dropdown">
              <summary
                class="btn btn-ghost btn-xs"
                title="Chain legend: stable, end of life, mass destabbed, mass critical, frigate"
              >
                <.icon name="hero-share" class="size-4" />
              </summary>
              <div class="dropdown-content z-10 rounded bg-base-200 p-2 text-xs shadow">
                <p><span class="badge badge-outline badge-xs">—</span> Stable</p>
                <p><span class="badge badge-error badge-xs">- -</span> End of Life</p>
                <p><span class="badge badge-warning badge-xs">—</span> Mass Critical</p>
                <p class="mt-1 font-semibold">Statics</p>
                <p class="max-w-56 opacity-60">
                  Badges show each static's destination class, e.g. C5; hover for the hole type.
                </p>
                <p class="mt-1 font-semibold">System class</p>
                <p :for={cls <- Tripwire.Systems.classes()} class="flex items-center gap-1">
                  <span
                    class="inline-block size-2.5 rounded-sm"
                    style={"background-color: #{Tripwire.Systems.color(%{sys_class: cls})}"}
                  >
                  </span>
                  {cls}
                </p>
              </div>
            </details>
            <span class="ml-auto text-xs tabular-nums opacity-60">
              {length(@systems)} systems
            </span>
            <button
              id="chain-zoom-out"
              type="button"
              class="btn btn-ghost btn-xs"
              title="Zoom out"
              phx-click={JS.dispatch("tripwire:zoom-out", to: "#chain-map")}
              disabled={@map_locked}
            >
              <.icon name="hero-magnifying-glass-minus" class="size-4" />
            </button>
            <span id="chain-zoom-level" class="w-12 text-center text-xs tabular-nums opacity-60">
              100%
            </span>
            <button
              id="chain-zoom-in"
              type="button"
              class="btn btn-ghost btn-xs"
              title="Zoom in"
              phx-click={JS.dispatch("tripwire:zoom-in", to: "#chain-map")}
              disabled={@map_locked}
            >
              <.icon name="hero-magnifying-glass-plus" class="size-4" />
            </button>
            <button
              id="chain-zoom-reset"
              class="btn btn-ghost btn-xs"
              title="Reset Zoom"
              phx-click="map-layout"
              phx-value-layout="default"
              phx-target={@myself}
              disabled={@map_locked}
            >
              Reset Zoom
            </button>
            <span
              :if={selected_name(@systems, @selected_system_id)}
              class="badge badge-primary badge-sm"
            >
              {selected_name(@systems, @selected_system_id)}
            </span>
          </li>
        </ul>
        <div
          class="relative min-h-0 w-full flex-1 bg-cover bg-center bg-no-repeat"
          style={if @map_background, do: "background-image: url('#{@map_background}')"}
        >
          <svg
            :if={@show_row_guides}
            id="map-row-guides"
            viewBox={"#{@pan_x} #{@pan_y} #{@view_w} #{@view_h}"}
            preserveAspectRatio="none"
            class="pointer-events-none absolute inset-0 z-0 size-full"
            aria-hidden="true"
          >
            <line
              :for={{cy, _} <- row_groups(@systems)}
              x1="1%"
              x2="99%"
              y1={cy}
              y2={cy}
              class="stroke-base-content/20"
              stroke-width="1"
              stroke-dasharray="2 3"
              vector-effect="non-scaling-stroke"
            />
          </svg>
          <div :if={@show_row_counts} class="pointer-events-none absolute inset-0 z-20">
            <span
              :for={{cy, level} <- row_levels(@systems)}
              data-guide-y={cy}
              class="absolute left-[1%] ml-1.5 -translate-y-full pb-1 text-[10px] leading-none text-base-content/60 tabular-nums"
              style={"top: #{(cy - @pan_y) / @view_h * 100}%"}
            >
              {level}
            </span>
          </div>
          <svg
            id="chain-map"
            viewBox={"#{@pan_x} #{@pan_y} #{@view_w} #{@view_h}"}
            preserveAspectRatio="xMidYMid meet"
            class="relative z-10 block size-full touch-none select-none"
            phx-hook="MapDrag"
            data-selected={@selected_system_id}
            data-locked={to_string(@map_locked)}
            data-node-w={@node_w}
            data-node-h={@node_h}
          >
            <g :if={Map.get(assigns, :show_jump_lines, true)} id="map-edges">
              <path
                :for={{conn, from, to} <- @drawn_connections}
                id={"connection-#{conn.id}"}
                d={edge_path(from, to, Map.get(assigns, :angled_lines, true))}
                fill="none"
                stroke-dasharray={edge_dash(conn)}
                stroke-width={edge_stroke(conn, from, to, Map.get(assigns, :line_weight, 2))}
                class={edge_class(conn)}
              >
                <title>{edge_title(conn, from, to)}</title>
              </path>
            </g>
            <g id="map-nodes">
              <g
                :for={system <- @systems}
                id={"node-#{system.id}"}
                transform={"translate(#{system.x}, #{system.y})"}
                class={if system.unknown, do: "cursor-default", else: "cursor-pointer"}
                data-system-id={system.id}
                data-unknown={to_string(system.unknown)}
                phx-click={unless system.unknown, do: "select-system"}
                phx-value-id={system.id}
                phx-target={@myself}
              >
                <svg
                  :if={effect = node_effect(system)}
                  x={node_icon_x(@node_radius)}
                  y={node_icon_y(@node_radius)}
                  width="16"
                  height="16"
                  viewBox="0 0 1024 1024"
                  fill={Tripwire.Systems.effect_color(effect)}
                  data-effect={effect}
                >
                  <title>{"System effect: " <> effect}</title>
                  {Phoenix.HTML.raw(effect_icon(effect))}
                </svg>
                <rect
                  width={@node_w}
                  height={@node_h}
                  rx={@node_radius}
                  stroke-dasharray={if MapSet.member?(@loop_hint_ids, system.id), do: "6 4"}
                  style={"--class-ink: #{node_color(system)}"}
                  class={[
                    if(system.id == @selected_system_id,
                      do: "fill-primary/30 stroke-primary",
                      else: "fill-base-200 class-ink-stroke"
                    ),
                    if(
                      Map.get(assigns, :show_line_glow, true) and
                        MapSet.member?(@loop_hint_ids, system.id),
                      do: "class-ink-glow"
                    )
                  ]}
                  stroke-width="2"
                />
                <g
                  :if={tip = occupant_tip(@occupants, system, assigns)}
                  transform={"translate(#{tip.badge_x}, 0)"}
                  class="group"
                >
                  <clipPath id={"occupant-clip-#{system.id}"}>
                    <rect x="-14" y="-14" width="28" height="28" rx="8" />
                  </clipPath>
                  <image
                    href={occupant_badge(tip.members)}
                    x="-14"
                    y="-14"
                    width="28"
                    height="28"
                    preserveAspectRatio="xMidYMid slice"
                    clip-path={"url(#occupant-clip-#{system.id})"}
                    onerror={
                      "this.onerror=null;this.setAttribute('href','#{EveImages.unknown_character_portrait(64)}')"
                    }
                  />
                  <rect
                    x="-14"
                    y="-14"
                    width="28"
                    height="28"
                    rx="8"
                    class="fill-none stroke-primary"
                    stroke-width="2"
                  />
                  <foreignObject
                    x={tip.x}
                    y={tip.y}
                    width={tip.width}
                    height={tip.height}
                    class="pointer-events-none opacity-0 transition-opacity duration-150 group-hover:opacity-100"
                  >
                    <div
                      xmlns="http://www.w3.org/1999/xhtml"
                      class="space-y-1 rounded-box border border-base-content/20 bg-base-300 p-2 shadow-xl"
                    >
                      <div
                        :for={occupant <- tip.members}
                        class="flex items-center gap-2"
                      >
                        <img
                          :if={occupant.ship_type_id}
                          src={EveImages.type_render(occupant.ship_type_id, 64)}
                          alt=""
                          class="size-7 shrink-0 rounded object-cover"
                          onerror={ship_fallback(occupant.ship_type_id)}
                        />
                        <.icon
                          :if={is_nil(occupant.ship_type_id)}
                          name="hero-cube"
                          class="size-7 shrink-0 rounded bg-base-200 p-1 opacity-50"
                        />
                        <img
                          src={EveImages.character_portrait(occupant.eve_id, 64)}
                          alt=""
                          class="size-7 shrink-0 rounded border border-primary"
                          onerror={
                            "this.onerror=null;this.src='#{EveImages.unknown_character_portrait(64)}'"
                          }
                        />
                        <span class="min-w-0 truncate text-xs leading-tight">
                          <span class="font-semibold">{occupant.character_name}</span><span :if={
                            ship_label(occupant)
                          }>{" - " <> ship_label(occupant)}</span>
                        </span>
                      </div>
                    </div>
                  </foreignObject>
                </g>
                <g
                  :if={occupied_count(@occupants, system.id) > 1}
                  transform={"translate(#{@node_w - 2}, 12)"}
                >
                  <circle r="8" class="fill-primary" />
                  <text
                    y="3.5"
                    text-anchor="middle"
                    class="fill-primary-content text-[10px] font-bold"
                  >
                    {occupied_count(@occupants, system.id)}
                  </text>
                </g>
                <g transform={
                    "translate(0, #{node_text_offset(node_footer(@connections, @wh_sigs, system.id), @node_h)})"
                  }>
                  <text
                    x={@node_w / 2}
                    y="18"
                    text-anchor="middle"
                    style={"--class-ink: #{node_color(system)}"}
                    class="class-ink-fill text-base font-semibold tracking-wide"
                  >
                    {node_class(system)}
                  </text>
                  <text
                    x={@node_w / 2}
                    y="41"
                    text-anchor="middle"
                    class="fill-base-content text-lg font-bold cursor-pointer hover:underline"
                    phx-click={unless system.unknown, do: "open-system"}
                    phx-value-id={system.id}
                    phx-target={@myself}
                  >
                    {node_label(system)}
                  </text>
                  <text
                    x={@node_w / 2}
                    y="61"
                    text-anchor="middle"
                    class="fill-base-content/60 text-sm"
                  >
                    {node_footer(@connections, @wh_sigs, system.id)}
                  </text>
                </g>
                <g :if={activity = node_activity(@stats, system.id)}>
                  <circle
                    :if={activity.jumps > 0}
                    cx={node_dot_x(@node_w, @node_radius)}
                    cy={@node_h}
                    r="4"
                    class="fill-info"
                  >
                    <title>{"#{activity.jumps} jumps"}</title>
                  </circle>
                  <circle
                    :if={activity.kills > 0}
                    cx={node_dot_x(@node_w, @node_radius) - 14}
                    cy={@node_h}
                    r="4"
                    class="fill-error"
                  >
                    <title>{"#{activity.kills} kills"}</title>
                  </circle>
                </g>
                <g
                  :for={{label, tip, x, y, color, text_color} <- node_badges(system, @node_radius)}
                  :if={Map.get(assigns, :show_node_badges, true)}
                  transform={"translate(#{x}, #{y})"}
                  style={"--badge-bg: #{color}; --badge-ink: #{text_color}"}
                >
                  <rect
                    width={badge_width(label)}
                    height="16"
                    rx="4"
                    stroke-width="0.5"
                    class="badge-swatch stroke-base-content/30"
                  />
                  <text
                    x={badge_width(label) / 2}
                    y="12"
                    text-anchor="middle"
                    class="badge-swatch-ink text-[10px] font-semibold"
                  >
                    {label}<title>{tip}</title>
                  </text>
                </g>
              </g>
            </g>
          </svg>
        </div>
      </div>
    </div>
    """
  end

  defp wormhole_sigs(_data, nil), do: []

  defp wormhole_sigs(data, map_id), do: Data.list_wormhole_signatures(data, map_id)

  defp selected_name(_systems, nil), do: nil

  defp selected_name(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{name: name} -> name
      nil -> nil
    end
  end

  defp edge_class(%{time_status: "critical"}), do: "stroke-error"
  defp edge_class(%{time_status: "<1h"}), do: "stroke-error"
  defp edge_class(%{mass_status: "critical"}), do: "stroke-warning"
  defp edge_class(_), do: "stroke-base-content/60"

  defp edge_dash(%{time_status: "critical"}), do: "4"
  defp edge_dash(%{time_status: "<1h"}), do: "2 2"
  defp edge_dash(_), do: nil

  defp edge_path(from, to, angled?) do
    {node_w, node_h} = Mapping.node_size()
    x1 = from.x + node_w / 2
    y1 = from.y + node_h / 2
    x2 = to.x + node_w / 2
    y2 = to.y + node_h / 2

    if x1 == x2 and y1 == y2 do
      "M #{x1} #{y1} C #{x1 - 40} #{y1 - 50}, #{x1 + 40} #{y1 - 50}, #{x1} #{y1}"
    else
      if angled? do
        "M #{x1} #{y1} L #{x2} #{y2}"
      else
        {tx, ty, bx, by} = if y1 <= y2, do: {x1, y1, x2, y2}, else: {x2, y2, x1, y1}

        if abs(by - ty) >= abs(bx - tx) do
          "M #{tx} #{ty} V #{(ty + by) / 2} H #{bx} V #{by}"
        else
          "M #{tx} #{ty} H #{(tx + bx) / 2} V #{by} H #{bx}"
        end
      end
    end
  end

  defp row_groups(systems) do
    {_node_w, node_h} = Mapping.node_size()
    systems |> Enum.group_by(&(&1.y + node_h / 2)) |> Enum.sort_by(&elem(&1, 0))
  end

  defp row_levels(systems) do
    systems
    |> row_groups()
    |> Enum.with_index(fn {cy, _members}, level -> {cy, level} end)
  end

  defp node_class(system), do: Tripwire.Systems.display_class(system)

  defp node_label(%{unknown: true}), do: ""
  defp node_label(system), do: system.alias || system.name

  defp node_color(system), do: Tripwire.Systems.color(system)

  defp visible_connections(assigns) do
    connections = Map.get(assigns, :connections, [])
    ids = Elixir.MapSet.new(Map.get(assigns, :systems, []), & &1.id)

    Enum.filter(connections, fn {_conn, from, to} ->
      Elixir.MapSet.member?(ids, from.id) and Elixir.MapSet.member?(ids, to.id)
    end)
  end

  defp loop_hint_ids(connections, cycle) do
    connections
    |> Enum.filter(fn {conn, _from, _to} -> Elixir.MapSet.member?(cycle, conn.id) end)
    |> Enum.flat_map(fn {_conn, from, to} -> [from.id, to.id] end)
    |> Elixir.MapSet.new()
  end

  defp node_badges(system, radius) do
    {node_w, node_h} = Mapping.node_size()
    inset = node_badge_inset(radius)

    system
    |> Tripwire.Systems.system_statics()
    |> Enum.map(&static_badge/1)
    |> Enum.map_reduce({inset, 0}, fn {label, tip, width, color, text_color}, {x, row} ->
      {x, row} =
        if x > inset and x + width > node_w - inset, do: {inset, row + 1}, else: {x, row}

      y = node_h - 8 + row * 20
      {{label, tip, x, y, color, text_color}, {x + width + 4, row}}
    end)
    |> elem(0)
  end

  defp static_badge(code) do
    code = code |> to_string() |> String.upcase()

    case Wormholes.leads_to(code) do
      [class] ->
        {class, "Static #{code} to #{class}", badge_width(class),
         Tripwire.Systems.badge_color(class), Tripwire.Systems.badge_text_color(class)}

      [_ | _] = classes ->
        label = Enum.join(classes, "/")

        {label, "Static #{code} to #{label}", badge_width(label),
         Tripwire.Systems.badge_color(nil), "#ffffff"}

      [] ->
        {code, "Static wormhole: #{code}", badge_width(code), Tripwire.Systems.badge_color(code),
         Tripwire.Systems.badge_text_color(code)}
    end
  end

  defp badge_width(label), do: String.length(label) * 6 + 14

  defp node_effect(system), do: Tripwire.Systems.display_effect(system)

  defp effect_icon("Black Hole"),
    do:
      ~s|<path d="M512 1024q-104 0-199-40.5t-163.5-109-109-163.5-40.5-199 40.5-199 109-163.5 163.5-109 199-40.5 199 40.5 163.5 109 109 163.5 40.5 199-40.5 199-109 163.5-163.5 109-199 40.5zM299 906q99 54 213 54 122 0 225-61t162-163q-48 46-115 71t-144 25q-150 0-235-85t-85-235q0-68 45-122-81 39-127 111.5t-46 170.5q0 59 28 122.5t79 111.5zM512 640q53 0 90.5-37.5t37.5-90.5-37.5-90.5-90.5-37.5-90.5 37.5-37.5 90.5 37.5 90.5 90.5 37.5zM125 288q48-46 115-71t144-25q150 0 235 85t85 235q0 68-45 122 81-39 127-111.5t46-170.5q0-59-28-122.5t-79-111.5q-99-54-213-54-122 0-225 61t-162 163z"/>|

  defp effect_icon("Cataclysmic Variable"),
    do:
      ~s|<path d="M259.544 511.998c0-65.416 53.030-118.446 118.446-118.446s118.446 53.030 118.446 118.446c0 65.416-53.030 118.446-118.446 118.446s-118.446-53.030-118.446-118.446zM512.004 0c-282.774 0-512.004 229.232-512.004 512s229.226 512 512.004 512c282.764 0 511.996-229.23 511.996-512 0-282.768-229.23-512-511.996-512zM379.396 959.282c-153.956-89.574-257.468-256.324-257.468-447.282s103.512-357.708 257.462-447.282c154.010 89.562 257.59 256.288 257.59 447.282 0 190.988-103.58 357.718-257.584 447.282z"/>|

  defp effect_icon("Magnetar"),
    do:
      ~s|<path d="M384 512c0 70.692 57.308 128 128 128s128-57.308 128-128c0-70.692-57.308-128-128-128s-128 57.308-128 128zM664.348 230.526c99.852 54.158 167.652 159.898 167.652 281.474s-67.8 227.316-167.652 281.474c44.066-70.126 71.652-170.27 71.652-281.474s-27.586-211.348-71.652-281.474zM288 512c0 111.204 27.584 211.348 71.652 281.474-99.852-54.16-167.652-159.898-167.652-281.474s67.8-227.314 167.652-281.474c-44.068 70.126-71.652 170.27-71.652 281.474zM96 512c0 171.9 54.404 326.184 140.652 431.722-142.302-90.948-236.652-250.314-236.652-431.722s94.35-340.774 236.652-431.722c-86.248 105.538-140.652 259.822-140.652 431.722zM787.352 80.28c142.298 90.946 236.648 250.312 236.648 431.72s-94.35 340.774-236.648 431.72c86.244-105.536 140.648-259.82 140.648-431.72s-54.404-326.184-140.648-431.72z"/>|

  defp effect_icon("Pulsar"),
    do:
      ~s|<path d="M980 324q-41 20-109.5 41.5t-166 49.5-144.5 42q27 10 95 32t104.5 34.5 83.5 31.5 76 35q22 13 32.5 38t8.5 49.5-13 42.5q-18 29-58 42t-79-6q-19-11-41-28.5t-38.5-31.5-45-40.5-41.5-39-47-46-42-41.5q-1 11-2.5 50t-2 54.5-2.5 49.5-4 52.5-4.5 44.5-6.5 46.5-8 37.5q-11 40-52.5 68t-76 28-59.5-28-12-68q10-33 32.5-83t40-85 54-106.5 47.5-93.5q-29 20-95.5 69.5t-105 77.5-89.5 61.5-87 52.5q-45 20-79 6.5t-42-42.5q-6-29 15-70t60-61q26-12 57-24.5t76.5-27 70.5-22.5 86.5-26.5 76.5-23.5q-13-3-48-12.5t-51-14-45-12.5-46-13.5-38.5-12.5-36.5-13.5-27-12.5q-17-10-21-27.5t2.5-34 19.5-27.5q20-18 55.5-26.5t64.5 3.5q21 11 53.5 33t53.5 37.5 70.5 53.5 63.5 49q-1-106-1-276 0-31 23-54.5t48.5-32.5 46.5-9q28 0 53.5 17t20.5 41q-6 30-24 73t-57 121-50 102q31-21 112.5-78t132.5-90 88-50q34-13 66-4t45 29q6 14 7 31.5t-11 37-33 30.5z"/>|

  defp effect_icon("Red Giant"),
    do:
      ~s|<path d="M512 0q139 0 257 68.5t186.5 186.5 68.5 257-68.5 257-186.5 186.5-257 68.5-257-68.5-186.5-186.5-68.5-257 68.5-257 186.5-186.5 257-68.5z"/>|

  defp effect_icon("Wolf Rayet"),
    do: ~s|<path d="M512 0l-320 512 320 512 320-512z"/>|

  defp effect_icon("Wolf-Rayet Star"), do: effect_icon("Wolf Rayet")

  defp effect_icon(_), do: ""

  defp node_footer(connections, wh_sigs, system_id) do
    case Enum.find(connections, fn {_conn, from, to} ->
           from.id == system_id or to.id == system_id
         end) do
      nil ->
        ""

      {conn, _, _} ->
        code = conn.hole_type |> to_string() |> String.upcase()

        case Enum.find(
               wh_sigs,
               &(&1.map_system_id == system_id and SigParser.wormhole_code(&1.type_name) == code)
             ) do
          nil -> ""
          sig -> sig.sig_id
        end
    end
  end

  defp edge_stroke(conn, from, to, line_weight) do
    factor = conn |> jump_for(from, to) |> mass_factor()
    max(1, round(line_weight * factor))
  end

  defp jump_for(%{hole_type: code}, from, to) when is_binary(code) and code != "" do
    Wormholes.jump(code) || likely_jump(from, to)
  end

  defp jump_for(_conn, from, to), do: likely_jump(from, to)

  defp likely_jump(from, to) do
    class1 = Tripwire.Systems.display_class(from)
    class2 = Tripwire.Systems.display_class(to)

    Wormholes.dummy(Wormholes.likely_wormhole(class1, class2)) |> Map.get("jump")
  end

  defp mass_factor(nil), do: 1.0
  defp mass_factor(jump) when jump <= 5_000_000, do: 0.6
  defp mass_factor(jump) when jump <= 62_000_000, do: 1.0
  defp mass_factor(jump) when jump <= 375_000_000, do: 1.3
  defp mass_factor(_jump), do: 1.7

  defp edge_title(conn, from, to) do
    case conn.hole_type do
      code when is_binary(code) and code != "" -> Wormholes.render(code)
      _ -> likely_title(from, to)
    end
  end

  defp likely_title(from, to) do
    class1 = Tripwire.Systems.display_class(from)
    class2 = Tripwire.Systems.display_class(to)
    size = Wormholes.likely_wormhole(class1, class2)

    "Likely #{size} wormhole (#{class1 || "?"} ➔ #{class2 || "?"})"
  end

  defp map_bottom(assigns) do
    assigns
    |> Map.get(:systems, [])
    |> Enum.reduce(0, &max(&1.y, &2))
  end

  defp flips_above?(system, height, map_bottom) do
    passes_bottom? = system.y + height + 8 > map_bottom
    room_above? = system.y >= height + 22

    passes_bottom? and room_above?
  end

  defp system_occupants(occupants, system_id) do
    occupants
    |> Enum.filter(&(&1.system_id == system_id))
    |> Enum.sort_by(& &1.character_name)
  end

  defp occupant_badge([occupant]), do: EveImages.character_portrait(occupant.eve_id, 64)
  defp occupant_badge(_members), do: EveImages.unknown_character_portrait(64)

  defp occupied_count(occupants, system_id) do
    length(system_occupants(occupants, system_id))
  end

  defp occupant_tip(occupants, system, assigns) do
    case system_occupants(occupants, system.id) do
      [] ->
        nil

      members ->
        node_w = Map.get(assigns, :node_w)
        node_h = Map.get(assigns, :node_h)
        rows = length(members)
        width = tip_width(members)

        height =
          rows * @occupant_row_h + (rows - 1) * @occupant_row_gap + 2 * @occupant_tip_pad

        x =
          if system.x + width <= @map_width,
            do: 14 - node_w,
            else: 14 - width

        y =
          if flips_above?(system, height, Map.get(assigns, :map_bottom, 0.0)),
            do: -(height + 22),
            else: node_h + 8

        %{
          members: members,
          x: x,
          y: y,
          width: width,
          height: height,
          badge_x: node_w - 14 - @occupant_badge_inset
        }
    end
  end

  defp tip_width(members) do
    longest = members |> Enum.map(&String.length(tip_row_label(&1))) |> Enum.max()

    (longest * @occupant_char_w + @occupant_tip_chrome)
    |> max(@occupant_tip_w)
    |> min(@occupant_tip_max_w)
    |> ceil()
  end

  defp tip_row_label(occupant) do
    case ship_label(occupant) do
      nil -> occupant.character_name
      ship -> "#{occupant.character_name} - #{ship}"
    end
  end

  defp ship_fallback(type_id) when is_integer(type_id) and type_id > 0 do
    "this.onerror=null;this.src='#{EveImages.type_icon(type_id, 64)}'"
  end

  defp ship_fallback(_type_id), do: nil

  defp ship_label(occupant) do
    present(occupant[:ship_type_name]) || custom_ship_name(occupant[:ship_name])
  end

  defp custom_ship_name(name) do
    case present(name) do
      "/" -> nil
      name -> name
    end
  end

  defp node_activity(stats, system_id) do
    case Map.get(stats, system_id) do
      nil ->
        nil

      stat ->
        jumps = stat.jumps || 0
        kills = stat.kills || 0

        if jumps > 0 or kills > 0 do
          %{jumps: jumps, kills: kills}
        else
          nil
        end
    end
  end
end
