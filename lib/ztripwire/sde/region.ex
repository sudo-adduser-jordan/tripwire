defmodule Ztripwire.Sde.Region do
  use Ecto.Schema

  @primary_key {:region_id, :integer, autogenerate: false}
  schema "sde_regions" do
    field :name, :string
    field :faction_id, :integer
  end
end
