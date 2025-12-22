defmodule TripwireWeb.NotesComponent do
  use Phoenix.Component
  import TripwireWeb.IconComponent

  def notes(assigns) do
    ~H"""
    <div id="notes" class="grid-stack-item" gs-w="6" gs-h="6" gs-x="6" gs-y="0" tabindex="0">
      <div class="grid-stack-item-content bg-base-100/50">
        <ul class="list rounded-box shadow-md">
          <li class="list-row h-fit p-1">
            <div tabindex="0">
              <.icon name="hero-document-plus" class="m-1 size-6" />
            </div>
            <div tabindex="0">
              <.icon name="hero-pencil-square" class="m-1 size-6" />
            </div>
            <div tabindex="0">
              <.icon name="hero-trash" class="m-1 size-6" />
            </div>
          </li>
        </ul>

        <div class="w-full text-center p-4">
          mdx
        </div>
      </div>
    </div>
    """
  end
end
