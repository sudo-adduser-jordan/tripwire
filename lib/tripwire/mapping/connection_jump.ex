defmodule Tripwire.Mapping.ConnectionJump do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Mapping.{MapConnection, MapSystem}

  schema "connection_jumps" do
    field :character_name, :string
    field :ship_type, :string

    belongs_to :map_connection, MapConnection
    belongs_to :to_system, MapSystem, foreign_key: :to_system_id

    timestamps(type: :utc_datetime)
  end

  def changeset(jump, attrs) do
    jump
    |> cast(attrs, [:map_connection_id, :character_name, :to_system_id, :ship_type])
    |> validate_required([:map_connection_id, :character_name])
  end
end
