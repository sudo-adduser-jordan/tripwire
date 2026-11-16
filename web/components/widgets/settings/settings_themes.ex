defmodule TripwireWeb.SettingsThemesComponent do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @themes [
    "tripwire",
    "native",
    "native-dark",
    "light",
    "dark",
    "cupcake",
    "bumblebee",
    "emerald",
    "corporate",
    "synthwave",
    "retro",
    "cyberpunk",
    "valentine",
    "halloween",
    "garden",
    "forest",
    "aqua",
    "lofi",
    "pastel",
    "fantasy",
    "wireframe",
    "black",
    "luxury",
    "dracula",
    "cmyk",
    "autumn",
    "business",
    "acid",
    "lemonade",
    "night",
    "coffee",
    "winter"
  ]

  def themes, do: @themes

  attr :settings_tab, :string, default: "account"

  def settings_themes(assigns) do
    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Theme"
      checked={@settings_tab == "themes"}
      phx-click="settings-tab"
      phx-value-tab="themes"
    />
    <div class="tab-content w-full max-w-full overflow-hidden border-base-300 bg-base-100/50 p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
        <p class="text-sm font-semibold">Themes</p>
        <div
          id="theme-container"
          class="rounded-box grid w-full max-w-full grid-cols-3 gap-2 sm:grid-cols-4 sm:gap-3 lg:grid-cols-5"
        >
          <%= for theme <- themes() do %>
            <button
              id={"theme-button-" <> theme}
              class="theme-button border-base-content/20 hover:border-base-content/40 min-w-0 overflow-hidden rounded-lg border outline-offset-2"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme={theme}
              tabindex="0"
            >
              <div
                data-theme={theme}
                class="bg-base-100 text-base-content w-full cursor-pointer font-sans"
              >
                <div class="grid grid-cols-5 grid-rows-3">
                  <div class="bg-base-200 col-start-1 row-span-2 row-start-1"></div>
                  <div class="bg-base-300 col-start-1 row-start-3"></div>
                  <div class="bg-base-100 col-span-4 col-start-2 row-span-3 row-start-1 flex min-w-0 flex-col gap-1 p-1.5">
                    <div class="truncate text-xs font-bold">{theme}</div>
                    <div class="flex flex-wrap gap-1">
                      <div class="bg-primary flex aspect-square w-4 items-center justify-center rounded">
                        <div class="text-primary-content text-xs font-bold">A</div>
                      </div>
                      <div class="bg-secondary flex aspect-square w-4 items-center justify-center rounded">
                        <div class="text-secondary-content text-xs font-bold">A</div>
                      </div>
                      <div class="bg-accent flex aspect-square w-4 items-center justify-center rounded">
                        <div class="text-accent-content text-xs font-bold">A</div>
                      </div>
                      <div class="bg-neutral flex aspect-square w-4 items-center justify-center rounded">
                        <div class="text-neutral-content text-xs font-bold">A</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
