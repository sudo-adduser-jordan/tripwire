defmodule Ztripwire.Mapping.SystemActivity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "system_activities" do
    field :solar_system_id, :integer
    field :recorded_at, :utc_datetime
    field :ship_jumps, :integer, default: 0
    field :ship_kills, :integer, default: 0
    field :pod_kills, :integer, default: 0
    field :npc_kills, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [
      :solar_system_id,
      :recorded_at,
      :ship_jumps,
      :ship_kills,
      :pod_kills,
      :npc_kills
    ])
    |> validate_required([:solar_system_id, :recorded_at])
    |> unique_constraint([:solar_system_id, :recorded_at])
  end
end
