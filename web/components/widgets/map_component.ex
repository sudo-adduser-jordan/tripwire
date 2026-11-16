defmodule TripwireWeb.MapComponent do
  use Phoenix.Component

  attr :systems, :list, required: true
  attr :connections, :list, default: []
  attr :selected_system_id, :integer, default: nil
  attr :map_name, :string, default: "Map"

  @view_box {0, 0, 1000, 700}

  def map(assigns) do
    assigns = assign(assigns, :view_box, @view_box |> Tuple.to_list() |> Enum.join(" "))

    ~H"""
    <div
      id="map"
      class="grid-stack-item h-full"
      gs-w="12"
      gs-h="6"
      gs-x="0"
      gs-y="12"
      tabindex="0"
    >
      <div class="grid-stack-item-content bg-base-100/50 overflow-hidden flex flex-col">
        <ul class="list rounded-box shadow-md shrink-0">
          <li class="list-row h-fit p-1 flex items-center gap-1">
            <p class="text-lg font-semibold px-1">Map</p>
            <span class="text-xs opacity-60">{@map_name}</span>
            <span class="ml-auto text-xs opacity-60">
              {length(@systems)} systems · {length(@connections)} links
            </span>
            <span :if={selected_name(@systems, @selected_system_id)} class="badge badge-primary badge-sm">
              {selected_name(@systems, @selected_system_id)}
            </span>
          </li>
        </ul>
        <div class="flex-1 min-h-0">
          <svg
            id="chain-map"
            viewBox={@view_box}
            class="block size-full select-none touch-none"
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
                />
                <text
                  x="40"
                  y="28"
                  text-anchor="middle"
                  textLength="72"
                  lengthAdjust="spacingAndGlyphs"
                  class="fill-base-content text-xs"
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
end
