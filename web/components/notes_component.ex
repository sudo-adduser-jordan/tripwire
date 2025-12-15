defmodule TripwireWeb.NotesComponent do
  use Phoenix.Component
  import TripwireWeb.IconComponent

  def notes(assigns) do
~H"""
<div id="notes" class="grid-stack-item" gs-w="6" gs-h="6" gs-x="6" gs-y="0">
  <div class="grid-stack-item-content">
    <ul class="list bg-base-100 rounded-box shadow-md">
      <li class="list-row h-fit p-1">
        <.icon name="hero-document-plus" class="m-1 size-6" />
        <.icon name="hero-pencil-square" class="m-1 size-6" />
        <.icon name="hero-trash" class="m-1 size-6" />
      </li>
    </ul>

    <div class="w-full text-center p-4">
      Press
      <kbd class="kbd kbd-sm">F</kbd>
      to pay respects.
    </div>

  </div>
</div>
"""
  end
end
