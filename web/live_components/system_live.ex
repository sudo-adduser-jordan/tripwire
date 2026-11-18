defmodule TripwireWeb.LiveComponents.SystemLive do
  use TripwireWeb, :live_component

  alias Tripwire.EveImages
  alias Tripwire.Mapping
  alias Tripwire.Systems

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
     |> assign(:connections, connections)
     |> assign_new(:system_info, fn -> nil end)
     |> assign_new(:chart_range, fn -> "24h" end)
     |> assign_new(:chart_hidden, fn -> MapSet.new() end)
     |> assign_new(:chart_data, fn ->
       %{labels: [], jumps: [], ship_kills: [], pod_kills: [], npc_kills: []}
     end)}
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
              <span class="ml-auto"></span>
              <details id="favorites-list" class="dropdown dropdown-end">
                <summary
                  class="btn btn-ghost btn-xs"
                  title="Favorited systems"
                >
                  ...
                </summary>
                <div class="dropdown-content z-10 max-h-64 w-48 overflow-y-auto rounded bg-base-200 p-1 text-xs shadow">
                  <p :if={favorites(@systems) == []} class="px-2 py-1 opacity-60">
                    No favorites yet
                  </p>
                  <button
                    :for={fav <- favorites(@systems)}
                    phx-click="select-system"
                    phx-value-id={fav.id}
                    title={"Select #{fav.name}"}
                    class="flex w-full items-center gap-2 rounded px-2 py-1 text-left hover:bg-base-300"
                  >
                    <span
                      class="inline-block size-2.5 shrink-0 rounded-full"
                      style={"background-color: #{Systems.color(fav)}"}
                    >
                    </span>
                    <span class="truncate font-mono">{fav.alias || fav.name}</span>
                  </button>
                </div>
              </details>
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
            </li>
            <li :if={selected_system(@systems, @selected_system_id)} class="px-2 pb-1">
              <.system_info
                system={selected_system(@systems, @selected_system_id)}
                system_info={@system_info}
              />
            </li>
          </ul>
          <div
            :if={selected_system(@systems, @selected_system_id)}
            class="flex flex-wrap items-center gap-x-3 gap-y-1 px-2 pb-1 text-xs"
          >
            <a
              :for={
                link <- Systems.external_links(selected_system(@systems, @selected_system_id))
              }
              href={link.url}
              target="_blank"
              rel="noopener noreferrer"
              class="link link-hover opacity-70 hover:opacity-100"
            >
              {link.label}
            </a>
          </div>
          <.chart_range_buttons
            chart_range={@chart_range}
            systems={@systems}
            connections={@connections}
            selected_system_id={@selected_system_id}
          />
          <div
            id="system-chart"
            phx-hook="ChartMount"
            data-chart-fn="initSystemChart"
            data-labels={Jason.encode!(@chart_data[:labels] || [])}
            data-jumps={Jason.encode!(@chart_data[:jumps] || [])}
            data-ship-kills={Jason.encode!(@chart_data[:ship_kills] || [])}
            data-pod-kills={Jason.encode!(@chart_data[:pod_kills] || [])}
            data-npc-kills={Jason.encode!(@chart_data[:npc_kills] || [])}
            phx-update="ignore"
            class="min-h-0 w-full flex-1"
          >
          </div>
          <.chart_legend chart_hidden={@chart_hidden} />
        </div>
      </div>
    </div>
    """
  end

  defp range_label("week"), do: "Week"
  defp range_label("48h"), do: "48H"
  defp range_label(_), do: "24H"

  defp range_title("week"), do: "Show last week"
  defp range_title("48h"), do: "Show last 48 hours"
  defp range_title(_), do: "Show last 24 hours"

  attr :chart_range, :string, default: "24h"
  attr :systems, :list, default: []
  attr :connections, :list, default: []
  attr :selected_system_id, :any, default: nil

  defp chart_range_buttons(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-between gap-1 px-2 pt-1">
      <div class="flex min-w-0 flex-row flex-wrap items-center gap-1">
        <button
          :for={sys <- visible_systems(@systems, @connections, @selected_system_id)}
          class={
            "btn btn-xs " <>
              (if sys.id == @selected_system_id, do: "btn-primary", else: "btn-ghost")
          }
          title={"Select system #{sys.name}"}
          phx-click="select-system"
          phx-value-id={sys.id}
        >
          {sys.name}
        </button>
        <span :if={@systems == []} class="p-1 text-sm opacity-50">No systems on map yet</span>
      </div>
      <div class="flex shrink-0 items-center gap-1" role="group" aria-label="Chart time range">
        <button
          :for={range <- ["week", "48h", "24h"]}
          phx-click="chart-range"
          phx-value-range={range}
          title={range_title(range)}
          class={
            "btn btn-xs " <>
              (if @chart_range == range, do: "btn-primary", else: "btn-ghost")
          }
        >
          {range_label(range)}
        </button>
      </div>
    </div>
    """
  end

  attr :chart_hidden, :any, default: nil

  defp chart_legend(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 px-2 pt-1 pb-1 text-[11px]">
      <.legend_toggle
        series="jumps"
        label="Jumps"
        color="#91cc75"
        hidden={hidden?(@chart_hidden, "jumps")}
      />
      <.legend_toggle
        series="pod_kills"
        label="Pod Kills"
        color="#fac858"
        hidden={hidden?(@chart_hidden, "pod_kills")}
      />
      <.legend_toggle
        series="ship_kills"
        label="Ship Kills"
        color="#ee6666"
        hidden={hidden?(@chart_hidden, "ship_kills")}
      />
      <.legend_toggle
        series="npc_kills"
        label="NPC Kills"
        color="#5470c6"
        hidden={hidden?(@chart_hidden, "npc_kills")}
      />
    </div>
    """
  end

  attr :series, :string, required: true
  attr :label, :string, required: true
  attr :color, :string, required: true
  attr :hidden, :boolean, default: false

  defp legend_toggle(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="chart-toggle-series"
      phx-value-series={@series}
      aria-pressed={to_string(!@hidden)}
      title={"Toggle #{@label}"}
      class={
        "inline-flex cursor-pointer items-center gap-1 rounded px-1 transition-opacity hover:opacity-100 " <>
          (if @hidden, do: "opacity-40", else: "opacity-80")
      }
    >
      <span class="inline-block size-2 rounded-full" style={"background-color: #{@color}"}></span>
      {@label}
    </button>
    """
  end

  defp hidden?(nil, _series), do: false
  defp hidden?(%MapSet{} = hidden, series), do: MapSet.member?(hidden, series)
  defp hidden?(hidden, series) when is_list(hidden), do: series in hidden
  defp hidden?(_, _), do: false

  attr :system, :map, required: true
  attr :system_info, :any, default: nil

  defp system_info(assigns) do
    ~H"""
    <div class="min-w-0 text-xs">
      <p class="flex min-w-0 items-center gap-x-2">
        <span
          class="shrink-0 font-semibold"
          style={"color: #{Systems.color(@system)}"}
        >
          {Systems.display_class(@system) || "Unknown"}
        </span>
        <span class="truncate opacity-60">
          {info_line(@system, @system_info)}
        </span>
      </p>
      <p
        :if={sov_holder(@system_info)}
        class="flex min-w-0 items-center gap-x-1.5 pt-0.5"
      >
        <img
          src={sov_logo(sov_holder(@system_info))}
          alt=""
          aria-hidden="true"
          class="size-4 shrink-0 rounded-sm"
          loading="lazy"
          onerror="this.onerror=null;this.src='/images/alliance-default.png'"
        />
        <span class="truncate opacity-60">
          {sov_holder(@system_info).name}
        </span>
      </p>
    </div>
    """
  end

  defp info_line(_system, %{region: region, constellation: constellation}) do
    "#{region} / #{constellation}"
  end

  defp info_line(_system, %{wormhole: true}), do: "W-Space"

  defp info_line(system, _loading) do
    if Systems.esi_resolvable?(system), do: "Loading region…", else: "W-Space"
  end

  defp selected_system(systems, id) do
    Enum.find(systems, &(&1.id == id))
  end

  defp sov_holder(%{sovereignty: %{name: _name} = holder}), do: holder
  defp sov_holder(_), do: nil

  defp sov_logo(%{kind: :alliance, id: id}), do: EveImages.alliance_logo(id, 32)
  defp sov_logo(%{kind: :faction, id: id}), do: EveImages.faction_logo(id, 32)
  defp sov_logo(_), do: "/images/alliance-default.png"

  defp selected_favorite?(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{favorite: true} -> true
      _ -> false
    end
  end

  defp favorites(systems) when is_list(systems) do
    Enum.filter(systems, & &1.favorite)
  end

  defp favorites(_), do: []

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
