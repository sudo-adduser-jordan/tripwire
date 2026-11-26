defmodule Ztripwire.SSOTest do
  use ExUnit.Case, async: true

  @secret_key_base String.duplicate("sso", 32)

  test "state_param returns the verified state cookie" do
    assert Ztripwire.SSO.state_param(request_with_cookie(signed_state())) == "abc123"
  end

  test "state_param ignores a tampered state cookie" do
    assert Ztripwire.SSO.state_param(request_with_cookie(signed_state() <> "x")) == nil
  end

  test "state_param returns nil without a state cookie" do
    conn =
      Plug.Test.conn(:get, "/auth/evesso/callback")
      |> Map.put(:secret_key_base, @secret_key_base)

    assert Ztripwire.SSO.state_param(conn) == nil
  end

  defp signed_state do
    %{value: value} =
      Plug.Test.conn(:get, "/auth/evesso")
      |> Map.put(:secret_key_base, @secret_key_base)
      |> Plug.Conn.put_resp_cookie("ueberauth.state_param", "abc123", sign: true)
      |> Map.fetch!(:resp_cookies)
      |> Map.fetch!("ueberauth.state_param")

    value
  end

  defp request_with_cookie(value) do
    Plug.Test.conn(:get, "/auth/evesso/callback")
    |> Map.put(:secret_key_base, @secret_key_base)
    |> Plug.Conn.put_req_header("cookie", "ueberauth.state_param=#{value}")
  end
end
