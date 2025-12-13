defmodule TripwireWeb.NotesComponent do
  use Phoenix.Component

  def notes(assigns) do
      ~H"""
      <div id="notes" class="grid-stack-item" gs-w="6" gs-h="6" gs-x="6" gs-y="0">
        <div class="grid-stack-item-content">
          <ul class="list bg-base-100 rounded-box shadow-md">
            <li class="list-row h-fit p-1">
              <div>Add</div>
              <div>Edit</div>
              <div>Delete</div>
            </li>
          </ul>
        </div>
      </div>
      """
  end
end
