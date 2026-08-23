defmodule Tripwire.Repo.Migrations.CreateMaps do
  use Ecto.Migration

  def change do
    create table(:maps) do
      add :name, :text, null: false
      add :mask_id, references(:masks, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:maps, [:mask_id])
  end
end
