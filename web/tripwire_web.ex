defmodule TripwireWeb do
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt data.json)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: TripwireWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  # Edited
  defp html_helpers do
    quote do
      use Gettext, backend: TripwireWeb.Gettext

      import Phoenix.HTML
      import TripwireWeb.CoreComponents
      import TripwireWeb.FlashComponent
      import TripwireWeb.TableComponent
      import TripwireWeb.ListComponent
      import TripwireWeb.InputComponent
      import TripwireWeb.IconComponent

      import TripwireWeb.NavigationComponent

      import TripwireWeb.SystemComponent
      import TripwireWeb.SignaturesComponent
      import TripwireWeb.NotesComponent
      import TripwireWeb.MapComponent

      alias Phoenix.LiveView.JS
      alias TripwireWeb.RootLayout

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: TripwireWeb.Endpoint,
        router: TripwireWeb.Router,
        statics: TripwireWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
