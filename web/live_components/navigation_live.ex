defmodule TripwireWeb.LiveComponents.NavigationLive do
  use Phoenix.Component

  import TripwireWeb.IconComponent
  import TripwireWeb.CharacterVisibilityComponents
  import TripwireWeb.MaskAvatarComponents

  alias Phoenix.LiveView.JS
  alias Tripwire.Systems

  attr :character, :string, required: true
  attr :characters, :list, default: []
  attr :presences, :map, default: %{}
  attr :masks, :list, default: []
  attr :tq_online, :boolean, default: false
  attr :tq_players, :any, default: nil
  attr :selected_system_name, :any, default: nil
  attr :current_system_name, :any, default: nil
  attr :character_online, :any, default: nil
  attr :topbar_now, :any, default: nil
  attr :grid_locked, :boolean, default: true
  attr :system_search, :string, default: ""
  attr :system_suggestions, :list, default: []
  attr :current_user, :map, default: nil
  attr :settings_open, :boolean, default: false
  attr :branding, :map, default: nil
  attr :demo?, :boolean, default: false
  attr :sso_configured?, :boolean, default: false
  attr :mask, :any, default: nil

  def navigation_live(assigns) do
    ~H"""
    <nav
      id="topbar"
      phx-hook="CharacterSwitch"
      class="sticky top-0 z-30 flex w-full max-w-full flex-wrap items-center gap-x-2 gap-y-1 bg-base-200/75 p-2"
    >
      <a href="/" class="flex w-fit items-center gap-2">
        <img
          :if={is_nil(@branding)}
          class="hidden min-[400px]:block size-7"
          src="/images/logo.svg"
        />
        <img
          :if={@branding}
          class="hidden min-[400px]:block size-7 rounded"
          src={@branding.image_url}
          alt={@branding.name}
        />
        <span :if={@demo?} class="hidden sm:block text-xs font-semibold">zTripwire</span>
        <span class="hidden sm:block text-xs tabular-nums opacity-60">
          v{Application.spec(:tripwire, :vsn)}
        </span>
      </a>
      <div
        class="m-1 hover:cursor-pointer hover:underline place-content-center flex gap-1 justify-center items-center"
        title={tq_title(@tq_online, @tq_players)}
      >
        <div class={["badge m-1", if(@tq_online, do: "badge-success", else: "badge-error")]}>
          {if @tq_online, do: format_players(@tq_players), else: "Down"}
        </div>
      </div>
      <p class="tabular-nums text-xs" title="EVE time (UTC)">{format_time(@topbar_now)}</p>
      <div
        id="topbar-system"
        class="hover:cursor-pointer hover:underline place-content-center px-2 text-center text-xs"
        title={if @character_online == false, do: "Character offline"}
      >
        {@selected_system_name || @current_system_name || "Jita"}
      </div>
      <div class="hidden min-[400px]:flex items-center text-xs">&gt;</div>
      <div
        class="relative hidden min-[400px]:block"
        id="system-search-wrap"
        phx-hook="SearchSuggest"
      >
        <form
          id="system-search-form"
          phx-submit="system-search-submit"
          phx-change="system-search-change"
        >
          <input
            id="system-search"
            name="search"
            value={@system_search}
            class="mx-1 h-6 w-36 rounded bg-base-100 px-2 text-xs placeholder:text-xs in-data-[mode=light]:bg-base-200 sm:w-44"
            placeholder="Search systems"
            autocomplete="off"
            phx-debounce="200"
          />
        </form>
        <div
          :if={@system_suggestions != []}
          class="absolute left-1 top-full z-40 mt-1 max-h-64 w-44 overflow-y-auto rounded bg-base-200 p-1 text-xs shadow"
        >
          <button
            :for={sug <- @system_suggestions}
            phx-click={if Map.get(sug, :id), do: "select-system", else: "system-search-pick"}
            phx-value-id={Map.get(sug, :id)}
            phx-value-name={sug.name}
            title={"Select #{sug.name}"}
            data-suggest-item
            class="flex w-full items-center gap-2 rounded px-2 py-1 text-left hover:bg-base-300"
          >
            <span
              class="inline-block size-2.5 shrink-0 rounded-full"
              style={"background-color: #{Systems.color(sug)}"}
            >
            </span>
            <span class="truncate font-mono">{Map.get(sug, :alias) || sug.name}</span>
          </button>
        </div>
      </div>
      <div class="ml-auto flex flex-wrap items-center gap-2">
        <div class="dropdown dropdown-start">
          <div
            tabindex="0"
            role="button"
            class="rounded-field hover:cursor-pointer hover:underline text-xs"
          >
            {@character}
          </div>
          <ul
            tabindex="-1"
            class="menu dropdown-content bg-base-200/75 rounded-box z-1 mt-4 w-64 p-2 shadow-sm"
          >
            <li :for={character <- @characters}>
              <div class="flex items-center gap-1">
                <.character_ship_toggle
                  character={character}
                  ship_type_id={presence_ship_type_id(@presences, character)}
                  size="lg"
                />
                <.character_portrait_toggle
                  character={character}
                  current_character={current_character(@characters, @character)}
                  online={presence_online(@presences, character)}
                  size="lg"
                />
                <button
                  type="button"
                  phx-click="switch-character"
                  phx-value-id={character.id}
                  title={"Switch to #{character_name(character)}"}
                  class="min-w-0 flex-1 truncate py-1 text-left text-xs"
                >
                  {character_name(character)}
                </button>
              </div>
            </li>
            <li :if={@characters == []}>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-12 rounded-xl">
                    <img src="/images/alliance-default.png" alt="" loading="lazy" />
                  </div>
                </div>
                {@character}
              </a>
            </li>
            <li :if={@sso_configured?}>
              <a href="/auth/evesso" title="Add character via EVE SSO">
                <.icon name="hero-plus" class="size-4" /> Add character
              </a>
            </li>
            <li :if={!@sso_configured?}>
              <button
                phx-click="add-character"
                title="EVE SSO is not configured"
              >
                <.icon name="hero-plus" class="size-4" /> Add character
              </button>
            </li>
          </ul>
        </div>
        <p class="text-xs">&gt;</p>
        <div class="dropdown dropdown-end">
          <div
            id="topbar-mask"
            tabindex="0"
            role="button"
            title="Switch mask"
            class="rounded-field hover:cursor-pointer hover:underline text-xs"
          >
            {mask_name(@mask)}
          </div>
          <ul
            tabindex="-1"
            class="menu dropdown-content bg-base-200/75 rounded-box z-1 mt-4 w-52 p-2 shadow-sm"
          >
            <li :for={mask <- @masks}>
              <button phx-click="switch-mask" phx-value-id={mask.id}>
                <.mask_avatar mask={mask} dot={current_dot(mask, @mask)} size="lg" />
                {mask.name} ({mask.kind})
              </button>
            </li>
            <li :if={@masks == []}>
              <a>
                <div class="avatar avatar-online">
                  <div class="w-12 rounded-xl">
                    <img src="/images/alliance-default.png" alt="" loading="lazy" />
                  </div>
                </div>
                Demo
              </a>
            </li>
            <li>
              <button
                phx-click="open-settings"
                phx-value-tab="account"
                title="Manage masks"
              >
                <.icon name="hero-cog-6-tooth" class="size-4" /> Manage masks
              </button>
            </li>
          </ul>
        </div>
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
            fill={if @grid_locked, do: "#ff6700", else: "#605dff"}
          >
            <path d="M21 2h-5v20h5c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1M2 21c0 .6.4 1 1 1h11v-9H2zM2 3v8h12V2H3c-.6 0-1 .4-1 1" />
          </svg>
        </button>
        <.mode_toggle />
        <button
          class="btn btn-primary btn-sm mr-2 h-8 min-h-8"
          id="settings-button"
          phx-click="toggle-settings"
          autofocus
        >
          Settings
          <span aria-hidden="true" id="settings-button-span">
            {if @settings_open, do: "←", else: "→"}
          </span>
        </button>
      </div>
    </nav>
    """
  end

  def mode_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-md">
      <div class="absolute w-1/3 h-full rounded border border-base-200 bg-base-100 brightness-200 left-0 in-data-[mode=light]:left-1/3 in-data-[mode=dark]:left-2/3 transition-[left]" />

      <button
        class="flex p-1.5 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-mode")}
        data-phx-mode="system"
        title="Follow the system light or dark mode"
      >
        <.icon name="hero-computer-desktop-micro" class="size-3 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-1.5 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-mode")}
        data-phx-mode="light"
        title="Light mode"
      >
        <.icon name="hero-sun-micro" class="size-3 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-1.5 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-mode")}
        data-phx-mode="dark"
        title="Dark mode"
      >
        <.icon name="hero-moon-micro" class="size-3 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  defp character_name(%{name: name}), do: name
  defp character_name(name) when is_binary(name), do: name

  defp mask_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp mask_name(_), do: "Mask"

  defp tq_title(true, players) when is_integer(players),
    do: "Tranquility online — #{players} players"

  defp tq_title(true, _), do: "Tranquility online"
  defp tq_title(_, _), do: "Tranquility unreachable"

  defp format_players(players) when is_integer(players), do: "#{players}"
  defp format_players(_), do: "Up"

  defp format_time(%DateTime{} = now) do
    now |> DateTime.shift_zone!("Etc/UTC") |> Calendar.strftime("%H:%M")
  rescue
    _ -> "00:00"
  end

  defp format_time(_), do: "00:00"

  defp current_dot(%{id: id}, %{id: other_id}) when id == other_id, do: "avatar-online"

  defp current_dot(%{name: name}, current) when is_binary(name) and is_binary(current) do
    if name == current, do: "avatar-online", else: "avatar-offline"
  end

  defp current_dot(name, current) when is_binary(name) and is_binary(current) do
    if name == current, do: "avatar-online", else: "avatar-offline"
  end

  defp current_dot(_, _), do: "avatar-offline"

  defp current_character(characters, name) when is_binary(name) do
    Enum.find(characters, &(&1.name == name))
  end

  defp current_character(_, _), do: nil

  defp presence(%{eve_id: eve_id}, presences), do: Map.get(presences || %{}, eve_id, %{})

  defp presence_ship_type_id(presences, character),
    do: Map.get(presence(character, presences), :ship_type_id)

  defp presence_online(presences, character), do: Map.get(presence(character, presences), :online)
end
