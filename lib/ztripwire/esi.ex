defmodule Ztripwire.ESI do
  alias Ztripwire.ESI.{Client, TokenCache}

  @login_base "https://login.eveonline.com/v2/oauth"

  def refresh_access_token(refresh_token) do
    case req(:post, @login_base <> "/token",
           auth: {:basic, "#{client_id()}:#{client_secret()}"},
           headers: [{"user-agent", Client.user_agent()}],
           form: [grant_type: "refresh_token", refresh_token: refresh_token]
         ) do
      {:ok, %{status: 200} = response} -> {:ok, response.body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  def get_character_location(character_id, access_token, character \\ nil),
    do:
      authorized_get(
        "/characters/#{character_id}/location/",
        character_id,
        access_token,
        character
      )

  def get_character_online(character_id, access_token, character \\ nil),
    do:
      authorized_get("/characters/#{character_id}/online/", character_id, access_token, character)

  def get_character(character_id, opts \\ []),
    do: public_get("/characters/#{character_id}/", opts)

  def get_corporation(corporation_id, opts \\ []),
    do: public_get("/corporations/#{corporation_id}/", opts)

  def get_alliance(alliance_id), do: public_get("/alliances/#{alliance_id}/")

  def get_character_roles(character_id, access_token, character \\ nil),
    do:
      authorized_get("/characters/#{character_id}/roles/", character_id, access_token, character)

  def get_character_titles(character_id, access_token, character \\ nil) do
    case authorized_get(
           "/characters/#{character_id}/titles/",
           character_id,
           access_token,
           character
         ) do
      {:ok, titles} when is_list(titles) -> {:ok, Enum.map(titles, & &1["name"])}
      other -> other
    end
  end

  def get_character_ship(character_id, access_token, character \\ nil),
    do: authorized_get("/characters/#{character_id}/ship/", character_id, access_token, character)

  def get_system_jumps, do: public_get("/universe/system_jumps/")

  def get_system_kills, do: public_get("/universe/system_kills/")

  def get_status, do: public_get("/status/")

  def get_system(system_id), do: public_get("/universe/systems/#{system_id}/")

  def get_type(type_id), do: public_get("/universe/types/#{type_id}/")

  def get_constellation(constellation_id),
    do: public_get("/universe/constellations/#{constellation_id}/")

  def get_region(region_id), do: public_get("/universe/regions/#{region_id}/")

  def get_sovereignty_map, do: public_get("/sovereignty/map/")

  def get_route(origin, destination, opts \\ []) do
    flag = Keyword.get(opts, :flag, "shortest")

    if kspace_id?(origin) and kspace_id?(destination) do
      public_get("/route/#{origin}/#{destination}/?flag=#{flag}")
    else
      {:error, :no_kspace_route}
    end
  end

  def resolve_system_id(name) when is_binary(name) do
    trimmed = String.trim(name)

    if trimmed == "" do
      :error
    else
      case public_post("/universe/ids/", [trimmed]) do
        {:ok, %{"systems" => [%{"id" => id} | _]}} ->
          {:ok, id}

        {:ok, %{"systems" => systems}} when is_list(systems) ->
          case Enum.find(
                 systems,
                 &(String.downcase(&1["name"] || "") ==
                     String.downcase(trimmed))
               ) do
            %{"id" => id} -> {:ok, id}
            _ -> :error
          end

        _ ->
          :error
      end
    end
  end

  def resolve_system_id(_), do: :error

  defp kspace_id?(id) when is_integer(id), do: id < 31_000_000
  defp kspace_id?(_), do: false

  def system_activity(solar_system_id) do
    jumps =
      case get_system_jumps() do
        {:ok, rows} when is_list(rows) ->
          case Enum.find(rows, &(&1["system_id"] == solar_system_id)) do
            %{"ship_jumps" => n} -> n || 0
            _ -> 0
          end

        _ ->
          0
      end

    {ship_kills, pod_kills, npc_kills} =
      case get_system_kills() do
        {:ok, rows} when is_list(rows) ->
          case Enum.find(rows, &(&1["system_id"] == solar_system_id)) do
            nil -> {0, 0, 0}
            row -> {row["ship_kills"] || 0, row["pod_kills"] || 0, row["npc_kills"] || 0}
          end

        _ ->
          {0, 0, 0}
      end

    %{jumps: jumps, ship_kills: ship_kills, pod_kills: pod_kills, npc_kills: npc_kills}
  end

  def valid_access_token(%{eve_id: eve_id} = character, cache \\ TokenCache) do
    case :global.trans(
           {{__MODULE__, eve_id}, self()},
           fn -> do_valid_access_token(character, cache) end,
           [node()]
         ) do
      :aborted -> {:error, :refresh_locked}
      result -> result
    end
  end

  defp do_valid_access_token(%{eve_id: eve_id, refresh_token: refresh_token}, cache) do
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
    case refresh_access_token(refresh_token) do
      {:ok, body} ->
        expires_at =
          DateTime.add(
            DateTime.utc_now(),
            (body["expires_in"] || 1200) - 60,
            :second
          )

        rotated = body["refresh_token"] || refresh_token

        cache.put(eve_id, %{
          access_token: body["access_token"],
          refresh_token: rotated,
          expires_at: expires_at
        })

        persist_refresh_token(eve_id, rotated)

        {:ok, body["access_token"]}

      {:error, reason} ->
        if invalid_grant?(reason) do
          cache.delete(eve_id)
          _ = Ztripwire.Accounts.clear_refresh_token(eve_id)
          {:error, :reauth_required}
        else
          {:error, reason}
        end
    end
  end

  defp invalid_grant?({400, %{"error" => "invalid_grant"}}), do: true

  defp invalid_grant?({400, body}) when is_binary(body),
    do: String.contains?(body, "invalid_grant")

  defp invalid_grant?(_), do: false

  defp persist_refresh_token(eve_id, refresh_token) when is_binary(refresh_token) do
    case Ztripwire.Accounts.get_character_by_eve_id(eve_id) do
      %{refresh_token: current} = character when current != refresh_token ->
        _ = Ztripwire.Accounts.update_character(character, %{refresh_token: refresh_token})
        :ok

      _ ->
        :ok
    end
  end

  defp persist_refresh_token(_eve_id, _refresh_token), do: :ok

  defp authorized_get(path, character_id, access_token, character) do
    case Client.get(path, subject: character_id, token: access_token) do
      {:error, {401, _}} when not is_nil(character) ->
        TokenCache.delete(character.eve_id)

        with {:ok, token} <- valid_access_token(character) do
          Client.get(path, subject: character_id, token: token)
        end

      other ->
        other
    end
  end

  defp public_get(path, opts \\ []) do
    Client.get(path, Keyword.put(opts, :subject, :public))
  end

  defp public_post(path, body) do
    Client.request(:post, path, subject: :public, json: body)
  end

  defp req(method, url, opts) do
    opts
    |> Keyword.put(:url, url)
    |> Keyword.merge(method: method)
    |> then(&Req.request(&1))
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, exception} -> {:error, exception}
    end
  end

  defp client_id, do: Ztripwire.SSO.client_id()
  defp client_secret, do: Ztripwire.SSO.client_secret()
end
