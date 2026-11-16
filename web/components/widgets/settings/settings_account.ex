defmodule TripwireWeb.SettingsAccountComponent do
  use Phoenix.Component

  attr :settings_tab, :string, default: "account"

  def settings_account(assigns) do
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
    <div class="tab-content w-full max-w-full overflow-hidden border-base-300 p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
        <div class="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-0.5">
          <p class="text-sm font-semibold">Account</p>
          <p class="truncate text-xs opacity-60">Last login: 2025-12-12 09:40:22</p>
        </div>

        <p class="text-xs font-medium opacity-70">Characters</p>
        <div class="grid w-full max-w-full grid-cols-2 gap-2 sm:grid-cols-3">
          <div class="stats shadow min-w-0 outline" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-online">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">Characer Name1</div>
              <div class="truncate text-xs opacity-70">Corporation Name</div>
              <div class="flex min-w-0 flex-row flex-wrap gap-1">
                <div class="badge badge-info badge-xs">Info</div>
                <div class="badge badge-success badge-xs">Success</div>
              </div>
            </div>
          </div>

          <div class="stats shadow min-w-0" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-offline">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">Characer Name1</div>
              <div class="truncate text-xs opacity-70">Corporation Name</div>
              <div class="flex min-w-0 flex-row flex-wrap gap-1">
                <div class="badge badge-info badge-xs">Info</div>
                <div class="badge badge-warning badge-xs">Warning</div>
              </div>
            </div>
          </div>

          <div class="stats shadow min-w-0" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-offline">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">Characer Name1</div>
              <div class="truncate text-xs opacity-70">Corporation Name</div>
              <div class="flex min-w-0 flex-row flex-wrap gap-1">
                <div class="badge badge-info badge-xs">Info</div>
              </div>
            </div>
          </div>
        </div>

        <p class="text-xs font-medium opacity-70">Masks</p>
        <div class="grid w-full max-w-full grid-cols-2 gap-2">
          <div class="stats shadow min-w-0 outline" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-online">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">Mask 1</div>
              <div class="truncate text-xs opacity-70">Corporation Name</div>
              <div class="flex min-w-0 flex-row flex-wrap gap-1">
                <div class="badge badge-info badge-xs">Character1</div>
                <div class="badge badge-info badge-xs">Character2</div>
              </div>
            </div>
          </div>

          <div class="stats shadow min-w-0" tabindex="0">
            <div class="stat min-w-0 gap-1 p-2">
              <div class="avatar avatar-offline">
                <div class="w-10 rounded-xl">
                  <img src="/images/alliance-default.png" alt="" />
                </div>
              </div>
              <div class="truncate text-sm font-semibold">Mask 2</div>
              <div class="truncate text-xs opacity-70">Corporation Name</div>
              <div class="flex min-w-0 flex-row flex-wrap gap-1">
                <div class="badge badge-info badge-xs">Character1</div>
                <div class="badge badge-info badge-xs">Character2</div>
                <div class="badge badge-info badge-xs">Character3</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
