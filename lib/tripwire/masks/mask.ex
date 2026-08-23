defmodule Tripwire.Masks.Mask do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping.Map
  alias Tripwire.Masks.MaskMembership

  @kinds ~w(personal corporation alliance)

  schema "masks" do
    field :name, :string
    field :kind, :string, default: "personal"
    field :eve_group_id, :integer

    belongs_to :owner_character, Character, foreign_key: :owner_character_id
    has_many :memberships, MaskMembership, on_delete: :delete_all
    has_many :maps, Map, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(mask, attrs) do
    mask
    |> cast(attrs, [:name, :kind, :eve_group_id, :owner_character_id])
    |> validate_required([:name])
    |> validate_inclusion(:kind, @kinds)
  end
end
