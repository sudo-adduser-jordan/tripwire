defmodule TripwireWeb.AuthController do
  use TripwireWeb, :controller

  alias Tripwire.SSO

  plug :require_sso when action in [:request, :callback, :delete]
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
    Tripwire.Accounts.bump_stats(character.id, login_count: 1)

    character_ids =
      (get_session(conn, :character_ids) || []) ++ [character.eve_id] |> Enum.uniq()

    conn
    |> put_session(:character_ids, character_ids)
    |> put_session(:current_user, %{id: character.eve_id, name: character.name})
    |> redirect(to: "/Jita")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "EVE SSO login failed")
    |> redirect(to: "/")
  end

  def switch(conn, %{"eve_id" => eve_id}) do
    character_ids = List.wrap(get_session(conn, :character_ids))
    current = get_session(conn, :current_user)
    current_id = if is_map(current), do: current[:id] || current["id"], else: nil

    with {id, ""} <- Integer.parse(to_string(eve_id)),
         %{} = character <- Tripwire.Accounts.get_character_by_eve_id(id),
         true <-
           to_string(id) == to_string(current_id) or
             to_string(id) in Enum.map(character_ids, &to_string/1) or
             Tripwire.SSO.demo?() do
      conn
      |> put_session(:current_user, %{id: character.eve_id, name: character.name})
      |> redirect(to: "/dashboard")
    else
      _ ->
        conn
        |> put_flash(:error, "Character not found")
        |> redirect(to: "/dashboard")
    end
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
