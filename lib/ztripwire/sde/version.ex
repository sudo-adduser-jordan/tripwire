defmodule Ztripwire.Sde.Version do
  use Ecto.Schema

  @primary_key {:id, :integer, autogenerate: false}
  schema "sde_version" do
    field :build_number, :integer
    field :release_date, :string
    field :synced_at, :utc_datetime
  end
end
