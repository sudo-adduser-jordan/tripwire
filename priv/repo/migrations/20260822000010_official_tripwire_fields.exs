defmodule Tripwire.Repo.Migrations.OfficialTripwireFields do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :corporation_name, :text
      add :alliance_name, :text
    end

    alter table(:masks) do
      add :owner_type, :text
      add :eve_owner_id, :integer
    end

    alter table(:signatures) do
      add :site_type, :text, default: "unknown"
      add :bookmark, :text
      add :life_length, :integer, default: 259_200
      add :expires_at, :utc_datetime
    end

    alter table(:map_connections) do
      add :parent, :text
    end

    alter table(:comments) do
      add :mask_id, references(:masks, on_delete: :delete_all)
    end

    create index(:comments, [:mask_id])
  end
end
