defmodule Tripwire.Sde.Faction do
  use Ecto.Schema

  @primary_key {:faction_id, :integer, autogenerate: false}
  schema "sde_factions" do
    field :name, :string
  end
end
