defmodule TripwireWeb.LiveComponents.SettingsLive do
  use Phoenix.Component

  alias TripwireWeb.LiveComponents.Settings.AccountLive
  alias TripwireWeb.LiveComponents.Settings.AdminLive
  alias TripwireWeb.LiveComponents.Settings.MapLive
  alias TripwireWeb.LiveComponents.Settings.ThemesLive
  alias TripwireWeb.LiveComponents.Settings.WidgetsLive

  attr :map_layout, :string, default: "top"
  attr :show_row_guides, :boolean, default: false
  attr :show_row_counts, :boolean, default: false
  attr :angled_lines, :boolean, default: true
  attr :settings_tab, :string, default: "account"
  attr :characters, :list, default: []
  attr :masks, :list, default: []
  attr :character, :any, default: nil
  attr :mask, :any, default: nil

  def settings_live(assigns) do
    ~H"""
    <div
      id="settings-widget"
      class="grid-stack-item scroll-mt-24"
      gs-w="12"
      gs-h="10"
      gs-x="0"
      gs-y="0"
      tabindex="0"
      phx-hook="GridWidget"
      phx-window-keydown="toggle-settings"
      phx-key="Escape"
    >
      <div
        id="settings-content"
        class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden"
        phx-hook="ScrollIntoView"
      >
        <div class="tabs tabs-box max-w-full min-h-0 size-full">
          <AccountLive.settings_account_live
            settings_tab={@settings_tab}
            characters={@characters}
            masks={@masks}
            character={@character}
            mask={@mask}
          />
          <MapLive.settings_map_live
            map_layout={@map_layout}
            settings_tab={@settings_tab}
            show_row_guides={@show_row_guides}
            show_row_counts={@show_row_counts}
            angled_lines={@angled_lines}
          />
          <WidgetsLive.settings_widgets_live settings_tab={@settings_tab} />
          <ThemesLive.settings_themes_live settings_tab={@settings_tab} />
          <AdminLive.settings_admin_live
            settings_tab={@settings_tab}
            character={@character}
            masks={@masks}
          />
        </div>
      </div>
    </div>
    """
  end
end
