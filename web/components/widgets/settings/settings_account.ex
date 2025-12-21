defmodule TripwireWeb.SettingsAccountComponent do
  use Phoenix.Component

  def settings_account(assigns) do
~H"""
    <input type="radio" name="my_tabs_6" class="tab" aria-label="Account" checked />
    <div class="tab-content overflow-hidden w-full  border-base-300 p-6" enabled>
      <div class="size-full flex flex-col gap-4 overflow-y-scroll">
        <p class="p-2">Account</p>
        <p class="p-2">Last login: 2025-12-12 09:40:22</p>

        <div class="w-full h-fit flex flex-col md:flex-row gap-4 p-4">
          Characters
          <div class="stats shadow overflow-hidden md:w-84 h-fit outline" tabindex="0">
            <div class="stat overflow-hidden flex flex-col">
              <div class="avatar avatar-online">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>
              <div class="stat-value text-lg lg:stat-value">Characer Name1</div>
              <div class="stat-title">Corporation Name</div>
              <div class="stat-desc text-secondary">Alliance Name</div>

              <div class="flex flex-row gap-1 w-full justify-items-start">
                <div class="badge badge-info">Info</div>
                <div class="badge badge-success">Success</div>
              </div>
            </div>
          </div>

          <div class="stats shadow overflow-hidden md:w-84 h-fit " tabindex="0">
            <div class="stat overflow-hidden flex flex-col">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>
              <div class="stat-value text-lg lg:stat-value">Characer Name1</div>
              <div class="stat-title">Corporation Name</div>
              <div class="stat-desc text-secondary">Alliance Name</div>

              <div class="flex flex-row gap-1 w-full justify-items-start">
                <div class="badge badge-info">Info</div>
                <div class="badge badge-warning">Warning</div>
              </div>
            </div>
          </div>

          <div class="stats shadow overflow-hidden md:w-84 h-fit " tabindex="0">
            <div class="stat overflow-hidden flex flex-col">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>
              <div class="stat-value text-lg lg:stat-value">Characer Name1</div>
              <div class="stat-title">Corporation Name</div>
              <div class="stat-desc text-secondary">Alliance Name</div>

              <div class="flex flex-row gap-1 w-full justify-items-start">
                <div class="badge badge-info">Info</div>
              </div>
            </div>
          </div>
        </div>

        <div class="w-full h-fit flex flex-col md:flex-row gap-4 p-4">
          Masks
          <div class="stats shadow overflow-hidden md:w-84 h-fit outline" tabindex="0">
            <div class="stat overflow-hidden flex flex-col">
              <div class="avatar avatar-online">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/gordon@192.webp" />
                </div>
              </div>
              <div class="stat-value text-lg lg:stat-value">Mask 1</div>
              <div class="stat-title">Corporation Name</div>
              <div class="stat-desc text-secondary">Alliance Name</div>

              <div class="flex flex-col md:flex-row gap-1 w-full justify-items-start">
                <div class="badge badge-info">Character1</div>
                <div class="badge badge-info">Character2</div>
              </div>
            </div>
          </div>

          <div class="stats shadow overflow-hidden md:w-84 h-fit " tabindex="0">
            <div class="stat overflow-hidden flex flex-col">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/gordon@192.webp" />
                </div>
              </div>
              <div class="stat-value text-lg lg:stat-value">Mask 2</div>
              <div class="stat-title">Corporation Name</div>
              <div class="stat-desc text-secondary">Alliance Name</div>

              <div class="flex flex-col md:flex-row gap-1 w-full justify-items-start">
                <div class="badge badge-info">Character1</div>
                <div class="badge badge-info">Character2</div>
                <div class="badge badge-info">Character3</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
"""
  end
end
