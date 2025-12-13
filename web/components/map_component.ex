defmodule TripwireWeb.MapComponent do
  use Phoenix.Component

  def map(assigns) do
~H"""
      <div id="map" class="grid-stack-item " gs-w="12" gs-h="6" gs-x="0" gs-y="12">
        <div class="grid-stack-item-content">


<!-- name of each tab group should be unique -->
<div class="tabs tabs-lift">
  <input type="radio" name="my_tabs_3" class="tab" aria-label="Tab 1" />
  <div class="tab-content bg-base-100 border-base-300 p-6">Tab content 1</div>

  <input type="radio" name="my_tabs_3" class="tab" aria-label="Tab 2" checked="checked" />
  <div class="tab-content bg-base-100 border-base-300 p-6">
          <div class="h-screen w-screen" id="treeMap"></div>

  </div>

  <input type="radio" name="my_tabs_3" class="tab" aria-label="Tab 3" />
  <div class="tab-content bg-base-100 border-base-300 p-6">Tab content 3</div>
</div>


        </div>
      </div>
"""
  end

end
