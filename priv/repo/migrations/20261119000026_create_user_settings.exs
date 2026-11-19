defmodule Tripwire.Repo.Migrations.CreateUserSettings do
  use Ecto.Migration

  def up do
    create table(:user_settings) do
      add :map_layout, :text, null: false, default: "top"
      add :show_row_guides, :boolean, null: false, default: false
      add :show_row_counts, :boolean, null: false, default: false
      add :angled_lines, :boolean, null: false, default: true
      add :show_jump_lines, :boolean, null: false, default: true
      add :show_line_glow, :boolean, null: false, default: true
      add :show_node_badges, :boolean, null: false, default: true
      add :line_weight, :integer, null: false, default: 2
      add :node_spacing, :integer, null: false, default: 100
      add :map_scale, :integer, null: false, default: 100
      add :map_background, :text
      add :grid_locked, :boolean, null: false, default: true
      add :widget_system, :boolean, null: false, default: true
      add :widget_notes, :boolean, null: false, default: true
      add :widget_signatures, :boolean, null: false, default: true
      add :widget_map, :boolean, null: false, default: true
      add :include_thera, :boolean, null: false, default: false
      add :show_all, :boolean, null: false, default: false
      add :chart_range, :text, null: false, default: "24h"
      add :chart_hidden, {:array, :text}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    execute("""
    INSERT INTO user_settings (id, inserted_at, updated_at)
    VALUES (1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    """)

    execute("""
    UPDATE user_settings
    SET include_thera = COALESCE((
          SELECT include_thera FROM maps
          WHERE mask_id IN (SELECT id FROM masks WHERE kind = 'personal')
          ORDER BY id
          LIMIT 1
        ), 0),
        show_all = COALESCE((
          SELECT show_all FROM maps
          WHERE mask_id IN (SELECT id FROM masks WHERE kind = 'personal')
          ORDER BY id
          LIMIT 1
        ), 0)
    WHERE id = 1
    """)

    alter table(:maps) do
      remove :include_thera
      remove :show_all
    end
  end

  def down do
    alter table(:maps) do
      add :include_thera, :boolean, null: false, default: false
      add :show_all, :boolean, null: false, default: false
    end

    execute("""
    UPDATE maps
    SET include_thera = COALESCE((SELECT include_thera FROM user_settings WHERE id = 1), 0),
        show_all = COALESCE((SELECT show_all FROM user_settings WHERE id = 1), 0)
    """)

    drop table(:user_settings)
  end
end
