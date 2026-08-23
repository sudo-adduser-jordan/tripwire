defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component
  import TripwireWeb.SettingsAccountComponent
  import TripwireWeb.SettingsMapComponent
  import TripwireWeb.SettingsWidgetsComponent
  import TripwireWeb.SettingsThemesComponent

  def settings(assigns) do
    ~H"""
    <div
      id="settings-modal"
      class="fixed inset-0 z-40"
      phx-window-keydown="toggle-settings"
      phx-key="Escape"
    >
      <div class="absolute inset-0 bg-black/60" phx-click="toggle-settings"></div>

      <div class="absolute z-10 top-13 left-2 right-2 bottom-2 sm:left-4 sm:right-4 flex flex-col">
        <div class="tabs tabs-box flex-1 overflow-hidden bg-base-100 rounded-lg border border-base-300 shadow-xl min-h-0">
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
