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

  defp login_legacy(conn, character) do
    Plug.Test.init_test_session(conn, %{
      current_user: %{id: character.eve_id, name: character.name}
    })
  end

  test "anonymous visitors get the demo dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Demo mode"
    assert html =~ "Demo User"
  end

  test "demo mode explains missing SSO configuration", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Demo mode"
    assert html =~ "EVESSO_CLIENT_ID"
    refute html =~ "/auth/evesso"
  end

  test "demo mode shows the official SSO button when credentials exist", %{conn: conn} do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_SECRET_KEY", "test-secret")

    try do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Demo mode"
      assert html =~ "/auth/evesso"
      refute html =~ "EVESSO_CLIENT_ID"
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_SECRET_KEY")
    end
  end

  test "demo mode mounts without a session and opens settings in the grid", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Demo mode"
    assert has_element?(view, "#grid-stack")
    assert has_element?(view, "#grid-stack[phx-hook='GridStack']")
    assert has_element?(view, "#system-chart")
    assert has_element?(view, "#chain-map")

    view |> element("#settings-button") |> render_click()
    assert has_element?(view, "#grid-stack #settings-widget")
    assert render(view) =~ "Theme"
    assert render(view) =~ "←"

    view
    |> render_keydown("toggle-settings", %{"key" => "Escape"})

    refute has_element?(view, "#settings-widget")
    assert render(view) =~ "→"
  end

  test "logged in characters get their own map instead of the demo map", %{
    conn: conn,
    character: character
  } do
    {:ok, _view, html} = live(login(conn, character), ~p"/dashboard")

    refute html =~ "Demo mode"
    refute html =~ "Demo User"
    refute html =~ "J150321"
    assert html =~ character.name
    assert html =~ "Jita"
  end

  test "legacy sessions with nested atom keys still provision the character", %{
    conn: conn,
    character: character
  } do
    {:ok, _view, html} = live(login_legacy(conn, character), ~p"/dashboard")

    refute html =~ "Demo mode"
    refute html =~ "Demo User"
    assert html =~ character.name
  end

  test "a session user without a character row is sent home, not into the demo", %{conn: conn} do
    conn =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => 999_999, "name" => "Ghost"}
      })

    assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/dashboard")
    assert flash["error"] =~ "Session expired"
  end

  test "the first login asks to claim admin", %{conn: conn, character: character} do
    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ "No admin is configured"
    assert has_element?(view, "#claim-admin-modal")
    assert has_element?(view, "#claim-admin-banner")
  end

  test "deferring the admin prompt keeps the banner", %{conn: conn, character: character} do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#claim-admin-modal button", "Later") |> render_click()

    refute has_element?(view, "#claim-admin-modal")
    assert has_element?(view, "#claim-admin-banner")
    refute Accounts.get_character(character.id).is_admin
  end

  test "claiming admin promotes the character and unlocks mask administration", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    html = view |> element("#claim-admin-modal button", "Make admin") |> render_click()

    assert html =~ "You are now an admin"
    refute has_element?(view, "#claim-admin-modal")
    refute has_element?(view, "#claim-admin-banner")
    assert Accounts.get_character(character.id).is_admin

    view |> element("#settings-button") |> render_click()
    html = render_click(view, "settings-tab", %{"tab" => "admin"})
    assert html =~ "Mask administration"
  end

  test "non-admins see no prompt once an admin exists", %{conn: conn, character: character} do
    {:ok, _admin} = Accounts.upsert_character(%{eve_id: 43_000, name: "Existing", is_admin: true})

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    refute html =~ "No admin is configured"
    refute has_element?(view, "#claim-admin-modal")
    refute has_element?(view, "#claim-admin-banner")
  end

  test "claiming fails when another character became admin first", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, _faster} = Accounts.upsert_character(%{eve_id: 43_000, name: "Faster", is_admin: true})

    html = view |> element("#claim-admin-banner button") |> render_click()

    assert html =~ "An admin already exists"
    refute Accounts.get_character(character.id).is_admin
  end

  test "admins never see the admin prompt", %{conn: conn, character: character} do
    {:ok, admin} = Accounts.upsert_character(%{eve_id: character.eve_id, is_admin: true})

    {:ok, _view, html} = live(login(conn, admin), ~p"/dashboard")

    refute html =~ "No admin is configured"
  end

  test "widgets settings tab hides unchecked widgets and keeps the settings panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "widgets"})

    assert has_element?(view, "#toggle-widget-system")
    assert has_element?(view, "#toggle-widget-notes")
    assert has_element?(view, "#toggle-widget-signatures")
    assert has_element?(view, "#toggle-widget-map")
    refute has_element?(view, "#toggle-widget-settings")

    view |> element("#toggle-widget-notes") |> render_click()
    refute has_element?(view, "#notes")
    assert has_element?(view, "#system-container")
    assert has_element?(view, "#settings-widget")

    view |> element("#toggle-widget-notes") |> render_click()
    assert has_element?(view, "#notes")

    view |> element("#toggle-widget-map") |> render_click()
    refute has_element?(view, "#chain-map")
    refute has_element?(view, "#map")

    view |> element("#toggle-widget-system") |> render_click()
    refute has_element?(view, "#system-container")

    view |> element("#toggle-widget-signatures") |> render_click()
    refute has_element?(view, "#signatures")
  end

  test "demo wormhole signatures are labelled with their connection destination", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "J150322"
    assert html =~ "J150327"
    assert html =~ "J150329"
    refute html =~ "Unstable Wormhole (O477)"
    refute html =~ "Unstable Wormhole (Y683)"
    refute html =~ "Unstable Wormhole (N062)"
  end

  test "demo user is tracked at home in a Cenotaph", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Demo User"
    refute view |> element("nav") |> render() =~ "Cenotaph"
    refute has_element?(view, "div[title='Characters tracked on chain']")

    map_html = view |> element("#chain-map") |> render()
    assert map_html =~ "Demo User - Cenotaph"
    assert map_html =~ "characters/9000002/portrait"
    assert has_element?(view, "#chain-map title", "Demo User - Cenotaph")
  end

  test "hiding the demo user on chain clears their occupancy badge", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")
    assert view |> element("#chain-map") |> render() =~ "Demo User"

    [character] = Enum.filter(Accounts.list_characters(), &(&1.name == "Demo User"))

    view
    |> element("button[phx-click='toggle-character-visibility'][phx-value-id='#{character.id}']")
    |> render_click()

    refute view |> element("#chain-map") |> render() =~ "Demo User"
  end

  test "demo mode provisions its own editable mask", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Demo mode"

    [mask] = Repo.all(Masks.Mask)
    assert mask.kind == "demo"
    assert mask.name == "Demo"

    [map] = Repo.all(Mapping.Map)
    assert map.mask_id == mask.id
    assert length(Mapping.list_systems(map.id)) == 27
    assert Enum.count(Mapping.list_systems(map.id), & &1.unknown) == 2

    assert html =~ "C3"
    assert html =~ "ABC-123"

    system = hd(Mapping.list_systems(map.id))

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    home =
      map.id
      |> Mapping.list_systems()
      |> Enum.find(&(&1.solar_system_id == map.home_solar_system_id))

    assert_push_event(view, "reset-pan", %{x: x, y: 20.0})
    assert_in_delta x, home.x + elem(Mapping.node_size(), 0) / 2 - 625.0, 0.001
    assert render(view) =~ "1250.0 875.0"

    reloaded = Mapping.get_system!(system.id)
    assert reloaded.y == 60.0
    assert is_number(reloaded.x)
  end

  test "mounts with session character and provisions a personal map", %{
    conn: conn,
    character: character
  } do
    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ "Kariyo Astrien"
    assert has_element?(view, "#grid-stack")

    mask = Masks.ensure_personal_mask(character) |> elem(1)
    [map] = Mapping.list_maps_for_mask(mask.id)
    assert map.name == "Home"
  end

  test "visibility toggles persist per character", %{conn: conn, character: character} do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("button[phx-click='toggle-ship-visibility'][phx-value-id='#{character.id}']")
    |> render_click()

    assert %{ship_on_chain: false, character_on_chain: true} =
             Accounts.get_character(character.id)

    assert render(view) =~ "ship is hidden on chain"

    view
    |> element("button[phx-click='toggle-character-visibility'][phx-value-id='#{character.id}']")
    |> render_click()

    assert %{ship_on_chain: false, character_on_chain: false} =
             Accounts.get_character(character.id)

    assert render(view) =~ "character and ship are hidden on chain"

    view
    |> element("button[phx-click='toggle-character-visibility'][phx-value-id='#{character.id}']")
    |> render_click()

    assert %{ship_on_chain: false, character_on_chain: true} =
             Accounts.get_character(character.id)
  end

  test "character dropdown toggles from its large icons and switches from the name", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    nav = view |> element("nav") |> render()

    assert nav =~ ~r/toggle-ship-visibility.*toggle-character-visibility.*\/auth\/switch/s
    refute nav =~ "size-4 rounded-full"

    assert has_element?(
             view,
             "button[phx-click='toggle-ship-visibility'][phx-value-id='#{character.id}']"
           )

    assert has_element?(
             view,
             "button[phx-click='toggle-character-visibility'][phx-value-id='#{character.id}'] img"
           )

    assert has_element?(
             view,
             "nav a[href='/auth/switch/#{character.eve_id}']"
           )
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

  defp column_keys(html) do
    ~r/data-column="([a-z]+)"/
    |> Regex.scan(html, capture: :all_but_first)
    |> List.flatten()
  end

  defp at(html, text) do
    {position, _length} = :binary.match(html, text)
    position
  end

  test "unknown placeholder nodes render empty fields and stay out of the system list", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, placeholder} = Mapping.add_unknown_system(map)

    {:ok, _, _} =
      Mapping.upsert_connection(map.id, system.id, placeholder.id, %{hole_type: "N770"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    node = view |> element("#node-#{placeholder.id}") |> render()
    refute node =~ ~r/>\s*C[1-6]\s*</
    refute node =~ ~r/>\s*J\d+\s*</
    refute node =~ "Unstable Wormhole"

    container = view |> element("#system-container") |> render()
    refute container =~ ~s|Select system "|
  end

  test "add button opens a modal and creates a signature", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
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

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "ABC-123\tCosmic Signature\tUnstable Wormhole (Z647)"
    })

    html = render(view)
    assert html =~ "ABC-123"
    assert html =~ "Unstable Wormhole (Z647)"

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

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
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

  test "confirming the stale toast drops wormhole connections and hides orphan nodes", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, neighbour} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, lone} = Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, system.id, neighbour.id, %{hole_type: "O477"})

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{
          sig_id: "ABC-123",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (O477)"
        },
        character
      )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    assert render(view) =~ "stale-toast"

    view |> element("#stale-toast button[phx-click='delete-stale']") |> render_click()

    html = render(view)
    refute html =~ "stale-toast"
    refute html =~ "ABC-123"

    assert Mapping.connection_between(map.id, system.id, neighbour.id) == nil

    assert %Mapping.MapSystem{hidden_at: hidden} = Mapping.get_system!(neighbour.id)
    refute is_nil(hidden)
    assert is_nil(Mapping.get_system!(lone.id).hidden_at)

    assert html =~ "J150323"
    refute html =~ "J150322"
  end

  test "removing missing signatures hides chains detached from home", %{
    conn: conn,
    character: character
  } do
    {_mask, map, home} = setup_with_system(%{character: character}, "J150321")
    {:ok, map} = Mapping.update_map(map, %{home_solar_system_id: 1, home_name: "J150321"})
    {:ok, branch} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, leaf} = Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323"})

    {:ok, home_link, _} =
      Mapping.upsert_connection(map.id, home.id, branch.id, %{hole_type: "N770"})

    {:ok, branch_link, _} =
      Mapping.upsert_connection(map.id, branch.id, leaf.id, %{hole_type: "B274"})

    {:ok, _} =
      Mapping.create_signature(
        home,
        %{
          sig_id: "AAA-123",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        branch,
        %{
          sig_id: "BBB-456",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    assert render(view) =~ "stale-toast"

    view |> element("#stale-toast button[phx-click='delete-stale']") |> render_click()

    assert Mapping.connection_between(map.id, home.id, branch.id) == nil
    assert Mapping.connection_between(map.id, branch.id, leaf.id) != nil
    refute is_nil(Mapping.get_system!(branch.id).hidden_at)
    assert is_nil(Mapping.get_system!(home.id).hidden_at)
    assert Mapping.list_signatures(home.id) |> Enum.map(& &1.sig_id) == ["NEW-002"]
    assert Mapping.list_signatures(branch.id) == []

    html = render(view)
    assert html =~ "J150321"
    refute html =~ "J150322"
    refute html =~ "J150323"

    refute has_element?(view, "#connection-#{home_link.id}")
    refute has_element?(view, "#connection-#{branch_link.id}")
  end

  test "loop connections keep their glow without drawing the closing edge", %{
    conn: conn,
    character: character
  } do
    {_mask, map, home} = setup_with_system(%{character: character}, "J150321")
    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323"})

    {:ok, first, _} = Mapping.upsert_connection(map.id, home.id, a.id)
    {:ok, second, _} = Mapping.upsert_connection(map.id, a.id, b.id)
    {:ok, closing, _} = Mapping.upsert_connection(map.id, b.id, home.id)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    connections = Mapping.list_connections_with_endpoints(map.id)
    assert [cycle_id] = Mapping.cycle_connection_ids(connections) |> MapSet.to_list()
    assert cycle_id == closing.id
    assert cycle_id > first.id and cycle_id > second.id

    refute has_element?(view, "#connection-#{cycle_id}")
    assert has_element?(view, "#connection-#{first.id}")
    assert has_element?(view, "#connection-#{second.id}")

    assert view |> element("#node-#{home.id}") |> render() =~ "6 4"
    assert view |> element("#node-#{b.id}") |> render() =~ "6 4"
    refute view |> element("#node-#{a.id}") |> render() =~ "6 4"
  end

  test "pasting a linking scan keeps the tree positions and only hints the loop", %{
    conn: conn,
    character: character
  } do
    {_mask, map, home} = setup_with_system(%{character: character}, "J150321")
    {:ok, map} = Mapping.update_map(map, %{home_solar_system_id: 1, home_name: "J150321"})

    {:ok, a} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, b} = Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323"})
    {:ok, jita} = Mapping.add_system_to_map(map, %{solar_system_id: 4, name: "J150324"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, home.id, a.id, %{hole_type: "N770"})
    {:ok, _, _} = Mapping.upsert_connection(map.id, a.id, b.id, %{hole_type: "B274"})
    {:ok, _, _} = Mapping.upsert_connection(map.id, b.id, jita.id, %{hole_type: "A641"})

    {:ok, _} =
      Mapping.create_signature(
        jita,
        %{
          sig_id: "TUV-679",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (M555)"
        },
        character
      )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    before = Map.new([home.id, a.id, b.id, jita.id], &{&1, Mapping.get_system!(&1)})

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "TUV-679\tCosmic Signature\tUnstable Wormhole (M555)\t100.00%\t1.21 AU"
    })

    for id <- [home.id, a.id, b.id, jita.id] do
      system = Mapping.get_system!(id)
      assert {system.x, system.y} == {before[id].x, before[id].y}
    end

    link = Mapping.connection_between(map.id, home.id, jita.id)
    assert %Mapping.MapConnection{} = link
    refute has_element?(view, "#connection-#{link.id}")

    assert view |> element("#node-#{home.id}") |> render() =~ "6 4"
    assert view |> element("#node-#{jita.id}") |> render() =~ "6 4"
    refute view |> element("#node-#{a.id}") |> render() =~ "6 4"
  end

  test "pasting wormhole signatures auto-links systems sharing the scan", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, jita} = Mapping.add_system_to_map(map, %{solar_system_id: 30_000_142, name: "J150099"})

    {:ok, _} =
      Mapping.create_signature(
        jita,
        %{
          sig_id: "TUV-679",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (M555)"
        },
        character
      )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "TUV-679\tCosmic Signature\tUnstable Wormhole (M555)\t100.00%\t1.21 AU"
    })

    assert %Mapping.MapConnection{hole_type: "M555"} =
             connection =
             Mapping.connection_between(map.id, system.id, jita.id)

    assert render(view) =~ "connection-#{connection.id}"
  end

  test "dismissing the stale toast keeps missing signatures", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.create_signature(system, %{sig_id: "OLD-001"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
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

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view |> render_click("global-paste", %{"text" => "nothing to see here"})

    html = render(view)
    refute html =~ "stale-toast"
    assert Mapping.list_signatures(system.id) == []
  end

  test "reset zoom notifies the map to reset its pan", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, map} = Mapping.update_map(map, %{home_solar_system_id: 1, home_name: "J150321"})

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 880.0, y: 612.0})

    {:ok, _link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ ~s|id="chain-map"|
    assert html =~ "J150321"

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    home =
      map.id
      |> Mapping.list_systems()
      |> Enum.find(&(&1.solar_system_id == map.home_solar_system_id))

    assert_push_event(view, "reset-pan", %{x: x, y: 20.0})
    assert_in_delta x, home.x + elem(Mapping.node_size(), 0) / 2 - 625.0, 0.001
  end

  test "reset zoom without a home falls back to the top-left pan", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    assert_push_event(view, "reset-pan", %{x: 0, y: 20.0})
  end

  test "header lock button toggles server-side and yellows when locked", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ ~s|id="toggle-lock"|
    assert html =~ "hero-lock-open"

    view |> element("#toggle-lock") |> render_click()
    html = render(view)
    assert html =~ "hero-lock-closed"
    assert html =~ "text-amber-400"
    assert html =~ ~s|data-locked="true"|

    view |> element("#toggle-lock") |> render_click()
    assert render(view) =~ "hero-lock-open"
  end

  test "map renders toolbar and connections between systems", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ ~s|id="chain-map"|
    assert html =~ "Map"
    assert html =~ "connection-#{link.id}"
    assert html =~ "J150321"
    assert html =~ "J150322"

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    assert render(view) =~ "J150321"
  end

  test "map nodes show class above name with signature code below", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.update_system(system, %{sys_class: "C3"})

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, _link, _new?} =
      Mapping.upsert_connection(map.id, system.id, other.id, %{hole_type: "K162"})

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{
          sig_id: "AAA-111",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (K162)"
        },
        character
      )

    {:ok, _view, html} = live(login(conn, character), ~p"/dashboard")

    [_, node_html] = String.split(html, ~s|<g id="node-#{system.id}"|, parts: 2)
    node_html = String.slice(node_html, 0, 2000)

    {class_pos, _} = :binary.match(node_html, "C3")
    {name_pos, _} = :binary.match(node_html, "J150321")
    {sig_pos, _} = :binary.match(node_html, "AAA-111")
    assert class_pos < name_pos
    assert name_pos < sig_pos
    refute node_html =~ "K162"
  end

  test "clicking a node's J-code opens the system editor and saves changes", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

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

  test "j-space nodes show static badges on the bottom edge", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.update_system(system, %{sys_class: "C1"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    html = render(view)
    assert html =~ "Static wormhole: HS"
    assert html =~ "Statics"
  end

  test "system editor saves the wormhole effect and badges it", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#chain-map text[phx-click='open-system']", "J150321")
    |> render_click()

    assert render(view) =~ "sys-modal"

    view
    |> element("#sys-modal form[phx-submit='update-system']")
    |> render_submit(%{
      "system" => %{"alias" => "", "sys_class" => "C2", "effect" => "Pulsar"}
    })

    refute render(view) =~ "sys-modal"

    reloaded = Mapping.get_system!(system.id)
    assert reloaded.effect == "Pulsar"
    assert render(view) =~ "data-effect=\"Pulsar\""
    assert render(view) =~ "System effect: Pulsar"
  end

  test "system editor rejects an unknown effect and keeps the modal open", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#chain-map text[phx-click='open-system']", "J150321")
    |> render_click()

    html =
      view
      |> element("#sys-modal form[phx-submit='update-system']")
      |> render_submit(%{"system" => %{"alias" => "", "sys_class" => "C2", "effect" => "Bogus"}})

    assert html =~ "sys-modal"
    assert html =~ "effect"
    assert Mapping.get_system!(system.id).effect == nil
  end

  test "system editor rejects an unknown class and keeps the modal open", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

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

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    refute render(view) =~ "hero-star-solid"

    view
    |> element("#system-favorite")
    |> render_click()

    html = render(view)
    assert html =~ "hero-star-solid"
    assert html =~ "text-amber-400"
    assert Mapping.get_system!(system.id).favorite

    assert render(view) =~ "favorites-list"

    view
    |> element("#show-favorite")
    |> render_click()

    html = render(view)
    assert html =~ "hero-star-solid"
    assert Mapping.get_system!(system.id).favorite
  end

  test "system widget lists only the selected system and its connections", %{
    conn: conn,
    character: character
  } do
    {_mask, map, first} = setup_with_system(%{character: character}, "J150321")

    {:ok, second} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, _other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323", x: 600.0, y: 200.0})

    {:ok, _link, _new?} = Mapping.upsert_connection(map.id, first.id, second.id)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    container = view |> element("#system-container") |> render()
    assert container =~ "J150321"
    assert container =~ "J150322"
    refute container =~ "J150323"

    view
    |> element("#system-container button[title='Select system J150322']")
    |> render_click()

    container = view |> element("#system-container") |> render()
    assert container =~ "J150321"
    assert container =~ "J150322"
    refute container =~ "J150323"
  end

  test "default layout arranges the tree from the top", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 0.0, y: 300.0})

    {:ok, _link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#settings-button")
    |> render_click()

    view
    |> element(~s|#settings-widget form[phx-change="map-layout"]|)
    |> render_change(%{"layout" => "default"})

    assert Mapping.get_system!(system.id).y == 60.0
    assert Mapping.get_system!(other.id).y == 220.0
  end

  test "map settings toggles jump lines and node badges", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.update_system(system, %{sys_class: "C1"})

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ ~s|id="map-edges"|
    assert html =~ "Static wormhole:"

    view |> element("#settings-button") |> render_click()

    html =
      view
      |> element("#toggle-jump-lines")
      |> render_click()

    refute html =~ ~s|id="map-edges"|

    html =
      view
      |> element("#toggle-node-badges")
      |> render_click()

    refute html =~ "Static wormhole:"
  end

  test "map settings line weight changes edge width", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})

    {:ok, _link, _new?} =
      Mapping.upsert_connection(map.id, system.id, other.id, %{hole_type: "B274"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    html =
      view
      |> element(~s|#settings-widget form[phx-change="line-weight"]|)
      |> render_change(%{weight: "4"})

    assert html =~ ~s|stroke-width="5"|
  end

  test "map settings background sets the map backdrop", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    html =
      view
      |> element(~s|#settings-widget form[phx-change="map-background"]|)
      |> render_change(%{background: "https://example.com/map-bg.jpg"})

    assert html =~ "background-image"
    assert html =~ "https://example.com/map-bg.jpg"
  end

  test "map settings node spacing relays out the tree", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322", x: 300.0, y: 200.0})

    {:ok, _link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    assert Mapping.get_system!(other.id).y == 220.0

    view |> element("#settings-button") |> render_click()

    view
    |> element(~s|#settings-widget form[phx-change="node-spacing"]|)
    |> render_change(%{spacing: "200"})

    assert Mapping.get_system!(other.id).y == 380.0
  end

  test "map settings scale pushes a zoom event", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    view
    |> element(~s|#settings-widget form[phx-change="map-scale"]|)
    |> render_change(%{scale: "150"})

    assert_push_event(view, "map-zoom", %{zoom: 1.5})
  end

  test "top bar renders ESI fallbacks and grid lock toggles", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Down"
    assert html =~ "sticky"
    assert html =~ ~s|id="lock-button"|
    assert html =~ ~s|data-grid-locked="true"|

    view |> element("#lock-button") |> render_click()
    assert render(view) =~ ~s|data-grid-locked="false"|

    view |> element("#lock-button") |> render_click()
    assert render(view) =~ ~s|data-grid-locked="true"|
  end

  test "system search selects a matching system", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    html =
      view
      |> element(~s|nav form[phx-submit="system-search-submit"]|)
      |> render_submit(%{search: "j150321"})

    assert html =~ "J150321"
    assert render(view) =~ "J150321"
  end

  test "typing in system search sends nothing until submit", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    refute html =~ ~s|phx-change="system-search"|
    assert html =~ ~s|phx-submit="system-search-submit"|
  end

  test "selecting a system reflects it in the topbar and system widget", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other} =
      Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})

    {:ok, _link, _new?} = Mapping.upsert_connection(map.id, system.id, other.id)

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ ~s|id="system-copy"|
    assert view |> element("#topbar-system") |> render() =~ "J150321"
    assert view |> element("#system-copy") |> render() =~ "J150321"

    view
    |> element("#system-container button[title='Select system J150322']")
    |> render_click()

    assert view |> element("#topbar-system") |> render() =~ "J150322"
    assert view |> element("#system-copy") |> render() =~ "J150322"

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

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> element(~s|#notes form[phx-submit="comment-submit"]|)
    |> render_submit(%{comment: "scouted"})

    html = render(view)
    assert html =~ "<textarea"
    assert html =~ "scouted"
    assert html =~ "1 notes"
    assert html =~ "ABC-123"
  end

  test "notes can be edited inline without leaving their system", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, comment} = Mapping.create_comment(system, %{body: "first draft"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    refute has_element?(view, "#comment-#{comment.id} textarea")

    view |> element("#note-edit-#{comment.id}") |> render_click()

    assert view |> element("#comment-#{comment.id} textarea") |> render() =~ "first draft"

    view |> element("#note-edit-cancel-#{comment.id}") |> render_click()
    refute has_element?(view, "#comment-#{comment.id} textarea")
    assert render(view) =~ "first draft"

    view |> element("#note-edit-#{comment.id}") |> render_click()

    view
    |> element("#comment-#{comment.id} form[phx-submit='comment-edit-submit']")
    |> render_submit(%{comment: "second draft"})

    html = render(view)
    assert html =~ "second draft"
    refute html =~ "first draft"
    assert html =~ "1 notes"
    refute has_element?(view, "#comment-#{comment.id} textarea")

    assert %{body: "second draft", map_system_id: map_system_id} =
             Mapping.get_comment!(comment.id)

    assert map_system_id == system.id
  end

  test "chain settings show all reveals detached chains at level 0", %{
    conn: conn,
    character: character
  } do
    {_mask, map, home} = setup_with_system(%{character: character}, "J150321")
    {:ok, map} = Mapping.update_map(map, %{home_solar_system_id: 1, home_name: "J150321"})

    {:ok, child} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, detached} = Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323"})
    {:ok, lone} = Mapping.add_system_to_map(map, %{solar_system_id: 4, name: "J150324"})

    {:ok, _, _} = Mapping.upsert_connection(map.id, home.id, child.id, %{hole_type: "ABC"})

    hidden_at = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, _} = Mapping.update_system(detached, %{hidden_at: hidden_at})
    {:ok, _} = Mapping.update_system(lone, %{hidden_at: hidden_at})

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    refute html =~ "J150323"
    refute html =~ "J150324"

    view |> element("#chain-edit") |> render_click()

    assert render(view) =~ "Show all chains"

    view
    |> element("#chain-modal form[phx-submit='save-chain-settings']")
    |> render_submit(%{"chain" => %{"home" => "J150321", "show_all" => "true"}})

    html = render(view)
    assert html =~ "J150323"
    assert html =~ "J150324"
    assert Mapping.get_map!(map.id).show_all

    assert Mapping.get_system!(home.id).y == 60.0
    assert Mapping.get_system!(child.id).y == 220.0
    assert Mapping.get_system!(detached.id).y == 60.0
    assert Mapping.get_system!(lone.id).y == 60.0

    xs = Enum.map([home, detached, lone], &Mapping.get_system!(&1.id).x)
    assert xs == Enum.uniq(xs)
  end

  test "layout reloads connections so edges follow the new node positions", %{
    conn: conn,
    character: character
  } do
    {_mask, map, home} = setup_with_system(%{character: character}, "J150321")
    {:ok, child} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, link, _} = Mapping.upsert_connection(map.id, home.id, child.id)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    view
    |> element(~s|#settings-widget form[phx-change="map-layout"]|)
    |> render_change(%{layout: "bottom"})

    home = Mapping.get_system!(home.id)
    child = Mapping.get_system!(child.id)

    path = view |> element("#connection-#{link.id}") |> render()
    {node_w, node_h} = Mapping.node_size()

    assert path =~ "M #{home.x + node_w / 2} #{home.y + node_h / 2}"
    assert path =~ "L #{child.x + node_w / 2} #{child.y + node_h / 2}"
  end

  test "map-layout rearranges the tree", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    view
    |> element(~s|#settings-widget form[phx-change="map-layout"]|)
    |> render_change(%{layout: "bottom"})

    map = Repo.one(Mapping.Map)

    home =
      Enum.find(Mapping.list_systems(map.id), &(&1.solar_system_id == map.home_solar_system_id))

    node = view |> element("#node-#{home.id}") |> render()

    assert node =~ ", 590.0)"
    refute node =~ ", 60.0)"
  end

  test "demo user is admin and sees the Admin settings tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    assert render(view) =~ "Admin"
    assert render(view) =~ "Mask administration"
  end

  test "admin tab shows the metrics link when dev routes are enabled", %{conn: conn} do
    previous = Application.get_env(:tripwire, :dev_routes)
    Application.put_env(:tripwire, :dev_routes, true)

    try do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element("#settings-button") |> render_click()

      html = render(view)

      assert html =~ "Developer tools"
      assert html =~ ~s|href="/dev/dashboard"|
      assert html =~ "Metrics"
    after
      if is_nil(previous) do
        Application.delete_env(:tripwire, :dev_routes)
      else
        Application.put_env(:tripwire, :dev_routes, previous)
      end
    end
  end

  test "admin tab hides the metrics link without dev routes", %{conn: conn} do
    refute Application.get_env(:tripwire, :dev_routes)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    refute render(view) =~ ~s|href="/dev/dashboard"|
  end

  test "non-admin characters do not see the Admin tab and are rejected", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    refute render(view) =~ "Mask administration"

    html = render_click(view, "settings-tab", %{"tab" => "admin"})

    assert html =~ "Admin access required"
  end

  test "admin can add and remove mask members", %{conn: conn, character: character} do
    {:ok, admin} = Accounts.upsert_character(%{eve_id: character.eve_id, is_admin: true})
    {:ok, mask} = Masks.ensure_personal_mask(admin)

    {:ok, view, _html} = live(login(conn, admin), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    html =
      view
      |> element(~s|#settings-widget form[phx-submit="add-mask-member"]|)
      |> render_submit(%{"mask_id" => mask.id, "eve_id" => "555001", "name" => "New Member"})

    assert html =~ "Added New Member"

    member = Accounts.get_character_by_eve_id(555_001)
    assert Masks.member?(mask, member)

    html =
      render_click(view, "remove-mask-member", %{
        "mask_id" => mask.id,
        "character_id" => member.id
      })

    assert html =~ "Removed New Member"
    refute Masks.member?(mask, member)
  end

  test "demo admin is scoped to demo masks", %{conn: conn} do
    {:ok, outsider} = Accounts.upsert_character(%{eve_id: 888_001, name: "Outsider"})
    {:ok, personal} = Masks.ensure_personal_mask(outsider)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    html =
      view
      |> element(~s|#settings-widget form[phx-submit="add-mask-member"]|)
      |> render_submit(%{"mask_id" => personal.id, "eve_id" => "555002", "name" => "Sneaky"})

    assert html =~ "scoped to demo"
    assert Accounts.get_character_by_eve_id(555_002) == nil
  end

  test "auto-tracker toggle always renders and is disabled without SSO credentials", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    toggle_html =
      view
      |> element("#signatures button[phx-click='toggle-tracker']")
      |> render()

    assert toggle_html =~ "disabled"
    assert toggle_html =~ "Sign in with EVE SSO to enable auto-tracking"

    assert Tripwire.Tracking.tracking?(character) == false
  end

  test "auto-tracker button sits between the signature count and system badge", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    html = render(view)
    assert html =~ ~r|signatures.*toggle-tracker.*J150321|s

    toggle =
      view
      |> element("#signatures button[phx-click='toggle-tracker']")
      |> render()

    assert toggle =~ ~r|>\s*A\s*<|
    assert toggle =~ "border-current"
    refute toggle =~ "bg-primary"
  end

  test "auto-tracker toggle is enabled for a character with SSO credentials", %{
    conn: conn,
    character: character
  } do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_SECRET_KEY", "test-secret")

    {:ok, character} =
      Accounts.upsert_character(%{eve_id: character.eve_id, refresh_token: "tok"})

    try do
      {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

      toggle_html =
        view
        |> element("#signatures button[phx-click='toggle-tracker']")
        |> render()

      refute toggle_html =~ "disabled"
      assert toggle_html =~ "Auto-track this character"
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_SECRET_KEY")
    end
  end

  test "signature table shows the mass status of a linked wormhole", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, target} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})

    {:ok, _, _} =
      Mapping.upsert_connection(map.id, system.id, target.id, %{
        hole_type: "N770",
        mass_status: "destab"
      })

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{
          sig_id: "ABC-123",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    table = view |> element("#signatures table") |> render()
    assert table =~ "Mass"
    assert table =~ "Destab"
  end

  test "signature table shows the age and life state of a signature", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, scanned} =
      Mapping.create_signature(
        system,
        %{
          sig_id: "ABC-123",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N770)"
        },
        character
      )

    {:ok, _eol} =
      Mapping.create_signature(
        system,
        %{
          sig_id: "ABC-124",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N771)",
          life_length: 2 * 3600
        },
        character
      )

    {:ok, _critical} =
      Mapping.create_signature(
        system,
        %{
          sig_id: "ABC-125",
          kind: "signature",
          site_type: "wormhole",
          type_name: "Unstable Wormhole (N772)",
          life_length: 600
        },
        character
      )

    Repo.update!(
      Ecto.Changeset.change(scanned,
        inserted_at:
          DateTime.utc_now() |> DateTime.add(-7500, :second) |> DateTime.truncate(:second)
      )
    )

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    table = view |> element("#signatures table") |> render()

    assert table =~ "Age"
    assert table =~ "Life"
    assert table =~ "Stable"
    assert table =~ "EOL"
    assert table =~ "Critical"
    assert table =~ ~r/2h 0[0-5]m/
  end

  test "clicking a signature column header sorts and toggles direction", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J000000")

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{sig_id: "AAA-001", type_name: "Zeta Site"},
        character
      )

    {:ok, _} =
      Mapping.create_signature(
        system,
        %{sig_id: "BBB-002", type_name: "Alpha Site"},
        character
      )

    {:ok, other} =
      Mapping.add_system_to_map(Mapping.get_map!(system.map_id), %{
        solar_system_id: 2,
        name: "J000001"
      })

    {:ok, _, _} = Mapping.upsert_connection(system.map_id, system.id, other.id, %{})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J000000']")
    |> render_click()

    view
    |> element("#signatures th button[phx-value-column='name']")
    |> render_click()

    table = view |> element("#signatures table") |> render()
    assert at(table, "BBB-002") < at(table, "AAA-001")

    assert view |> element("#signatures th[data-column='name']") |> render() =~
             ~s(aria-sort="ascending")

    view
    |> element("#signatures th button[phx-value-column='name']")
    |> render_click()

    table = view |> element("#signatures table") |> render()
    assert at(table, "AAA-001") < at(table, "BBB-002")

    assert view |> element("#signatures th[data-column='name']") |> render() =~
             ~s(aria-sort="descending")

    view
    |> element("#system-container button[title='Select system J000001']")
    |> render_click()

    refute view |> element("#signature-columns") |> render() =~ ~s(aria-sort="ascending")
    refute view |> element("#signature-columns") |> render() =~ ~s(aria-sort="descending")
  end

  test "signature column headers and body cells can be reordered", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J000000")
    {:ok, _} = Mapping.create_signature(system, %{sig_id: "AAA-001"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J000000']")
    |> render_click()

    assert column_keys(view |> element("#signature-columns") |> render()) ==
             ~w(status id age type name life mass)

    view
    |> element("#signature-columns")
    |> render_hook("reorder-columns", %{"order" => ~w(name id type mass age life status)})

    header_html = view |> element("#signature-columns") |> render()
    assert column_keys(header_html) == ~w(name id type mass age life status)

    table = view |> element("#signatures table") |> render()

    assert column_keys(table) ==
             ~w(name id type mass age life status name id type mass age life status)

    view
    |> element("#signature-columns")
    |> render_hook("reorder-columns", %{"order" => ~w(name bogus name)})

    assert column_keys(view |> element("#signature-columns") |> render()) ==
             ~w(name status id age type life mass)
  end

  test "delete then undo restores the signature", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J000000")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, sig} =
      Mapping.create_signature(system, %{sig_id: "XYZ-010"}, character)

    view
    |> element("#system-container button[title='Select system J000000']")
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

  test "topbar character dropdown adds, switches, and removes characters", %{
    conn: conn,
    character: character
  } do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_SECRET_KEY", "test-secret")

    try do
      {:ok, other} = Accounts.upsert_character(%{eve_id: 43_000, name: "Second Char"})

      session =
        Plug.Test.init_test_session(conn, %{
          "current_user" => %{"id" => character.eve_id, "name" => character.name},
          "character_ids" => [character.eve_id, other.eve_id]
        })

      {:ok, view, html} = live(session, ~p"/dashboard")

      assert html =~ "Add character"
      assert html =~ "/auth/switch/#{other.eve_id}"
      assert html =~ "Manage masks"

      view
      |> element(~s|button[title="Remove Second Char"]|)
      |> render_click()

      html = render(view)
      assert html =~ "Removed Second Char"
      refute html =~ "Remove Second Char"
      refute html =~ "/auth/switch/43000"
      assert html =~ character.name
      assert Accounts.get_character(other.id) == nil
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_SECRET_KEY")
    end
  end

  test "manage masks opens settings on the account tab", %{conn: conn, character: character} do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    refute has_element?(view, "#settings-widget")

    view
    |> element(~s|button[title="Manage masks"]|)
    |> render_click()

    assert has_element?(view, "#settings-widget")
    assert render(view) =~ "Masks"
  end

  test "statistics tab shows personal stat sections", %{conn: conn, character: character} do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    html = render_click(view, "settings-tab", %{"tab" => "statistics"})

    assert html =~ "Personal Statistics"
    assert html =~ "Signatures"
    assert html =~ "Wormholes"
    assert html =~ "Comments"
    assert html =~ "Systems visited"
    assert html =~ "Logins"
    assert html =~ "Last login"
  end

  test "flash toasts render below the topbar and auto-dismiss", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    html =
      view
      |> element(~s|nav form[phx-submit="system-search-submit"]|)
      |> render_submit(%{search: "nope"})

    assert html =~ "mt-16"
    assert html =~ "AutoDismiss"
    assert html =~ "data-timeout=\"4000\""
    refute html =~ "stale-toast"
  end

  test "stale toast has no auto-dismiss hook", %{conn: conn, character: character} do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.create_signature(system, %{sig_id: "OLD-001"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    assert render(view) =~ "stale-toast"

    stale_html = view |> element("#stale-toast") |> render()
    assert stale_html =~ "mt-16"
    refute stale_html =~ "AutoDismiss"
  end

  test "stale toast only appears for valid pastes with missing signatures", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Mapping.create_signature(system, %{sig_id: "OLD-001"}, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    assert render(view) =~ "stale-toast"

    view
    |> render_click("global-paste", %{
      "text" =>
        "OLD-001\tCosmic Signature\tSerpentis Frigate Den\nNEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    refute render(view) =~ "stale-toast"

    view
    |> render_click("global-paste", %{
      "text" => "NEW-002\tCosmic Signature\tSerpentis Frigate Den"
    })

    assert render(view) =~ "stale-toast"

    view
    |> render_click("global-paste", %{"text" => "nothing to see here"})

    refute render(view) =~ "stale-toast"
  end

  test "demo dropdowns dot the current user and mask green", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "avatar avatar-online"
    refute html =~ "avatar avatar-offline"
  end

  test "dropdowns dot only the current character and mask green", %{
    conn: conn,
    character: character
  } do
    {:ok, _other} = Accounts.upsert_character(%{eve_id: 43_001, name: "Other Char"})

    session =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id, 43_001]
      })

    {:ok, _view, html} = live(session, ~p"/dashboard")

    assert html =~ "avatar avatar-online"
    assert html =~ "avatar avatar-offline"
  end

  test "demo add character buttons explain SSO is unavailable", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Add character"
    refute html =~ "/auth/evesso"

    html =
      view
      |> element("button[phx-click='add-character']")
      |> render_click()

    assert html =~ "EVE SSO is not configured"

    view |> element("#settings-button") |> render_click()
    settings_html = view |> element("#settings-widget") |> render()
    assert settings_html =~ "add-character"
  end

  test "account tab manages characters and masks", %{conn: conn} do
    System.put_env("EVESSO_CLIENT_ID", "test-id")
    System.put_env("EVESSO_SECRET_KEY", "test-secret")

    try do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view |> element("#settings-button") |> render_click()
      html = render_click(view, "settings-tab", %{"tab" => "account"})

      assert html =~ "Add character"
      assert html =~ "remove-character"
      assert html =~ "create-corp-mask"
      assert html =~ "delete-mask"
    after
      System.delete_env("EVESSO_CLIENT_ID")
      System.delete_env("EVESSO_SECRET_KEY")
    end
  end

  test "account tab hides mask management from non-admins", %{conn: conn, character: character} do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    html = render_click(view, "settings-tab", %{"tab" => "account"})

    assert html =~ "remove-character"
    refute html =~ "create-corp-mask"
    refute html =~ "delete-mask"
  end

  test "removing the current character navigates away", %{conn: conn, character: character} do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    assert {_, {:live_redirect, %{to: "/dashboard"}}} =
             view
             |> element(~s|button[title="Remove #{character.name}"]|)
             |> render_click()
  end

  test "switching characters updates the session", %{conn: conn, character: character} do
    {:ok, other} = Accounts.upsert_character(%{eve_id: 44_000, name: "Switch Target"})

    conn =
      conn
      |> Plug.Test.init_test_session(%{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id, other.eve_id]
      })
      |> get("/auth/switch/#{other.eve_id}")

    assert redirected_to(conn) == "/dashboard"
    assert %{"id" => id, "name" => _} = get_session(conn, "current_user")
    assert id == other.eve_id
    assert other.eve_id in get_session(conn, "character_ids")

    denied =
      build_conn()
      |> Plug.Test.init_test_session(%{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id]
      })
      |> get("/auth/switch/999999")

    assert redirected_to(denied) == "/dashboard"
    assert get_session(denied, "current_user")["id"] == character.eve_id
  end
end
