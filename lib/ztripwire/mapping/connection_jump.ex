defmodule Ztripwire.Mapping.ConnectionJump do
  use Ecto.Schema

  alias Ztripwire.Mapping.{MapConnection, MapSystem}

  schema "connection_jumps" do
    field :character_name, :string
    field :ship_type, :string

    belongs_to :map_connection, MapConnection
    belongs_to :to_system, MapSystem, foreign_key: :to_system_id

    timestamps(type: :utc_datetime)
  end
end
