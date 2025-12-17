defmodule TripwireWeb.DashboardController do
  use TripwireWeb, :controller

  def dashboard(conn, %{"user" => user}) do
    users = TripwireWeb.DashboardHTML.users()
    render(conn, :dashboard, user: user, users: users)
  end

  # public
  def dashboard_admin_demo(conn, _params) do
    render(conn, :dashboard, user: "Admin", demo?: true)
  end

  def dashboard_user_demo(conn, _params) do
    render(conn, :dashboard, user: "User", demo?: true)
  end

end
