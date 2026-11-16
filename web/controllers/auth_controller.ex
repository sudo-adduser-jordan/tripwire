defmodule TripwireWeb.AuthController do
  use TripwireWeb, :controller

  alias Tripwire.SSO

  plug :require_sso
  plug Ueberauth

  defp require_sso(conn, _opts) do
    if SSO.demo?() do
      conn
      |> put_flash(:info, "EVE SSO is not configured, demo mode is active")
      |> redirect(to: ~p"/")
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

  def request(conn, _params), do: conn

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    {:ok, character} = Tripwire.Accounts.upsert_character_from_ueberauth(auth)
    {:ok, _pid} = Tripwire.Tracking.ensure_poller(character)

    character = maybe_grant_admin(character, auth)

    conn
    |> put_session(:current_user, %{id: character.eve_id, name: character.name})
    |> redirect(to: "/Jita")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "EVE SSO login failed")
    |> redirect(to: "/")
  end

  # Mirrors official Tripwire: registering as admin requires CEO, Director,
  # or Tripwire Admin corp roles. Non-blocking — ESI failures keep is_admin false.
  defp maybe_grant_admin(character, auth) do
    token = auth.credentials && auth.credentials.token

    with token when is_binary(token) and token != "" <- token,
         {:ok, true} <- Tripwire.Accounts.esi_admin?(auth.uid, token),
         {:ok, updated} <- Tripwire.Accounts.upsert_character(%{eve_id: character.eve_id, is_admin: true}) do
      updated
    else
      _ -> character
    end
  end
end
