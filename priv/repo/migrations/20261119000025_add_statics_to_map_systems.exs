defmodule Ztripwire.Repo.Migrations.AddStaticsToMapSystems do
  use Ecto.Migration

  def up do
    alter table(:map_systems) do
      add :statics, {:array, :text}, default: []
    end

    flush()

    Ztripwire.Mapping.SystemData.backfill()
  end

  def down do
    alter table(:map_systems) do
      remove :statics
    end
  end
end
