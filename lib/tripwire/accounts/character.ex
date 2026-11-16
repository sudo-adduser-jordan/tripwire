defmodule Tripwire.Accounts.Character do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.EctoTypes.EncryptedBinary

  schema "characters" do
    field :eve_id, :integer
    field :name, :string
    field :corporation_id, :integer
    field :corporation_name, :string
    field :alliance_id, :integer
    field :alliance_name, :string
    field :scopes, {:array, :string}, default: []
    field :refresh_token, EncryptedBinary
    field :last_login_at, :utc_datetime
    field :is_admin, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :eve_id,
      :name,
      :corporation_id,
      :corporation_name,
      :alliance_id,
      :alliance_name,
      :scopes,
      :refresh_token,
      :last_login_at,
      :is_admin
    ])
    |> validate_required([:eve_id, :name])
    |> unique_constraint(:eve_id)
  end
end
