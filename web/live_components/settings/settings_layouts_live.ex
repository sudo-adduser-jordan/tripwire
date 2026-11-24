defmodule TripwireWeb.LiveComponents.Settings.LayoutsLive do
  use Phoenix.Component

  attr :settings_tab, :string, default: "account"
  attr :layouts, :list, default: []
  attr :active_layout, :string, default: nil
  attr :layout_errors, :list, default: []

  def settings_layouts_live(assigns) do
    assigns =
      assign(assigns,
        core: Enum.filter(assigns.layouts, & &1.core?),
        saved: Enum.reject(assigns.layouts, & &1.core?)
      )

    ~H"""
    <input
      type="radio"
      name="my_tabs_6"
      class="tab"
      aria-label="Layouts"
      checked={@settings_tab == "layouts"}
      phx-click="settings-tab"
      phx-value-tab="layouts"
    />
    <div class="tab-content w-full max-w-full overflow-hidden p-3 sm:p-4">
      <div class="flex min-h-0 w-full max-w-full flex-col gap-3 overflow-hidden">
        <p class="text-sm font-semibold">Layouts</p>

        <div class="flex min-w-0 flex-wrap items-center gap-2">
          <form id="save-layout-form" phx-submit="save-layout" class="flex min-w-0 flex-wrap gap-2">
            <input
              id="layout-name"
              name="name"
              value=""
              placeholder="Layout name"
              autocomplete="off"
              maxlength="40"
              class="input input-bordered input-sm min-w-0 flex-1 sm:max-w-64"
            />
            <button id="save-layout" type="submit" class="btn btn-primary btn-sm">
              Save current layout
            </button>
          </form>
          <button
            id="reset-layout"
            type="button"
            class="btn btn-sm"
            phx-click="reset-layout"
            title="Restore the Default positions, sizes and visibility"
          >
            Reset layout
          </button>
        </div>
        <p class="text-xs opacity-60">
          Widget positions and sizes are remembered for this account. Reset restores Default.
        </p>
        <p :if={@layout_errors != []} id="layout-errors" class="alert alert-error py-2 text-sm">
          {Enum.join(@layout_errors, ", ")}
        </p>

        <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
          <p class="settings-section-label">Core Layouts</p>
          <div
            :for={layout <- @core}
            id={"layout-" <> dom_id(layout.id)}
            class="settings-card flex min-w-0 flex-wrap items-center gap-2 border border-base-300"
          >
            <div class="min-w-0 flex-1">
              <p class="text-sm font-medium">{layout.name}</p>
              <p class="text-xs opacity-60">{layout.description}</p>
            </div>
            <span :if={@active_layout == layout.id} class="badge badge-primary badge-sm">Active</span>
            <button
              id={"apply-layout-" <> dom_id(layout.id)}
              type="button"
              class="btn btn-sm"
              phx-click="apply-layout"
              phx-value-id={layout.id}
            >
              Apply
            </button>
          </div>
        </div>

        <div class="flex min-h-0 w-full max-w-full flex-col gap-2 overflow-hidden">
          <p class="settings-section-label">Saved Layouts</p>
          <p :if={@saved == []} id="no-saved-layouts" class="settings-empty">
            No saved layouts yet. Arrange the widgets, unlock the grid and save the result here.
          </p>
          <div
            :for={layout <- @saved}
            id={"layout-" <> dom_id(layout.id)}
            class="settings-card flex min-w-0 flex-wrap items-center gap-2 border border-base-300"
          >
            <div class="min-w-0 flex-1">
              <p class="text-sm font-medium">{layout.name}</p>
            </div>
            <span :if={@active_layout == layout.id} class="badge badge-primary badge-sm">Active</span>
            <button
              id={"apply-layout-" <> dom_id(layout.id)}
              type="button"
              class="btn btn-sm"
              phx-click="apply-layout"
              phx-value-id={layout.id}
            >
              Apply
            </button>
            <button
              id={"remove-layout-" <> dom_id(layout.id)}
              type="button"
              class="btn btn-error btn-sm"
              phx-click="delete-layout"
              phx-value-id={layout.id}
              data-confirm={"Remove #{layout.name}?"}
            >
              Remove
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp dom_id(id), do: String.replace(id, ":", "-")
end
