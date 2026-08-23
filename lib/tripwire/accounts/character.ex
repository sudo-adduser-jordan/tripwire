defmodule Tripwire.Accounts.Character do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.EctoTypes.EncryptedBinary

  schema "characters" do
    field :eve_id, :integer
    field :name, :string
    field :corporation_id, :integer
    field :alliance_id, :integer
    field :scopes, {:array, :string}, default: []
    field :refresh_token, EncryptedBinary
    field :last_login_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :eve_id,
      :name,
      :corporation_id,
      :alliance_id,
      :scopes,
      :refresh_token,
      :last_login_at
    ])
    |> validate_required([:eve_id, :name])
    |> unique_constraint(:eve_id)
  end
end
