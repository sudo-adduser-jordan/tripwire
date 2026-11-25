defmodule Tripwire.Sde.Station do
  use Ecto.Schema

  @primary_key {:station_id, :integer, autogenerate: false}
  schema "sde_stations" do
    field :solar_system_id, :integer
    field :owner_id, :integer
    field :owner_name, :string
    field :operation, :string
    field :type_id, :integer
    field :type_name, :string
    field :services, {:array, :string}, default: []
  end
end
