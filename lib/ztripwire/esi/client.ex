defmodule Ztripwire.ESI.Client do
  use GenServer

  alias Ztripwire.Log

  @cache_table :esi_cache
  @budget_table :esi_budget
  @sweep_interval 60_000
  @default_timeout 15_000
  @error_limit_floor 5
  @quota_window_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(path, opts \\ []) do
    request(:get, path, opts)
  end

  def request(method, path, opts \\ []) do
    subject = Keyword.get(opts, :subject, :public)
    key = {method, path, subject}
    now = now_ms()

    case cached(key, now, opts) do
      {:fresh, body} ->
        {:ok, body}

      {:stale, entry} ->
        perform(method, path, key, entry, opts)

      :miss ->
        perform(method, path, key, nil, opts)
    end
  end

  def clear do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, :clear)
    else
      :ok
    end
  end

  def cached?(method, path, subject) do
    table?(@cache_table) and
      :ets.member(@cache_table, {method, path, subject})
  end

  def expire(method, path, subject) do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, {:expire, {method, path, subject}})
    else
      :ok
    end
  end

  @impl true
  def init(_opts) do
    :ets.new(@cache_table, [
      :named_table,
      :protected,
      :set,
      read_concurrency: true
    ])

    :ets.new(@budget_table, [
      :named_table,
      :protected,
      :set,
      read_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    if table?(@cache_table), do: :ets.delete_all_objects(@cache_table)
    if table?(@budget_table), do: :ets.delete_all_objects(@budget_table)
    {:reply, :ok, state}
  end

  def handle_call({:expire, key}, _from, state) do
    if table?(@cache_table) do
      case :ets.lookup(@cache_table, key) do
        [{^key, entry}] -> :ets.insert(@cache_table, {key, %{entry | expires_at: 0}})
        [] -> :ok
      end
    end

    {:reply, :ok, state}
  end

  def handle_call({:store, key, body, etag, ttl}, _from, state) do
    if table?(@cache_table) do
      :ets.insert(@cache_table, {key, cache_entry(body, etag, ttl)})
    end

    {:reply, :ok, state}
  end

  def handle_call({:refresh, key, entry, etag, ttl}, _from, state) do
    if table?(@cache_table) do
      updated = %{
        entry
        | etag: etag || entry.etag,
          ttl: ttl,
          expires_at: now_ms() + ttl * 1000
      }

      :ets.insert(@cache_table, {key, updated})
    end

    {:reply, :ok, state}
  end

  def handle_call({:record_budget, path, resp}, _from, state) do
    do_record_budget(path, resp)
    {:reply, :ok, state}
  end

  def handle_call({:quota, source, bucket}, _from, state) do
    count =
      if table?(@budget_table) do
        key = {:quota, source, bucket}
        :ets.update_counter(@budget_table, key, 1, {key, 0})
      else
        0
      end

    {:reply, count, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep(now_ms())
    schedule_sweep()
    {:noreply, state}
  end

  defp perform(method, path, key, entry, opts) do
    source = Keyword.get(opts, :source, :interactive)

    with :ok <- budget_allows?(path, source) do
      started = System.monotonic_time(:millisecond)
      response = send_request(method, path, entry, opts)
      duration = System.monotonic_time(:millisecond) - started

      case response do
        {:ok, %{status: 304} = resp} ->
          body = entry && entry.body
          refresh_entry(key, entry, resp)
          log_request(method, path, resp, duration, true, true)
          {:ok, body}

        {:ok, %{status: status} = resp} when status in [200, 201, 204] ->
          body = if status == 204, do: %{}, else: resp.body
          record_budget(path, resp)
          store(key, body, resp)
          log_request(method, path, resp, duration, false, true)
          {:ok, body}

        {:ok, %{status: status} = resp} when status in [429, 420] ->
          record_budget(path, resp)
          log_request(method, path, resp, duration, false, true)
          {:error, {:rate_limited, retry_after(resp)}}

        {:ok, resp} ->
          record_budget(path, resp)
          log_request(method, path, resp, duration, false, true)
          {:error, {resp.status, resp.body}}

        {:error, exception} ->
          Log.emit(:warning, %{
            event: "esi_request_failed",
            method: method,
            path: path,
            duration_ms: duration,
            error: Exception.message(exception)
          })

          {:error, exception}
      end
    end
  end

  defp send_request(method, path, entry, opts) do
    headers =
      [
        {"user-agent", user_agent()},
        {"accept", "application/json"}
      ]
      |> maybe_header("x-compatibility-date", compatibility_date())
      |> maybe_header("authorization", bearer(opts))
      |> maybe_header("if-none-match", entry && entry.etag)
      |> Keyword.merge(Keyword.get(opts, :headers, []))

    options =
      [
        method: method,
        url: base_url() <> path,
        headers: headers,
        receive_timeout: Keyword.get(opts, :timeout, @default_timeout),
        retry: &retry?/2,
        max_retries: 2
      ]
      |> maybe_option(:json, Keyword.get(opts, :json))
      |> maybe_option(:form, Keyword.get(opts, :form))
      |> Keyword.merge(req_options())

    case Req.request(options) do
      {:ok, response} -> {:ok, response}
      {:error, exception} -> {:error, exception}
    end
  rescue
    exception -> {:error, exception}
  end

  defp cached(key, now, opts) do
    if Keyword.get(opts, :cache, cache_enabled?()) do
      cached_entry(key, now, opts)
    else
      :miss
    end
  end

  defp cached_entry(key, now, opts) do
    if table?(@cache_table) do
      case :ets.lookup(@cache_table, key) do
        [{^key, entry}] ->
          if entry.expires_at > now and not Keyword.get(opts, :refresh, false) do
            {:fresh, entry.body}
          else
            {:stale, entry}
          end

        [] ->
          :miss
      end
    else
      :miss
    end
  end

  defp store(key, body, resp) do
    if cache_enabled?() do
      ttl = ttl_seconds(resp, key)

      if ttl > 0 and Process.whereis(__MODULE__) do
        GenServer.call(__MODULE__, {:store, key, body, header(resp, "etag"), ttl})
      end
    end

    :ok
  end

  defp cache_entry(body, etag, ttl) do
    %{body: body, etag: etag, ttl: ttl, expires_at: now_ms() + ttl * 1000}
  end

  defp refresh_entry(_key, nil, _resp), do: :ok

  defp refresh_entry(key, entry, resp) do
    ttl =
      case ttl_seconds(resp, key) do
        0 -> entry.ttl
        value -> value
      end

    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, {:refresh, key, entry, header(resp, "etag"), ttl})
    end

    :ok
  end

  defp ttl_seconds(resp, key) do
    case max_age(resp) do
      nil -> default_ttl(key)
      value -> value
    end
  end

  defp max_age(resp) do
    with [cache_control | _] <- Req.Response.get_header(resp, "cache-control"),
         [_, value] <- Regex.run(~r/max-age=(\d+)/, cache_control) do
      String.to_integer(value)
    else
      _ -> client_ttl(resp)
    end
  end

  defp client_ttl(resp) do
    with [value | _] <- Req.Response.get_header(resp, "x-client-cache-ttl"),
         {ttl, ""} <- Integer.parse(value) do
      ttl
    else
      _ -> nil
    end
  end

  defp default_ttl({_method, path, _subject}) do
    cond do
      String.starts_with?(path, "/universe/systems/") -> 86_400
      String.starts_with?(path, "/universe/types/") -> 86_400
      String.starts_with?(path, "/universe/constellations/") -> 86_400
      String.starts_with?(path, "/universe/regions/") -> 86_400
      true -> 0
    end
  end

  defp budget_allows?(path, source) do
    now = now_ms()

    cond do
      blocked_until({:blocked, :global}) > now ->
        {:error, {:rate_limited, seconds_until(blocked_until({:blocked, :global}), now)}}

      blocked_until({:blocked, {:path, path}}) > now ->
        {:error, {:rate_limited, seconds_until(blocked_until({:blocked, {:path, path}}), now)}}

      true ->
        case group_for(path) do
          nil ->
            with :ok <- error_limit_allows?(now), do: quota_allows?(source, now)

          group ->
            cond do
              blocked_until({:blocked, {:group, group}}) > now ->
                {:error,
                 {:rate_limited, seconds_until(blocked_until({:blocked, {:group, group}}), now)}}

              group_exhausted?(group, now, source) ->
                {:error, {:rate_limited, seconds_until(budget({:group, group}).reset_at, now)}}

              true ->
                with :ok <- error_limit_allows?(now), do: quota_allows?(source, now)
            end
        end
    end
  end

  defp group_exhausted?(group, now, source) do
    case budget({:group, group}) do
      %{remaining: remaining, reset_at: reset_at} = budget when reset_at > now ->
        remaining <= reserved_for(source, budget)

      _ ->
        false
    end
  end

  defp reserved_for(:poller, _budget), do: 0

  defp reserved_for(_source, %{limit: limit}) when is_integer(limit) and limit > 0 do
    round(limit * poller_reserve())
  end

  defp reserved_for(_source, _budget), do: 0

  defp quota_allows?(source, now) do
    quota = quota_for(source)
    bucket = div(now, @quota_window_ms)

    count =
      if Process.whereis(__MODULE__) do
        GenServer.call(__MODULE__, {:quota, source, bucket})
      else
        0
      end

    if count > quota do
      {:error, {:rate_limited, seconds_until((bucket + 1) * @quota_window_ms, now)}}
    else
      :ok
    end
  end

  defp error_limit_allows?(now) do
    case budget({:error_limit}) do
      %{remain: remain, reset_at: reset_at}
      when remain <= @error_limit_floor and reset_at > now ->
        {:error, :error_limit}

      _ ->
        :ok
    end
  end

  defp record_budget(path, resp) do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, {:record_budget, path, resp})
    end

    :ok
  end

  defp do_record_budget(path, resp) do
    group = header(resp, "x-ratelimit-group")

    if group && table?(@budget_table) do
      :ets.insert(@budget_table, {{:path_group, path}, {group, now_ms()}})

      case window_seconds(header(resp, "x-ratelimit-limit")) do
        nil ->
          :ok

        window ->
          remaining = integer_header(resp, "x-ratelimit-remaining") || 0
          limit = integer_header(resp, "x-ratelimit-limit")

          :ets.insert(
            @budget_table,
            {{:group, group},
             %{remaining: remaining, limit: limit, reset_at: now_ms() + window * 1000}}
          )
      end
    end

    remain = integer_header(resp, "x-esi-error-limit-remain")
    reset = integer_header(resp, "x-esi-error-limit-reset")

    if remain && table?(@budget_table) do
      :ets.insert(
        @budget_table,
        {:error_limit, %{remain: remain, reset_at: now_ms() + (reset || 60) * 1000}}
      )
    end

    cond do
      resp.status == 420 ->
        :ets.insert(@budget_table, {{:blocked, :global}, now_ms() + (reset || 60) * 1000})

      resp.status == 429 ->
        retry = integer_header(resp, "retry-after") || 60

        key =
          if group do
            {:blocked, {:group, group}}
          else
            {:blocked, {:path, path}}
          end

        :ets.insert(@budget_table, {key, now_ms() + retry * 1000})

      true ->
        :ok
    end

    :ok
  end

  defp group_for(path) do
    case budget({:path_group, path}) do
      {group, _stored_at} when is_binary(group) -> group
      group when is_binary(group) -> group
      _ -> nil
    end
  end

  defp blocked_until(key) do
    case budget(key) do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  defp budget(key) do
    if table?(@budget_table) do
      case :ets.lookup(@budget_table, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    end
  end

  defp window_seconds(nil), do: nil

  defp window_seconds(limit) do
    case Regex.run(~r{/(\d+)([mh])}, limit) do
      [_, amount, "m"] -> String.to_integer(amount) * 60
      [_, amount, "h"] -> String.to_integer(amount) * 3600
      _ -> nil
    end
  end

  defp retry_after(resp) do
    integer_header(resp, "retry-after") ||
      integer_header(resp, "x-esi-error-limit-reset") ||
      60
  end

  defp seconds_until(deadline, now), do: max(div(deadline - now + 999, 1000), 1)

  defp log_request(method, path, resp, duration, cached, _decode) do
    fields = %{
      event: "esi_request",
      method: String.upcase(to_string(method)),
      path: path,
      status: resp.status,
      duration_ms: duration,
      cached: cached,
      group: header(resp, "x-ratelimit-group"),
      remaining: integer_header(resp, "x-ratelimit-remaining"),
      error_limit_remain: integer_header(resp, "x-esi-error-limit-remain")
    }

    level =
      if resp.status in [401, 403, 420, 429] or resp.status >= 500, do: :warning, else: :info

    Log.emit(level, fields)
  end

  defp header(resp, name) do
    case Req.Response.get_header(resp, name) do
      [value | _] -> value
      _ -> nil
    end
  end

  defp integer_header(resp, name) do
    case header(resp, name) do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {number, _} -> number
          :error -> nil
        end
    end
  end

  defp sweep(now) do
    if table?(@cache_table) do
      :ets.foldl(
        fn {key, entry}, acc ->
          if entry.expires_at <= now - 300_000, do: :ets.delete(@cache_table, key)
          acc
        end,
        :ok,
        @cache_table
      )
    end

    if table?(@budget_table) do
      current_bucket = div(now, @quota_window_ms)

      :ets.foldl(
        fn
          {key = {:quota, _source, bucket}, _value}, acc ->
            if bucket < current_bucket - 1, do: :ets.delete(@budget_table, key)
            acc

          {key = {:path_group, _path}, {_group, stored_at}}, acc ->
            if stored_at <= now - 86_400_000, do: :ets.delete(@budget_table, key)
            acc

          {key, value}, acc ->
            if match?({:blocked, _}, key) and is_integer(value) and value <= now - 300_000 do
              :ets.delete(@budget_table, key)
            end

            acc
        end,
        :ok,
        @budget_table
      )
    end

    :ok
  end

  defp maybe_header(headers, _name, nil), do: headers
  defp maybe_header(headers, _name, ""), do: headers
  defp maybe_header(headers, name, value), do: [{name, value} | headers]

  defp maybe_option(options, _key, nil), do: options
  defp maybe_option(options, key, value), do: Keyword.put(options, key, value)

  defp retry?(_request, %Req.Response{status: status}),
    do: status in [408, 500, 502, 503, 504]

  defp retry?(_request, %Req.TransportError{reason: reason}),
    do: reason in [:timeout, :econnrefused, :closed]

  defp retry?(_request, _error), do: false

  defp bearer(opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) and token != "" -> "Bearer #{token}"
      _ -> nil
    end
  end

  def user_agent do
    :ztripwire
    |> Application.get_env(Ztripwire.ESI, [])
    |> Keyword.get(:user_agent, "Ztripwire/0.1.0 (+https://bitbucket.org/daimian/tripwire)")
  end

  defp compatibility_date do
    :ztripwire
    |> Application.get_env(Ztripwire.ESI, [])
    |> Keyword.get(:compatibility_date)
  end

  defp base_url do
    :ztripwire
    |> Application.get_env(Ztripwire.ESI, [])
    |> Keyword.get(:base_url, "https://esi.evetech.net/latest")
  end

  defp cache_enabled? do
    :ztripwire
    |> Application.get_env(Ztripwire.ESI, [])
    |> Keyword.get(:cache, true)
  end

  defp quota_for(:poller), do: esi_config(:poller_quota, 600)
  defp quota_for(_source), do: esi_config(:interactive_quota, 120)

  defp poller_reserve, do: esi_config(:poller_reserve, 0.1)

  defp esi_config(key, default) do
    :ztripwire
    |> Application.get_env(Ztripwire.ESI, [])
    |> Keyword.get(key, default)
  end

  defp req_options do
    :ztripwire
    |> Application.get_env(Ztripwire.ESI, [])
    |> Keyword.get(:req_options, [])
  end

  defp table?(name), do: :ets.whereis(name) != :undefined

  defp now_ms, do: System.system_time(:millisecond)

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)
end
