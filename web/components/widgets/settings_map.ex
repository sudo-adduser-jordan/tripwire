defmodule TripwireWeb.SettingsMapComponent do
  use Phoenix.Component

  def settings_map(assigns) do
~H"""
        <input type="radio" name="my_tabs_6" class="tab" aria-label="Map" />
        <div class="tab-content overflow-y-scroll bg-base-100 border-base-300 p-6" enabled>
          Map Settings
          <div class="flex flex-col gap-4 p-1 md:p-4">
            <div class="flex flex-row gap-4">
              <p class="w-25/100 sm:pl-8">Map Render</p>
              <select class="select">
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
              <p class="w-4/10 sm:pl-8">Show Jump Lines</p>
              <input type="checkbox" checked="checked" class="toggle toggle-primary" />
            </div>
            <div class="flex flex-row gap-4">
              <p class="w-4/10 sm:pl-8">Show Line Glow</p>
              <input type="checkbox" checked="checked" class="toggle toggle-secondary" />
            </div>
            <div class="flex flex-row gap-4">
              <p class="w-4/10 sm:pl-8">Show Node Signatures</p>
              <input type="checkbox" checked="checked" class="toggle toggle-neutral" />
            </div>

            <div class="flex flex-row gap-4">
              <p class="w-25/100 sm:pl-8">Map Scale</p>
              <input type="range" min="0" max="100" value="40" class="range range-primary" />
            </div>
            <div class="flex flex-row gap-4">
              <p class="w-25/100 sm:pl-8">Line Weight</p>
              <input type="range" min="0" max="100" value="40" class="range range-primary" />
            </div>
            <div class="flex flex-row gap-4">
              <p class="w-25/100 sm:pl-8">Node Spacing</p>
              <input type="range" min="0" max="100" value="40" class="range range-primary" />
            </div>

            <div class="flex flex-row gap-4">
              <p class="w-25/100 sm:pl-8">Background Image</p>
              <label class="input">
                <input type="text" placeholder="domain name" />
                <span class="label">.com</span>
              </label>
            </div>
          </div>
        </div>
"""
  end
end
