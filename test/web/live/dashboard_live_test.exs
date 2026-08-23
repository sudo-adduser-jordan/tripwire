defmodule TripwireWeb.DashboardLiveTest do
  use TripwireWeb.ConnCase, async: false

  alias Tripwire.Accounts
  alias Tripwire.Mapping
  alias Tripwire.Masks

  setup do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 42_000, name: "Kariyo Astrien"})
    %{character: character}
  end

  defp login(conn, character) do
    Plug.Test.init_test_session(conn, %{
      "current_user" => %{"id" => character.eve_id, "name" => character.name}
    })
  end

  test "redirects anonymous visitors to the landing page", %{conn: conn} do
    conn = get(conn, ~p"/dashboard/Kariyo Astrien")
    assert redirected_to(conn) == "/"
  end

  test "mounts with session character and provisions a personal map", %{
    conn: conn,
    character: character
  } do
    {:ok, view, html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    assert html =~ "Kariyo Astrien"
    assert has_element?(view, "#grid-stack")

    mask = Masks.ensure_personal_mask(character) |> elem(1)
    [map] = Mapping.list_maps_for_mask(mask.id)
    assert map.name == "Home"
  end

  defp setup_with_system(%{character: character}, system_name) do
    {:ok, mask} = Masks.ensure_personal_mask(character)

    map =
      case Mapping.list_maps_for_mask(mask.id) do
        [] -> elem(Mapping.create_map(%{name: "Home", mask_id: mask.id}), 1)
        [existing | _] -> existing
      end

    {:ok, system} = Mapping.add_system_to_map(map, %{solar_system_id: 1, name: system_name})
    {mask, map, system}
  end

  test "paste flow imports signatures for a selected system", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    view |> element("button[phx-click='toggle-paste']") |> render_click()

    view
    |> element("#signatures textarea")
    |> render_change(%{value: "ABC-123\tCosmic Signature\tUnstable Wormhole (Z647)"})

    view |> element("button[phx-click='paste-submit']") |> render_click()

    html = render(view)
    assert html =~ "ABC-123"
    assert html =~ "Z647"

    assert [%Mapping.Signature{} = sig] = Mapping.list_signatures(system.id)
    assert sig.sig_id == "ABC-123"
    assert sig.type_name == "Unstable Wormhole (Z647)"
  end

  test "move-system persists dragged coordinates", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    assert html =~ ~s|id="chain-map"|
    assert html =~ "J150321"

    view
    |> render_click("move-system", %{
      "id" => Integer.to_string(system.id),
      "x" => "500",
      "y" => "300"
    })

    reloaded = Mapping.get_system!(system.id)
    assert reloaded.x == 500.0
    assert reloaded.y == 300.0
  end

  test "delete then undo restores the signature", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J000000")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    {:ok, sig} =
      Mapping.create_signature(system, %{sig_id: "XYZ-010"}, character)

    view
    |> element("#system-container button", "J000000")
    |> render_click()

    assert render(view) =~ "XYZ-010"

    view
    |> element("#signature-#{sig.id} button[phx-click='delete-signature']")
    |> render_click()

    refute render(view) =~ "XYZ-010"

    view |> element("button[phx-click='undo']") |> render_click()

    assert render(view) =~ "XYZ-010"
    assert [_restored] = Mapping.list_signatures(system.id)
  end
end
