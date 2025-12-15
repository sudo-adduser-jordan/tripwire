defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component


# make widget / show stats button from account settings
# Signatures added: 	22255
# Signatures updated: 	2728
# Signatures deleted: 	4280
# Wormholes added: 	3162
# Wormholes updated: 	4253
# Wormholes deleted: 	1443
# Comments added: 	62
# Comments updated: 	18
# Comments deleted: 	8
# Systems visited: 	2,777
# Logins: 	875




  # Line Weight Factor*: 	0.5
# Chain Map Node Reference: 	Wormhole Type Signature ID
# Node Spacing Factor*: 1-10
# K-space route selection:
# Avoiding:
# Signature copy output separator:
# Background Image:
# UI Scale:


  def settings(assigns) do
~H"""
<div class="hidden size-full" id="settings-template">
  <div class="tabs tabs-box size-full">

    <input type="radio" name="my_tabs_6" class="tab" aria-label="Account" checked="checked" />
    <div class="tab-content  bg-base-100 border-base-300 p-6">
      <div class="size-full flex flex-col gap-4">
        <p class="p-2">Account</p>
        <p class="p-2">Last login: 2025-12-12 09:40:22</p>
        <div class="flex flex-row ">
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">
              <div class="avatar avatar-online">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>

            </div>
            <div class="stat-value">Characer Name1</div>
            <div class="stat-title">Corporation Name</div>
            <div class="stat-desc text-secondary">Alliance Name</div>
          </div>
        </div>
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>

            </div>
            <div class="stat-value">Characer Name2</div>
            <div class="stat-title">Corporation Name</div>
            <div class="stat-desc text-secondary">Alliance Name</div>
          </div>
        </div>

        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-xl">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>

            </div>
            <div class="stat-value">Characer Name3</div>
            <div class="stat-title">Corporation Name</div>
            <div class="stat-desc text-secondary">Alliance Name</div>
          </div>
      </div>
      </div>
        <div class="flex flex-col gap-4">
        Masks
        <div class="badge badge-soft badge-primary ml-8 ">Mask 1</div>
        <div class="badge badge-soft badge-secondary ml-8 ">Mask 2</div>
        <div class="badge badge-soft badge-accent ml-8 ">Mask 3</div>
      </div>
    </div>
    </div>





  <input type="radio" name="my_tabs_6" class="tab" aria-label="Map" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Map Settings
    <div class="flex flex-col gap-4">

      <div class="flex flex-row gap-4">
        <p class="w-25/100 pl-8">Map Render</p>
        <select class="select select-ghost">
          <option disabled selected>Default</option>
          <option>Default</option>
          <option>Radial</option>
          <option>Top</option>
          <option>Bottom</option>
          <option>Left</option>
          <option>Right</option>
        </select>
      </div>

      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">Show Jump Lines</p>
        <input type="checkbox" checked="checked" class="toggle toggle-primary" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">Show Line Glow</p>
        <input type="checkbox" checked="checked" class="toggle toggle-secondary" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">Scroll with Ctrl Key</p>
        <input type="checkbox" checked="checked" class="toggle toggle-accent" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">Show Node Signatures</p>
        <input type="checkbox" checked="checked" class="toggle toggle-neutral" />
      </div>
      <%!-- <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-info" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-success" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-warning" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-error" />
      </div> --%>

    </div>
  </div>

  <input type="radio" name="my_tabs_6" class="tab" aria-label="Widgets" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Widgets
    <div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />
        <p>System</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" checked="checked" class="checkbox checkbox-secondary" />
        <p>Notes</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" checked="checked" class="checkbox checkbox-accent" />
        <p>Signatures</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" checked="checked" class="checkbox checkbox-neutral" />
        <p>Map</p>
      </div>
<%!--
      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-error" />
        <p>Killboard</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-info" />
        <p>Player Statistics</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-success" />
        <p>Discord Intell</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-warning" />
        <p>Udema Scout</p>
      </div>
 --%>
    </div>
  </div>

  <input type="radio" name="my_tabs_6" class="tab" aria-label="Theme" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Themes
    <div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />
        <p>Default</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-secondary" />
        <p>Native</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-info" />
        <p>Caldari</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-success" />
        <p>Gallente</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-error" />
        <p>Minmatar</p>
      </div>

      <div class="flex flex-row gap-4">
        <input type="checkbox" class="checkbox checkbox-info" />
        <p>Amarr</p>
      </div>

    </div>
  </div>


  </div>


</div>
"""
    end
end
