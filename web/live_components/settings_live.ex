defmodule TripwireWeb.LiveComponents.SettingsLive do
  use Phoenix.Component

  alias TripwireWeb.LiveComponents.Settings.AccountLive
  alias TripwireWeb.LiveComponents.Settings.AdminLive
  alias TripwireWeb.LiveComponents.Settings.LayoutsLive
  alias TripwireWeb.LiveComponents.Settings.MapLive
  alias TripwireWeb.LiveComponents.Settings.StatisticsLive
  alias TripwireWeb.LiveComponents.Settings.ThemesLive
  alias TripwireWeb.LiveComponents.Settings.WidgetsLive

  attr :map_layout, :string, default: "top"
  attr :show_row_guides, :boolean, default: false
  attr :show_row_counts, :boolean, default: false
  attr :angled_lines, :boolean, default: true
  attr :show_jump_lines, :boolean, default: true
  attr :show_line_glow, :boolean, default: true
  attr :show_node_badges, :boolean, default: true
  attr :line_weight, :integer, default: 2
  attr :node_spacing, :integer, default: 100
  attr :map_scale, :integer, default: 100
  attr :map_background, :string, default: nil
  attr :settings_tab, :string, default: "account"
  attr :widget_system, :boolean, default: true
  attr :widget_notes, :boolean, default: true
  attr :widget_signatures, :boolean, default: true
  attr :widget_map, :boolean, default: true
  attr :layouts, :list, default: []
  attr :active_layout, :string, default: nil
  attr :layout_errors, :list, default: []
  attr :characters, :list, default: []
  attr :masks, :list, default: []
  attr :admin_masks, :list, default: []
  attr :character, :any, default: nil
  attr :mask, :any, default: nil
  attr :sso_configured?, :boolean, default: false
  attr :presences, :map, default: %{}
  attr :current_user, :map, default: nil

  def settings_live(assigns) do
    ~H"""
    <div
      id="settings-widget"
      class="grid-stack-item scroll-mt-24"
      gs-w="11"
      gs-h="10"
      gs-x="0"
      gs-y="0"
      tabindex="0"
      phx-hook="GridWidget"
      phx-window-keydown="toggle-settings"
      phx-key="Escape"
    >
      <div
        id="settings-content"
        class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden"
        phx-hook="ScrollIntoView"
      >
        <div class="tabs tabs-box max-w-full min-h-0 size-full">
          <AccountLive.settings_account_live
            settings_tab={@settings_tab}
            characters={@characters}
            masks={@masks}
            character={@character}
            mask={@mask}
            sso_configured?={@sso_configured?}
            presences={@presences}
            current_user={@current_user}
          />
          <MapLive.settings_map_live
            map_layout={@map_layout}
            settings_tab={@settings_tab}
            show_row_guides={@show_row_guides}
            show_row_counts={@show_row_counts}
            angled_lines={@angled_lines}
            show_jump_lines={@show_jump_lines}
            show_line_glow={@show_line_glow}
            show_node_badges={@show_node_badges}
            line_weight={@line_weight}
            node_spacing={@node_spacing}
            map_scale={@map_scale}
            map_background={@map_background}
          />
          <WidgetsLive.settings_widgets_live
            settings_tab={@settings_tab}
            widget_system={@widget_system}
            widget_notes={@widget_notes}
            widget_signatures={@widget_signatures}
            widget_map={@widget_map}
          />
          <LayoutsLive.settings_layouts_live
            settings_tab={@settings_tab}
            layouts={@layouts}
            active_layout={@active_layout}
            layout_errors={@layout_errors}
          />
          <StatisticsLive.settings_statistics_live
            settings_tab={@settings_tab}
            character={@character}
          />
          <ThemesLive.settings_themes_live settings_tab={@settings_tab} />
          <AdminLive.settings_admin_live
            settings_tab={@settings_tab}
            character={@character}
            masks={@admin_masks}
          />
        </div>
      </div>
    </div>
    """
  end
end
