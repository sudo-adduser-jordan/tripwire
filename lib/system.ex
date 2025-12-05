# defmodule Tripwire.System do
#   import Ecto.Query, warn: false
#   alias Tripwire.Repo

#   alias Tripwire.System

#   def list_systems do
#     Repo.all(System)
#   end

#   def get_system!(id), do: Repo.get!(System, id)

#   def create_system(attrs) do
#     %System{}
#     |> System.changeset(attrs)
#     |> Repo.insert()
#   end

#   def update_system(%System{} = post, attrs) do
#     post
#     |> System.changeset(attrs)
#     |> Repo.update()
#   end

#   def delete_system(%System{} = post) do
#     Repo.delete(post)
#   end

#   def change_system(%System{} = post, attrs \\ %{}) do
#     System.changeset(post, attrs)
#   end
# end
