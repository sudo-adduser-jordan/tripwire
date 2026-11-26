defmodule Ztripwire.Repo.Migrations.MapSystemEffect do
  use Ecto.Migration

  def change do
    alter table(:map_systems) do
      add :effect, :string
    end
  end
end
