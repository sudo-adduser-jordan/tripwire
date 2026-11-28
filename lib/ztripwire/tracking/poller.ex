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
      {:ok, solar_system_id} -> apply_change({:ok, solar_system_id}, state)
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
           ESI.get_character_online(character.eve_id, token, character) do
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
         {:ok, %{"solar_system_id" => solar_system_id}} <-
           ESI.get_character_location(character.eve_id, token, character) do
      {:ok, solar_system_id}
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
           ESI.get_character_ship(character.eve_id, token, character) do
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

  defp apply_change({:ok, solar_system_id}, state)
       when solar_system_id == state.last_solar_system_id do
    state
  end

  defp apply_change({:ok, solar_system_id}, state) do
    case Tracking.apply_location_change(
           state.map,
           state.character.name,
           state.last_system_row,
           solar_system_id
         ) do
      {:ok, %{system: system}} ->
        %{
          state
          | last_solar_system_id: solar_system_id,
            last_system_row: system,
            system_name: system.name,
            online: true
        }

      error ->
        Ztripwire.Log.warning(%{
          event: "esi_poll_apply_failed",
          eve_id: state.character.eve_id,
          reason: inspect(error)
        })

        state
    end
  end

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
