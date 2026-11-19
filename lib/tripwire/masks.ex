defmodule Tripwire.Masks do
  import Ecto.Query

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping
  alias Tripwire.Masks.{Mask, MaskMembership}
  alias Tripwire.Repo

  def ensure_personal_mask(%Character{}) do
    case Repo.one(from(m in Mask, where: m.kind == "personal", order_by: [asc: m.id], limit: 1)) do
      %Mask{} = mask ->
        {:ok, mask}

      nil ->
        %Mask{}
        |> Mask.changeset(%{name: "Private", kind: "personal"})
        |> Repo.insert()
    end
  end

  def ensure_demo_mask do
    case Repo.one(from(m in Mask, where: m.kind == "demo")) do
      %Mask{} = mask ->
        {:ok, mask}

      nil ->
        %Mask{}
        |> Mask.changeset(%{name: "Demo", kind: "demo"})
        |> Repo.insert()
    end
  end

  def ensure_corporation_mask(%Character{corporation_id: nil}), do: {:error, :no_corporation}

  def ensure_corporation_mask(%Character{corporation_id: corp_id, corporation_name: corp_name}) do
    case Repo.one(from(m in Mask, where: m.kind == "corporation" and m.eve_owner_id == ^corp_id)) do
      %Mask{} = mask ->
        {:ok, mask}

      nil ->
        %Mask{}
        |> Mask.changeset(%{
          name: corp_name || "Corporation #{corp_id}",
          kind: "corporation",
          eve_owner_id: corp_id,
          owner_type: "corporation"
        })
        |> Repo.insert()
    end
  end

  def ensure_alliance_mask(%Character{alliance_id: nil}), do: {:error, :no_alliance}

  def ensure_alliance_mask(%Character{alliance_id: alliance_id, alliance_name: alliance_name}) do
    case Repo.one(from(m in Mask, where: m.kind == "alliance" and m.eve_owner_id == ^alliance_id)) do
      %Mask{} = mask ->
        {:ok, mask}

      nil ->
        %Mask{}
        |> Mask.changeset(%{
          name: alliance_name || "Alliance #{alliance_id}",
          kind: "alliance",
          eve_owner_id: alliance_id,
          owner_type: "alliance"
        })
        |> Repo.insert()
    end
  end

  def create_mask(attrs) do
    %Mask{} |> Mask.changeset(attrs) |> Repo.insert()
  end

  def delete_mask(%Mask{} = mask), do: Repo.delete(mask)

  def delete_mask_full(%Mask{id: mask_id} = mask) do
    mask_id
    |> Mapping.list_maps_for_mask()
    |> Enum.each(&Mapping.delete_map_full/1)

    Repo.delete_all(from(mm in MaskMembership, where: mm.mask_id == ^mask_id))
    Repo.delete(mask)
  end

  def remove_membership(%Mask{} = mask, %Character{} = character) do
    Repo.delete_all(
      from(mm in MaskMembership,
        where: mm.mask_id == ^mask.id and mm.character_id == ^character.id
      )
    )

    {:ok, :removed}
  end

  def member?(%Mask{} = mask, %Character{} = character) do
    Repo.exists?(
      from(mm in MaskMembership,
        where: mm.mask_id == ^mask.id and mm.character_id == ^character.id
      )
    )
  end

  def add_membership(%Mask{} = mask, %Character{} = character) do
    %MaskMembership{mask_id: mask.id, character_id: character.id}
    |> MaskMembership.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  def list_masks_for_character(character_id) do
    Repo.all(
      from(m in Mask,
        join: mm in MaskMembership,
        on: mm.mask_id == m.id,
        where: mm.character_id == ^character_id,
        distinct: true
      )
    )
  end

  def list_masks do
    from(m in Mask, where: m.kind != "demo")
    |> Repo.all()
    |> Enum.sort_by(&{kind_rank(&1.kind), &1.name})
  end

  defp kind_rank("personal"), do: 0
  defp kind_rank("corporation"), do: 1
  defp kind_rank("alliance"), do: 2
  defp kind_rank("demo"), do: 3
  defp kind_rank(_), do: 4
end
