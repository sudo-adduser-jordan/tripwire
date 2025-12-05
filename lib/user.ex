# defmodule Tripwire.Users do
#   use Ecto.Schema
#   import Ecto.Changeset

#   schema "users" do
#     field :name, :string
#     field :system, :string
#     field :corporation, :string

#     timestamps(type: :utc_datetime)
#   end

#   @doc false
#   def changeset(user, attrs) do
#     user
#     |> cast(attrs, [:title, :body])
#     |> validate_required([:title, :body])
#   end
# end
