defmodule Tripwire.Repo.Migrations.CreateMasks do
  use Ecto.Migration

  def change do
    create table(:masks) do
      add :name, :text, null: false
      add :kind, :text, null: false, default: "custom"
      add :eve_group_id, :integer
      add :owner_character_id, references(:characters, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:masks, [:owner_character_id])

    create unique_index(:masks, [:kind, :eve_group_id],
             where: "eve_group_id IS NOT NULL",
             name: :masks_kind_eve_group_id_index
           )
  end
end
