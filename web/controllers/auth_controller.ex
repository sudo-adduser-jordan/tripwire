defmodule TripwireWeb.AuthController do
  use TripwireWeb, :controller

  alias Tripwire.SSO

  plug :require_sso
  plug Ueberauth

  defp require_sso(conn, _opts) do
    if SSO.demo?() do
      conn
      |> put_flash(:info, "EVE SSO is not configured, demo mode is active")
      |> redirect(to: ~p"/dashboard/User")
      |> halt()
    else
      conn
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> clear_session()
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    {:ok, character} = Tripwire.Accounts.upsert_character_from_ueberauth(auth)
    {:ok, _pid} = Tripwire.Tracking.ensure_poller(character)

    conn
    |> put_session(:current_user, %{id: character.eve_id, name: character.name})
    |> redirect(to: ~p"/dashboard/#{character.name}")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "EVE SSO login failed")
    |> redirect(to: "/")
  end
end
