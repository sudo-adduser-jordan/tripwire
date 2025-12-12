defmodule TripwireWeb.DashboardController do
  use TripwireWeb, :controller

  def dashboard(conn, %{"user" => user}) do
    users = TripwireWeb.DashboardHTML.users()
    post = TripwireWeb.DashboardHTML.post()
    render(conn, :dashboard, user: user, users: users, post: post)
  end

end
