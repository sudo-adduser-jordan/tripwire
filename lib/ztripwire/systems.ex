defmodule Ztripwire.Systems do
  alias Ztripwire.WormholeSystems

  @classes ~w(C1 C2 C3 C4 C5 C6 C13 Thera Drifter HS LS NS Trig)

  @w_space_min 31_000_000
  @w_space_max 35_000_000

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
    "C13" => "#6b7280",
    "Drifter" => "#8B5CF6",
    "HS" => "#50D25A",
    "LS" => "#F5B544",
    "NS" => "#FF4747",
    "Trig" => "#FF4747",
    "T" => "#FF4747",
    "Thera" => "#FF4747",
    "K" => "#6b7280",
    "W" => "#6b7280"
  }

  @unknown_color "#6b7280"

  @effect_colors %{
    "Black Hole" => "#f0f0f0",
    "Cataclysmic Variable" => "#ffffbb",
    "Magnetar" => "#e06fdf",
    "Pulsar" => "#428bca",
    "Red Giant" => "#ff0000",
    "Wolf Rayet" => "#e28a0d"
  }

  def classes, do: @classes

  def effects, do: @effects

  def effect_color("Wolf-Rayet Star"), do: effect_color("Wolf Rayet")
  def effect_color(effect), do: Map.get(@effect_colors, effect)

  def statics(class) when is_binary(class), do: Map.get(@statics, class, [])
  def statics(_), do: []

  def system_statics(%{statics: statics}) when is_list(statics) and statics != [], do: statics

  def system_statics(system), do: statics(display_class(system))

  def display_class(%{sys_class: class}) when is_binary(class) and class != "", do: class

  def display_class(%{solar_system_id: id} = system) when is_integer(id) do
    case WormholeSystems.get(id) do
      %{class: class} when is_binary(class) -> class
      _ -> security_class(system)
    end
  end

  def display_class(system), do: security_class(system)

  def display_effect(%{effect: effect}) when is_binary(effect) and effect != "", do: effect
  def display_effect(_), do: nil

  def sde_attrs(solar_system_id, name \\ nil) do
    attrs = WormholeSystems.attrs(solar_system_id, name)

    case Ztripwire.Systems.Catalog.get(solar_system_id) do
      %{security: security} when is_number(security) ->
        Map.put_new(attrs, :security, security)

      _ ->
        attrs
    end
  end

  defp security_class(%{solar_system_id: id})
       when is_integer(id) and id >= @w_space_min and id < @w_space_max,
       do: "W"

  defp security_class(%{security: security}) when is_number(security) and security >= 0.45,
    do: "HS"

  defp security_class(%{security: security}) when is_number(security) and security > 0.0,
    do: "LS"

  defp security_class(%{security: security}) when is_number(security), do: "NS"
  defp security_class(_), do: nil

  def color(system), do: Map.get(@colors, display_class(system), @unknown_color)

  def badge_color(label) when is_binary(label), do: Map.get(@colors, label, @unknown_color)
  def badge_color(_), do: @unknown_color

  def badge_text_color(label) when label in ["HS", "LS"], do: "#111111"
  def badge_text_color(_), do: "#ffffff"

  def security_label(system), do: label_for(security_class(system))

  defp label_for("HS"), do: "High-Sec"
  defp label_for("LS"), do: "Low-Sec"
  defp label_for("NS"), do: "Null-Sec"
  defp label_for(_), do: "W-Space"

  def esi_resolvable?(%{solar_system_id: id}) when is_integer(id), do: id < @w_space_min
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
           Ztripwire.ESI.get_system(solar_id),
         {:ok, %{"name" => constellation_name, "region_id" => region_id}} <-
           Ztripwire.ESI.get_constellation(constellation_id),
         {:ok, %{"name" => region_name}} <- Ztripwire.ESI.get_region(region_id) do
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
        %{kind: :faction, id: faction_id, name: Ztripwire.EveImages.faction_name(faction_id)}

      _ ->
        nil
    end
  end

  defp alliance_name(alliance_id) do
    case Ztripwire.ESI.get_alliance(alliance_id) do
      {:ok, %{"name" => name}} -> name
      _ -> "Alliance #{alliance_id}"
    end
  end

  defp sovereignty_for(solar_id) do
    case Ztripwire.ESI.get_sovereignty_map() do
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
