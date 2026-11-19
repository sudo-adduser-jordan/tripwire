defmodule TripwireWeb.AuthControllerTest do
  use TripwireWeb.ConnCase, async: false

  test "failed SSO callback flashes the failure reason", %{conn: conn} do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_CLIENT_SECRET", "test-secret")

    try do
      conn = get(conn, "/auth/evesso/callback?code=code&state=wrong")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "phoenix_flash")["error"] =~ "EVE SSO login failed"
      assert get_session(conn, "phoenix_flash")["error"] =~ "Cross-Site Request Forgery attack"
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_CLIENT_SECRET")
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
