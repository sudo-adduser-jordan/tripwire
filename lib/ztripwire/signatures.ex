defmodule Ztripwire.Signatures do
  alias Ztripwire.Signatures.Parsed

  @id_regex ~r/^([A-Za-z]{3}-[0-9]{3})\b/
  @wormhole_code_regex ~r/\b([A-Z][0-9]{3})\b/

  @scan_groups %{
    "cosmic signature" => :signature,
    "cosmic anomaly" => :anomaly,
    "signature cosmique" => :signature,
    "anomalie cosmique" => :anomaly,
    "kosmische signatur" => :signature,
    "kosmische anomalie" => :anomaly,
    "宇宙のシグネチャ" => :signature,
    "宇宙の特異点" => :anomaly,
    "코즈믹 시그니처" => :signature,
    "코즈믹 어노말리" => :anomaly,
    "скрытый сигнал" => :signature,
    "космическая аномалия" => :anomaly
  }

  @site_types %{
    "combat site" => :combat,
    "data site" => :data,
    "gas site" => :gas,
    "ore site" => :ore,
    "relic site" => :relic,
    "wormhole" => :wormhole,
    "site de combat" => :combat,
    "site de données" => :data,
    "site de collecte de gaz" => :gas,
    "site de minerai" => :ore,
    "site de reliques" => :relic,
    "trou de ver" => :wormhole,
    "kampfgebiet" => :combat,
    "datengebiet" => :data,
    "gasgebiet" => :gas,
    "mineraliengebiet" => :ore,
    "reliktgebiet" => :relic,
    "wurmloch" => :wormhole,
    "戦闘サイト" => :combat,
    "データサイト" => :data,
    "ガスサイト" => :gas,
    "鉱石サイト" => :ore,
    "遺物サイト" => :relic,
    "ワームホール" => :wormhole,
    "전투 사이트" => :combat,
    "데이터 사이트" => :data,
    "가스 사이트" => :gas,
    "채광 사이트" => :ore,
    "유물 사이트" => :relic,
    "웜홀" => :wormhole,
    "боевой район" => :combat,
    "информационный район" => :data,
    "газовый район" => :gas,
    "астероидный район" => :ore,
    "археологический район" => :relic,
    "червоточина" => :wormhole
  }

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

  @spec parse_line(String.t()) :: {:ok, Parsed.t()} | :error
  def parse_line(line) when is_binary(line) do
    trimmed = String.trim(line)

    case Regex.run(@id_regex, trimmed) do
      [_full, raw_id] ->
        sig_id = String.upcase(raw_id)

        columns =
          trimmed
          |> columns_after_id(raw_id)
          |> classify_columns()

        name = blank_to_nil(Enum.join(columns.names, " "))
        wormhole_type = extract_wormhole_type(name)

        {:ok,
         %Parsed{
           sig_id: sig_id,
           kind: columns.kind || :signature,
           name: name,
           wormhole_type: wormhole_type,
           category: columns.site_type || infer_category(name, wormhole_type)
         }}

      nil ->
        :error
    end
  end

  def parse_line(_), do: :error

  def life_left(created_at, life_length \\ default_life_length(), now \\ DateTime.utc_now()) do
    created_at
    |> DateTime.add(life_length, :second)
    |> DateTime.diff(now, :second)
    |> max(0)
  end

  def default_life_length, do: 72 * 3600

  def age_seconds(scanned_at, now \\ DateTime.utc_now()) do
    now |> DateTime.diff(scanned_at, :second) |> max(0)
  end

  def life_status(seconds_left) when seconds_left <= 0, do: :expired
  def life_status(seconds_left) when seconds_left < 3600, do: :critical
  def life_status(seconds_left) when seconds_left < 4 * 3600, do: :eol
  def life_status(_seconds_left), do: :stable

  def scan_insert_attrs(entry, now \\ now_naive()) do
    %{
      sig_id: entry.sig_id,
      kind: kind_string(entry.kind),
      type_name: entry.name || entry.wormhole_type,
      site_type: site_type_string(entry.category),
      life_length: default_life_length(),
      expires_at: NaiveDateTime.add(now, default_life_length(), :second)
    }
  end

  def scan_update_attrs(existing, entry, now \\ now_naive()) do
    site_type = site_type_string(entry.category)
    kind = kind_string(entry.kind)
    name = entry.name || entry.wormhole_type
    existing_type = Map.get(existing, :site_type)
    existing_name = Map.get(existing, :type_name)

    cond do
      existing_type == "wormhole" ->
        :skip

      site_type == "wormhole" ->
        %{kind: kind, site_type: "wormhole", type_name: name || existing_name}

      not scan_changed?(existing, name, site_type, kind) ->
        :skip

      true ->
        %{
          kind: kind,
          site_type: if(site_type == "unknown", do: existing_type, else: site_type),
          type_name: name || existing_name,
          life_length: default_life_length(),
          expires_at: NaiveDateTime.add(now, default_life_length(), :second)
        }
    end
  end

  defp scan_changed?(existing, name, site_type, kind) do
    (is_binary(name) and name != (Map.get(existing, :type_name) || "")) or
      (site_type != "unknown" and site_type != Map.get(existing, :site_type)) or
      kind != Map.get(existing, :kind)
  end

  defp kind_string(nil), do: "signature"
  defp kind_string(kind), do: to_string(kind)

  defp site_type_string(nil), do: "unknown"
  defp site_type_string(type), do: to_string(type)

  defp now_naive do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

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

  @spec infer_site_type(String.t() | nil, String.t() | nil) :: String.t()
  def infer_site_type("unknown", name) when is_binary(name) do
    if Regex.match?(@wormhole_code_regex, String.upcase(name)), do: "wormhole", else: "unknown"
  end

  def infer_site_type(type, _name) when is_binary(type) and type != "", do: type
  def infer_site_type(_, _), do: "unknown"

  def default_form do
    %{
      "sig_id" => "",
      "kind" => "signature",
      "site_type" => "unknown",
      "type_name" => "",
      "type_id" => "",
      "life_length" => "259200",
      "scanned_at" => "",
      "bookmark" => ""
    }
  end

  def form_from(signature) do
    %{
      "sig_id" => signature.sig_id || "",
      "kind" => signature.kind || "signature",
      "site_type" => signature.site_type || "unknown",
      "type_name" => signature.type_name || "",
      "type_id" => format_type_id(signature.type_id),
      "life_length" => to_string(signature.life_length || 259_200),
      "scanned_at" => format_scanned_at(signature.inserted_at),
      "bookmark" => signature.bookmark || ""
    }
  end

  def split_id(sig_id) when is_binary(sig_id) do
    case sig_id |> String.trim() |> String.upcase() |> String.split("-", parts: 2) do
      [prefix, number] -> {prefix, number}
      [prefix] -> {prefix, ""}
      _ -> {"", ""}
    end
  end

  def split_id(_), do: {"", ""}

  def join_id(prefix, number) do
    prefix = prefix |> to_string() |> String.trim() |> String.upcase()
    number = number |> to_string() |> String.trim()

    if prefix == "" and number == "", do: "", else: "#{prefix}-#{number}"
  end

  def split_wormhole(nil), do: {"", ""}

  def split_wormhole(type_name) when is_binary(type_name) do
    trimmed = String.trim(type_name)

    case Regex.run(~r/^(.*?)\s*\(([A-Za-z?][0-9?]{3})\)$/, trimmed) do
      [_, name, code] ->
        {String.trim(name), String.upcase(code)}

      nil ->
        if Regex.match?(~r/^[A-Z?][0-9?]{3}$/, String.upcase(trimmed)),
          do: {"", String.upcase(trimmed)},
          else: {trimmed, ""}
    end
  end

  def split_wormhole(_), do: {"", ""}

  def join_wormhole(name, code) do
    name = name |> to_string() |> String.trim()
    code = code |> to_string() |> String.trim() |> String.upcase()

    cond do
      name == "" -> code
      code == "" -> name
      true -> "#{name} (#{code})"
    end
  end

  def length_parts(seconds) when is_integer(seconds) and seconds > 0 do
    {div(seconds, 86_400), div(rem(seconds, 86_400), 3_600), div(rem(seconds, 3_600), 60)}
  end

  def length_parts(_), do: {3, 0, 0}

  def length_seconds(days, hours, minutes) do
    total = count(days) * 86_400 + count(hours) * 3_600 + count(minutes) * 60
    if total > 0, do: total
  end

  defp count(value) do
    case Integer.parse(to_string(value || "")) do
      {n, _} when n > 0 -> n
      _ -> 0
    end
  end

  def signature_life_status(%{expires_at: %NaiveDateTime{} = expires_at}) do
    seconds_left = NaiveDateTime.diff(expires_at, NaiveDateTime.utc_now(), :second)

    case life_status(seconds_left) do
      :stable -> "stable"
      :eol -> "critical"
      _ -> "<1h"
    end
  end

  def signature_life_status(_), do: "stable"

  def expires_at_for(status, length), do: expires_at_for(status, length, now_naive())

  def expires_at_for("critical", _length, _reference), do: in_seconds(4 * 3600)
  def expires_at_for("<1h", _length, _reference), do: in_seconds(3600)

  def expires_at_for(_status, length, reference) when is_integer(length) and length > 0,
    do: NaiveDateTime.add(reference, length, :second)

  def expires_at_for(_status, _, _reference), do: in_seconds(default_life_length())

  defp in_seconds(seconds) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(seconds, :second)
    |> NaiveDateTime.truncate(:second)
  end

  def attrs_from_params(params) do
    type_name = trim_or_nil(params["type_name"])

    %{
      sig_id: params_id(params),
      kind: params["kind"] || "signature",
      site_type: infer_site_type(params["site_type"] || "unknown", type_name),
      type_name: type_name,
      type_id: parse_type_id(params["type_id"]),
      bookmark: trim_or_nil(params["bookmark"]),
      life_length: params_life_length(params)
    }
    |> put_scanned_at(params["scanned_at"])
  end

  defp params_id(params) do
    case params["sig_id"] do
      id when is_binary(id) and id != "" -> id
      _ -> join_id(params["prefix"], params["number"])
    end
  end

  defp params_life_length(params) do
    case params["life_length"] do
      value when value in [nil, ""] ->
        length_seconds(params["days"], params["hours"], params["minutes"]) ||
          default_life_length()

      value ->
        parse_life_length(value)
    end
  end

  def parse_scanned_at(value) when is_binary(value) do
    value = String.trim(value)
    value = if byte_size(value) == 16, do: value <> ":00", else: value

    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> NaiveDateTime.truncate(naive, :second)
      _ -> nil
    end
  end

  def parse_scanned_at(_value), do: nil

  defp put_scanned_at(attrs, value) do
    case parse_scanned_at(value) do
      nil -> attrs
      scanned_at -> Elixir.Map.put(attrs, :inserted_at, scanned_at)
    end
  end

  defp format_type_id(type_id) when is_integer(type_id) and type_id > 0,
    do: Integer.to_string(type_id)

  defp format_type_id(_type_id), do: ""

  defp format_scanned_at(%NaiveDateTime{} = scanned_at) do
    Calendar.strftime(scanned_at, "%Y-%m-%dT%H:%M")
  end

  defp format_scanned_at(_scanned_at), do: ""

  defp parse_type_id(value) when is_integer(value) and value > 0, do: value

  defp parse_type_id(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {type_id, ""} when type_id > 0 -> type_id
      _ -> nil
    end
  end

  defp parse_type_id(_value), do: nil

  defp trim_or_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trim_or_nil(_value), do: nil

  defp parse_life_length(value) when is_integer(value), do: value

  defp parse_life_length(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> default_life_length()
    end
  end

  @spec wormhole_code(String.t() | nil) :: String.t() | nil
  def wormhole_code(name) when is_binary(name) do
    case Regex.run(@wormhole_code_regex, String.upcase(name)) do
      [_, code] -> code
      _ -> nil
    end
  end

  def wormhole_code(_), do: nil

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
    rest = binary_part(trimmed, byte_size(raw_id), byte_size(trimmed) - byte_size(raw_id))

    if String.contains?(rest, "\t") do
      String.split(rest, "\t")
    else
      String.split(rest, ~r/\s{2,}/)
    end
  end

  defp classify_columns(columns) do
    columns
    |> Enum.map(&normalize_column/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&distance?/1)
    |> Enum.reduce(%{kind: nil, site_type: nil, names: []}, fn column, acc ->
      key = String.downcase(column)

      cond do
        kind = Map.get(@scan_groups, key) ->
          %{acc | kind: kind}

        type = Map.get(@site_types, key) ->
          %{acc | site_type: type}

        true ->
          %{acc | names: [column | acc.names]}
      end
    end)
    |> then(fn acc -> %{acc | names: Enum.reverse(acc.names)} end)
  end

  defp normalize_column(value) do
    value
    |> String.trim()
    |> String.replace(~r/^\d+(?:[.,]\d+)?\s*%$/, "")
    |> String.trim()
  end

  defp distance?(column) do
    case Regex.run(~r/^(\d+(?:[.,]\d+)?)\s*(.*)$/, column) do
      [_, _number, unit] -> String.downcase(unit) in ["au", "m", "km", "а.е.", "км", "м"]
      _ -> false
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(name), do: name

  defp extract_wormhole_type(nil), do: nil

  defp extract_wormhole_type(name) do
    case Regex.run(@wormhole_code_regex, String.upcase(name)) do
      [_, code] -> code
      _ -> nil
    end
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
