defmodule TripwireWeb.LiveComponents.NavigationLive do
  use Phoenix.Component

  attr :user, :string, required: true
  attr :characters, :list, default: []
  attr :masks, :list, default: []

  def navigation_live(assigns) do
    ~H"""
    <nav class="flex w-full max-w-full flex-col gap-2 p-2 sm:flex-row sm:gap-0 sm:p-3">
      <nav class="flex h-auto min-h-12 w-full items-center gap-2 rounded bg-base-200/75 p-2 sm:rounded-none sm:rounded-l-lg">
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
        <div class="hover:cursor-pointer hover:underline place-content-center px-2 text-center">
          Jita
        </div>
        <div class="hidden min-[400px]:flex items-center">&gt;</div>
        <input
          class="mx-1 h-8 w-36 rounded bg-base-100 px-2 py-1 sm:w-44 hidden min-[400px]:block"
          placeholder="Search systems"
        />
      </nav>
      <nav class="flex h-auto min-h-12 w-full flex-row items-center justify-start gap-2 rounded bg-base-200/75 p-2 sm:justify-end sm:rounded-none sm:rounded-r-lg">
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
            class="menu dropdown-content bg-base-200/75 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
          >
            <li :for={character <- @characters}>
              <a>
                <div class="avatar avatar-offline">
                  <div class="w-12 rounded-xl">
                    <img src="/images/alliance-default.png" />
                  </div>
                </div>
                {character_name(character)}
              </a>
            </li>
            <li :if={@characters == []}>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-12 rounded-xl">
                    <img src="/images/alliance-default.png" />
                  </div>
                </div>
                {@user}
              </a>
            </li>
          </ul>
        </div>
        <p>&gt;</p>
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="rounded-field hover:cursor-pointer hover:underline">
            Corporation
          </div>
          <ul
            tabindex="-1"
            class="menu dropdown-content bg-base-200/75 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
          >
            <li :for={mask <- @masks}>
              <a>
                <div class="avatar avatar-offline">
                  <div class="w-24 rounded-xl">
                    <img src="/images/alliance-default.png" />
                  </div>
                </div>
                {mask.name}
              </a>
            </li>
            <li :if={@masks == []}>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-24 rounded-xl">
                    <img src="/images/alliance-default.png" />
                  </div>
                </div>
                Demo
              </a>
            </li>
          </ul>
        </div>
      </nav>
    </nav>
    """
  end

  defp character_name(%{name: name}), do: name
  defp character_name(name) when is_binary(name), do: name
end
