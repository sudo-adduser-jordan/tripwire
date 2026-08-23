defmodule TripwireWeb.Router do
  use TripwireWeb, :router

  defp authorized(conn, _opts) do
    if get_session(conn, :current_user) do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/")
      |> Plug.Conn.halt()
    end
  end

  defp load_current_user(conn, _opts) do
    case get_session(conn, :current_user) do
      %{id: eve_id} ->
        character = Tripwire.Accounts.get_character_by_eve_id(eve_id)

        assign(conn, :current_user, character && %{id: character.eve_id, name: character.name})

      _ ->
        assign(conn, :current_user, nil)
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TripwireWeb.RootLayout, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser_authorized do
    plug :browser
    plug :authorized
  end

  scope "/", TripwireWeb do
    pipe_through :browser
    get "/", HomeController, :home
  end

  if Application.compile_env(:tripwire, :dev_routes) do
    scope "/", TripwireWeb do
      pipe_through :browser
      get "/dashboard/Admin", DashboardController, :dashboard_admin_demo
      get "/dashboard/User", DashboardController, :dashboard_user_demo
    end
  end

  scope "/auth", TripwireWeb do
    pipe_through :browser
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  scope "/", TripwireWeb do
    pipe_through :browser_authorized
    live "/dashboard/:user", DashboardLive
  end

  if Application.compile_env(:tripwire, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: TripwireWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
