defmodule Tripwire.ESI do
  alias Tripwire.ESI.TokenCache

  @login_base "https://login.eveonline.com/v2/oauth"
  @esi_base "https://esi.evetech.net/latest"

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

  def get_corporation(corporation_id), do: public_get("/corporations/#{corporation_id}/")

  def get_alliance(alliance_id), do: public_get("/alliances/#{alliance_id}/")

  def get_character_roles(character_id, access_token),
    do: authorized_get("/characters/#{character_id}/roles/", access_token)

  def get_character_titles(character_id, access_token) do
    case authorized_get("/characters/#{character_id}/titles/", access_token) do
      {:ok, titles} when is_list(titles) -> {:ok, Enum.map(titles, & &1["name"])}
      other -> other
    end
  end

  def get_character_ship(character_id, access_token),
    do: authorized_get("/characters/#{character_id}/ship/", access_token)

  def set_waypoint(solar_system_id, access_token, opts \\ []) do
    clear = Keyword.get(opts, :clear, true)
    first = Keyword.get(opts, :first, false)
    query = "?add_to_beginning=#{first}&clear_other_waypoints=#{clear}"
    authorized_post("/ui/autopilot/waypoint/#{query}", solar_system_id, access_token)
  end

  def open_window(target_id, access_token) do
    authorized_post("/ui/openwindow/information/?target_id=#{target_id}", %{}, access_token)
  end

  def search_structures(query, access_token, opts \\ []) do
    categories = Keyword.get(opts, :categories, "structure")

    authorized_get(
      "/search/?categories=#{categories}&search=#{URI.encode_www_form(query)}",
      access_token
    )
  end

  def get_system_jumps, do: public_get("/universe/system_jumps/")

  def get_system_kills, do: public_get("/universe/system_kills/")

  def get_status, do: public_get("/status/")

  def get_system(system_id), do: public_get("/universe/systems/#{system_id}/")

  def get_type(type_id), do: public_get("/universe/types/#{type_id}/")

  def get_constellation(constellation_id),
    do: public_get("/universe/constellations/#{constellation_id}/")

  def get_region(region_id), do: public_get("/universe/regions/#{region_id}/")

  def get_sovereignty_map, do: public_get("/universe/sovereignty/map/")

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
    end
  end

  defp persist_refresh_token(eve_id, refresh_token) when is_binary(refresh_token) do
    case Tripwire.Accounts.get_character_by_eve_id(eve_id) do
      %{refresh_token: current} = character when current != refresh_token ->
        _ = Tripwire.Accounts.update_character(character, %{refresh_token: refresh_token})
        :ok

      _ ->
        :ok
    end
  end

  defp persist_refresh_token(_eve_id, _refresh_token), do: :ok

  defp authorized_get(path, access_token) do
    case req(:get, @esi_base <> path, headers: [{"authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200} = response} -> {:ok, response.body}
      {:ok, %{status: 201} = response} -> {:ok, response.body}
      {:ok, %{status: 204}} -> {:ok, %{}}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  defp authorized_post(path, body, access_token) do
    case req(:post, @esi_base <> path,
           headers: [{"authorization", "Bearer #{access_token}"}],
           json: body
         ) do
      {:ok, %{status: status} = response} when status in [200, 201, 204] -> {:ok, response.body}
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

  defp public_post(path, body) do
    case req(:post, @esi_base <> path, json: body) do
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

  defp client_id, do: Tripwire.SSO.client_id()
  defp client_secret, do: Tripwire.SSO.client_secret()
end
