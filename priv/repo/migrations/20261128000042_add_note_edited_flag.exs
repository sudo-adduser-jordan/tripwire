defmodule Ztripwire.Repo.Migrations.AddNoteEditedFlag do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :edited, :boolean, null: false, default: false
    end
  end
end
