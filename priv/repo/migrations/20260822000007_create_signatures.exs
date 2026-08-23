defmodule Tripwire.Repo.Migrations.CreateSignatures do
  use Ecto.Migration

  def change do
    create table(:signatures) do
      add :map_system_id, references(:map_systems, on_delete: :delete_all), null: false
      add :sig_id, :text, null: false
      add :kind, :text, null: false, default: "signature"
      add :type_name, :text
      add :type_id, :integer
      add :created_by_id, references(:characters, on_delete: :nilify_all)
      add :updated_by_id, references(:characters, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:signatures, [:map_system_id, :sig_id])
    create index(:signatures, [:map_system_id])
  end
end
