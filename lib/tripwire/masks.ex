defmodule Tripwire.Masks do
  import Ecto.Query

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping
  alias Tripwire.Masks.{Mask, MaskMembership}
  alias Tripwire.Repo

  @doc """
  Returns the character's personal mask, creating it on first use.
  """
  def ensure_personal_mask(%Character{id: id, name: name}) do
    case Repo.one(from(m in Mask, where: m.owner_character_id == ^id and m.kind == "personal")) do
      %Mask{} = mask ->
        {:ok, mask}

      nil ->
        %Mask{}
        |> Mask.changeset(%{name: name, kind: "personal", owner_character_id: id})
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

  @doc """
  Hard-deletes a mask with all of its maps (systems, connections,
  signatures, comments, flares, stats) and memberships.
  """
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
end
