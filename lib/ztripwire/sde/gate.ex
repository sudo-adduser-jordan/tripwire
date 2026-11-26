defmodule Ztripwire.Sde.Gate do
  use Ecto.Schema

  schema "sde_gates" do
    field :from_id, :integer
    field :to_id, :integer
  end
end
