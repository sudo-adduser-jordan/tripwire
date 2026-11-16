defmodule TripwireWeb.SettingsWidgetsComponent do
  use Phoenix.Component

  attr :settings_tab, :string, default: "account"

  def settings_widgets(assigns) do
    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Widgets"
      checked={@settings_tab == "widgets"}
      phx-click="settings-tab"
      phx-value-tab="widgets"
    />
    <div class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
        <p class="text-sm font-semibold">Widgets</p>
        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-primary checkbox-sm" />
          <p class="text-sm">System</p>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-secondary checkbox-sm" />
          <p class="text-sm">Notes</p>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-accent checkbox-sm" />
          <p class="text-sm">Signatures</p>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-neutral checkbox-sm" />
          <p class="text-sm">Map</p>
        </div>

        <div class="flex min-w-0 flex-row flex-wrap items-center gap-2 sm:gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-info checkbox-sm" />
          <p class="text-sm">Settings</p>
        </div>
      </div>
    </div>
    """
  end
end
