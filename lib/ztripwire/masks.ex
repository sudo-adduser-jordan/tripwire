defmodule Ztripwire.Masks do
  import Ecto.Query

  alias Ztripwire.Accounts.Character
  alias Ztripwire.Mapping
  alias Ztripwire.Masks.{Mask, MaskMembership}
  alias Ztripwire.Repo

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

  def get_mask(id), do: Repo.get(Mask, id)

  def delete_mask_full(%Mask{id: mask_id} = mask) do
    Repo.delete_all(from(m in Mapping.Map, where: m.mask_id == ^mask_id))
    :ok = Mapping.delete_mask_chain(mask_id)
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

  def list_masks_for_characters(characters) when is_list(characters) do
    character_ids = Enum.map(characters, & &1.id)
    corporation_ids = characters |> Enum.map(& &1.corporation_id) |> Enum.reject(&is_nil/1)
    alliance_ids = characters |> Enum.map(& &1.alliance_id) |> Enum.reject(&is_nil/1)

    member_mask_ids =
      from(mm in MaskMembership, where: mm.character_id in ^character_ids, select: mm.mask_id)

    from(m in Mask,
      where: m.kind != "demo",
      where:
        m.kind == "personal" or
          (m.kind == "corporation" and m.eve_owner_id in ^corporation_ids) or
          (m.kind == "alliance" and m.eve_owner_id in ^alliance_ids) or
          m.id in subquery(member_mask_ids)
    )
    |> Repo.all()
    |> Enum.sort_by(&{kind_rank(&1.kind), &1.name})
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

  def prune_orphan_masks, do: prune_orphan_masks(nil)

  def prune_orphan_masks(owner_ids) when is_list(owner_ids) or is_nil(owner_ids) do
    if unknown_corporations?() do
      []
    else
      corporation_ids =
        Repo.all(from c in Character, select: c.corporation_id)

      alliance_ids =
        Repo.all(from c in Character, where: not is_nil(c.alliance_id), select: c.alliance_id)

      orphaned =
        Mask
        |> orphaned_masks_query(corporation_ids, alliance_ids, owner_ids)
        |> Repo.all()

      Enum.map(orphaned, fn mask ->
        {:ok, _} = delete_mask_full(mask)
        mask
      end)
    end
  end

  defp orphaned_masks_query(query, corporation_ids, alliance_ids, nil) do
    from(m in query,
      where:
        (m.kind == "corporation" and not is_nil(m.eve_owner_id) and
           m.eve_owner_id not in ^corporation_ids) or
          (m.kind == "alliance" and not is_nil(m.eve_owner_id) and
             m.eve_owner_id not in ^alliance_ids)
    )
  end

  defp orphaned_masks_query(query, corporation_ids, alliance_ids, owner_ids) do
    from(m in query,
      where:
        (m.kind == "corporation" and not is_nil(m.eve_owner_id) and
           m.eve_owner_id in ^owner_ids and m.eve_owner_id not in ^corporation_ids) or
          (m.kind == "alliance" and not is_nil(m.eve_owner_id) and
             m.eve_owner_id in ^owner_ids and m.eve_owner_id not in ^alliance_ids)
    )
  end

  defp unknown_corporations? do
    Repo.exists?(
      from c in Character,
        where:
          is_nil(c.corporation_id) and
            (not is_nil(c.last_login_at) or not is_nil(c.refresh_token))
    )
  end

  defp kind_rank("personal"), do: 0
  defp kind_rank("corporation"), do: 1
  defp kind_rank("alliance"), do: 2
  defp kind_rank("demo"), do: 3
  defp kind_rank(_), do: 4
end
