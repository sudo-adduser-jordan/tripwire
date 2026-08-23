defmodule Tripwire.Mapping.MapSystem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Mapping.{Comment, Map, Signature}

  schema "map_systems" do
    field :solar_system_id, :integer
    field :name, :string
    field :alias, :string
    field :x, :float, default: 0.0
    field :y, :float, default: 0.0
    field :locked, :boolean, default: false

    belongs_to :map, Map

    has_many :signatures, Signature, on_delete: :delete_all
    has_many :comments, Comment, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(map_system, attrs) do
    map_system
    |> cast(attrs, [:map_id, :solar_system_id, :name, :alias, :x, :y, :locked])
    |> validate_required([:map_id, :solar_system_id, :name])
  end
end
