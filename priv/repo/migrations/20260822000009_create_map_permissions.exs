defmodule Tripwire.Repo.Migrations.CreateMapPermissions do
  use Ecto.Migration

  def change do
    create table(:map_permissions) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :mask_id, references(:masks, on_delete: :delete_all), null: false
      add :role, :text, null: false, default: "view"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:map_permissions, [:map_id, :mask_id])
  end
end
