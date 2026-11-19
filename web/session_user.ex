defmodule TripwireWeb.SessionUser do
  @user_keys ["current_user", :current_user]
  @ids_keys ["character_ids", :character_ids]

  def get(session) when is_map(session) do
    session |> fetch(@user_keys) |> normalize()
  end

  def get(_session), do: nil

  def ids(session) when is_map(session) do
    session |> fetch(@ids_keys) |> List.wrap()
  end

  def ids(_session), do: []

  def put(conn, %{eve_id: eve_id, name: name}) do
    ids =
      conn
      |> current_ids()
      |> List.wrap()
      |> Kernel.++([eve_id])
      |> Enum.uniq()

    conn
    |> Plug.Conn.put_session("current_user", %{"id" => eve_id, "name" => name})
    |> Plug.Conn.put_session("character_ids", ids)
  end

  defp current_ids(conn) do
    Enum.find_value(@ids_keys, &Plug.Conn.get_session(conn, &1))
  end

  defp fetch(session, keys), do: Enum.find_value(keys, &Map.get(session, &1))

  defp normalize(%{"id" => id, "name" => name}), do: %{id: id, name: name}
  defp normalize(%{id: id, name: name}), do: %{id: id, name: name}
  defp normalize(_user), do: nil
end
