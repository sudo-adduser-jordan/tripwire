defmodule Tripwire.Repo.Migrations.UpdateWelcomeShortcuts do
  use Ecto.Migration

  def up do
    Tripwire.Mapping.refresh_welcome_shortcuts()
  end

  def down do
    :ok
  end
end
