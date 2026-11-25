defmodule Tripwire.Mapping.MapSystem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Mapping.{Comment, Map, Signature}

  schema "map_systems" do
    field :solar_system_id, :integer
    field :name, :string
    field :alias, :string
    field :security, :float
    field :sys_class, :string
    field :effect, :string
    field :statics, {:array, :string}, default: []
    field :favorite, :boolean, default: false
    field :unknown, :boolean, default: false
    field :hidden_at, :utc_datetime
    field :x, :float, default: 0.0
    field :y, :float, default: 0.0

    belongs_to :map, Map

    has_many :signatures, Signature, on_delete: :delete_all
    has_many :comments, Comment, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(map_system, attrs) do
    map_system
    |> cast(attrs, [
      :map_id,
      :solar_system_id,
      :name,
      :alias,
      :security,
      :sys_class,
      :effect,
      :statics,
      :favorite,
      :unknown,
      :hidden_at,
      :x,
      :y
    ])
    |> validate_required([:map_id])
    |> require_known_fields()
    |> validate_number(:security, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_inclusion(:sys_class, Tripwire.Systems.classes() ++ [nil])
    |> validate_inclusion(:effect, Tripwire.Systems.effects() ++ [nil])
  end

  defp require_known_fields(changeset) do
    if get_field(changeset, :unknown) do
      changeset
    else
      validate_required(changeset, [:solar_system_id, :name])
    end
  end
end
