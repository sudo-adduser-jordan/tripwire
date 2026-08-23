defmodule Tripwire.Repo.Migrations.CreateMapSystems do
  use Ecto.Migration

  def change do
    create table(:map_systems) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :solar_system_id, :integer, null: false
      add :name, :text, null: false
      add :alias, :text
      add :x, :float, default: 0.0
      add :y, :float, default: 0.0
      add :locked, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:map_systems, [:map_id])
    create index(:map_systems, [:map_id, :solar_system_id])
  end
end
