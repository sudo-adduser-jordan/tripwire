defmodule Tripwire.Repo.Migrations.AddJumpsToConnections do
  use Ecto.Migration

  def change do
    alter table(:map_connections) do
      add :jumps, :integer
    end
  end
end
