defmodule TripwireWeb.MapComponent do
  use Phoenix.Component

  attr :systems, :list, required: true
  attr :connections, :list, default: []
  attr :selected_system_id, :integer, default: nil

  @view_box {0, 0, 1000, 700}

  def map(assigns) do
    assigns = assign(assigns, :view_box, @view_box |> Tuple.to_list() |> Enum.join(" "))

    ~H"""
    <div
      id="map"
      class="grid-stack-item h-full"
      gs-w="6"
      gs-h="6"
      gs-x="6"
      gs-y="0"
      tabindex="0"
    >
      <div class="grid-stack-item-content bg-base-100/50 overflow-hidden">
        <svg
          id="chain-map"
          viewBox={@view_box}
          class="size-full select-none touch-none"
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
              class={edge_class(conn)}
            />
            <text
              :for={{conn, from, to} <- @connections}
              x={(from.x + to.x) / 2 + 40}
              y={(from.y + to.y) / 2 + 22}
              class="fill-base-content/60 text-[10px] text-center"
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
              <text x="40" y="28" text-anchor="middle" class="fill-base-content text-xs">
                {system.name}
              </text>
            </g>
          </g>
        </svg>
      </div>
    </div>
    """
  end

  defp edge_class(%{time_status: "eol"}), do: "stroke-error stroke-1 stroke-dasharray-4"
  defp edge_class(%{mass_status: "critical"}), do: "stroke-warning stroke-1"
  defp edge_class(_), do: "stroke-base-content/60 stroke-1"
end
