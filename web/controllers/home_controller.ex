defmodule TripwireWeb.HomeController do
  use TripwireWeb, :controller

  alias Tripwire.Accounts
  alias Tripwire.SSO

  def home(conn, _params) do
    demo? = SSO.demo?()
    branding = if demo?, do: nil, else: Accounts.branding()
    render(conn, :home, demo?: demo?, branding: branding)
  end
end
