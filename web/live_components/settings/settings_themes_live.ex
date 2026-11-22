defmodule TripwireWeb.LiveComponents.Settings.ThemesLive do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  alias Tripwire.EveImages

  @faction_theme_ids %{
    "amarr" => 500_003,
    "caldari" => 500_001,
    "gallente" => 500_004,
    "minmatar" => 500_002,
    "angel" => 500_011,
    "blood" => 500_012,
    "guristas" => 500_010,
    "sansha" => 500_019,
    "serpentis" => 500_020
  }

  @theme_sections [
    %{
      id: "core",
      label: "Core",
      icon: "hero-cube",
      themes: ["phoenix", "eve", "carbon"]
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
    },
    %{
      id: "mapper",
      label: "Mapper",
      icon: "hero-map",
      themes: ["tripwire", "wanderer"]
    }
  ]

  def themes, do: Enum.flat_map(@theme_sections, & &1.themes)

  def theme_sections, do: @theme_sections

  defp theme_icon(theme) do
    case Map.get(@faction_theme_ids, theme) do
      nil -> "/images/themes/" <> theme <> ".svg"
      faction_id -> EveImages.faction_logo(faction_id, 32)
    end
  end

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
    <div
      id="theme-settings"
      phx-hook="ThemeSelect"
      class="tab-content w-full max-w-full overflow-hidden border-base-300 bg-base-100/50 p-3 sm:p-4"
    >
      <div class="flex min-h-0 w-full max-w-full flex-col gap-4">
        <p class="text-sm font-semibold">Themes</p>
        <%= for section <- theme_sections() do %>
          <div class="flex min-h-0 w-full max-w-full flex-col gap-2">
            <div class="flex items-center gap-1.5">
              <span class={[section.icon, "size-4 opacity-60"]} />
              <p class="text-xs font-semibold uppercase tracking-wider opacity-70">{section.label}</p>
            </div>
            <div
              id={"theme-container-" <> section.id}
              class="rounded-box grid w-full max-w-full grid-cols-[repeat(auto-fill,minmax(min(10rem,100%),10rem))] gap-2 sm:gap-3"
            >
              <%= for theme <- section.themes do %>
                <button
                  id={"theme-button-" <> theme}
                  class="theme-button border-base-content/20 hover:border-base-content/40 min-w-0 overflow-hidden rounded-lg border outline-offset-2"
                  phx-click={JS.dispatch("phx:set-theme")}
                  data-phx-theme={theme}
                >
                  <div
                    data-theme={theme}
                    class="bg-base-100 text-base-content flex w-full min-w-0 cursor-pointer items-center gap-1.5 p-2 font-sans"
                  >
                    <img
                      src={theme_icon(theme)}
                      alt=""
                      aria-hidden="true"
                      class="size-3.5 shrink-0 rounded-[3px]"
                      loading="lazy"
                      onerror="this.onerror=null;this.src='/images/alliance-default.png'"
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
