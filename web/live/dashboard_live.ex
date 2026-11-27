defmodule ZtripwireWeb.DashboardLive do
  use ZtripwireWeb, :live_view

  alias Ztripwire.Accounts
  alias Ztripwire.Data
  alias Ztripwire.Demo
  alias Ztripwire.ESI
  alias Ztripwire.Layouts
  alias Ztripwire.Mapping
  alias Ztripwire.Masks
  alias Ztripwire.Settings
  alias Ztripwire.Signatures, as: SigParser
  alias Ztripwire.Systems
  alias Ztripwire.Tracking
  alias Ztripwire.Wormholes

  import ZtripwireWeb.FormHelpers, only: [changeset_errors: 1, changeset_message: 1]

  @demo_character_eve_id Ztripwire.Demo.character_eve_id()
  @demo_ship_name Ztripwire.Demo.ship_name()
  @demo_ship_type_id Ztripwire.Demo.ship_type_id()
  @topbar_refresh_ms 60_000
  @chart_refresh_ms 60_000
  @chart_ranges ~w(24h 48h week)
  @settings_tabs ~w(account map widgets layouts statistics themes admin)
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
        {:ok,
         socket
         |> provision(character, session)
         |> assign_characters(session)
         |> ensure_character_pollers()}

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
    case ZtripwireWeb.SessionUser.get(session) do
      %{id: eve_id} ->
        case Accounts.get_character_by_eve_id(eve_id) do
          nil -> :expired
          character -> {:ok, character}
        end

      nil ->
        :anonymous
    end
  end

  defp assign_characters(%{assigns: %{demo?: true}} = socket, _session), do: socket

  defp assign_characters(socket, session) do
    assign(socket, :characters, session_characters(session, socket.assigns.character))
  end

  defp ensure_character_pollers(%{assigns: %{demo?: true}} = socket), do: socket

  defp ensure_character_pollers(socket) do
    socket.assigns[:characters]
    |> List.wrap()
    |> Enum.reject(&(&1.eve_id == @demo_character_eve_id))
    |> Enum.reject(&is_nil(&1.refresh_token))
    |> Enum.each(&Tracking.ensure_poller/1)

    socket
  end

  defp refresh_occupants(socket) do
    presences = socket.assigns[:presences] || %{}

    occupants =
      case socket.assigns[:map] do
        nil ->
          []

        map ->
          Data.occupants(data(socket), map.id, socket.assigns[:mask])
          |> Enum.filter(&mask_member?(&1, socket.assigns[:mask]))
          |> Enum.map(&put_ship_type_name(&1, presences))
      end

    assign(socket, :occupants, occupants)
  end

  defp put_ship_type_name(occupant, presences) do
    case Map.get(presences, occupant.eve_id) do
      %{ship_type_name: name} when is_binary(name) and name != "" ->
        Map.put(occupant, :ship_type_name, name)

      _ ->
        occupant
    end
  end

  defp mask_member?(occupant, %{kind: "corporation", eve_owner_id: corp_id})
       when is_integer(corp_id),
       do: occupant.corporation_id == corp_id

  defp mask_member?(occupant, %{kind: "alliance", eve_owner_id: alliance_id})
       when is_integer(alliance_id),
       do: occupant.alliance_id == alliance_id

  defp mask_member?(_occupant, _mask), do: true

  defp demo_mask_members(%{demo?: true, mask: mask, demo_state: state}) do
    %{mask.id => Demo.members(state, mask.id)}
  end

  defp demo_mask_members(_assigns), do: nil

  defp demo_character_stats(%{demo?: true, demo_state: state}),
    do: Demo.character_statistics(state)

  defp demo_character_stats(_assigns), do: nil

  defp data(%{assigns: %{demo?: true, demo_state: state}}), do: state
  defp data(_socket), do: :db

  defp put_data(socket, :db), do: socket
  defp put_data(socket, %Ztripwire.Demo.State{} = state), do: assign(socket, :demo_state, state)

  defp assign_demo_presence(socket) do
    presence = fetch_character_presence(socket.assigns.character)
    presences = Map.new(socket.assigns.characters, &{&1.eve_id, presence})

    socket
    |> assign(:current_system_name, presence.system_name)
    |> assign(:character_online, presence.online)
    |> assign(:presences, presences)
  end

  defp mount_demo(socket) do
    state = Demo.fixture()
    character = state.character
    mask = state.mask
    map = hd(state.maps)
    settings = Demo.settings_assigns(state)

    socket
    |> assign(:demo?, true)
    |> assign(:demo_state, state)
    |> assign(:current_user, nil)
    |> assign(:character, character)
    |> assign(:characters, [character])
    |> assign(:mask, mask)
    |> assign(:masks, [mask])
    |> assign(:admin_masks, [mask])
    |> assign(:map, map)
    |> assign(:maps, Demo.list_maps_for_mask(state, mask.id))
    |> assign_topbar_defaults()
    |> assign(settings)
    |> assign_layouts()
    |> assign(:systems, Demo.list_chain_systems(state, map, settings.show_all))
    |> assign(:connections, Demo.list_connections_with_endpoints(state, map.id))
    |> refresh_occupants()
    |> apply_tree_layout(settings.map_layout)
    |> assign_blank_view()
    |> assign(:claim_admin?, false)
    |> assign(:claim_admin_modal?, false)
    |> assign(:branding, nil)
    |> assign(:tracking?, true)
    |> assign_demo_presence()
    |> assign(:sso_configured?, Ztripwire.SSO.configured?())
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
            socket = expand_hidden_selection(socket, id)

            if socket.assigns[:selected_system_id] == id do
              {:noreply, socket}
            else
              {:noreply, select_system(socket, id)}
            end

          nil ->
            select_named_offchain(socket, system_name, systems)
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

  def handle_info({:toggle_collapse, system_id}, socket) do
    {:noreply, toggle_collapse(socket, system_id)}
  end

  def handle_info(:expand_all, socket) do
    {:noreply, put_collapsed_ids(socket, Elixir.MapSet.new())}
  end

  def handle_info({:select_gate_system, solar_system_id}, socket) do
    {:noreply, select_gate_system(socket, solar_system_id)}
  end

  def handle_info({:open_node_signature, system_id, signature_id}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply,
       socket |> select_system_and_patch(system_id) |> put_flash(:error, "Map is locked")}
    else
      socket = select_system_and_patch(socket, system_id)

      socket =
        case signature_id && Data.get_signature(data(socket), signature_id) do
          nil -> open_signature_add(socket)
          signature -> open_signature_edit(socket, signature)
        end

      {:noreply, socket}
    end
  end

  def handle_info(:toggle_favorite, socket) do
    {:noreply, toggle_favorite(socket)}
  end

  def handle_info({:systems_updated, map_id}, %{assigns: %{map: map}} = socket)
      when not is_nil(map) and map_id == map.id do
    {:noreply,
     socket
     |> assign(:systems, chain_systems(socket, map))
     |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map_id))}
  end

  def handle_info({:comments_updated, system_id}, socket) do
    socket =
      if socket.assigns.selected_system_id == system_id do
        assign(socket, :comments, Data.list_comments(data(socket), system_id))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:demo_toggle_tracker, socket) do
    tracking? = !Map.get(socket.assigns, :tracking?, true)
    {_result, data} = Demo.set_tracking(data(socket), tracking?)

    {:noreply, socket |> put_data(data) |> assign(:tracking?, tracking?) |> refresh_occupants()}
  end

  def handle_info({:demo_comment_create, system_id, body}, socket) do
    case Data.get_system(data(socket), system_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        case Data.create_comment(data(socket), system, %{body: body}, socket.assigns.character) do
          {{:ok, _}, data} ->
            {:noreply,
             socket
             |> put_data(data)
             |> assign(:comments, Data.list_comments(data(socket), system_id))}

          {{:error, changeset}, data} ->
            {:noreply, socket |> put_data(data) |> flash_changeset_errors(changeset)}
        end
    end
  end

  def handle_info({:demo_comment_update, id, body}, socket) do
    case Data.get_comment!(data(socket), id) do
      nil ->
        {:noreply, socket}

      comment ->
        case Data.update_comment(data(socket), comment, %{body: body}, socket.assigns.character) do
          {{:ok, updated}, data} ->
            {:noreply,
             socket
             |> put_data(data)
             |> assign(:comments, Data.list_comments(data(socket), updated.map_system_id))}

          {{:error, changeset}, data} ->
            {:noreply, socket |> put_data(data) |> flash_changeset_errors(changeset)}
        end
    end
  end

  def handle_info({:demo_comment_delete, id}, socket) do
    case Data.get_comment!(data(socket), id) do
      nil ->
        {:noreply, socket}

      comment ->
        {{:ok, _}, data} = Data.delete_comment(data(socket), comment, socket.assigns.character)

        {:noreply,
         socket
         |> put_data(data)
         |> assign(:comments, Data.list_comments(data(socket), comment.map_system_id))}
    end
  end

  def handle_info({:system_changed, %{character: name, system: system}}, socket) do
    current_name = socket.assigns.character && socket.assigns.character.name

    socket =
      if current_name == name do
        assign(socket, :current_system_name, system.name)
      else
        socket
      end

    {:noreply, refresh_occupants(socket)}
  end

  def handle_info(:load_topbar, socket) do
    schedule_topbar_refresh()
    {:noreply, socket |> request_topbar_data() |> refresh_occupants()}
  end

  def handle_info(:refresh_topbar, socket) do
    schedule_topbar_refresh()
    {:noreply, socket |> request_topbar_data() |> refresh_occupants()}
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
     |> assign(:presences, data.presences)
     |> assign(:topbar_now, data.now)
     |> refresh_occupants()}
  end

  def handle_info({:system_info_loaded, solar_system_id, info}, socket) do
    if chart_solar(socket.assigns[:chart_system]) == solar_system_id do
      {:noreply, assign(socket, :system_info, info_to_assign(info))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:chart_data_loaded, solar_system_id, range, data}, socket) do
    if chart_solar(socket.assigns[:chart_system]) == solar_system_id and
         socket.assigns.chart_range == range do
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

    if connected?(socket) && socket.assigns[:chart_system] do
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

  def handle_info(:open_map_modal, socket),
    do: handle_event("open-map-modal", %{}, socket)

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle-settings", _params, socket) do
    {:noreply, update(socket, :settings_open, &(!&1))}
  end

  def handle_event("toggle-grid-lock", _params, socket) do
    {:noreply, put_setting(socket, :grid_locked, !socket.assigns.grid_locked)}
  end

  def handle_event("toggle-widget", %{"widget" => widget}, socket) do
    case @widgets do
      %{^widget => key} ->
        socket =
          socket
          |> put_setting(key, !socket.assigns[key])
          |> clear_active_layout()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("apply-layout", %{"id" => id}, socket) do
    case Data.get_layout(data(socket), id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Layout not found")}

      layout ->
        socket = save_arrangement(socket, layout.widgets, layout.id)

        socket =
          socket
          |> assign(:active_layout, layout.id)
          |> assign_widget_layout(layout.widgets)
          |> push_event("layout-apply", %{widgets: layout.widgets})

        {:noreply, put_flash(socket, :info, "Applied #{layout.name}")}
    end
  end

  def handle_event("apply-layout", _params, socket), do: {:noreply, socket}

  def handle_event("save-layout", %{"name" => name}, socket) do
    name = name |> to_string() |> String.trim()

    if name == "" do
      {:noreply, assign(socket, :layout_errors, ["Layout name is required"])}
    else
      socket = socket |> assign(:layout_name, name) |> assign(:layout_errors, [])
      {:noreply, push_event(socket, "layout-capture", %{})}
    end
  end

  def handle_event("save-layout", _params, socket) do
    {:noreply, assign(socket, :layout_errors, ["Layout name is required"])}
  end

  def handle_event("layout-captured", %{"widgets" => widgets}, socket) do
    widgets = Layouts.with_visibility(widgets, socket.assigns)

    case Data.save_layout(data(socket), socket.assigns[:layout_name], widgets) do
      {{:ok, layout}, data} ->
        socket =
          socket
          |> put_data(data)
          |> save_arrangement(widgets, "saved:#{layout.id}")
          |> assign(:layouts, Data.list_layouts(data))
          |> assign(:active_layout, "saved:#{layout.id}")
          |> assign(:layout_name, "")
          |> assign(:layout_errors, [])

        {:noreply, put_flash(socket, :info, "Saved #{layout.name}")}

      {{:error, changeset}, data} ->
        {:noreply,
         socket
         |> put_data(data)
         |> assign(:layout_errors, changeset_errors(changeset))}
    end
  end

  def handle_event("layout-captured", _params, socket), do: {:noreply, socket}

  def handle_event("delete-layout", %{"id" => id}, socket) do
    case Data.delete_layout(data(socket), id) do
      {{:ok, layout}, data} ->
        socket =
          socket
          |> put_data(data)
          |> assign(:layouts, Data.list_layouts(data))

        if socket.assigns[:active_layout] == id do
          {_result, data} = Data.reset_arrangement(data)
          widgets = Layouts.default_widgets()

          socket =
            socket
            |> put_data(data)
            |> assign(:active_layout, nil)
            |> assign_widget_layout(widgets)
            |> push_event("layout-apply", %{widgets: widgets})

          {:noreply, put_flash(socket, :info, "Removed #{layout.name}, back to Default")}
        else
          {:noreply, put_flash(socket, :info, "Removed #{layout.name}")}
        end

      {{:error, :core}, _data} ->
        {:noreply, put_flash(socket, :error, "Core layouts cannot be removed")}

      {{:error, _reason}, _data} ->
        {:noreply, put_flash(socket, :error, "Layout not found")}
    end
  end

  def handle_event("delete-layout", _params, socket), do: {:noreply, socket}

  def handle_event("layout-changed", params, socket) do
    socket = clear_active_layout(socket)

    case params do
      %{"widgets" => widgets} when is_map(widgets) ->
        widgets = Layouts.with_visibility(widgets, socket.assigns)
        socket = save_arrangement(socket, widgets, nil)
        {:noreply, assign_widget_positions(socket, widgets)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("reset-layout", _params, socket) do
    widgets = Layouts.default_widgets()
    visibility = Map.new(@widgets, fn {_key, assign_key} -> {assign_key, true} end)

    case Data.reset_layout(data(socket), visibility) do
      {{:ok, _}, data} ->
        put_data(socket, data)

      {{:error, changeset}, _data} ->
        Ztripwire.Log.emit(:warning, %{
          event: "user_layout_update_failed",
          action: "reset",
          errors: changeset_errors(changeset)
        })

        socket
    end
    |> then(fn socket ->
      socket =
        socket
        |> assign(:active_layout, nil)
        |> assign_widget_layout(widgets)
        |> push_event("layout-apply", %{widgets: widgets})

      {:noreply, put_flash(socket, :info, "Layout reset to Default")}
    end)
  end

  def handle_event("toggle-map-lock", _params, socket) do
    {:noreply, update(socket, :map_locked, &(!&1))}
  end

  def handle_event("toggle-collapse", %{"id" => id}, socket) do
    case Integer.parse(to_string(id)) do
      {system_id, ""} -> {:noreply, toggle_collapse(socket, system_id)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("expand-all", _params, socket) do
    {:noreply, put_collapsed_ids(socket, Elixir.MapSet.new())}
  end

  def handle_event("open-map-modal", _params, socket) do
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
       |> assign(:map_modal_open, true)
       |> assign(:sig_modal_open, false)
       |> assign(:map_errors, [])
       |> assign(:map_form, %{
         "name" => (map && map.name) || "",
         "home" => home || "",
         "include_thera" => socket.assigns.include_thera,
         "show_all" => socket.assigns.show_all
       })}
    end
  end

  def handle_event("close-map-modal", _params, socket) do
    {:noreply, assign(socket, :map_modal_open, false)}
  end

  def handle_event("save-map-settings", %{"map" => params}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      {:noreply, save_map_settings(socket, params)}
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
         |> expand_hidden_selection(id)
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

  def handle_event("claim-admin", _params, %{assigns: %{demo?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("claim-admin", _params, socket) do
    with true <- socket.assigns[:claim_admin?],
         {:ok, character} <- Accounts.claim_admin(socket.assigns.character) do
      Ztripwire.Log.emit(:info, %{
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

  def handle_event("remove-character", %{"id" => _id}, %{assigns: %{demo?: true}} = socket) do
    {:noreply, put_flash(socket, :error, "Demo characters cannot be removed")}
  end

  def handle_event("remove-character", %{"id" => id}, socket) do
    with {char_id, ""} <- Integer.parse(to_string(id)),
         %{} = character <- Accounts.get_character(char_id),
         {:ok, _} <- Accounts.delete_character(character) do
      Tracking.stop_poller(character)
      pruned_ids = Masks.prune_orphan_masks() |> MapSet.new(& &1.id)
      remaining = Enum.reject(socket.assigns.characters, &(&1.id == character.id))
      socket = assign(socket, :characters, remaining)

      if socket.assigns.character && socket.assigns.character.id == character.id do
        socket = refresh_masks(socket, pruned_ids)

        case remaining do
          [next | _] -> {:noreply, push_navigate(socket, to: "/auth/switch/#{next.eve_id}")}
          [] -> {:noreply, push_navigate(socket, to: "/dashboard")}
        end
      else
        {:noreply,
         socket
         |> after_masks_removed(pruned_ids)
         |> put_flash(:info, "Removed #{character.name}")}
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

  def handle_event("select-gate-system", %{"solar" => solar}, socket) do
    case Integer.parse(to_string(solar)) do
      {solar_system_id, ""} -> {:noreply, select_gate_system(socket, solar_system_id)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("chart-range", %{"range" => range}, socket) when range in @chart_ranges do
    socket =
      socket
      |> put_setting(:chart_range, range)
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
     |> put_setting(:chart_hidden, hidden)
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
      socket =
        socket
        |> put_setting(:map_scale, 100)
        |> put_setting(:map_layout, "top")
        |> apply_tree_layout("top")

      zoom = map_zoom(socket)
      {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map, zoom)
      {:noreply, push_event(socket, "reset-pan", %{x: x, y: y, zoom: zoom})}
    end
  end

  def handle_event("map-layout", %{"layout" => layout}, socket)
      when layout in ~w(top bottom left right) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      {:noreply, socket |> put_setting(:map_layout, layout) |> apply_tree_layout(layout)}
    end
  end

  def handle_event("map-layout", _params, socket), do: {:noreply, socket}

  def handle_event("toggle-row-guides", _params, socket) do
    {:noreply, put_setting(socket, :show_row_guides, !socket.assigns.show_row_guides)}
  end

  def handle_event("toggle-row-counts", _params, socket) do
    {:noreply, put_setting(socket, :show_row_counts, !socket.assigns.show_row_counts)}
  end

  def handle_event("toggle-angled-lines", _params, socket) do
    {:noreply, put_setting(socket, :angled_lines, !socket.assigns.angled_lines)}
  end

  def handle_event("toggle-jump-lines", _params, socket) do
    {:noreply, put_setting(socket, :show_jump_lines, !socket.assigns.show_jump_lines)}
  end

  def handle_event("toggle-line-glow", _params, socket) do
    {:noreply, put_setting(socket, :show_line_glow, !socket.assigns.show_line_glow)}
  end

  def handle_event("toggle-node-badges", _params, socket) do
    {:noreply, put_setting(socket, :show_node_badges, !socket.assigns.show_node_badges)}
  end

  def handle_event("map-scale", %{"scale" => scale}, socket) do
    scale = parse_int(scale, 100, 50, 200)

    {:noreply,
     socket
     |> put_setting(:map_scale, scale)
     |> push_event("map-zoom", %{zoom: scale / 100})}
  end

  def handle_event("map-scale", _params, socket), do: {:noreply, socket}

  def handle_event("line-weight", %{"weight" => weight}, socket) do
    {:noreply, put_setting(socket, :line_weight, parse_int(weight, 2, 1, 5))}
  end

  def handle_event("line-weight", _params, socket), do: {:noreply, socket}

  def handle_event("node-spacing", %{"spacing" => spacing}, socket) do
    socket = put_setting(socket, :node_spacing, parse_int(spacing, 100, 50, 200))
    socket = socket |> apply_tree_layout(socket.assigns.map_layout || "top")
    zoom = map_zoom(socket)
    {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map, zoom)
    {:noreply, push_event(socket, "reset-pan", %{x: x, y: y, zoom: zoom})}
  end

  def handle_event("node-spacing", _params, socket), do: {:noreply, socket}

  def handle_event("node-roundness", %{"roundness" => roundness}, socket)
      when roundness in ~w(square rounded oval) do
    {:noreply, put_setting(socket, :node_roundness, roundness)}
  end

  def handle_event("node-roundness", _params, socket), do: {:noreply, socket}

  def handle_event("map-background", %{"background" => background}, socket) do
    background = background |> to_string() |> String.trim()

    {:noreply,
     put_setting(socket, :map_background, if(background == "", do: nil, else: background))}
  end

  def handle_event("map-background", _params, socket), do: {:noreply, socket}

  def handle_event("create-corp-mask", _params, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_create_corp_mask(socket) do
      {:noreply,
       socket
       |> assign_masks()
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

  def handle_event("add-mask-member", params, %{assigns: %{demo?: true}} = socket) do
    mask = Enum.find(socket.assigns.masks, &(to_string(&1.id) == to_string(params["mask_id"])))

    with true <- admin?(socket),
         %{} = mask <- mask,
         true <- mask.kind == "demo",
         {eve_id, ""} <- Integer.parse(to_string(params["eve_id"] || "")),
         name when name != "" <- String.trim(to_string(params["name"] || "")) do
      {{:ok, member}, state} = Demo.add_member(data(socket), mask.id, eve_id, name)

      {:noreply,
       socket
       |> put_data(state)
       |> put_flash(:info, "Added #{member.name} to #{mask.name}")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Admin access required")}

      _ ->
        {:noreply, put_flash(socket, :error, "Demo admins are scoped to demo masks")}
    end
  end

  def handle_event("add-mask-member", params, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_mask(socket, params["mask_id"]),
         {:ok, member} <- scoped_upsert_member(params),
         {:ok, _} <- Masks.add_membership(mask, member) do
      {:noreply,
       socket
       |> assign_masks()
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

  def handle_event("remove-mask-member", params, %{assigns: %{demo?: true}} = socket) do
    mask =
      Enum.find(
        socket.assigns.masks,
        &(to_string(&1.id) == to_string(params["mask_id"] || params["mask-id"]))
      )

    member_id =
      String.to_integer(to_string(params["character_id"] || params["character-id"] || "0"))

    with %{} = mask <- mask,
         true <- mask.kind == "demo",
         {{:ok, member}, state} <- Demo.remove_member(data(socket), mask.id, member_id) do
      {:noreply,
       socket
       |> put_data(state)
       |> put_flash(:info, "Removed #{member.name} from #{mask.name}")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Demo admins are scoped to demo masks")}

      _ ->
        {:noreply, put_flash(socket, :error, "Member not found")}
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
       |> assign_masks()
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

  def handle_event("delete-mask", _params, %{assigns: %{demo?: true}} = socket) do
    {:noreply, put_flash(socket, :error, "Demo masks cannot be removed")}
  end

  def handle_event("delete-mask", %{"id" => id}, socket) do
    with true <- admin?(socket),
         {:ok, mask} <- scoped_mask(socket, id),
         {:ok, _} <- Masks.delete_mask_full(mask) do
      {:noreply,
       socket
       |> after_masks_removed(MapSet.new([mask.id]))
       |> put_flash(:info, "Deleted #{mask.name}")}
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
      before = Data.list_signatures(data(socket), system.id)
      before_ids = MapSet.new(before, & &1.sig_id)

      pasted_ids = entries |> Enum.map(& &1.sig_id) |> MapSet.new()

      {{added, updated}, data} =
        Data.upsert_signatures(data(socket), system, entries, socket.assigns.character)

      socket = put_data(socket, data)

      {{dropped, linked, hidden}, data} =
        Data.sync_map_after_signature_change(data(socket), system, [])

      socket = put_data(socket, data)

      socket =
        push_signature_history(
          socket,
          system.id,
          {:batch, signature_diff_ops(before, Data.list_signatures(data(socket), system.id))}
        )

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
        system = Data.get_system!(data(socket), system_id)

        deleted =
          system_id
          |> then(&Data.list_signatures(data(socket), &1))
          |> Enum.filter(&MapSet.member?(stale_set, &1.sig_id))

        {socket, deleted} =
          Enum.reduce(deleted, {socket, []}, fn signature, {socket, acc} ->
            {{:ok, removed}, data} =
              Data.delete_signature(data(socket), signature, socket.assigns.character)

            {put_data(socket, data), acc ++ [removed]}
          end)

        {{dropped, linked, hidden}, data} =
          Data.sync_map_after_signature_change(data(socket), system, deleted)

        socket = put_data(socket, data)

        {:noreply,
         socket
         |> push_signature_history(
           system.id,
           {:batch, Enum.map(deleted, &{:delete, signature_history_attrs(&1)})}
         )
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

  def handle_event("open-add", _params, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      _system ->
        {:noreply, open_signature_add(socket)}
    end
  end

  def handle_event("open-edit", %{"id" => id}, socket) do
    case Data.get_signature(data(socket), id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Signature not found")}

      sig ->
        {:noreply, open_signature_edit(socket, sig)}
    end
  end

  def handle_event("close-sig-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:sig_modal_open, false)
     |> assign(:sig_edit_id, nil)
     |> assign(:sig_errors, [])}
  end

  def handle_event("delete-signature", %{"id" => id}, socket) do
    case Data.get_signature(data(socket), id) do
      nil ->
        {:noreply, socket}

      signature ->
        case delete_signature_data(socket, signature) do
          {:ok, socket} ->
            {:noreply,
             socket
             |> push_signature_history(
               signature.map_system_id,
               {:delete, signature_history_attrs(signature)}
             )
             |> assign(:sig_modal_open, false)
             |> assign(:sig_edit_id, nil)
             |> assign(:sig_errors, [])}

          {:error, socket} ->
            {:noreply, socket}
        end
    end
  end

  def handle_event("undo", _params, socket) do
    case socket.assigns.selected_system_id do
      nil -> {:noreply, put_flash(socket, :error, "Select a system before undoing")}
      system_id -> {:noreply, apply_signature_history_step(socket, system_id, :undo)}
    end
  end

  def handle_event("redo", _params, socket) do
    case socket.assigns.selected_system_id do
      nil -> {:noreply, put_flash(socket, :error, "Select a system before redoing")}
      system_id -> {:noreply, apply_signature_history_step(socket, system_id, :redo)}
    end
  end

  def handle_event("sig-form-change", %{"sig" => params}, socket) do
    previous = socket.assigns.sig_form
    form = Map.merge(previous, params)
    form = form |> autofill_wormhole(previous, params) |> refresh_quick_types(socket)

    {:noreply, assign(socket, :sig_form, form)}
  end

  def handle_event("sig-type-pick", %{"code" => code}, socket) do
    previous = socket.assigns.sig_form
    form = Map.put(previous, "wormhole_code", String.upcase(code))

    form =
      form
      |> autofill_wormhole(previous, %{"wormhole_code" => code})
      |> refresh_quick_types(socket)

    {:noreply, assign(socket, :sig_form, form)}
  end

  def handle_event("sig-other-type-pick", %{"code" => code}, socket) do
    previous = socket.assigns.sig_form
    form = Map.put(previous, "other_wormhole_code", String.upcase(code))

    form =
      form
      |> autofill_wormhole(previous, %{"other_wormhole_code" => code})
      |> refresh_quick_types(socket)

    {:noreply, assign(socket, :sig_form, form)}
  end

  def handle_event("sig-leads-pick", %{"value" => value}, socket) do
    form = socket.assigns.sig_form |> Map.put("leads_to", value) |> refresh_quick_types(socket)

    {:noreply, assign(socket, :sig_form, form)}
  end

  def handle_event("sig-clear-leads", _params, socket) do
    form = socket.assigns.sig_form |> Map.put("leads_to", "") |> refresh_quick_types(socket)

    {:noreply, assign(socket, :sig_form, form)}
  end

  def handle_event("save-signature", %{"sig" => params}, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        attrs = signature_attrs(params)

        case socket.assigns.sig_edit_id do
          nil ->
            case Data.create_signature(data(socket), system, attrs, socket.assigns.character) do
              {{:ok, sig}, data} ->
                {:noreply,
                 socket
                 |> put_data(data)
                 |> push_signature_history(system.id, {:add, signature_history_attrs(sig)})
                 |> assign(:sig_modal_open, false)
                 |> assign(:sig_edit_id, nil)
                 |> assign(:sig_errors, [])
                 |> sync_map_hole_type(system, nil, sig_hole_code(attrs))
                 |> apply_sig_links(sig, params)
                 |> reload_signatures()
                 |> reload_map()
                 |> put_flash(:info, "Signature added")}

              {{:error, changeset}, data} ->
                {:noreply,
                 socket |> put_data(data) |> assign(:sig_errors, changeset_errors(changeset))}
            end

          id ->
            sig = Data.get_signature!(data(socket), id)
            old_attrs = signature_history_attrs(sig)

            case Data.update_signature(data(socket), sig, attrs, socket.assigns.character) do
              {{:ok, sig}, data} ->
                {:noreply,
                 socket
                 |> put_data(data)
                 |> push_signature_history(
                   system.id,
                   {:update, old_attrs, signature_history_attrs(sig)}
                 )
                 |> assign(:sig_modal_open, false)
                 |> assign(:sig_edit_id, nil)
                 |> assign(:sig_errors, [])
                 |> sync_map_hole_type(system, sig_hole_code(sig), sig_hole_code(attrs))
                 |> apply_sig_links(sig, params)
                 |> reload_signatures()
                 |> reload_map()
                 |> put_flash(:info, "Signature updated")}

              {{:error, changeset}, data} ->
                {:noreply,
                 socket |> put_data(data) |> assign(:sig_errors, changeset_errors(changeset))}
            end
        end
    end
  end

  def handle_event("switch-character", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.characters, &(to_string(&1.id) == to_string(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Character not found")}

      character ->
        if socket.assigns.character && socket.assigns.character.id == character.id do
          {:noreply, socket}
        else
          socket = switch_character(socket, character)

          {:noreply,
           push_event(socket, "character-switched", %{
             eve_id: character.eve_id,
             mask_id: socket.assigns.mask.id
           })}
        end
    end
  end

  def handle_event("switch-mask", %{"id" => _id}, %{assigns: %{demo?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("switch-mask", %{"id" => id}, socket) do
    mask_id = String.to_integer(id)

    case Enum.find(socket.assigns.masks, &(&1.id == mask_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Mask not found")}

      mask ->
        {map, socket} = map_for_mask(socket, mask)
        socket = ensure_jita_system(socket, map)

        Phoenix.PubSub.unsubscribe(
          Ztripwire.PubSub,
          Ztripwire.Tracking.map_topic(socket.assigns.map.id)
        )

        Phoenix.PubSub.subscribe(Ztripwire.PubSub, Ztripwire.Tracking.map_topic(map.id))

        {:noreply,
         socket
         |> assign(:mask, mask)
         |> assign(:map, map)
         |> assign(:maps, Data.list_maps_for_mask(data(socket), mask.id))
         |> assign(:systems, chain_systems(socket, map))
         |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map.id))
         |> assign(:selected_system_id, nil)
         |> assign(:selected_system_name, nil)
         |> assign(:chart_system, nil)
         |> assign(:system_suggestions, [])
         |> assign(:signatures, [])
         |> assign(:comments, [])
         |> assign(:undo, %{})
         |> assign(:redo, %{})
         |> refresh_occupants()
         |> patch_to_preferred(chain_systems(socket, map))
         |> push_event("mask-switched", %{mask_id: mask.id})}
    end
  end

  def handle_event("new-map", _params, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      mask = socket.assigns.mask
      count = length(Data.list_maps_for_mask(data(socket), mask.id))
      name = "Chain #{count + 1}"

      case Data.create_map(data(socket), %{name: name, mask_id: mask.id}) do
        {{:ok, map}, data} ->
          socket = put_data(socket, data)

          {:noreply,
           socket
           |> assign(:maps, Data.list_maps_for_mask(data(socket), mask.id))
           |> assign_active_map(map)
           |> put_flash(:info, "Created #{name}")}

        {{:error, changeset}, data} ->
          {:noreply, socket |> put_data(data) |> flash_changeset_errors(changeset)}
      end
    end
  end

  def handle_event("switch-map", %{"id" => id}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      map_id = String.to_integer(id)

      case Data.get_map!(data(socket), map_id) do
        %{mask_id: mask_id} = map when mask_id == socket.assigns.mask.id ->
          {:noreply, assign_active_map(socket, map)}

        _ ->
          {:noreply, put_flash(socket, :error, "Map not found")}
      end
    end
  rescue
    _ -> {:noreply, put_flash(socket, :error, "Map not found")}
  end

  def handle_event("delete-map", %{"id" => id}, socket) do
    if socket.assigns[:map_locked] do
      {:noreply, put_flash(socket, :error, "Map is locked")}
    else
      mask = socket.assigns.mask
      maps = Data.list_maps_for_mask(data(socket), mask.id)
      target = Enum.find(maps, &(to_string(&1.id) == to_string(id)))

      if target do
        current? = socket.assigns.map && socket.assigns.map.id == target.id
        primary? = List.first(maps) == target

        {{:ok, _deleted}, data} = Data.delete_map_full(data(socket), target)

        socket =
          put_data(socket, data)
          |> assign(:map_modal_open, false)
          |> drop_collapsed_map(target.id)

        socket =
          if current? do
            {replacement, socket} = replacement_map(socket, mask)
            assign_active_map(socket, replacement)
          else
            socket
          end

        socket =
          socket
          |> assign(:maps, Data.list_maps_for_mask(data(socket), mask.id))
          |> after_map_replaced()
          |> restart_pollers_for(primary?)

        {:noreply, put_flash(socket, :info, "Deleted #{target.name}")}
      else
        {:noreply, put_flash(socket, :error, "Map not found")}
      end
    end
  end

  def handle_event("add-viewing", _params, %{assigns: %{demo?: true}} = socket) do
    {:noreply, put_flash(socket, :error, "ESI location unavailable")}
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
             Ztripwire.Tracking.apply_location_change(
               socket.assigns.map,
               socket.assigns.character.name,
               prev,
               solar_system_id
             ) do
        {:noreply,
         socket
         |> assign(:systems, chain_systems(socket))
         |> assign(
           :connections,
           Data.list_connections_with_endpoints(data(socket), socket.assigns.map.id)
         )
         |> select_system(system.id)
         |> push_patch(to: "/" <> system.name)
         |> put_flash(:info, "Added viewing system #{system.name}")}
      else
        _ -> {:noreply, put_flash(socket, :error, "ESI location unavailable")}
      end
    end
  end

  def handle_event("refresh-occupants", _params, socket) do
    {:noreply, refresh_occupants(socket)}
  end

  defp admin?(%{assigns: %{character: %{is_admin: true}}}), do: true
  defp admin?(_), do: false

  defp session_characters(session, current) do
    known =
      session
      |> ZtripwireWeb.SessionUser.ids()
      |> Enum.map(&Accounts.get_character_by_eve_id/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)

    case current do
      nil ->
        known

      %{id: id} = character ->
        if Enum.any?(known, &(&1.id == id)), do: known, else: known ++ [character]
    end
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

  defp mask_options(socket) do
    if demo?(socket), do: socket.assigns.masks, else: Masks.list_masks()
  end

  defp assign_masks(socket) do
    socket
    |> assign(:masks, mask_options(socket))
    |> assign(:admin_masks, masks_for_admin(socket))
  end

  defp assign_admin_masks(socket) do
    assign(socket, :admin_masks, masks_for_admin(socket))
  end

  defp refresh_masks(socket, removed_ids) do
    socket
    |> assign(:masks, Enum.reject(socket.assigns.masks, &MapSet.member?(removed_ids, &1.id)))
    |> assign_admin_masks()
  end

  defp after_masks_removed(%{assigns: %{demo?: true}} = socket, _removed_ids), do: socket

  defp after_masks_removed(socket, removed_ids) do
    socket = refresh_masks(socket, removed_ids)

    if MapSet.member?(removed_ids, socket.assigns.mask.id) do
      case List.first(socket.assigns.masks) do
        nil ->
          socket

        next ->
          {map, socket} = replacement_map(socket, next)

          socket
          |> assign(:mask, next)
          |> assign(:maps, Data.list_maps_for_mask(data(socket), next.id))
          |> assign_active_map(map)
      end
    else
      socket
    end
  end

  defp scoped_mask(socket, id) do
    with {mask_id, ""} <- Integer.parse(to_string(id || "")),
         %{} = mask <- find_mask(socket, mask_id) do
      if demo?(socket) and mask.kind != "demo" do
        {:error, :forbidden}
      else
        {:ok, mask}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp find_mask(%{assigns: %{demo?: true}} = socket, mask_id) do
    Enum.find(socket.assigns.masks, &(&1.id == mask_id))
  end

  defp find_mask(socket, mask_id) do
    Enum.find(socket.assigns.masks, &(&1.id == mask_id)) ||
      Ztripwire.Repo.get(Ztripwire.Masks.Mask, mask_id)
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
    systems = chain_systems(socket, map)
    connections = Data.list_connections_with_endpoints(data(socket), map.id)
    home_id = home_root_id(systems, map)

    positions = layout_positions(systems, connections, layout, spacing, home_id)

    {_socket, data} =
      Enum.reduce(systems, {socket, data(socket)}, fn system, {socket, data} ->
        pos = positions[system.id]
        stored = Data.get_system!(data, system.id)
        {{:ok, _}, data} = Data.update_system_position(data, stored, pos.x, pos.y)
        {socket, data}
      end)

    socket = put_data(socket, data)

    socket
    |> assign(:systems, chain_systems(socket, map))
    |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map.id))
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

  defp chain_systems(socket, map \\ nil) do
    Data.list_chain_systems(data(socket), map || socket.assigns.map, socket.assigns.show_all)
  end

  defp assign_layouts(socket) do
    data = data(socket)
    layouts = Data.list_layouts(data)

    case Data.resolve_active(data) do
      nil ->
        socket
        |> assign(:layouts, layouts)
        |> assign(:active_layout, nil)
        |> assign_widget_positions(Data.arrangement(data))

      layout ->
        socket
        |> assign(:layouts, layouts)
        |> assign(:active_layout, layout.id)
        |> assign_widget_layout(layout.widgets)
    end
  end

  defp assign_widget_positions(socket, widgets) do
    positions = Map.merge(socket.assigns.widget_positions || %{}, widgets)
    assign(socket, :widget_positions, positions)
  end

  defp assign_widget_layout(socket, widgets) do
    Enum.reduce(@widgets, socket, fn {key, assign_key}, socket ->
      socket
      |> assign(:widget_positions, Map.put(socket.assigns.widget_positions, key, widgets[key]))
      |> assign(assign_key, widgets[key]["visible"])
    end)
  end

  defp clear_active_layout(socket) do
    if socket.assigns[:active_layout] do
      {_result, data} = Data.clear_active(data(socket))
      socket |> put_data(data) |> assign(:active_layout, nil)
    else
      socket
    end
  end

  defp save_arrangement(socket, widgets, active_id) do
    case Data.put_arrangement(data(socket), widgets, active_id) do
      {{:ok, _}, data} ->
        put_data(socket, data)

      {{:error, changeset}, _data} ->
        Ztripwire.Log.emit(:warning, %{
          event: "user_layout_update_failed",
          action: "save",
          active_layout: inspect(active_id),
          errors: changeset_errors(changeset)
        })

        socket
    end
  end

  defp put_setting(socket, key, value) do
    case Data.put_setting(data(socket), key, value) do
      {{:ok, _}, data} ->
        put_data(socket, data) |> assign(key, value)

      {{:error, changeset}, _data} ->
        Ztripwire.Log.emit(:warning, %{
          event: "user_settings_update_failed",
          key: key,
          value: inspect(value),
          errors: changeset_errors(changeset)
        })

        assign(socket, key, value)
    end
  end

  defp map_zoom(socket) do
    case socket.assigns[:map_scale] do
      scale when is_number(scale) -> Mapping.default_zoom() * scale / 100
      _ -> Mapping.default_zoom()
    end
  end

  defp parse_int(value, default, min, max) do
    case Integer.parse(to_string(value || "")) do
      {n, ""} -> n |> max(min) |> min(max)
      _ -> default
    end
  end

  defp provision(socket, character, session) do
    mask = character |> ensure_character_masks() |> restore_mask(session)
    {map, socket} = personal_map(socket, mask)

    masks = Masks.list_masks()
    admin_masks = Masks.list_masks_for_character(character.id)
    socket = ensure_jita_system(socket, map)
    settings = Settings.assigns()

    socket
    |> assign(:current_user, %{id: character.eve_id, name: character.name})
    |> assign(:character, character)
    |> assign(:characters, [character])
    |> assign(:mask, mask)
    |> assign(:masks, masks)
    |> assign(:admin_masks, admin_masks)
    |> assign(:map, map)
    |> assign(:maps, Data.list_maps_for_mask(data(socket), mask.id))
    |> assign_topbar_defaults()
    |> assign(settings)
    |> assign_layouts()
    |> assign(:systems, Data.list_chain_systems(data(socket), map, settings.show_all))
    |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map.id))
    |> apply_tree_layout(settings.map_layout)
    |> assign_blank_view()
    |> assign(:demo?, false)
    |> assign_claim_admin(character)
    |> assign(:branding, Accounts.branding())
    |> assign(:sso_configured?, Ztripwire.SSO.configured?())
    |> subscribe_to_map(map.id)
    |> schedule_topbar_load()
    |> schedule_chart_refresh()
  end

  defp assign_blank_view(socket) do
    socket
    |> assign(:selected_system_id, nil)
    |> assign(:selected_system_name, nil)
    |> assign(:chart_system, nil)
    |> assign(:system_suggestions, [])
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> autoselect_first_system()
    |> assign(:stale_ids, [])
    |> assign(:stale_system_id, nil)
    |> assign(:settings_open, false)
    |> assign(:settings_tab, "account")
    |> assign(:sig_modal_open, false)
    |> assign(:sig_edit_id, nil)
    |> assign(:sig_form, SigParser.default_form())
    |> assign(:sig_errors, [])
  end

  defp assign_selection_reset(socket) do
    socket
    |> assign(:system_search, "")
    |> assign(:system_suggestions, [])
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> assign(:system_info, nil)
    |> assign(:chart_data, empty_chart_data(socket.assigns[:chart_range] || "24h"))
    |> assign(:stale_ids, [])
    |> assign(:stale_system_id, nil)
  end

  defp restore_mask(default, session) do
    case ZtripwireWeb.SessionUser.mask_id(session) do
      nil ->
        default

      id ->
        case Masks.get_mask(id) do
          %{kind: "demo"} -> default
          %{} = mask -> mask
          nil -> default
        end
    end
  end

  defp ensure_character_masks(character) do
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

    mask
  end

  defp personal_map(socket, mask) do
    case Data.list_maps_for_mask(data(socket), mask.id) do
      [map | _] ->
        {map, socket}

      [] ->
        {{:ok, map}, data} = Data.create_map(data(socket), %{name: "Home", mask_id: mask.id})
        {map, put_data(socket, data)}
    end
  end

  defp map_for_mask(socket, mask) do
    personal_map(socket, mask)
  end

  defp assign_active_map(socket, map) do
    unless demo?(socket) do
      if socket.assigns[:map], do: unsubscribe_from_map(socket.assigns.map.id)
      _ = subscribe_to_map(socket, map.id)
    end

    systems = chain_systems(socket, map)

    socket
    |> assign(:map, map)
    |> assign(:systems, systems)
    |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map.id))
    |> assign(:selected_system_id, nil)
    |> assign(:selected_system_name, nil)
    |> assign(:chart_system, nil)
    |> assign(:system_suggestions, [])
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> assign(:undo, %{})
    |> assign(:redo, %{})
    |> patch_to_preferred(systems)
    |> refresh_occupants()
  end

  defp replacement_map(socket, mask) do
    case Data.list_maps_for_mask(data(socket), mask.id) do
      [map | _] -> {map, socket}
      [] -> default_map(socket, mask)
    end
  end

  defp default_map(%{assigns: %{demo?: true}} = socket, _mask) do
    data = Demo.reset_map(data(socket))
    {hd(data.maps), put_data(socket, data)}
  end

  defp default_map(socket, mask) do
    {map, socket} = personal_map(socket, mask)
    {map, ensure_jita_system(socket, map)}
  end

  defp after_map_replaced(%{assigns: %{demo?: true}} = socket) do
    refresh_occupants(socket)
  end

  defp after_map_replaced(socket), do: socket

  defp restart_pollers_for(%{assigns: %{mask: mask, demo?: demo?}} = socket, primary?) do
    if primary? and not demo? and mask.kind == "personal" do
      Enum.each(socket.assigns[:characters] || [], fn character ->
        if Tracking.tracking?(character) do
          _ = Tracking.stop_poller(character)
          _ = Tracking.ensure_poller(character)
        end
      end)
    end

    socket
  end

  defp switch_character(socket, character) do
    mask = ensure_character_masks(character)
    {map, socket} = personal_map(socket, mask)
    socket = ensure_jita_system(socket, map)
    settings = socket.assigns
    claim_admin_modal? = settings[:claim_admin_modal?]

    Phoenix.PubSub.unsubscribe(
      Ztripwire.PubSub,
      Ztripwire.Tracking.map_topic(socket.assigns.map.id)
    )

    Phoenix.PubSub.subscribe(Ztripwire.PubSub, Ztripwire.Tracking.map_topic(map.id))

    socket
    |> assign(:character, character)
    |> assign(:current_user, %{id: character.eve_id, name: character.name})
    |> assign(:mask, mask)
    |> assign(:masks, Masks.list_masks())
    |> assign(:admin_masks, Masks.list_masks_for_character(character.id))
    |> assign(:map, map)
    |> assign(:maps, Data.list_maps_for_mask(data(socket), mask.id))
    |> apply_tree_layout_with_home(settings.map_layout, map)
    |> assign(:selected_system_id, nil)
    |> assign(:selected_system_name, nil)
    |> assign(:chart_system, nil)
    |> assign(:undo, %{})
    |> assign(:redo, %{})
    |> assign(:system_suggestions, [])
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> assign(:system_info, nil)
    |> assign(:chart_data, empty_chart_data(settings[:chart_range] || "24h"))
    |> assign(:stale_ids, [])
    |> assign(:stale_system_id, nil)
    |> assign(:presences, %{})
    |> assign_claim_admin(character)
    |> assign(:claim_admin_modal?, claim_admin_modal?)
    |> ensure_character_pollers()
    |> request_topbar_data()
    |> patch_to_preferred(chain_systems(socket, map))
  end

  defp selected_system(%{assigns: %{selected_system_id: nil}}), do: nil

  defp selected_system(%{assigns: %{selected_system_id: id}} = socket) do
    Data.get_system(data(socket), id)
  end

  defp selected_system_name(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{name: name} -> name
      nil -> nil
    end
  end

  defp collapsed_ids(socket) do
    map_id = socket.assigns[:map] && socket.assigns.map.id

    Elixir.Map.get(socket.assigns[:collapsed_by_map] || %{}, map_id, Elixir.MapSet.new())
  end

  defp put_collapsed_ids(socket, ids) do
    case socket.assigns[:map] do
      nil ->
        socket

      map ->
        assign(
          socket,
          :collapsed_by_map,
          Elixir.Map.put(socket.assigns[:collapsed_by_map] || %{}, map.id, ids)
        )
    end
  end

  defp drop_collapsed_map(socket, map_id) do
    assign(
      socket,
      :collapsed_by_map,
      Elixir.Map.delete(socket.assigns[:collapsed_by_map] || %{}, map_id)
    )
  end

  defp hidden_system_ids(socket) do
    systems = socket.assigns[:systems] || []
    connections = socket.assigns[:connections] || []
    root_id = Mapping.chain_home_id(systems, socket.assigns[:map])

    Mapping.collapse_hidden_ids(systems, connections, collapsed_ids(socket), root_id: root_id)
  end

  defp expand_hidden_selection(socket, system_id) do
    if Elixir.MapSet.member?(hidden_system_ids(socket), system_id) do
      put_collapsed_ids(socket, Elixir.MapSet.new())
    else
      socket
    end
  end

  defp toggle_collapse(socket, system_id) do
    if Enum.any?(socket.assigns[:systems] || [], &(&1.id == system_id)) do
      collapsed = collapsed_ids(socket)

      collapsed =
        if Elixir.MapSet.member?(collapsed, system_id) do
          Elixir.MapSet.delete(collapsed, system_id)
        else
          Elixir.MapSet.put(collapsed, system_id)
        end

      put_collapsed_ids(socket, collapsed)
    else
      socket
    end
  end

  defp select_system(socket, system_id) do
    chart_system =
      Enum.find(socket.assigns.systems, &(&1.id == system_id)) ||
        Data.get_system(data(socket), system_id)

    socket =
      socket
      |> assign_selection_reset()
      |> assign(:selected_system_id, system_id)
      |> assign(:selected_system_name, selected_system_name(socket.assigns.systems, system_id))
      |> assign(:chart_system, chart_system)
      |> assign(:signatures, Data.list_signatures(data(socket), system_id))
      |> assign(:comments, Data.list_comments(data(socket), system_id))

    schedule_system_detail(socket, chart_system)
  end

  defp select_gate_system(socket, solar_system_id, opts \\ []) do
    case Systems.Catalog.get(solar_system_id) do
      %{name: name} = system ->
        socket =
          socket
          |> assign_selection_reset()
          |> assign(:chart_system, system)
          |> assign(:selected_system_id, nil)
          |> assign(:selected_system_name, name)
          |> schedule_system_detail(system)

        if Keyword.get(opts, :patch, true) do
          push_patch(socket, to: "/" <> name)
        else
          socket
        end

      nil ->
        put_flash(socket, :error, "System not found")
    end
  end

  defp select_named_offchain(socket, system_name, systems) do
    case Systems.Catalog.find(system_name) do
      %{solar_system_id: solar_system_id} when is_integer(solar_system_id) ->
        if kspace_solar?(solar_system_id) do
          if chart_solar(socket.assigns[:chart_system]) == solar_system_id and
               is_nil(socket.assigns[:selected_system_id]) do
            {:noreply, socket}
          else
            {:noreply, select_gate_system(socket, solar_system_id, patch: false)}
          end
        else
          {:noreply, select_preferred(socket, systems)}
        end

      _ ->
        {:noreply, select_preferred(socket, systems)}
    end
  end

  defp select_preferred(socket, systems) do
    case preferred_system(systems) do
      %{id: id, name: name} ->
        socket |> select_system(id) |> push_patch(to: "/" <> name)

      nil ->
        socket
    end
  end

  defp chart_solar(%{solar_system_id: solar_system_id}), do: solar_system_id
  defp chart_solar(_), do: nil

  defp kspace_solar?(solar_system_id),
    do: is_integer(solar_system_id) and solar_system_id < 31_000_000

  defp toggle_favorite(socket) do
    case selected_system(socket) do
      nil ->
        put_flash(socket, :error, "Select a system first")

      system ->
        case Data.update_system(data(socket), system, %{favorite: !system.favorite}) do
          {{:ok, _}, data} ->
            socket = put_data(socket, data)
            assign(socket, :systems, chain_systems(socket))

          {{:error, changeset}, data} ->
            socket |> put_data(data) |> flash_changeset_errors(changeset)
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
      candidates = Data.list_favorite_candidates(data(socket), mask.id, map.id)
      candidates = Enum.reject(candidates, &MapSet.member?(chain_solar, &1.solar_system_id))

      route_fn =
        Application.get_env(:ztripwire, :route_fn, fn o, d -> ESI.get_route(o, d) end)

      {added, skipped, socket} =
        Enum.reduce(candidates, {0, 0, socket}, fn cand, {a, s, socket} ->
          chain_for_check =
            if socket.assigns.systems == chain_systems,
              do: chain_systems,
              else: Data.list_systems(data(socket), map.id)

          current_solar = MapSet.new(chain_for_check, & &1.solar_system_id)

          case favorite_link_target(
                 socket,
                 mask.id,
                 cand,
                 chain_for_check,
                 current_solar,
                 route_fn
               ) do
            nil ->
              {a, s + 1, socket}

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

              case Data.ensure_chain_system(data(socket), map, attrs) do
                {{:ok, fresh, _}, data} ->
                  socket = put_data(socket, data)

                  {{:ok, _, _}, data} =
                    Data.upsert_connection(data(socket), map.id, fresh.id, target.id, %{
                      hole_type: hole_type,
                      jumps: jumps
                    })

                  {a + 1, s, put_data(socket, data)}

                {_error, data} ->
                  {a, s + 1, put_data(socket, data)}
              end
          end
        end)

      socket =
        socket
        |> assign(:systems, chain_systems(socket, map))
        |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map.id))
        |> apply_tree_layout(socket.assigns.map_layout || "top")

      zoom = map_zoom(socket)
      {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map, zoom)

      socket =
        socket
        |> push_event("reset-pan", %{x: x, y: y, zoom: zoom})

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

  defp favorite_link_target(socket, mask_id, cand, chain_systems, current_solar, route_fn) do
    case Data.wormhole_link_target(data(socket), mask_id, cand.solar_system_id, chain_systems) do
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

  defp save_map_settings(socket, params) do
    map = socket.assigns.map
    name = params["name"] |> to_string() |> String.trim()
    home_input = params["home"] |> to_string() |> String.trim()
    include_thera = params["include_thera"] in ["true", "on", "1"]
    show_all = params["show_all"] in ["true", "on", "1"]

    with {:ok, home_solar, home_name} <- resolve_home_input(socket, home_input) do
      case Data.update_map(data(socket), map, %{
             name: name,
             home_solar_system_id: home_solar,
             home_name: home_name
           }) do
        {{:ok, updated}, data} ->
          socket = put_data(socket, data)
          socket = put_setting(socket, :include_thera, include_thera)
          socket = put_setting(socket, :show_all, show_all)

          socket =
            socket
            |> assign(:map, updated)

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
            |> assign(:map_modal_open, false)
            |> assign(:map_errors, [])
            |> assign(:maps, Data.list_maps_for_mask(data(socket), socket.assigns.mask.id))

          zoom = map_zoom(socket)
          {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map, zoom)

          socket
          |> push_event("reset-pan", %{x: x, y: y, zoom: zoom})
          |> put_flash(:info, "Map saved")

        {{:error, %Ecto.Changeset{} = changeset}, data} ->
          socket |> put_data(data) |> assign(:map_errors, changeset_errors(changeset))

        {{:error, _}, data} ->
          socket |> put_data(data) |> assign(:map_errors, ["Could not save map settings"])
      end
    else
      {:error, message} when is_binary(message) ->
        assign(socket, :map_errors, [message])
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
    mask_maps = Data.list_maps_for_mask(data(socket), socket.assigns.mask.id)
    map_ids = Enum.map(mask_maps, & &1.id)

    Enum.find_value(map_ids, fn _ -> nil end)

    found =
      Enum.find(socket.assigns.systems || [], &(&1.solar_system_id == solar))

    if found, do: found.name, else: nil
  end

  defp ensure_home_node(socket, map, solar, name) do
    case Enum.find(Data.list_systems(data(socket), map.id), &(&1.solar_system_id == solar)) do
      %{id: id} ->
        {{:ok, _}, data} = Data.unhide_systems(data(socket), [id])
        put_data(socket, data)

      nil ->
        create_home_node(socket, map, solar, name)
    end
  end

  defp create_home_node(socket, map, solar, name) do
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

    case Data.ensure_chain_system(data(socket), map, attrs) do
      {{:ok, system, _}, data} ->
        {{:ok, _}, data} = Data.unhide_systems(data, [system.id])
        put_data(socket, data)

      {_error, data} ->
        put_data(socket, data)
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

      case Data.ensure_chain_system(data(socket), map, attrs) do
        {{:ok, thera, true}, data} ->
          socket = put_data(socket, data)
          link_target = (socket.assigns.systems || []) |> List.first()

          if link_target do
            {{:ok, _, _}, data} =
              Data.upsert_connection(data(socket), map.id, thera.id, link_target.id, %{})

            put_data(socket, data)
          else
            socket
          end

        {{:ok, _thera, false}, data} ->
          put_data(socket, data)

        {_error, data} ->
          put_data(socket, data)
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
        {_result, data} =
          Data.sync_signature_to_connections(
            data(socket),
            socket.assigns.map,
            system,
            old_code,
            new_code
          )

        socket = put_data(socket, data)
        unless demo?(socket), do: Ztripwire.Tracking.broadcast_map_update(socket.assigns.map.id)

        assign(
          socket,
          :connections,
          Data.list_connections_with_endpoints(data(socket), socket.assigns.map.id)
        )
    end
  end

  defp sig_hole_code(%{site_type: "wormhole", type_name: name}), do: SigParser.wormhole_code(name)
  defp sig_hole_code(_), do: nil

  defp signature_attrs(params) do
    params =
      if params["site_type"] == "wormhole" do
        Map.put(
          params,
          "type_name",
          SigParser.join_wormhole(params["type_name"], params["wormhole_code"])
        )
      else
        params
      end

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    attrs = SigParser.attrs_from_params(params)

    attrs
    |> Map.put(:inserted_at, now)
    |> Map.put(:expires_at, SigParser.expires_at_for(params["life_status"], attrs[:life_length]))
  end

  defp signature_history_attrs(sig) do
    %{
      sig_id: sig.sig_id,
      kind: sig.kind,
      type_name: sig.type_name,
      type_id: sig.type_id,
      site_type: sig.site_type,
      bookmark: sig.bookmark,
      life_length: sig.life_length,
      inserted_at: sig.inserted_at,
      expires_at: sig.expires_at
    }
  end

  defp push_signature_history(socket, _system_id, {:batch, []}), do: socket

  defp push_signature_history(socket, system_id, {:batch, [op]}),
    do: push_signature_history(socket, system_id, op)

  defp push_signature_history(socket, system_id, op) do
    undo = Map.update(socket.assigns.undo, system_id, [op], &[op | &1])
    redo = Map.delete(socket.assigns.redo, system_id)
    assign(socket, undo: undo, redo: redo)
  end

  defp apply_signature_history_step(socket, system_id, direction) do
    {from, to} = if direction == :undo, do: {:undo, :redo}, else: {:redo, :undo}

    case Map.get(socket.assigns[from], system_id, []) do
      [] ->
        socket

      [op | rest] ->
        case apply_signature_history(socket, system_id, op, direction) do
          {:ok, socket} ->
            from_map = Map.put(socket.assigns[from], system_id, rest)
            to_map = Map.update(socket.assigns[to], system_id, [op], &[op | &1])
            assign(socket, [{from, from_map}, {to, to_map}])

          {:error, socket} ->
            socket
        end
    end
  end

  defp apply_signature_history(socket, system_id, {:batch, ops}, :undo) do
    Enum.reduce_while(Enum.reverse(ops), {:ok, socket}, fn op, {:ok, acc} ->
      case apply_signature_history(acc, system_id, op, :undo) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        {:error, acc} -> {:halt, {:error, acc}}
      end
    end)
  end

  defp apply_signature_history(socket, system_id, {:batch, ops}, :redo) do
    Enum.reduce_while(ops, {:ok, socket}, fn op, {:ok, acc} ->
      case apply_signature_history(acc, system_id, op, :redo) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        {:error, acc} -> {:halt, {:error, acc}}
      end
    end)
  end

  defp apply_signature_history(socket, system_id, {:add, attrs}, :undo),
    do: delete_history_signature(socket, system_id, attrs.sig_id)

  defp apply_signature_history(socket, system_id, {:add, attrs}, :redo),
    do: create_history_signature(socket, system_id, attrs)

  defp apply_signature_history(socket, system_id, {:delete, attrs}, :undo),
    do: create_history_signature(socket, system_id, attrs)

  defp apply_signature_history(socket, system_id, {:delete, attrs}, :redo),
    do: delete_history_signature(socket, system_id, attrs.sig_id)

  defp apply_signature_history(socket, system_id, {:update, old_attrs, new_attrs}, :undo),
    do: update_history_signature(socket, system_id, old_attrs, new_attrs.sig_id)

  defp apply_signature_history(socket, system_id, {:update, old_attrs, new_attrs}, :redo),
    do: update_history_signature(socket, system_id, new_attrs, old_attrs.sig_id)

  defp delete_history_signature(socket, system_id, sig_id) do
    case find_signature_by_id(socket, system_id, sig_id) do
      nil -> {:error, put_flash(socket, :error, "Signature not found")}
      signature -> delete_signature_data(socket, signature)
    end
  end

  defp create_history_signature(socket, system_id, attrs) do
    case Data.get_system(data(socket), system_id) do
      nil ->
        {:error, put_flash(socket, :error, "Signature system not found")}

      system ->
        case Data.create_signature(data(socket), system, attrs, socket.assigns.character) do
          {{:ok, _signature}, data} ->
            {{dropped, linked, hidden}, data} =
              Data.sync_map_after_signature_change(data, system, [])

            socket = put_data(socket, data)
            {:ok, socket |> reload_map_from_sync(dropped, linked, hidden) |> reload_signatures()}

          {{:error, changeset}, data} ->
            {:error, socket |> put_data(data) |> flash_changeset_errors(changeset)}
        end
    end
  end

  defp update_history_signature(socket, system_id, attrs, current_sig_id) do
    with %{} = system <- Data.get_system(data(socket), system_id),
         %{} = signature <- find_signature_by_id(socket, system_id, current_sig_id) do
      case Data.update_signature(data(socket), signature, attrs, socket.assigns.character) do
        {{:ok, updated}, data} ->
          socket = put_data(socket, data)

          socket =
            sync_map_hole_type(socket, system, sig_hole_code(signature), sig_hole_code(updated))

          {:ok, socket |> reload_signatures() |> reload_map()}

        {{:error, changeset}, data} ->
          {:error, socket |> put_data(data) |> flash_changeset_errors(changeset)}
      end
    else
      _ -> {:error, put_flash(socket, :error, "Signature not found")}
    end
  end

  defp find_signature_by_id(socket, system_id, sig_id) do
    data(socket)
    |> Data.list_signatures(system_id)
    |> Enum.find(&(&1.sig_id == sig_id))
  end

  defp delete_signature_data(socket, signature) do
    case Data.get_system(data(socket), signature.map_system_id) do
      nil ->
        {:error, put_flash(socket, :error, "Signature not found")}

      system ->
        case Data.delete_signature(data(socket), signature, socket.assigns.character) do
          {{:ok, deleted}, data} ->
            {{dropped, linked, hidden}, data} =
              Data.sync_map_after_signature_change(data, system, [deleted])

            socket = put_data(socket, data)
            {:ok, socket |> reload_map_from_sync(dropped, linked, hidden) |> reload_signatures()}

          {{:error, _changeset}, data} ->
            {:error, put_data(socket, data)}
        end
    end
  end

  defp signature_diff_ops(before_sigs, after_sigs) do
    before_by_id = Map.new(before_sigs, &{&1.sig_id, &1})
    after_by_id = Map.new(after_sigs, &{&1.sig_id, &1})

    added =
      for {id, sig} <- after_by_id, not Map.has_key?(before_by_id, id) do
        {:add, signature_history_attrs(sig)}
      end

    deleted =
      for {id, sig} <- before_by_id, not Map.has_key?(after_by_id, id) do
        {:delete, signature_history_attrs(sig)}
      end

    updated =
      for {id, sig} <- after_by_id,
          old = Map.get(before_by_id, id),
          old != nil,
          signature_history_attrs(old) != signature_history_attrs(sig) do
        {:update, signature_history_attrs(old), signature_history_attrs(sig)}
      end

    added ++ deleted ++ updated
  end

  defp open_signature_add(socket) do
    socket
    |> assign(:sig_modal_open, true)
    |> assign(:map_modal_open, false)
    |> assign(:sig_edit_id, nil)
    |> assign(:sig_errors, [])
    |> assign(:sig_form, sig_form_for(socket, selected_system(socket), nil))
  end

  defp open_signature_edit(socket, signature) do
    socket
    |> assign(:sig_modal_open, true)
    |> assign(:map_modal_open, false)
    |> assign(:sig_edit_id, signature.id)
    |> assign(:sig_errors, [])
    |> assign(:sig_form, sig_form_for(socket, selected_system(socket), signature))
  end

  defp sig_form_for(socket, system, sig) do
    base = if sig, do: SigParser.form_from(sig), else: SigParser.default_form()
    {prefix, number} = SigParser.split_id(base["sig_id"])
    life_length = parse_integer(base["life_length"]) || SigParser.default_life_length()
    {days, hours, minutes} = SigParser.length_parts(life_length)
    {connection, far} = sig_connection(socket, system)
    {name, code} = if sig, do: SigParser.split_wormhole(sig.type_name), else: {"", ""}
    paired = if sig, do: sig_pair(socket, far, sig), else: nil

    {other_prefix, other_number} =
      if paired, do: SigParser.split_id(paired.sig_id), else: {"", ""}

    {other_name, other_code} =
      if paired, do: SigParser.split_wormhole(paired.type_name), else: {"", ""}

    base
    |> Map.merge(%{
      "site_type" => base["site_type"] || "unknown",
      "type_name" => name,
      "wormhole_code" => code,
      "prefix" => prefix,
      "number" => number,
      "days" => Integer.to_string(days),
      "hours" => Integer.to_string(hours),
      "minutes" => Integer.to_string(minutes),
      "life_status" =>
        (connection && connection.time_status) ||
          (sig && SigParser.signature_life_status(sig)) || "stable",
      "mass_status" => (connection && connection.mass_status) || "stable",
      "leads_to" => if(far, do: far.name || "", else: ""),
      "other_prefix" => other_prefix,
      "other_number" => other_number,
      "other_type_name" => other_name,
      "other_wormhole_code" => other_code
    })
    |> refresh_quick_types(socket)
  end

  defp autofill_wormhole(form, previous, params) do
    form
    |> autofill_code(previous, params, "wormhole_code", "other_wormhole_code")
    |> autofill_code(previous, params, "other_wormhole_code", "wormhole_code")
  end

  defp autofill_code(form, previous, params, key, mirror_key) do
    value = form[key] |> to_string() |> String.trim() |> String.upcase()
    previous_value = previous[key] |> to_string() |> String.upcase()

    cond do
      not Map.has_key?(params, key) ->
        form

      value == "" or value == previous_value ->
        Map.put(form, key, value)

      Wormholes.get(value) == nil and value != "????" ->
        Map.put(form, key, value)

      true ->
        form
        |> Map.put(key, value)
        |> Map.put(mirror_key, mirror_code(form[mirror_key], value))
        |> put_length_from_code(value)
    end
  end

  defp mirror_code(current, code) do
    current = current |> to_string() |> String.trim() |> String.upcase()

    cond do
      code == "K162" and Wormholes.get(current) != nil -> "????"
      code != "K162" and current in ["", "K162", "????"] -> "K162"
      true -> current
    end
  end

  defp put_length_from_code(form, code) do
    case Wormholes.life_seconds(code) do
      nil ->
        form

      seconds ->
        {days, hours, minutes} = SigParser.length_parts(seconds)

        Map.merge(form, %{
          "days" => Integer.to_string(days),
          "hours" => Integer.to_string(hours),
          "minutes" => Integer.to_string(minutes)
        })
    end
  end

  defp refresh_quick_types(form, socket) do
    system = selected_system(socket)
    source = system && Systems.display_class(system)
    target = sig_leads_class(form["leads_to"])
    codes = Wormholes.eligible_types(source, target).from

    Map.put(form, "quick_types", if(length(codes) in 1..3, do: codes, else: []))
  end

  defp sig_leads_class(value) do
    case generic_target(value) do
      nil -> nil
      {_label, class} -> class
    end
  end

  defp generic_target(value) do
    case value |> to_string() |> String.trim() |> String.downcase() do
      "class-1" -> {"Class-1", "C1"}
      "class-2" -> {"Class-2", "C2"}
      "class-3" -> {"Class-3", "C3"}
      "class-4" -> {"Class-4", "C4"}
      "class-5" -> {"Class-5", "C5"}
      "class-6" -> {"Class-6", "C6"}
      "class-13" -> {"Class-13", "C13"}
      "thera" -> {"Thera", "Thera"}
      "high-sec" -> {"High-Sec", "HS"}
      "low-sec" -> {"Low-Sec", "LS"}
      "null-sec" -> {"Null-Sec", "NS"}
      "triglavian" -> {"Triglavian", "Trig"}
      "drifter" -> {"Drifter", "Drifter"}
      _ -> nil
    end
  end

  defp leads_chips do
    [
      {"Class-1", "C1"},
      {"Class-2", "C2"},
      {"Class-3", "C3"},
      {"Class-4", "C4"},
      {"Class-5", "C5"},
      {"Class-6", "C6"},
      {"High-Sec", "HS"},
      {"Low-Sec", "LS"},
      {"Null-Sec", "NS"},
      {"Triglavian", "Trig"},
      {"Drifter", "Drifter"}
    ]
  end

  defp leads_system_options(systems, selected_id) do
    systems
    |> Enum.reject(&(&1.id == selected_id))
    |> Enum.map(& &1.name)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.sort()
  end

  defp life_choices do
    [
      {"stable", "Stable", "More than 4 hours remaining"},
      {"critical", "EOL", "End of life: less than 4 hours remaining"},
      {"<1h", "<1h", "Less than 1 hour remaining"}
    ]
  end

  defp mass_choices do
    [
      {"stable", "Stable", "More than 50% remaining"},
      {"destab", "<50%", "Less than 50% remaining"},
      {"critical", "<10%", "Less than 10% remaining"}
    ]
  end

  defp sig_connection(_socket, nil), do: {nil, nil}

  defp sig_connection(socket, %{id: system_id}) do
    Enum.find_value(socket.assigns.connections, {nil, nil}, fn {connection, from, to} ->
      cond do
        connection.from_system_id == system_id -> {connection, to}
        connection.to_system_id == system_id -> {connection, from}
        true -> nil
      end
    end)
  end

  defp sig_pair(_socket, nil, _sig), do: nil

  defp sig_pair(socket, far, sig) do
    case sig_hole_code(sig) do
      nil ->
        nil

      code ->
        data(socket)
        |> Data.list_signatures(far.id)
        |> Enum.find(&(sig_hole_code(&1) == code))
    end
  end

  defp apply_sig_links(socket, sig, params) do
    with true <- sig.site_type == "wormhole",
         %{} = system <- Data.get_system(data(socket), sig.map_system_id) do
      {connection, far} = sig_connection(socket, system)

      socket
      |> apply_signature_connection(system, connection, far, params)
      |> reload_map()
      |> apply_other_side(sig, params)
    else
      _ -> socket
    end
  end

  defp sig_target(_socket, value) when value in [nil, ""], do: nil

  defp sig_target(socket, value) do
    name = value |> to_string() |> String.trim()

    cond do
      name == "" ->
        nil

      system =
          Enum.find(
            socket.assigns.systems,
            &(String.downcase(&1.name || "") == String.downcase(name))
          ) ->
        {:system, system}

      target = generic_target(name) ->
        {:class, elem(target, 0), elem(target, 1)}

      system = Systems.Catalog.find(name) ->
        {:catalog, system.solar_system_id, system.name}

      true ->
        :invalid
    end
  end

  defp apply_signature_connection(socket, _system, nil, _far, _params), do: socket

  defp apply_signature_connection(socket, system, connection, far, params) do
    mass = params["mass_status"] || connection.mass_status || "stable"
    life = params["life_status"] || connection.time_status || "stable"

    case sig_target(socket, params["leads_to"]) do
      nil ->
        update_connection_status(socket, connection, %{mass_status: mass, time_status: life})

      :invalid ->
        socket

      {:system, target} ->
        attrs =
          cond do
            far && far.id == target.id ->
              %{mass_status: mass, time_status: life}

            connection.from_system_id == system.id ->
              %{to_system_id: target.id, mass_status: mass, time_status: life}

            true ->
              %{from_system_id: target.id, mass_status: mass, time_status: life}
          end

        update_connection_status(socket, connection, attrs)

      {:class, label, class} ->
        socket = relabel_far_system(socket, far, label, class)
        update_connection_status(socket, connection, %{mass_status: mass, time_status: life})

      {:catalog, solar, name} ->
        case Data.add_system_to_map(data(socket), socket.assigns.map, %{
               solar_system_id: solar,
               name: name
             }) do
          {{:ok, target}, data} ->
            socket = put_data(socket, data)

            attrs =
              if connection.from_system_id == system.id,
                do: %{to_system_id: target.id, mass_status: mass, time_status: life},
                else: %{from_system_id: target.id, mass_status: mass, time_status: life}

            update_connection_status(socket, connection, attrs)

          _ ->
            socket
        end
    end
  end

  defp update_connection_status(socket, connection, attrs) do
    case Data.update_connection(data(socket), connection, attrs) do
      {{:ok, _connection}, data} -> put_data(socket, data)
      _ -> socket
    end
  end

  defp relabel_far_system(socket, %{unknown: true} = far, label, class) do
    case Data.update_system(data(socket), far, %{name: label, sys_class: class}) do
      {{:ok, _system}, data} -> socket |> put_data(data) |> reload_map()
      _ -> socket
    end
  end

  defp relabel_far_system(socket, _far, _label, _class), do: socket

  defp apply_other_side(socket, sig, params) do
    other_id = SigParser.join_id(params["other_prefix"], params["other_number"])
    system = Data.get_system(data(socket), sig.map_system_id)
    {_connection, far} = sig_connection(socket, system)

    if other_id == "" or far == nil do
      socket
    else
      other_type_name =
        SigParser.join_wormhole(params["other_type_name"], params["other_wormhole_code"])

      case sig_pair(socket, far, sig) do
        nil -> create_paired_signature(socket, far, other_id, params)
        paired -> update_paired_signature(socket, paired, other_id, other_type_name)
      end
    end
  end

  defp create_paired_signature(socket, far, other_id, params) do
    attrs =
      signature_attrs(%{
        "sig_id" => other_id,
        "kind" => "signature",
        "site_type" => "wormhole",
        "type_name" => params["other_type_name"],
        "wormhole_code" => params["other_wormhole_code"],
        "life_length" => params["life_length"],
        "life_status" => params["life_status"]
      })

    case Data.create_signature(data(socket), far, attrs, socket.assigns.character) do
      {{:ok, _signature}, data} -> put_data(socket, data)
      _ -> socket
    end
  end

  defp update_paired_signature(socket, paired, other_id, other_type_name) do
    attrs = %{
      sig_id: other_id,
      site_type: "wormhole",
      type_name: other_type_name
    }

    case Data.update_signature(data(socket), paired, attrs, socket.assigns.character) do
      {{:ok, _signature}, data} -> put_data(socket, data)
      _ -> socket
    end
  end

  defp parse_integer(value) do
    case Integer.parse(to_string(value || "")) do
      {number, _} -> number
      _ -> nil
    end
  end

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

  defp reload_signatures(socket) do
    case socket.assigns.selected_system_id do
      nil -> socket
      id -> assign(socket, :signatures, Data.list_signatures(data(socket), id))
    end
  end

  defp reload_map_from_sync(socket, dropped, linked, hidden) do
    if dropped + linked + hidden == 0 do
      socket
    else
      socket =
        if dropped + hidden > 0 do
          socket = apply_tree_layout(socket, socket.assigns.map_layout || "top")
          zoom = map_zoom(socket)
          {x, y} = Mapping.home_center(socket.assigns.systems, socket.assigns.map, zoom)
          push_event(socket, "reset-pan", %{x: x, y: y, zoom: zoom})
        else
          reload_map(socket)
        end

      sync_flash(socket, dropped, linked, hidden)
    end
  end

  defp reload_map(socket) do
    map = socket.assigns.map

    socket
    |> assign(:systems, chain_systems(socket, map))
    |> assign(:connections, Data.list_connections_with_endpoints(data(socket), map.id))
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

  defp ensure_jita_system(socket, map) do
    case Data.list_systems(data(socket), map.id) do
      [] ->
        attrs = %{
          solar_system_id: 30_000_142,
          name: "Jita",
          security: 0.9,
          x: 880.0,
          y: 380.0
        }

        case Data.add_system_to_map(data(socket), map, attrs, fill?: false) do
          {{:ok, _}, data} -> put_data(socket, data)
          {_error, data} -> put_data(socket, data)
        end

      _systems ->
        socket
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
    hidden = hidden_system_ids(socket)
    visible = Enum.reject(systems, &Elixir.MapSet.member?(hidden, &1.id))

    case preferred_system(visible) do
      %{id: id, name: name} ->
        socket |> select_system(id) |> push_patch(to: "/" <> name)

      nil ->
        socket
    end
  end

  defp autoselect_first_system(%{assigns: %{selected_system_id: nil, systems: systems}} = socket)
       when is_list(systems) and systems != [] do
    case preferred_system(systems) do
      %{id: id, name: name} = system ->
        socket =
          socket
          |> assign(:selected_system_id, id)
          |> assign(:selected_system_name, name)
          |> assign(:chart_system, system)
          |> assign(:signatures, Data.list_signatures(data(socket), id))
          |> assign(:comments, Data.list_comments(data(socket), id))

        schedule_system_detail(socket, system)

      nil ->
        socket
    end
  end

  defp autoselect_first_system(socket), do: socket

  defp subscribe_to_map(socket, map_id) do
    Phoenix.PubSub.subscribe(Ztripwire.PubSub, Ztripwire.Tracking.map_topic(map_id))
    socket
  end

  defp unsubscribe_from_map(map_id) do
    Phoenix.PubSub.unsubscribe(Ztripwire.PubSub, Ztripwire.Tracking.map_topic(map_id))
  end

  defp assign_topbar_defaults(socket) do
    socket
    |> assign(:tq_online, false)
    |> assign(:tq_players, nil)
    |> assign(:current_system_name, nil)
    |> assign(:character_online, nil)
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
    |> assign(:widget_positions, Layouts.default_widgets())
    |> assign(:layouts, [])
    |> assign(:active_layout, nil)
    |> assign(:layout_name, "")
    |> assign(:layout_errors, [])
    |> assign(:line_weight, 2)
    |> assign(:node_spacing, 100)
    |> assign(:node_roundness, "oval")
    |> assign(:map_scale, 100)
    |> assign(:map_background, nil)
    |> assign(:sso_configured?, false)
    |> assign(:occupants, [])
    |> assign(:system_info, nil)
    |> assign(:chart_range, "24h")
    |> assign(:chart_hidden, MapSet.new())
    |> assign(:chart_data, %{labels: [], jumps: [], ship_kills: [], pod_kills: [], npc_kills: []})
    |> assign(:map_locked, false)
    |> assign(:collapsed_by_map, %{})
    |> assign(:undo, %{})
    |> assign(:redo, %{})
    |> assign(:map_modal_open, false)
    |> assign(:map_form, %{
      "name" => "",
      "home" => "",
      "include_thera" => false,
      "show_all" => false
    })
    |> assign(:map_errors, [])
  end

  defp toggle_visibility(socket, id, attrs_fn) do
    with {char_id, ""} <- Integer.parse(to_string(id)) do
      case Data.update_character(data(socket), char_id, attrs_fn) do
        {{:ok, updated}, data} ->
          socket = put_data(socket, data)

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

        {{:error, _}, data} ->
          {:noreply, socket |> put_data(data) |> put_flash(:error, "Character not found")}
      end
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

  defp request_topbar_data(socket) do
    if topbar_esi_enabled?() do
      pid = self()
      character = socket.assigns.character
      characters = socket.assigns.characters
      Task.start(fn -> send(pid, {:topbar_loaded, fetch_topbar_data(character, characters)}) end)
    end

    socket
  end

  defp schedule_chart_refresh(socket \\ nil) do
    if is_nil(socket) || connected?(socket) do
      Process.send_after(self(), :refresh_chart, @chart_refresh_ms)
    end

    socket
  end

  defp topbar_esi_enabled? do
    Application.get_env(:ztripwire, :topbar_esi, true)
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
      Ztripwire.Log.emit(:warning, %{
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

  defp schedule_system_detail(socket, nil), do: socket

  defp schedule_system_detail(socket, system) do
    if connected?(socket) do
      pid = self()
      solar_system_id = system.solar_system_id
      range = socket.assigns[:chart_range] || "24h"

      Task.start(fn ->
        send(pid, {:system_info_loaded, solar_system_id, Ztripwire.Systems.fetch_info(system)})
      end)

      Task.start(fn ->
        send(pid, {:chart_data_loaded, solar_system_id, range, chart_data_for(system, range)})
      end)
    end

    socket
  end

  defp schedule_chart_reload(socket) do
    if connected?(socket) and socket.assigns[:chart_system] do
      pid = self()
      system = socket.assigns.chart_system
      solar_system_id = system.solar_system_id
      range = socket.assigns[:chart_range] || "24h"

      Task.start(fn ->
        send(pid, {:chart_data_loaded, solar_system_id, range, chart_data_for(system, range)})
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

  defp chart_data_for(system, range) do
    labels = range_labels(range)
    width = bucket_width_hours(range)
    now = DateTime.utc_now()

    {ship_kills, pod_kills} =
      if Ztripwire.Systems.esi_resolvable?(system) do
        since = DateTime.add(now, -length(labels) * width * 3600, :second)

        case Ztripwire.ZKill.kill_history(system.solar_system_id, since: since) do
          {:ok, kills} -> Ztripwire.ZKill.bucket(kills, now, length(labels), width)
          {:error, _} -> {List.duplicate(0, length(labels)), List.duplicate(0, length(labels))}
        end
      else
        {List.duplicate(0, length(labels)), List.duplicate(0, length(labels))}
      end

    {jumps, npc_kills} =
      if Ztripwire.Systems.esi_resolvable?(system) do
        activity = Ztripwire.ESI.system_activity(system.solar_system_id)
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

  defp flash_changeset_errors(socket, changeset) do
    put_flash(socket, :error, changeset_message(changeset))
  end
end
