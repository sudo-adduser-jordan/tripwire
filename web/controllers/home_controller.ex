defmodule TripwireWeb.HomeController do
  use TripwireWeb, :controller

  alias Tripwire.SSO

  def home(conn, _params) do
    render(conn, :home, demo?: SSO.demo?())
  end
end
