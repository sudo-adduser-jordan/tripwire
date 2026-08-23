defmodule Tripwire.Mapping.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping.MapSystem

  schema "comments" do
    field :body, :string

    belongs_to :map_system, MapSystem
    belongs_to :character, Character

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:map_system_id, :character_id, :body])
    |> validate_required([:map_system_id, :body])
  end
end
