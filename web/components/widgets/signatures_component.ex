defmodule TripwireWeb.SignaturesComponent do
  use Phoenix.Component
  import TripwireWeb.IconComponent

  alias Tripwire.Signatures, as: SigParser

  attr :id, :string, default: "signatures"
  attr :signatures, :list, required: true
  attr :selected_system_id, :integer, default: nil
  attr :paste_open, :boolean, default: false
  attr :paste_text, :string, default: ""

  def signatures(assigns) do
    ~H"""
    <div id={@id} class="grid-stack-item h-full" gs-w="12" gs-h="6" gs-x="0" gs-y="6" tabindex="0">
      <div class="grid-stack-item-content bg-base-100/50 flex flex-col">
        <div class="sticky top-0">
          <ul class="list rounded-box shadow-md">
            <li class="list-row h-fit p-1 flex items-center gap-1">
              <button
                class="btn btn-xs btn-ghost"
                title="Paste scan results"
                phx-click="toggle-paste"
              >
                <.icon name="hero-plus-circle" class="size-5" /> Paste
              </button>
              <button class="btn btn-xs btn-ghost" title="Undo" phx-click="undo">
                <.icon name="hero-arrow-uturn-left" class="size-5" />
              </button>
              <button class="btn btn-xs btn-ghost" title="Redo" phx-click="redo">
                <.icon name="hero-arrow-uturn-right" class="size-5" />
              </button>
              <span class="ml-auto text-xs opacity-60">
                {system_label(@selected_system_id)}
              </span>
            </li>

            <li :if={@paste_open} class="p-2 flex flex-col gap-2 border-b border-base-300">
              <textarea
                class="textarea textarea-sm w-full font-mono"
                rows="4"
                placeholder="Paste probe results, e.g.\nABC-123\tCosmic Signature\tUnstable Wormhole"
                phx-change="paste-update"
                value={@paste_text}
              ></textarea>
              <div class="flex gap-2 justify-end">
                <button class="btn btn-xs" phx-click="toggle-paste">Cancel</button>
                <button class="btn btn-xs btn-primary" phx-click="paste-submit">Import</button>
              </div>
            </li>
          </ul>

          <table class="table table-xs w-full">
            <thead class="sticky top-0 outline">
              <tr>
                <th class="outline outline-primary text-xs text-center p-0">ID</th>
                <th class="outline outline-primary text-xs text-center p-0">Type</th>
                <th class="outline outline-primary text-xs text-center p-0">Name</th>
                <th class="outline outline-primary text-xs text-center p-0">Life</th>
                <th class="outline outline-primary text-xs text-center p-0"></th>
              </tr>
            </thead>
          </table>
        </div>

        <div class="overflow-auto flex-1">
          <table class="table table-xs w-full">
            <tbody>
              <tr :for={sig <- @signatures} id={"signature-#{sig.id}"}>
                <td class="font-mono">{sig.sig_id}</td>
                <td>{kind_label(sig)}</td>
                <td>{sig.type_name || "-"}</td>
                <td>{format_life_left(sig.inserted_at)}</td>
                <td class="text-right">
                  <button
                    class="btn btn-ghost btn-xs"
                    title="Delete signature"
                    phx-click="delete-signature"
                    phx-value-id={sig.id}
                    data-confirm="Delete this signature?"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </td>
              </tr>

              <tr :if={@signatures == []}>
                <td colspan="5" class="text-center text-sm opacity-50 py-4">
                  No signatures yet. Paste scan results for the selected system.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp system_label(nil), do: "no system selected"
  defp system_label(_), do: "system selected"

  defp kind_label(%{kind: "anomaly"}), do: "Anomaly"
  defp kind_label(_), do: "Signature"

  defp format_life_left(inserted_at) do
    seconds = SigParser.life_left(DateTime.from_naive!(inserted_at, "Etc/UTC"))

    hours = div(seconds, 3600)
    minutes = rem(seconds, 3600) |> div(60)
    "#{hours}h #{String.pad_leading(Integer.to_string(minutes), 2, "0")}m"
  end
end
