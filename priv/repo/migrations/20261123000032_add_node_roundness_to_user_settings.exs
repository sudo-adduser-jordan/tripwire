defmodule Ztripwire.Repo.Migrations.AddNodeRoundnessToUserSettings do
  use Ecto.Migration

  def change do
    alter table(:user_settings) do
      add :node_roundness, :text, null: false, default: "oval"
    end
  end
end
