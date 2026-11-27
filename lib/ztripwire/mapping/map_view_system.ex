defmodule Ztripwire.Mapping.MapViewSystem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ztripwire.Mapping.{Map, MapSystem}

  schema "map_view_systems" do
    field :x, :float, default: 0.0
    field :y, :float, default: 0.0

    belongs_to :map, Map
    belongs_to :map_system, MapSystem

    timestamps(type: :utc_datetime)
  end

  def changeset(position, attrs) do
    position
    |> cast(attrs, [:map_id, :map_system_id, :x, :y])
    |> validate_required([:map_id, :map_system_id])
    |> unique_constraint([:map_id, :map_system_id])
  end
end
