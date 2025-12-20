defmodule TripwireWeb.MapComponent do
  use Phoenix.Component
  import TripwireWeb.IconComponent

  def map(assigns) do
    ~H"""
    <div id="map" class="grid-stack-item " gs-w="12" gs-h="6" gs-x="0" gs-y="12">
      <div class="grid-stack-item-content">

    <!-- name of each tab group should be unique -->
        <div class="tabs tabs-lift">
          <.icon name="hero-folder-plus" class="m-1 size-6" />
              <.icon name="hero-pencil-square" class="m-1 size-6" />
          <.icon name="hero-star" class="m-1 size-6" />
          <.icon name="hero-rocket-launch" class="m-1 size-6" />
          <.icon name="hero-eye" class="m-1 size-6" />

          <input type="radio" name="my_tabs_3" class="tab" aria-label="Intructions" />
          <div class="tab-content bg-base-100 border-base-300 p-6">
            <section class="flex flex-col p-4">
              <div class="w-full text-center p-4">
                Press <kbd class="kbd">ctrl</kbd> + <kbd class="kbd">v</kbd> to paste items
              </div>

              <div class="w-full text-center p-4">
                Press <kbd class="kbd">ctrl</kbd> + <kbd class="kbd">a</kbd> to select all items
              </div>

              <div class="w-full text-center p-4">
                Press <kbd class="kbd">ctrl</kbd> + <kbd class="kbd">c</kbd> to copy items
              </div>

              <div class="w-full text-center p-4">
                Press <kbd class="kbd">delete</kbd> to delete items
              </div>

              <div class="w-full text-center p-4">
                Press <kbd class="kbd">click</kbd> to pan and <kbd class="kbd">scroll</kbd> to zoom.
              </div>
            </section>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="Tab 1" checked />
          <div class="tab-content bg-base-100 border-base-300 p-6">
            <div class="h-screen w-screen" id="treeMap"></div>
          </div>

        </div>
      </div>
    </div>
    """
  end
end
