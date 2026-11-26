defmodule Ztripwire.Mapping.Flare do
  use Ecto.Schema

  alias Ztripwire.Accounts.Character
  alias Ztripwire.Mapping.MapSystem
  alias Ztripwire.Masks.Mask

  schema "flares" do
    field :color, :string, default: "red"
    field :reason, :string
    field :life_length, :integer, default: 3600
    field :expires_at, :utc_datetime

    belongs_to :map_system, MapSystem
    belongs_to :mask, Mask
    belongs_to :created_by, Character, foreign_key: :created_by_id

    timestamps(type: :utc_datetime)
  end
end
