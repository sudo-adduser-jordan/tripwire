defmodule ZtripwireWeb.AuthController do
  use ZtripwireWeb, :controller

  alias Ztripwire.SSO
  alias ZtripwireWeb.SessionUser

  @detail_limit 120

  plug :require_sso when action in [:request, :callback, :delete]
  plug :restore_state_param when action in [:callback]
  plug :require_state_param when action in [:callback]
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

  defp require_state_param(conn, _opts) do
    expected = SSO.state_param(conn)
    provided = conn.params["state"]

    if is_binary(expected) and is_binary(provided) and
         Plug.Crypto.secure_compare(provided, expected) do
      conn
    else
      Ztripwire.Log.emit(:warning, %{
        event: "sso_login_failed",
        provider: "evesso",
        reason: "invalid_state",
        has_code: is_binary(conn.params["code"]),
        params: conn.params |> Map.keys() |> Enum.sort(),
        state_cookie: Map.has_key?(conn.req_cookies, "ueberauth.state_param")
      })

      conn
      |> put_flash(:error, "EVE SSO login failed: login session expired, sign in again")
      |> redirect(to: "/")
      |> halt()
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
    token = auth.credentials && auth.credentials.token

    case Ztripwire.SSO.JWT.verify(token, subject: auth.uid) do
      {:ok, _claims} ->
        login(conn, auth)

      {:error, reason} ->
        Ztripwire.Log.emit(:warning, %{
          event: "sso_token_invalid",
          reason: inspect(reason)
        })

        conn
        |> put_flash(:error, "EVE SSO login failed: token verification failed")
        |> redirect(to: "/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    details = failure_message(failure)

    Ztripwire.Log.emit(:warning, %{
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

  defp login(conn, auth) do
    previous = Ztripwire.Accounts.get_character_by_eve_id(auth.uid)
    {:ok, character} = Ztripwire.Accounts.upsert_character_from_ueberauth(auth)
    character = handle_owner_change(previous, character)

    Task.start(fn -> Ztripwire.SyncServer.sync_character(character) end)
    {:ok, _pid} = Ztripwire.Tracking.ensure_poller(character)

    character = sync_admin(character)
    Ztripwire.Accounts.bump_stats(character.id, login_count: 1)

    conn
    |> SessionUser.put(character)
    |> redirect(to: "/Jita")
  end

  defp handle_owner_change(previous, character) do
    if Ztripwire.Accounts.owner_changed?(previous, character) do
      Ztripwire.Log.emit(:warning, %{
        event: "sso_owner_changed",
        eve_id: character.eve_id,
        name: character.name
      })

      case Ztripwire.Accounts.revoke_admin(character) do
        {:ok, updated} -> updated
        _ -> character
      end
    else
      character
    end
  end

  defp sync_admin(character) do
    cond do
      Ztripwire.Accounts.admin_allowlisted?(character) ->
        case Ztripwire.Accounts.ensure_admin(character) do
          {:ok, updated} -> updated
          _ -> character
        end

      character.is_admin and Ztripwire.Accounts.admin_allowlist_configured?() ->
        case Ztripwire.Accounts.revoke_admin(character) do
          {:ok, updated} ->
            Ztripwire.Log.emit(:warning, %{
              event: "admin_revoked",
              eve_id: character.eve_id,
              name: character.name
            })

            updated

          _ ->
            character
        end

      true ->
        character
    end
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

  def mask_session(conn, %{"id" => id}) do
    with {mask_id, ""} <- Integer.parse(to_string(id)),
         %{} = mask <- find_session_mask(conn, mask_id) do
      conn
      |> SessionUser.put_mask(mask.id)
      |> send_resp(:no_content, "")
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end

  defp find_session_mask(conn, mask_id) do
    conn
    |> session_characters()
    |> Ztripwire.Masks.list_masks_for_characters()
    |> Enum.find(&(&1.id == mask_id))
  end

  defp session_characters(conn) do
    session = get_session(conn)

    current =
      case SessionUser.get(session) do
        %{id: eve_id} -> Ztripwire.Accounts.get_character_by_eve_id(eve_id)
        _ -> nil
      end

    session
    |> SessionUser.ids()
    |> Enum.map(&Ztripwire.Accounts.get_character_by_eve_id/1)
    |> then(&[current | &1])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
  end

  defp put_character_session(conn, eve_id) do
    character_ids = SessionUser.ids(get_session(conn))
    current = SessionUser.get(get_session(conn))
    current_id = current && current.id

    with {id, ""} <- Integer.parse(to_string(eve_id)),
         %{} = character <- Ztripwire.Accounts.get_character_by_eve_id(id),
         true <-
           to_string(id) == to_string(current_id) or
             to_string(id) in Enum.map(character_ids, &to_string/1) or
             Ztripwire.SSO.demo?() do
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
end
