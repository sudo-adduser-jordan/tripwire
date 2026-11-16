defmodule Tripwire.Repo.Migrations.CharacterIsAdmin do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :is_admin, :boolean, default: false, null: false
    end
  end
end
