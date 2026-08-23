defmodule Tripwire.Repo.Migrations.CreateMaskMemberships do
  use Ecto.Migration

  def change do
    create table(:mask_memberships) do
      add :mask_id, references(:masks, on_delete: :delete_all), null: false
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mask_memberships, [:mask_id, :character_id])
    create index(:mask_memberships, [:character_id])
  end
end
