defmodule Tripwire.Masks.MaskMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Accounts.Character
  alias Tripwire.Masks.Mask

  schema "mask_memberships" do
    belongs_to :mask, Mask
    belongs_to :character, Character

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:mask_id, :character_id])
    |> validate_required([:mask_id, :character_id])
    |> unique_constraint([:mask_id, :character_id])
  end
end
