defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component

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

  def settings(assigns) do
    ~H"""
    <div class="hidden size-full overflow-hidden" id="settings-template">
      <div class="tabs tabs-box size-full overflow-hidden">
        <input type="radio" name="my_tabs_6" class="tab" aria-label="Account" checked="checked" />
        <div class="tab-content overflow-hidden w-full  bg-red-300 border-base-300 p-6" enabled>
          <div class="size-full flex flex-col gap-4 overflow-y-scroll">
            <p class="p-2">Account</p>
            <p class="p-2">Last login: 2025-12-12 09:40:22</p>

            <div class="w-full h-fit flex flex-col md:flex-row gap-4 bg-amber-200 p-4">
              Characters
              <div class="stats shadow overflow-hidden md:w-84 h-fit " tabindex="0">
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

            <div class="w-full h-fit flex flex-col md:flex-row gap-4 bg-amber-200 p-4">
              Masks
              <div class="stats shadow overflow-hidden md:w-84 h-fit " tabindex="0">
                <div class="stat overflow-hidden flex flex-col">
                  <div class="avatar avatar-online">
                    <div class="w-16 rounded-xl">
                      <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
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
                      <img src="https://img.daisyui.com/images/profile/demo/anakeen@192.webp" />
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

        <input type="radio" name="my_tabs_6" class="tab" aria-label="Widgets" />
        <div class="tab-content overflow-y-scroll bg-base-100 border-base-300 p-6  " enabled>
          Widgets
          <div class="p-4 flex flex-col gap-1">
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
              <input type="checkbox" checked="checked" class="checkbox checkbox-info" />
              <p>Settings</p>
            </div>
          </div>
        </div>

        <input type="radio" name="my_tabs_6" class="tab" aria-label="Theme" />
        <div class="tab-content size-full overflow-y-scroll bg-base-100 border-base-300 p-6" enabled>
          Themes
          <div
            id="theme-container"
            class="rounded-box size-fit overflow-y-scroll p-4 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5"
          >
            <%= for theme <- themes() do %>
              <button
                class={
                      "border-base-content/20 hover:border-base-content/40 overflow-hidden rounded-lg border outline-2 outline-offset-2 z-10"
                       <>
                      (if theme == "dark" do "outline" else "outline-transparent " end)
                    }
                data-set-theme={theme}
                onclick={
                            "document.documentElement.setAttribute('data-theme', '" <> theme <> "')"
                    }
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
      </div>
    </div>
    """
  end
end
