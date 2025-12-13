defmodule TripwireWeb.SystemComponent do
  use Phoenix.Component

  def system(assigns) do
      ~H"""
      <div id="system-container" gs-w="6" gs-h="6" gs-x="0" gs-y="0" class="grid-stack-item"  >
        <div class="grid-stack-item-content">
          <div id="system-chart" class="size-full" ></div>
        </div>
      </div>
      """
    end
end
