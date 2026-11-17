defmodule TripwireWeb.LiveComponents.Settings.StatisticsLive do
  use Phoenix.Component

  alias Tripwire.Mapping

  attr :settings_tab, :string, default: "account"
  attr :character, :any, default: nil

  def settings_statistics_live(assigns) do
    assigns = assign(assigns, :stats, Mapping.character_statistics(assigns.character))

    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Statistics"
      checked={@settings_tab == "statistics"}
      phx-click="settings-tab"
      phx-value-tab="statistics"
    />
    <div class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-3 overflow-hidden">
        <p class="text-sm font-semibold">Personal Statistics</p>
        <p :if={@character} class="truncate text-xs opacity-60">
          {@character.name}
        </p>
        <p :if={is_nil(@character)} class="text-xs opacity-60">
          Log in with EVE SSO to track personal statistics.
        </p>
        <div class="grid w-full max-w-full grid-cols-1 gap-2 md:grid-cols-3">
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <p class="text-xs font-semibold">Signatures</p>
            <dl class="mt-1 space-y-0.5 text-xs tabular-nums">
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Added</dt>
                <dd>{format_count(@stats.signatures_added)}</dd>
              </div>
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Updated</dt>
                <dd>{format_count(@stats.signatures_updated)}</dd>
              </div>
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Deleted</dt>
                <dd>{format_count(@stats.signatures_deleted)}</dd>
              </div>
            </dl>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <p class="text-xs font-semibold">Wormholes</p>
            <dl class="mt-1 space-y-0.5 text-xs tabular-nums">
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Added</dt>
                <dd>{format_count(@stats.wormholes_added)}</dd>
              </div>
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Updated</dt>
                <dd>{format_count(@stats.wormholes_updated)}</dd>
              </div>
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Deleted</dt>
                <dd>{format_count(@stats.wormholes_deleted)}</dd>
              </div>
            </dl>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <p class="text-xs font-semibold">Comments</p>
            <dl class="mt-1 space-y-0.5 text-xs tabular-nums">
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Added</dt>
                <dd>{format_count(@stats.comments_added)}</dd>
              </div>
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Updated</dt>
                <dd>{format_count(@stats.comments_updated)}</dd>
              </div>
              <div class="flex justify-between gap-2">
                <dt class="opacity-70">Deleted</dt>
                <dd>{format_count(@stats.comments_deleted)}</dd>
              </div>
            </dl>
          </div>
        </div>
        <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
          <p class="text-xs font-semibold">Activity</p>
          <dl class="mt-1 space-y-0.5 text-xs tabular-nums">
            <div class="flex justify-between gap-2">
              <dt class="opacity-70">Systems visited</dt>
              <dd>{format_count(@stats.systems_visited)}</dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="opacity-70">Logins</dt>
              <dd>{format_count(@stats.logins)}</dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="opacity-70">Last login</dt>
              <dd>{format_login(@stats.last_login)}</dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  defp format_count(n) when is_integer(n) and n >= 0 do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map_join(",", &Enum.join/1)
  end

  defp format_count(_), do: "0"

  defp format_login(%DateTime{} = login) do
    Calendar.strftime(login, "%Y-%m-%d %H:%M:%S")
  end

  defp format_login(%NaiveDateTime{} = login) do
    Calendar.strftime(login, "%Y-%m-%d %H:%M:%S")
  end

  defp format_login(_), do: "—"
end
