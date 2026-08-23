defmodule Tripwire.Signatures do
  @moduledoc """
  Parses EVE Online probe-scan results pasted from the scanning window.

  Each line is expected to start with a signature ID (`XXX-123`), optionally
  followed by tab-separated columns such as scan group, site type/name,
  signal strength and distance. Lines without a valid signature ID are skipped.

      iex> Tripwire.Signatures.parse_paste("ABC-123\\tCosmic Signature\\t\\tSerpentis Frigate Den")
      [
        %Tripwire.Signatures.Parsed{
          sig_id: "ABC-123",
          kind: :signature,
          name: "Serpentis Frigate Den",
          wormhole_type: nil,
          category: :combat
        }
      ]
  """

  alias Tripwire.Signatures.Parsed

  @id_regex ~r/^([A-Za-z]{3}-[0-9]{3})\b/
  @wormhole_code_regex ~r/\b([A-Z][0-9]{3})\b/

  @anomaly_label "cosmic anomaly"

  @doc """
  Parses an entire paste buffer, returning one entry per parsable line.
  """
  @spec parse_paste(String.t()) :: [Parsed.t()]
  def parse_paste(text) when is_binary(text) do
    text
    |> String.split(["\r\n", "\n", "\r"])
    |> Enum.reduce([], fn line, acc ->
      case parse_line(line) do
        {:ok, parsed} -> [parsed | acc]
        :error -> acc
      end
    end)
    |> Enum.reverse()
  end

  def parse_paste(_), do: []

  @doc """
  Parses a single scan-result line.

      iex> Tripwire.Signatures.parse_line("ghi-789\\tCosmic Anomaly\\tForsaken Hub")
      {:ok, %Tripwire.Signatures.Parsed{sig_id: "GHI-789", kind: :anomaly, name: "Forsaken Hub",
        wormhole_type: nil, category: :combat}}

      iex> Tripwire.Signatures.parse_line("no signature here")
      :error
  """
  @spec parse_line(String.t()) :: {:ok, Parsed.t()} | :error
  def parse_line(line) when is_binary(line) do
    case Regex.run(@id_regex, String.trim(line)) do
      [_full, raw_id] ->
        sig_id = String.upcase(raw_id)

        {group_label, raw_name} =
          String.trim(line)
          |> columns_after_id(raw_id)
          |> split_group_and_name()

        name = blank_to_nil(raw_name)
        wormhole_type = extract_wormhole_type(name)

        {:ok,
         %Parsed{
           sig_id: sig_id,
           kind: infer_kind(group_label),
           name: name,
           wormhole_type: wormhole_type,
           category: infer_category(name, wormhole_type)
         }}

      nil ->
        :error
    end
  end

  def parse_line(_), do: :error

  @doc """
  Remaining lifetime of a signature given its creation time and total life length.

      iex> created = ~U[2026-01-01 00:00:00Z]
      iex> now = DateTime.add(created, 3600, :second)
      iex> Tripwire.Signatures.life_left(created, 72 * 3600, now)
      255600
  """
  def life_left(created_at, life_length \\ default_life_length(), now \\ DateTime.utc_now()) do
    created_at
    |> DateTime.add(life_length, :second)
    |> DateTime.diff(now, :second)
    |> max(0)
  end

  def default_life_length, do: 72 * 3600

  defp columns_after_id(trimmed, raw_id) do
    rest =
      binary_part(trimmed, String.length(raw_id), String.length(trimmed) - String.length(raw_id))

    if String.contains?(rest, "\t") do
      String.split(rest, "\t")
    else
      String.split(rest, ~r/\s{2,}/)
    end
  end

  defp split_group_and_name(columns) do
    columns =
      columns
      |> Enum.map(&(String.trim(&1) |> strip_percent()))
      |> Enum.reject(&(&1 == ""))
      |> Enum.reject(&distance?/1)

    {group_label, name_columns} =
      case columns do
        [first | rest] ->
          if scan_group?(first), do: {first, rest}, else: {"", columns}

        [] ->
          {"", []}
      end

    {group_label, Enum.join(name_columns, " ") |> String.trim()}
  end

  defp scan_group?(column), do: String.downcase(column) =~ "cosmic"

  defp distance?(column), do: Regex.match?(~r/^\d+(\.\d+)?\s*(AU|au|m|km)$/i, column)

  defp strip_percent(value), do: String.replace(value, ~r/^\d+(\.\d+)?%$/, "")

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(name), do: name

  defp extract_wormhole_type(nil), do: nil

  defp extract_wormhole_type(name) do
    case Regex.run(@wormhole_code_regex, String.upcase(name)) do
      [_, code] -> code
      _ -> nil
    end
  end

  defp infer_kind(group_label) do
    if String.downcase(group_label) == @anomaly_label, do: :anomaly, else: :signature
  end

  defp infer_category(_, type) when is_binary(type), do: :wormhole

  defp infer_category(nil, _), do: :unknown

  defp infer_category(name, _) do
    lowered = String.downcase(name)

    cond do
      lowered =~ "wormhole" -> :wormhole
      lowered =~ "relic" -> :relic
      lowered =~ "data" -> :data
      lowered =~ "gas" or lowered =~ "withdrawal" or lowered =~ "reservoir" -> :gas
      lowered =~ "ore" or lowered =~ "mining" -> :ore
      true -> :combat
    end
  end
end
