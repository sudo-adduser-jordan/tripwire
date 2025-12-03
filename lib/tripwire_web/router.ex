defmodule TripwireWeb.Router do
  use TripwireWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TripwireWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWeb.Plugs.Locale, "en"
  end

  scope "/", TripwireWeb do
    pipe_through :browser
    get "/", PageController, :home
    get "/login", LoginController, :index
    # get "/dashboard", LoginController, :index

    # get "/systems", LoginController, :index
    # get "/stations", LoginController, :index
    # get "/signatures", LoginController, :index

    # get "/users", LoginController, :index
    # get "/alliances", LoginController, :index
    # get "/corporations", LoginController, :index

    # resources "/users", UserController do
    #   resources "/posts", PostController
    # end
    # resources "/reviews", ReviewController
  end

  # scope "/admin", HelloWeb.Admin do
  #   pipe_through :browser
  #   resources "/users",   UserController
  #   resources "/images",   UserController
  #   resources "/reviews", ReviewController
  # end

  if Application.compile_env(:tripwire, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: TripwireWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
