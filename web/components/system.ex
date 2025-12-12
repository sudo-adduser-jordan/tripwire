defmodule TripwireWeb.SystemComponent do
  use Phoenix.Component

  def system(assigns) do
      ~H"""
      <div class="grid-stack-item overflow-x-scroll" gs-w="4" gs-h="3">
        <div class="grid-stack-item-content overflow-x-scroll">
          <div class="size-full overflow-x-scroll" id="system-chart"></div>
        </div>
      </div>
      """
    end
end
