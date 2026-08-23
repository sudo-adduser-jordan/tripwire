defmodule TripwireWeb.NotesComponent do
  use Phoenix.Component
  import TripwireWeb.IconComponent

  def notes(assigns) do
    ~H"""
    <div id="notes" class="grid-stack-item" gs-w="6" gs-h="6" gs-x="6" gs-y="0" tabindex="0">
      <div class="grid-stack-item-content bg-base-100/50">
        <ul class="list rounded-box shadow-md">
          <li class="list-row h-fit p-1">
            <div tabindex="0">
              <.icon name="hero-document-plus" class="m-1 size-6" />
            </div>
            <div tabindex="0">
              <.icon name="hero-pencil-square" class="m-1 size-6" />
            </div>
            <div tabindex="0">
              <.icon name="hero-trash" class="m-1 size-6" />
            </div>
          </li>
        </ul>

        <div class="w-full p-4 overflow-auto text-sm leading-6">
          <h3 class="font-bold text-base">Welcome to zTripwire</h3>
          <p class="opacity-70 mt-1">
            The modern wormhole mapping tool. Here is how to get started:
          </p>

          <ol class="list-decimal list-inside mt-3 space-y-1.5 opacity-90">
            <li>
              <span class="font-semibold">Log in with EVE SSO</span> to create your personal map.
            </li>
            <li>
              <span class="font-semibold">Paste probe results</span> into the Signatures widget,
              then select a system to file them under.
            </li>
            <li>
              Manage signatures with delete and <span class="font-semibold">undo / redo</span>.
            </li>
            <li>
              <span class="font-semibold">Drag systems</span> on the map to arrange your chain;
              tracked character jumps add systems and links automatically.
            </li>
            <li>
              Open <span class="font-semibold">Settings</span> to pick a theme and tune widgets.
            </li>
          </ol>

          <p class="opacity-60 mt-3">
            Tip: the lock icon in the top bar freezes or unfreezes the dashboard layout.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
