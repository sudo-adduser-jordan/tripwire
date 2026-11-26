defmodule Tripwire.Repo.Migrations.ResetRadialMapLayout do
  use Ecto.Migration

  def up do
    execute("UPDATE user_settings SET map_layout = 'top' WHERE map_layout = 'radial'")
  end

  def down do
    :ok
  end
end
