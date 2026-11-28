defmodule Ztripwire.PollerESIStub do
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    pid = Keyword.fetch!(opts, :pid)
    online = Keyword.get(opts, :online, false)
    path = String.replace_prefix(conn.request_path, "/latest", "")

    cond do
      String.ends_with?(path, "/online/") ->
        send(pid, {:esi, :online})
        json(conn, %{"online" => online})

      String.ends_with?(path, "/location/") ->
        send(pid, {:esi, :location})
        json(conn, %{"solar_system_id" => 31_000_001})

      String.ends_with?(path, "/ship/") ->
        send(pid, {:esi, :ship})
        json(conn, %{"ship_name" => "Stub Ship", "ship_type_id" => 670})

      String.starts_with?(path, "/universe/systems/") ->
        json(conn, %{"name" => "Stub System", "security_status" => 0.0, "constellation_id" => 1})

      true ->
        json(conn, %{})
    end
  end

  defp json(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end
end
