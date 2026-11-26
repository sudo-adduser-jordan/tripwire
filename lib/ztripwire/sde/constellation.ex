defmodule Ztripwire.Sde.Constellation do
  use Ecto.Schema

  @primary_key {:constellation_id, :integer, autogenerate: false}
  schema "sde_constellations" do
    field :region_id, :integer
    field :name, :string
    field :faction_id, :integer
    field :wormhole_class_id, :integer
  end
end
