defmodule Tripwire.Repo.Migrations.CharacterStatCounters do
  use Ecto.Migration

  def up do
    alter table(:characters) do
      add :signatures_added, :integer, default: 0, null: false
      add :signatures_updated, :integer, default: 0, null: false
      add :signatures_deleted, :integer, default: 0, null: false
      add :wormholes_added, :integer, default: 0, null: false
      add :wormholes_updated, :integer, default: 0, null: false
      add :wormholes_deleted, :integer, default: 0, null: false
      add :comments_added, :integer, default: 0, null: false
      add :comments_updated, :integer, default: 0, null: false
      add :comments_deleted, :integer, default: 0, null: false
      add :systems_visited, :integer, default: 0, null: false
      add :login_count, :integer, default: 0, null: false
    end

    execute("""
    UPDATE characters SET
      signatures_added = (SELECT COUNT(*) FROM signatures WHERE created_by_id = characters.id),
      signatures_updated = (SELECT COUNT(*) FROM signatures WHERE updated_by_id = characters.id),
      wormholes_added = (SELECT COUNT(*) FROM signatures WHERE created_by_id = characters.id AND site_type = 'wormhole'),
      wormholes_updated = (SELECT COUNT(*) FROM signatures WHERE updated_by_id = characters.id AND site_type = 'wormhole'),
      comments_added = (SELECT COUNT(*) FROM comments WHERE character_id = characters.id)
    """)
  end

  def down do
    alter table(:characters) do
      remove :signatures_added
      remove :signatures_updated
      remove :signatures_deleted
      remove :wormholes_added
      remove :wormholes_updated
      remove :wormholes_deleted
      remove :comments_added
      remove :comments_updated
      remove :comments_deleted
      remove :systems_visited
      remove :login_count
    end
  end
end
