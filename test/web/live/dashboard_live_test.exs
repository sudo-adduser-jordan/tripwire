defmodule TripwireWeb.DashboardLiveTest do
  use TripwireWeb.ConnCase, async: false

  alias Tripwire.Accounts
  alias Tripwire.Mapping
  alias Tripwire.Masks
  alias Tripwire.Repo

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

  test "demo mode mounts without a session and opens settings in the grid", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard/Admin")

    assert html =~ "Demo mode"
    assert has_element?(view, "#grid-stack")
    assert has_element?(view, "#grid-stack[phx-hook='GridStack']")
    assert has_element?(view, "#system-chart")
    assert has_element?(view, "#chain-map")

    view |> element("#settings-button") |> render_click()
    assert has_element?(view, "#grid-stack #settings-widget")
    assert render(view) =~ "Theme"

    view
    |> render_keydown("toggle-settings", %{"key" => "Escape"})

    refute has_element?(view, "#settings-widget")
  end

  test "demo mode provisions its own editable mask", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard/User")
    assert html =~ "Demo mode"

    [mask] = Repo.all(Masks.Mask)
    assert mask.kind == "demo"
    assert mask.name == "Demo"

    [map] = Repo.all(Mapping.Map)
    assert map.mask_id == mask.id
    assert length(Mapping.list_systems(map.id)) == 5

    assert html =~ "C3"
    assert html =~ "K162"

    system = hd(Mapping.list_systems(map.id))

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    assert_push_event(view, "reset-pan", %{x: 0, y: 0})
    assert Mapping.get_system!(system.id).x == 120.0
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

  test "add button opens a modal and creates a signature", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    refute render(view) =~ "sig-modal"

    view
    |> element("#signatures button[phx-click='open-add']")
    |> render_click()

    assert render(view) =~ "sig-modal"
    assert render(view) =~ "Add Signature"

    view
    |> element("#sig-modal form[phx-submit='save-signature']")
    |> render_submit(%{
      "sig" => %{"sig_id" => "QWE-123", "kind" => "signature", "site_type" => "wormhole"}
    })

    html = render(view)
    assert html =~ "QWE-123"
    refute html =~ "sig-modal"

    assert [%Mapping.Signature{sig_id: "QWE-123"}] = Mapping.list_signatures(system.id)
  end

  test "global paste imports signatures for a selected system", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "ABC-123\tCosmic Signature\tUnstable Wormhole (Z647)"
    })

    html = render(view)
    assert html =~ "ABC-123"
    assert html =~ "Z647"

    assert [%Mapping.Signature{} = sig] = Mapping.list_signatures(system.id)
    assert sig.sig_id == "ABC-123"
    assert sig.type_name == "Unstable Wormhole (Z647)"
  end

  test "global paste offers to delete signatures missing from the paste", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.create_signature(system, %{sig_id: "OLD-001"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    assert render(view) =~ "OLD-001"

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    html = render(view)
    assert html =~ "NEW-002"
    assert html =~ "stale-toast"
    assert html =~ "OLD-001"

    view |> element("#stale-toast button[phx-click='delete-stale']") |> render_click()

    html = render(view)
    assert html =~ "NEW-002"
    refute html =~ "OLD-001"
    refute html =~ "stale-toast"
    assert [%Mapping.Signature{sig_id: "NEW-002"}] = Mapping.list_signatures(system.id)
  end

  test "dismissing the stale toast keeps missing signatures", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.create_signature(system, %{sig_id: "OLD-001"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    assert render(view) =~ "stale-toast"

    view |> element("#stale-toast button[phx-click='dismiss-stale']") |> render_click()

    html = render(view)
    refute html =~ "stale-toast"
    assert html =~ "OLD-001"
    assert html =~ "NEW-002"
    assert length(Mapping.list_signatures(system.id)) == 2
  end

  test "global paste with no valid signatures changes nothing", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    view |> render_click("global-paste", %{"text" => "nothing to see here"})

    html = render(view)
    refute html =~ "stale-toast"
    assert Mapping.list_signatures(system.id) == []
  end

  test "reset zoom notifies the map to reset its pan", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 880.0, y: 612.0})

    {:ok, _link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    assert html =~ ~s|id="chain-map"|
    assert html =~ "J150321"

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    assert_push_event(view, "reset-pan", %{x: 0, y: 0})
  end

  test "header lock button toggles its icon without touching systems", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    assert render(view) =~ "hero-lock-closed"

    view
    |> element("#toggle-lock")
    |> render_click()

    assert render(view) =~ "hero-lock-open"

    view
    |> element("#toggle-lock")
    |> render_click()

    assert render(view) =~ "hero-lock-closed"
  end

  test "map renders toolbar and connections between systems", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    assert html =~ ~s|id="chain-map"|
    assert html =~ "Map"
    assert html =~ "connection-#{link.id}"
    assert html =~ "J150321"
    assert html =~ "J150322"

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    assert render(view) =~ "J150321"
  end

  test "map nodes show class above name with hole type below", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.update_system(system, %{sys_class: "C3"})

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, _link, _new?} =
      Mapping.upsert_connection(map.id, system.id, other.id, %{hole_type: "K162"})

    {:ok, _view, html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    [_, node_html] = String.split(html, ~s|<g id="node-#{system.id}"|, parts: 2)
    node_html = String.slice(node_html, 0, 2000)

    {class_pos, _} = :binary.match(node_html, "C3")
    {name_pos, _} = :binary.match(node_html, "J150321")
    {hole_pos, _} = :binary.match(node_html, "K162")
    assert class_pos < name_pos
    assert name_pos < hole_pos
  end

  test "nodes are color coded by system class", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.update_system(system, %{sys_class: "C3"})

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, _link, _new?} =
      Mapping.upsert_connection(map.id, system.id, other.id, %{hole_type: "K162"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150322")
    |> render_click()

    html = render(view)
    assert html =~ "chain-map"
    assert html =~ ~s|stroke="#4399F0"|
    assert html =~ ~s|fill="#4399F0"|
  end

  test "clicking a node's J-code opens the system editor and saves changes", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    refute render(view) =~ "sys-modal"

    view
    |> element("#chain-map text[phx-click='open-system']", "J150321")
    |> render_click()

    assert render(view) =~ "sys-modal"
    assert render(view) =~ "Edit System"

    view
    |> element("#sys-modal form[phx-submit='update-system']")
    |> render_submit(%{
      "system" => %{"alias" => "Home", "sys_class" => "C3"}
    })

    refute render(view) =~ "sys-modal"

    reloaded = Mapping.get_system!(system.id)
    assert reloaded.alias == "Home"
    assert reloaded.sys_class == "C3"
  end

  test "system editor rejects an unknown class and keeps the modal open", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#chain-map text[phx-click='open-system']", "J150321")
    |> render_click()

    html =
      view
      |> element("#sys-modal form[phx-submit='update-system']")
      |> render_submit(%{"system" => %{"alias" => "", "sys_class" => "C9"}})

    assert html =~ "sys-modal"
    assert html =~ "sys_class"
    assert Mapping.get_system!(system.id).sys_class == nil
  end

  test "clicking the star favorites the system and turns all stars yellow", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    refute render(view) =~ "hero-star-solid"

    view
    |> element("#system-favorite")
    |> render_click()

    html = render(view)
    assert html =~ "hero-star-solid"
    assert html =~ "text-amber-400"
    assert Mapping.get_system!(system.id).favorite

    view
    |> element("#show-favorite")
    |> render_click()

    html = render(view)
    refute html =~ "hero-star-solid"
    refute Mapping.get_system!(system.id).favorite
  end

  test "signature types render color coded badges", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{sig_id: "ABC-123", kind: "signature", site_type: "wormhole"},
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{sig_id: "DEF-456", kind: "signature", site_type: "combat"},
        character
      )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    html = render(view)
    assert html =~ "badge-info"
    assert html =~ "badge-error"
  end

  test "top bar renders ESI fallbacks and grid lock toggles", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard/User")

    assert html =~ "TQ"
    assert html =~ "Down"
    assert html =~ ~s|id="lock-button"|
    assert html =~ ~s|data-grid-locked="true"|

    view |> element("#lock-button") |> render_click()
    assert render(view) =~ ~s|data-grid-locked="false"|

    view |> element("#lock-button") |> render_click()
    assert render(view) =~ ~s|data-grid-locked="true"|
  end

  test "system search selects a matching system", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    html =
      view
      |> element(~s|nav form[phx-submit="system-search-submit"]|)
      |> render_submit(%{search: "j150321"})

    assert html =~ "J150321"
    assert render(view) =~ "J150321"
  end

  test "typing in system search sends nothing until submit", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard/User")

    refute html =~ ~s|phx-change="system-search"|
    assert html =~ ~s|phx-submit="system-search-submit"|
  end

  test "selecting a system reflects it in the topbar and system widget", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, _other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    assert html =~ ~s|id="system-copy"|
    assert view |> element("#topbar-system") |> render() =~ "J150321"
    assert view |> element("#system-container p") |> render() =~ "J150321"

    view
    |> element("#system-container button", "J150322")
    |> render_click()

    assert view |> element("#topbar-system") |> render() =~ "J150322"
    assert view |> element("#system-container p") |> render() =~ "J150322"

    copy_html = view |> element("#system-copy") |> render()
    assert copy_html =~ ~s|data-copy="J150322"|
    assert copy_html =~ "Copy J150322"
    refute copy_html =~ "disabled"

    for id <- ["#system-container", "#notes", "#signatures", "#chain-map", "#grid-stack"] do
      assert has_element?(view, id)
    end

    assert Mapping.get_system!(system.id).name == "J150321"
  end

  test "adding a note leaves signatures untouched", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, _sig} = Mapping.create_signature(system, %{sig_id: "ABC-123"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard/#{character.name}")

    view
    |> element("#system-container button", "J150321")
    |> render_click()

    view
    |> element(~s|#notes form[phx-submit="comment-submit"]|)
    |> render_submit(%{comment: "scouted"})

    html = render(view)
    assert html =~ "scouted"
    assert html =~ "1 notes"
    assert html =~ "ABC-123"
  end

  test "map-layout rearranges the tree", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/User")

    view |> element("#settings-button") |> render_click()

    html =
      view
      |> element(~s|#settings-widget form[phx-change="map-layout"]|)
      |> render_change(%{layout: "bottom"})

    assert html =~ "translate(460.0, 590.0)"
    refute html =~ "translate(460.0, 60.0)"
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
