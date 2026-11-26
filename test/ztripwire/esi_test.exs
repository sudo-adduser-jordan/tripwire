defmodule Ztripwire.ESITest do
  use ExUnit.Case, async: false

  alias Ztripwire.ESI
  alias Ztripwire.ESI.TokenCache
  alias Ztripwire.SSO

  setup do
    on_exit(fn ->
      TokenCache.delete(999_001)
      TokenCache.delete(999_002)
    end)
  end

  test "valid_access_token reads the default token cache instead of an undefined module" do
    assert ESI.valid_access_token(%{eve_id: 999_001, refresh_token: nil}) ==
             {:error, :no_refresh_token}
  end

  test "token cache accepts reads and writes from other processes" do
    expires_at = DateTime.add(DateTime.utc_now(), 600, :second)

    cached =
      Task.async(fn ->
        TokenCache.put(999_002, %{
          access_token: "access-token",
          refresh_token: "refresh-token",
          expires_at: expires_at
        })

        TokenCache.get(999_002)
      end)
      |> Task.await()

    assert %{access_token: "access-token", refresh_token: "refresh-token"} = cached

    assert ESI.valid_access_token(%{eve_id: 999_002, refresh_token: nil}) ==
             {:ok, "access-token"}

    assert TokenCache.delete(999_002) == :ok
    assert TokenCache.get(999_002) == nil
  end

  test "SSO resolves the client credentials from the environment" do
    with_env(
      %{"EVESSO_CLIENT_ID" => "client-id", "EVESSO_SECRET_KEY" => "secret-key"},
      ["EVESSO_CLIENT_SECRET"],
      fn ->
        assert SSO.client_id() == "client-id"
        assert SSO.client_secret() == "secret-key"
        assert SSO.configured?()
      end
    )
  end

  test "SSO falls back to the alternate secret variable" do
    with_env(
      %{"EVESSO_CLIENT_ID" => "client-id", "EVESSO_CLIENT_SECRET" => "alt-secret"},
      ["EVESSO_SECRET_KEY"],
      fn ->
        assert SSO.client_secret() == "alt-secret"
      end
    )
  end

  defp with_env(set, delete, fun) do
    keys = Map.keys(set) ++ delete
    previous = Map.new(keys, &{&1, System.get_env(&1)})

    Enum.each(delete, &System.delete_env/1)
    Enum.each(set, fn {key, value} -> System.put_env(key, value) end)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end
end
