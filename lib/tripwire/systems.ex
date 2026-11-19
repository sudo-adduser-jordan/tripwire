defmodule Tripwire.Systems do
  @classes ~w(C1 C2 C3 C4 C5 C6 HS LS NS Trig)

  @effects [
    "Black Hole",
    "Cataclysmic Variable",
    "Magnetar",
    "Pulsar",
    "Red Giant",
    "Wolf Rayet"
  ]

  @statics %{
    "C1" => ["HS"],
    "C2" => [],
    "C3" => [],
    "C4" => [],
    "C5" => [],
    "C6" => ["C6"]
  }

  @colors %{
    "C1" => "#4399F0",
    "C2" => "#4399F0",
    "C3" => "#4399F0",
    "C4" => "#A855F7",
    "C5" => "#A855F7",
    "C6" => "#EC4899",
    "HS" => "#50D25A",
    "LS" => "#F5B544",
    "NS" => "#FF4747",
    "Trig" => "#FF4747"
  }

  @unknown_color "#6b7280"

  @badge_colors %{
    "C1" => "#4399F0",
    "C2" => "#4399F0",
    "C3" => "#4399F0",
    "C4" => "#A855F7",
    "C5" => "#A855F7",
    "C6" => "#EC4899",
    "HS" => "#50D25A",
    "LS" => "#F5B544",
    "NS" => "#FF4747",
    "Trig" => "#FF4747",
    "T" => "#FF4747",
    "Thera" => "#FF4747",
    "K" => "#6b7280",
    "W" => "#6b7280"
  }

  def classes, do: @classes

  def effects, do: @effects

  def statics(class) when is_binary(class), do: Map.get(@statics, class, [])
  def statics(_), do: []

  def display_class(%{sys_class: class}) when is_binary(class) and class != "", do: class
  def display_class(%{security: security}) when is_number(security) and security >= 0.45, do: "HS"
  def display_class(%{security: security}) when is_number(security) and security > 0.0, do: "LS"
  def display_class(%{security: security}) when is_number(security), do: "NS"
  def display_class(_), do: nil

  def color(system), do: Map.get(@colors, display_class(system), @unknown_color)

  def badge_color(label) when is_binary(label), do: Map.get(@badge_colors, label, @unknown_color)
  def badge_color(_), do: @unknown_color

  def badge_text_color(label) when label in ["HS", "LS"], do: "#111111"
  def badge_text_color(_), do: "#ffffff"

  def security_label(%{security: security}) when is_number(security) and security >= 0.45,
    do: "High-Sec"

  def security_label(%{security: security}) when is_number(security) and security > 0.0,
    do: "Low-Sec"

  def security_label(%{security: security}) when is_number(security), do: "Null-Sec"
  def security_label(_), do: "W-Space"

  def format_security(%{security: security}) when is_number(security),
    do: :erlang.float_to_binary(security * 1.0, decimals: 1)

  def format_security(_), do: ""

  def esi_resolvable?(%{solar_system_id: id}) when is_integer(id), do: id < 31_000_000
  def esi_resolvable?(_), do: false

  def external_links(%{name: name, solar_system_id: solar_id} = system) do
    dotlan_name = name |> to_string() |> String.replace(" ", "_")

    base = [
      %{label: "Dotlan", url: "https://evemaps.dotlan.net/system/#{dotlan_name}"},
      %{label: "zKill", url: "https://zkillboard.com/system/#{solar_id}/"}
    ]

    if esi_resolvable?(system) do
      base
    else
      base ++ [%{label: "Anoik.is", url: "https://anoik.is/systems/#{dotlan_name}"}]
    end
  end

  def external_links(_), do: []

  def fetch_info(%{solar_system_id: solar_id} = system) do
    if esi_resolvable?(system) do
      fetch_info(solar_id)
    else
      {:error, :wormhole}
    end
  end

  def fetch_info(solar_id) when is_integer(solar_id) do
    with {:ok, %{"constellation_id" => constellation_id} = sys} <-
           Tripwire.ESI.get_system(solar_id),
         {:ok, %{"name" => constellation_name, "region_id" => region_id}} <-
           Tripwire.ESI.get_constellation(constellation_id),
         {:ok, %{"name" => region_name}} <- Tripwire.ESI.get_region(region_id) do
      {:ok,
       %{
         constellation: constellation_name,
         region: region_name,
         security: sys["security_status"],
         sovereignty: sovereignty_holder(solar_id)
       }}
    end
  end

  defp sovereignty_holder(solar_id) do
    case sovereignty_for(solar_id) do
      %{alliance_id: alliance_id} ->
        %{kind: :alliance, id: alliance_id, name: alliance_name(alliance_id)}

      %{faction_id: faction_id} ->
        %{kind: :faction, id: faction_id, name: Tripwire.EveImages.faction_name(faction_id)}

      _ ->
        nil
    end
  end

  defp alliance_name(alliance_id) do
    case Tripwire.ESI.get_alliance(alliance_id) do
      {:ok, %{"name" => name}} -> name
      _ -> "Alliance #{alliance_id}"
    end
  end

  defp sovereignty_for(solar_id) do
    case Tripwire.ESI.get_sovereignty_map() do
      {:ok, rows} when is_list(rows) ->
        case Enum.find(rows, &(&1["solar_system_id"] == solar_id)) do
          %{"alliance_id" => alliance_id} when not is_nil(alliance_id) ->
            %{alliance_id: alliance_id}

          %{"faction_id" => faction_id} when not is_nil(faction_id) ->
            %{faction_id: faction_id}

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def attrs_from_esi(%{"name" => name} = body) do
    %{name: name, security: body["security_status"]}
  end

  def attrs_from_esi(_), do: %{name: nil, security: nil}
end
