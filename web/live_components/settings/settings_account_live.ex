defmodule TripwireWeb.LiveComponents.Settings.AccountLive do
  use Phoenix.Component

  import TripwireWeb.CharacterVisibilityComponents
  import TripwireWeb.MaskAvatarComponents

  attr :settings_tab, :string, default: "account"
  attr :characters, :list, default: []
  attr :masks, :list, default: []
  attr :character, :any, default: nil
  attr :mask, :any, default: nil
  attr :sso_configured?, :boolean, default: false
  attr :presences, :map, default: %{}

  def settings_account_live(assigns) do
    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Account"
      checked={@settings_tab == "account"}
      phx-click="settings-tab"
      phx-value-tab="account"
    />
    <div class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-3 overflow-hidden">
        <div class="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-0.5">
          <p class="text-sm font-semibold">Account</p>
          <p :if={@character && @character.last_login_at} class="truncate text-xs opacity-60">
            Last login: {@character.last_login_at}
          </p>
        </div>

        <div class="flex items-center justify-between gap-2">
          <p class="text-xs font-medium opacity-70">Characters</p>
          <div class="flex items-center gap-2">
            <span class="badge badge-ghost badge-xs tabular-nums">{length(@characters)}</span>
            <a
              :if={@sso_configured?}
              href="/auth/evesso"
              title="Add character via EVE SSO"
              class="btn btn-ghost btn-xs"
            >
              Add
            </a>
            <button
              :if={!@sso_configured?}
              type="button"
              class="btn btn-ghost btn-xs"
              title="EVE SSO is not configured"
              phx-click="add-character"
            >
              Add
            </button>
          </div>
        </div>
        <div
          id="character-cards"
          phx-hook="CardGrid"
          data-card-grid
          class="grid w-full max-w-full grid-cols-2 gap-2 md:grid-cols-3 2xl:grid-cols-4"
        >
          <div
            :for={entry <- @characters}
            id={"character-card-#{entry.id}"}
            role="button"
            tabindex={if current_character?(@character, entry), do: "0", else: "-1"}
            aria-label={"Switch to #{entry.name}"}
            aria-current={current_character?(@character, entry) && "true"}
            data-card
            class={[
              "relative flex min-w-0 items-center gap-2 rounded-lg border bg-base-100/50 p-2 transition-colors hover:bg-base-200/60 focus-visible:ring-2 focus-visible:ring-success focus-visible:outline-none",
              current_character?(@character, entry) &&
                "border-success bg-success/10 ring-1 ring-success",
              !current_character?(@character, entry) && "border-base-300"
            ]}
          >
            <button
              type="button"
              phx-click="switch-character"
              phx-value-id={entry.id}
              tabindex="-1"
              data-card-action
              title={"Switch to #{entry.name}"}
              aria-label={"Switch to #{entry.name}"}
              class="absolute inset-0 z-0 rounded-lg hover:cursor-pointer"
            >
            </button>
            <div class="pointer-events-none relative z-10 flex min-w-0 flex-1 items-center gap-2">
              <.character_ship_toggle
                character={entry}
                ship_type_id={presence_field(@presences, entry, :ship_type_id)}
              />
              <.character_portrait_toggle
                character={entry}
                current_character={@character}
                online={presence_field(@presences, entry, :online)}
              />
              <div class="min-w-0 flex-1">
                <div class="truncate text-xs font-semibold">{entry.name}</div>
                <div class="truncate text-[11px] opacity-70">{corporation(entry)}</div>
                <div class="truncate text-[11px] opacity-70">
                  {presence_line(@presences, entry)}
                </div>
                <div class="mt-0.5 flex min-w-0 flex-row flex-wrap gap-1">
                  <div :if={entry.alliance_name} class="badge badge-info badge-xs truncate max-w-full">
                    {entry.alliance_name}
                  </div>
                  <div
                    :if={presence_field(@presences, entry, :online) == false}
                    class="badge badge-ghost badge-xs"
                  >
                    Offline
                  </div>
                </div>
              </div>
              <button
                type="button"
                class="btn btn-ghost btn-xs pointer-events-auto shrink-0 p-1"
                title={"Remove #{entry.name}"}
                data-confirm={"Remove #{entry.name}?"}
                phx-click="remove-character"
                phx-value-id={entry.id}
              >
                Remove
              </button>
            </div>
          </div>
          <div
            :if={@characters == []}
            class="col-span-full rounded-box bg-base-200/50 p-3 text-xs opacity-60"
          >
            No characters yet. Log in with EVE SSO to add one.
          </div>
        </div>

        <div class="flex items-center justify-between gap-2">
          <p class="text-xs font-medium opacity-70">Masks</p>
          <div class="flex items-center gap-2">
            <span class="badge badge-ghost badge-xs tabular-nums">{length(@masks)}</span>
            <button
              :if={admin?(@character)}
              type="button"
              class="btn btn-ghost btn-xs"
              title="Create corporate mask"
              phx-click="create-corp-mask"
            >
              Add
            </button>
          </div>
        </div>
        <div
          id="mask-cards"
          phx-hook="CardGrid"
          data-card-grid
          class="grid w-full max-w-full grid-cols-2 gap-2 md:grid-cols-3 2xl:grid-cols-4"
        >
          <div
            :for={entry <- @masks}
            id={"mask-card-#{entry.id}"}
            role="button"
            tabindex={if current_mask?(@mask, entry), do: "0", else: "-1"}
            aria-label={"Switch to #{entry.name}"}
            aria-current={current_mask?(@mask, entry) && "true"}
            data-card
            class={[
              "relative flex min-w-0 items-center gap-2 rounded-lg border bg-base-100/50 p-2 transition-colors hover:bg-base-200/60 focus-visible:ring-2 focus-visible:ring-success focus-visible:outline-none",
              current_mask?(@mask, entry) && "border-success bg-success/10 ring-1 ring-success",
              !current_mask?(@mask, entry) && "border-base-300"
            ]}
          >
            <button
              type="button"
              phx-click="switch-mask"
              phx-value-id={entry.id}
              tabindex="-1"
              data-card-action
              title={"Switch to #{entry.name}"}
              aria-label={"Switch to #{entry.name}"}
              class="absolute inset-0 z-0 rounded-lg hover:cursor-pointer"
            >
            </button>
            <div class="pointer-events-none relative z-10 flex min-w-0 flex-1 items-center gap-2">
              <.mask_avatar
                mask={entry}
                dot={(current_mask?(@mask, entry) && "avatar-online") || "avatar-offline"}
              />
              <div class="min-w-0 flex-1">
                <div class="truncate text-xs font-semibold">{entry.name}</div>
                <div class="truncate text-[11px] opacity-70 capitalize">{entry.kind || "custom"}</div>
                <div class="mt-0.5 flex min-w-0 flex-row flex-wrap gap-1">
                  <div class={["badge badge-xs", mask_badge(entry.kind)]}>
                    {entry.kind || "custom"}
                  </div>
                </div>
              </div>
              <button
                :if={admin?(@character)}
                type="button"
                class="btn btn-ghost btn-xs pointer-events-auto shrink-0 p-1"
                title={"Remove #{entry.name}"}
                data-confirm={"Delete #{entry.name} and all of its maps?"}
                phx-click="delete-mask"
                phx-value-id={entry.id}
              >
                Remove
              </button>
            </div>
          </div>
          <div
            :if={@masks == []}
            class="col-span-full rounded-box bg-base-200/50 p-3 text-xs opacity-60"
          >
            No masks yet. Masks are shared across characters.
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp current_character?(%{id: id}, %{id: other_id}), do: id == other_id
  defp current_character?(_, _), do: false

  defp admin?(%{is_admin: true}), do: true
  defp admin?(_), do: false

  defp current_mask?(%{id: id}, %{id: other_id}), do: id == other_id
  defp current_mask?(_, _), do: false

  defp presence(%{eve_id: eve_id}, presences), do: Map.get(presences || %{}, eve_id, %{})

  defp presence_field(presences, character, key),
    do: Map.get(presence(character, presences), key)

  defp presence_line(presences, character) do
    ship = ship_label(presences, character)
    system = present(presence_field(presences, character, :system_name))

    case {ship, system} do
      {nil, nil} -> "Location unknown"
      {nil, system} -> system
      {ship, nil} -> ship
      {ship, system} -> "#{ship} · #{system}"
    end
  end

  defp ship_label(presences, character) do
    present(presence_field(presences, character, :ship_type_name)) ||
      custom_ship_name(presence_field(presences, character, :ship_name))
  end

  defp custom_ship_name(name) do
    case present(name) do
      "/" -> nil
      other -> other
    end
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil

  defp corporation(%{corporation_name: name}) when is_binary(name) and name != "",
    do: name

  defp corporation(%{corporation_id: id}) when is_integer(id),
    do: "Corp #{id}"

  defp corporation(_), do: "Unknown corporation"

  defp mask_badge("personal"), do: "badge-info"
  defp mask_badge("demo"), do: "badge-warning"
  defp mask_badge("corporation"), do: "badge-success"
  defp mask_badge("alliance"), do: "badge-accent"
  defp mask_badge(_), do: "badge-neutral"
end
