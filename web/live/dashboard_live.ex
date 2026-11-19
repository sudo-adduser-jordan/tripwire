defmodule TripwireWeb.DashboardLive do
  use TripwireWeb, :live_view

  alias Tripwire.Accounts
  alias Tripwire.ESI
  alias Tripwire.Mapping
  alias Tripwire.Masks
  alias Tripwire.Signatures, as: SigParser
  alias Tripwire.Systems
  alias Tripwire.Tracking

  @demo_character_eve_id Tripwire.Demo.character_eve_id()
  @demo_character_name Tripwire.Demo.character_name()
  @demo_ship_name Tripwire.Demo.ship_name()
  @demo_ship_type_id Tripwire.Demo.ship_type_id()
  @topbar_refresh_ms 60_000
  @chart_refresh_ms 60_000
  @chart_ranges ~w(24h 48h week)
  @settings_tabs ~w(account map widgets statistics themes admin)
  @widgets %{
    "system" => :widget_system,
    "notes" => :widget_notes,
    "signatures" => :widget_signatures,
    "map" => :widget_map
  }

  @impl true
  def mount(_params, session, socket) do
    case session_character(session) do
      {:ok, character} ->
        {:ok, socket |> provision(character) |> assign_characters(session)}

      :expired ->
        {:ok,
         socket
         |> put_flash(:error, "Session expired, log in again")
         |> redirect(to: "/")}

      :anonymous ->
        {:ok, socket |> mount_demo() |> assign_characters(session)}
    end
  end

  defp session_character(session) do
    case TripwireWeb.SessionUser.get(session) do
      %{id: eve_id} ->
        case Accounts.get_character_by_eve_id(eve_id) do
          nil -> :expired
          character -> {:ok, character}
        end

      nil ->
        :anonymous
    end
  end

  defp assign_characters(socket, session) do
    assign(socket, :characters, session_characters(session, socket.assigns.character))
  end

  defp ensure_demo_presence(character, map, systems) do
    case Enum.find(systems, &(&1.alias == "Home")) do
      %{id: _} = home ->
        Tracking.DemoPresence.ensure_started(character, map, home, ship_name: @demo_ship_name)

      nil ->
        :ok
    end
  end

  defp refresh_occupants(socket) do
    occupants =
      if socket.assigns.map, do: Tracking.list_occupants(socket.assigns.map.id), else: []

    assign(socket, :occupants, occupants)
  end

  defp assign_demo_presence(socket) do
    presence = fetch_character_presence(socket.assigns.character)
    presences = Map.new(socket.assigns.characters, &{&1.eve_id, presence})

    socket
    |> assign(:current_system_name, presence.system_name)
    |> assign(:character_online, presence.online)
    |> assign(:ship_type_id, presence.ship_type_id)
    |> assign(:presences, presences)
  end

  defp mount_demo(socket) do
    {:ok, character} =
      Accounts.upsert_character(%{
        eve_id: @demo_character_eve_id,
        name: @demo_character_name,
        is_admin: true
      })

    {:ok, mask} = Masks.ensure_demo_mask()
    {:ok, _} = Masks.add_membership(mask, character)
    {:ok, map} = Mapping.ensure_demo_map(mask.id)
    systems = ensure_jita_system(map, Mapping.list_systems(map.id))
    ensure_demo_presence(character, map, systems)

    socket
    |> assign(:current_user, nil)
    |> assign(:character, character)
    |> assign(:characters, [character])
    |> assign(:mask, mask)
    |> assign(:masks, [mask])
    |> assign(:map, map)
    |> assign(:maps, Mapping.list_maps_for_mask(mask.id))
    |> assign(:systems, Mapping.list_chain_systems(map))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
    |> refresh_occupants()
    |> apply_tree_layout("top")
    |> assign(:selected_system_id, nil)
    |> assign(:selected_system_name, nil)
    |> assign(:system_suggestions, [])
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> autoselect_first_system()
    |> assign(:stale_ids, [])
    |> assign(:stale_system_id, nil)
    |> assign(:settings_open, false)
    |> assign(:settings_tab, "account")
    |> assign(:map_layout, "top")
    |> assign(:undo, [])
    |> assign(:redo, [])
    |> assign(:demo?, true)
    |> assign(:claim_admin?, false)
    |> assign(:claim_admin_modal?, false)
    |> assign(:branding, nil)
    |> assign(:sig_modal_open, false)
    |> assign(:sig_edit_id, nil)
    |> assign(:sig_form, %{
      "sig_id" => "",
      "kind" => "signature",
      "site_type" => "unknown",
      "type_name" => "",
      "life_length" => "259200",
      "bookmark" => ""
    })
    |> assign(:sig_errors, [])
    |> assign_topbar_defaults()
    |> assign_demo_presence()
    |> assign(:sso_configured?, Tripwire.SSO.configured?())
    |> subscribe_to_map(map.id)
    |> schedule_topbar_load()
    |> schedule_chart_refresh()
  end

  @impl true
  def handle_params(params, _url, socket) do
    system_name = Map.get(params, "system_name") || Map.get(params, "system")
    systems = socket.assigns[:systems] || []

    cond do
      system_name && systems != [] ->
        case Enum.find(systems, &(String.downcase(&1.name) == String.downcase(system_name))) do
          %{id: id} ->
            if socket.assigns[:selected_system_id] == id do
              {:noreply, socket}
            else
              {:noreply, select_system(socket, id)}
            end

          nil ->
            case preferred_system(systems) do
              %{id: id, name: name} ->
                {:noreply, socket |> select_system(id) |> push_patch(to: "/" <> name)}

              nil ->
                {:noreply, socket}
            end
        end

      systems != [] ->
        if socket.assigns[:selected_system_id] do
          {:noreply, socket}
        else
          case preferred_system(systems) do
            %{id: id} -> {:noreply, select_system(socket, id)}
            nil -> {:noreply, socket}
          end
        end

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:map_updated, map_id}, %{assigns: %{map: map}} = socket)
      when not is_nil(map) and map_id == map.id do
    {:noreply,
     socket
     |> apply_tree_layout(socket.assigns.map_layout || "top")}
  end

  def handle_info({:select_system, system_id}, socket) do
    {:noreply, select_system_and_patch(socket, system_id)}
  end

  def handle_info({:open_system, system_id}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply,
       socket |> select_system_and_patch(system_id) |> put_flash(:error, "Map is locked")}
    else
      {:noreply,
       socket
       |> select_system_and_patch(system_id)
       |> open_system_modal(system_id)}
    end
  end

  def handle_info(:toggle_favorite, socket) do
    {:noreply, toggle_favorite(socket)}
  end

  def handle_info({:open_connection, conn_id}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      case Mapping.get_connection(conn_id) do
        nil ->
          {:noreply, socket}

        conn ->
          {:noreply,
           socket
           |> assign(:conn_modal_open, true)
           |> assign(:conn_edit_id, conn.id)
           |> assign(:conn_errors, [])
           |> assign(:conn_form, %{
             "hole_type" => conn.hole_type || "",
             "mass_status" => conn.mass_status || "stable",
             "time_status" => conn.time_status || "stable",
             "ship_size" => conn.ship_size || ""
           })}
      end
    end
  end

  def handle_info({:signatures_updated, system_id}, socket) do
    socket =
      if socket.assigns.selected_system_id == system_id do
        assign(socket, :signatures, Mapping.list_signatures(system_id))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:systems_updated, map_id}, %{assigns: %{map: map}} = socket)
      when not is_nil(map) and map_id == map.id do
    {:noreply,
     socket
     |> assign(:systems, Mapping.list_chain_systems(map))
     |> assign(:connections, Mapping.list_connections_with_endpoints(map_id))}
  end

  def handle_info({:comments_updated, system_id}, socket) do
    socket =
      if socket.assigns.selected_system_id == system_id do
        assign(socket, :comments, Mapping.list_comments(system_id))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:system_changed, %{character: name, system: system}}, socket) do
    current_name = socket.assigns.character && socket.assigns.character.name

    socket =
      if current_name == name do
        assign(socket, :current_system_name, system.name)
      else
        socket
      end

    {:noreply,
     socket
     |> refresh_occupants()
     |> put_flash(:info, "#{name} jumped into #{system.name}")}
  end

  def handle_info(:load_topbar, socket) do
    if topbar_esi_enabled?() do
      pid = self()
      character = socket.assigns.character
      characters = socket.assigns.characters
      Task.start(fn -> send(pid, {:topbar_loaded, fetch_topbar_data(character, characters)}) end)
    end

    schedule_topbar_refresh()
    {:noreply, refresh_occupants(socket)}
  end

  def handle_info(:refresh_topbar, socket) do
    if topbar_esi_enabled?() do
      pid = self()
      character = socket.assigns.character
      characters = socket.assigns.characters
      Task.start(fn -> send(pid, {:topbar_loaded, fetch_topbar_data(character, characters)}) end)
    end

    schedule_topbar_refresh()
    {:noreply, refresh_occupants(socket)}
  end

  def handle_info({:topbar_loaded, data}, socket) do
    {:noreply,
     socket
     |> assign(:tq_online, data.tq_online)
     |> assign(:tq_players, data.tq_players)
     |> assign(
       :current_system_name,
       data.current_system_name || socket.assigns.current_system_name
     )
     |> assign(:character_online, data.character_online)
     |> assign(:ship_type_id, data.ship_type_id)
     |> assign(:presences, data.presences)
     |> assign(:topbar_now, data.now)}
  end

  def handle_info({:system_info_loaded, system_id, info}, socket) do
    if socket.assigns.selected_system_id == system_id do
      {:noreply, assign(socket, :system_info, info_to_assign(info))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:chart_data_loaded, system_id, range, data}, socket) do
    if socket.assigns.selected_system_id == system_id and socket.assigns.chart_range == range do
      {:noreply,
       socket
       |> assign(:chart_data, data)
       |> push_event(
         "system-chart-data",
         chart_payload(data, socket.assigns[:chart_hidden] || MapSet.new())
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:refresh_chart, socket) do
    schedule_chart_refresh()

    if connected?(socket) && socket.assigns.selected_system_id do
      {:noreply, schedule_chart_reload(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_map}, socket), do: handle_event("new-map", %{}, socket)

  def handle_info({:switch_map, map_id}, socket),
    do: handle_event("switch-map", %{"id" => to_string(map_id)}, socket)

  def handle_info({:add_viewing}, socket), do: handle_event("add-viewing", %{}, socket)

  def handle_info({:map_layout, layout}, socket),
    do: handle_event("map-layout", %{"layout" => layout}, socket)

  def handle_info(:toggle_map_lock, socket),
    do: handle_event("toggle-map-lock", %{}, socket)

  def handle_info(:show_favorites, socket),
    do: handle_event("show-favorites", %{}, socket)

  def handle_info(:open_chain_modal, socket),
    do: handle_event("open-chain-modal", %{}, socket)

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle-settings", _params, socket) do
    {:noreply, update(socket, :settings_open, &(!&1))}
  end

  def handle_event("toggle-grid-lock", _params, socket) do
    {:noreply, update(socket, :grid_locked, &(!&1))}
  end

  def handle_event("toggle-widget", %{"widget" => widget}, socket) do
    case @widgets do
      %{^widget => key} -> {:noreply, update(socket, key, &(!&1))}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle-map-lock", _params, socket) do
    {:noreply, update(socket, :map_locked, &(!&1))}
  end

  def handle_event("open-chain-modal", _params, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      map = socket.assigns.map

      home =
        cond do
          map && map.home_name not in [nil, ""] -> map.home_name
          map && map.home_solar_system_id -> to_string(map.home_solar_system_id)
          true -> socket.assigns[:selected_system_name] || ""
        end

      {:noreply,
       socket
       |> assign(:chain_modal_open, true)
       |> assign(:chain_errors, [])
       |> assign(:chain_form, %{
         "home" => home || "",
         "include_thera" => !!(map && map.include_thera),
         "show_all" => !!(map && map.show_all)
       })}
    end
  end

  def handle_event("close-chain-modal", _params, socket) do
    {:noreply, assign(socket, :chain_modal_open, false)}
  end

  def handle_event("save-chain-settings", %{"chain" => params}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      {:noreply, save_chain_settings(socket, params)}
    end
  end

  def handle_event("show-favorites", _params, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      {:noreply, import_connected_favorites(socket)}
    end
  end

  def handle_event("system-search-submit", %{"search" => search}, socket) do
    trimmed = String.trim(search || "")

    case Enum.find(socket.assigns.systems, fn s ->
           String.downcase(s.name) == String.downcase(trimmed)
         end) do
      %{id: id, name: name} ->
        {:noreply,
         socket
         |> select_system(id)
         |> push_patch(to: "/" <> name)}

      nil ->
        case Systems.Catalog.find(trimmed) do
          %{name: name} ->
            {:noreply, push_system_patch(socket, name)}

          nil ->
            {:noreply,
             socket
             |> assign(:system_search, search || "")
             |> assign(:system_suggestions, suggest_systems(socket.assigns.systems, trimmed))
             |> put_flash(:error, "No system matching #{inspect(trimmed)}")}
        end
    end
  end

  def handle_event("system-search-pick", %{"name" => name}, socket) do
    {:noreply, push_system_patch(socket, name)}
  end

  def handle_event("system-search-pick", _params, socket), do: {:noreply, socket}

  def handle_event("system-search-change", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:system_search, search || "")
     |> assign(:system_suggestions, suggest_systems(socket.assigns.systems, search || ""))}
  end

  def handle_event("settings-tab", %{"tab" => tab}, socket)
      when tab in @settings_tabs do
    if tab == "admin" and not admin?(socket) do
      {:noreply, put_flash(socket, :error, "Admin access required")}
    else
      {:noreply, assign(socket, :settings_tab, tab)}
    end
  end

  def handle_event("settings-tab", _params, socket), do: {:noreply, socket}

  def handle_event("open-settings", %{"tab" => tab}, socket)
      when tab in @settings_tabs do
    {:noreply, socket |> assign(:settings_open, true) |> assign(:settings_tab, tab)}
  end

  def handle_event("open-settings", _params, socket), do: {:noreply, socket}

  def handle_event("claim-admin", _params, socket) do
    with true <- socket.assigns[:claim_admin?],
         {:ok, character} <- Accounts.claim_admin(socket.assigns.character) do
      Tripwire.Log.emit(:info, %{
        event: "admin_claimed",
        eve_id: character.eve_id,
        name: character.name
      })

      {:noreply,
       socket
       |> assign(:character, character)
       |> assign(:characters, replace_character(socket.assigns.characters, character))
       |> assign(:claim_admin?, false)
       |> assign(:claim_admin_modal?, false)
       |> assign(:branding, Accounts.branding())
       |> put_flash(:info, "You are now an admin")}
    else
      {:error, :admin_exists} ->
        {:noreply, put_flash(socket, :error, "An admin already exists")}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("defer-claim-admin", _params, socket) do
    {:noreply, assign(socket, :claim_admin_modal?, false)}
  end

  def handle_event("add-character", _params, socket) do
    {:noreply, put_flash(socket, :error, "EVE SSO is not configured, demo mode is active")}
  end

  def handle_event("remove-character", %{"id" => id}, socket) do
    with {char_id, ""} <- Integer.parse(to_string(id)),
         %{} = character <- Accounts.get_character(char_id),
         {:ok, _} <- Accounts.delete_character(character) do
      Tracking.stop_poller(character)
      remaining = Enum.reject(socket.assigns.characters, &(&1.id == character.id))
      socket = assign(socket, :characters, remaining)

      if socket.assigns.character && socket.assigns.character.id == character.id do
        case remaining do
          [next | _] -> {:noreply, push_navigate(socket, to: "/auth/switch/#{next.eve_id}")}
          [] -> {:noreply, push_navigate(socket, to: "/dashboard")}
        end
      else
        {:noreply, put_flash(socket, :info, "Removed #{character.name}")}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Character not found")}
    end
  end

  def handle_event("toggle-ship-visibility", %{"id" => id}, socket) do
    toggle_visibility(socket, id, fn %{ship_on_chain: ship_on_chain} ->
      %{ship_on_chain: not ship_on_chain}
    end)
  end

  def handle_event("toggle-character-visibility", %{"id" => id}, socket) do
    toggle_visibility(socket, id, fn
      %{character_on_chain: false} -> %{character_on_chain: true}
      _ -> %{character_on_chain: false, ship_on_chain: false}
    end)
  end

  def handle_event("select-system", %{"id" => id}, socket) do
    {:noreply, select_system_and_patch(socket, String.to_integer(id))}
  end

  def handle_event("chart-range", %{"range" => range}, socket) when range in @chart_ranges do
    socket =
      socket
      |> assign(:chart_range, range)
      |> schedule_chart_reload()

    {:noreply, socket}
  end

  def handle_event("chart-range", _params, socket), do: {:noreply, socket}

  def handle_event("chart-toggle-series", %{"series" => series}, socket)
      when series in ~w(jumps ship_kills pod_kills npc_kills) do
    hidden = socket.assigns[:chart_hidden] || MapSet.new()

    hidden =
      if MapSet.member?(hidden, series),
        do: MapSet.delete(hidden, series),
        else: MapSet.put(hidden, series)

    {:noreply,
     socket
     |> assign(:chart_hidden, hidden)
     |> push_event("system-chart-data", chart_payload(socket.assigns.chart_data, hidden))}
  end

  def handle_event("chart-toggle-series", _params, socket), do: {:noreply, socket}

  def handle_event("toggle-favorite", _params, socket) do
    {:noreply, toggle_favorite(socket)}
  end

  def handle_event("map-layout", %{"layout" => "default"}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      socket = socket |> assign(:map_layout, "top") |> apply_tree_layout("top")
      {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map)
      {:noreply, push_event(socket, "reset-pan", %{x: x, y: y})}
    end
  end

  def handle_event("map-layout", %{"layout" => layout}, socket)
      when layout in ~w(top bottom left right radial) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      {:noreply, socket |> assign(:map_layout, layout) |> apply_tree_layout(layout)}
    end
  end

  def handle_event("map-layout", _params, socket), do: {:noreply, socket}

  def handle_event("toggle-row-guides", _params, socket) do
    {:noreply, update(socket, :show_row_guides, &(!&1))}
  end

  def handle_event("toggle-row-counts", _params, socket) do
    {:noreply, update(socket, :show_row_counts, &(!&1))}
  end

  def handle_event("toggle-angled-lines", _params, socket) do
    {:noreply, update(socket, :angled_lines, &(!&1))}
  end

  def handle_event("toggle-jump-lines", _params, socket) do
    {:noreply, update(socket, :show_jump_lines, &(!&1))}
  end

  def handle_event("toggle-line-glow", _params, socket) do
    {:noreply, update(socket, :show_line_glow, &(!&1))}
  end

  def handle_event("toggle-node-badges", _params, socket) do
    {:noreply, update(socket, :show_node_badges, &(!&1))}
  end

  def handle_event("map-scale", %{"scale" => scale}, socket) do
    scale = parse_int(scale, 100, 50, 200)

    {:noreply,
     socket |> assign(:map_scale, scale) |> push_event("map-zoom", %{zoom: scale / 100})}
  end

  def handle_event("map-scale", _params, socket), do: {:noreply, socket}

  def handle_event("line-weight", %{"weight" => weight}, socket) do
    {:noreply, assign(socket, :line_weight, parse_int(weight, 2, 1, 5))}
  end

  def handle_event("line-weight", _params, socket), do: {:noreply, socket}

  def handle_event("node-spacing", %{"spacing" => spacing}, socket) do
    socket = assign(socket, :node_spacing, parse_int(spacing, 100, 50, 200))
    socket = socket |> apply_tree_layout(socket.assigns.map_layout || "top")
    {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map)
    {:noreply, push_event(socket, "reset-pan", %{x: x, y: y})}
  end

  def handle_event("node-spacing", _params, socket), do: {:noreply, socket}

  def handle_event("map-background", %{"background" => background}, socket) do
    background = background |> to_string() |> String.trim()
    {:noreply, assign(socket, :map_background, if(background == "", do: nil, else: background))}
  end

  def handle_event("map-background", _params, socket), do: {:noreply, socket}

  def handle_event("create-corp-mask", _params, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_create_corp_mask(socket) do
      {:noreply,
       socket
       |> assign(:masks, masks_for_admin(socket))
       |> put_flash(:info, "Created #{mask.name}")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Admin access required")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Demo admins are scoped to demo masks")}

      {:error, :no_corporation} ->
        {:noreply, put_flash(socket, :error, "No corporation on file")}

      {:error, changeset} ->
        {:noreply, flash_changeset_errors(socket, changeset)}
    end
  end

  def handle_event("add-mask-member", params, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_mask(socket, params["mask_id"]),
         {:ok, member} <- scoped_upsert_member(params),
         {:ok, _} <- Masks.add_membership(mask, member) do
      {:noreply,
       socket
       |> assign(:masks, masks_for_admin(socket))
       |> put_flash(:info, "Added #{member.name} to #{mask.name}")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Admin access required")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Demo admins are scoped to demo masks")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Mask not found")}

      {:error, changeset} ->
        {:noreply, flash_changeset_errors(socket, changeset)}
    end
  end

  def handle_event("remove-mask-member", params, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_mask(socket, params["mask_id"] || params["mask-id"]),
         member when not is_nil(member) <-
           Accounts.get_character(params["character_id"] || params["character-id"]),
         true <- scoped_member?(socket, mask, member),
         {:ok, _} <- Masks.remove_membership(mask, member) do
      {:noreply,
       socket
       |> assign(:masks, masks_for_admin(socket))
       |> put_flash(:info, "Removed #{member.name} from #{mask.name}")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Admin access required")}

      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Demo admins are scoped to demo masks")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Mask not found")}
    end
  end

  def handle_event("delete-mask", %{"id" => id}, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_mask(socket, id),
         {:ok, _} <- Masks.delete_mask_full(mask) do
      remaining = masks_for_admin(socket) |> Enum.reject(&(&1.id == mask.id))

      socket =
        if socket.assigns.mask.id == mask.id do
          next = List.first(remaining) || elem(Masks.ensure_demo_mask(), 1)

          next_map =
            case Mapping.list_maps_for_mask(next.id) do
              [] -> elem(Mapping.create_map(%{name: "Home", mask_id: next.id}), 1)
              [m | _] -> m
            end

          next_systems = Mapping.list_chain_systems(next_map)

          socket
          |> assign(:mask, next)
          |> assign(:masks, remaining)
          |> assign(:map, next_map)
          |> assign(:maps, Mapping.list_maps_for_mask(next.id))
          |> assign(:systems, next_systems)
          |> assign(:connections, Mapping.list_connections_with_endpoints(next_map.id))
          |> assign(:selected_system_id, nil)
          |> assign(:selected_system_name, nil)
          |> assign(:system_suggestions, [])
          |> assign(:signatures, [])
          |> assign(:comments, [])
          |> patch_to_preferred(next_systems)
        else
          assign(socket, masks: remaining)
        end

      {:noreply, put_flash(socket, :info, "Deleted #{mask.name}")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Admin access required")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Demo admins are scoped to demo masks")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Mask not found")}
    end
  end

  def handle_event("global-paste", params, socket) do
    text = Map.get(params, "text", "") |> to_string()
    socket = clear_flash(socket)

    with system when not is_nil(system) <- selected_system(socket),
         entries when entries != [] <- SigParser.parse_paste(text) do
      before_ids =
        system.id |> Mapping.list_signatures() |> Enum.map(& &1.sig_id) |> MapSet.new()

      pasted_ids = entries |> Enum.map(& &1.sig_id) |> MapSet.new()

      {added, updated} = Mapping.upsert_signatures(system, entries, socket.assigns.character)

      {dropped, linked, hidden} = Mapping.sync_map_after_signature_change(system, [])

      missing = before_ids |> MapSet.difference(pasted_ids) |> Enum.sort()

      socket =
        if missing == [] do
          socket |> assign(:stale_ids, []) |> assign(:stale_system_id, nil)
        else
          socket |> assign(:stale_ids, missing) |> assign(:stale_system_id, system.id)
        end

      {:noreply,
       socket
       |> reload_map_from_sync(dropped, linked, hidden)
       |> reload_signatures()
       |> maybe_match_flash(added, updated)}
    else
      nil ->
        {:noreply,
         socket
         |> assign(:stale_ids, [])
         |> assign(:stale_system_id, nil)
         |> put_flash(:error, "Select a system first")}

      [] ->
        {:noreply,
         socket
         |> assign(:stale_ids, [])
         |> assign(:stale_system_id, nil)
         |> put_flash(:error, "No signatures recognized — bad input")}
    end
  end

  def handle_event("delete-stale", _params, socket) do
    case {socket.assigns.stale_system_id, socket.assigns.stale_ids} do
      {nil, _} ->
        {:noreply, socket}

      {_, []} ->
        {:noreply, socket}

      {system_id, stale_ids} ->
        stale_set = MapSet.new(stale_ids)
        system = Mapping.get_system!(system_id)

        deleted =
          system_id
          |> Mapping.list_signatures()
          |> Enum.filter(&MapSet.member?(stale_set, &1.sig_id))

        Enum.each(deleted, &Mapping.delete_signature(&1, socket.assigns.character))

        {dropped, linked, hidden} = Mapping.sync_map_after_signature_change(system, deleted)

        {:noreply,
         socket
         |> assign(:stale_ids, [])
         |> assign(:stale_system_id, nil)
         |> reload_map_from_sync(dropped, linked, hidden)
         |> reload_signatures()
         |> put_flash(:info, stale_flash(deleted, dropped, linked, hidden))}
    end
  end

  def handle_event("dismiss-stale", _params, socket) do
    {:noreply, socket |> assign(:stale_ids, []) |> assign(:stale_system_id, nil)}
  end

  def handle_event("add-signature", %{"sig" => params}, socket) do
    with system when not is_nil(system) <- selected_system(socket),
         {:ok, _sig} <-
           Mapping.create_signature(system, sig_attrs(params), socket.assigns.character) do
      {:noreply, socket |> reload_signatures() |> put_flash(:info, "Signature added")}
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a system first")}
      {:error, changeset} -> {:noreply, flash_changeset_errors(socket, changeset)}
    end
  end

  def handle_event("open-add", _params, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      _system ->
        {:noreply,
         socket
         |> assign(:sig_modal_open, true)
         |> assign(:sig_edit_id, nil)
         |> assign(:sig_errors, [])
         |> assign(:sig_form, %{
           "sig_id" => "",
           "kind" => "signature",
           "site_type" => "unknown",
           "type_name" => "",
           "life_length" => "259200",
           "bookmark" => ""
         })}
    end
  end

  def handle_event("open-edit", %{"id" => id}, socket) do
    case Mapping.get_signature(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Signature not found")}

      sig ->
        {:noreply,
         socket
         |> assign(:sig_modal_open, true)
         |> assign(:sig_edit_id, sig.id)
         |> assign(:sig_errors, [])
         |> assign(:sig_form, %{
           "sig_id" => sig.sig_id || "",
           "kind" => sig.kind || "signature",
           "site_type" => sig.site_type || "unknown",
           "type_name" => sig.type_name || "",
           "life_length" => to_string(sig.life_length || 259_200),
           "bookmark" => sig.bookmark || ""
         })}
    end
  end

  def handle_event("close-sig-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:sig_modal_open, false)
     |> assign(:sig_edit_id, nil)
     |> assign(:sig_errors, [])}
  end

  def handle_event("save-signature", %{"sig" => params}, socket) do
    with system when not is_nil(system) <- selected_system(socket) do
      attrs = sig_attrs(params)

      case socket.assigns.sig_edit_id do
        nil ->
          case Mapping.create_signature(system, attrs, socket.assigns.character) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(:sig_modal_open, false)
               |> assign(:sig_edit_id, nil)
               |> assign(:sig_errors, [])
               |> reload_signatures()
               |> sync_map_hole_type(system, nil, sig_hole_code(attrs))
               |> put_flash(:info, "Signature added")}

            {:error, changeset} ->
              {:noreply, assign(socket, :sig_errors, changeset_errors(changeset))}
          end

        id ->
          sig = Mapping.get_signature!(id)

          case Mapping.update_signature(sig, attrs, socket.assigns.character) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(:sig_modal_open, false)
               |> assign(:sig_edit_id, nil)
               |> assign(:sig_errors, [])
               |> reload_signatures()
               |> sync_map_hole_type(system, sig_hole_code(sig), sig_hole_code(attrs))
               |> put_flash(:info, "Signature updated")}

            {:error, changeset} ->
              {:noreply, assign(socket, :sig_errors, changeset_errors(changeset))}
          end
      end
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a system first")}
    end
  end

  def handle_event("delete-signature", %{"id" => id}, socket) do
    signature = Mapping.get_signature!(id)
    {:ok, deleted} = Mapping.delete_signature(signature, socket.assigns.character)

    {:noreply,
     socket
     |> reload_signatures()
     |> push_undo({:delete, deleted})}
  end

  def handle_event("undo", _params, socket) do
    case pop_undo(socket) do
      {nil, socket} ->
        {:noreply, socket}

      {{op, inverse}, socket} ->
        apply_inverse(op, inverse, socket)
    end
  end

  def handle_event("redo", _params, socket) do
    case redo_op(socket) do
      {nil, socket} ->
        {:noreply, socket}

      {redo_item, socket} ->
        socket = apply_redo(redo_item, socket)
        {:noreply, socket}
    end
  end

  def handle_event("close-sys-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:sys_modal_open, false)
     |> assign(:sys_edit_id, nil)
     |> assign(:sys_errors, [])}
  end

  def handle_event("update-system", %{"system" => params}, socket) do
    case socket.assigns.sys_edit_id && Mapping.get_system(socket.assigns.sys_edit_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "No system selected")}

      system ->
        attrs = %{
          alias: present(params["alias"]),
          sys_class: present(params["sys_class"]),
          effect: present(params["effect"])
        }

        case Mapping.update_system(system, attrs) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:systems, Mapping.list_chain_systems(socket.assigns.map))
             |> assign(:sys_modal_open, false)
             |> assign(:sys_edit_id, nil)
             |> assign(:sys_errors, [])
             |> put_flash(:info, "System updated")}

          {:error, changeset} ->
            {:noreply, assign(socket, :sys_errors, changeset_errors(changeset))}
        end
    end
  end

  def handle_event("delete-system", _params, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        {:ok, _} = Mapping.delete_system(system)

        remaining = Mapping.list_chain_systems(socket.assigns.map)

        socket =
          socket
          |> assign(:systems, remaining)
          |> assign(:connections, Mapping.list_connections_with_endpoints(socket.assigns.map.id))
          |> assign(:selected_system_id, nil)
          |> assign(:selected_system_name, nil)
          |> assign(:system_suggestions, [])
          |> assign(:signatures, [])
          |> assign(:comments, [])
          |> assign(:sys_modal_open, false)
          |> assign(:sys_edit_id, nil)
          |> assign(:sys_errors, [])
          |> put_flash(:info, "System removed")

        {:noreply, patch_to_preferred(socket, remaining)}
    end
  end

  def handle_event("open-connection", %{"id" => id}, socket) do
    case Mapping.get_connection(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Connection not found")}

      conn ->
        {:noreply,
         socket
         |> assign(:conn_modal_open, true)
         |> assign(:conn_edit_id, conn.id)
         |> assign(:conn_errors, [])
         |> assign(:conn_form, %{
           "hole_type" => conn.hole_type || "",
           "mass_status" => conn.mass_status || "stable",
           "time_status" => conn.time_status || "stable",
           "ship_size" => conn.ship_size || ""
         })}
    end
  end

  def handle_event("close-conn-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:conn_modal_open, false)
     |> assign(:conn_edit_id, nil)
     |> assign(:conn_errors, [])}
  end

  def handle_event("save-connection", %{"conn" => params}, socket) do
    case socket.assigns.conn_edit_id && Mapping.get_connection(socket.assigns.conn_edit_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "No connection selected")}

      conn ->
        attrs = %{
          hole_type: present(params["hole_type"]),
          mass_status: params["mass_status"] || "stable",
          time_status: params["time_status"] || "stable",
          ship_size: present(params["ship_size"])
        }

        case Mapping.update_connection(conn, attrs) do
          {:ok, updated} ->
            _ = Mapping.sync_connection_life(updated)

            {:noreply,
             socket
             |> assign(:conn_modal_open, false)
             |> assign(:conn_edit_id, nil)
             |> assign(
               :connections,
               Mapping.list_connections_with_endpoints(socket.assigns.map.id)
             )
             |> put_flash(:info, "Connection updated")}

          {:error, changeset} ->
            {:noreply, assign(socket, :conn_errors, changeset_errors(changeset))}
        end
    end
  end

  def handle_event("delete-connection", %{"id" => id}, socket) do
    case Mapping.get_connection(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Connection not found")}

      conn ->
        {:ok, _} = Mapping.delete_connection(conn)

        {:noreply,
         socket
         |> assign(:connections, Mapping.list_connections_with_endpoints(socket.assigns.map.id))
         |> put_flash(:info, "Connection removed")}
    end
  end

  def handle_event("switch-mask", %{"id" => id}, socket) do
    mask_id = String.to_integer(id)

    case Enum.find(socket.assigns.masks, &(&1.id == mask_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Mask not found")}

      mask ->
        map =
          case Mapping.list_maps_for_mask(mask.id) do
            [] -> elem(Mapping.create_map(%{name: "Home", mask_id: mask.id}), 1)
            [m | _] -> m
          end

        Phoenix.PubSub.unsubscribe(
          Tripwire.PubSub,
          Tripwire.Tracking.map_topic(socket.assigns.map.id)
        )

        Phoenix.PubSub.subscribe(Tripwire.PubSub, Tripwire.Tracking.map_topic(map.id))

        {:noreply,
         socket
         |> assign(:mask, mask)
         |> assign(:map, map)
         |> assign(:maps, Mapping.list_maps_for_mask(mask.id))
         |> assign(:systems, Mapping.list_chain_systems(map))
         |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
         |> assign(:selected_system_id, nil)
         |> assign(:selected_system_name, nil)
         |> assign(:system_suggestions, [])
         |> assign(:signatures, [])
         |> assign(:comments, [])
         |> assign(:flares, [])
         |> assign(:system_stat, nil)
         |> patch_to_preferred(Mapping.list_chain_systems(map))}
    end
  end

  def handle_event("new-map", _params, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      mask = socket.assigns.mask
      count = length(Mapping.list_maps_for_mask(mask.id))
      name = "Chain #{count + 1}"

      case Mapping.create_map(%{name: name, mask_id: mask.id}) do
        {:ok, map} ->
          Phoenix.PubSub.unsubscribe(
            Tripwire.PubSub,
            Tripwire.Tracking.map_topic(socket.assigns.map.id)
          )

          Phoenix.PubSub.subscribe(Tripwire.PubSub, Tripwire.Tracking.map_topic(map.id))

          {:noreply,
           socket
           |> assign(:map, map)
           |> assign(:maps, Mapping.list_maps_for_mask(mask.id))
           |> assign(:systems, [])
           |> assign(:connections, [])
           |> assign(:selected_system_id, nil)
           |> assign(:selected_system_name, nil)
           |> assign(:system_suggestions, [])
           |> assign(:signatures, [])
           |> assign(:comments, [])
           |> assign(:flares, [])
           |> assign(:system_stat, nil)
           |> put_flash(:info, "Created #{name}")}

        {:error, changeset} ->
          {:noreply, flash_changeset_errors(socket, changeset)}
      end
    end
  end

  def handle_event("switch-map", %{"id" => id}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      map_id = String.to_integer(id)

      case Mapping.get_map!(map_id) do
        %{mask_id: mask_id} = map when mask_id == socket.assigns.mask.id ->
          Phoenix.PubSub.unsubscribe(
            Tripwire.PubSub,
            Tripwire.Tracking.map_topic(socket.assigns.map.id)
          )

          Phoenix.PubSub.subscribe(Tripwire.PubSub, Tripwire.Tracking.map_topic(map.id))

          {:noreply,
           socket
           |> assign(:map, map)
           |> assign(:systems, Mapping.list_chain_systems(map))
           |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
           |> assign(:selected_system_id, nil)
           |> assign(:selected_system_name, nil)
           |> assign(:system_suggestions, [])
           |> assign(:signatures, [])
           |> assign(:comments, [])
           |> assign(:flares, [])
           |> assign(:system_stat, nil)
           |> patch_to_preferred(Mapping.list_chain_systems(map))}

        _ ->
          {:noreply, put_flash(socket, :error, "Map not found")}
      end
    end
  rescue
    _ -> {:noreply, put_flash(socket, :error, "Map not found")}
  end

  def handle_event("add-viewing", _params, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      with %{refresh_token: token} when not is_nil(token) <- socket.assigns.character,
           {:ok, access} <- ESI.valid_access_token(socket.assigns.character),
           {:ok, %{"solar_system_id" => solar_system_id}} <-
             ESI.get_character_location(socket.assigns.character.eve_id, access),
           prev = selected_system(socket),
           {:ok, %{system: system}} <-
             Tripwire.Tracking.apply_location_change(
               socket.assigns.map,
               socket.assigns.character.name,
               prev,
               solar_system_id
             ) do
        {:noreply,
         socket
         |> assign(:systems, Mapping.list_chain_systems(socket.assigns.map))
         |> assign(:connections, Mapping.list_connections_with_endpoints(socket.assigns.map.id))
         |> select_system(system.id)
         |> push_patch(to: "/" <> system.name)
         |> put_flash(:info, "Added viewing system #{system.name}")}
      else
        _ -> {:noreply, put_flash(socket, :error, "ESI location unavailable")}
      end
    end
  end

  def handle_event("set-waypoint", _params, socket) do
    with %{solar_system_id: esi_id} <- selected_system_esi(socket),
         {:ok, token} <- ESI.valid_access_token(socket.assigns.character) do
      case ESI.set_waypoint(esi_id, token) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Waypoint set")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Waypoint failed: #{inspect(reason)}")}
      end
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a system first")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "ESI not available")}
    end
  end

  def handle_event("refresh-occupants", _params, socket) do
    {:noreply, refresh_occupants(socket)}
  end

  def handle_event("create-flare", %{"flare" => params}, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        attrs = %{
          color: params["color"] || "red",
          reason: present(params["reason"]),
          life_length: parse_life_length(params["life_length"])
        }

        case Mapping.create_flare(
               system,
               attrs,
               socket.assigns.character,
               socket.assigns.mask && socket.assigns.mask.id
             ) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:flares, Mapping.list_flares(system.id))
             |> put_flash(:info, "Flare set")}

          {:error, changeset} ->
            {:noreply, flash_changeset_errors(socket, changeset)}
        end
    end
  end

  def handle_event("delete-flare", %{"id" => id}, socket) do
    flare = Tripwire.Repo.get!(Tripwire.Mapping.Flare, String.to_integer(id))
    {:ok, _} = Mapping.delete_flare(flare)
    system_id = socket.assigns.selected_system_id

    {:noreply,
     assign(socket, :flares, if(system_id, do: Mapping.list_flares(system_id), else: []))}
  end

  def handle_event("ping", %{"message" => message}, socket) do
    system_name = socket.assigns.selected_system_name || "Unknown"

    case Tripwire.Notifier.ping(system_name, message) do
      :ok ->
        {:noreply, put_flash(socket, :info, "Ping sent")}

      {:error, :no_webhook} ->
        {:noreply, put_flash(socket, :error, "Discord webhook not configured")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Ping failed: #{inspect(reason)}")}
    end
  end

  def handle_event("move-comment", %{"id" => id}, socket) do
    case {Mapping.get_comment!(String.to_integer(id)), selected_system(socket)} do
      {_comment, nil} ->
        {:noreply, put_flash(socket, :error, "Select a destination system first")}

      {comment, system} ->
        case Mapping.move_comment(comment, system.id, socket.assigns.character) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:comments, Mapping.list_comments(system.id))
             |> put_flash(:info, "Note moved")}

          {:error, changeset} ->
            {:noreply, flash_changeset_errors(socket, changeset)}
        end
    end
  end

  def handle_event("log-jump", %{"connection_id" => conn_id, "ship" => ship}, socket) do
    case Mapping.get_connection(conn_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Connection not found")}

      conn ->
        name =
          (socket.assigns.character && socket.assigns.character.name) ||
            "Unknown"

        {:ok, _} =
          Mapping.log_connection_jump(
            conn,
            name,
            socket.assigns.selected_system_id,
            present(ship)
          )

        {:noreply, put_flash(socket, :info, "Jump logged")}
    end
  end

  defp admin?(%{assigns: %{character: %{is_admin: true}}}), do: true
  defp admin?(_), do: false

  defp session_characters(session, current) do
    ids = TripwireWeb.SessionUser.ids(session)

    known =
      ids
      |> Enum.map(&Accounts.get_character_by_eve_id/1)
      |> Enum.reject(&is_nil/1)

    [current | known] |> Enum.reject(&is_nil/1) |> Enum.uniq_by(& &1.id)
  end

  defp replace_character(characters, character) do
    Enum.map(characters, fn
      %{id: id} = other -> if id == character.id, do: character, else: other
    end)
  end

  defp demo?(%{assigns: %{demo?: true}}), do: true
  defp demo?(_), do: false

  defp assign_claim_admin(socket, %{is_admin: false}) do
    claim? = not Accounts.admin_exists?()

    socket
    |> assign(:claim_admin?, claim?)
    |> assign(:claim_admin_modal?, claim?)
  end

  defp assign_claim_admin(socket, _character) do
    socket
    |> assign(:claim_admin?, false)
    |> assign(:claim_admin_modal?, false)
  end

  defp masks_for_admin(socket) do
    if demo?(socket) do
      socket.assigns.masks
    else
      Masks.list_masks_for_character(socket.assigns.character.id)
    end
  end

  defp scoped_mask(socket, id) do
    with {mask_id, ""} <- Integer.parse(to_string(id || "")),
         %{} = mask <-
           Enum.find(socket.assigns.masks, &(&1.id == mask_id)) ||
             Tripwire.Repo.get(Tripwire.Masks.Mask, mask_id) do
      if demo?(socket) and mask.kind != "demo" do
        {:error, :forbidden}
      else
        {:ok, mask}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp scoped_member?(socket, mask, member) do
    if demo?(socket) do
      mask.kind == "demo" and not is_nil(member)
    else
      not is_nil(member)
    end
  end

  defp scoped_create_corp_mask(socket) do
    if demo?(socket) do
      {:error, :forbidden}
    else
      Masks.ensure_corporation_mask(socket.assigns.character)
    end
  end

  defp scoped_upsert_member(%{"eve_id" => eve_id, "name" => name}) do
    with {id, ""} <- Integer.parse(to_string(eve_id || "")),
         trimmed when trimmed != "" <- String.trim(to_string(name || "")) do
      Accounts.upsert_character(%{eve_id: id, name: trimmed})
    else
      _ -> {:error, %Ecto.Changeset{errors: [member: {"is invalid", []}], data: %{}, params: %{}}}
    end
  end

  defp scoped_upsert_member(_), do: {:error, :forbidden}

  defp apply_tree_layout(%{assigns: %{map: map}} = socket, layout) when not is_nil(map) do
    apply_tree_layout_with_home(socket, layout, map)
  end

  defp apply_tree_layout_with_home(%{assigns: assigns} = socket, layout, map) do
    spacing = spacing_factor(assigns[:node_spacing])
    systems = Mapping.list_chain_systems(map)
    connections = Mapping.list_connections_with_endpoints(map.id)
    home_id = home_root_id(systems, map)

    positions = layout_positions(systems, connections, layout, spacing, home_id)

    Enum.each(systems, fn s ->
      pos = positions[s.id]
      {:ok, _} = Mapping.update_system_position(Mapping.get_system!(s.id), pos.x, pos.y)
    end)

    socket
    |> assign(:systems, Mapping.list_chain_systems(map))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
  end

  defp home_root_id(systems, %{home_solar_system_id: solar}) when is_integer(solar) do
    case Enum.find(systems, &(&1.solar_system_id == solar)) do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp home_root_id(_, _), do: nil

  defp normalize_layout("top"), do: "down"
  defp normalize_layout("bottom"), do: "up"
  defp normalize_layout("left"), do: "right"
  defp normalize_layout("right"), do: "left"

  defp layout_positions(systems, connections, "radial", spacing, _home_id),
    do: Mapping.radial_layout(systems, connections, spacing)

  defp layout_positions(systems, connections, layout, spacing, nil),
    do: Mapping.tree_layout(systems, connections, normalize_layout(layout), spacing)

  defp layout_positions(systems, connections, layout, spacing, home_id),
    do:
      Mapping.tree_layout(systems, connections, normalize_layout(layout), spacing,
        root_id: home_id
      )

  defp spacing_factor(nil), do: 1.0
  defp spacing_factor(spacing) when is_number(spacing), do: spacing / 100
  defp spacing_factor(_), do: 1.0

  defp parse_int(value, default, min, max) do
    case Integer.parse(to_string(value || "")) do
      {n, ""} -> n |> max(min) |> min(max)
      _ -> default
    end
  end

  defp provision(socket, character) do
    {:ok, mask} = Masks.ensure_personal_mask(character)
    _ = Masks.add_membership(mask, character)

    _ =
      case Masks.ensure_corporation_mask(character) do
        {:ok, m} -> Masks.add_membership(m, character)
        _ -> :ok
      end

    _ =
      case Masks.ensure_alliance_mask(character) do
        {:ok, m} -> Masks.add_membership(m, character)
        _ -> :ok
      end

    map =
      case Mapping.list_maps_for_mask(mask.id) do
        [] -> elem(Mapping.create_map(%{name: "Home", mask_id: mask.id}), 1)
        [map | _] -> map
      end

    masks = Masks.list_masks_for_character(character.id)
    masks = if Enum.any?(masks, &(&1.id == mask.id)), do: masks, else: [mask | masks]
    _ = ensure_jita_system(map, Mapping.list_systems(map.id))

    socket
    |> assign(:current_user, %{id: character.eve_id, name: character.name})
    |> assign(:character, character)
    |> assign(:characters, [character])
    |> assign(:mask, mask)
    |> assign(:masks, masks)
    |> assign(:map, map)
    |> assign(:maps, Mapping.list_maps_for_mask(mask.id))
    |> assign(:systems, Mapping.list_chain_systems(map))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
    |> apply_tree_layout("top")
    |> assign(:selected_system_id, nil)
    |> assign(:selected_system_name, nil)
    |> assign(:system_suggestions, [])
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> autoselect_first_system()
    |> assign(:stale_ids, [])
    |> assign(:stale_system_id, nil)
    |> assign(:settings_open, false)
    |> assign(:settings_tab, "account")
    |> assign(:map_layout, "top")
    |> assign(:undo, [])
    |> assign(:redo, [])
    |> assign(:demo?, false)
    |> assign_claim_admin(character)
    |> assign(:branding, Accounts.branding())
    |> assign(:sig_modal_open, false)
    |> assign(:sig_edit_id, nil)
    |> assign(:sig_form, %{
      "sig_id" => "",
      "kind" => "signature",
      "site_type" => "unknown",
      "type_name" => "",
      "life_length" => "259200",
      "bookmark" => ""
    })
    |> assign(:sig_errors, [])
    |> assign_topbar_defaults()
    |> assign(:sso_configured?, Tripwire.SSO.configured?())
    |> subscribe_to_map(map.id)
    |> schedule_topbar_load()
    |> schedule_chart_refresh()
  end

  defp apply_inverse(:delete, signature, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system before undoing")}

      system ->
        {:ok, restored} =
          Mapping.create_signature(
            system,
            %{
              sig_id: signature.sig_id,
              kind: signature.kind,
              site_type: signature.site_type,
              type_name: signature.type_name,
              bookmark: signature.bookmark,
              life_length: signature.life_length
            },
            socket.assigns.character
          )

        {:noreply,
         socket
         |> reload_signatures()
         |> push_redo({:delete, restored})}
    end
  end

  defp selected_system(%{assigns: %{selected_system_id: nil}}), do: nil

  defp selected_system(%{assigns: %{selected_system_id: id}}) do
    Mapping.get_system(id)
  end

  defp selected_system_esi(%{assigns: %{selected_system_id: nil}}), do: nil
  defp selected_system_esi(%{assigns: %{selected_system_id: id}}), do: Mapping.get_system(id)

  defp selected_system_name(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{name: name} -> name
      nil -> nil
    end
  end

  defp select_system(socket, system_id) do
    socket =
      socket
      |> assign(:selected_system_id, system_id)
      |> assign(:selected_system_name, selected_system_name(socket.assigns.systems, system_id))
      |> assign(:system_search, "")
      |> assign(:system_suggestions, [])
      |> assign(:signatures, Mapping.list_signatures(system_id))
      |> assign(:comments, Mapping.list_comments(system_id))
      |> assign(:flares, Mapping.list_flares(system_id))
      |> assign(:system_stat, Mapping.get_system_stat(system_id))
      |> assign(:system_info, nil)
      |> assign(:chart_data, empty_chart_data(socket.assigns[:chart_range] || "24h"))
      |> assign(:stale_ids, [])
      |> assign(:stale_system_id, nil)
      |> assign(:undo, [])
      |> assign(:redo, [])
      |> assign(:sys_form, sys_form_for(socket.assigns.systems, system_id))

    schedule_system_detail(socket, system_id)
  end

  defp open_system_modal(socket, system_id) do
    socket
    |> assign(:sys_modal_open, true)
    |> assign(:sys_edit_id, system_id)
    |> assign(:sys_errors, [])
    |> assign(:sys_form, sys_form_for(socket.assigns.systems, system_id))
  end

  defp toggle_favorite(socket) do
    case selected_system(socket) do
      nil ->
        put_flash(socket, :error, "Select a system first")

      system ->
        case Mapping.update_system(system, %{favorite: !system.favorite}) do
          {:ok, _} ->
            assign(socket, :systems, Mapping.list_chain_systems(socket.assigns.map))

          {:error, changeset} ->
            flash_changeset_errors(socket, changeset)
        end
    end
  end

  defp import_connected_favorites(socket) do
    map = socket.assigns.map
    mask = socket.assigns.mask

    if is_nil(map) or is_nil(mask) do
      put_flash(socket, :error, "No chain selected")
    else
      chain_systems = socket.assigns.systems || []
      chain_solar = MapSet.new(chain_systems, & &1.solar_system_id)
      candidates = Mapping.list_favorite_candidates(mask.id, map.id)
      candidates = Enum.reject(candidates, &MapSet.member?(chain_solar, &1.solar_system_id))

      route_fn =
        Application.get_env(:tripwire, :route_fn, fn o, d -> ESI.get_route(o, d) end)

      {added, skipped, socket_systems} =
        Enum.reduce(candidates, {0, 0, chain_systems}, fn cand, {a, s, current} ->
          chain_for_check =
            if current == chain_systems, do: chain_systems, else: Mapping.list_systems(map.id)

          current_solar = MapSet.new(chain_for_check, & &1.solar_system_id)

          case favorite_link_target(mask.id, cand, chain_for_check, current_solar, route_fn) do
            nil ->
              {a, s + 1, current}

            {target, hole_type, jumps} ->
              attrs = %{
                solar_system_id: cand.solar_system_id,
                name: cand.name,
                security: cand.security,
                sys_class: cand.sys_class,
                effect: cand.effect,
                favorite: true,
                x: target.x + 170.0,
                y: target.y + 40.0
              }

              case Mapping.ensure_chain_system(map, attrs) do
                {:ok, fresh, _} ->
                  {:ok, _, _} =
                    Mapping.upsert_connection(map.id, fresh.id, target.id, %{
                      hole_type: hole_type,
                      jumps: jumps
                    })

                  {a + 1, s, current ++ [fresh]}

                _ ->
                  {a, s + 1, current}
              end
          end
        end)

      _ = socket_systems

      socket =
        socket
        |> assign(:systems, Mapping.list_chain_systems(map))
        |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
        |> apply_tree_layout(socket.assigns.map_layout || "top")

      {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map)

      socket =
        socket
        |> push_event("reset-pan", %{x: x, y: y})

      cond do
        added == 0 and skipped == 0 ->
          put_flash(socket, :info, "No favorited systems to add")

        added == 0 ->
          put_flash(
            socket,
            :info,
            "No favorited systems connect to this chain (#{skipped} skipped)"
          )

        true ->
          put_flash(
            socket,
            :info,
            "Added #{added} favorited system(s)#{if skipped > 0, do: " (#{skipped} skipped, no route)"}"
          )
      end
    end
  end

  defp favorite_link_target(mask_id, cand, chain_systems, current_solar, route_fn) do
    case Mapping.wormhole_link_target(mask_id, cand.solar_system_id, chain_systems) do
      {target, hole_type} ->
        {target, hole_type, 1}

      nil ->
        case kspace_link_target(cand, chain_systems, current_solar, route_fn) do
          nil -> nil
          {target, jumps} -> {target, nil, jumps}
        end
    end
  end

  defp kspace_link_target(cand, _chain_systems, _current_solar, _route_fn)
       when not is_integer(cand.solar_system_id) or cand.solar_system_id >= 31_000_000,
       do: nil

  defp kspace_link_target(cand, chain_systems, _current_solar, route_fn) do
    kspace_chain =
      Enum.filter(
        chain_systems,
        &(is_integer(&1.solar_system_id) and &1.solar_system_id < 31_000_000)
      )

    Enum.find_value(kspace_chain, fn target ->
      case route_fn.(cand.solar_system_id, target.solar_system_id) do
        {:ok, route} when is_list(route) and length(route) > 0 ->
          jumps = max(length(route) - 1, 1)
          {target, jumps}

        _ ->
          false
      end
    end)
  end

  defp save_chain_settings(socket, params) do
    map = socket.assigns.map
    home_input = params["home"] |> to_string() |> String.trim()
    include_thera = params["include_thera"] in ["true", "on", "1"]
    show_all = params["show_all"] in ["true", "on", "1"]

    with {:ok, home_solar, home_name} <- resolve_home_input(socket, home_input),
         {:ok, updated} <-
           Mapping.update_map(map, %{
             home_solar_system_id: home_solar,
             home_name: home_name,
             include_thera: include_thera,
             show_all: show_all
           }) do
      socket = assign(socket, :map, updated)

      socket =
        case home_solar do
          nil -> socket
          solar -> ensure_home_node(socket, updated, solar, home_name)
        end

      socket =
        if include_thera do
          ensure_thera_node(socket, updated)
        else
          socket
        end

      socket =
        socket
        |> apply_tree_layout_with_home(socket.assigns.map_layout || "top", updated)
        |> assign(:chain_modal_open, false)
        |> assign(:chain_errors, [])
        |> assign(:maps, Mapping.list_maps_for_mask(socket.assigns.mask.id))

      {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map)

      socket
      |> push_event("reset-pan", %{x: x, y: y})
      |> put_flash(:info, "Chain settings saved")
    else
      {:error, message} when is_binary(message) ->
        assign(socket, :chain_errors, [message])

      {:error, _} ->
        assign(socket, :chain_errors, ["Could not save chain settings"])
    end
  end

  defp resolve_home_input(_socket, ""), do: {:ok, nil, nil}

  defp resolve_home_input(socket, input) do
    case Integer.parse(input) do
      {solar, ""} ->
        case system_name_for_solar(socket, solar) do
          nil ->
            case ESI.get_system(solar) do
              {:ok, %{"name" => name} = body} ->
                {:ok, solar, Map.get(body, "name", name)}

              _ ->
                {:error, "Home system not found: #{input}"}
            end

          name ->
            {:ok, solar, name}
        end

      _ ->
        existing =
          Enum.find(
            socket.assigns.systems || [],
            &(String.downcase(&1.name) == String.downcase(input))
          )

        cond do
          existing ->
            {:ok, existing.solar_system_id, existing.name}

          true ->
            case ESI.resolve_system_id(input) do
              {:ok, solar} -> {:ok, solar, input}
              :error -> {:error, "Home system not found: #{input}"}
            end
        end
    end
  end

  defp system_name_for_solar(socket, solar) do
    mask_maps = Mapping.list_maps_for_mask(socket.assigns.mask.id)
    map_ids = Enum.map(mask_maps, & &1.id)

    Enum.find_value(map_ids, fn _ -> nil end)

    found =
      Enum.find(socket.assigns.systems || [], &(&1.solar_system_id == solar))

    if found, do: found.name, else: nil
  end

  defp ensure_home_node(socket, map, solar, name) do
    resolved_name = name || "System #{solar}"

    attrs =
      case ESI.get_system(solar) do
        {:ok, body} when is_map(body) ->
          %{
            solar_system_id: solar,
            name: body["name"] || resolved_name,
            security: body["security_status"]
          }

        _ ->
          %{solar_system_id: solar, name: resolved_name}
      end

    case Mapping.ensure_chain_system(map, attrs) do
      {:ok, _system, _} -> socket
      _ -> socket
    end
  end

  defp ensure_thera_node(socket, map) do
    solar = Mapping.thera_solar_system_id()
    existing? = Enum.any?(socket.assigns.systems || [], &(&1.solar_system_id == solar))

    if existing? do
      socket
    else
      attrs =
        case ESI.get_system(solar) do
          {:ok, body} when is_map(body) ->
            %{
              solar_system_id: solar,
              name: body["name"] || Mapping.thera_name(),
              security: body["security_status"]
            }

          _ ->
            %{solar_system_id: solar, name: Mapping.thera_name()}
        end

      case Mapping.ensure_chain_system(map, attrs) do
        {:ok, thera, true} ->
          link_target =
            (socket.assigns.systems || []) |> List.first()

          if link_target do
            {:ok, _, _} = Mapping.upsert_connection(map.id, thera.id, link_target.id, %{})
          end

          socket

        _ ->
          socket
      end
    end
  end

  defp maybe_match_flash(socket, 0, updated),
    do: put_flash(socket, :info, "All #{updated} signatures match")

  defp maybe_match_flash(socket, _added, _updated), do: socket

  defp sync_map_hole_type(socket, system, old_code, new_code) do
    case new_code do
      nil ->
        socket

      _code ->
        :ok =
          Mapping.sync_signature_to_connections(
            socket.assigns.map,
            system,
            old_code,
            new_code
          )

        Tripwire.Tracking.broadcast_map_update(socket.assigns.map.id)

        assign(
          socket,
          :connections,
          Mapping.list_connections_with_endpoints(socket.assigns.map.id)
        )
    end
  end

  defp sig_hole_code(%{site_type: "wormhole", type_name: name}), do: SigParser.wormhole_code(name)
  defp sig_hole_code(_), do: nil

  defp suggest_systems(systems, query) when is_list(systems) do
    q = query |> to_string() |> String.trim() |> String.downcase()

    if q == "" do
      []
    else
      local =
        systems
        |> Enum.reject(& &1.unknown)
        |> Enum.filter(fn s ->
          String.contains?(String.downcase(s.name || ""), q) ||
            String.contains?(String.downcase(s.alias || ""), q)
        end)

      taken = Enum.map(local, & &1.solar_system_id) |> MapSet.new()

      remote =
        Systems.Catalog.search(q, 8)
        |> Enum.reject(&MapSet.member?(taken, &1.solar_system_id))
        |> Enum.map(&Map.put(&1, :id, nil))

      Enum.take(local ++ remote, 8)
    end
  end

  defp suggest_systems(_, _), do: []

  defp sys_form_for(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{alias: alias_, sys_class: sys_class, effect: effect} ->
        %{"alias" => alias_ || "", "sys_class" => sys_class || "", "effect" => effect || ""}

      _ ->
        %{"alias" => "", "sys_class" => "", "effect" => ""}
    end
  end

  defp reload_signatures(socket) do
    case socket.assigns.selected_system_id do
      nil -> socket
      id -> assign(socket, :signatures, Mapping.list_signatures(id))
    end
  end

  defp reload_map_from_sync(socket, dropped, linked, hidden) do
    if dropped + linked + hidden == 0 do
      socket
    else
      socket =
        if dropped + hidden > 0 do
          socket = apply_tree_layout(socket, socket.assigns.map_layout || "top")
          {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map)
          push_event(socket, "reset-pan", %{x: x, y: y})
        else
          reload_map(socket)
        end

      sync_flash(socket, dropped, linked, hidden)
    end
  end

  defp reload_map(socket) do
    map = socket.assigns.map

    socket
    |> assign(:systems, Mapping.list_chain_systems(map))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
  end

  defp sync_flash(socket, dropped, linked, hidden) do
    parts =
      [{dropped, "dropped"}, {linked, "linked"}, {hidden, "hid"}]
      |> Enum.map(fn {count, verb} -> "#{count} #{verb}" end)
      |> Enum.join(", ")

    put_flash(socket, :info, "Map updated: #{parts}")
  end

  defp stale_flash(deleted, dropped, linked, hidden) do
    base = "Deleted #{length(deleted)} missing signatures"

    if dropped + linked + hidden == 0 do
      base
    else
      parts =
        [{dropped, "dropped"}, {linked, "linked"}, {hidden, "hid"}]
        |> Enum.map(fn {count, verb} -> "#{count} #{verb}" end)
        |> Enum.join(", ")

      base <> ", map updated: " <> parts
    end
  end

  defp preferred_system(systems) do
    known = Enum.reject(systems, & &1.unknown)

    Enum.find(known, &(String.downcase(&1.name || "") == "jita")) || List.first(known)
  end

  defp ensure_jita_system(_map, systems) when systems != [] do
    systems
  end

  defp ensure_jita_system(map, []) do
    case Mapping.add_system_to_map(map, %{
           solar_system_id: 30_000_142,
           name: "Jita",
           security: 0.9,
           x: 880.0,
           y: 380.0
         }) do
      {:ok, _} -> Mapping.list_systems(map.id)
      _ -> []
    end
  end

  defp push_system_patch(socket, name) do
    socket
    |> assign(:system_search, "")
    |> assign(:system_suggestions, [])
    |> push_patch(to: "/" <> name)
  end

  defp select_system_and_patch(socket, system_id) do
    socket = select_system(socket, system_id)

    case socket.assigns[:selected_system_name] do
      nil -> socket
      name -> push_patch(socket, to: "/" <> name)
    end
  end

  defp patch_to_preferred(socket, systems) do
    case preferred_system(systems) do
      %{id: id, name: name} ->
        socket |> select_system(id) |> push_patch(to: "/" <> name)

      nil ->
        socket
    end
  end

  defp autoselect_first_system(%{assigns: %{selected_system_id: nil, systems: systems}} = socket)
       when is_list(systems) and systems != [] do
    case preferred_system(systems) do
      %{id: id, name: name} ->
        socket =
          socket
          |> assign(:selected_system_id, id)
          |> assign(:selected_system_name, name)
          |> assign(:signatures, Mapping.list_signatures(id))
          |> assign(:comments, Mapping.list_comments(id))

        schedule_system_detail(socket, id)

      nil ->
        socket
    end
  end

  defp autoselect_first_system(socket), do: socket

  defp subscribe_to_map(socket, map_id) do
    Phoenix.PubSub.subscribe(Tripwire.PubSub, Tripwire.Tracking.map_topic(map_id))
    socket
  end

  defp assign_topbar_defaults(socket) do
    socket
    |> assign(:tq_online, false)
    |> assign(:tq_players, nil)
    |> assign(:current_system_name, nil)
    |> assign(:character_online, nil)
    |> assign(:ship_type_id, nil)
    |> assign(:presences, %{})
    |> assign(:topbar_now, DateTime.utc_now())
    |> assign(:grid_locked, true)
    |> assign(:system_search, "")
    |> assign(:system_suggestions, [])
    |> assign(:show_row_guides, false)
    |> assign(:show_row_counts, false)
    |> assign(:angled_lines, true)
    |> assign(:show_jump_lines, true)
    |> assign(:show_line_glow, true)
    |> assign(:show_node_badges, true)
    |> assign(:widget_system, true)
    |> assign(:widget_notes, true)
    |> assign(:widget_signatures, true)
    |> assign(:widget_map, true)
    |> assign(:line_weight, 2)
    |> assign(:node_spacing, 100)
    |> assign(:map_scale, 100)
    |> assign(:map_background, nil)
    |> assign(:sso_configured?, false)
    |> assign(:conn_modal_open, false)
    |> assign(:conn_edit_id, nil)
    |> assign(:conn_form, %{
      "hole_type" => "",
      "mass_status" => "stable",
      "time_status" => "stable",
      "ship_size" => ""
    })
    |> assign(:conn_errors, [])
    |> assign(:sys_form, %{"alias" => "", "sys_class" => "", "effect" => ""})
    |> assign(:sys_modal_open, false)
    |> assign(:sys_edit_id, nil)
    |> assign(:sys_errors, [])
    |> assign(:occupants, [])
    |> assign(:flares, [])
    |> assign(:system_stat, nil)
    |> assign(:system_info, nil)
    |> assign(:chart_range, "24h")
    |> assign(:chart_hidden, MapSet.new())
    |> assign(:chart_data, %{labels: [], jumps: [], ship_kills: [], pod_kills: [], npc_kills: []})
    |> assign(:map_locked, false)
    |> assign(:chain_modal_open, false)
    |> assign(:chain_form, %{"home" => "", "include_thera" => false, "show_all" => false})
    |> assign(:chain_errors, [])
  end

  defp toggle_visibility(socket, id, attrs_fn) do
    with {char_id, ""} <- Integer.parse(to_string(id)),
         %{} = character <- Accounts.get_character(char_id),
         {:ok, updated} <- Accounts.update_character(character, attrs_fn.(character)) do
      characters =
        Enum.map(socket.assigns.characters, fn c ->
          if c.id == updated.id, do: updated, else: c
        end)

      character =
        if socket.assigns.character && socket.assigns.character.id == updated.id,
          do: updated,
          else: socket.assigns.character

      {:noreply,
       socket
       |> assign(:character, character)
       |> assign(:characters, characters)
       |> refresh_occupants()
       |> put_flash(:info, visibility_flash(updated))}
    else
      _ -> {:noreply, put_flash(socket, :error, "Character not found")}
    end
  end

  defp visibility_flash(%{name: name, ship_on_chain: false, character_on_chain: false}),
    do: "#{name}'s character and ship are hidden on chain"

  defp visibility_flash(%{name: name, character_on_chain: false}),
    do: "#{name} is hidden on chain"

  defp visibility_flash(%{name: name, ship_on_chain: false}),
    do: "#{name}'s ship is hidden on chain"

  defp visibility_flash(%{name: name}), do: "#{name} is visible on chain"

  defp schedule_topbar_load(socket) do
    if connected?(socket), do: send(self(), :load_topbar)
    socket
  end

  defp schedule_topbar_refresh do
    Process.send_after(self(), :refresh_topbar, @topbar_refresh_ms)
  end

  defp schedule_chart_refresh(socket \\ nil) do
    if is_nil(socket) || connected?(socket) do
      Process.send_after(self(), :refresh_chart, @chart_refresh_ms)
    end

    socket
  end

  defp topbar_esi_enabled? do
    Application.get_env(:tripwire, :topbar_esi, true)
  end

  defp fetch_topbar_data(character, characters) do
    {tq_online, tq_players} =
      case ESI.get_status() do
        {:ok, %{"players" => players}} -> {true, players}
        _ -> {false, nil}
      end

    presences = fetch_presences(characters)
    presence = Map.get(presences, character.eve_id, empty_presence())

    %{
      tq_online: tq_online,
      tq_players: tq_players,
      current_system_name: presence.system_name,
      character_online: presence.online,
      ship_type_id: presence.ship_type_id,
      presences: presences,
      now: DateTime.utc_now()
    }
  end

  defp fetch_presences(characters) do
    characters
    |> Task.async_stream(
      fn character -> {character.eve_id, fetch_character_presence(character)} end,
      max_concurrency: 4,
      timeout: 20_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {eve_id, presence}}, acc -> Map.put(acc, eve_id, presence)
      _other, acc -> acc
    end)
  end

  defp empty_presence,
    do: %{system_name: nil, online: nil, ship_name: nil, ship_type_id: nil, ship_type_name: nil}

  defp fetch_character_presence(nil), do: empty_presence()

  defp fetch_character_presence(%{eve_id: @demo_character_eve_id}) do
    %{
      system_name: "J150321",
      online: true,
      ship_name: @demo_ship_name,
      ship_type_id: @demo_ship_type_id,
      ship_type_name: @demo_ship_name
    }
  end

  defp fetch_character_presence(%{refresh_token: nil}), do: empty_presence()

  defp fetch_character_presence(character) do
    case ESI.valid_access_token(character) do
      {:ok, token} ->
        {ship_name, ship_type_id, ship_type_name} = fetch_character_ship(character.eve_id, token)

        %{
          system_name: fetch_character_system(character.eve_id, token),
          online: fetch_character_online(character.eve_id, token),
          ship_name: ship_name,
          ship_type_id: ship_type_id,
          ship_type_name: ship_type_name
        }

      {:error, _reason} ->
        empty_presence()
    end
  rescue
    exception ->
      Tripwire.Log.emit(:warning, %{
        event: "character_presence_failed",
        eve_id: character.eve_id,
        error: Exception.message(exception)
      })

      empty_presence()
  end

  defp fetch_character_online(eve_id, token) do
    case ESI.get_character_online(eve_id, token) do
      {:ok, %{"online" => online}} -> online
      _ -> nil
    end
  end

  defp fetch_character_ship(eve_id, token) do
    case ESI.get_character_ship(eve_id, token) do
      {:ok, %{"ship_type_id" => type_id} = ship} ->
        {ship["ship_name"], type_id, fetch_type_name(type_id)}

      _ ->
        {nil, nil, nil}
    end
  end

  defp fetch_type_name(type_id) when is_integer(type_id) do
    case ESI.get_type(type_id) do
      {:ok, %{"name" => name}} -> name
      _ -> nil
    end
  end

  defp fetch_type_name(_type_id), do: nil

  defp fetch_character_system(eve_id, token) do
    with {:ok, %{"solar_system_id" => system_id}} <- ESI.get_character_location(eve_id, token),
         {:ok, %{"name" => name}} <- ESI.get_system(system_id) do
      name
    else
      _ -> nil
    end
  end

  defp push_undo(socket, op), do: update(socket, :undo, &[op | &1])

  defp schedule_system_detail(socket, system_id) do
    if connected?(socket) do
      pid = self()
      system = Enum.find(socket.assigns.systems, &(&1.id == system_id))
      range = socket.assigns[:chart_range] || "24h"

      Task.start(fn ->
        info =
          case system do
            nil -> {:error, :not_found}
            s -> Tripwire.Systems.fetch_info(s)
          end

        send(pid, {:system_info_loaded, system_id, info})
      end)

      Task.start(fn ->
        send(pid, {:chart_data_loaded, system_id, range, chart_data_for(system, range)})
      end)
    end

    socket
  end

  defp schedule_chart_reload(socket) do
    if connected?(socket) do
      pid = self()
      system_id = socket.assigns.selected_system_id
      system = Enum.find(socket.assigns.systems, &(&1.id == system_id))
      range = socket.assigns[:chart_range] || "24h"

      Task.start(fn ->
        send(pid, {:chart_data_loaded, system_id, range, chart_data_for(system, range)})
      end)
    end

    socket
  end

  defp info_to_assign({:ok, info}), do: info
  defp info_to_assign({:error, :wormhole}), do: %{wormhole: true}
  defp info_to_assign(_), do: nil

  defp empty_chart_data(range) do
    labels = range_labels(range)
    zeros = List.duplicate(0, length(labels))
    %{labels: labels, jumps: zeros, ship_kills: zeros, pod_kills: zeros, npc_kills: zeros}
  end

  defp chart_data_for(nil, range), do: empty_chart_data(range)

  defp chart_data_for(system, range) do
    labels = range_labels(range)
    width = bucket_width_hours(range)
    now = DateTime.utc_now()

    {ship_kills, pod_kills} =
      if Tripwire.Systems.esi_resolvable?(system) do
        since = DateTime.add(now, -length(labels) * width * 3600, :second)

        case Tripwire.ZKill.kill_history(system.solar_system_id, since: since) do
          {:ok, kills} -> Tripwire.ZKill.bucket(kills, now, length(labels), width)
          {:error, _} -> {List.duplicate(0, length(labels)), List.duplicate(0, length(labels))}
        end
      else
        {List.duplicate(0, length(labels)), List.duplicate(0, length(labels))}
      end

    {jumps, npc_kills} =
      if Tripwire.Systems.esi_resolvable?(system) do
        activity = Tripwire.ESI.system_activity(system.solar_system_id)
        tip = fn value -> List.duplicate(0, length(labels) - 1) ++ [value] end
        {tip.(activity.jumps), tip.(activity.npc_kills)}
      else
        {List.duplicate(0, length(labels)), List.duplicate(0, length(labels))}
      end

    %{
      labels: labels,
      jumps: jumps,
      ship_kills: ship_kills,
      pod_kills: pod_kills,
      npc_kills: npc_kills
    }
  end

  defp bucket_width_hours("48h"), do: 6
  defp bucket_width_hours("week"), do: 24
  defp bucket_width_hours(_), do: 3

  defp range_labels("48h"), do: ["48h", "42h", "36h", "30h", "24h", "18h", "12h", "6h", "0h"]
  defp range_labels("week"), do: ["7d", "6d", "5d", "4d", "3d", "2d", "1d", "0d"]
  defp range_labels(_), do: ["24h", "21h", "18h", "15h", "12h", "9h", "6h", "3h", "0h"]

  defp chart_payload(data, hidden) do
    data = data || %{labels: [], jumps: [], ship_kills: [], pod_kills: [], npc_kills: []}

    %{
      "labels" => data.labels,
      "jumps" => data.jumps,
      "ship_kills" => data.ship_kills,
      "pod_kills" => data.pod_kills,
      "npc_kills" => data.npc_kills,
      "hidden" => MapSet.to_list(hidden)
    }
  end

  defp pop_undo(socket) do
    case socket.assigns.undo do
      [top | rest] -> {top, assign(socket, :undo, rest)}
      [] -> {nil, socket}
    end
  end

  defp push_redo(socket, op), do: update(socket, :redo, &[op | &1])

  defp redo_op(socket) do
    case socket.assigns.redo do
      [top | rest] -> {top, assign(socket, :redo, rest)}
      [] -> {nil, socket}
    end
  end

  defp apply_redo({:delete, signature}, socket) do
    _ = Mapping.delete_signature(signature, socket.assigns.character)
    socket |> reload_signatures() |> update(:undo, &[{:delete, signature} | &1])
  end

  defp flash_changeset_errors(socket, changeset) do
    message =
      changeset.errors
      |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
      |> Enum.join(", ")

    put_flash(socket, :error, message)
  end

  defp changeset_errors(changeset) do
    Enum.map(changeset.errors, fn {field, {message, _}} -> "#{field} #{message}" end)
  end

  defp life_options do
    [
      {"24 hours", 86_400},
      {"48 hours", 172_800},
      {"72 hours", 259_200},
      {"7 days", 604_800}
    ]
  end

  defp sig_attrs(params) do
    type_name = present(params["type_name"])

    %{
      sig_id: params["sig_id"],
      kind: params["kind"] || "signature",
      site_type: SigParser.infer_site_type(params["site_type"] || "unknown", type_name),
      type_name: type_name,
      bookmark: present(params["bookmark"]),
      life_length: parse_life_length(params["life_length"])
    }
  end

  defp parse_life_length(nil), do: 259_200
  defp parse_life_length(""), do: 259_200
  defp parse_life_length(value) when is_integer(value), do: value

  defp parse_life_length(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> 259_200
    end
  end

  defp present(nil), do: nil
  defp present(""), do: nil

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(value), do: value
end
