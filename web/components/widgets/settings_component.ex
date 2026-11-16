defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component
  import TripwireWeb.SettingsAccountComponent
  import TripwireWeb.SettingsMapComponent
  import TripwireWeb.SettingsWidgetsComponent
  import TripwireWeb.SettingsThemesComponent

  attr :map_layout, :string, default: "default"
  attr :settings_tab, :string, default: "account"

  def settings(assigns) do
    ~H"""
    <div
      id="settings-widget"
      class="grid-stack-item"
      gs-w="12"
      gs-h="10"
      gs-x="0"
      gs-y="0"
      tabindex="0"
      phx-hook="GridWidget"
      phx-window-keydown="toggle-settings"
      phx-key="Escape"
    >
      <div class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden">
        <div class="tabs tabs-box max-w-full min-h-0 size-full">
          <.settings_account settings_tab={@settings_tab} />
          <.settings_map map_layout={@map_layout} settings_tab={@settings_tab} />
          <.settings_widgets settings_tab={@settings_tab} />
          <.settings_themes settings_tab={@settings_tab} />
        </div>
      </div>
    </div>
    """
  end
end
