defmodule TripwireWeb.LiveComponents.Settings.AdminLive do
  use Phoenix.Component

  alias Tripwire.Accounts

  attr :settings_tab, :string, default: "account"
  attr :character, :any, default: nil
  attr :masks, :list, default: []

  def settings_admin_live(assigns) do
    ~H"""
    <input
      :if={admin?(@character)}
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Admin"
      checked={@settings_tab == "admin"}
      phx-click="settings-tab"
      phx-value-tab="admin"
    />
    <div :if={admin?(@character)} class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-3 overflow-hidden">
        <p class="text-sm font-semibold">Mask administration</p>
        <p class="text-xs opacity-60">
          Create corporate masks and manage membership. Demo admins are scoped to demo masks only.
        </p>
        <form phx-submit="create-corp-mask" class="flex flex-wrap items-center gap-2">
          <button type="submit" class="btn btn-primary btn-sm">Create corporate mask</button>
        </form>
        <div :for={mask <- @masks} class="rounded border border-base-300 p-2">
          <div class="flex flex-wrap items-center gap-2">
            <p class="text-sm font-semibold">{mask.name} ({mask.kind})</p>
            <button
              type="button"
              class="btn btn-error btn-xs ml-auto"
              phx-click="delete-mask"
              phx-value-id={mask.id}
              data-confirm="Delete this mask and all of its maps?"
            >
              Delete mask
            </button>
          </div>
          <ul class="mt-1 space-y-1">
            <li
              :for={member <- Accounts.list_characters_for_mask(mask.id)}
              class="flex items-center gap-2 text-sm"
            >
              <span>{member.name} ({member.eve_id})</span>
              <span :if={member.is_admin} class="badge badge-warning badge-xs">admin</span>
              <button
                type="button"
                class="btn btn-ghost btn-xs ml-auto"
                phx-click="remove-mask-member"
                phx-value-mask-id={mask.id}
                phx-value-character-id={member.id}
                data-confirm="Remove this member?"
              >
                Remove
              </button>
            </li>
          </ul>
          <form phx-submit="add-mask-member" class="mt-2 flex flex-wrap items-center gap-2">
            <input type="hidden" name="mask_id" value={mask.id} />
            <input
              name="eve_id"
              type="number"
              placeholder="EVE ID"
              required
              class="input input-bordered input-sm w-32"
            />
            <input
              name="name"
              type="text"
              placeholder="Character name"
              required
              class="input input-bordered input-sm w-40"
            />
            <button type="submit" class="btn btn-secondary btn-sm">Add member</button>
          </form>
        </div>
        <%= if Application.get_env(:tripwire, :dev_routes) do %>
          <div class="rounded border border-base-300 p-2">
            <p class="text-sm font-semibold">Developer tools</p>
            <p class="mt-1 text-xs opacity-60">Available in dev builds only.</p>
            <div class="mt-2 flex flex-wrap items-center gap-2">
              <a href="/dev/dashboard" class="btn btn-secondary btn-sm">Metrics</a>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp admin?(%{is_admin: true}), do: true
  defp admin?(_), do: false
end
