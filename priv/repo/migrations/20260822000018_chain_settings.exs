defmodule Ztripwire.Repo.Migrations.ChainSettings do
  use Ecto.Migration

  def change do
    alter table(:maps) do
      add :home_solar_system_id, :integer
      add :home_name, :text
      add :include_thera, :boolean, default: false, null: false
    end
  end
end
