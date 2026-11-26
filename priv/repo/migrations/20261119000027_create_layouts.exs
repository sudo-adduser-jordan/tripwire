defmodule Ztripwire.Repo.Migrations.CreateLayouts do
  use Ecto.Migration

  def change do
    create table(:layouts) do
      add :name, :text, null: false
      add :widgets, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:layouts, [:name])

    alter table(:user_settings) do
      add :active_layout, :text
    end
  end
end
