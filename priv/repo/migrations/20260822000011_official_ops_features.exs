defmodule Tripwire.Repo.Migrations.OfficialOpsFeatures do
  use Ecto.Migration

  def change do
    create table(:flares) do
      add :map_system_id, references(:map_systems, on_delete: :delete_all), null: false
      add :mask_id, references(:masks, on_delete: :delete_all)
      add :color, :text, null: false, default: "red"
      add :reason, :text
      add :life_length, :integer, null: false, default: 3600
      add :expires_at, :utc_datetime
      add :created_by_id, references(:characters, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:flares, [:map_system_id])
    create index(:flares, [:mask_id])

    create table(:system_stats) do
      add :map_system_id, references(:map_systems, on_delete: :delete_all), null: false
      add :jumps, :integer, null: false, default: 0
      add :kills, :integer, null: false, default: 0
      add :visits, :integer, null: false, default: 0
      add :recorded_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:system_stats, [:map_system_id])

    create table(:connection_jumps) do
      add :map_connection_id, references(:map_connections, on_delete: :delete_all), null: false
      add :character_name, :text, null: false
      add :to_system_id, references(:map_systems, on_delete: :nilify_all)
      add :ship_type, :text
      timestamps(type: :utc_datetime)
    end

    create index(:connection_jumps, [:map_connection_id])
  end
end
