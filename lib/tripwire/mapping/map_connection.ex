defmodule Tripwire.Mapping.MapConnection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Mapping.Map
  alias Tripwire.Mapping.MapSystem

  @mass_statuses ~w(stable degraded critical)
  @time_statuses ~w(stable eol)
  @ship_sizes ~w(mass medium small)

  schema "map_connections" do
    field :hole_type, :string
    field :mass_status, :string, default: "stable"
    field :time_status, :string, default: "stable"
    field :ship_size, :string

    belongs_to :map, Map
    belongs_to :from_system, MapSystem, foreign_key: :from_system_id
    belongs_to :to_system, MapSystem, foreign_key: :to_system_id

    timestamps(type: :utc_datetime)
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [
      :map_id,
      :from_system_id,
      :to_system_id,
      :hole_type,
      :mass_status,
      :time_status,
      :ship_size
    ])
    |> validate_required([:map_id, :from_system_id, :to_system_id])
    |> validate_inclusion(:mass_status, @mass_statuses)
    |> validate_inclusion(:time_status, @time_statuses)
    |> validate_inclusion(:ship_size, @ship_sizes ++ [nil])
  end
end
