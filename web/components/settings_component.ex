defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component


# Username: 	lostcoastwizard
# Characters:
# Mask settings:

# Map Render: left right top bottom radial
# Show Map Jump Lines: Yes No
# Show Line Aura*: 	Yes No
# Line Weight Factor*: 	0.5
# Allow Scroll Without Ctrl Key: 	Yes No
# Chain Map Node Reference: 	Wormhole Type Signature ID
# Show sig name on map: true
# Node Spacing Factor*: 1-10
# K-space route selection:
# Avoiding:
# Signature copy output separator:
# Background Image:
# UI Scale:

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
# Last login: 2025-12-12 09:40:22


  def settings(assigns) do
~H"""
<div class="hidden size-full" id="settings-template">

  <div class="tabs tabs-box size-full">
    <input type="radio" name="my_tabs_6" class="tab" aria-label="Account" checked="checked" />
    <div class="tab-content  bg-base-100 border-base-300 p-6">

    <div class="size-full flex flex-col gap-4">
      Account
      <div class="flex flex-row ">
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">
              <div class="avatar avatar-online">
                <div class="w-16 rounded-full">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>

            </div>
            <div class="stat-value">Characer Name1</div>
            <div class="stat-title">Corporation Name</div>
            <div class="stat-desc text-secondary">Masks</div>
          </div>
        </div>
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-full">
                  <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
                </div>
              </div>

            </div>
            <div class="stat-value">Characer Name2</div>
            <div class="stat-title">Corporation Name</div>
            <div class="stat-desc text-secondary">Masks</div>
          </div>
        </div>

        <div class="stats shadow">
          <div class="stat">
            <div class="stat-figure text-secondary">
              <div class="avatar avatar-offline">
                <div class="w-16 rounded-full">
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
        <p class="w-25/100 pl-8">System</p>
        <select class="select select-ghost">
          <option disabled selected>Pick a font</option>
          <option>Inter</option>
          <option>Poppins</option>
          <option>Raleway</option>
        </select>

      </div>

      <div class="flex flex-row gap-4">
        <p class="w-25/100 pl-8">System</p>
        <select class="select select-ghost">
          <option disabled selected>Pick a font</option>
          <option>Inter</option>
          <option>Poppins</option>
          <option>Raleway</option>
        </select>
      </div>

      <div class="flex flex-row gap-4">
        <p class="w-25/100 pl-8">System</p>
        <select class="select select-ghost">
          <option disabled selected>Pick a font</option>
          <option>Inter</option>
          <option>Poppins</option>
          <option>Raleway</option>
        </select>
      </div>






      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-primary" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-secondary" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-accent" />
      </div>
      <div class="flex flex-row gap-4">
        <p class="w-4/10 pl-8">System</p>
        <input type="checkbox" checked="checked" class="toggle toggle-neutral" />
      </div>
      <div class="flex flex-row gap-4">
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
      </div>

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
