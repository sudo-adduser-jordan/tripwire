defmodule Ztripwire.Repo.Migrations.AddNoteMetadata do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :sticky, :boolean, null: false, default: false
      add :updated_by_id, references(:characters, on_delete: :nilify_all)
    end

    create index(:comments, [:updated_by_id])
  end
end
