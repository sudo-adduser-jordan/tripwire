defmodule Tripwire.Repo.Migrations.AddWidgetLayoutToUserSettings do
  use Ecto.Migration

  def change do
    alter table(:user_settings) do
      add :widget_layout, :map
    end
  end
end
