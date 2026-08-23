defmodule Tripwire.Repo.Migrations.CreateMapConnections do
  use Ecto.Migration

  def change do
    create table(:map_connections) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :from_system_id, references(:map_systems, on_delete: :delete_all), null: false
      add :to_system_id, references(:map_systems, on_delete: :delete_all), null: false
      add :hole_type, :text
      add :mass_status, :text, default: "stable"
      add :time_status, :text, default: "stable"
      add :ship_size, :text

      timestamps(type: :utc_datetime)
    end

    create index(:map_connections, [:map_id])
    create index(:map_connections, [:from_system_id])
    create index(:map_connections, [:to_system_id])

    create unique_index(:map_connections, [:from_system_id, :to_system_id])

    create unique_index(:map_connections, [:to_system_id, :from_system_id],
             name: :map_connections_reverse_index
           )
  end
end
