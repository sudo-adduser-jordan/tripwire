defmodule Ztripwire.Sde.Type do
  use Ecto.Schema

  @primary_key {:type_id, :integer, autogenerate: false}
  schema "sde_types" do
    field :name, :string
    field :group_id, :integer
    field :group_name, :string
    field :category_id, :integer
    field :category_name, :string
  end
end
