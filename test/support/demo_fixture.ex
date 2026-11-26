defmodule Ztripwire.TestFixtures do
  alias Ztripwire.Mapping
  alias Ztripwire.Mapping.{Comment, Signature}
  alias Ztripwire.Masks
  alias Ztripwire.Repo

  def demo_mask do
    {:ok, mask} = Masks.create_mask(%{name: "Demo", kind: "demo"})
    mask
  end

  def seed_demo_map(mask) do
    state = Ztripwire.Demo.fixture()

    {:ok, map} =
      Mapping.create_map(%{
        name: "Demo",
        mask_id: mask.id,
        home_solar_system_id: 31_000_001,
        home_name: "J150321"
      })

    ids =
      Enum.reduce(state.systems, %{}, fn system, acc ->
        attrs = %{
          solar_system_id: system.solar_system_id,
          name: system.name,
          alias: system.alias,
          security: system.security,
          sys_class: system.sys_class,
          effect: system.effect,
          statics: system.statics,
          favorite: system.favorite,
          unknown: system.unknown,
          x: system.x,
          y: system.y
        }

        {:ok, inserted} = Mapping.add_system_to_map(map, attrs, fill?: false)
        Map.put(acc, system.id, inserted.id)
      end)

    Enum.each(state.connections, fn conn ->
      {:ok, _, _} =
        Mapping.upsert_connection(
          map.id,
          Map.fetch!(ids, conn.from_system_id),
          Map.fetch!(ids, conn.to_system_id),
          %{
            hole_type: conn.hole_type,
            mass_status: conn.mass_status,
            time_status: conn.time_status
          }
        )
    end)

    Enum.each(state.signatures, fn signature ->
      attrs = %{
        map_system_id: Map.fetch!(ids, signature.map_system_id),
        sig_id: signature.sig_id,
        kind: signature.kind,
        site_type: signature.site_type,
        type_name: signature.type_name,
        bookmark: signature.bookmark,
        life_length: signature.life_length
      }

      %Signature{}
      |> Signature.changeset(attrs)
      |> Repo.insert!()
    end)

    Enum.each(state.comments, fn comment ->
      attrs = %{
        map_system_id: Map.fetch!(ids, comment.map_system_id),
        mask_id: mask.id,
        body: comment.body
      }

      %Comment{}
      |> Comment.changeset(attrs)
      |> Repo.insert!()
    end)

    {:ok, map}
  end
end
