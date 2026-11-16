defmodule Tripwire.Mapping.Flare do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping.MapSystem

  @colors ~w(red yellow green)

  schema "flares" do
    field :color, :string, default: "red"
    field :reason, :string
    field :life_length, :integer, default: 3600
    field :expires_at, :utc_datetime

    belongs_to :map_system, MapSystem
    belongs_to :mask, Tripwire.Masks.Mask
    belongs_to :created_by, Character, foreign_key: :created_by_id

    timestamps(type: :utc_datetime)
  end

  def changeset(flare, attrs) do
    flare
    |> cast(attrs, [
      :map_system_id,
      :mask_id,
      :color,
      :reason,
      :life_length,
      :expires_at,
      :created_by_id
    ])
    |> validate_required([:map_system_id, :color])
    |> validate_inclusion(:color, @colors)
  end
end
