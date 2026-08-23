defmodule TripwireWeb.AuthController do
  use TripwireWeb, :controller

  plug Ueberauth

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
