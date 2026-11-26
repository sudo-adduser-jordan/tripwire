defmodule Ztripwire.Repo.Migrations.AddMapSystemHiddenAt do
  use Ecto.Migration

  def change do
    alter table(:map_systems) do
      add :hidden_at, :utc_datetime
    end
  end
end
