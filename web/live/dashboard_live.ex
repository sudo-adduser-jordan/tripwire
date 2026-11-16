defmodule TripwireWeb.DashboardLive do
  use TripwireWeb, :live_view

  alias Tripwire.Accounts
  alias Tripwire.ESI
  alias Tripwire.Mapping
  alias Tripwire.Masks
  alias Tripwire.Signatures, as: SigParser

  @demo_users ~w(Admin User)
  @demo_eve_ids %{"Admin" => 9_000_001, "User" => 9_000_002}
  @topbar_refresh_ms 60_000

  @impl true
  def mount(%{"user" => user} = _params, _session, socket) when user in @demo_users do
    {:ok, character} =
      Accounts.upsert_character(%{eve_id: Map.fetch!(@demo_eve_ids, user), name: user})

    {:ok, mask} = Masks.ensure_demo_mask()
    {:ok, _} = Masks.add_membership(mask, character)
    {:ok, map} = Mapping.ensure_demo_map(mask.id)

    {:ok,
     socket
     |> assign(:current_user, nil)
     |> assign(:nav_user, user)
     |> assign(:character, character)
     |> assign(:characters, [character])
     |> assign(:mask, mask)
     |> assign(:masks, [mask])
     |> assign(:map, map)
     |> assign(:maps, Mapping.list_maps_for_mask(mask.id))
     |> assign(:systems, Mapping.list_systems(map.id))
     |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
     |> assign(:selected_system_id, nil)
     |> assign(:selected_system_name, nil)
     |> assign(:signatures, [])
     |> assign(:comments, [])
     |> autoselect_first_system()
     |> assign(:stale_ids, [])
     |> assign(:stale_system_id, nil)
     |> assign(:settings_open, false)
     |> assign(:settings_tab, "account")
     |> assign(:map_layout, "default")
     |> assign(:undo, [])
     |> assign(:redo, [])
     |> assign(:demo?, true)
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
     |> subscribe_to_map(map.id)
     |> schedule_topbar_load()}
  end

  def mount(_params, session, socket) do
    case session["current_user"] do
      %{"id" => eve_id} ->
        character = Accounts.get_character_by_eve_id(eve_id)

        cond do
          is_nil(character) ->
            {:ok,
             put_flash(socket, :error, "Character not found, please log in again")
             |> push_navigate(to: ~p"/")}

          true ->
            {:ok, provision(socket, character)}
        end

      _ ->
        {:ok,
         put_flash(socket, :error, "Please log in to view your dashboard")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    system_name = Map.get(params, "system")

    socket =
      if system_name && socket.assigns[:systems] do
        case Enum.find(
               socket.assigns.systems,
               &(String.downcase(&1.name) == String.downcase(system_name))
             ) do
          %{id: id, name: name} ->
            socket
            |> assign(:selected_system_id, id)
            |> assign(:selected_system_name, name)
            |> assign(:signatures, Mapping.list_signatures(id))
            |> assign(:comments, Mapping.list_comments(id))

          nil ->
            socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:map_updated, map_id}, %{assigns: %{map: map}} = socket)
      when not is_nil(map) and map_id == map.id do
    {:noreply,
     socket
     |> assign(:systems, Mapping.list_systems(map_id))
     |> assign(:connections, Mapping.list_connections_with_endpoints(map_id))}
  end

  def handle_info({:select_system, system_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_system_id, system_id)
     |> assign(:selected_system_name, selected_system_name(socket.assigns.systems, system_id))
     |> assign(:signatures, Mapping.list_signatures(system_id))
     |> assign(:comments, Mapping.list_comments(system_id))
     |> assign(:flares, Mapping.list_flares(system_id))
     |> assign(:system_stat, Mapping.get_system_stat(system_id))
     |> assign(:stale_ids, [])
     |> assign(:stale_system_id, nil)
     |> assign(:undo, [])
     |> assign(:redo, [])
     |> assign(:sys_form, sys_form_for(socket.assigns.systems, system_id))}
  end

  def handle_info({:open_connection, conn_id}, socket) do
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
     |> assign(:systems, Mapping.list_systems(map_id))
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
    socket =
      if socket.assigns.nav_user == name do
        assign(socket, :current_system_name, system.name)
      else
        socket
      end

    {:noreply, put_flash(socket, :info, "#{name} jumped into #{system.name}")}
  end

  def handle_info(:load_topbar, socket) do
    if topbar_esi_enabled?() do
      pid = self()
      character = socket.assigns.character
      Task.start(fn -> send(pid, {:topbar_loaded, fetch_topbar_data(character)}) end)
    end

    schedule_topbar_refresh()
    {:noreply, socket}
  end

  def handle_info(:refresh_topbar, socket) do
    if topbar_esi_enabled?() do
      pid = self()
      character = socket.assigns.character
      Task.start(fn -> send(pid, {:topbar_loaded, fetch_topbar_data(character)}) end)
    end

    schedule_topbar_refresh()
    {:noreply, socket}
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
     |> assign(:ship_name, data.ship_name)
     |> assign(:topbar_now, data.now)}
  end

  def handle_info({:new_map}, socket), do: handle_event("new-map", %{}, socket)

  def handle_info({:switch_map, map_id}, socket),
    do: handle_event("switch-map", %{"id" => to_string(map_id)}, socket)

  def handle_info({:add_viewing}, socket), do: handle_event("add-viewing", %{}, socket)

  def handle_info({:toggle_lock}, socket), do: handle_event("toggle-lock", %{}, socket)

  def handle_info({:map_layout, layout}, socket),
    do: handle_event("map-layout", %{"layout" => layout}, socket)

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle-settings", _params, socket) do
    {:noreply, update(socket, :settings_open, &(!&1))}
  end

  def handle_event("toggle-grid-lock", _params, socket) do
    {:noreply, update(socket, :grid_locked, &(!&1))}
  end

  def handle_event("system-search-submit", %{"search" => search}, socket) do
    trimmed = String.trim(search || "")

    system =
      Enum.find(socket.assigns.systems, fn s ->
        String.downcase(s.name) == String.downcase(trimmed)
      end)

    socket = assign(socket, :system_search, search)

    if system do
      {:noreply,
       socket
       |> assign(:selected_system_id, system.id)
       |> assign(:selected_system_name, system.name)
       |> assign(:signatures, Mapping.list_signatures(system.id))
       |> assign(:comments, Mapping.list_comments(system.id))
       |> assign(:stale_ids, [])
       |> assign(:stale_system_id, nil)
       |> assign(:undo, [])
       |> assign(:redo, [])}
    else
      {:noreply, put_flash(socket, :error, "No system matching #{inspect(trimmed)} on this map")}
    end
  end

  def handle_event("settings-tab", %{"tab" => tab}, socket)
      when tab in ~w(account map widgets themes) do
    {:noreply, assign(socket, :settings_tab, tab)}
  end

  def handle_event("settings-tab", _params, socket), do: {:noreply, socket}

  def handle_event("select-system", %{"id" => id}, socket) do
    system_id = String.to_integer(id)

    {:noreply,
     socket
     |> assign(:selected_system_id, system_id)
     |> assign(:selected_system_name, selected_system_name(socket.assigns.systems, system_id))
     |> assign(:signatures, Mapping.list_signatures(system_id))
     |> assign(:comments, Mapping.list_comments(system_id))
     |> assign(:flares, Mapping.list_flares(system_id))
     |> assign(:system_stat, Mapping.get_system_stat(system_id))
     |> assign(:stale_ids, [])
     |> assign(:stale_system_id, nil)
     |> assign(:undo, [])
     |> assign(:redo, [])
     |> assign(:sys_form, sys_form_for(socket.assigns.systems, system_id))}
  end

  def handle_event("move-system", %{"id" => id, "x" => x, "y" => y}, socket) do
    system = Mapping.get_system!(String.to_integer(id))

    {:ok, moved} =
      Mapping.update_system_position(system, coord(x), coord(y))

    systems =
      Enum.map(socket.assigns.systems, fn s ->
        if s.id == moved.id, do: %{s | x: moved.x, y: moved.y}, else: s
      end)

    {:noreply,
     socket
     |> assign(:systems, systems)
     |> assign(:connections, Mapping.list_connections_with_endpoints(socket.assigns.map.id))}
  end

  def handle_event("map-layout", %{"layout" => "default"}, socket),
    do: {:noreply, assign(socket, :map_layout, "default")}

  def handle_event("map-layout", %{"layout" => layout}, socket)
      when layout in ~w(top bottom left right radial) do
    {:noreply, socket |> assign(:map_layout, layout) |> apply_tree_layout(layout)}
  end

  def handle_event("map-layout", _params, socket), do: {:noreply, socket}

  def handle_event("global-paste", params, socket) do
    text = Map.get(params, "text", "") |> to_string()

    with system when not is_nil(system) <- selected_system(socket),
         entries when entries != [] <- SigParser.parse_paste(text) do
      before_ids =
        system.id |> Mapping.list_signatures() |> Enum.map(& &1.sig_id) |> MapSet.new()

      pasted_ids = entries |> Enum.map(& &1.sig_id) |> MapSet.new()

      {added, updated} = Mapping.upsert_signatures(system, entries, socket.assigns.character)

      missing = before_ids |> MapSet.difference(pasted_ids) |> Enum.sort()

      {:noreply,
       socket
       |> assign(:stale_ids, missing)
       |> assign(:stale_system_id, if(missing == [], do: nil, else: system.id))
       |> reload_signatures()
       |> put_flash(
         :info,
         "Parsed #{added + updated} signatures (#{added} new, #{updated} known)"
       )}
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a system first")}
      [] -> {:noreply, socket}
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

        system_id
        |> Mapping.list_signatures()
        |> Enum.filter(&MapSet.member?(stale_set, &1.sig_id))
        |> Enum.each(&Mapping.delete_signature/1)

        {:noreply,
         socket
         |> assign(:stale_ids, [])
         |> assign(:stale_system_id, nil)
         |> reload_signatures()
         |> put_flash(:info, "Deleted #{length(stale_ids)} missing signatures")}
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
      case socket.assigns.sig_edit_id do
        nil ->
          case Mapping.create_signature(system, sig_attrs(params), socket.assigns.character) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(:sig_modal_open, false)
               |> assign(:sig_edit_id, nil)
               |> assign(:sig_errors, [])
               |> reload_signatures()
               |> put_flash(:info, "Signature added")}

            {:error, changeset} ->
              {:noreply, assign(socket, :sig_errors, changeset_errors(changeset))}
          end

        id ->
          sig = Mapping.get_signature!(id)

          case Mapping.update_signature(sig, sig_attrs(params), socket.assigns.character) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(:sig_modal_open, false)
               |> assign(:sig_edit_id, nil)
               |> assign(:sig_errors, [])
               |> reload_signatures()
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
    {:ok, deleted} = Mapping.delete_signature(signature)

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

  def handle_event("update-system", %{"system" => params}, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        attrs = %{
          alias: present(params["alias"]),
          locked: params["locked"] in ["true", "on", true]
        }

        case Mapping.update_system(system, attrs) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:systems, Mapping.list_systems(socket.assigns.map.id))
             |> assign(:sys_form, %{"alias" => attrs.alias || "", "locked" => attrs.locked})
             |> put_flash(:info, "System updated")}

          {:error, changeset} ->
            {:noreply, flash_changeset_errors(socket, changeset)}
        end
    end
  end

  def handle_event("delete-system", _params, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        {:ok, _} = Mapping.delete_system(system)

        {:noreply,
         socket
         |> assign(:systems, Mapping.list_systems(socket.assigns.map.id))
         |> assign(:connections, Mapping.list_connections_with_endpoints(socket.assigns.map.id))
         |> assign(:selected_system_id, nil)
         |> assign(:selected_system_name, nil)
         |> assign(:signatures, [])
         |> assign(:comments, [])
         |> put_flash(:info, "System removed")}
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
          {:ok, _} ->
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
         |> assign(:systems, Mapping.list_systems(map.id))
         |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
         |> assign(:selected_system_id, nil)
         |> assign(:selected_system_name, nil)
         |> assign(:signatures, [])
         |> assign(:comments, [])
         |> assign(:flares, [])
         |> assign(:system_stat, nil)
         |> put_flash(:info, "Switched to #{mask.name}")}
    end
  end

  def handle_event("new-map", _params, socket) do
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
         |> assign(:signatures, [])
         |> assign(:comments, [])
         |> assign(:flares, [])
         |> assign(:system_stat, nil)
         |> put_flash(:info, "Created #{name}")}

      {:error, changeset} ->
        {:noreply, flash_changeset_errors(socket, changeset)}
    end
  end

  def handle_event("switch-map", %{"id" => id}, socket) do
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
         |> assign(:systems, Mapping.list_systems(map.id))
         |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
         |> assign(:selected_system_id, nil)
         |> assign(:selected_system_name, nil)
         |> assign(:signatures, [])
         |> assign(:comments, [])
         |> assign(:flares, [])
         |> assign(:system_stat, nil)
         |> put_flash(:info, "Switched to #{map.name}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Map not found")}
    end
  rescue
    _ -> {:noreply, put_flash(socket, :error, "Map not found")}
  end

  def handle_event("add-viewing", _params, socket) do
    with %{refresh_token: token} when not is_nil(token) <- socket.assigns.character,
         {:ok, access} <- ESI.valid_access_token(socket.assigns.character),
         {:ok, %{"solar_system_id" => solar_system_id}} <-
           ESI.get_character_location(socket.assigns.character.eve_id, access),
         prev = selected_system(socket),
         {:ok, %{system: system}} <-
           Tripwire.Tracking.apply_location_change(
             socket.assigns.map,
             socket.assigns.nav_user || socket.assigns.character.name,
             prev,
             solar_system_id
           ) do
      {:noreply,
       socket
       |> assign(:systems, Mapping.list_systems(socket.assigns.map.id))
       |> assign(:connections, Mapping.list_connections_with_endpoints(socket.assigns.map.id))
       |> assign(:selected_system_id, system.id)
       |> assign(:selected_system_name, system.name)
       |> assign(:signatures, Mapping.list_signatures(system.id))
       |> assign(:comments, Mapping.list_comments(system.id))
       |> assign(:flares, Mapping.list_flares(system.id))
       |> assign(:system_stat, Mapping.get_system_stat(system.id))
       |> put_flash(:info, "Added viewing system #{system.name}")}
    else
      _ -> {:noreply, put_flash(socket, :error, "ESI location unavailable")}
    end
  end

  def handle_event("toggle-lock", _params, socket) do
    case selected_system(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      system ->
        case Mapping.update_system(system, %{locked: !system.locked}) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:systems, Mapping.list_systems(socket.assigns.map.id))
             |> put_flash(:info, if(system.locked, do: "Unlocked", else: "Locked"))}

          {:error, changeset} ->
            {:noreply, flash_changeset_errors(socket, changeset)}
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
    occupants =
      if socket.assigns.map, do: Tripwire.Tracking.list_occupants(socket.assigns.map.id), else: []

    {:noreply, assign(socket, :occupants, occupants)}
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
        case Mapping.move_comment(comment, system.id) do
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
          socket.assigns.nav_user || (socket.assigns.character && socket.assigns.character.name) ||
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

  defp apply_tree_layout(%{assigns: %{map: map}} = socket, layout) when not is_nil(map) do
    positions = layout_positions(socket.assigns.systems, socket.assigns.connections, layout)

    Enum.each(socket.assigns.systems, fn s ->
      pos = positions[s.id]
      {:ok, _} = Mapping.update_system_position(Mapping.get_system!(s.id), pos.x, pos.y)
    end)

    socket
    |> assign(:systems, Mapping.list_systems(map.id))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
  end

  # "top"/"bottom"/"left"/"right" name the side the tree is anchored to.
  defp normalize_layout("top"), do: "down"
  defp normalize_layout("bottom"), do: "up"
  defp normalize_layout("left"), do: "right"
  defp normalize_layout("right"), do: "left"

  defp layout_positions(systems, connections, "radial"),
    do: Mapping.radial_layout(systems, connections)

  defp layout_positions(systems, connections, layout),
    do: Mapping.tree_layout(systems, connections, normalize_layout(layout))

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

    socket
    |> assign(:current_user, %{id: character.eve_id, name: character.name})
    |> assign(:nav_user, character.name)
    |> assign(:character, character)
    |> assign(:characters, [character])
    |> assign(:mask, mask)
    |> assign(:masks, masks)
    |> assign(:map, map)
    |> assign(:maps, Mapping.list_maps_for_mask(mask.id))
    |> assign(:systems, Mapping.list_systems(map.id))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
    |> assign(:selected_system_id, nil)
    |> assign(:selected_system_name, nil)
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> autoselect_first_system()
    |> assign(:stale_ids, [])
    |> assign(:stale_system_id, nil)
    |> assign(:settings_open, false)
    |> assign(:map_layout, "default")
    |> assign(:undo, [])
    |> assign(:redo, [])
    |> assign(:demo?, false)
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
    |> subscribe_to_map(map.id)
    |> schedule_topbar_load()
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

  defp sys_form_for(systems, id) do
    case Enum.find(systems, &(&1.id == id)) do
      %{alias: alias_, locked: locked} -> %{"alias" => alias_ || "", "locked" => locked || false}
      _ -> %{"alias" => "", "locked" => false}
    end
  end

  defp reload_signatures(socket) do
    case socket.assigns.selected_system_id do
      nil -> socket
      id -> assign(socket, :signatures, Mapping.list_signatures(id))
    end
  end

  defp autoselect_first_system(
         %{assigns: %{selected_system_id: nil, systems: [%{id: id, name: name} | _]}} = socket
       ) do
    socket
    |> assign(:selected_system_id, id)
    |> assign(:selected_system_name, name)
    |> assign(:signatures, Mapping.list_signatures(id))
    |> assign(:comments, Mapping.list_comments(id))
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
    |> assign(:ship_name, nil)
    |> assign(:topbar_now, DateTime.utc_now())
    |> assign(:grid_locked, true)
    |> assign(:system_search, "")
    |> assign(:conn_modal_open, false)
    |> assign(:conn_edit_id, nil)
    |> assign(:conn_form, %{
      "hole_type" => "",
      "mass_status" => "stable",
      "time_status" => "stable",
      "ship_size" => ""
    })
    |> assign(:conn_errors, [])
    |> assign(:sys_form, %{"alias" => "", "locked" => false})
    |> assign(:occupants, [])
    |> assign(:flares, [])
    |> assign(:system_stat, nil)
  end

  defp schedule_topbar_load(socket) do
    if connected?(socket), do: send(self(), :load_topbar)
    socket
  end

  defp schedule_topbar_refresh do
    Process.send_after(self(), :refresh_topbar, @topbar_refresh_ms)
  end

  defp topbar_esi_enabled? do
    Application.get_env(:tripwire, :topbar_esi, true)
  end

  defp fetch_topbar_data(character) do
    {tq_online, tq_players} =
      case ESI.get_status() do
        {:ok, %{"players" => players}} -> {true, players}
        _ -> {false, nil}
      end

    {current_system_name, character_online, ship_name} = fetch_character_presence(character)

    %{
      tq_online: tq_online,
      tq_players: tq_players,
      current_system_name: current_system_name,
      character_online: character_online,
      ship_name: ship_name,
      now: DateTime.utc_now()
    }
  end

  defp fetch_character_presence(nil), do: {nil, nil, nil}
  defp fetch_character_presence(%{refresh_token: nil}), do: {nil, nil, nil}

  defp fetch_character_presence(character) do
    with {:ok, token} <- ESI.valid_access_token(character),
         {:ok, location} <- ESI.get_character_location(character.eve_id, token) do
      online =
        case ESI.get_character_online(character.eve_id, token) do
          {:ok, %{"online" => online}} -> online
          _ -> nil
        end

      ship =
        case ESI.get_character_ship(character.eve_id, token) do
          {:ok, %{"ship_name" => name}} -> name
          _ -> nil
        end

      system_name =
        case location do
          %{"solar_system_id" => id} ->
            case ESI.get_system(id) do
              {:ok, %{"name" => name}} -> name
              _ -> nil
            end

          _ ->
            nil
        end

      {system_name, online, ship}
    else
      _ -> {nil, nil, nil}
    end
  rescue
    _ -> {nil, nil, nil}
  end

  defp push_undo(socket, op), do: update(socket, :undo, &[op | &1])

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
    _ = Mapping.delete_signature(signature)
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
    %{
      sig_id: params["sig_id"],
      kind: params["kind"] || "signature",
      site_type: params["site_type"] || "unknown",
      type_name: present(params["type_name"]),
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

  defp coord(value) when is_binary(value) do
    {number, ""} = Integer.parse(value)
    number * 1.0
  end

  defp coord(number) when is_number(number), do: number * 1.0
end
