defmodule Tripwire.Wormholes do
  @moduledoc """
  Static wormhole-type database ported from official Tripwire's
  `tools/wormholes.json`.

  Each type code maps to its natural lifetime (`life`), the system classes it
  connects (`from` → `leadsTo`), its total mass, and its maximum jump mass.
  Official Tripwire reads this to label the two ends of a hole, style the
  chain-map line by jump mass, and infer a likely hole size when the type is
  unknown.

  Labels are normalised to the short forms this port uses everywhere else
  (`Class-4` → `C4`, `High-Sec` → `HS`, `Null-Sec` → `NS`, `Triglavian` →
  `Trig`); a `leadsTo` that names a specific system (e.g. `Turnur`) is kept
  verbatim.
  """

  @path Path.expand("../../priv/data/wormholes.json", __DIR__)
  @external_resource @path
  @wormholes @path |> File.read!() |> Jason.decode!()

  # Placeholder holes for when the exact type is unknown, matching official
  # Tripwire's `wormholeAnalysis.dummyWormholes`.
  @dummy %{
    "GATE" => %{
      "from" => ["Null-Sec", "Low-Sec", "High-Sec", "Triglavian"],
      "leadsTo" => ["Null-Sec", "Low-Sec", "High-Sec", "Triglavian"]
    },
    "SML" => %{"jump" => 5_000_000},
    "MED" => %{"jump" => 62_000_000, "mass" => 500_000_000},
    "LRG" => %{"jump" => 375_000_000, "mass" => 2_000_000_000},
    "XLG" => %{"jump" => 2_000_000_000, "mass" => 3_300_000_000}
  }

  @class_short %{
    "Class-1" => "C1",
    "Class-2" => "C2",
    "Class-3" => "C3",
    "Class-4" => "C4",
    "Class-5" => "C5",
    "Class-6" => "C6",
    "Class-13" => "C13",
    "Class-14" => "C14",
    "Class-15" => "C15",
    "Class-16" => "C16",
    "Class-17" => "C17",
    "Class-18" => "C18",
    "High-Sec" => "HS",
    "Low-Sec" => "LS",
    "Null-Sec" => "NS",
    "Triglavian" => "Trig"
  }

  @doc "Every known wormhole type code."
  def all_codes, do: Map.keys(@wormholes) |> Enum.sort()

  @doc "The raw data map for a type code, or `nil` when unknown."
  def get(code) when is_binary(code), do: Map.get(@wormholes, String.upcase(code))
  def get(_), do: nil

  @doc "Natural lifetime label (e.g. `\"16 Hours\"`), or `nil`."
  def life(code), do: field(code, "life")

  @doc "Source class labels a hole of this type comes from, normalised to short forms."
  def from(code), do: get(code) |> ends("from")

  @doc "Destination class/system labels a hole of this type leads to, normalised."
  def leads_to(code), do: get(code) |> ends("leadsTo")

  @doc "Total mass in kg, or `nil`."
  def mass(code), do: field(code, "mass")

  @doc "Maximum jump mass in kg, or `nil`."
  def jump(code), do: field(code, "jump")

  defp field(code, key) do
    case get(code) do
      nil -> nil
      type -> Map.get(type, key)
    end
  end

  defp ends(nil, _field), do: []

  defp ends(type, field) do
    type
    |> Map.get(field)
    |> List.wrap()
    |> Enum.map(&class_short/1)
  end

  @doc """
  Normalises a class/system label to its short form, leaving system names and
  unknown labels untouched.
  """
  def class_short(label) when is_binary(label), do: Map.get(@class_short, label, label)
  def class_short(label), do: label

  @doc "Renders a jump mass as `\"375kt\"`, or `nil`."
  def render_mass(nil), do: nil
  def render_mass(mass) when is_number(mass), do: "#{div(trunc(mass), 1_000_000)}kt"

  @doc """
  Renders a wormhole type as official Tripwire does: `"B274: C4 ➔ C3 (375kt)"`.
  Unknown types fall back to the bare code.
  """
  def render(code) when is_binary(code) do
    key = String.upcase(code)

    case get(code) do
      nil ->
        key

      _type ->
        from_str = from(code) |> format_end()
        to_str = leads_to(code) |> format_end()

        case render_mass(jump(code)) do
          nil -> "#{key}: #{from_str} ➔ #{to_str}"
          mass -> "#{key}: #{from_str} ➔ #{to_str} (#{mass})"
        end
    end
  end

  def render(_), do: "?"

  defp format_end([]), do: "?"
  defp format_end(types), do: Enum.join(types, ", ")

  @doc """
  Infers a dummy hole size (`"SML"`, `"MED"`, `"LRG"`, `"XLG"`) for a hole of
  unknown type, from the classes of the two systems it connects. Port of
  official Tripwire's `wormholeAnalysis.likelyWormhole`.
  """
  def likely_wormhole(class1, class2) do
    cond do
      k_space?(class1) -> infer_k_space(class2)
      k_space?(class2) -> infer_k_space(class1)
      class1 == "C13" or class2 == "C13" -> "SML"
      class1 == "C1" or class2 == "C1" -> "MED"
      high_class?(class1) and high_class?(class2) -> "XLG"
      true -> "LRG"
    end
  end

  @doc """
  The dummy data map for a likely hole size, e.g. for rendering mass when a
  connection's type is unknown.
  """
  def dummy(key), do: Map.get(@dummy, key)

  @doc """
  Returns `%{from: [codes], to: [codes]}` of wormhole types eligible for a
  connection between two system classes. `source`/`target` are short class
  labels (or `nil` for unknown). Port of official `eligibleWormholeTypes`,
  simplified to class-only matching (no exclusion or multi-class variants
  appear in the shipped database).
  """
  def eligible_types(source, target) do
    source = source |> to_string() |> class_short() |> blank_to_nil()
    target = target |> to_string() |> class_short() |> blank_to_nil()

    Enum.reduce(@wormholes, %{from: [], to: []}, fn {code, wt}, acc ->
      wt_from = wt |> Map.get("from") |> List.wrap() |> Enum.map(&class_short/1)
      wt_leads = wt |> Map.get("leadsTo") |> List.wrap() |> Enum.map(&class_short/1)

      %{
        from:
          if(match_end?(wt_from, source) and match_end?(wt_leads, target),
            do: [code | acc.from],
            else: acc.from
          ),
        to:
          if(match_end?(wt_from, target) and match_end?(wt_leads, source),
            do: [code | acc.to],
            else: acc.to
          )
      }
    end)
    |> Map.update!(:from, &Enum.reverse/1)
    |> Map.update!(:to, &Enum.reverse/1)
  end

  defp match_end?(_possible, nil), do: true
  defp match_end?(nil, _system), do: false
  defp match_end?(possible, system) when is_list(possible), do: system in possible

  defp k_space?(class), do: class in ["HS", "LS", "NS"]

  defp high_class?(class), do: class in ["C5", "C6"]

  defp infer_k_space(class) do
    cond do
      high_class?(class) -> "XLG"
      class == "C1" -> "MED"
      true -> "LRG"
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
