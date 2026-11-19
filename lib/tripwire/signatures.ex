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

  @doc """
  Returns how long ago a signature was scanned, in seconds.

      iex> scanned = ~U[2026-01-01 00:00:00Z]
      iex> now = DateTime.add(scanned, 90, :second)
      iex> Tripwire.Signatures.age_seconds(scanned, now)
      90
  """
  def age_seconds(scanned_at, now \\ DateTime.utc_now()) do
    now |> DateTime.diff(scanned_at, :second) |> max(0)
  end

  @doc """
  Life state of a signature from its remaining lifetime, matching the labels
  official Tripwire shows for a wormhole.

      iex> Tripwire.Signatures.life_status(5 * 3600)
      :stable
      iex> Tripwire.Signatures.life_status(2 * 3600)
      :eol
      iex> Tripwire.Signatures.life_status(600)
      :critical
      iex> Tripwire.Signatures.life_status(0)
      :expired
  """
  def life_status(seconds_left) when seconds_left <= 0, do: :expired
  def life_status(seconds_left) when seconds_left < 3600, do: :critical
  def life_status(seconds_left) when seconds_left < 4 * 3600, do: :eol
  def life_status(_seconds_left), do: :stable

  @known_sites [
    "Average Frontier Deposit",
    "Barren Perimeter Reservoir",
    "Bountiful Frontier Reservoir",
    "Common Perimeter Deposit",
    "Core Bastion",
    "Core Citadel",
    "Core Garrison",
    "Core Stronghold",
    "Exceptional Core Deposit",
    "Forgotten Core Assembly Hall",
    "Forgotten Core Circuitry Disassembler",
    "Forgotten Core Data Field",
    "Forgotten Core Information Pen",
    "Forgotten Frontier Conversion Module",
    "Forgotten Frontier Evacuation Center",
    "Forgotten Frontier Quarantine Outpost",
    "Forgotten Frontier Recursive Depot",
    "Forgotten Perimeter Coronation Platform",
    "Forgotten Perimeter Gateway",
    "Forgotten Perimeter Habitation Coils",
    "Forgotten Perimeter Power Array",
    "Fortification Frontier Stronghold",
    "Frontier Barracks",
    "Frontier Command Post",
    "Infrequent Core Deposit",
    "Instrumental Core Reservoir",
    "Integrated Terminus",
    "Isolated Core Deposit",
    "Minor Perimeter Reservoir",
    "Ordinary Perimeter Reservoir",
    "Ordinary Permiter Deposit",
    "Oruze Osobnyk",
    "Outpost Frontier Stronghold",
    "Perimeter Ambush Point",
    "Perimeter Camp",
    "Perimeter Checkpoint",
    "Perimeter Hangar",
    "Phase Catalyst Node",
    "Quarantine Area",
    "Rarified Core Deposit",
    "Sizeable Perimeter Reservoir",
    "Sleeper Data Sanctuary",
    "Sleeper Information Sanctum",
    "Solar Cell",
    "Strange Energy Readings",
    "The Line",
    "The Mirror",
    "The Oruze Construct",
    "The Ruins of Enclave Cohort 27",
    "Token Perimeter Reservoir",
    "Uncommon Core Deposit",
    "Unexceptional Frontier Deposit",
    "Unsecured Core Backup Array",
    "Unsecured Core Emergence",
    "Unsecured Frontier Database",
    "Unsecured Frontier Digital Nexus",
    "Unsecured Frontier Enclave Relay",
    "Unsecured Frontier Receiver",
    "Unsecured Frontier Server Bank",
    "Unsecured Frontier Trinary Hub",
    "Unsecured Perimeter Amplifier",
    "Unsecured Perimeter Comms Relay",
    "Unsecured Perimeter Information Center",
    "Unsecured Perimeter Transponder Farm",
    "Unusual Core Deposit",
    "Vast Frontier Reservoir",
    "Vital Core Reservoir"
  ]

  @known_site_set MapSet.new(@known_sites)

  @doc """
  Infers a concrete site type when the user names a wormhole but leaves
  the type on "unknown", so a scanned signature is never shown as unscanned.
  """
  @spec infer_site_type(String.t() | nil, String.t() | nil) :: String.t()
  def infer_site_type("unknown", name) when is_binary(name) do
    if Regex.match?(@wormhole_code_regex, String.upcase(name)), do: "wormhole", else: "unknown"
  end

  def infer_site_type(type, _name) when is_binary(type) and type != "", do: type
  def infer_site_type(_, _), do: "unknown"

  @doc """
  Extracts a wormhole type code (`"B274"`) from a type name such as
  `"Unstable Wormhole (B274)"`, or `nil` when none is present.
  """
  @spec wormhole_code(String.t() | nil) :: String.t() | nil
  def wormhole_code(name) when is_binary(name) do
    case Regex.run(@wormhole_code_regex, String.upcase(name)) do
      [_, code] -> code
      _ -> nil
    end
  end

  def wormhole_code(_), do: nil

  @doc """
  Returns the eve-survival guide URL for a known site name, matching
  official Tripwire. Any other named site falls back to the EVE
  University wiki. Blank names have no external guide.
  """
  @spec external_link(String.t() | nil) :: String.t() | nil
  def external_link(name) when is_binary(name) and name != "" do
    if MapSet.member?(@known_site_set, name) do
      "https://eve-survival.org/wikka.php?wakka=" <> String.replace(name, " ", "")
    else
      "https://wiki.eveuniversity.org/" <> wiki_title(name)
    end
  end

  def external_link(_), do: nil

  defp wiki_title(name) do
    name
    |> String.replace(" ", "_")
    |> URI.encode(&URI.char_unreserved?/1)
  end

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
