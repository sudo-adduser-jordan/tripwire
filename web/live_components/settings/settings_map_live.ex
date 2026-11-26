defmodule TripwireWeb.LiveComponents.Settings.MapLive do
  use Phoenix.Component

  attr :settings_tab, :string, default: "account"
  attr :map_layout, :string, default: "top"
  attr :show_row_guides, :boolean, default: false
  attr :show_row_counts, :boolean, default: false
  attr :angled_lines, :boolean, default: true
  attr :show_jump_lines, :boolean, default: true
  attr :show_line_glow, :boolean, default: true
  attr :show_node_badges, :boolean, default: true
  attr :line_weight, :integer, default: 2
  attr :node_spacing, :integer, default: 100
  attr :node_roundness, :string, default: "oval"
  attr :map_scale, :integer, default: 100
  attr :map_background, :string, default: nil

  def settings_map_live(assigns) do
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
    <div class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-3 overflow-hidden">
        <p class="text-sm font-semibold">Map Settings</p>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Map Layout</p>
          <form phx-change="map-layout" class="min-w-0">
            <select name="layout" class="select select-sm w-full max-w-48">
              <option value="top" selected={@map_layout == "top"}>Top</option>
              <option value="bottom" selected={@map_layout == "bottom"}>Bottom</option>
              <option value="left" selected={@map_layout == "left"}>Left</option>
              <option value="right" selected={@map_layout == "right"}>Right</option>
            </select>
          </form>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Node Corners</p>
          <form phx-change="node-roundness" class="min-w-0">
            <select
              id="select-node-roundness"
              name="roundness"
              class="select select-sm w-full max-w-48"
            >
              <option value="square" selected={@node_roundness == "square"}>Square</option>
              <option value="rounded" selected={@node_roundness == "rounded"}>Rounded</option>
              <option value="oval" selected={@node_roundness == "oval"}>Oval</option>
            </select>
          </form>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Show Jump Lines</p>
          <input
            id="toggle-jump-lines"
            type="checkbox"
            checked={@show_jump_lines}
            phx-click="toggle-jump-lines"
            class="toggle toggle-primary toggle-sm"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Show Line Glow</p>
          <input
            id="toggle-line-glow"
            type="checkbox"
            checked={@show_line_glow}
            phx-click="toggle-line-glow"
            class="toggle toggle-primary toggle-sm"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Show Node Signatures</p>
          <input
            id="toggle-node-badges"
            type="checkbox"
            checked={@show_node_badges}
            phx-click="toggle-node-badges"
            class="toggle toggle-primary toggle-sm"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Show Row Guides</p>
          <input
            id="toggle-row-guides"
            type="checkbox"
            checked={@show_row_guides}
            phx-click="toggle-row-guides"
            class="toggle toggle-primary toggle-sm"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Show Row Levels</p>
          <input
            id="toggle-row-counts"
            type="checkbox"
            checked={@show_row_counts}
            phx-click="toggle-row-counts"
            class="toggle toggle-primary toggle-sm"
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Angled Lines</p>
          <input
            id="toggle-angled-lines"
            type="checkbox"
            checked={@angled_lines}
            phx-click="toggle-angled-lines"
            class="toggle toggle-primary toggle-sm"
          />
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Map Scale</p>
          <form phx-change="map-scale" class="min-w-0 max-w-full flex-1 sm:max-w-64">
            <div class="flex items-center gap-2">
              <input
                type="range"
                name="scale"
                min="50"
                max="200"
                step="10"
                value={@map_scale}
                class="range range-primary range-xs min-w-0 flex-1"
              />
              <span class="w-12 shrink-0 text-right text-xs tabular-nums opacity-60">
                {@map_scale}%
              </span>
            </div>
          </form>
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Line Weight</p>
          <form phx-change="line-weight" class="min-w-0 max-w-full flex-1 sm:max-w-64">
            <div class="flex items-center gap-2">
              <input
                type="range"
                name="weight"
                min="1"
                max="5"
                step="1"
                value={@line_weight}
                class="range range-primary range-xs min-w-0 flex-1"
              />
              <span class="w-12 shrink-0 text-right text-xs tabular-nums opacity-60">
                {@line_weight}
              </span>
            </div>
          </form>
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Node Spacing</p>
          <form phx-change="node-spacing" class="min-w-0 max-w-full flex-1 sm:max-w-64">
            <div class="flex items-center gap-2">
              <input
                type="range"
                name="spacing"
                min="50"
                max="200"
                step="10"
                value={@node_spacing}
                class="range range-primary range-xs min-w-0 flex-1"
              />
              <span class="w-12 shrink-0 text-right text-xs tabular-nums opacity-60">
                {@node_spacing}%
              </span>
            </div>
          </form>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Background Image</p>
          <form
            phx-change="map-background"
            class="input input-sm min-w-0 max-w-full flex-1 sm:max-w-64"
          >
            <input
              type="text"
              name="background"
              value={@map_background || ""}
              placeholder="https://example.com/map-bg.jpg"
              autocomplete="off"
              class="min-w-0 flex-1 bg-transparent outline-none"
            />
          </form>
        </div>
      </div>
    </div>
    """
  end
end
