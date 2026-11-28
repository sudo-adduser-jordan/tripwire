defmodule Ztripwire.Repo.Migrations.DefaultShowRowGuides do
  use Ecto.Migration

  def up do
    execute("UPDATE user_settings SET show_row_guides = 1")
  end

  def down do
    execute("UPDATE user_settings SET show_row_guides = 0")
  end
end
