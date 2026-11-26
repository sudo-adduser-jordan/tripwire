defmodule Ztripwire.Repo.Migrations.SeedWelcomeNotes do
  use Ecto.Migration

  def up do
    Ztripwire.Mapping.seed_welcome_notes()
  end

  def down do
    :ok
  end
end
