defmodule Tripwire.Mapping.Map do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Masks.Mask
  alias Tripwire.Mapping.MapSystem

  schema "maps" do
    field :name, :string

    belongs_to :mask, Mask
    has_many :systems, MapSystem, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [:name, :mask_id])
    |> validate_required([:name, :mask_id])
  end
end
