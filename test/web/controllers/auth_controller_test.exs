defmodule TripwireWeb.AuthControllerTest do
  use TripwireWeb.ConnCase, async: false

  test "failed SSO callback flashes the failure reason", %{conn: conn} do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_CLIENT_SECRET", "test-secret")

    try do
      conn = get(conn, "/auth/evesso/callback?code=code&state=wrong")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "phoenix_flash")["error"] =~ "EVE SSO login failed"
      assert get_session(conn, "phoenix_flash")["error"] =~ "login session expired"
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_CLIENT_SECRET")
    end
  end

  test "SSO request redirects to EVE with a state parameter and state cookie", %{conn: conn} do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_SECRET_KEY", "test-secret")

    try do
      conn = get(conn, "/auth/evesso")

      assert redirected_to(conn, 302) =~ "login.eveonline.com/v2/oauth/authorize"

      assert %{"state" => state} =
               conn
               |> redirected_to(302)
               |> URI.parse()
               |> Map.fetch!(:query)
               |> URI.decode_query()

      assert is_binary(state) and state != ""
      assert %{value: signed} = conn.resp_cookies["ueberauth.state_param"]
      assert is_binary(signed) and signed != state
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_SECRET_KEY")
    end
  end

  test "SSO callback with a matching state cookie passes the CSRF checks", %{conn: conn} do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_SECRET_KEY", "test-secret")

    config = Application.get_env(:ueberauth, Ueberauth.Strategy.EVESSO.OAuth)

    Application.put_env(
      :ueberauth,
      Ueberauth.Strategy.EVESSO.OAuth,
      Keyword.put(config, :token_url, "http://127.0.0.1:1/token")
    )

    try do
      request_conn = get(conn, "/auth/evesso")

      state =
        request_conn
        |> redirected_to(302)
        |> URI.parse()
        |> Map.fetch!(:query)
        |> URI.decode_query()
        |> Map.fetch!("state")

      signed = request_conn.resp_cookies["ueberauth.state_param"].value

      conn =
        build_conn()
        |> put_req_header("cookie", "ueberauth.state_param=#{signed}")
        |> get("/auth/evesso/callback?code=code&state=#{state}")

      flash = get_session(conn, "phoenix_flash")["error"]

      assert redirected_to(conn) == "/"
      assert flash =~ "EVE SSO login failed"
      assert byte_size(flash) < 200
      refute flash =~ "login session expired"
      refute flash =~ "Cross-Site Request Forgery"
    after
      Application.put_env(:ueberauth, Ueberauth.Strategy.EVESSO.OAuth, config)
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_SECRET_KEY")
    end
  end

  test "SSO callback without configured credentials stays in demo mode", %{conn: conn} do
    System.delete_env("EVESSO_CLIENT_ID")
    System.delete_env("EVESSO_SECRET_KEY")
    System.delete_env("EVESSO_CLIENT_SECRET")

    conn = get(conn, "/auth/evesso")

    assert redirected_to(conn) == "/"
    assert get_session(conn, "phoenix_flash")["info"] =~ "demo mode"
  end
end
