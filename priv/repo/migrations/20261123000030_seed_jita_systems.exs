defmodule Ztripwire.Repo.Migrations.SeedJitaSystems do
  use Ecto.Migration

  def up do
    Ztripwire.Mapping.seed_jita_systems()
  end

  def down do
    :ok
  end
end
