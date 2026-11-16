defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component
  import TripwireWeb.SettingsAccountComponent
  import TripwireWeb.SettingsMapComponent
  import TripwireWeb.SettingsWidgetsComponent
  import TripwireWeb.SettingsThemesComponent

  def settings(assigns) do
    ~H"""
    <div
      id="settings-widget"
      class="grid-stack-item"
      gs-w="12"
      gs-h="9"
      gs-x="0"
      gs-y="18"
      tabindex="0"
      phx-hook="GridWidget"
      phx-window-keydown="toggle-settings"
      phx-key="Escape"
    >
      <div class="grid-stack-item-content bg-base-100/50 overflow-hidden">
        <div class="tabs tabs-box size-full overflow-hidden">
          <.settings_account />
          <.settings_map />
          <.settings_widgets />
          <.settings_themes />
        </div>
      </div>
    </div>
    """
  end
end
