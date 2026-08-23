defmodule Tripwire.Mapping do
  import Ecto.Query

  alias Tripwire.Accounts.Character
  alias Tripwire.Mapping.{Map, MapConnection, MapSystem, Signature}
  alias Tripwire.Repo

  def get_map!(id), do: Repo.get!(Map, id)

  def list_maps_for_mask(mask_id) do
    Repo.all(from(m in Map, where: m.mask_id == ^mask_id))
  end

  def create_map(attrs) do
    %Map{}
    |> Map.changeset(attrs)
    |> Repo.insert()
  end

  def list_systems(map_id) do
    Repo.all(from(s in MapSystem, where: s.map_id == ^map_id, order_by: [asc: s.id]))
  end

  def get_system!(id), do: Repo.get!(MapSystem, id)

  def get_system(id), do: Repo.get(MapSystem, id)

  def list_connections(map_id) do
    Repo.all(
      from(c in MapConnection,
        where: c.map_id == ^map_id,
        preload: [:from_system, :to_system],
        order_by: [asc: c.id]
      )
    )
  end

  @doc """
  Finds a connection between two systems in either direction and updates it,
  or creates it if none exists. Returns {:ok, connection} and whether it is new.
  """
  def upsert_connection(map_id, system_a_id, system_b_id, attrs \\ %{}) do
    connection =
      Repo.one(
        from(c in MapConnection,
          where:
            c.map_id == ^map_id and
              ((c.from_system_id == ^system_a_id and c.to_system_id == ^system_b_id) or
                 (c.from_system_id == ^system_b_id and c.to_system_id == ^system_a_id))
        )
      )

    case connection do
      %MapConnection{} = conn ->
        {:ok, conn} =
          conn
          |> MapConnection.changeset(merge_attrs(attrs, %{map_id: conn.map_id}))
          |> Repo.update()

        {:ok, conn, false}

      nil ->
        changeset =
          %MapConnection{}
          |> MapConnection.changeset(
            merge_attrs(attrs, %{
              map_id: map_id,
              from_system_id: system_a_id,
              to_system_id: system_b_id
            })
          )

        case Repo.insert(changeset) do
          {:ok, conn} -> {:ok, Repo.preload(conn, [:from_system, :to_system]), true}
          error -> error
        end
    end
  end

  def add_system_to_map(%Map{} = map, attrs) do
    %MapSystem{map_id: map.id}
    |> MapSystem.changeset(attrs)
    |> Repo.insert()
  end

  def update_system_position(%MapSystem{} = system, x, y) do
    system
    |> Ecto.Changeset.change(x: x, y: y)
    |> Repo.update()
  end

  def list_signatures(system_id) do
    Repo.all(
      from(s in Signature,
        where: s.map_system_id == ^system_id,
        order_by: [asc: s.sig_id]
      )
    )
  end

  @doc """
  Inserts or updates signatures for a system from parsed scan results.

  Returns `{inserted, updated}` counts.
  """
  def upsert_signatures(%MapSystem{} = system, entries, %Character{id: character_id})
      when is_list(entries) do
    Enum.reduce(entries, {0, 0}, fn entry, {added, updated} ->
      attrs = %{
        map_system_id: system.id,
        sig_id: entry.sig_id,
        kind: to_string(entry.kind),
        type_name: entry.name || entry.wormhole_type,
        updated_by_id: character_id
      }

      existing = Repo.get_by(Signature, map_system_id: system.id, sig_id: entry.sig_id)

      result =
        case existing do
          %Signature{} = signature ->
            signature
            |> Signature.changeset(merge_attrs(attrs, %{created_by_id: signature.created_by_id}))
            |> Repo.update()

          nil ->
            %Signature{}
            |> Signature.changeset(merge_attrs(attrs, %{created_by_id: character_id}))
            |> Repo.insert()
        end

      case {result, existing} do
        {{:ok, _}, nil} -> {added + 1, updated}
        {{:ok, _}, _signature} -> {added, updated + 1}
        {{:error, _}, _} -> {added, updated}
      end
    end)
  end

  def create_signature(%MapSystem{} = system, attrs, %Character{id: character_id}) do
    %Signature{}
    |> Signature.changeset(
      merge_attrs(attrs, %{
        map_system_id: system.id,
        created_by_id: character_id,
        updated_by_id: character_id
      })
    )
    |> Repo.insert()
  end

  def update_signature(%Signature{} = signature, attrs, %Character{id: character_id}) do
    signature
    |> Signature.changeset(merge_attrs(attrs, %{updated_by_id: character_id}))
    |> Repo.update()
  end

  def delete_signature(%Signature{} = signature), do: Repo.delete(signature)

  def get_signature!(id), do: Repo.get!(Signature, id)

  defp merge_attrs(attrs, extra), do: Elixir.Map.merge(attrs, extra)
end
