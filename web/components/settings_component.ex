defmodule TripwireWeb.SettingsComponent do
  use Phoenix.Component

  def settings(assigns) do
~H"""
<section class="hidden size-full" id="template" >

<div class="tabs tabs-box size-full">
  <input type="radio" name="my_tabs_12s" class="tab" aria-label="Account" checked="checked" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Account Settings
    <section>
        <input type="range" min="0" max="100" value="40" class="range range-primary" />
        <input type="range" min="0" max="100" value="40" class="range range-secondary" />
        <input type="range" min="0" max="100" value="40" class="range range-accent" />
        <input type="range" min="0" max="100" value="40" class="range range-success" />
        <input type="range" min="0" max="100" value="40" class="range range-warning" />
        <input type="range" min="0" max="100" value="40" class="range range-info" />
        <input type="range" min="0" max="100" value="40" class="range range-error" />
    </section>

  </div>
  <input type="radio" name="my_tabs_12s" class="tab" aria-label="Map" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Map Settings
    <section>
        <input type="checkbox" checked="checked" class="toggle toggle-primary" />
        <input type="checkbox" checked="checked" class="toggle toggle-secondary" />
        <input type="checkbox" checked="checked" class="toggle toggle-accent" />
        <input type="checkbox" checked="checked" class="toggle toggle-neutral" />
        <input type="checkbox" checked="checked" class="toggle toggle-info" />
        <input type="checkbox" checked="checked" class="toggle toggle-success" />
        <input type="checkbox" checked="checked" class="toggle toggle-warning" />
        <input type="checkbox" checked="checked" class="toggle toggle-error" />
    </section>
  </div>

  <input type="radio" name="my_tabs_12s" class="tab" aria-label="Widgets" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Widgets
    <section >
        <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-secondary" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-accent" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-neutral" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-info" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-success" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-warning" />
        <input type="checkbox" checked="checked" class="checkbox checkbox-error" />
    </section>
  </div>

  <input type="radio" name="my_tabs_12s" class="tab" aria-label="Theme" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
    Themes
    <section>
        <input
        type="radio" name="radio-12" checked="checked"
        class="radio bg-red-100 border-red-300 checked:bg-red-200 checked:text-red-600 checked:border-red-600" />
        <input
        type="radio" name="radio-12" checked="checked"
        class="radio bg-blue-100 border-blue-300 checked:bg-blue-200 checked:text-blue-600 checked:border-blue-600" />
    </section>
    <section>
        <select class="select select-ghost">
        <option disabled selected>Pick a font</option>
        <option>Inter</option>
        <option>Poppins</option>
        <option>Raleway</option>
        </select>
    </section>
  </div>
</div>


</section>
"""
    end
end
