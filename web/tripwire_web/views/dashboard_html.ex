defmodule TripwireWeb.DashboardHTML do
  use TripwireWeb, :html
  embed_templates "dashboard.html"

  attr :user, :string

  def navigation(assigns) do
    ~H"""
    <nav class="flex flex-col gap-2 sm:gap-0 sm:flex-row">
      <nav class="flex flex-row bg-base-200 p-2 w-full h-fit gap-2">

        <div class="flex justify-center items-center gap-1">
        <div class="inline-grid *:[grid-area:1/1]">
          <div class="status status-error animate-ping"></div>
          <div class="status status-error"></div>
        </div>
        </div>

        <div class="hover:cursor-pointer hover:underline place-content-center flex gap-1 justify-center items-center">
        TQ
        <div class="badge badge-error">Down</div>
        </div>

        <div>|</div>
        <div class="hover:cursor-pointer hover:underline place-content-center">System</div>
        <div>&gt;</div>
        <input class="bg-base-100 rounded w-36 sm:w-42" placeholder="Search systems" />
      </nav>

      <nav class="flex flex-row justify-start sm:justify-end bg-base-200 p-2 h-fit gap-2">
        <button id="lock-toggle" class="">
          <svg
            id="lockImage"
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="#ff6700"
          >
            <path d="M21 2h-5v20h5c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1M2 21c0 .6.4 1 1 1h11v-9H2zM2 3v8h12V2H3c-.6 0-1 .4-1 1" />
          </svg>
        </button>
        <div class=" hover:cursor-pointer hover:underline">{@user}</div>
        <p class="  ">&gt;</p>
        <div class=" hover:cursor-pointer hover:underline">Corporation</div>
      </nav>
    </nav>
    """
  end

  def settings(assigns) do
    ~H"""
    """
  end

  def system(assigns) do
    ~H"""
    <div class="grid-stack-item" gs-w="4" gs-h="3">
      <div class="grid-stack-item-content">
        <div class="size-full" id="system-chart"></div>
      </div>
    </div>
    """
  end

  def map(assigns) do
    ~H"""
    <div class="grid-stack-item" gs-w="12" gs-h="6">
      <div class="grid-stack-item-content">
        <div class="size-full" id="map"></div>
      </div>
    </div>
    """
  end

  def signatures(assigns) do
    ~H"""
    <div class="grid-stack-item" gs-w="4" gs-h="3">
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

  def notes(assigns) do
    ~H"""
    <div class="grid-stack-item" gs-w="4" gs-h="3">
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
