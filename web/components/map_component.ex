defmodule TripwireWeb.MapComponent do
  use Phoenix.Component

  def map(assigns) do
      ~H"""
      <div id="map" class="grid-stack-item " gs-w="12" gs-h="6" gs-x="0" gs-y="12">
        <div class="grid-stack-item-content">
          <div class="h-screen w-screen" id="treeMap"></div>
        </div>
      </div>
      """
  end

end
