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
<section class="hidden size-full" id="settings-template" >

<div class="tabs tabs-box size-full">
  <input type="radio" name="my_tabs_2" class="tab" aria-label="Account" checked="checked" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Account Settings
    <section>
    <div class="stats shadow">
  <div class="stat">
    <div class="stat-figure text-primary">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        class="inline-block h-8 w-8 stroke-current"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
        ></path>
      </svg>
    </div>
    <div class="stat-title">Total Likes</div>
    <div class="stat-value text-primary">25.6K</div>
    <div class="stat-desc">21% more than last month</div>
  </div>

  <div class="stat">
    <div class="stat-figure text-secondary">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        class="inline-block h-8 w-8 stroke-current"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M13 10V3L4 14h7v7l9-11h-7z"
        ></path>
      </svg>
    </div>
    <div class="stat-title">Page Views</div>
    <div class="stat-value text-secondary">2.6M</div>
    <div class="stat-desc">21% more than last month</div>
  </div>

  <div class="stat">
    <div class="stat-figure text-secondary">
      <div class="avatar avatar-online">
        <div class="w-16 rounded-full">
          <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
        </div>
      </div>
    </div>
    <div class="stat-value">86%</div>
    <div class="stat-title">Tasks done</div>
    <div class="stat-desc text-secondary">31 tasks remaining</div>
  </div>
</div>
</section>

  </div>
  <input type="radio" name="my_tabs_2" class="tab" aria-label="Map" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Map Settings
    <section>
        <input type="checkbox" checked="checked" class="toggle toggle-primary" />
        <input type="checkbox" checked="checked" class="toggle toggle-secondary" />
        <input type="checkbox" checked="checked" class="toggle toggle-accent" />
        <input type="checkbox" checked="checked" class="toggle toggle-neutral" />
        <input type="checkbox" checked="checked" class="toggle toggle-info" />
        <input type="checkbox" checked="checked" class="toggle toggle-success" />
        <input type="checkbox" checked="checked" class="toggle toggle-warning" />
        <input type="checkbox" checked="checked" class="toggle toggle-error" />
        <section>
        <select class="select select-ghost">
        <option disabled selected>Pick a font</option>
        <option>Inter</option>
        <option>Poppins</option>
        <option>Raleway</option>
        </select>
    </section>
        <section>
        <select class="select select-ghost">
        <option disabled selected>Pick a font</option>
        <option>Inter</option>
        <option>Poppins</option>
        <option>Raleway</option>
        </select>
    </section>
        <section>
        <select class="select select-ghost">
        <option disabled selected>Pick a font</option>
        <option>Inter</option>
        <option>Poppins</option>
        <option>Raleway</option>
        </select>
    </section>

    </section>
  </div>

  <input type="radio" name="my_tabs_2" class="tab" aria-label="Widgets" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Widgets
    <section >
    <p>System</p>
    <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />

    <p>Notes</p>
    <input type="checkbox" checked="checked" class="checkbox checkbox-secondary" />

    <p>Signatures</p>
    <input type="checkbox" checked="checked" class="checkbox checkbox-accent" />

    <p>Map</p>
    <input type="checkbox" checked="checked" class="checkbox checkbox-neutral" />

    <p>Killboard</p>
        <input type="checkbox" checked="checked" class="checkbox checkbox-error" />

    <p>Player Statistics</p>
        <input type="checkbox" checked="checked" class="checkbox checkbox-info" />

    <p>Discord Intell Channel</p>
        <input type="checkbox" checked="checked" class="checkbox checkbox-success" />

    <p>Udema Scout</p>
        <input type="checkbox" checked="checked" class="checkbox checkbox-warning" />
    </section>
  </div>

  <input type="radio" name="my_tabs_2" class="tab" aria-label="Theme" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Themes
    <section >
    <p>Default</p>
    <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />

    <p>Native</p>
    <input type="checkbox" class="checkbox checkbox-secondary" />

    <p>Caldari</p>
    <input type="checkbox" class="checkbox checkbox-info" />

    <p>Gallente</p>
    <input type="checkbox" class="checkbox checkbox-success" />

    <p>Minmatar</p>
        <input type="checkbox" class="checkbox checkbox-error" />

    <p>Amarr</p>
        <input type="checkbox" class="checkbox checkbox-info" />

    </section>
  </div>
</div>


</section>
"""
    end
end
