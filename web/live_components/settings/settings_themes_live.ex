defmodule TripwireWeb.LiveComponents.Settings.ThemesLive do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @theme_sections [
    %{
      id: "core",
      label: "Core",
      icon: "hero-cube",
      themes: ["tripwire", "native", "native-dark", "light", "dark", "eve", "carbon"]
    },
    %{
      id: "faction",
      label: "Faction",
      icon: "hero-flag",
      themes: ["amarr", "caldari", "gallente", "minmatar"]
    },
    %{
      id: "pirate",
      label: "Pirate",
      icon: "hero-fire",
      themes: ["angel", "blood", "guristas", "sansha", "serpentis"]
    }
  ]

  def themes, do: Enum.flat_map(@theme_sections, & &1.themes)

  def theme_sections, do: @theme_sections

  attr :settings_tab, :string, default: "account"

  def settings_themes_live(assigns) do
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
      <div class="flex min-h-0 w-full max-w-full flex-col gap-4 overflow-hidden">
        <p class="text-sm font-semibold">Themes</p>
        <%= for section <- theme_sections() do %>
          <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
            <div class="flex items-center gap-1.5">
              <span class={[section.icon, "size-4 opacity-60"]} />
              <p class="text-xs font-semibold uppercase tracking-wider opacity-70">{section.label}</p>
            </div>
            <div
              id={"theme-container-" <> section.id}
              class="rounded-box grid w-full max-w-full grid-cols-3 gap-2 sm:grid-cols-4 sm:gap-3 lg:grid-cols-5"
            >
              <%= for theme <- section.themes do %>
                <button
                  id={"theme-button-" <> theme}
                  class="theme-button border-base-content/20 hover:border-base-content/40 min-w-0 overflow-hidden rounded-lg border outline-offset-2"
                  phx-click={JS.dispatch("phx:set-theme")}
                  data-phx-theme={theme}
                  tabindex="0"
                >
                  <div
                    data-theme={theme}
                    class="bg-base-100 text-base-content flex w-full min-w-0 cursor-pointer items-center gap-1.5 p-2 font-sans"
                  >
                    <img
                      src={"/images/themes/" <> theme <> ".svg"}
                      alt=""
                      aria-hidden="true"
                      class="size-3.5 shrink-0"
                      loading="lazy"
                    />
                    <div class="truncate text-xs font-bold">{theme}</div>
                  </div>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
