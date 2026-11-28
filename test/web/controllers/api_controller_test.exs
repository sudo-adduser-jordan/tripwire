defmodule ZtripwireWeb.ApiControllerTest do
  use ZtripwireWeb.ConnCase, async: false

  setup do
    previous = System.get_env("TRIPWIRE_API")
    System.put_env("TRIPWIRE_API", "secret-token")

    on_exit(fn ->
      if previous do
        System.put_env("TRIPWIRE_API", previous)
      else
        System.delete_env("TRIPWIRE_API")
      end
    end)

    :ok
  end

  test "rejects every request when no token is configured", %{conn: conn} do
    System.delete_env("TRIPWIRE_API")

    conn =
      conn
      |> put_req_header("x-api-token", "secret-token")
      |> get("/api/signatures?mask_id=1")

    assert json_response(conn, 403) == %{"error" => "API disabled"}
  end

  test "accepts the token from the header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-api-token", "secret-token")
      |> get("/api/signatures?mask_id=1")

    assert %{"signatures" => _} = json_response(conn, 200)
  end

  test "rejects the token in the query string", %{conn: conn} do
    conn = get(conn, "/api/signatures?mask_id=1&token=secret-token")

    assert json_response(conn, 401) == %{"error" => "invalid token"}
  end

  test "rejects a wrong token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-api-token", "wrong")
      |> get("/api/signatures?mask_id=1")

    assert json_response(conn, 401) == %{"error" => "invalid token"}
  end
end
