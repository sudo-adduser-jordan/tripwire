defmodule Tripwire.Repo.Migrations.MapSystemClass do
  use Ecto.Migration

  def change do
    alter table(:map_systems) do
      add :security, :float
      add :sys_class, :text
    end
  end
end
