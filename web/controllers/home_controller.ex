defmodule TripwireWeb.HomeController do
  use TripwireWeb, :controller

  alias Tripwire.Accounts
  alias Tripwire.SSO

  def home(%{assigns: %{current_user: %{}}} = conn, _params) do
    redirect(conn, to: "/dashboard")
  end

  def home(conn, _params) do
    demo? = SSO.demo?()
    branding = if demo?, do: nil, else: Accounts.branding()

    conn
    |> assign(:theme_lock, true)
    |> render(:home, demo?: demo?, branding: branding)
  end
end
