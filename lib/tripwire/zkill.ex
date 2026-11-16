defmodule Tripwire.ZKill do
  @moduledoc """
  Read-only zKillboard API client used for kill history behind the system
  activity graph. ESI only publishes the current hour's jumps/kills, so
  ship/pod kill history over 24h/48h/week comes from recent killmails.
  """

  @api "https://zkillboard.com/api"
  @user_agent "Tripwire/1.0 (system activity graph)"
  @capsule_type_id 670
  @page_size 200

  @doc """
  Returns `{:ok, kills}` where each kill is `%{time: DateTime, pod: boolean}`.
  Fetches up to `max_pages` result pages (200 killmails each, newest first),
  stopping early once killmails are older than `since` (a DateTime) or the
  last page is reached. Partial results are returned when the API rate
  limits or fails mid-way; `{:error, reason}` only when nothing was fetched.
  """
  def kill_history(solar_system_id, opts \\ []) do
    since = Keyword.get(opts, :since, nil)
    max_pages = Keyword.get(opts, :max_pages, 3)
    fetch_pages(solar_system_id, 1, max_pages, since, [])
  end

  @doc """
  Buckets kills into `count` slots of `width_hours` hours ending at `now`.
  Slot 0 is the oldest, slot `count - 1` covers `[now - width, now]`.
  Returns `{ship_kills, pod_kills}` count lists. Capsule victims count as
  pod kills only (matching ESI semantics); everything else is a ship kill.
  """
  def bucket(kills, now, count, width_hours) do
    width_s = width_hours * 3600
    slots = List.duplicate(0, count)

    {ships, pods} =
      Enum.reduce(kills, {slots, slots}, fn %{time: time, pod: pod}, {ship_acc, pod_acc} ->
        age_s = DateTime.diff(now, time)

        if age_s >= 0 do
          # Slot index from the right: last slot holds the newest window.
          idx = count - 1 - div(age_s, width_s)

          if idx >= 0 and idx < count do
            if pod do
              {ship_acc, List.update_at(pod_acc, idx, &(&1 + 1))}
            else
              {List.update_at(ship_acc, idx, &(&1 + 1)), pod_acc}
            end
          else
            {ship_acc, pod_acc}
          end
        else
          {ship_acc, pod_acc}
        end
      end)

    {ships, pods}
  end

  defp fetch_pages(_id, page, max_pages, _since, acc) when page > max_pages, do: {:ok, acc}

  defp fetch_pages(id, page, max_pages, since, acc) do
    case get("/kills/solarSystemID/#{id}/page/#{page}/") do
      {:ok, body} when is_list(body) ->
        kills = body |> Enum.map(&parse_kill/1) |> Enum.reject(&is_nil/1)
        acc = acc ++ kills

        cond do
          length(body) < @page_size -> {:ok, acc}
          since && past_since?(kills, since) -> {:ok, acc}
          true -> fetch_pages(id, page + 1, max_pages, since, acc)
        end

      {:ok, _} ->
        done(acc)

      {:error, _} ->
        done(acc)
    end
  end

  defp done([]), do: {:error, :unavailable}
  defp done(acc), do: {:ok, acc}

  defp past_since?(kills, since) do
    Enum.any?(kills, fn %{time: time} -> DateTime.compare(time, since) == :lt end)
  end

  defp parse_kill(%{"killmail_time" => time, "victim" => %{"ship_type_id" => ship_id}}) do
    case DateTime.from_iso8601(time) do
      {:ok, dt, _} -> %{time: dt, pod: ship_id == @capsule_type_id}
      _ -> nil
    end
  end

  defp parse_kill(_), do: nil

  defp get(path) do
    case Req.get(@api <> path,
           headers: [{"user-agent", @user_agent}, {"accept", "application/json"}],
           receive_timeout: 10_000
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, status}
      {:error, reason} -> {:error, reason}
    end
  end
end
