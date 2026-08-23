defmodule TripwireWeb.DashboardController do
  use TripwireWeb, :controller

  def dashboard_admin_demo(conn, _params) do
    render(conn, :dashboard, user: "Admin")
  end

  def dashboard_user_demo(conn, _params) do
    render(conn, :dashboard, user: "User")
  end
end
