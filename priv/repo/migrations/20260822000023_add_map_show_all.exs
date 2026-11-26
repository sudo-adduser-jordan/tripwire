defmodule Ztripwire.Repo.Migrations.AddMapShowAll do
  use Ecto.Migration

  def change do
    alter table(:maps) do
      add :show_all, :boolean, default: false, null: false
    end
  end
end
