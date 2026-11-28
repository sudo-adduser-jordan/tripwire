defmodule Ztripwire.SSO.JWT do
  alias Ztripwire.ESI.Client
  alias Ztripwire.SSO

  @metadata_url "https://login.eveonline.com/.well-known/oauth-authorization-server"
  @accepted_issuers ["https://login.eveonline.com", "login.eveonline.com"]
  @expected_audience "EVE Online"

  def verify(token, opts \\ [])

  def verify(token, opts) when is_binary(token) do
    with {:ok, kid, alg} <- header(token),
         {:ok, jwks} <- jwks(opts),
         {:ok, key} <- signing_key(jwks, kid, alg),
         {:ok, claims} <- verify_signature(token, key, alg),
         :ok <- validate_claims(claims, opts) do
      {:ok, claims}
    end
  end

  def verify(_token, _opts), do: {:error, :invalid_token}

  defp header(token) do
    case String.split(token, ".") do
      [encoded, _payload, _signature] ->
        with {:ok, json} <- Base.url_decode64(encoded, padding: false),
             {:ok, %{"kid" => kid, "alg" => alg}} <- Jason.decode(json) do
          {:ok, kid, alg}
        else
          _ -> {:error, :invalid_token}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  defp jwks(opts) do
    case Keyword.get(opts, :jwks) do
      nil -> fetch_jwks()
      jwks -> {:ok, jwks}
    end
  end

  defp fetch_jwks do
    headers = [{"user-agent", Client.user_agent()}, {"accept", "application/json"}]

    with {:ok, %{status: 200, body: metadata}} <-
           Req.get(@metadata_url, headers: headers, receive_timeout: 10_000),
         %{"jwks_uri" => jwks_uri} when is_binary(jwks_uri) <- metadata,
         {:ok, %{status: 200, body: jwks}} <-
           Req.get(jwks_uri, headers: headers, receive_timeout: 10_000) do
      {:ok, jwks}
    else
      _ -> {:error, :jwks_unavailable}
    end
  end

  defp signing_key(jwks, kid, alg) do
    keys = Map.get(jwks, "keys", [])

    key =
      Enum.find(keys, fn key -> key["kid"] == kid and key["alg"] == alg end) ||
        Enum.find(keys, fn key -> key["alg"] == alg end)

    case key do
      nil -> {:error, :unknown_signing_key}
      key -> {:ok, JOSE.JWK.from_map(key)}
    end
  end

  defp verify_signature(token, key, alg) do
    case JOSE.JWT.verify_strict(key, [alg], token) do
      {true, jwt, _jws} -> {:ok, jwt.fields}
      _ -> {:error, :invalid_signature}
    end
  rescue
    _ -> {:error, :invalid_signature}
  end

  defp validate_claims(claims, opts) do
    with :ok <- validate_issuer(claims),
         :ok <- validate_audience(claims, opts),
         :ok <- validate_expiry(claims),
         :ok <- validate_subject(claims) do
      :ok
    end
  end

  defp validate_issuer(%{"iss" => issuer}) when issuer in @accepted_issuers, do: :ok
  defp validate_issuer(_), do: {:error, :invalid_issuer}

  defp validate_audience(claims, opts) do
    audiences =
      case Map.get(claims, "aud") do
        value when is_list(value) -> value
        value when is_binary(value) -> [value]
        _ -> []
      end

    client_id = Keyword.get(opts, :client_id, SSO.client_id())

    cond do
      @expected_audience not in audiences ->
        {:error, :invalid_audience}

      is_binary(client_id) and client_id != "" and client_id not in audiences ->
        {:error, :invalid_audience}

      true ->
        :ok
    end
  end

  defp validate_expiry(%{"exp" => exp}) when is_integer(exp) do
    if exp > System.system_time(:second), do: :ok, else: {:error, :expired}
  end

  defp validate_expiry(_), do: {:error, :missing_expiry}

  defp validate_subject(%{"sub" => "CHARACTER:EVE:" <> _}), do: :ok
  defp validate_subject(_), do: {:error, :invalid_subject}
end
