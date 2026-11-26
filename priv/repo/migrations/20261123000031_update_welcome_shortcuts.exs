defmodule Ztripwire.Repo.Migrations.UpdateWelcomeShortcuts do
  use Ecto.Migration

  def up do
    Ztripwire.Mapping.refresh_welcome_shortcuts()
  end

  def down do
    :ok
  end
end
