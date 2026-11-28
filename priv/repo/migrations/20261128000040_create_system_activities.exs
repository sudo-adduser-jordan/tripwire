defmodule Ztripwire.Repo.Migrations.CreateSystemActivities do
  use Ecto.Migration

  def change do
    create table(:system_activities) do
      add :solar_system_id, :integer, null: false
      add :recorded_at, :utc_datetime, null: false
      add :ship_jumps, :integer, null: false, default: 0
      add :ship_kills, :integer, null: false, default: 0
      add :pod_kills, :integer, null: false, default: 0
      add :npc_kills, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:system_activities, [:solar_system_id, :recorded_at])
    create index(:system_activities, [:recorded_at])
  end
end
