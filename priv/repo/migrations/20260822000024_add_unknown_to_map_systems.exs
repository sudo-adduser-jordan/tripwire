defmodule Ztripwire.Repo.Migrations.AddUnknownToMapSystems do
  use Ecto.Migration

  def change do
    alter table(:map_systems) do
      add :unknown, :boolean, default: false, null: false
    end
  end
end
