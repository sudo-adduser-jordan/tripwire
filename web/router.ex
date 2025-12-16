defmodule TripwireWeb.Router do
  use TripwireWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TripwireWeb.RootLayout, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

#   pipeline :api do
#     plug :accepts, ["json"]
#   end

    scope "/", TripwireWeb do
        pipe_through :browser
        get "/", HomeController, :home
        get "/dashboard/:user", DashboardController, :dashboard
    end

  # scope "/auth", TripwireWeb do
  #    pipe_through :browser
  #     get "/:provider", AuthController, :request
  #     get "/:provider/callback", AuthController, :callback
  #     post "/:provider/callback", AuthController, :callback
  #     delete "/logout", AuthController, :delete
  # end

  # dev
  if Application.compile_env(:tripwire, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router
    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TripwireWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
