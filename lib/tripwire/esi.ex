defmodule Tripwire.ESI do
  @moduledoc """
  Minimal EVE Swagger Interface (ESI) and EVE SSO token client built on Req.
  """

  @login_base "https://login.eveonline.com/v2/oauth"
  @esi_base "https://esi.evetech.net/latest"

  @doc """
  Refreshes the access token for a stored refresh token.

      {:ok, %{"access_token" => at, "expires_in" => 1200}} = Tripwire.ESI.refresh_access_token(rt)
  """
  def refresh_access_token(refresh_token) do
    case req(:post, @login_base <> "/token",
           auth: {:basic, "#{client_id()}:#{client_secret()}"},
           form: [grant_type: "refresh_token", refresh_token: refresh_token]
         ) do
      {:ok, %{status: 200} = response} -> {:ok, response.body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  def get_character_location(character_id, access_token),
    do: authorized_get("/characters/#{character_id}/location/", access_token)

  def get_character_online(character_id, access_token),
    do: authorized_get("/characters/#{character_id}/online/", access_token)

  def get_character(character_id), do: public_get("/characters/#{character_id}/")

  def get_system(system_id), do: public_get("/universe/systems/#{system_id}/")

  @doc """
  Returns an unexpired access token for the character, refreshing it when needed.
  """
  def valid_access_token(%{eve_id: eve_id, refresh_token: refresh_token}, cache \\ TokenCache) do
    case cache.get(eve_id) do
      %{access_token: token, expires_at: expires_at} = cached ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, token}
        else
          cache.delete(eve_id)
          do_refresh(cached.refresh_token || refresh_token, eve_id, cache)
        end

      nil ->
        do_refresh(refresh_token, eve_id, cache)
    end
  end

  defp do_refresh(nil, _eve_id, _cache), do: {:error, :no_refresh_token}

  defp do_refresh(refresh_token, eve_id, cache) do
    with {:ok, body} <- refresh_access_token(refresh_token) do
      expires_at =
        DateTime.add(
          DateTime.utc_now(),
          body["expires_in"] || 1200 - 60,
          :second
        )

      cache.put(eve_id, %{
        access_token: body["access_token"],
        refresh_token: body["refresh_token"] || refresh_token,
        expires_at: expires_at
      })

      {:ok, body["access_token"]}
    end
  end

  defp authorized_get(path, access_token) do
    case req(:get, @esi_base <> path, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200} = response} -> {:ok, response.body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  defp public_get(path) do
    case req(:get, @esi_base <> path) do
      {:ok, %{status: 200} = response} -> {:ok, response.body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  defp req(method, url, opts \\ []) do
    opts
    |> Keyword.put(:url, url)
    |> Keyword.merge(method: method)
    |> then(&Req.request(&1))
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, exception} -> {:error, exception}
    end
  end

  defp client_id, do: resolve_credential(:client_id)
  defp client_secret, do: resolve_credential(:client_secret)

  defp resolve_credential(key) do
    :tripwire
    |> Application.get_env(Ueberauth.Strategy.EVESSO.OAuth, [])
    |> Keyword.get(key)
    |> case do
      {:system, env_var} -> System.get_env(env_var, "")
      value when is_binary(value) -> value
      _ -> ""
    end
  end
end
