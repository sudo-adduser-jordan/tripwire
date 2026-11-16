defmodule Tripwire.Systems do
  @moduledoc """
  System-class resolution mirroring official Tripwire node content.

  Official Tripwire renders each chain-map node as class (top), system
  name or J-code (middle), and wormhole type (bottom). The class comes
  from its EVE dump when known (`C1`–`C6`, …); otherwise it falls back
  to security status: `HS` (`>= 0.45`), `LS` (`> 0.0`), `NS` (`<= 0.0`).

  This port stores `sys_class` (exact label, e.g. `"C3"`) and `security`
  (ESI `security_status`) on each map system. The security fallback only
  applies to known-space (`security >= 0`); wormhole systems without a
  known class render a blank class line instead of being mislabeled `NS`.

  Node colors: wormhole classes C1–C3 render blue, C4–C5 render
  purple, C6 renders pink, highsec green, lowsec amber, and
  nullsec plus Triglavian/Pochven red.
  """

  @classes ~w(C1 C2 C3 C4 C5 C6 HS LS NS Trig)

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

  @doc """
  Returns the class labels a system can be assigned by hand.
  """
  def classes, do: @classes

  @doc """
  Returns the class label for a map system (`"C3"`, `"HS"`, `"LS"`,
  `"NS"`) or `nil` when unknown.
  """
  def display_class(%{sys_class: class}) when is_binary(class) and class != "", do: class
  def display_class(%{security: security}) when is_number(security) and security >= 0.45, do: "HS"
  def display_class(%{security: security}) when is_number(security) and security > 0.0, do: "LS"
  def display_class(%{security: security}) when is_number(security), do: "NS"
  def display_class(_), do: nil

  @doc """
  Returns the node accent color (hex) for a map system, keyed by its
  display class. Unknown classes fall back to a neutral gray.
  """
  def color(system), do: Map.get(@colors, display_class(system), @unknown_color)

  @doc """
  Human security label: `High-Sec`, `Low-Sec`, `Null-Sec`, or `W-Space`.
  """
  def security_label(%{security: security}) when is_number(security) and security >= 0.45,
    do: "High-Sec"

  def security_label(%{security: security}) when is_number(security) and security > 0.0,
    do: "Low-Sec"

  def security_label(%{security: security}) when is_number(security), do: "Null-Sec"
  def security_label(_), do: "W-Space"

  @doc """
  Formats a security status float to one decimal (`0.9`, `-1.0`).
  Returns `""` when unknown (wormholes).
  """
  def format_security(%{security: security}) when is_number(security),
    do: :erlang.float_to_binary(security * 1.0, decimals: 1)

  def format_security(_), do: ""

  @doc """
  True for real New Eden systems (ESI-resolvable). Fake J-codes used for
  wormholes (`>= 31_000_000`) have no ESI detail pages.
  """
  def esi_resolvable?(%{solar_system_id: id}) when is_integer(id), do: id < 31_000_000
  def esi_resolvable?(_), do: false

  @doc """
  External reference links for a system. Dotlan/zKill need a real solar
  id; wormholes fall back to name search / Anoikis.
  """
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

  @doc """
  Fetches ESI detail for a real system: constellation + region names and
  the sovereignty holder (alliance/faction) when present. Returns
  `{:error, :wormhole}` for fake J-codes.
  """
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
         sovereignty: sovereignty_for(solar_id)
       }}
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

  @doc """
  Builds system attributes from an ESI `GET /universe/systems/{id}/`
  response body.
  """
  def attrs_from_esi(%{"name" => name} = body) do
    %{name: name, security: body["security_status"]}
  end

  def attrs_from_esi(_), do: %{name: nil, security: nil}
end
