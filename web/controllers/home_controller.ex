defmodule TripwireWeb.HomeController do
  use TripwireWeb, :controller

  alias Tripwire.SSO

  def home(conn, _params) do
    if SSO.demo?() do
      redirect(conn, to: ~p"/dashboard/User")
    else
      render(conn, :home)
    end
  end
end
