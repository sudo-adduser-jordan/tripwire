defmodule Tripwire.Mapping.SystemStat do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Mapping.MapSystem

  schema "system_stats" do
    field :jumps, :integer, default: 0
    field :kills, :integer, default: 0
    field :visits, :integer, default: 0
    field :recorded_at, :utc_datetime

    belongs_to :map_system, MapSystem

    timestamps(type: :utc_datetime)
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:map_system_id, :jumps, :kills, :visits, :recorded_at])
    |> validate_required([:map_system_id])
    |> unique_constraint(:map_system_id)
  end
end
