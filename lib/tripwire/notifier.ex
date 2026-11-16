defmodule Tripwire.Notifier do
  require Logger

  def ping(system_name, message, opts \\ []) do
    webhook = webhook_url()

    if webhook in [nil, ""] do
      {:error, :no_webhook}
    else
      mention = if Keyword.get(opts, :everyone, false), do: "@here ", else: ""

      payload = %{
        "content" =>
          "#{mention}#{system_name}: #{message} https://tripwire.eve-apps.com/?system=#{URI.encode_www_form(system_name)}",
        "allowed_mentions" => %{"parse" => if(mention == "", do: [], else: ["here"])}
      }

      case Req.post(webhook, json: payload) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status, body: body}} ->
          {:error, {status, body}}

        {:error, reason} ->
          Logger.warning("Discord ping failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp webhook_url,
    do: System.get_env("DISCORD_WEB_HOOK", Application.get_env(:tripwire, :discord_webhook, ""))
end
