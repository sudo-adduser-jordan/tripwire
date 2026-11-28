defmodule Ztripwire.Repo.Migrations.DefaultShowRowCounts do
  use Ecto.Migration

  def up do
    execute("UPDATE user_settings SET show_row_counts = 1")
  end

  def down do
    execute("UPDATE user_settings SET show_row_counts = 0")
  end
end
