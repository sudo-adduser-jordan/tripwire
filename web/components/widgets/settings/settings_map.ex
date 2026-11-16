defmodule TripwireWeb.SettingsMapComponent do
  use Phoenix.Component

  attr :settings_tab, :string, default: "account"
  attr :map_layout, :string, default: "default"

  def settings_map(assigns) do
    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Map"
      checked={@settings_tab == "map"}
      phx-click="settings-tab"
      phx-value-tab="map"
    />
    <div class="tab-content w-full max-w-full overflow-hidden border-base-300 bg-base-100/50 p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden sm:gap-3">
        <p class="text-sm font-semibold">Map Settings</p>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Map Layout</p>
          <form phx-change="map-layout" class="min-w-0">
            <select name="layout" class="select select-sm w-full max-w-48">
              <option value="default" selected={@map_layout == "default"}>Default</option>
              <option value="radial" selected={@map_layout == "radial"}>Radial</option>
              <option value="top" selected={@map_layout == "top"}>Top</option>
              <option value="bottom" selected={@map_layout == "bottom"}>Bottom</option>
              <option value="left" selected={@map_layout == "left"}>Left</option>
              <option value="right" selected={@map_layout == "right"}>Right</option>
            </select>
          </form>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Show Jump Lines</p>
          <input type="checkbox" checked="checked" class="toggle toggle-primary toggle-sm" />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Show Line Glow</p>
          <input type="checkbox" checked="checked" class="toggle toggle-secondary toggle-sm" />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Show Node Signatures</p>
          <input type="checkbox" checked="checked" class="toggle toggle-neutral toggle-sm" />
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Map Scale</p>
          <input
            type="range"
            min="0"
            max="100"
            value="40"
            class="range range-primary range-xs min-w-0 max-w-full flex-1 sm:max-w-64"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Line Weight</p>
          <input
            type="range"
            min="0"
            max="100"
            value="40"
            class="range range-primary range-xs min-w-0 max-w-full flex-1 sm:max-w-64"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Node Spacing</p>
          <input
            type="range"
            min="0"
            max="100"
            value="40"
            class="range range-primary range-xs min-w-0 max-w-full flex-1 sm:max-w-64"
          />
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm sm:w-40 sm:pl-8">Background Image</p>
          <label class="input input-sm min-w-0 max-w-full flex-1 sm:max-w-64">
            <input type="text" placeholder="domain name" class="min-w-0" />
            <span class="label">.com</span>
          </label>
        </div>
      </div>
    </div>
    """
  end
end
