defmodule ZtripwireWeb.LiveComponents.SystemLive do
  use ZtripwireWeb, :live_component

  alias Ztripwire.EveImages
  alias Ztripwire.Mapping
  alias Ztripwire.Systems

  def update(assigns, socket) do
    systems =
      case Map.get(assigns, :systems) do
        nil -> Mapping.list_systems(assigns.mask_id)
        systems -> systems
      end

    connections =
      Map.get_lazy(assigns, :connections, fn ->
        Mapping.list_connections_with_endpoints(assigns.mask_id)
      end)

    chart_system = Map.get(assigns, :chart_system)
    connected_systems = connected_systems(systems, connections, chart_system)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:systems, systems)
     |> assign(:connections, connections)
     |> assign(:chart_system, chart_system)
     |> assign(:connected_systems, connected_systems)
     |> assign(:gate_systems, gate_systems(chart_system, connected_systems))
     |> assign_new(:system_info, fn -> nil end)
     |> assign_new(:chart_range, fn -> "24h" end)
     |> assign_new(:chart_hidden, fn -> MapSet.new() end)
     |> assign_new(:chart_data, fn ->
       %{labels: [], jumps: [], ship_kills: [], pod_kills: [], npc_kills: []}
     end)
     |> assign_new(:kill_stream, fn -> [] end)
     |> assign_new(:character, fn -> nil end)}
  end

  def handle_event("select-system", %{"id" => id}, socket) do
    case parse_id(id) do
      nil -> :ok
      system_id -> send(self(), {:select_system, system_id})
    end

    {:noreply, socket}
  end

  def handle_event("select-gate-system", %{"solar" => solar}, socket) do
    case parse_id(solar) do
      nil -> :ok
      solar_system_id -> send(self(), {:select_gate_system, solar_system_id})
    end

    {:noreply, socket}
  end

  def handle_event("toggle-favorite", _params, socket) do
    send(self(), :toggle_favorite)
    {:noreply, socket}
  end

  def handle_event("set-destination", %{"solar" => solar}, socket) do
    case parse_id(solar) do
      nil -> :ok
      solar_id -> send(self(), {:set_destination, solar_id})
    end

    {:noreply, socket}
  end

  def handle_event("open-window", %{"solar" => solar}, socket) do
    case parse_id(solar) do
      nil -> :ok
      solar_id -> send(self(), {:open_window, solar_id})
    end

    {:noreply, socket}
  end

  defp parse_id(id) do
    case Integer.parse(to_string(id)) do
      {value, ""} -> value
      _ -> nil
    end
  end

  attr :position, :map, default: %{"x" => 0, "y" => 0, "w" => 6, "h" => 6}

  def render(assigns) do
    ~H"""
    <div
      id="system-container"
      gs-w={@position["w"]}
      gs-h={@position["h"]}
      gs-x={@position["x"]}
      gs-y={@position["y"]}
      class="grid-stack-item"
      tabindex="0"
      phx-hook="GridWidget"
    >
      <div class="grid-stack-item-content bg-base-100 flex flex-col overflow-hidden">
        <div class="flex min-h-0 size-full flex-col">
          <ul class="list rounded-box shadow-md shrink-0">
            <li class="widget-header">
              <button
                id="system-copy"
                class="group flex min-w-0 cursor-pointer items-center gap-1 rounded px-1 hover:bg-base-200"
                title={"Copy #{chart_name(@chart_system)}"}
                phx-hook="CopyText"
                data-copy={chart_name(@chart_system)}
              >
                <span class="truncate text-lg font-semibold">
                  {chart_name(@chart_system)}
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
                  <a
                    :for={fav <- favorites(@systems)}
                    href={"/" <> fav.name}
                    title={"Select #{fav.name}"}
                    class="flex w-full items-center gap-2 rounded px-2 py-1 text-left hover:bg-base-300"
                  >
                    <span
                      class="inline-block size-2.5 shrink-0 rounded-full"
                      style={"background-color: #{Systems.color(fav)}"}
                    >
                    </span>
                    <span class="truncate font-mono">{fav.alias || fav.name}</span>
                  </a>
                </div>
              </details>
              <button
                :if={not is_nil(@selected_system_id)}
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
                      do: "size-5 text-active-accent",
                      else: "size-5 opacity-60"
                  }
                />
              </button>
            </li>
          </ul>
          <div
            :if={@chart_system}
            class="flex shrink-0 flex-col gap-y-1 px-2 pt-1"
          >
            <.system_info system={@chart_system} system_info={@system_info} />
          </div>
          <div class="flex shrink-0 flex-wrap items-center justify-between gap-x-3 gap-y-1 px-2 pt-1 text-xs">
            <div :if={@chart_system} class="flex flex-wrap items-center gap-x-3 gap-y-1">
              <a
                :for={link <- Systems.external_links(@chart_system)}
                href={link.url}
                target="_blank"
                rel="noopener noreferrer"
                class="link link-hover opacity-70 hover:opacity-100"
              >
                {link.label}
              </a>
              <button
                :if={character?(@character)}
                id="system-set-destination"
                type="button"
                class="link link-hover opacity-70 hover:opacity-100 disabled:opacity-40"
                disabled={
                  !waypoint_available?(@chart_system) or
                    !scope?(@character, "esi-ui.write_waypoint.v1")
                }
                title={
                  cond do
                    not scope?(@character, "esi-ui.write_waypoint.v1") ->
                      "Log in again to grant autopilot access"

                    not waypoint_available?(@chart_system) ->
                      "Autopilot is available for k-space systems only"

                    true ->
                      "Set autopilot destination"
                  end
                }
                phx-click="set-destination"
                phx-value-solar={@chart_system.solar_system_id}
                phx-target={@myself}
              >
                Set destination
              </button>
              <button
                :if={character?(@character)}
                id="system-open-window"
                type="button"
                class="link link-hover opacity-70 hover:opacity-100 disabled:opacity-40"
                disabled={!scope?(@character, "esi-ui.open_window.v1")}
                title={
                  if scope?(@character, "esi-ui.open_window.v1"),
                    do: "Open in the EVE client",
                    else: "Log in again to grant window access"
                }
                phx-click="open-window"
                phx-value-solar={@chart_system.solar_system_id}
                phx-target={@myself}
              >
                Open in game
              </button>
            </div>
            <.chart_range_buttons :if={chart_visible?(@chart_system)} chart_range={@chart_range} />
          </div>
          <div
            :if={chart_visible?(@chart_system)}
            id="system-chart"
            phx-hook="ChartMount"
            data-chart-fn="initSystemChart"
            data-labels={Jason.encode!(@chart_data[:labels] || [])}
            data-jumps={Jason.encode!(@chart_data[:jumps] || [])}
            data-ship-kills={Jason.encode!(@chart_data[:ship_kills] || [])}
            data-pod-kills={Jason.encode!(@chart_data[:pod_kills] || [])}
            data-npc-kills={Jason.encode!(@chart_data[:npc_kills] || [])}
            data-hidden={Jason.encode!(hidden_series(@chart_hidden))}
            phx-update="ignore"
            class="min-h-0 w-full flex-1"
          >
          </div>
          <.chart_legend :if={chart_visible?(@chart_system)} chart_hidden={@chart_hidden} />
          <.kill_stream
            :if={@chart_system && not chart_visible?(@chart_system)}
            kills={@kill_stream}
          />
          <.system_selector
            systems={@systems}
            connected_systems={@connected_systems}
            chart_system={@chart_system}
            gate_systems={@gate_systems}
          />
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

  defp chart_visible?(nil), do: false
  defp chart_visible?(system), do: Systems.esi_resolvable?(system)

  defp character?(nil), do: false
  defp character?(%{refresh_token: token}), do: not is_nil(token)
  defp character?(_), do: false

  defp scope?(character, scope), do: scope in List.wrap(Map.get(character, :scopes, []))

  defp waypoint_available?(%{solar_system_id: id}) when is_integer(id), do: id < 31_000_000
  defp waypoint_available?(_), do: false

  attr :kills, :list, default: []

  defp kill_stream(assigns) do
    ~H"""
    <div class="min-h-0 w-full flex-1 overflow-y-auto px-2 pb-2">
      <p class="mb-1 flex items-center justify-between text-[10px] uppercase tracking-widest opacity-60">
        <span>Recent kills</span>
        <span>past 8 hours · zKillboard</span>
      </p>
      <div
        :if={@kills == []}
        class="rounded border border-dashed border-base-content/20 p-4 text-center text-xs opacity-60"
      >
        No kills in the past 8 hours.
      </div>
      <div :if={@kills != []} class="grid grid-cols-5 gap-1.5">
        <a
          :for={kill <- @kills}
          href={"https://zkillboard.com/kill/#{kill.id}/"}
          target="_blank"
          rel="noopener noreferrer"
          class="flex min-w-0 flex-col items-center gap-1 rounded border border-base-content/20 bg-base-200 p-1 hover:border-primary"
          title={"#{kill.ship_name} · #{format_isk(kill.value)} ISK · #{kill_age(kill.time)} ago"}
        >
          <img
            src={EveImages.type_render(kill.ship_type_id, 64)}
            alt=""
            loading="lazy"
            class="size-11 rounded object-cover"
            onerror={"this.onerror=null;this.src='#{EveImages.type_icon(kill.ship_type_id, 64)}'"}
          />
          <span class="w-full truncate text-center text-[10px]">{kill.ship_name}</span>
          <span class="text-[10px] tabular-nums opacity-60">
            {format_isk(kill.value)} · {kill_age(kill.time)}
          </span>
        </a>
      </div>
    </div>
    """
  end

  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}b"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}m"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}k"
      true -> Integer.to_string(trunc(value))
    end
  end

  defp format_isk(_), do: "0"

  defp kill_age(%DateTime{} = time), do: kill_age(DateTime.diff(DateTime.utc_now(), time))

  defp kill_age(%NaiveDateTime{} = time),
    do: kill_age(NaiveDateTime.diff(NaiveDateTime.utc_now(), time))

  defp kill_age(seconds) when is_integer(seconds) and seconds < 3600,
    do: "#{max(1, div(seconds, 60))}m"

  defp kill_age(seconds) when is_integer(seconds) do
    "#{Float.round(seconds / 3600, 1) |> :erlang.float_to_binary(decimals: 1)}h"
  end

  attr :chart_range, :string, default: "24h"

  defp chart_range_buttons(assigns) do
    ~H"""
    <div class="ml-auto flex shrink-0 items-center gap-1" role="group" aria-label="Chart time range">
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
    """
  end

  attr :systems, :list, default: []
  attr :connected_systems, :list, default: []
  attr :chart_system, :any, default: nil
  attr :gate_systems, :list, default: []

  defp system_selector(assigns) do
    ~H"""
    <div class="flex shrink-0 flex-wrap items-center gap-1 px-2 pt-0.5 pb-2">
      <button
        :for={sys <- @connected_systems}
        class="btn btn-ghost btn-xs"
        title={"Select system #{sys.name}"}
        phx-click="select-system"
        phx-value-id={sys.id}
      >
        {sys.name}
      </button>
      <span
        :if={@gate_systems != [] and @connected_systems != []}
        class="mx-1 h-4 w-px shrink-0 bg-base-content/20"
        aria-hidden="true"
      >
      </span>
      <button
        :for={sys <- @gate_systems}
        class="btn btn-ghost btn-xs"
        title={"Select system #{sys.name} (1 jump from #{chart_name(@chart_system)})"}
        phx-click="select-gate-system"
        phx-value-solar={sys.solar_system_id}
      >
        {sys.name}
      </button>
      <span :if={@systems == []} class="p-1 text-sm opacity-50">No systems on map yet</span>
    </div>
    """
  end

  attr :chart_hidden, :any, default: nil

  defp chart_legend(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 px-2 pt-1 pb-3 text-[11px]">
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

  defp hidden_series(nil), do: []
  defp hidden_series(%MapSet{} = hidden), do: hidden |> MapSet.to_list() |> Enum.sort()
  defp hidden_series(hidden) when is_list(hidden), do: Enum.sort(hidden)
  defp hidden_series(_), do: []

  attr :system, :map, required: true
  attr :system_info, :any, default: nil

  defp system_info(assigns) do
    ~H"""
    <div class="min-w-0 text-xs">
      <p class="flex min-w-0 items-center gap-x-2">
        <span
          class="class-ink shrink-0 font-semibold"
          style={"--class-ink: #{Systems.color(@system)}"}
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

  defp chart_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp chart_name(_), do: "Jita"

  defp gate_systems(chart, connected_systems) do
    with %{solar_system_id: solar} when is_integer(solar) <- chart,
         true <- solar < 31_000_000,
         true <- Systems.Gates.loaded?(),
         true <- Systems.Catalog.loaded?() do
      shown = MapSet.new(connected_systems, & &1.solar_system_id)

      Systems.Gates.neighbors(solar)
      |> Enum.reject(&(&1 >= 31_000_000 or MapSet.member?(shown, &1)))
      |> Enum.map(&Systems.Catalog.get/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&String.downcase(&1.name || ""))
    else
      _ -> []
    end
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

  defp connected_systems(systems, connections, chart_system) do
    known = Enum.reject(systems, & &1.unknown)
    solar_system_id = solar_system_id(chart_system)

    neighbor_ids =
      for {_conn, from, to} <- connections,
          from.solar_system_id == solar_system_id or to.solar_system_id == solar_system_id,
          id <- [from.solar_system_id, to.solar_system_id],
          id != solar_system_id,
          into: MapSet.new() do
        id
      end

    Enum.filter(known, &MapSet.member?(neighbor_ids, &1.solar_system_id))
  end

  defp solar_system_id(%{solar_system_id: solar_system_id}), do: solar_system_id
  defp solar_system_id(_), do: nil
end
