defmodule TripwireWeb.LiveComponents.NavigationLive do
  use Phoenix.Component

  attr :user, :string, required: true
  attr :characters, :list, default: []
  attr :masks, :list, default: []
  attr :tq_online, :boolean, default: false
  attr :tq_players, :any, default: nil
  attr :selected_system_name, :any, default: nil
  attr :current_system_name, :any, default: nil
  attr :character_online, :any, default: nil
  attr :ship_name, :any, default: nil
  attr :topbar_now, :any, default: nil
  attr :grid_locked, :boolean, default: true
  attr :system_search, :string, default: ""

  def navigation_live(assigns) do
    ~H"""
    <nav class="flex w-full max-w-full flex-col gap-2 p-2 sm:flex-row sm:gap-0 sm:p-3">
      <nav class="flex h-auto min-h-12 w-full items-center gap-2 rounded bg-base-200/75 p-2 sm:rounded-none sm:rounded-l-lg">
        <div class="m-1 flex justify-center items-center gap-1">
          <div class="inline-grid *:[grid-area:1/1]" aria-hidden="true">
            <div class={[
              "status animate-[ping_2.4s_cubic-bezier(0,0,0.2,1)_infinite] opacity-40",
              if(@tq_online, do: "status-success", else: "status-error")
            ]}>
            </div>
            <div class={[
              "status blur-[3px] opacity-70",
              if(@tq_online, do: "status-success", else: "status-error")
            ]}>
            </div>
            <div class={["status", if(@tq_online, do: "status-success", else: "status-error")]}></div>
          </div>
        </div>
        <div
          class="m-1 hover:cursor-pointer hover:underline place-content-center flex gap-1 justify-center items-center"
          title={tq_title(@tq_online, @tq_players)}
        >
          <p>TQ</p>
          <div class={["badge m-1", if(@tq_online, do: "badge-success", else: "badge-error")]}>
            {if @tq_online, do: format_players(@tq_players), else: "Down"}
          </div>
        </div>
        <p class="flex items-center">|</p>
        <p class="tabular-nums" title="EVE time (UTC)">{format_time(@topbar_now)}</p>
        <p class="flex items-center">|</p>
        <div
          id="topbar-system"
          class="hover:cursor-pointer hover:underline place-content-center px-2 text-center"
          title={if @character_online == false, do: "Character offline"}
        >
          {@selected_system_name || @current_system_name || "Jita"}
        </div>
        <div :if={@ship_name} class="hidden text-xs opacity-60 min-[400px]:block max-w-32 truncate">
          {@ship_name}
        </div>
        <div class="hidden min-[400px]:flex items-center">&gt;</div>
        <form
          phx-submit="system-search-submit"
          class="hidden min-[400px]:block"
        >
          <input
            id="system-search"
            name="search"
            value={@system_search}
            class="mx-1 h-8 w-36 rounded bg-base-100 px-2 py-1 sm:w-44"
            placeholder="Search systems"
            autocomplete="off"
          />
        </form>
      </nav>
      <nav class="flex h-auto min-h-12 w-full flex-row items-center justify-start gap-2 rounded bg-base-200/75 p-2 sm:justify-end sm:rounded-none sm:rounded-r-lg">
        <button
          id="lock-button"
          phx-click="toggle-grid-lock"
          title={if @grid_locked, do: "Unlock dashboard layout", else: "Lock dashboard layout"}
        >
          <svg
            id="lock-svg"
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill={if @grid_locked, do: "#605dff", else: "#ff6700"}
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
                <div class={["avatar", online_class(@character_online)]}>
                  <div class="w-12 rounded-xl">
                    <img src="/images/alliance-default.png" alt="" loading="lazy" />
                  </div>
                </div>
                {character_name(character)}
              </a>
            </li>
            <li :if={@characters == []}>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-12 rounded-xl">
                    <img src="/images/alliance-default.png" alt="" loading="lazy" />
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
              <button phx-click="switch-mask" phx-value-id={mask.id}>
                <div class="avatar avatar-offline">
                  <div class="w-24 rounded-xl">
                    <img src="/images/alliance-default.png" alt="" loading="lazy" />
                  </div>
                </div>
                {mask.name} ({mask.kind})
              </button>
            </li>
            <li :if={@masks == []}>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-24 rounded-xl">
                    <img src="/images/alliance-default.png" alt="" loading="lazy" />
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

  defp tq_title(true, players) when is_integer(players),
    do: "Tranquility online — #{players} players"

  defp tq_title(true, _), do: "Tranquility online"
  defp tq_title(_, _), do: "Tranquility unreachable"

  defp format_players(players) when is_integer(players), do: "#{players} online"
  defp format_players(_), do: "Up"

  defp format_time(%DateTime{} = now) do
    now |> DateTime.shift_zone!("Etc/UTC") |> Calendar.strftime("%H:%M")
  rescue
    _ -> "00:00"
  end

  defp format_time(_), do: "00:00"

  defp online_class(true), do: "avatar-online"
  defp online_class(false), do: "avatar-offline"
  defp online_class(_), do: "avatar-offline"
end
