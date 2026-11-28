defmodule Ztripwire.SSO.JWTTest do
  use ExUnit.Case, async: true

  alias Ztripwire.SSO.JWT

  setup do
    key = JOSE.JWK.generate_key({:rsa, 2048})

    {_fields, public} =
      key
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()

    jwks = %{"keys" => [public |> Map.put("kid", "key-1") |> Map.put("alg", "RS256")]}

    {:ok, key: key, jwks: jwks}
  end

  test "accepts a valid access token", %{key: key, jwks: jwks} do
    token = sign(key, claims())

    assert {:ok, %{"sub" => "CHARACTER:EVE:123"}} =
             JWT.verify(token, jwks: jwks, client_id: "client-id")
  end

  test "rejects a token for another client", %{key: key, jwks: jwks} do
    token = sign(key, claims(%{"aud" => ["EVE Online", "other-client"]}))

    assert {:error, :invalid_audience} =
             JWT.verify(token, jwks: jwks, client_id: "client-id")
  end

  test "rejects an expired token", %{key: key, jwks: jwks} do
    token = sign(key, claims(%{"exp" => System.system_time(:second) - 60}))

    assert {:error, :expired} = JWT.verify(token, jwks: jwks, client_id: "client-id")
  end

  test "rejects another issuer", %{key: key, jwks: jwks} do
    token = sign(key, claims(%{"iss" => "https://example.com"}))

    assert {:error, :invalid_issuer} = JWT.verify(token, jwks: jwks, client_id: "client-id")
  end

  test "rejects a token signed by an unknown key", %{jwks: jwks} do
    other = JOSE.JWK.generate_key({:rsa, 2048})
    token = sign(other, claims())

    assert {:error, :invalid_signature} =
             JWT.verify(token, jwks: jwks, client_id: "client-id")
  end

  defp claims(overrides \\ %{}) do
    Map.merge(
      %{
        "iss" => "https://login.eveonline.com",
        "aud" => ["EVE Online", "client-id"],
        "exp" => System.system_time(:second) + 300,
        "sub" => "CHARACTER:EVE:123",
        "name" => "Test Character",
        "owner" => "owner-hash"
      },
      overrides
    )
  end

  defp sign(key, claims) do
    {_jws, token} =
      key
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => "key-1"}, claims)
      |> JOSE.JWS.compact()

    token
  end
end
