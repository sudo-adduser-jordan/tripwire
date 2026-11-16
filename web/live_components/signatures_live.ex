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
     |> assign_new(:undo, fn -> [] end)
     |> assign_new(:redo, fn -> [] end)}
  end

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
    {:ok, deleted} = Mapping.delete_signature(signature)
    undo = [{:delete, deleted} | socket.assigns.undo]

    send(self(), {:signatures_updated, deleted.map_system_id})

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
            send(self(), {:signatures_updated, system.id})

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
        _ = Mapping.delete_signature(signature)
        undo = [{:delete, signature} | socket.assigns.undo]
        send(self(), {:signatures_updated, signature.map_system_id})

        {:noreply,
         socket
         |> assign(:redo, rest)
         |> assign(:undo, undo)
         |> assign(:signatures, Mapping.list_signatures(signature.map_system_id))}
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
                <.icon name="hero-plus" class="size-5" /> Add
              </button>
              <button
                class="btn btn-ghost btn-xs"
                title="Undo"
                phx-click="undo"
                phx-target={@myself}
              >
                <.icon name="hero-arrow-uturn-left" class="size-5" />
              </button>
              <button
                class="btn btn-ghost btn-xs"
                title="Redo"
                phx-click="redo"
                phx-target={@myself}
              >
                <.icon name="hero-arrow-uturn-right" class="size-5" />
              </button>
              <span class="ml-auto text-xs opacity-60">
                {system_label(@selected_system_id)}
              </span>
            </li>
          </ul>
        </div>
        <div class="min-h-0 w-full max-w-full flex-1 overflow-auto">
          <table class="widget-table table table-xs w-full">
            <thead class="sticky top-0 z-10 bg-base-100">
              <tr>
                <th class="p-1 text-center text-xs">ID</th>
                <th class="p-1 text-center text-xs">Type</th>
                <th class="p-1 text-center text-xs">Name</th>
                <th class="p-1 text-center text-xs">Life</th>
                <th class="p-1 text-center text-xs"><span class="sr-only">Actions</span></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={sig <- @signatures} id={"signature-#{sig.id}"}>
                <td>
                  <button
                    class="font-mono link link-hover"
                    title="Edit signature"
                    phx-click="open-edit"
                    phx-value-id={sig.id}
                  >
                    {sig.sig_id}
                  </button>
                </td>
                <td>{site_label(sig)}</td>
                <td class="cell-truncate">{sig.type_name || "-"}</td>
                <td class="tabular-nums">{format_life_left(sig)}</td>
                <td class="text-right">
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
                <td colspan="5" class="py-4 text-center text-sm opacity-50">
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

  defp kind_label(%{kind: "anomaly"}), do: "Anomaly"
  defp kind_label(_), do: "Signature"

  defp site_label(%{kind: "anomaly"}), do: "Anomaly"
  defp site_label(%{site_type: type}) when type in ~w(combat data relic ore gas wormhole), do: String.capitalize(type)
  defp site_label(sig), do: kind_label(sig)

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
  defp present(value) when is_binary(value), do: String.trim(value) |> nullify()
  defp present(value), do: value

  defp nullify(""), do: nil
  defp nullify(value), do: value

  defp changeset_errors(changeset) do
    changeset.errors |> Enum.map(fn {f, {m, _}} -> "#{f} #{m}" end) |> Enum.join(", ")
  end
end
