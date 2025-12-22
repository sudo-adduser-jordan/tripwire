defmodule TripwireWeb.SettingsWidgetsComponent do
  use Phoenix.Component

  def settings_widgets(assigns) do
~H"""
    <input type="radio" name="my_tabs_6" class="tab" aria-label="Widgets" />
    <div class="tab-content overflow-y-scroll bg-base-100/50 border-base-300 p-6  " enabled>
      Widgets
      <div class="p-4 flex flex-col gap-1">
        <div class="flex flex-row gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />
          <p>System</p>
        </div>

        <div class="flex flex-row gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-secondary" />
          <p>Notes</p>
        </div>

        <div class="flex flex-row gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-accent" />
          <p>Signatures</p>
        </div>

        <div class="flex flex-row gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-neutral" />
          <p>Map</p>
        </div>

        <div class="flex flex-row gap-4">
          <input type="checkbox" checked="checked" class="checkbox checkbox-info" />
          <p>Settings</p>
        </div>
      </div>
    </div>
"""
  end
end
