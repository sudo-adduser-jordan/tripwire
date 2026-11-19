defmodule Tripwire.Repo.Migrations.AddCriticalTimeStatus do
  use Ecto.Migration

  def up do
    execute("UPDATE map_connections SET time_status = 'critical' WHERE time_status = 'eol'")
  end

  def down do
    execute("UPDATE map_connections SET time_status = 'eol' WHERE time_status = 'critical'")
  end
end
