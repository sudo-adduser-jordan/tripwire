defmodule Ztripwire.Repo.Migrations.RemoveMapSystemLocked do
  use Ecto.Migration

  def change do
    alter table(:map_systems) do
      remove :locked
    end
  end
end
