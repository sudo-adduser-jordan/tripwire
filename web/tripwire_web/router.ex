defmodule TripwireWeb.Router do
  use TripwireWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TripwireWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TripwireWeb do
    pipe_through :browser

    get "/", HomeController, :home
    get "/:user/dashboard/", DashboardController, :dashboard
    get "/:user/settings/", SettingsController, :settings
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
