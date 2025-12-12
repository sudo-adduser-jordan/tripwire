defmodule TripwireWeb.SignaturesComponent do
  use Phoenix.Component

  def signatures(assigns) do
      ~H"""

        <div class="grid-stack-item" gs-w="4" gs-h="3" id='signatures'>
          <div class="grid-stack-item-content">
            <ul class="list bg-base-100 rounded-box shadow-md">
              <li class="list-row h-fit p-1">
                <div>Add</div>
                <div>Edit</div>
                <div>Undo</div>
                <div>Redo</div>
                <div>Delete</div>
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

              <li class="list-row h-fit p-1">
                <div>ID</div>
                <div>Type</div>
                <div>Age</div>
                <div>Name</div>
                <div>Life</div>
                <div>Mass</div>
              </li>

              <li class="list-row h-fit p-1">
                <div>ID</div>
                <div>Type</div>
                <div>Age</div>
                <div>Name</div>
                <div>Life</div>
                <div>Mass</div>
              </li>

              <li class="list-row h-fit p-1">
                <div>ID</div>
                <div>Type</div>
                <div>Age</div>
                <div>Name</div>
                <div>Life</div>
                <div>Mass</div>
              </li>

              <li class="list-row h-fit p-1">
                <div>ID</div>
                <div>Type</div>
                <div>Age</div>
                <div>Name</div>
                <div>Life</div>
                <div>Mass</div>
              </li>

              <li class="list-row h-fit p-1">
                <div>ID</div>
                <div>Type</div>
                <div>Age</div>
                <div>Name</div>
                <div>Life</div>
                <div>Mass</div>
              </li>

              <li class="list-row h-fit p-1">
                <div>ID</div>
                <div>Type</div>
                <div>Age</div>
                <div>Name</div>
                <div>Life</div>
                <div>Mass</div>
              </li>
            </ul>
          </div>
        </div>
      """
    end
end
