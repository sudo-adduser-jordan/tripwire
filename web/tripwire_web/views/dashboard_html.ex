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

        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="rounded-field hover:cursor-pointer hover:underline">
            {@user}
          </div>
          <ul
            tabindex="-1"
            class="menu dropdown-content bg-base-200 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
          >
            <li>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-12 rounded-xl">
                    <img src="https://img.daisyui.com/images/profile/demo/yellingwoman@192.webp" />
                  </div>
                </div>
                Character 1
              </a>
            </li>
            <li>
              <a>
                <div class="avatar avatar-offline">
                  <div class="w-12 rounded-xl">
                    <img src="https://img.daisyui.com/images/profile/demo/yellingcat@192.webp" />
                  </div>
                </div>
                Character 2
              </a>
            </li>
            <li>
              <a>
                <div class="avatar avatar-offline">
                  <div class="rounded-xl w-12">
                    <img src="https://img.daisyui.com/images/profile/demo/distracted2@192.webp" />
                  </div>
                </div>
                Character 3
              </a>
            </li>
          </ul>
        </div>

        <p class="  ">&gt;</p>

        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="rounded-field hover:cursor-pointer hover:underline">
            Corporation
          </div>
          <ul
            tabindex="-1"
            class="menu dropdown-content bg-base-200 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
          >
            <li>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-24 rounded-xl">
                    <img src="https://img.daisyui.com/images/profile/demo/gordon@192.webp" />
                  </div>
                </div>
                Mask 1
              </a>
            </li>
            <li>
              <a>
                <div class="avatar avatar-offline">
                  <div class="w-24 rounded-xl">
                    <img src="https://img.daisyui.com/images/profile/demo/gordon@192.webp" />
                  </div>
                </div>
                Mask 2
              </a>
            </li>
          </ul>
        </div>
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
    <div class="grid-stack-item overflow-x-scroll" gs-w="4" gs-h="3">
      <div class="grid-stack-item-content overflow-x-scroll">
        <div class="size-full overflow-x-scroll" id="system-chart"></div>
      </div>
    </div>
    """
  end

  def map(assigns) do
    ~H"""
    <div class="grid-stack-item overflow-x-scroll" gs-w="12" gs-h="6">
      <div class="grid-stack-item-content overflow-x-scroll">
        <div class="w-screen h-screen overflow-x-scroll" id="map"></div>
      </div>
    </div>
    """
  end

  @spec signatures(any()) :: Phoenix.LiveView.Rendered.t()
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
