defmodule TripwireWeb.SignaturesComponent do
  use Phoenix.Component
  import TripwireWeb.IconComponent

  def signatures(assigns) do
    ~H"""
    <div id="signatures" class="grid-stack-item" gs-w="12" gs-h="6" gs-x="0" gs-y="6" tabindex="0">
      <div class="grid-stack-item-content">
        <ul class="list bg-base-100 rounded-box shadow-md">
          <li class="list-row h-fit p-1">
            <.icon name="hero-plus-circle" class="m-1 size-6" />
            <.icon name="hero-pencil-square" class="m-1 size-6" />
            <.icon name="hero-arrow-uturn-left" class="m-1 size-6" />
            <.icon name="hero-arrow-uturn-right" class="m-1 size-6" />
            <.icon name="hero-trash" class="m-1 size-6" />
          </li>
        </ul>

        <ul class="list bg-base-100 rounded-box shadow-md">
          <li class="list-row h-fit p-1">
            <div>ID</div>
            <div>Type</div>
            <div>Age</div>
            <div>Name</div>
            <div>Life</div>
            <div>Mass</div>
          </li>
        </ul>

        <div class="w-full text-center p-4">
          Press <kbd class="kbd kbd-sm">F</kbd> to pay respects.
        </div>

        <div class="w-full text-center p-4">
          <kbd class="kbd">ctrl</kbd> + <kbd class="kbd">v</kbd>
        </div>

        <div class="w-full text-center p-4">
          <kbd class="kbd">ctrl</kbd> + <kbd class="kbd">c</kbd>
        </div>
      </div>
    </div>
    """
  end
end
