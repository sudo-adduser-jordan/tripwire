defmodule TripwireWeb.SettingsThemesComponent do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @themes [
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

  def settings_themes(assigns) do
~H"""
        <input type="radio" name="my_tabs_6" class="tab" aria-label="Theme" />
        <div class="tab-content size-full overflow-y-scroll bg-base-100 border-base-300 p-6" enabled>
          Themes
          <div
            id="theme-container"
            class="rounded-box size-fit overflow-y-scroll p-4 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5"
          >
            <%= for theme <- themes() do %>
              <button
              id={"theme-button-" <> theme }
                class={
                      "theme-button border-base-content/20 hover:border-base-content/40 overflow-hidden rounded-lg border outline-offset-2"
                    }
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
                    <div class="bg-base-100 col-span-4 col-start-2 row-span-3 row-start-1 flex flex-col gap-1 p-2">
                      <div class="font-bold">{theme}</div>
                      <div class="flex flex-wrap gap-1">
                        <div class="bg-primary flex aspect-square w-5 items-center justify-center rounded lg:w-6">
                          <div class="text-primary-content text-sm font-bold">A</div>
                        </div>
                        <div class="bg-secondary flex aspect-square w-5 items-center justify-center rounded lg:w-6">
                          <div class="text-secondary-content text-sm font-bold">A</div>
                        </div>
                        <div class="bg-accent flex aspect-square w-5 items-center justify-center rounded lg:w-6">
                          <div class="text-accent-content text-sm font-bold">A</div>
                        </div>
                        <div class="bg-neutral flex aspect-square w-5 items-center justify-center rounded lg:w-6">
                          <div class="text-neutral-content text-sm font-bold">A</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </button>
            <% end %>
          </div>
        </div>
"""
  end
end
