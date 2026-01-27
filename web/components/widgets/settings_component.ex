defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component
    import TripwireWeb.SettingsAccountComponent
    import TripwireWeb.SettingsMapComponent
    import TripwireWeb.SettingsWidgetsComponent
    import TripwireWeb.SettingsThemesComponent

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
      <div class="tabs tabs-box size-full overflow-hidden bg-base-100/50">
            <.settings_account />
            <.settings_map />
            <.settings_widgets />
            <.settings_themes />
      </div>
    </div>
"""
  end
end
