defmodule TripwireWeb.DashboardLive do
  use TripwireWeb, :live_view

  alias Tripwire.Accounts
  alias Tripwire.Mapping
  alias Tripwire.Masks
  alias Tripwire.Signatures, as: SigParser

  @demo_users ~w(Admin User)
  @demo_eve_ids %{"Admin" => 9_000_001, "User" => 9_000_002}

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
     |> assign(:systems, Mapping.list_systems(map.id))
     |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
     |> assign(:selected_system_id, nil)
     |> assign(:signatures, [])
     |> assign(:comments, [])
     |> assign(:paste_open, false)
     |> assign(:paste_text, "")
     |> assign(:settings_open, false)
     |> assign(:settings_tab, "account")
     |> assign(:map_layout, "default")
     |> assign(:undo, [])
     |> assign(:redo, [])
     |> assign(:demo?, true)
     |> subscribe_to_map(map.id)}
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
  def handle_params(%{"user" => _user}, _url, socket), do: {:noreply, socket}

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
     |> assign(:signatures, Mapping.list_signatures(system_id))
     |> assign(:comments, Mapping.list_comments(system_id))
     |> assign(:undo, [])
     |> assign(:redo, [])}
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
    {:noreply, put_flash(socket, :info, "#{name} jumped into #{system.name}")}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle-settings", _params, socket) do
    {:noreply, update(socket, :settings_open, &(!&1))}
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
     |> assign(:signatures, Mapping.list_signatures(system_id))
     |> assign(:comments, Mapping.list_comments(system_id))
     |> assign(:undo, [])
     |> assign(:redo, [])}
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

  def handle_event("toggle-paste", _params, socket) do
    {:noreply, update(socket, :paste_open, &(!&1))}
  end

  def handle_event("paste-update", %{"value" => value}, socket) do
    {:noreply, assign(socket, :paste_text, value)}
  end

  def handle_event("paste-submit", _params, socket) do
    with system when not is_nil(system) <- selected_system(socket),
         entries <- SigParser.parse_paste(socket.assigns.paste_text),
         false <- entries == [],
         {added, updated} <-
           Mapping.upsert_signatures(system, entries, socket.assigns.character) do
      {:noreply,
       socket
       |> assign(:paste_text, "")
       |> assign(:paste_open, false)
       |> reload_signatures()
       |> put_flash(
         :info,
         "Parsed #{added + updated} signatures (#{added} new, #{updated} known)"
       )}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "Select a system first")}

      true ->
        {:noreply, put_flash(socket, :error, "No signatures found in paste")}

      _invalid ->
        {:noreply, put_flash(socket, :error, "Could not save signatures")}
    end
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

    map =
      case Mapping.list_maps_for_mask(mask.id) do
        [] -> elem(Mapping.create_map(%{name: "Home", mask_id: mask.id}), 1)
        [map | _] -> map
      end

    socket
    |> assign(:current_user, %{id: character.eve_id, name: character.name})
    |> assign(:nav_user, character.name)
    |> assign(:character, character)
    |> assign(:characters, [character])
    |> assign(:mask, mask)
    |> assign(:masks, [mask | Masks.list_masks_for_character(character.id)])
    |> assign(:map, map)
    |> assign(:systems, Mapping.list_systems(map.id))
    |> assign(:connections, Mapping.list_connections_with_endpoints(map.id))
    |> assign(:selected_system_id, nil)
    |> assign(:signatures, [])
    |> assign(:comments, [])
    |> assign(:paste_open, false)
    |> assign(:paste_text, "")
    |> assign(:settings_open, false)
    |> assign(:map_layout, "default")
    |> assign(:undo, [])
    |> assign(:redo, [])
    |> assign(:demo?, false)
    |> subscribe_to_map(map.id)
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
              type_name: signature.type_name
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

  defp reload_signatures(socket) do
    case socket.assigns.selected_system_id do
      nil -> socket
      id -> assign(socket, :signatures, Mapping.list_signatures(id))
    end
  end

  defp subscribe_to_map(socket, map_id) do
    Phoenix.PubSub.subscribe(Tripwire.PubSub, Tripwire.Tracking.map_topic(map_id))
    socket
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

  defp sig_attrs(params) do
    %{
      sig_id: params["sig_id"],
      kind: params["kind"] || "signature",
      type_name: present(params["type_name"])
    }
  end

  defp present(""), do: nil
  defp present(value), do: value

  defp coord(value) when is_binary(value) do
    {number, ""} = Integer.parse(value)
    number * 1.0
  end

  defp coord(number) when is_number(number), do: number * 1.0
end
