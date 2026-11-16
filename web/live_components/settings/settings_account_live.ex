defmodule TripwireWeb.LiveComponents.Settings.AccountLive do
  use Phoenix.Component

  attr :settings_tab, :string, default: "account"
  attr :characters, :list, default: []
  attr :masks, :list, default: []
  attr :character, :any, default: nil

  def settings_account_live(assigns) do
    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Account"
      checked={@settings_tab == "account"}
      phx-click="settings-tab"
      phx-value-tab="account"
    />
    <div class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
        <div class="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-0.5">
          <p class="text-sm font-semibold">Account</p>
          <p :if={@character} class="truncate text-xs opacity-60">
            Last login: {@character.last_login_at}
          </p>
        </div>
        <p class="text-xs font-medium opacity-70">Characters</p>
        <div class="grid w-full max-w-full grid-cols-2 gap-2 sm:grid-cols-3">
          <div :for={character <- @characters} class="stats shadow min-w-0" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-offline">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">{character.name}</div>
              <div class="truncate text-xs opacity-70">
                {character.corporation_name || "Corporation"}
              </div>
            </div>
          </div>
          <p :if={@characters == []} class="text-xs opacity-50">No characters yet</p>
        </div>
        <p class="text-xs font-medium opacity-70">Masks</p>
        <div class="grid w-full max-w-full grid-cols-2 gap-2">
          <div :for={mask <- @masks} class="stats shadow min-w-0" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-offline">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">{mask.name}</div>
              <div class="truncate text-xs opacity-70">{mask.kind}</div>
            </div>
          </div>
          <p :if={@masks == []} class="text-xs opacity-50">No masks yet</p>
        </div>
      </div>
    </div>
    """
  end
end
