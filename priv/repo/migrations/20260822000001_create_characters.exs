defmodule Tripwire.Repo.Migrations.CreateCharacters do
  use Ecto.Migration

  def change do
    create table(:characters) do
      add :eve_id, :integer, null: false
      add :name, :text, null: false
      add :corporation_id, :integer
      add :alliance_id, :integer
      add :scopes, {:array, :text}, default: []
      add :refresh_token, :binary
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:characters, [:eve_id])
  end
end
