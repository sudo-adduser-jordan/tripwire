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
        <div class="grid w-full max-w-full grid-cols-2 gap-2 md:grid-cols-3 2xl:grid-cols-5">
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <div class="text-2xl font-bold tabular-nums">{@stats.signatures_created}</div>
            <div class="text-xs opacity-70">Signatures added</div>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <div class="text-2xl font-bold tabular-nums">{@stats.signatures_updated}</div>
            <div class="text-xs opacity-70">Signatures touched</div>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <div class="text-2xl font-bold tabular-nums">{@stats.notes}</div>
            <div class="text-xs opacity-70">Notes written</div>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <div class="text-2xl font-bold tabular-nums">{@stats.flares}</div>
            <div class="text-xs opacity-70">Flares set</div>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100/50 p-3">
            <div class="text-2xl font-bold tabular-nums">{@stats.jumps}</div>
            <div class="text-xs opacity-70">Jumps logged</div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
