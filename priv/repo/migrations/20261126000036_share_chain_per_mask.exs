defmodule Ztripwire.Repo.Migrations.ShareChainPerMask do
  use Ecto.Migration

  def up do
    alter table(:map_systems) do
      add :mask_id, references(:masks, on_delete: :delete_all)
    end

    alter table(:map_connections) do
      add :mask_id, references(:masks, on_delete: :delete_all)
    end

    create table(:map_view_systems) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :map_system_id, references(:map_systems, on_delete: :delete_all), null: false
      add :x, :float, default: 0.0
      add :y, :float, default: 0.0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:map_view_systems, [:map_id, :map_system_id])
    create index(:map_view_systems, [:map_system_id])

    execute(
      "UPDATE map_systems SET mask_id = (SELECT mask_id FROM maps WHERE maps.id = map_systems.map_id)"
    )

    execute(
      "UPDATE map_connections SET mask_id = (SELECT mask_id FROM maps WHERE maps.id = map_connections.map_id)"
    )

    execute("""
    CREATE TEMP TABLE zt_system_remap AS
    SELECT id AS old_id,
           MIN(id) OVER (PARTITION BY mask_id, solar_system_id) AS new_id
    FROM map_systems
    WHERE unknown = 0 AND solar_system_id > 0
    """)

    execute("""
    UPDATE map_systems
    SET hidden_at = NULL
    WHERE id IN (
      SELECT r.new_id
      FROM zt_system_remap r
      JOIN map_systems s ON s.id = r.old_id
      WHERE s.hidden_at IS NULL
    )
    """)

    execute("""
    UPDATE map_systems
    SET favorite = 1
    WHERE id IN (
      SELECT r.new_id
      FROM zt_system_remap r
      JOIN map_systems s ON s.id = r.old_id
      WHERE s.favorite = 1
    )
    """)

    execute("""
    INSERT OR IGNORE INTO map_view_systems (map_id, map_system_id, x, y, inserted_at, updated_at)
    SELECT s.map_id, COALESCE(r.new_id, s.id), s.x, s.y, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM map_systems s
    LEFT JOIN zt_system_remap r ON r.old_id = s.id
    """)

    execute("""
    CREATE TEMP TABLE zt_connection_remap AS
    WITH mapped AS (
      SELECT c.id,
             c.mask_id,
             c.updated_at,
             COALESCE(rf.new_id, c.from_system_id) AS from_id,
             COALESCE(rt.new_id, c.to_system_id) AS to_id
      FROM map_connections c
      LEFT JOIN zt_system_remap rf ON rf.old_id = c.from_system_id
      LEFT JOIN zt_system_remap rt ON rt.old_id = c.to_system_id
    ),
    ranked AS (
      SELECT id,
             mask_id,
             from_id,
             to_id,
             FIRST_VALUE(id) OVER (
               PARTITION BY mask_id, MIN(from_id, to_id), MAX(from_id, to_id)
               ORDER BY updated_at DESC, id ASC
             ) AS survivor_id
      FROM mapped
    )
    SELECT id AS old_id, survivor_id, from_id, to_id
    FROM ranked
    """)

    execute("""
    UPDATE connection_jumps
    SET map_connection_id = (
      SELECT survivor_id FROM zt_connection_remap r
      WHERE r.old_id = connection_jumps.map_connection_id
    )
    WHERE map_connection_id IN (
      SELECT old_id FROM zt_connection_remap WHERE old_id != survivor_id
    )
    """)

    execute("""
    DELETE FROM map_connections
    WHERE id IN (
      SELECT old_id FROM zt_connection_remap WHERE old_id != survivor_id
    )
    """)

    execute("""
    UPDATE map_connections
    SET from_system_id = (
          SELECT from_id FROM zt_connection_remap r WHERE r.old_id = map_connections.id
        ),
        to_system_id = (
          SELECT to_id FROM zt_connection_remap r WHERE r.old_id = map_connections.id
        )
    WHERE id IN (
      SELECT old_id FROM zt_connection_remap WHERE old_id = survivor_id
    )
    """)

    execute("""
    UPDATE connection_jumps
    SET to_system_id = (
      SELECT new_id FROM zt_system_remap r WHERE r.old_id = connection_jumps.to_system_id
    )
    WHERE to_system_id IN (
      SELECT old_id FROM zt_system_remap WHERE old_id != new_id
    )
    """)

    execute("""
    UPDATE OR IGNORE signatures
    SET map_system_id = (
      SELECT new_id FROM zt_system_remap r WHERE r.old_id = signatures.map_system_id
    )
    WHERE map_system_id IN (
      SELECT old_id FROM zt_system_remap WHERE old_id != new_id
    )
    """)

    execute("""
    DELETE FROM signatures
    WHERE id NOT IN (SELECT MIN(id) FROM signatures GROUP BY map_system_id, sig_id)
    """)

    execute("""
    UPDATE comments
    SET map_system_id = (
      SELECT new_id FROM zt_system_remap r WHERE r.old_id = comments.map_system_id
    )
    WHERE map_system_id IN (
      SELECT old_id FROM zt_system_remap WHERE old_id != new_id
    )
    """)

    execute("""
    UPDATE flares
    SET map_system_id = (
      SELECT new_id FROM zt_system_remap r WHERE r.old_id = flares.map_system_id
    )
    WHERE map_system_id IN (
      SELECT old_id FROM zt_system_remap WHERE old_id != new_id
    )
    """)

    execute("""
    CREATE TEMP TABLE zt_stat_merge AS
    SELECT r.new_id AS map_system_id,
           SUM(s.jumps) AS jumps,
           SUM(s.kills) AS kills,
           SUM(s.visits) AS visits,
           MAX(s.recorded_at) AS recorded_at
    FROM system_stats s
    JOIN zt_system_remap r ON r.old_id = s.map_system_id
    GROUP BY r.new_id
    """)

    execute("""
    DELETE FROM system_stats
    WHERE map_system_id IN (SELECT new_id FROM zt_system_remap)
    """)

    execute("""
    INSERT INTO system_stats (map_system_id, jumps, kills, visits, recorded_at, inserted_at, updated_at)
    SELECT map_system_id, jumps, kills, visits, recorded_at, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM zt_stat_merge
    """)

    execute("""
    DELETE FROM map_systems
    WHERE id IN (SELECT old_id FROM zt_system_remap WHERE old_id != new_id)
    """)

    drop index(:map_systems, [:map_id])
    drop index(:map_systems, [:map_id, :solar_system_id])
    drop index(:map_connections, [:map_id])

    alter table(:map_systems) do
      remove :map_id
    end

    alter table(:map_connections) do
      remove :map_id
    end

    create index(:map_systems, [:mask_id])
    create index(:map_systems, [:mask_id, :solar_system_id])
    create index(:map_connections, [:mask_id])

    execute("""
    CREATE UNIQUE INDEX map_systems_mask_known_index
    ON map_systems (mask_id, solar_system_id)
    WHERE unknown = 0 AND solar_system_id > 0
    """)

    flush()

    Ztripwire.Mapping.seed_jita_systems()
    Ztripwire.Mapping.seed_welcome_notes()
    Ztripwire.Mapping.refresh_welcome_shortcuts()
  end

  def down do
    drop index(:map_systems, [:mask_id])
    drop index(:map_systems, [:mask_id, :solar_system_id])
    drop index(:map_connections, [:mask_id])
    execute("DROP INDEX IF EXISTS map_systems_mask_known_index")

    alter table(:map_systems) do
      add :map_id, references(:maps, on_delete: :delete_all)
    end

    alter table(:map_connections) do
      add :map_id, references(:maps, on_delete: :delete_all)
    end

    execute("""
    UPDATE map_systems
    SET map_id = (SELECT MIN(id) FROM maps WHERE maps.mask_id = map_systems.mask_id)
    """)

    execute("""
    UPDATE map_connections
    SET map_id = (SELECT MIN(id) FROM maps WHERE maps.mask_id = map_connections.mask_id)
    """)

    drop table(:map_view_systems)

    alter table(:map_systems) do
      remove :mask_id
    end

    alter table(:map_connections) do
      remove :mask_id
    end

    create index(:map_systems, [:map_id])
    create index(:map_systems, [:map_id, :solar_system_id])
    create index(:map_connections, [:map_id])
  end
end
