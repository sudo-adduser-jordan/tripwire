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
      themes: ["phoenix", "carbon", "eve-online"]
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

  defp theme_icon(theme) do
    case Map.get(@faction_theme_ids, theme) do
      nil -> "/images/themes/" <> theme <> ".svg"
      faction_id -> EveImages.faction_logo(faction_id, 64)
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
      class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4"
    >
      <div class="flex min-h-0 w-full max-w-full flex-col gap-3">
        <p class="text-sm font-semibold">Themes</p>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Solid background</p>
          <input
            id="toggle-solid-background"
            data-solid-toggle
            type="checkbox"
            class="toggle toggle-primary toggle-sm"
            phx-click={JS.dispatch("phx:set-solid")}
          />
        </div>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <p class="w-28 shrink-0 text-sm leading-tight sm:w-40">Font</p>
          <select id="font-select" data-font-select class="select select-sm w-full max-w-48">
            <option value="eve">EVE Online</option>
            <option value="sans">Sans</option>
            <option value="mono">Mono</option>
            <option value="serif">Serif</option>
            <option value="theme">Theme default</option>
          </select>
        </div>
        <%= for section <- theme_sections() do %>
          <div class="flex min-h-0 w-full max-w-full flex-col gap-2">
            <div class="flex items-center gap-1.5">
              <span class={[section.icon, "size-4 opacity-60"]} />
              <p class="settings-section-label">{section.label}</p>
            </div>
            <div
              id={"theme-container-" <> section.id}
              class="grid w-full max-w-full grid-cols-2 gap-2 md:grid-cols-3 2xl:grid-cols-4"
            >
              <%= for theme <- section.themes do %>
                <button
                  id={"theme-button-" <> theme}
                  class="theme-button settings-card border-base-300 hover:border-base-content/40 focus-visible:ring-success min-w-0 overflow-hidden border transition-colors focus-visible:ring-2 focus-visible:outline-none"
                  phx-click={JS.dispatch("phx:set-theme")}
                  data-phx-theme={theme}
                >
                  <div
                    data-theme={theme}
                    class="text-base-content flex w-full min-w-0 cursor-pointer items-center gap-2 font-sans"
                  >
                    <img
                      src={theme_icon(theme)}
                      alt=""
                      aria-hidden="true"
                      class="size-6 shrink-0 rounded"
                      loading="lazy"
                      onerror="this.onerror=null;this.src='/images/alliance-default.png'"
                    />
                    <div class="truncate text-xs font-semibold">{theme}</div>
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
