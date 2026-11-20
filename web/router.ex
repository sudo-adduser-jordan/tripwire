defmodule TripwireWeb.Router do
  use TripwireWeb, :router

  defp load_current_user(conn, _opts) do
    case TripwireWeb.SessionUser.get(get_session(conn)) do
      %{id: eve_id} ->
        case Tripwire.Accounts.get_character_by_eve_id(eve_id) do
          nil -> assign(conn, :current_user, nil)
          character -> assign(conn, :current_user, %{id: character.eve_id, name: character.name})
        end

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

  scope "/api", TripwireWeb do
    pipe_through :api
    get "/signatures", ApiController, :signatures
    get "/wormholes", ApiController, :wormholes
    get "/comments", ApiController, :comments
    get "/statistics", ApiController, :statistics
  end

  scope "/", TripwireWeb do
    pipe_through :browser
    get "/", HomeController, :home
    live "/dashboard", DashboardLive
    live "/:system_name", DashboardLive
  end

  scope "/auth", TripwireWeb do
    pipe_through :browser
    get "/switch/:eve_id", AuthController, :switch
    get "/session/:eve_id", AuthController, :switch_session
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  if Application.compile_env(:tripwire, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: TripwireWeb.Telemetry,
        ecto_repos: [Tripwire.Repo]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
