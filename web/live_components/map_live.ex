defmodule TripwireWeb.LiveComponents.MapLive do
  use TripwireWeb, :live_component

  alias Tripwire.EveImages
  alias Tripwire.Mapping
  alias Tripwire.Signatures, as: SigParser
  alias Tripwire.Wormholes

  @occupant_tip_w 280
  @occupant_row_h 28
  @occupant_row_gap 4
  @occupant_tip_pad 8
  @occupant_badge_inset 6
  @map_width 1000.0

  def update(assigns, socket) do
    map_id = Map.get(assigns, :map_id)
    systems = Map.get_lazy(assigns, :systems, fn -> Mapping.list_visible_systems(map_id) end)

    connections =
      Map.get_lazy(assigns, :connections, fn ->
        Mapping.list_connections_with_endpoints(map_id)
      end)

    stats = Map.get_lazy(assigns, :stats, fn -> Mapping.list_system_stats(map_id) end)
    occupants = Map.get(assigns, :occupants, [])
    {pan_x, pan_y} = Mapping.home_center(systems, Map.get(assigns, :map))
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
     |> assign(:wh_sigs, wormhole_sigs(map_id))
     |> assign_new(:pan_x, fn -> pan_x end)
     |> assign_new(:pan_y, fn -> pan_y end)
     |> assign_new(:map_locked, fn -> false end)
     |> assign_new(:show_row_guides, fn -> false end)
     |> assign_new(:show_row_counts, fn -> false end)
     |> assign_new(:angled_lines, fn -> true end)
     |> assign_new(:show_jump_lines, fn -> true end)
     |> assign_new(:show_line_glow, fn -> true end)
     |> assign_new(:show_node_badges, fn -> true end)
     |> assign_new(:line_weight, fn -> 2 end)
     |> assign_new(:map_background, fn -> nil end)}
  end

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

  def handle_event("open-connection", %{"id" => id}, socket) do
    send(self(), {:open_connection, String.to_integer(id)})
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
    {view_w, view_h} = Mapping.view_size()

    assigns =
      assigns
      |> assign(:visible_connections, visible)
      |> assign(:view_w, view_w)
      |> assign(:view_h, view_h)
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
      <div class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden">
        <ul class="list rounded-box shadow-md shrink-0">
          <li class="flex h-fit flex-wrap items-center justify-start gap-1 p-1">
            <span id="chainTabs" class="join">
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
                class={if @map_locked, do: "size-4 text-amber-400", else: "size-4"}
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
          class="min-h-0 w-full flex-1 bg-cover bg-center bg-no-repeat"
          style={if @map_background, do: "background-image: url('#{@map_background}')"}
        >
          <svg
            id="chain-map"
            viewBox={"#{@pan_x} #{@pan_y} #{@view_w} #{@view_h}"}
            preserveAspectRatio="xMidYMid meet"
            class="block size-full touch-pan-y select-none"
            phx-hook="MapDrag"
            data-selected={@selected_system_id}
            data-locked={to_string(@map_locked)}
            data-node-w={@node_w}
            data-node-h={@node_h}
          >
            <g id="map-guides">
              <line
                :for={{cy, _} <- row_groups(@systems)}
                :if={@show_row_guides}
                x1="0"
                x2="1000"
                y1={cy}
                y2={cy}
                class="stroke-base-content/20"
                stroke-width="1"
                stroke-dasharray="2 3"
              />
              <text
                :for={{cy, count} <- row_counts(@systems)}
                :if={@show_row_counts}
                x="8"
                y={cy - 8}
                text-anchor="start"
                class="fill-base-content/60 text-[10px]"
              >
                {count}
              </text>
            </g>
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
                  x="4"
                  y="4"
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke={node_color(system)}
                  stroke-width="1.5"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  data-effect={effect}
                >
                  <title>{"System effect: " <> effect}</title>
                  {Phoenix.HTML.raw(effect_icon(effect))}
                </svg>
                <rect
                  width={@node_w}
                  height={@node_h}
                  rx="8"
                  stroke={node_stroke(system, @selected_system_id)}
                  stroke-dasharray={if MapSet.member?(@loop_hint_ids, system.id), do: "6 4"}
                  style={
                    if Map.get(assigns, :show_line_glow, true) and
                         MapSet.member?(@loop_hint_ids, system.id),
                       do: "filter: drop-shadow(0 0 6px #{node_color(system)})"
                  }
                  class={
                    if system.id == @selected_system_id,
                      do: "fill-primary/30 stroke-primary",
                      else: "fill-base-200/75"
                  }
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
                      class="space-y-1 rounded-box border border-base-content/20 bg-base-300/95 p-2 shadow-xl"
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
                <text
                  x={@node_w / 2}
                  y="20"
                  text-anchor="middle"
                  fill={node_color(system)}
                  class="text-sm font-semibold tracking-wider"
                >
                  {node_class(system)}
                </text>
                <text
                  x={@node_w / 2}
                  y="46"
                  text-anchor="middle"
                  class="fill-base-content text-base font-bold cursor-pointer hover:underline"
                  phx-click={unless system.unknown, do: "open-system"}
                  phx-value-id={system.id}
                  phx-target={@myself}
                >
                  {node_label(system)}
                </text>
                <text
                  x={@node_w / 2}
                  y="70"
                  text-anchor="middle"
                  class="fill-base-content/60 text-xs"
                >
                  {node_footer(@connections, @wh_sigs, system.id)}
                </text>
                <g :if={activity = node_activity(@stats, system.id)}>
                  <circle
                    :if={activity.jumps > 0}
                    cx={@node_w - 22}
                    cy={@node_h}
                    r="4"
                    class="fill-info"
                  >
                    <title>{"#{activity.jumps} jumps"}</title>
                  </circle>
                  <circle
                    :if={activity.kills > 0}
                    cx={@node_w - 8}
                    cy={@node_h}
                    r="4"
                    class="fill-error"
                  >
                    <title>{"#{activity.kills} kills"}</title>
                  </circle>
                </g>
                <g
                  :for={{label, tip, x, y, color, text_color} <- node_badges(system)}
                  :if={Map.get(assigns, :show_node_badges, true)}
                  transform={"translate(#{x}, #{y})"}
                >
                  <rect
                    width={badge_width(label)}
                    height="16"
                    rx="4"
                    style={"fill: #{color}"}
                    stroke-width="0.5"
                    class="stroke-base-content/30"
                  />
                  <text
                    x={badge_width(label) / 2}
                    y="12"
                    text-anchor="middle"
                    style={"fill: #{text_color}"}
                    class="text-[10px] font-semibold"
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

  defp wormhole_sigs(nil), do: []

  defp wormhole_sigs(map_id), do: Mapping.list_wormhole_signatures(map_id)

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

  defp row_counts(systems) do
    Enum.map(row_groups(systems), fn {cy, members} -> {cy, length(members)} end)
  end

  defp node_class(system), do: Tripwire.Systems.display_class(system)

  defp node_label(%{unknown: true}), do: ""
  defp node_label(system), do: system.alias || system.name

  defp node_color(system), do: Tripwire.Systems.color(system)

  defp node_stroke(system, selected_id) when system.id == selected_id, do: nil
  defp node_stroke(system, _selected_id), do: node_color(system)

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

  defp node_badges(system) do
    {node_w, node_h} = Mapping.node_size()

    system
    |> Tripwire.Systems.system_statics()
    |> Enum.map(&static_badge/1)
    |> Enum.map_reduce({4, 0}, fn {label, tip, width, color, text_color}, {x, row} ->
      {x, row} = if x > 4 and x + width > node_w - 4, do: {4, row + 1}, else: {x, row}
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
      ~s|<path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"/>|

  defp effect_icon("Cataclysmic Variable"),
    do:
      ~s|<path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"/>|

  defp effect_icon("Magnetar"),
    do:
      ~s|<path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z"/>|

  defp effect_icon("Pulsar"),
    do:
      ~s|<path stroke-linecap="round" stroke-linejoin="round" d="m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z"/>|

  defp effect_icon("Red Giant"),
    do:
      ~s|<path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"/>|

  defp effect_icon("Wolf Rayet"),
    do:
      ~s|<path stroke-linecap="round" stroke-linejoin="round" d="M15.362 5.214A8.252 8.252 0 0 1 12 21 8.25 8.25 0 0 1 6.038 7.047 8.287 8.287 0 0 0 9 9.601a8.983 8.983 0 0 1 3.361-6.867 8.21 8.21 0 0 0 3 2.48Z"/><path stroke-linecap="round" stroke-linejoin="round" d="M12 18a3.75 3.75 0 0 0 .495-7.468 5.99 5.99 0 0 0-1.925 3.547 5.975 5.975 0 0 1-2.133-1.001A3.75 3.75 0 0 0 12 18Z"/>|

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

        height =
          rows * @occupant_row_h + (rows - 1) * @occupant_row_gap + 2 * @occupant_tip_pad

        x =
          if system.x + node_w / 2 <= @map_width / 2,
            do: 14 - node_w,
            else: 14 - @occupant_tip_w

        y =
          if flips_above?(system, height, Map.get(assigns, :map_bottom, 0.0)),
            do: -(height + 22),
            else: node_h + 8

        %{
          members: members,
          x: x,
          y: y,
          width: @occupant_tip_w,
          height: height,
          badge_x: node_w - 14 - @occupant_badge_inset
        }
    end
  end

  defp ship_fallback(type_id) when is_integer(type_id) and type_id > 0 do
    "this.onerror=null;this.src='#{EveImages.type_icon(type_id, 64)}'"
  end

  defp ship_fallback(_type_id), do: nil

  defp ship_label(occupant) do
    present_name(occupant[:ship_type_name]) || custom_ship_name(occupant[:ship_name])
  end

  defp custom_ship_name(name) do
    case present_name(name) do
      "/" -> nil
      name -> name
    end
  end

  defp present_name(name) when is_binary(name) do
    case String.trim(name) do
      "" -> nil
      name -> name
    end
  end

  defp present_name(_name), do: nil

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
