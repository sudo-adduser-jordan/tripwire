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
    # user_info = %{
    #   uid: auth.uid,
    #   name: auth.info.name,
    #   image: auth.info.image,
    #   token: auth.credentials.token
    # }

    conn
    # |> put_session(:user, user_info)
    |> put_session(:current_user, %{id: auth.uid, name: auth.info.name})
    |> redirect(to: "/dashboard/#{auth.info.name}")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "EVE SSO login failed")
    |> redirect(to: "/")
  end
end
