defmodule Ztripwire.Repo.Migrations.AddAutomapperToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :automapper, :boolean, null: false, default: true
    end
  end
end
