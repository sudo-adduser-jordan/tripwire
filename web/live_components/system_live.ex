defmodule TripwireWeb.LiveComponents.SystemLive do
  use TripwireWeb, :live_component

  alias Tripwire.Mapping

  def update(assigns, socket) do
    systems =
      case Map.get(assigns, :systems) do
        nil -> Mapping.list_systems(assigns.map_id)
        systems -> systems
      end

    connections =
      Map.get_lazy(assigns, :connections, fn ->
        Mapping.list_connections_with_endpoints(assigns.map_id)
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

  def handle_event("toggle-favorite", _params, socket) do
    send(self(), :toggle_favorite)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id="system-container"
      gs-w="6"
      gs-h="6"
      gs-x="0"
      gs-y="0"
      class="grid-stack-item"
      tabindex="0"
    >
      <div class="grid-stack-item-content bg-base-100/50 flex flex-col overflow-hidden">
        <div class="flex min-h-0 size-full flex-col">
          <ul class="list rounded-box shadow-md shrink-0">
            <li class="flex items-center gap-1 p-1">
              <button
                id="system-copy"
                class="group flex min-w-0 cursor-pointer items-center gap-1 rounded px-1 hover:bg-base-200"
                title={"Copy #{selected_name(@systems, @selected_system_id) || "Jita"}"}
                phx-hook="CopyText"
                data-copy={selected_name(@systems, @selected_system_id) || "Jita"}
              >
                <span class="truncate text-lg font-semibold">
                  {selected_name(@systems, @selected_system_id) || "Jita"}
                </span>
                <.icon
                  name="hero-clipboard"
                  class="copy-icon size-4 shrink-0 opacity-0 transition-opacity group-hover:opacity-60"
                />
                <.icon name="hero-check" class="copied-icon hidden size-4 shrink-0 text-success" />
              </button>
              <button
                id="system-favorite"
                class="btn btn-ghost btn-xs p-1"
                title="Add/remove selected system from favorites"
                phx-click="toggle-favorite"
                phx-target={@myself}
              >
                <.icon
                  name={
                    if selected_favorite?(@systems, @selected_system_id),
                      do: "hero-star-solid",
                      else: "hero-star"
                  }
                  class={
                    if selected_favorite?(@systems, @selected_system_id),
                      do: "size-5 text-amber-400",
                      else: "size-5 opacity-60"
                  }
                />
              </button>
              <span class="ml-auto text-xs opacity-60">
                {length(@systems)} systems
              </span>
            </li>
          </ul>
          <div class="flex flex-row flex-wrap gap-1 p-2">
            <button
              :for={sys <- visible_systems(@systems, @connections, @selected_system_id)}
              class={"btn btn-xs " <> (if sys.id == @selected_system_id, do: "btn-primary", else: "btn-ghost")}
              phx-click="select-system"
              phx-value-id={sys.id}
              phx-target={@myself}
            >
              {sys.name}
            </button>
            <span :if={@systems == []} class="p-1 text-sm opacity-50">No systems on map yet</span>
          </div>
          <div
            id="system-chart"
            phx-hook="ChartMount"
            data-chart-fn="initSystemChart"
            phx-update="ignore"
            class="min-h-0 w-full flex-1"
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp selected_favorite?(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{favorite: true} -> true
      _ -> false
    end
  end

  defp visible_systems(systems, _connections, nil), do: systems

  defp visible_systems(systems, connections, selected_id) do
    if Enum.any?(systems, &(&1.id == selected_id)) do
      neighbor_ids =
        for {_conn, from, to} <- connections,
            from.id == selected_id or to.id == selected_id,
            id <- [from.id, to.id],
            id != selected_id,
            into: MapSet.new() do
          id
        end

      Enum.filter(systems, &(&1.id == selected_id or MapSet.member?(neighbor_ids, &1.id)))
    else
      systems
    end
  end

  defp selected_name(_systems, nil), do: nil

  defp selected_name(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{name: name} -> name
      nil -> nil
    end
  end
end
