defmodule TripwireWeb.MapComponent do
  use Phoenix.Component

  def map(assigns) do
      ~H"""
      <div class="grid-stack-item overflow-x-scroll" gs-w="12" gs-h="6">
        <div class="grid-stack-item-content overflow-x-scroll">
          <div class="w-screen h-screen overflow-x-scroll" id="map"></div>
        </div>
      </div>
      """
  end

end
