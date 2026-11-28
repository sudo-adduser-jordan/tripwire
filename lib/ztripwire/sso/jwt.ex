defmodule Ztripwire.SSO.JWT do
  alias Ztripwire.ESI.Client
  alias Ztripwire.SSO

  @metadata_url "https://login.eveonline.com/.well-known/oauth-authorization-server"
  @jwks_prefix "https://login.eveonline.com/"
  @accepted_issuers ["https://login.eveonline.com", "login.eveonline.com"]
  @expected_audience "EVE Online"
  @allowed_algs ["RS256"]
  @jwks_ttl_ms 3_600_000
  @jwks_key {__MODULE__, :jwks}

  def verify(token, opts \\ [])

  def verify(token, opts) when is_binary(token) do
    with {:ok, kid, alg} <- header(token),
         {:ok, jwks} <- jwks(opts) do
      case signing_key(jwks, kid, alg) do
        {:ok, key} -> finish(token, key, alg, opts)
        {:error, :unknown_signing_key} -> refetch_and_verify(token, kid, alg, opts)
      end
    end
  end

  def verify(_token, _opts), do: {:error, :invalid_token}

  def clear_cache, do: :persistent_term.erase(@jwks_key)

  defp refetch_and_verify(token, kid, alg, opts) do
    if Keyword.get(opts, :jwks) do
      {:error, :unknown_signing_key}
    else
      clear_cache()

      with {:ok, jwks} <- jwks(opts),
           {:ok, key} <- signing_key(jwks, kid, alg) do
        finish(token, key, alg, opts)
      end
    end
  end

  defp finish(token, key, alg, opts) do
    with {:ok, claims} <- verify_signature(token, key, alg),
         :ok <- validate_claims(claims, opts) do
      {:ok, claims}
    end
  end

  defp header(token) do
    case String.split(token, ".") do
      [encoded, _payload, _signature] ->
        with {:ok, json} <- Base.url_decode64(encoded, padding: false),
             {:ok, %{"kid" => kid, "alg" => alg}} when alg in @allowed_algs <-
               Jason.decode(json) do
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
      nil -> cached_jwks()
      jwks -> {:ok, jwks}
    end
  end

  defp cached_jwks do
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get(@jwks_key, nil) do
      {jwks, expires_at} when expires_at > now -> {:ok, jwks}
      _ -> fetch_and_cache_jwks()
    end
  end

  defp fetch_and_cache_jwks do
    with {:ok, jwks} <- fetch_jwks() do
      expires_at = System.monotonic_time(:millisecond) + @jwks_ttl_ms
      :persistent_term.put(@jwks_key, {jwks, expires_at})
      {:ok, jwks}
    end
  end

  defp fetch_jwks do
    headers = [{"user-agent", Client.user_agent()}, {"accept", "application/json"}]

    with {:ok, %{status: 200, body: metadata}} <-
           Req.get(@metadata_url, headers: headers, receive_timeout: 10_000),
         %{"jwks_uri" => jwks_uri} when is_binary(jwks_uri) <- metadata,
         :ok <- allowed_jwks_uri?(jwks_uri),
         {:ok, %{status: 200, body: jwks}} <-
           Req.get(jwks_uri, headers: headers, receive_timeout: 10_000) do
      {:ok, jwks}
    else
      _ -> {:error, :jwks_unavailable}
    end
  end

  defp allowed_jwks_uri?(jwks_uri) do
    if String.starts_with?(jwks_uri, @jwks_prefix), do: :ok, else: {:error, :jwks_unavailable}
  end

  defp signing_key(jwks, kid, alg) do
    keys = Map.get(jwks, "keys", [])

    case Enum.find(keys, fn key -> key["kid"] == kid and key["alg"] in [nil, alg] end) do
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
         :ok <- validate_subject(claims),
         :ok <- validate_subject_id(claims, opts) do
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

  defp validate_subject_id(claims, opts) do
    case Keyword.get(opts, :subject) do
      nil ->
        :ok

      subject ->
        if claims["sub"] == "CHARACTER:EVE:#{subject}", do: :ok, else: {:error, :subject_mismatch}
    end
  end
end
