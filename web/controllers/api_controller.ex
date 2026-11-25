defmodule TripwireWeb.ApiController do
  use TripwireWeb, :controller

  alias Tripwire.Mapping

  plug :require_api_token

  def signatures(conn, %{"mask_id" => mask_id}) do
    with {mask_id, ""} <- Integer.parse(mask_id),
         [%{id: map_id} | _] <- Mapping.list_maps_for_mask(mask_id) do
      systems = Mapping.list_systems(map_id)

      data =
        Enum.flat_map(systems, fn s ->
          Enum.map(Mapping.list_signatures(s.id), &sig_json(&1, s))
        end)

      json(conn, %{signatures: data})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "mask_id required"})
    end
  end

  def wormholes(conn, %{"mask_id" => mask_id}) do
    with {mask_id, ""} <- Integer.parse(mask_id),
         [map | _] <- Mapping.list_maps_for_mask(mask_id) do
      data =
        Enum.map(Mapping.list_connections_with_endpoints(map.id), fn {c, from, to} ->
          wormhole_json(c, from, to)
        end)

      json(conn, %{wormholes: data})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "mask_id required"})
    end
  end

  def comments(conn, %{"mask_id" => mask_id}) do
    with {mask_id, ""} <- Integer.parse(mask_id),
         [map | _] <- Mapping.list_maps_for_mask(mask_id) do
      systems = Mapping.list_systems(map.id)

      data =
        Enum.flat_map(systems, fn s ->
          Enum.map(Mapping.list_comments(s.id), &comment_json(&1, s))
        end)

      json(conn, %{comments: data})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "mask_id required"})
    end
  end

  def statistics(conn, %{"mask_id" => mask_id}) do
    with {mask_id, ""} <- Integer.parse(mask_id),
         [map | _] <- Mapping.list_maps_for_mask(mask_id) do
      json(conn, Mapping.map_statistics(map.id))
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "mask_id required"})
    end
  end

  defp require_api_token(conn, _opts) do
    expected = System.get_env("TRIPWIRE_API", Application.get_env(:tripwire, :api_token, ""))

    token =
      conn
      |> get_req_header("x-api-token")
      |> List.first() || conn.params["token"] || ""

    cond do
      expected in [nil, ""] ->
        conn |> put_status(:forbidden) |> json(%{error: "API disabled"}) |> halt()

      token == expected ->
        conn

      true ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid token"}) |> halt()
    end
  end

  defp sig_json(sig, system) do
    %{
      id: sig.sig_id,
      system: system.name,
      type: sig.site_type,
      name: sig.type_name,
      life_length: sig.life_length,
      updated_at: sig.updated_at
    }
  end

  defp wormhole_json(conn, from, to) do
    jumps = Mapping.list_connection_jumps(conn.id)

    %{
      id: conn.id,
      from: from.name,
      to: to.name,
      type: conn.hole_type,
      mass: conn.mass_status,
      time: conn.time_status,
      ship_size: conn.ship_size,
      jumps:
        Enum.map(jumps, &%{character: &1.character_name, ship: &1.ship_type, at: &1.inserted_at})
    }
  end

  defp comment_json(comment, system) do
    %{
      id: comment.id,
      system: system.name,
      body: comment.body,
      by: comment.character && comment.character.name
    }
  end
end
