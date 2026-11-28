defmodule Ztripwire.ESIStub do
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    path = String.replace_prefix(conn.request_path, "/latest", "")

    case {conn.method, path} do
      {"GET", "/status/"} ->
        json(conn, %{"players" => 1000})

      {"GET", "/universe/system_jumps/"} ->
        json(conn, [])

      {"GET", "/universe/system_kills/"} ->
        json(conn, [])

      {"GET", "/sovereignty/map/"} ->
        json(conn, [])

      {"GET", "/universe/systemjumps/"} ->
        json(conn, [])

      {"GET", "/characters/" <> _} ->
        character_response(conn, path)

      {"GET", "/universe/systems/" <> _} ->
        json(conn, %{
          "name" => "Stub System",
          "security_status" => 0.5,
          "constellation_id" => 20_000_020
        })

      {"GET", "/universe/constellations/" <> _} ->
        json(conn, %{"name" => "Stub Constellation", "region_id" => 10_000_002})

      {"GET", "/universe/regions/" <> _} ->
        json(conn, %{"name" => "Stub Region"})

      {"GET", "/universe/types/" <> _} ->
        json(conn, %{"name" => "Stub Type"})

      {"GET", "/alliances/" <> _} ->
        json(conn, %{"name" => "Stub Alliance"})

      {"GET", "/corporations/" <> _} ->
        json(conn, %{"name" => "Stub Corporation"})

      {"GET", "/route/" <> _} ->
        json(conn, [30_000_142, 30_000_143])

      {"POST", "/universe/ids/"} ->
        json(conn, %{"systems" => []})

      _ ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, ~s({"error":"not found"}))
    end
  end

  defp character_response(conn, path) do
    cond do
      String.ends_with?(path, "/location/") ->
        json(conn, %{"solar_system_id" => 30_000_142})

      String.ends_with?(path, "/ship/") ->
        json(conn, %{"ship_name" => "Stub Ship", "ship_type_id" => 670})

      String.ends_with?(path, "/online/") ->
        json(conn, %{"online" => true})

      String.ends_with?(path, "/roles/") ->
        json(conn, %{"roles" => []})

      String.ends_with?(path, "/titles/") ->
        json(conn, [])

      true ->
        json(conn, %{"name" => "Stub Character", "corporation_id" => 1})
    end
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
