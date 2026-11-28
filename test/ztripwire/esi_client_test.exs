defmodule Ztripwire.ESI.ClientTest do
  use ExUnit.Case, async: false

  alias Ztripwire.ESI
  alias Ztripwire.ESI.Client

  setup do
    previous = Application.get_env(:ztripwire, Ztripwire.ESI)

    Application.put_env(
      :ztripwire,
      Ztripwire.ESI,
      base_url: "https://esi.test/latest",
      user_agent: "Ztripwire/1.0 (test@example.com)",
      compatibility_date: "2026-05-18",
      cache: true,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    Client.clear()

    on_exit(fn ->
      Application.put_env(:ztripwire, Ztripwire.ESI, previous)
      Client.clear()
    end)

    :ok
  end

  test "sends identifying headers and serves repeated calls from the cache" do
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(parent, {:headers, conn.req_headers})

      conn
      |> Plug.Conn.put_resp_header("cache-control", "public, max-age=60")
      |> Plug.Conn.put_resp_header("etag", ~s("v1"))
      |> Req.Test.json(%{"name" => "Jita"})
    end)

    assert {:ok, %{"name" => "Jita"}} = ESI.get_system(30_000_142)
    assert {:ok, %{"name" => "Jita"}} = ESI.get_system(30_000_142)

    assert_received {:headers, headers}
    refute_received {:headers, _}

    assert {"user-agent", "Ztripwire/1.0 (test@example.com)"} in headers
    assert {"x-compatibility-date", "2026-05-18"} in headers
    assert {"accept", "application/json"} in headers
  end

  test "revalidates a stale entry with If-None-Match and reuses the body on 304" do
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(parent, {:headers, conn.req_headers})

      case Plug.Conn.get_req_header(conn, "if-none-match") do
        [~s("v1")] ->
          conn
          |> Plug.Conn.put_resp_header("cache-control", "public, max-age=60")
          |> Plug.Conn.put_resp_header("etag", ~s("v1"))
          |> Plug.Conn.send_resp(304, "")

        _ ->
          conn
          |> Plug.Conn.put_resp_header("cache-control", "public, max-age=60")
          |> Plug.Conn.put_resp_header("etag", ~s("v1"))
          |> Req.Test.json(%{"name" => "Jita"})
      end
    end)

    assert {:ok, %{"name" => "Jita"}} =
             Client.get("/universe/systems/30000142/", subject: :public)

    Client.expire(:get, "/universe/systems/30000142/", :public)

    assert {:ok, %{"name" => "Jita"}} =
             Client.get("/universe/systems/30000142/", subject: :public)

    assert_received {:headers, _first}
    assert_received {:headers, second}
    assert {"if-none-match", ~s("v1")} in second
  end

  test "backs off after a rate limited response" do
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(parent, {:requested, conn.request_path})

      conn
      |> Plug.Conn.put_resp_header("retry-after", "60")
      |> Plug.Conn.put_resp_header("x-ratelimit-group", "char-location")
      |> Plug.Conn.put_resp_header("x-ratelimit-limit", "1200/15m")
      |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "0")
      |> Plug.Conn.send_resp(429, "")
    end)

    assert {:error, {:rate_limited, 60}} =
             Client.get("/characters/1/location/", subject: 1, token: "token")

    assert_received {:requested, _}

    assert {:error, {:rate_limited, _seconds}} =
             Client.get("/characters/1/location/", subject: 1, token: "token")

    refute_received {:requested, _}
  end

  test "uses the corrected sovereignty route" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/latest/sovereignty/map/"
      Req.Test.json(conn, [])
    end)

    assert {:ok, []} = ESI.get_sovereignty_map()
  end

  test "blocks requests when the ESI error limit is exhausted" do
    parent = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(parent, {:requested, conn.request_path})

      conn
      |> Plug.Conn.put_resp_header("x-esi-error-limit-remain", "0")
      |> Plug.Conn.put_resp_header("x-esi-error-limit-reset", "30")
      |> Plug.Conn.send_resp(420, "")
    end)

    assert {:error, {:rate_limited, 30}} = ESI.get_status()
    assert_received {:requested, _}
    assert {:error, {:rate_limited, _seconds}} = ESI.get_status()
    refute_received {:requested, _}
  end
end
