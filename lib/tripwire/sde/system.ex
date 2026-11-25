defmodule Tripwire.Sde.System do
  use Ecto.Schema

  @primary_key {:solar_system_id, :integer, autogenerate: false}
  schema "sde_systems" do
    field :name, :string
    field :security, :float
    field :security_class, :string
    field :region_id, :integer
    field :constellation_id, :integer
    field :star_class, :string
    field :temperature, :float
    field :luminosity, :float
    field :radius, :float
    field :planet_count, :integer, default: 0
    field :moon_count, :integer, default: 0
    field :belt_count, :integer, default: 0
    field :station_count, :integer, default: 0
    field :effect, :string
    field :hub, :boolean, default: false
    field :border, :boolean, default: false
    field :corridor, :boolean, default: false
    field :regional, :boolean, default: false
    field :international, :boolean, default: false
    field :position_x, :float
    field :position_y, :float
  end
end
