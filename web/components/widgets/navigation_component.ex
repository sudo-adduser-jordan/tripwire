defmodule TripwireWeb.NavigationComponent do
  use Phoenix.Component

  attr :user, :string, required: true
  def navigation(assigns) do
~H"""
      <nav class="flex items-center content-center flex-col gap-2 sm:gap-0 sm:flex-row ">

            <nav class="flex items-center content-center flex-row bg-base-200 rounded sm:rounded-none sm:rounded-l-lg p-2 h-12 w-full  gap-2">

              <div class="m-1 flex justify-center items-center gap-1">
                <div class="inline-grid *:[grid-area:1/1]">
                  <div class="status status-error animate-ping"></div>
                  <div class="status status-error"></div>
                </div>
              </div>

              <div class="m-1 hover:cursor-pointer hover:underline place-content-center flex gap-1 justify-center items-center">
                <p>TQ</p>
                <div class="badge badge-error m-1">Down</div>
              </div>

              <p class="flex items-center">|</p>
                <p>00:00</p>
              <p class="flex items-center">|</p>


              <div class="hover:cursor-pointer hover:underline place-content-center px-2 text-center">Jita</div>
              <div class="hidden min-[400px]:flex items-center">&gt;</div>

              <input class="mx-1 px-2 py-1 bg-base-100 rounded h-7/10 w-36 sm:w-42 hidden min-[400px]:block" placeholder="Search systems" />

            </nav>

            <nav class="flex flex-row justify-start items-center sm:justify-end bg-base-200 sm:rounded-none  gap-2 rounded sm:rounded-r-lg  p-2 h-12 w-full">
              <button id="lock-button" class="">
                <svg
                  id="lock-svg"
                  xmlns="http://www.w3.org/2000/svg"
                  width="24"
                  height="24"
                  viewBox="0 0 24 24"
                  fill="#605dff"

                >
                  <path d="M21 2h-5v20h5c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1M2 21c0 .6.4 1 1 1h11v-9H2zM2 3v8h12V2H3c-.6 0-1 .4-1 1" />
                </svg>
              </button>

              <div class="dropdown dropdown-start">
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

end
