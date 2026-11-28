defmodule Ztripwire.Repo.Migrations.AddOwnerHashToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :owner_hash, :string
    end
  end
end
