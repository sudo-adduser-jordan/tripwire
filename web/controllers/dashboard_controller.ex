defmodule TripwireWeb.DashboardController do
  use TripwireWeb, :controller

  def dashboard(conn, %{"user" => user}) do
    users = TripwireWeb.DashboardHTML.users()
    render(conn, :dashboard, user: user, users: users)
  end

end
