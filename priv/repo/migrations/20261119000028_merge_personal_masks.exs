defmodule Ztripwire.Repo.Migrations.MergePersonalMasks do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE masks
    SET name = 'Private',
        owner_character_id = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE kind = 'personal'
      AND id = (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    """)

    execute("""
    UPDATE maps
    SET mask_id = (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    WHERE mask_id IN (
      SELECT id FROM masks
      WHERE kind = 'personal'
        AND id != (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    )
    """)

    execute("""
    UPDATE comments
    SET mask_id = (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    WHERE mask_id IN (
      SELECT id FROM masks
      WHERE kind = 'personal'
        AND id != (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    )
    """)

    execute("""
    UPDATE flares
    SET mask_id = (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    WHERE mask_id IN (
      SELECT id FROM masks
      WHERE kind = 'personal'
        AND id != (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    )
    """)

    execute("""
    UPDATE OR IGNORE map_permissions
    SET mask_id = (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    WHERE mask_id IN (
      SELECT id FROM masks
      WHERE kind = 'personal'
        AND id != (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    )
    """)

    execute("""
    INSERT INTO mask_memberships (mask_id, character_id, inserted_at, updated_at)
    SELECT (SELECT MIN(id) FROM masks WHERE kind = 'personal'),
           mm.character_id,
           CURRENT_TIMESTAMP,
           CURRENT_TIMESTAMP
    FROM mask_memberships mm
    WHERE mm.mask_id IN (SELECT id FROM masks WHERE kind = 'personal')
      AND NOT EXISTS (
        SELECT 1
        FROM mask_memberships existing
        WHERE existing.mask_id = (SELECT MIN(id) FROM masks WHERE kind = 'personal')
          AND existing.character_id = mm.character_id
      )
    """)

    execute("""
    DELETE FROM masks
    WHERE kind = 'personal'
      AND id != (SELECT MIN(id) FROM masks WHERE kind = 'personal')
    """)
  end

  def down, do: :ok
end
