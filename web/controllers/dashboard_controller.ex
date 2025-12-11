defmodule TripwireWeb.DashboardController do
  use TripwireWeb, :controller

  def dashboard(conn, %{"user" => user}) do
    render(conn, :dashboard, user: user)
  end
end
