defmodule Ztripwire.Mapping.Map do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ztripwire.Masks.Mask
  alias Ztripwire.Mapping.MapViewSystem

  schema "maps" do
    field :name, :string
    field :home_solar_system_id, :integer
    field :home_name, :string

    belongs_to :mask, Mask
    has_many :view_systems, MapViewSystem, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [
      :name,
      :mask_id,
      :home_solar_system_id,
      :home_name
    ])
    |> validate_required([:name, :mask_id])
  end
end
