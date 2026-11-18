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
    field :ship_on_chain, :boolean, default: true
    field :character_on_chain, :boolean, default: true
    field :signatures_added, :integer, default: 0
    field :signatures_updated, :integer, default: 0
    field :signatures_deleted, :integer, default: 0
    field :wormholes_added, :integer, default: 0
    field :wormholes_updated, :integer, default: 0
    field :wormholes_deleted, :integer, default: 0
    field :comments_added, :integer, default: 0
    field :comments_updated, :integer, default: 0
    field :comments_deleted, :integer, default: 0
    field :systems_visited, :integer, default: 0
    field :login_count, :integer, default: 0

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
      :is_admin,
      :ship_on_chain,
      :character_on_chain
    ])
    |> validate_required([:eve_id, :name])
    |> unique_constraint(:eve_id)
  end
end
