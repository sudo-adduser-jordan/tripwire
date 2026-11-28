defmodule Ztripwire.Repo.Migrations.ScopeSettingsToCharacters do
  use Ecto.Migration

  def up do
    alter table(:user_settings) do
      add :character_id, references(:characters, on_delete: :delete_all)
    end

    create unique_index(:user_settings, [:character_id])

    drop unique_index(:layouts, [:name])

    alter table(:layouts) do
      add :owner_character_id, references(:characters, on_delete: :delete_all)
    end

    create unique_index(:layouts, [:owner_character_id, :name])

    execute("""
    UPDATE user_settings
    SET character_id = (SELECT id FROM characters ORDER BY id LIMIT 1)
    WHERE character_id IS NULL
      AND (SELECT COUNT(*) FROM characters) > 0
    """)

    execute("""
    UPDATE layouts
    SET owner_character_id = (SELECT id FROM characters ORDER BY id LIMIT 1)
    WHERE owner_character_id IS NULL
      AND (SELECT COUNT(*) FROM characters) > 0
    """)
  end

  def down do
    drop unique_index(:layouts, [:owner_character_id, :name])

    alter table(:layouts) do
      remove :owner_character_id
    end

    create unique_index(:layouts, [:name])

    drop unique_index(:user_settings, [:character_id])

    alter table(:user_settings) do
      remove :character_id
    end
  end
end
