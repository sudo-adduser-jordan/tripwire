defmodule TripwireWeb.DashboardController do
  use TripwireWeb, :controller

  def dashboard(conn, %{"user" => user}) do
    render(conn, :dashboard, user: user)
  end

  def dashboard_admin_demo(conn, _params) do
    render(conn, :dashboard, user: "Admin", demo?: true)
  end

  def dashboard_user_demo(conn, _params) do
    render(conn, :dashboard, user: "User", demo?: true)
  end
end
