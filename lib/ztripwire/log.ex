defmodule Ztripwire.Log do
  @levels [:debug, :info, :warning, :error]

  def new(fields \\ %{}) do
    base = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      service: service_name(),
      node: Node.self() |> Atom.to_string(),
      pid: inspect(self())
    }

    Map.merge(base, normalize(fields))
  end

  def put(event, key, value) when is_map(event) do
    Map.put(event, to_key(key), value)
  end

  def merge(event, fields) when is_map(event) and is_map(fields) do
    Map.merge(event, normalize(fields))
  end

  def debug(event), do: emit(:debug, event)
  def info(event), do: emit(:info, event)
  def warning(event), do: emit(:warning, event)
  def error(event), do: emit(:error, event)

  def emit(level, message) when level in @levels and is_binary(message) do
    emit(level, %{message: message})
  end

  def emit(level, fields) when level in @levels and is_map(fields) do
    event =
      fields
      |> normalize()
      |> Map.put_new(:timestamp, DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.put_new(:service, service_name())
      |> Map.put(:level, Atom.to_string(level))

    if keep?(level, event) do
      append_jsonl(level, event)
    end

    print_pretty(level, event)
    {:ok, event}
  end

  def keep?(level, event) when level in @levels and is_map(event) do
    cond do
      level in [:error, :warning] -> true
      Map.has_key?(event, :error) -> true
      Map.has_key?(event, "error") -> true
      slow?(event) -> true
      true -> :rand.uniform() <= sample_rate()
    end
  end

  defp slow?(event) do
    duration = Map.get(event, :duration_ms, Map.get(event, "duration_ms", 0))

    is_number(duration) and duration > 2_000
  end

  defp append_jsonl(level, event) do
    dir = log_dir(level)
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{Date.utc_today() |> Date.to_iso8601()}.jsonl")
    line = Jason.encode!(event) <> "\n"

    case File.write(path, line, [:append]) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end

  defp print_pretty(level, event) do
    {message, rest} = Map.pop(event, :message, Map.get(event, "message"))
    rest = Map.delete(rest, "message")
    timestamp = Map.get(rest, :timestamp, Map.get(rest, "timestamp", ""))

    rest =
      rest
      |> Map.delete(:timestamp)
      |> Map.delete("timestamp")
      |> Map.delete(:level)
      |> Map.delete("level")
      |> Map.delete(:service)
      |> Map.delete("service")

    line =
      "#{dim(to_string(timestamp))} #{level_label(level)} #{bright(to_string(message))}#{format_fields(rest)}"

    IO.puts(line)
  end

  defp format_fields(fields) when map_size(fields) == 0, do: ""

  defp format_fields(fields) do
    fields
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> " #{key_color(to_string(k))}#{dim("=")}#{value_color(v)}" end)
    |> Enum.join("")
  end

  defp key_color(key), do: IO.ANSI.cyan() <> key <> IO.ANSI.reset()

  defp value_color(nil), do: IO.ANSI.red() <> "nil" <> IO.ANSI.reset()
  defp value_color(true), do: IO.ANSI.magenta() <> "true" <> IO.ANSI.reset()
  defp value_color(false), do: IO.ANSI.magenta() <> "false" <> IO.ANSI.reset()
  defp value_color(v) when is_binary(v), do: IO.ANSI.green() <> inspect(v) <> IO.ANSI.reset()
  defp value_color(v) when is_atom(v), do: IO.ANSI.blue() <> inspect(v) <> IO.ANSI.reset()

  defp value_color(v) when is_integer(v) or is_float(v),
    do: IO.ANSI.yellow() <> to_string(v) <> IO.ANSI.reset()

  defp value_color(v) when is_map(v) or is_list(v),
    do: IO.ANSI.cyan() <> inspect(v, pretty: true, limit: 20) <> IO.ANSI.reset()

  defp value_color(v), do: IO.ANSI.white() <> inspect(v) <> IO.ANSI.reset()

  defp level_label(:debug), do: IO.ANSI.cyan() <> "DEBUG" <> IO.ANSI.reset()
  defp level_label(:info), do: IO.ANSI.green() <> "INFO " <> IO.ANSI.reset()
  defp level_label(:warning), do: IO.ANSI.yellow() <> "WARN " <> IO.ANSI.reset()
  defp level_label(:error), do: IO.ANSI.red() <> "ERROR" <> IO.ANSI.reset()

  defp dim(text), do: IO.ANSI.faint() <> text <> IO.ANSI.reset()
  defp bright(text), do: IO.ANSI.bright() <> text <> IO.ANSI.reset()

  defp log_dir(:error), do: configured_path(:error_path, "logs/errors")
  defp log_dir(:warning), do: configured_path(:error_path, "logs/errors")
  defp log_dir(_), do: configured_path(:test_path, "logs/test")

  defp configured_path(key, default) do
    :ztripwire
    |> Application.get_env(Ztripwire.Log, [])
    |> Keyword.get(key, default)
  end

  defp service_name do
    :ztripwire
    |> Application.get_env(Ztripwire.Log, [])
    |> Keyword.get(:service, "ztripwire")
  end

  defp sample_rate do
    :ztripwire
    |> Application.get_env(Ztripwire.Log, [])
    |> Keyword.get(:sample_rate, 1.0)
  end

  defp normalize(fields) when is_map(fields) do
    Map.new(fields, fn {k, v} -> {to_key(k), v} end)
  end

  defp to_key(k) when is_atom(k), do: k
  defp to_key(k) when is_binary(k), do: k
end
