defmodule TripwireWeb.LiveComponents.MapLive do
  use TripwireWeb, :live_component

  alias Tripwire.Mapping

  def update(assigns, socket) do
    map_id = Map.get(assigns, :map_id)
    systems = Map.get_lazy(assigns, :systems, fn -> Mapping.list_systems(map_id) end)

    connections =
      Map.get_lazy(assigns, :connections, fn ->
        Mapping.list_connections_with_endpoints(map_id)
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:systems, systems)
     |> assign(:connections, connections)}
  end

  def handle_event("select-system", %{"id" => id}, socket) do
    send(self(), {:select_system, String.to_integer(id)})
    {:noreply, socket}
  end

  def handle_event("move-system", %{"id" => id, "x" => x, "y" => y}, socket) do
    system = Mapping.get_system!(String.to_integer(id))
    system = if system.locked, do: system, else: system

    case Mapping.update_system_position(system, coord(x), coord(y)) do
      {:ok, _} ->
        send(self(), {:systems_updated, socket.assigns.map_id})
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
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

  def handle_event("toggle-lock", _params, socket) do
    send(self(), {:toggle_lock})
    {:noreply, socket}
  end

  def handle_event("map-layout", %{"layout" => layout}, socket) do
    send(self(), {:map_layout, layout})
    {:noreply, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :view_box, "0 0 1000 700")

    ~H"""
    <div id="map" class="grid-stack-item" gs-w="12" gs-h="6" gs-x="0" gs-y="12" tabindex="0">
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
            >
              <.icon name="hero-plus" class="size-4" />
            </button>
            <span class="opacity-30">|</span>
            <button
              id="show-viewing"
              class="btn btn-ghost btn-xs"
              title="Add viewing system to chain"
              phx-click="add-viewing"
              phx-target={@myself}
            >
              <.icon name="hero-eye" class="size-4" />
            </button>
            <button
              id="show-favorite"
              class="btn btn-ghost btn-xs"
              title="Lock/unlock selected system"
              phx-click="toggle-lock"
              phx-target={@myself}
            >
              <.icon name="hero-star" class="size-4" />
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
              </div>
            </details>
            <span class="text-xs tabular-nums opacity-60">
              {length(@systems)} systems
            </span>
            <button
              id="chain-zoom-reset"
              class="btn btn-ghost btn-xs"
              title="Reset Zoom"
              phx-click="map-layout"
              phx-value-layout="default"
              phx-target={@myself}
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
        <div class="min-h-0 w-full flex-1">
          <svg
            id="chain-map"
            viewBox={@view_box}
            preserveAspectRatio="xMidYMid meet"
            class="block size-full touch-pan-y select-none"
            phx-hook="MapDrag"
            data-selected={@selected_system_id}
          >
            <g id="map-edges">
              <line
                :for={{conn, from, to} <- @connections}
                id={"connection-#{conn.id}"}
                x1={from.x + 40}
                y1={from.y + 25}
                x2={to.x + 40}
                y2={to.y + 25}
                stroke-dasharray={if conn.time_status == "eol", do: "4"}
                class={edge_class(conn)}
              />
              <text
                :for={{conn, from, to} <- @connections}
                x={(from.x + to.x) / 2 + 40}
                y={(from.y + to.y) / 2 + 22}
                text-anchor="middle"
                class="fill-base-content/60 text-[10px]"
              >
                {conn.hole_type || "?"}
              </text>
            </g>
            <g id="map-nodes">
              <g
                :for={system <- @systems}
                id={"node-#{system.id}"}
                transform={"translate(#{system.x}, #{system.y})"}
                class="cursor-pointer"
                data-system-id={system.id}
                phx-click="select-system"
                phx-value-id={system.id}
                phx-target={@myself}
              >
                <rect
                  width="80"
                  height="50"
                  rx="8"
                  class={
                    if system.id == @selected_system_id,
                      do: "fill-primary/30 stroke-primary",
                      else: "fill-base-200/75 stroke-base-content/40"
                  }
                  stroke-width="2"
                  stroke-dasharray={if system.locked, do: "4"}
                />
                <text
                  x="40"
                  y={if system.alias, do: "22", else: "28"}
                  text-anchor="middle"
                  textLength="72"
                  lengthAdjust="spacingAndGlyphs"
                  class="fill-base-content text-xs"
                >
                  {system.alias || system.name}
                </text>
                <text
                  :if={system.alias}
                  x="40"
                  y="36"
                  text-anchor="middle"
                  textLength="72"
                  lengthAdjust="spacingAndGlyphs"
                  class="fill-base-content/60 text-[10px]"
                >
                  {system.name}
                </text>
              </g>
            </g>
          </svg>
        </div>
      </div>
    </div>
    """
  end

  defp selected_name(_systems, nil), do: nil

  defp selected_name(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{name: name} -> name
      nil -> nil
    end
  end

  defp edge_class(%{time_status: "eol"}), do: "stroke-error stroke-1"
  defp edge_class(%{mass_status: "critical"}), do: "stroke-warning stroke-1"
  defp edge_class(_), do: "stroke-base-content/60 stroke-1"

  defp coord(value) when is_binary(value) do
    {number, ""} = Integer.parse(value)
    number * 1.0
  end

  defp coord(number) when is_number(number), do: number * 1.0
end
