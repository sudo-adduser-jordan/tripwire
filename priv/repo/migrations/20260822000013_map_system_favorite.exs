defmodule Ztripwire.Repo.Migrations.MapSystemFavorite do
  use Ecto.Migration

  def change do
    alter table(:map_systems) do
      add :favorite, :boolean, default: false, null: false
    end
  end
end
