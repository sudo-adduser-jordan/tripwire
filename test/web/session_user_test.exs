defmodule TripwireWeb.SessionUserTest do
  use ExUnit.Case, async: true

  alias TripwireWeb.SessionUser

  test "get/1 reads the canonical string keyed session" do
    assert SessionUser.get(%{"current_user" => %{"id" => 1, "name" => "Pilot"}}) ==
             %{id: 1, name: "Pilot"}
  end

  test "get/1 reads legacy sessions with nested atom keys" do
    assert SessionUser.get(%{"current_user" => %{id: 1, name: "Pilot"}}) ==
             %{id: 1, name: "Pilot"}

    assert SessionUser.get(%{current_user: %{id: 1, name: "Pilot"}}) ==
             %{id: 1, name: "Pilot"}
  end

  test "get/1 returns nil without a usable user" do
    assert SessionUser.get(%{}) == nil
    assert SessionUser.get(%{"current_user" => nil}) == nil
    assert SessionUser.get(%{"current_user" => %{"id" => 1}}) == nil
    assert SessionUser.get(nil) == nil
  end

  test "ids/1 reads both key styles" do
    assert SessionUser.ids(%{"character_ids" => [1, 2]}) == [1, 2]
    assert SessionUser.ids(%{character_ids: [3]}) == [3]
    assert SessionUser.ids(%{}) == []
  end

  test "put/2 writes the canonical session and merges ids" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Test.init_test_session(%{"character_ids" => [1]})
      |> SessionUser.put(%{eve_id: 2, name: "Pilot"})

    assert Plug.Conn.get_session(conn, "current_user") == %{"id" => 2, "name" => "Pilot"}
    assert Plug.Conn.get_session(conn, "character_ids") == [1, 2]
  end

  test "put/2 keeps a single id per character" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Test.init_test_session(%{"character_ids" => [2]})
      |> SessionUser.put(%{eve_id: 2, name: "Pilot"})

    assert Plug.Conn.get_session(conn, "character_ids") == [2]
  end
end
