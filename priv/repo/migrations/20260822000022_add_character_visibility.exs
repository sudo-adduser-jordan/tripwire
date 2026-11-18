defmodule Tripwire.Repo.Migrations.AddCharacterVisibility do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :ship_on_chain, :boolean, default: true, null: false
      add :character_on_chain, :boolean, default: true, null: false
    end
  end
end
