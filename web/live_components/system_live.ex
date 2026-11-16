defmodule TripwireWeb.LiveComponents.SystemLive do
  use TripwireWeb, :live_component

  alias Tripwire.Mapping

  def update(assigns, socket) do
    systems =
      case Map.get(assigns, :systems) do
        nil -> Mapping.list_systems(assigns.map_id)
        systems -> systems
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:systems, systems)}
  end

  def handle_event("select-system", %{"id" => id}, socket) do
    send(self(), {:select_system, String.to_integer(id)})
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
            <li class="list-row h-fit items-center gap-1 p-1">
              <p class="px-1 text-lg font-semibold">
                {selected_name(@systems, @selected_system_id) || "Jita"}
              </p>
              <button
                id="system-copy"
                class="btn btn-ghost btn-xs p-1"
                title={"Copy #{selected_name(@systems, @selected_system_id) || "Jita"}"}
                phx-hook="CopyText"
                data-copy={selected_name(@systems, @selected_system_id) || "Jita"}
              >
                <svg
                  class="size-5 opacity-60"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.666 3.888A2.25 2.25 0 0 0 13.5 2.25h-3c-1.03 0-1.9.693-2.166 1.638m7.332 0c.055.194.084.4.084.612v0a.75.75 0 0 1-.75.75H9a.75.75 0 0 1-.75-.75v0c0-.212.03-.418.084-.612m7.332 0c.646.049 1.288.11 1.927.184 1.1.128 1.907 1.077 1.907 2.185V19.5a2.25 2.25 0 0 1-2.25 2.25H6.75A2.25 2.25 0 0 1 4.5 19.5V6.257c0-1.108.806-2.057 1.907-2.185a48.208 48.208 0 0 1 1.927-.184"
                  />
                </svg>
              </button>
              <.icon name="hero-star" class="size-5 opacity-60" />
              <span class="ml-auto text-xs opacity-60">
                {length(@systems)} systems
              </span>
            </li>
          </ul>
          <div class="flex flex-row flex-wrap gap-1 p-2">
            <button
              :for={sys <- @systems}
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

  defp selected_name(_systems, nil), do: nil

  defp selected_name(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{name: name} -> name
      nil -> nil
    end
  end
end
