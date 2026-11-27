defmodule ZtripwireWeb.PageControllerTest do
  use ZtripwireWeb.ConnCase, async: false

  test "GET / shows the landing page in demo mode with a disabled SSO button", %{conn: conn} do
    with_env(
      %{
        "EVESSO_CLIENT_ID" => nil,
        "EVESSO_SECRET_KEY" => nil,
        "EVESSO_CLIENT_SECRET" => nil
      },
      fn ->
        conn = get(conn, ~p"/")
        html = html_response(conn, 200)

        assert html =~ "The modern wormhole mapping tool"
        assert html =~ ~s|aria-disabled="true"|
        refute html =~ ~s|href="/auth/evesso"|
        assert html =~ ~s|href="/Jita"|
        assert html =~ "Demo"
        assert html =~ ~r|href="/Jita"[^>]*data-autofocus|
        assert length(Regex.scan(~r/data-autofocus/, html)) == 1
        assert html =~ ~s|data-theme-lock="true"|
      end
    )
  end

  test "GET / shows the landing page when SSO credentials are configured", %{conn: conn} do
    with_env(
      %{
        "EVESSO_CLIENT_ID" => "client-id",
        "EVESSO_CLIENT_SECRET" => "client-secret"
      },
      fn ->
        conn = get(conn, ~p"/")
        html = html_response(conn, 200)

        assert html =~ "The modern wormhole mapping tool"
        assert html =~ ~s|href="/auth/evesso"|
        refute html =~ ~s|aria-disabled="true"|
        assert html =~ ~s|href="/Jita"|
        assert html =~ "Demo"
        assert html =~ ~r|href="/auth/evesso"[^>]*data-autofocus|
        assert length(Regex.scan(~r/data-autofocus/, html)) == 1
        assert html =~ ~s|data-theme-lock="true"|
      end
    )
  end

  test "GET / redirects a logged-in character to the dashboard", %{conn: conn} do
    {:ok, character} =
      Ztripwire.Accounts.upsert_character(%{eve_id: 77_100, name: "Landing Pilot"})

    conn =
      conn
      |> Plug.Test.init_test_session(%{
        "current_user" => %{"id" => character.eve_id, "name" => character.name}
      })
      |> get(~p"/")

    assert redirected_to(conn) == "/dashboard"
  end

  test "GET / renders the landing page when the session character is gone", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{"current_user" => %{"id" => 999_999, "name" => "Ghost"}})
      |> get(~p"/")

    html = html_response(conn, 200)
    assert html =~ "The modern wormhole mapping tool"
    assert html =~ ~s|href="/Jita"|
    assert html =~ ~s|data-theme-lock="true"|
  end

  defp with_env(vars, fun) do
    previous = Map.new(vars, fn {name, _value} -> {name, System.get_env(name)} end)

    Enum.each(vars, fn
      {name, nil} -> System.delete_env(name)
      {name, value} -> System.put_env(name, value)
    end)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end
  end
end
