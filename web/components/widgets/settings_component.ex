defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component
  import TripwireWeb.SettingsAccountComponent
  import TripwireWeb.SettingsMapComponent
  import TripwireWeb.SettingsWidgetsComponent
  import TripwireWeb.SettingsThemesComponent

  def settings(assigns) do
    ~H"""
    <div class="fixed inset-0 z-40 bg-black/50" phx-click="toggle-settings"></div>
    <div class="fixed z-50 top-16 left-2 right-2 bottom-2 sm:left-4 sm:right-4">
      <div class="tabs tabs-box size-full overflow-hidden bg-base-100/95 rounded-lg border border-base-300 shadow-xl">
        <.settings_account />
        <.settings_map />
        <.settings_widgets />
        <.settings_themes />
      </div>
    </div>
    """
  end
end
