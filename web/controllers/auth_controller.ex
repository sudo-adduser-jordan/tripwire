defmodule TripwireWeb.AuthController do
  use TripwireWeb, :controller

  alias Tripwire.SSO
  alias TripwireWeb.SessionUser

  @detail_limit 120

  plug :require_sso when action in [:request, :callback, :delete]
  plug :restore_state_param when action in [:callback]
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

  defp restore_state_param(conn, _opts) do
    case SSO.state_param(conn) do
      nil -> conn
      state -> put_private(conn, :ueberauth_state_param, state)
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

    conn
    |> SessionUser.put(character)
    |> redirect(to: "/Jita")
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    details = failure_message(failure)

    Tripwire.Log.emit(:warning, %{
      event: "sso_login_failed",
      provider: failure.provider,
      strategy: failure.strategy,
      message_keys: Enum.map(failure.errors, & &1.message_key),
      messages: Enum.map(failure.errors, &log_message(&1.message)),
      has_code: is_binary(conn.params["code"]),
      params: conn.params |> Map.keys() |> Enum.sort(),
      state_cookie: Map.has_key?(conn.req_cookies, "ueberauth.state_param"),
      sso_error: conn.params["error"],
      sso_error_description: conn.params["error_description"]
    })

    conn
    |> put_flash(:error, "EVE SSO login failed: #{details}")
    |> redirect(to: "/")
  end

  def switch(conn, %{"eve_id" => eve_id}) do
    case put_character_session(conn, eve_id) do
      {:ok, conn} ->
        redirect(conn, to: "/dashboard")

      {:error, conn} ->
        conn
        |> put_flash(:error, "Character not found")
        |> redirect(to: "/dashboard")
    end
  end

  def switch_session(conn, %{"eve_id" => eve_id}) do
    case put_character_session(conn, eve_id) do
      {:ok, conn} -> send_resp(conn, :no_content, "")
      {:error, conn} -> send_resp(conn, :not_found, "")
    end
  end

  defp put_character_session(conn, eve_id) do
    character_ids = SessionUser.ids(get_session(conn))
    current = SessionUser.get(get_session(conn))
    current_id = current && current.id

    with {id, ""} <- Integer.parse(to_string(eve_id)),
         %{} = character <- Tripwire.Accounts.get_character_by_eve_id(id),
         true <-
           to_string(id) == to_string(current_id) or
             to_string(id) in Enum.map(character_ids, &to_string/1) or
             Tripwire.SSO.demo?() do
      {:ok, SessionUser.put(conn, character)}
    else
      _ -> {:error, conn}
    end
  end

  defp failure_message(%{errors: errors} = failure) do
    if Enum.any?(errors, &(&1.message_key in ["csrf_attack", "invalid_state"])) do
      "login session expired, sign in again"
    else
      failure_details(failure)
    end
  end

  defp failure_details(%{errors: errors}) do
    case errors |> Enum.map(& &1.message) |> Enum.reject(&is_nil/1) do
      [] -> "unknown error"
      messages -> messages |> Enum.map(&first_line/1) |> Enum.join(", ") |> shorten()
    end
  end

  defp log_message(nil), do: nil
  defp log_message(message), do: message |> first_line() |> shorten()

  defp first_line(message), do: message |> String.split("\n", parts: 2) |> hd() |> String.trim()

  defp shorten(message) do
    if String.length(message) > @detail_limit do
      String.slice(message, 0, @detail_limit) <> "..."
    else
      message
    end
  end

  defp maybe_grant_admin(character, auth) do
    token = auth.credentials && auth.credentials.token

    with token when is_binary(token) and token != "" <- token,
         {:ok, true} <- Tripwire.Accounts.esi_admin?(auth.uid, token),
         {:ok, updated} <-
           Tripwire.Accounts.upsert_character(%{eve_id: character.eve_id, is_admin: true}) do
      updated
    else
      _ -> character
    end
  end
end
