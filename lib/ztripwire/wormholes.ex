defmodule Ztripwire.Wormholes do
  @path Path.expand("../../priv/data/wormholes.json", __DIR__)
  @external_resource @path
  @wormholes @path |> File.read!() |> Jason.decode!()

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

  def all_codes, do: Map.keys(@wormholes) |> Enum.sort()

  def get(code) when is_binary(code), do: Map.get(@wormholes, String.upcase(code))
  def get(_), do: nil

  def from(code), do: get(code) |> ends("from")

  def leads_to(code), do: get(code) |> ends("leadsTo")

  def mass(code), do: field(code, "mass")

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

  def class_short(label) when is_binary(label), do: Map.get(@class_short, label, label)
  def class_short(label), do: label

  def render_mass(nil), do: nil
  def render_mass(mass) when is_number(mass), do: "#{div(trunc(mass), 1_000_000)}kt"

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

  def dummy(key), do: Map.get(@dummy, key)

  def life_hours(code) when is_binary(code) do
    case get(code) do
      %{"life" => life} when is_binary(life) ->
        case Float.parse(life) do
          {hours, _} -> hours
          :error -> nil
        end

      _ ->
        nil
    end
  end

  def life_hours(_), do: nil

  def life_seconds(code) do
    case life_hours(code) do
      nil -> nil
      hours -> round(hours * 3600)
    end
  end

  def eligible_types(source, target) do
    source = endpoint(source)
    target = endpoint(target)

    Enum.reduce(@wormholes, %{from: [], to: []}, fn {code, wt}, acc ->
      wt_from = wt |> Map.get("from") |> List.wrap()
      wt_leads = wt |> Map.get("leadsTo") |> List.wrap()

      %{
        from:
          if(endpoint_match?(wt_from, source) and endpoint_match?(wt_leads, target),
            do: [code | acc.from],
            else: acc.from
          ),
        to:
          if(endpoint_match?(wt_from, target) and endpoint_match?(wt_leads, source),
            do: [code | acc.to],
            else: acc.to
          )
      }
    end)
    |> Map.update!(:from, &Enum.reverse/1)
    |> Map.update!(:to, &Enum.reverse/1)
  end

  def endpoint(nil), do: nil
  def endpoint(""), do: nil

  def endpoint(value) when is_binary(value) do
    %{
      name: value,
      class: value |> class_short() |> blank_to_nil(),
      classes: endpoint_classes(value)
    }
  end

  def endpoint(%{} = system) do
    name = Map.get(system, :name) || Map.get(system, "name")
    class = Map.get(system, :sys_class) || Map.get(system, "sys_class")

    class =
      cond do
        is_binary(class) and class != "" -> class
        Map.has_key?(system, :security) -> Ztripwire.Systems.display_class(system)
        true -> nil
      end

    %{
      name: name,
      class: class,
      classes: endpoint_classes(class),
      solar: Map.get(system, :solar_system_id)
    }
  end

  defp endpoint_match?(_possible, nil), do: true
  defp endpoint_match?([], _endpoint), do: true

  defp endpoint_match?(possible, endpoint) do
    Enum.any?(possible, fn value ->
      class = value |> class_short() |> blank_to_nil()
      value_class = endpoint_classes(value)

      endpoint.class == class or
        (is_binary(endpoint.name) and endpoint.name == value) or
        Enum.any?(value_class, &(&1 in endpoint.classes)) or
        Enum.any?(endpoint.classes, &(&1 in value_class))
    end)
  end

  defp endpoint_classes(value) do
    case class_short(value) do
      "Drifter" -> ~w(C14 C15 C16 C17 C18)
      "Dangerous" -> ~w(C4 C5)
      "Unknown" -> ~w(C2 C3)
      "Unknown (small)" -> ~w(C1 C2 C3 C13)
      nil -> []
      class -> [class]
    end
  end

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
