defmodule Ztripwire.Tracking.Poller do
  use GenServer

  alias Ztripwire.{ESI, Mapping, Tracking}
  alias Ztripwire.Tracking.Presence

  @default_interval 10_000
  @default_online_interval 60_000
  @default_idle_interval 300_000
  @default_jitter 2_000

  def start_link(opts) do
    character = Keyword.fetch!(opts, :character)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {Ztripwire.TrackingRegistry, character.eve_id}}
    )
  end

  @impl true
  def init(opts) do
    character = Keyword.fetch!(opts, :character)

    map =
      Keyword.get_lazy(opts, :map, fn ->
        {:ok, mask} = Ztripwire.Masks.ensure_personal_mask(character)

        case Mapping.list_maps_for_mask(mask.id) do
          [] -> elem(Mapping.create_map(%{name: "Home", mask_id: mask.id}), 1)
          [map | _] -> map
        end
      end)

    state = %{
      character: character,
      map: map,
      interval: Keyword.get(opts, :interval, @default_interval),
      online_interval: Keyword.get(opts, :online_interval, @default_online_interval),
      idle_interval: Keyword.get(opts, :idle_interval, @default_idle_interval),
      jitter: Keyword.get(opts, :jitter, @default_jitter),
      online: nil,
      ship_name: nil,
      ship_type_id: nil,
      ship_type_name: nil,
      last_solar_system_id: nil,
      last_system_row: nil,
      last_rows: %{},
      system_name: nil,
      last_online_ms: 0,
      reauth?: false,
      cooldown_until: 0
    }

    publish(state)
    schedule_tick(state)

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    viewers = Presence.viewers(state.character.eve_id)

    state =
      state
      |> maybe_check_online(viewers)
      |> maybe_follow(viewers)
      |> publish()

    schedule_tick(state)

    {:noreply, state}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:update_character, character}, _from, state) do
    {:reply, :ok, %{state | character: character, reauth?: false, last_online_ms: 0}}
  end

  @impl true
  def terminate(_reason, state) do
    Presence.delete(state.character.eve_id)
    :ok
  end

  defp maybe_check_online(state, viewers) do
    now = now_ms()
    interval = if viewers > 0, do: state.online_interval, else: state.idle_interval

    if state.online == nil or now - state.last_online_ms >= interval do
      case fetch_online(state.character) do
        {:ok, online} ->
          %{state | online: online, last_online_ms: now, reauth?: false}

        :untracked ->
          %{state | online: false, last_online_ms: now, reauth?: true}

        :reauth ->
          %{state | online: false, last_online_ms: now, reauth?: true}

        {:rate_limited, seconds} ->
          %{state | last_online_ms: now, cooldown_until: now + seconds * 1000}

        :error ->
          %{state | last_online_ms: now}
      end
    else
      state
    end
  end

  defp maybe_follow(state, viewers) do
    cond do
      viewers == 0 -> state
      state.online != true -> state
      state.reauth? -> state
      true -> state |> follow_location() |> follow_ship()
    end
  end

  defp follow_location(state) do
    case fetch_location(state.character) do
      {:ok, location} -> apply_change({:ok, location}, state)
      :reauth -> %{state | reauth?: true}
      :offline -> %{state | online: false, last_online_ms: 0}
      {:rate_limited, seconds} -> cooldown(state, seconds)
      _ -> state
    end
  end

  defp follow_ship(state) do
    case fetch_ship(state.character) do
      {ship_name, type_id} when is_integer(type_id) ->
        if type_id == state.ship_type_id do
          %{state | ship_name: ship_name || state.ship_name}
        else
          %{
            state
            | ship_name: ship_name || state.ship_name,
              ship_type_id: type_id,
              ship_type_name: Ztripwire.Sde.type_name(type_id) || state.ship_type_name
          }
        end

      _ ->
        state
    end
  end

  defp cooldown(state, seconds) do
    %{state | cooldown_until: now_ms() + seconds * 1000}
  end

  defp fetch_online(character) do
    with {:ok, token} <- ESI.valid_access_token(character),
         {:ok, %{"online" => online}} <-
           ESI.get_character_online(character.eve_id, token, character, source: :poller) do
      {:ok, online}
    else
      {:error, :no_refresh_token} -> :untracked
      {:error, :reauth_required} -> :reauth
      {:error, {:rate_limited, seconds}} -> {:rate_limited, seconds}
      {:error, reason} -> log_failure(:online, character, reason)
    end
  end

  defp fetch_location(character) do
    with {:ok, token} <- ESI.valid_access_token(character),
         {:ok, %{"solar_system_id" => _} = location} <-
           ESI.get_character_location(character.eve_id, token, character, source: :poller) do
      {:ok, location}
    else
      {:error, :no_refresh_token} -> :untracked
      {:error, :reauth_required} -> :reauth
      {:error, {:rate_limited, seconds}} -> {:rate_limited, seconds}
      {:error, {404, _}} -> :offline
      {:error, reason} -> log_failure(:location, character, reason)
    end
  end

  defp fetch_ship(character) do
    with {:ok, token} <- ESI.valid_access_token(character),
         {:ok, %{"ship_type_id" => type_id} = ship} <-
           ESI.get_character_ship(character.eve_id, token, character, source: :poller) do
      {ship["ship_name"], type_id}
    else
      {:error, :no_refresh_token} -> nil
      {:error, :reauth_required} -> nil
      {:error, {:rate_limited, _seconds}} -> nil
      {:error, {404, _}} -> nil
      {:error, reason} -> log_failure(:ship, character, reason)
    end
  end

  defp log_failure(resource, character, reason) do
    Ztripwire.Log.warning(%{
      event: "esi_poll_failed",
      resource: resource,
      eve_id: character.eve_id,
      reason: inspect(reason)
    })

    :error
  end

  defp apply_change({:ok, %{"solar_system_id" => solar_system_id}}, state)
       when solar_system_id == state.last_solar_system_id do
    state
  end

  defp apply_change({:ok, location}, state) do
    solar_system_id = location["solar_system_id"]
    docked? = not is_nil(location["station_id"] || location["structure_id"])

    {state, first_system} =
      state
      |> target_maps()
      |> Enum.reduce({state, nil}, fn map, {state, first_system} ->
        prev = previous_row(state, map)

        cond do
          prev == nil and not wspace?(solar_system_id) ->
            {put_last_row(state, map, Mapping.get_system_by_solar(map.mask_id, solar_system_id)),
             first_system}

          prev == nil ->
            apply_to_map(state, map, nil, solar_system_id, first_system, docked?)

          Tracking.automap_allowed?(map, prev, solar_system_id,
            character: state.character,
            docked: docked?,
            ship_type_id: state.ship_type_id
          ) ->
            apply_to_map(state, map, prev, solar_system_id, first_system, docked?)

          true ->
            {put_last_row(state, map, Mapping.get_system_by_solar(map.mask_id, solar_system_id)),
             first_system}
        end
      end)

    %{
      state
      | last_solar_system_id: solar_system_id,
        last_system_row: first_system || state.last_system_row,
        system_name: system_name(first_system, solar_system_id),
        online: true
    }
  end

  defp apply_to_map(state, map, prev, solar_system_id, first_system, _docked?) do
    case Tracking.apply_location_change(
           map,
           state.character.name,
           prev,
           solar_system_id,
           record_stats: first_system == nil
         ) do
      {:ok, %{system: system}} ->
        {put_last_row(state, map, system), first_system || system}

      error ->
        Ztripwire.Log.warning(%{
          event: "esi_poll_apply_failed",
          eve_id: state.character.eve_id,
          reason: inspect(error)
        })

        {state, first_system}
    end
  end

  defp target_maps(state) do
    maps =
      state.character.eve_id
      |> Tracking.targets()
      |> Enum.map(fn target -> Mapping.get_map(target[:map_id] || target["map_id"]) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)

    case maps do
      [] -> List.wrap(state.map)
      maps -> maps
    end
  end

  defp previous_row(state, map) do
    Map.get(state.last_rows, map.id) ||
      (state.last_solar_system_id &&
         Mapping.get_system_by_solar(map.mask_id, state.last_solar_system_id))
  end

  defp put_last_row(state, map, row) do
    %{state | last_rows: Map.put(state.last_rows, map.id, row)}
  end

  defp system_name(nil, solar_system_id), do: Tracking.system_name(solar_system_id)
  defp system_name(%{name: name}, _solar_system_id), do: name

  defp wspace?(id) when is_integer(id), do: id >= 31_000_000
  defp wspace?(_), do: false

  defp publish(state) do
    character = state.character

    Presence.put(character.eve_id, %{
      name: character.name,
      corporation_id: character.corporation_id,
      alliance_id: character.alliance_id,
      character_on_chain: Map.get(character, :character_on_chain, true),
      ship_on_chain: Map.get(character, :ship_on_chain, true),
      online: state.online,
      solar_system_id: state.last_solar_system_id,
      system_name: state.system_name,
      ship_name: state.ship_name,
      ship_type_id: state.ship_type_id,
      ship_type_name: state.ship_type_name
    })

    state
  end

  defp schedule_tick(state) do
    now = now_ms()

    delay =
      cond do
        state.cooldown_until > now -> state.cooldown_until - now
        state.reauth? -> state.idle_interval
        true -> state.interval
      end

    Process.send_after(self(), :tick, delay + jitter(state.jitter))
  end

  defp jitter(0), do: 0
  defp jitter(max) when max > 0, do: :rand.uniform(max)

  defp now_ms, do: System.system_time(:millisecond)
end
