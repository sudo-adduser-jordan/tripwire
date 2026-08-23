defmodule Tripwire.Masks do
  import Ecto.Query

  alias Tripwire.Accounts.Character
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
