defmodule TripwireWeb.PageControllerTest do
  use TripwireWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "The modern wormhole mapping tool"
  end
end
