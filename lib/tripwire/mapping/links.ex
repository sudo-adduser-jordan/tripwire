defmodule Tripwire.Mapping.Links do
  alias Tripwire.Signatures, as: SigParser

  def deleted_codes(signatures) do
    signatures
    |> Enum.filter(&(&1.site_type == "wormhole"))
    |> Enum.map(&SigParser.wormhole_code(&1.type_name))
    |> MapSet.new(fn
      nil -> ""
      code -> code
    end)
    |> MapSet.delete("")
  end

  def link_targets(signature, others) do
    case SigParser.wormhole_code(signature.type_name) do
      nil ->
        []

      code ->
        case Enum.filter(
               others,
               &(&1.sig_id == signature.sig_id and SigParser.wormhole_code(&1.type_name) == code)
             ) do
          [] ->
            by_code = Enum.filter(others, &(SigParser.wormhole_code(&1.type_name) == code))
            if unique_systems?(by_code), do: by_code, else: []

          same_id ->
            same_id
        end
    end
  end

  def unique_systems?(signatures) do
    signatures
    |> Enum.map(& &1.map_system_id)
    |> Enum.uniq()
    |> length() == 1
  end

  def pair_key(system_a_id, system_b_id, code) do
    {code, Enum.min([system_a_id, system_b_id]), Enum.max([system_a_id, system_b_id])}
  end
end
