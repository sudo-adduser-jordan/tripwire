defmodule TripwireWeb.LiveComponents.SignaturesLive do
  use TripwireWeb, :live_component

  alias Tripwire.Mapping
  alias Tripwire.Signatures, as: SigParser

  def update(assigns, socket) do
    signatures =
      case {Map.get(assigns, :signatures), Map.get(assigns, :selected_system_id)} do
        {sigs, _} when is_list(sigs) -> sigs
        {_, nil} -> []
        {_, system_id} -> Mapping.list_signatures(system_id)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:signatures, signatures)
     |> assign(:wh_links, wh_links(Map.get(assigns, :connections, [])))
     |> assign(:wh_mass, wh_mass(Map.get(assigns, :connections, [])))
     |> assign(:tracking?, tracking?(assigns))
     |> assign(:tracking_available?, tracking_available?(assigns))
     |> assign_new(:undo, fn -> [] end)
     |> assign_new(:redo, fn -> [] end)}
  end

  # Maps {system_id, hole code} to the system the connection leads to, so a
  # scanned wormhole signature can be labelled with its destination like in
  # official Tripwire.
  defp wh_links(connections) do
    Enum.flat_map(connections, fn {conn, from, to} ->
      case hole_code(conn.hole_type) do
        nil -> []
        code -> [{{from.id, code}, dest_name(to)}, {{to.id, code}, dest_name(from)}]
      end
    end)
    |> Map.new()
  end

  defp hole_code(nil), do: nil

  defp hole_code(code) do
    case Regex.run(~r/^([A-Z][0-9]{3})$/, String.upcase(to_string(code))) do
      [_, code] -> code
      _ -> nil
    end
  end

  defp wh_mass(connections) do
    Enum.reduce(connections, %{}, fn {conn, from, to}, acc ->
      case hole_code(conn.hole_type) do
        nil ->
          acc

        code ->
          mass = conn.mass_status || "stable"

          acc
          |> Map.put({from.id, code}, mass)
          |> Map.put({to.id, code}, mass)
      end
    end)
  end

  defp mass_for(%{site_type: "wormhole"} = sig, wh_mass) do
    Map.get(wh_mass, {sig.map_system_id, SigParser.wormhole_code(sig.type_name)})
  end

  defp mass_for(_sig, _wh_mass), do: nil

  defp mass_label(nil), do: "-"
  defp mass_label("stable"), do: "Stable"
  defp mass_label("destab"), do: "Destab"
  defp mass_label("critical"), do: "Critical"
  defp mass_label(other), do: to_string(other)

  defp mass_text_class("stable"), do: "opacity-60"
  defp mass_text_class("destab"), do: "text-warning"
  defp mass_text_class("critical"), do: "text-error"
  defp mass_text_class(_), do: "opacity-40"

  defp dest_name(system), do: system.alias || system.name

  def handle_event("add-signature", %{"sig" => params}, socket) do
    with system when not is_nil(system) <- selected_system(socket),
         {:ok, _} <- Mapping.create_signature(system, sig_attrs(params), socket.assigns.character) do
      send(self(), {:signatures_updated, system.id})
      {:noreply, socket |> assign(:signatures, Mapping.list_signatures(system.id))}
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a system first")}
      {:error, changeset} -> {:noreply, put_flash(socket, :error, changeset_errors(changeset))}
    end
  end

  def handle_event("delete-signature", %{"id" => id}, socket) do
    signature = Mapping.get_signature!(id)
    {:ok, deleted} = Mapping.delete_signature(signature, socket.assigns.character)
    undo = [{:delete, deleted} | socket.assigns.undo]

    system = Mapping.get_system!(deleted.map_system_id)
    {dropped, linked, hidden} = Mapping.sync_map_after_signature_change(system, [deleted])

    send(self(), {:signatures_updated, deleted.map_system_id})
    send_map_update(system, dropped, linked, hidden)

    {:noreply,
     socket
     |> assign(:undo, undo)
     |> assign(:signatures, Mapping.list_signatures(deleted.map_system_id))}
  end

  def handle_event("undo", _params, socket) do
    case socket.assigns.undo do
      [] ->
        {:noreply, socket}

      [{:delete, signature} | rest] ->
        case selected_system(socket) do
          nil ->
            {:noreply, put_flash(socket, :error, "Select a system before undoing")}

          system ->
            {:ok, restored} =
              Mapping.create_signature(
                system,
                %{sig_id: signature.sig_id, kind: signature.kind, type_name: signature.type_name},
                socket.assigns.character
              )

            redo = [{:delete, restored} | socket.assigns.redo]
            {dropped, linked, hidden} = Mapping.sync_map_after_signature_change(system, [])

            send(self(), {:signatures_updated, system.id})
            send_map_update(system, dropped, linked, hidden)

            {:noreply,
             socket
             |> assign(:undo, rest)
             |> assign(:redo, redo)
             |> assign(:signatures, Mapping.list_signatures(system.id))}
        end
    end
  end

  def handle_event("redo", _params, socket) do
    case socket.assigns.redo do
      [] ->
        {:noreply, socket}

      [{:delete, signature} | rest] ->
        {:ok, deleted} = Mapping.delete_signature(signature, socket.assigns.character)
        undo = [{:delete, signature} | socket.assigns.undo]

        system = Mapping.get_system!(deleted.map_system_id)
        {dropped, linked, hidden} = Mapping.sync_map_after_signature_change(system, [deleted])

        send(self(), {:signatures_updated, deleted.map_system_id})
        send_map_update(system, dropped, linked, hidden)

        {:noreply,
         socket
         |> assign(:redo, rest)
         |> assign(:undo, undo)
         |> assign(:signatures, Mapping.list_signatures(deleted.map_system_id))}
    end
  end

  def handle_event("toggle-tracker", _params, socket) do
    case socket.assigns do
      %{character: %{} = character, tracking?: true} ->
        _ = Tripwire.Tracking.stop_poller(character)
        {:noreply, assign(socket, :tracking?, false)}

      %{character: %{} = character, tracking_available?: true} ->
        _ = Tripwire.Tracking.ensure_poller(character)
        {:noreply, assign(socket, :tracking?, true)}

      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div id={@id} class="grid-stack-item" gs-w="12" gs-h="6" gs-x="0" gs-y="6" tabindex="0">
      <div class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden">
        <div class="shrink-0">
          <ul class="list rounded-box shadow-md">
            <li class="flex items-center gap-1 p-1">
              <button
                class="btn btn-ghost btn-xs"
                title="Add signature"
                phx-click="open-add"
              >
                <.icon name="hero-plus" class="size-4" />
              </button>
              <button
                class="btn btn-ghost btn-xs"
                title="Undo"
                phx-click="undo"
                phx-target={@myself}
              >
                <.icon name="hero-arrow-uturn-left" class="size-4" />
              </button>
              <button
                class="btn btn-ghost btn-xs"
                title="Redo"
                phx-click="redo"
                phx-target={@myself}
              >
                <.icon name="hero-arrow-uturn-right" class="size-4" />
              </button>
              <span class="ml-auto text-xs tabular-nums opacity-60">
                {length(@signatures)} signatures
              </span>
              <button
                class={[
                  "btn btn-ghost btn-xs",
                  if(@tracking?, do: "btn-primary text-base-content"),
                  if(not @tracking_available?, do: "btn-disabled")
                ]}
                disabled={!@tracking_available?}
                title={
                  cond do
                    @tracking? -> "Stop auto-tracking this character"
                    @tracking_available? -> "Auto-track this character"
                    true -> "Sign in with EVE SSO to enable auto-tracking"
                  end
                }
                phx-click="toggle-tracker"
                phx-target={@myself}
              >
                <span class={[
                  "flex size-4 items-center justify-center rounded-sm border text-[10px] font-bold leading-none",
                  if(@tracking?,
                    do: "border-primary bg-primary text-primary-content",
                    else: "border-current"
                  )
                ]}>
                  A
                </span>
              </button>
              <span
                :if={Map.get(assigns, :selected_system_name)}
                class="badge badge-primary badge-sm"
              >
                {Map.get(assigns, :selected_system_name)}
              </span>
              <span :if={!Map.get(assigns, :selected_system_name)} class="text-xs opacity-60">
                {system_label(@selected_system_id)}
              </span>
            </li>
          </ul>
        </div>
        <div class="min-h-0 w-full max-w-full flex-1 overflow-auto">
          <table class="widget-table table table-xs w-full">
            <thead class="sticky top-0 z-10 bg-base-100">
              <tr>
                <th class="p-1"></th>
                <th class="p-1 text-center text-xs">ID</th>
                <th class="p-1 text-center text-xs">Type</th>
                <th class="p-1 text-center text-xs">Name</th>
                <th class="p-1 text-center text-xs">Mass</th>
                <th class="p-1 text-center text-xs">Age</th>
                <th class="p-1 text-center text-xs">Life</th>
                <th class="p-1 text-center text-xs"><span class="sr-only">Actions</span></th>
              </tr>
            </thead>
            <tbody class="text-center">
              <tr :for={sig <- @signatures} id={"signature-#{sig.id}"}>
                <td class="text-center">
                  <.icon name={scan_icon(sig)} class={["size-4", scan_icon_class(sig)]} />
                </td>
                <td class="text-center">
                  <button
                    class="font-mono link link-hover"
                    title="Edit signature"
                    phx-click="open-edit"
                    phx-value-id={sig.id}
                  >
                    {sig.sig_id}
                  </button>
                </td>
                <td class="text-center">
                  <span class={["badge badge-xs", site_badge(sig)]}>{site_label(sig)}</span>
                </td>
                <td class="cell-truncate text-center">
                  <span
                    :if={wormhole_display(sig)}
                    class="inline-flex items-center justify-center gap-1.5"
                    title={sig.type_name}
                  >
                    <span class="inline-block size-2 shrink-0 rounded-full bg-info"></span>
                    {wormhole_label(sig, @wh_links)}
                  </span>
                  <a
                    :if={is_nil(wormhole_display(sig)) and sig_link(sig)}
                    href={sig_link(sig)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="link link-hover text-yellow-400"
                  >
                    {sig.type_name}
                  </a>
                  <span :if={is_nil(wormhole_display(sig)) and is_nil(sig_link(sig))}>
                    {sig.type_name || "-"}
                  </span>
                </td>
                <td class="text-center">
                  <span class={["text-xs", mass_text_class(mass_for(sig, @wh_mass))]}>
                    {mass_label(mass_for(sig, @wh_mass))}
                  </span>
                </td>
                <td class="text-center tabular-nums text-xs opacity-60">{format_age(sig)}</td>
                <td class="text-center">
                  <span
                    class={["text-xs", life_text_class(life_status(sig))]}
                    title={"Expires in " <> format_life_left(sig)}
                  >
                    {life_label(life_status(sig))}
                  </span>
                </td>
                <td class="text-center">
                  <button
                    class="btn btn-ghost btn-xs"
                    title="Edit signature"
                    phx-click="open-edit"
                    phx-value-id={sig.id}
                  >
                    <.icon name="hero-pencil" class="size-4" />
                  </button>
                  <button
                    class="btn btn-ghost btn-xs"
                    title="Delete signature"
                    phx-click="delete-signature"
                    phx-value-id={sig.id}
                    phx-target={@myself}
                    data-confirm="Delete this signature?"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </td>
              </tr>
              <tr :if={@signatures == []}>
                <td colspan="8" class="py-4 text-center text-sm opacity-50">
                  No signatures yet. Click Add or paste scan results anywhere.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp selected_system(%{assigns: %{selected_system_id: nil}}), do: nil
  defp selected_system(%{assigns: %{selected_system_id: id}}), do: Mapping.get_system(id)

  defp system_label(nil), do: "no system selected"
  defp system_label(_), do: "system selected"

  defp tracking?(assigns) do
    case Map.get(assigns, :character) do
      %{} = character -> Tripwire.Tracking.tracking?(character)
      _ -> false
    end
  end

  defp tracking_available?(assigns) do
    case Map.get(assigns, :character) do
      %{refresh_token: token} -> Tripwire.SSO.configured?() and not is_nil(token)
      _ -> false
    end
  end

  defp sig_link(%{type_name: name}), do: SigParser.external_link(name)
  defp sig_link(_), do: nil

  # A scanned wormhole that backs a connection is labelled with the system the
  # connection leads to (Tripwire behaviour); otherwise the full typed name is
  # kept so a scanned hole is never displayed like an unscanned one.
  defp wormhole_label(sig, wh_links) do
    case Map.get(wh_links, {sig.map_system_id, SigParser.wormhole_code(sig.type_name)}) do
      nil -> wormhole_display(sig)
      name -> name
    end
  end

  defp wormhole_display(%{site_type: "wormhole", type_name: name})
       when is_binary(name) do
    case String.trim(name) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp wormhole_display(_), do: nil

  defp kind_label(%{kind: "anomaly"}), do: "Anomaly"
  defp kind_label(_), do: "Signature"

  defp site_label(%{kind: "anomaly"}), do: "Anomaly"

  defp site_label(%{site_type: type}) when type in ~w(combat data relic ore gas wormhole),
    do: String.capitalize(type)

  defp site_label(sig), do: kind_label(sig)

  defp site_badge(%{kind: "anomaly"}), do: "badge-neutral"
  defp site_badge(%{site_type: "wormhole"}), do: "badge-info"
  defp site_badge(%{site_type: "combat"}), do: "badge-error"
  defp site_badge(%{site_type: "data"}), do: "badge-warning"
  defp site_badge(%{site_type: "relic"}), do: "badge-secondary"
  defp site_badge(%{site_type: "ore"}), do: "badge-accent"
  defp site_badge(%{site_type: "gas"}), do: "badge-success"
  defp site_badge(_), do: "badge-ghost"

  defp scan_icon(%{site_type: type}) when type in ~w(combat data relic ore gas wormhole),
    do: "hero-check"

  defp scan_icon(_), do: "hero-x-mark"

  defp scan_icon_class(%{site_type: type}) when type in ~w(combat data relic ore gas wormhole),
    do: "text-success"

  defp scan_icon_class(_), do: "text-error"

  defp format_life_left(%{inserted_at: inserted_at, life_length: life_length}) do
    seconds =
      SigParser.life_left(
        DateTime.from_naive!(inserted_at, "Etc/UTC"),
        life_length || SigParser.default_life_length()
      )

    hours = div(seconds, 3600)
    minutes = rem(seconds, 3600) |> div(60)
    "#{hours}h #{String.pad_leading(Integer.to_string(minutes), 2, "0")}m"
  end

  defp life_status(%{inserted_at: inserted_at, life_length: life_length}) do
    DateTime.from_naive!(inserted_at, "Etc/UTC")
    |> SigParser.life_left(life_length || SigParser.default_life_length())
    |> SigParser.life_status()
  end

  defp life_label(:stable), do: "Stable"
  defp life_label(:eol), do: "EOL"
  defp life_label(:critical), do: "Critical"
  defp life_label(:expired), do: "Expired"

  defp life_text_class(:stable), do: "opacity-60"
  defp life_text_class(:eol), do: "text-warning"
  defp life_text_class(:critical), do: "text-error"
  defp life_text_class(:expired), do: "text-error line-through"

  defp format_age(%{inserted_at: inserted_at}) do
    DateTime.from_naive!(inserted_at, "Etc/UTC")
    |> SigParser.age_seconds()
    |> format_duration()
  end

  defp format_duration(seconds) when seconds < 60, do: "<1m"
  defp format_duration(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m"

  defp format_duration(seconds) when seconds < 86_400 do
    hours = div(seconds, 3600)
    minutes = rem(seconds, 3600) |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hours}h #{minutes}m"
  end

  defp format_duration(seconds) do
    days = div(seconds, 86_400)
    hours = rem(seconds, 86_400) |> div(3600)
    "#{days}d #{hours}h"
  end

  defp send_map_update(system, dropped, linked, hidden) do
    if dropped + linked + hidden > 0 do
      send(self(), {:systems_updated, system.map_id})
    end
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
  defp present(value) when is_binary(value), do: String.trim(value) |> nullify()
  defp present(value), do: value

  defp nullify(""), do: nil
  defp nullify(value), do: value

  defp changeset_errors(changeset) do
    changeset.errors |> Enum.map(fn {f, {m, _}} -> "#{f} #{m}" end) |> Enum.join(", ")
  end
end
