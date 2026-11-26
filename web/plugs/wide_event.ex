defmodule ZtripwireWeb.Plugs.WideEvent do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    start = System.monotonic_time(:millisecond)

    event =
      Ztripwire.Log.new(%{
        request_id: request_id(conn),
        method: conn.method,
        path: conn.request_path,
        remote_ip: remote_ip(conn),
        user_agent: user_agent(conn)
      })

    conn
    |> put_private(:wide_event, event)
    |> put_private(:wide_event_start, start)
    |> register_before_send(&finish/1)
  end

  defp finish(conn) do
    start = conn.private[:wide_event_start] || System.monotonic_time(:millisecond)
    duration = System.monotonic_time(:millisecond) - start
    base = conn.private[:wide_event] || Ztripwire.Log.new()

    event =
      Ztripwire.Log.merge(base, %{
        status: conn.status || 0,
        duration_ms: duration,
        outcome: outcome(conn.status)
      })

    level = if (conn.status || 0) >= 500, do: :error, else: :info
    Ztripwire.Log.emit(level, event)
    conn
  end

  defp outcome(status) when is_integer(status) and status >= 500, do: "error"
  defp outcome(status) when is_integer(status) and status >= 400, do: "client_error"
  defp outcome(_), do: "success"

  defp request_id(conn) do
    case get_resp_header(conn, "x-request-id") do
      [id | _] -> id
      [] -> "req_#{:erlang.unique_integer([:positive])}"
    end
  end

  defp remote_ip(conn) do
    case conn.remote_ip do
      nil -> "unknown"
      tuple -> tuple |> :inet.ntoa() |> to_string()
    end
  end

  defp user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [agent | _] -> agent
      [] -> "unknown"
    end
  end
end
