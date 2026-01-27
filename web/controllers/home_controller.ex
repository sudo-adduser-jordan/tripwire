defmodule TripwireWeb.HomeController do
  use TripwireWeb, :controller

  def home(conn, _params) do
    render(conn, :home, current_user: get_session(conn, :current_user))
  end
end
