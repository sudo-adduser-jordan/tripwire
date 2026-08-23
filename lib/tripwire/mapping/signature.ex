defmodule Tripwire.Mapping.Signature do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping.MapSystem

  @kinds ~w(anomaly signature)

  schema "signatures" do
    field :sig_id, :string
    field :kind, :string, default: "signature"
    field :type_name, :string
    field :type_id, :integer

    belongs_to :map_system, MapSystem
    belongs_to :created_by, Character, foreign_key: :created_by_id
    belongs_to :updated_by, Character, foreign_key: :updated_by_id

    timestamps(type: :utc_datetime)
  end

  def changeset(signature, attrs) do
    signature
    |> cast(attrs, [
      :map_system_id,
      :sig_id,
      :kind,
      :type_name,
      :type_id,
      :created_by_id,
      :updated_by_id
    ])
    |> validate_required([:map_system_id, :sig_id])
    |> update_change(:sig_id, &String.upcase/1)
    |> validate_format(:sig_id, ~r/^[A-Z]{3}-\d{3}$/)
    |> validate_inclusion(:kind, @kinds)
    |> unique_constraint([:map_system_id, :sig_id])
  end
end
