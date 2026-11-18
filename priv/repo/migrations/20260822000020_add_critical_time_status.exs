defmodule Tripwire.Repo.Migrations.AddCriticalTimeStatus do
  use Ecto.Migration

  # Official Tripwire's wormhole "life" has three states: stable, critical,
  # and <1h. This port previously used "eol" as a stand-in for critical.
  def up do
    execute("UPDATE map_connections SET time_status = 'critical' WHERE time_status = 'eol'")
  end

  def down do
    execute("UPDATE map_connections SET time_status = 'eol' WHERE time_status = 'critical'")
  end
end
