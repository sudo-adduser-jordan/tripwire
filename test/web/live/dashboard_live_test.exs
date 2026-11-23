defmodule TripwireWeb.DashboardLiveTest do
  use TripwireWeb.ConnCase, async: false

  alias Tripwire.Accounts
  alias Tripwire.Layouts
  alias Tripwire.Mapping
  alias Tripwire.Masks
  alias Tripwire.Repo
  alias Tripwire.Settings
  alias Tripwire.Systems
  alias Tripwire.Systems.Gates

  setup do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 42_000, name: "Kariyo Astrien"})
    on_exit(fn -> stop_trackers() end)
    %{character: character}
  end

  defp stop_trackers do
    Tripwire.TrackingRegistry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [:"$2"]}])
    |> Enum.each(&DynamicSupervisor.terminate_child(Tripwire.Tracking.PollerSupervisor, &1))
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

  test "row guides label rows by depth and span the chain edges", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    view |> element("#toggle-row-guides") |> render_click()
    view |> element("#toggle-row-counts") |> render_click()

    map_html = view |> element("#map") |> render()

    levels =
      ~r/data-guide-y="[-\d.]+"[^>]*>\s*(\d+)\s*<\/span>/
      |> Regex.scan(map_html, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)

    assert length(levels) > 1
    assert levels == Enum.to_list(0..(length(levels) - 1))

    guides_html = view |> element("#map-row-guides") |> render()
    assert guides_html =~ ~s(preserveAspectRatio="none")
    assert guides_html =~ ~s(x1="1%")
    assert guides_html =~ ~s(x2="99%")
  end

  test "the demo map shows the tracked character badge and its tooltip", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    map_html = view |> element("#chain-map") |> render()

    assert map_html =~ "<foreignobject"
    assert map_html =~ ~s(width="28")
    assert map_html =~ "https://images.evetech.net/characters/9000002/portrait?size=64"
    assert map_html =~ "https://images.evetech.net/types/85086/render?size=64"
    refute map_html =~ "<title>Demo User"
    assert has_element?(view, "#chain-map foreignobject", "Demo User - Cenotaph")
  end

  test "several characters in one system share the default badge and list both in the tooltip", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, other} = Accounts.upsert_character(%{eve_id: 42_500, name: "Second Pilot"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, _} =
      Tripwire.Tracking.DemoPresence.ensure_started(character, map, system,
        ship_name: "Rifter",
        ship_type_id: 587
      )

    {:ok, _} = Tripwire.Tracking.DemoPresence.ensure_started(other, map, system)

    render_click(view, "refresh-occupants", %{})

    map_html = view |> element("#chain-map") |> render()

    assert map_html =~ ~s|href="https://images.evetech.net/characters/1/portrait?size=64"|
    refute map_html =~ ~s|href="https://images.evetech.net/characters/42000/portrait|
    assert has_element?(view, "#chain-map foreignobject", "Kariyo Astrien - Rifter")
    assert has_element?(view, "#chain-map foreignobject", "Second Pilot")
    assert map_html =~ ~r|>\s*2\s*</text>|
  end

  test "the tooltip prefers the ship type name and hides raw ship names", %{
    conn: conn,
    character: character
  } do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, _} =
      Tripwire.Tracking.DemoPresence.ensure_started(character, map, system,
        ship_name: "u'ⁿ'",
        ship_type_id: 587
      )

    send(
      view.pid,
      {:topbar_loaded,
       %{
         tq_online: true,
         tq_players: 1000,
         current_system_name: "J150321",
         character_online: true,
         ship_type_id: 587,
         presences: %{
           character.eve_id => %{
             system_name: "J150321",
             online: true,
             ship_name: "u'ⁿ'",
             ship_type_id: 587,
             ship_type_name: "Rifter"
           }
         },
         now: DateTime.utc_now()
       }}
    )

    html = view |> element("#chain-map") |> render()

    assert has_element?(view, "#chain-map foreignobject", "Kariyo Astrien - Rifter")
    refute html =~ "u'ⁿ'"
  end

  test "the tooltip widens to fit a long ship name", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, _} =
      Tripwire.Tracking.DemoPresence.ensure_started(character, map, system,
        ship_name: "A Very Long Ship Name",
        ship_type_id: 587
      )

    render_click(view, "refresh-occupants", %{})

    map_html = view |> element("#chain-map") |> render()
    [_, width] = Regex.run(~r/<foreignobject[^>]*width="([\d.]+)"/, map_html)
    {width, _rest} = Float.parse(width)

    assert width > 280.0
  end

  test "the tooltip hides a slash ship name", %{conn: conn, character: character} do
    {_mask, map, system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, _} =
      Tripwire.Tracking.DemoPresence.ensure_started(character, map, system,
        ship_name: "/",
        ship_type_id: 587
      )

    render_click(view, "refresh-occupants", %{})

    html = view |> element("#chain-map") |> render()

    assert html =~ "Kariyo Astrien"
    refute html =~ "Kariyo Astrien - /"
  end

  test "every session character with a token gets its own tracker", %{
    conn: conn,
    character: character
  } do
    {:ok, character} =
      Accounts.upsert_character(%{eve_id: character.eve_id, refresh_token: "one"})

    {:ok, other} =
      Accounts.upsert_character(%{eve_id: 42_600, name: "Alt Pilot", refresh_token: "two"})

    conn =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id, other.eve_id]
      })

    {:ok, _view, _html} = live(conn, ~p"/dashboard")

    assert Tripwire.Tracking.tracking?(character)
    assert Tripwire.Tracking.tracking?(other)
  end

  test "a corporation mask lists only corporation members on the map", %{
    conn: conn,
    character: character
  } do
    {:ok, character} =
      Accounts.update_character(character, %{
        corporation_id: 98_000_001,
        corporation_name: "Test Corp"
      })

    {:ok, corp_mask} = Masks.ensure_corporation_mask(character)
    {:ok, corp_map} = Mapping.create_map(%{name: "Corp Chain", mask_id: corp_mask.id})

    {:ok, corp_system} =
      Mapping.add_system_to_map(corp_map, %{solar_system_id: 1, name: "J150321"})

    {:ok, outsider} =
      Accounts.upsert_character(%{
        eve_id: 42_700,
        name: "Other Corp Pilot",
        corporation_id: 98_000_002,
        corporation_name: "Other Corp"
      })

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    {:ok, _} = Tripwire.Tracking.DemoPresence.ensure_started(character, corp_map, corp_system)
    {:ok, _} = Tripwire.Tracking.DemoPresence.ensure_started(outsider, corp_map, corp_system)

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{corp_mask.id}"]|)
    |> render_click()

    map_html = view |> element("#chain-map") |> render()
    assert map_html =~ "Kariyo Astrien"
    refute map_html =~ "Other Corp Pilot"
  end

  test "the occupant tooltip opens below a lone root node instead of flipping off the map", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    [map] = Repo.all(Mapping.Map)
    [system] = Mapping.list_systems(map.id)
    on_exit(fn -> Tripwire.Tracking.stop_poller(character) end)

    {:ok, _} =
      Tripwire.Tracking.DemoPresence.ensure_started(character, map, system,
        ship_name: "Rifter",
        ship_type_id: 587
      )

    render_click(view, "refresh-occupants", %{})

    map_html = view |> element("#chain-map") |> render()
    [_, y] = Regex.run(~r/<foreignobject[^>]*y="([-\d.]+)"/, map_html)
    assert y == "96.0"
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

  test "theme settings list phoenix, eve and carbon in core and tripwire under mapper", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    for mode <- ~w(system light dark) do
      assert has_element?(view, "button[data-phx-mode='#{mode}']")
    end

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "themes"})

    core = view |> element("#theme-container-core") |> render()
    mapper = view |> element("#theme-container-mapper") |> render()

    for theme <- ~w(phoenix eve carbon) do
      assert core =~ ~s|id="theme-button-#{theme}"|
    end

    assert mapper =~ ~s|id="theme-button-tripwire"|
    assert mapper =~ ~s|id="theme-button-wanderer"|

    for theme <- ~w(light dark native native-dark) do
      refute core =~ ~s|id="theme-button-#{theme}"|
      refute mapper =~ ~s|id="theme-button-#{theme}"|
    end
  end

  test "settings are shared across characters", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "widgets"})
    view |> element("#toggle-widget-notes") |> render_click()

    refute has_element?(view, "#notes")
    refute Settings.get().widget_notes

    {:ok, other} = Accounts.upsert_character(%{eve_id: 43_100, name: "Alt Character"})
    {:ok, other_view, _html} = live(login(conn, other), ~p"/dashboard")

    refute has_element?(other_view, "#notes")

    other_view |> element("#settings-button") |> render_click()
    render_click(other_view, "settings-tab", %{"tab" => "widgets"})
    refute has_element?(other_view, "#toggle-widget-notes[checked]")
  end

  test "layouts settings tab lists core layouts without remove controls", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "layouts"})

    assert has_element?(view, "#layout-core-default")
    assert has_element?(view, "#layout-core-map-focus")
    assert has_element?(view, "#layout-core-signatures-focus")
    assert has_element?(view, "#layout-core-compact")
    assert has_element?(view, "#apply-layout-core-default")
    refute has_element?(view, "#remove-layout-core-default")
    assert has_element?(view, "#no-saved-layouts")
    assert render(view) =~ "Map Focus"
  end

  test "applying a layout moves widgets, hides widgets and persists the choice", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    assert has_element?(view, "#signatures")
    assert has_element?(view, "#map[gs-y='12']")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "layouts"})
    view |> element("#apply-layout-core-map-focus") |> render_click()

    assert has_element?(view, "#map[gs-y='0']")
    refute has_element?(view, "#signatures")
    assert Layouts.active_layout() == "core:map-focus"
    assert render(view) =~ "Active"

    {:ok, reloaded, _html} = live(login(conn, character), ~p"/dashboard")

    assert has_element?(reloaded, "#map[gs-y='0']")
    refute has_element?(reloaded, "#signatures")
  end

  test "saving the current layout stores positions and visibility", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "layouts"})

    view |> element("#save-layout-form") |> render_submit(%{"name" => "Wide"})

    widgets = %{
      "system" => %{"x" => 0, "y" => 0, "w" => 6, "h" => 4},
      "notes" => %{"x" => 6, "y" => 0, "w" => 6, "h" => 4},
      "signatures" => %{"x" => 0, "y" => 4, "w" => 12, "h" => 6},
      "map" => %{"x" => 0, "y" => 10, "w" => 12}
    }

    view |> element("#grid-stack") |> render_hook("layout-captured", %{"widgets" => widgets})

    assert [layout] = Layouts.list_saved()
    assert layout.name == "Wide"
    assert has_element?(view, "#layout-saved-#{layout.id}")
    assert has_element?(view, "#apply-layout-saved-#{layout.id}")
    assert has_element?(view, "#remove-layout-saved-#{layout.id}")
    assert Layouts.active_layout() == "saved:#{layout.id}"
    assert render(view) =~ "Active"
  end

  test "saving a layout with a duplicate name shows an error", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _layout} = Layouts.save_layout("Wide", Layouts.default_widgets())

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "layouts"})
    view |> element("#save-layout-form") |> render_submit(%{"name" => "Wide"})
    view |> element("#grid-stack") |> render_hook("layout-captured", %{"widgets" => %{}})

    assert render(view) =~ "name has already been taken"
    assert length(Layouts.list_saved()) == 1
  end

  test "only saved layouts can be removed", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")
    {:ok, layout} = Layouts.save_layout("Wide", Layouts.default_widgets())

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "layouts"})

    view |> element("#remove-layout-saved-#{layout.id}") |> render_click()

    assert Layouts.list_saved() == []
    assert has_element?(view, "#no-saved-layouts")

    render_click(view, "delete-layout", %{"id" => "core:default"})

    assert render(view) =~ "Core layouts cannot be removed"
    assert has_element?(view, "#layout-core-default")
  end

  test "changing widgets clears the active layout marker", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "layouts"})
    view |> element("#apply-layout-core-map-focus") |> render_click()
    assert Layouts.active_layout() == "core:map-focus"

    render_click(view, "settings-tab", %{"tab" => "widgets"})
    view |> element("#toggle-widget-signatures") |> render_click()

    assert Layouts.active_layout() == nil
  end

  test "settings survive switching masks", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, other_mask} =
      Masks.create_mask(%{
        name: "Second",
        kind: "corporation",
        owner_character_id: character.id,
        eve_owner_id: 90_001
      })

    {:ok, _} = Masks.add_membership(other_mask, character)
    {:ok, _} = Mapping.create_map(%{name: "Home", mask_id: other_mask.id})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "widgets"})
    view |> element("#toggle-widget-map") |> render_click()
    refute has_element?(view, "#chain-map")

    view
    |> element("#mask-card-#{other_mask.id} button[phx-click='switch-mask']")
    |> render_click()

    refute has_element?(view, "#chain-map")
    refute Settings.get().widget_map
  end

  test "persisted layout and scale apply on the next mount", %{conn: conn} do
    {:ok, _} = Settings.update(%{map_layout: "bottom", map_scale: 150, widget_notes: false})

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    map = Repo.one(Mapping.Map)
    systems = map |> Mapping.list_chain_systems(Settings.get().show_all)

    home =
      Enum.find(Mapping.list_systems(map.id), &(&1.solar_system_id == map.home_solar_system_id))

    node = view |> element("#node-#{home.id}") |> render()

    assert node =~ ", 590.0)"
    refute has_element?(view, "#notes")

    zoom = Mapping.default_zoom() * 150 / 100
    {pan_x, pan_y} = Mapping.home_center(systems, map, zoom)
    {view_w, view_h} = Mapping.view_size(zoom)

    assert view |> element("#chain-map") |> render() =~
             ~s|viewBox="#{pan_x} #{pan_y} #{view_w} #{view_h}"|
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

  test "the demo map renders every seeded node with show all off", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    map = Repo.one(Mapping.Map)
    systems = Mapping.list_systems(map.id)

    assert length(systems) == 27
    assert length(Mapping.list_chain_systems(map, false)) == 27
    assert Enum.all?(systems, &has_element?(view, "#node-#{&1.id}"))
  end

  test "demo user is tracked at home in a Cenotaph", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Demo User"
    refute view |> element("nav") |> render() =~ "Cenotaph"
    refute has_element?(view, "div[title='Characters tracked on chain']")

    map_html = view |> element("#chain-map") |> render()
    assert map_html =~ "characters/9000002/portrait"
    assert has_element?(view, "#chain-map foreignobject", "Demo User - Cenotaph")
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

    systems = map.id |> Mapping.list_systems() |> Enum.sort_by(& &1.id)
    home = Enum.find(systems, &(&1.solar_system_id == map.home_solar_system_id))
    {node_w, _node_h} = Mapping.node_size()
    {pan_x, pan_y} = Mapping.home_center(systems, map)

    assert_push_event(view, "reset-pan", %{x: x, y: y})
    assert_in_delta x, pan_x, 0.001
    assert_in_delta y, pan_y, 0.001
    assert home.x - x < 1250.0
    assert home.x + node_w - x > 0.0
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

    assert nav =~
             ~r/toggle-ship-visibility.*toggle-character-visibility.*switch-character/s

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
             "nav button[phx-click='switch-character'][phx-value-id='#{character.id}']"
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

  defp seed_catalog(entries) do
    Systems.Catalog.put_systems(entries)
    on_exit(fn -> Systems.Catalog.clear() end)
  end

  defp seed_gates(links) do
    Gates.put_stargates(links)
    on_exit(fn -> Gates.clear() end)
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

    systems = Mapping.list_systems(map.id)
    {pan_x, pan_y} = Mapping.home_center(systems, map)

    assert_push_event(view, "reset-pan", %{x: x, y: y, zoom: zoom})
    assert_in_delta x, pan_x, 0.001
    assert_in_delta y, pan_y, 0.001
    assert_in_delta zoom, Mapping.default_zoom(), 0.001
  end

  test "reset zoom clears a scaled up map and reopens at the default zoom", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")
    {:ok, _} = Settings.update(%{map_scale: 150})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    assert Settings.get().map_scale == 100

    assert_push_event(view, "reset-pan", %{zoom: zoom})
    assert_in_delta zoom, Mapping.default_zoom(), 0.001
  end

  test "reset zoom without a home pins the chain to the top and centers it", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#chain-zoom-reset")
    |> render_click()

    [system] = map.id |> Mapping.list_systems()

    assert_push_event(view, "reset-pan", %{x: x, y: y})
    assert_in_delta x, system.x + 70.0 - 625.0, 0.001
    assert_in_delta y, system.y - 40.0, 0.001
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
    assert html =~ "text-active-accent"
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

  test "chain nodes show real wormhole class, effect and static destinations", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _system} = setup_with_system(%{character: character}, "Jita")
    {:ok, _} = Mapping.add_system_to_map(map, %{solar_system_id: 31_001_663, name: "J231710"})

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ "System effect: Magnetar"

    map_html = view |> element("#chain-map") |> render()
    assert map_html =~ ~r/>\s*C3\s*<title>Static C247 to C3/
    assert map_html =~ ~r/>\s*C5\s*<title>Static H900 to C5/
    refute map_html =~ ~r/>\s*C247\s*</
    refute map_html =~ ~r/>\s*H900\s*</
    assert map_html =~ "C4"
  end

  test "static badges wrap under the node when a system has many statics", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _system} = setup_with_system(%{character: character}, "Jita")

    {:ok, _} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_001, name: "Sentinel MZ"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")
    map_html = view |> element("#chain-map") |> render()

    for class <- ~w(C1 C2 C3 C4 C5 C6) do
      assert map_html =~ ~r/>\s*#{class}\s*<title>Static /
    end

    assert map_html =~ "translate(4, 80.0)"
    assert map_html =~ "translate(4, 100.0)"
    assert map_html =~ "translate(34, 100.0)"
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
    assert html =~ "text-active-accent"
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

  test "system widget lists gate neighbours of the selected k-space system", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _hole} = setup_with_system(%{character: character}, "J150321")

    {:ok, _jita} =
      Mapping.add_system_to_map(map, %{
        solar_system_id: 30_000_142,
        name: "Jita",
        security: 0.9
      })

    seed_catalog([
      %{solar_system_id: 30_000_142, name: "Jita", security: 0.9},
      %{solar_system_id: 30_000_144, name: "Perimeter", security: 1.0},
      %{solar_system_id: 30_000_145, name: "Maurasi", security: 0.9},
      %{solar_system_id: 30_001_385, name: "Rancer", security: 0.3}
    ])

    seed_gates([{30_000_142, 30_000_144}, {30_000_142, 30_000_145}])

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    container = view |> element("#system-container") |> render()
    assert container =~ "Perimeter"
    assert container =~ "Maurasi"
    refute container =~ "Rancer"
    assert container =~ "Gates"

    view
    |> element("#system-container button[title='Select system Perimeter (1 jump from Jita)']")
    |> render_click()

    assert_patch(view, "/Perimeter")

    container = view |> element("#system-container") |> render()
    assert container =~ "Perimeter"
    refute container =~ "Gates"
    assert view |> element("#topbar-system") |> render() =~ "Perimeter"

    jita_button =
      view |> element("#system-container button[title='Select system Jita']") |> render()

    refute jita_button =~ "btn-primary"
    assert render(view) =~ "Shortcuts"
  end

  test "an off-chain k-space url opens its statistics without a chain node", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _hole} = setup_with_system(%{character: character}, "J150321")

    {:ok, _jita} =
      Mapping.add_system_to_map(map, %{
        solar_system_id: 30_000_142,
        name: "Jita",
        security: 0.9
      })

    seed_catalog([
      %{solar_system_id: 30_000_142, name: "Jita", security: 0.9},
      %{solar_system_id: 30_000_144, name: "Perimeter", security: 1.0}
    ])

    seed_gates([{30_000_142, 30_000_144}])

    {:ok, view, _html} = live(login(conn, character), ~p"/Perimeter")

    assert view |> element("#system-container") |> render() =~ "Perimeter"
    assert view |> element("#topbar-system") |> render() =~ "Perimeter"
    assert length(Mapping.list_systems(map.id)) == 2
  end

  test "system widget lists no gate neighbours without gate data", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _hole} = setup_with_system(%{character: character}, "J150321")

    {:ok, _jita} =
      Mapping.add_system_to_map(map, %{
        solar_system_id: 30_000_142,
        name: "Jita",
        security: 0.9
      })

    seed_catalog([
      %{solar_system_id: 30_000_142, name: "Jita", security: 0.9},
      %{solar_system_id: 30_000_144, name: "Perimeter", security: 1.0}
    ])

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    container = view |> element("#system-container") |> render()
    assert container =~ "Jita"
    refute container =~ "Perimeter"
    refute container =~ "Gates"
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
    assert Settings.get().map_layout == "top"
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
    refute Settings.get().show_jump_lines
    refute Settings.get().show_node_badges
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
    assert Settings.get().line_weight == 4
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
    assert Settings.get().map_background == "https://example.com/map-bg.jpg"
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
    assert Settings.get().node_spacing == 200
  end

  test "map settings scale pushes a zoom event", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()

    view
    |> element(~s|#settings-widget form[phx-change="map-scale"]|)
    |> render_change(%{scale: "150"})

    assert_push_event(view, "map-zoom", %{zoom: 1.5})
    assert Settings.get().map_scale == 150
  end

  test "top bar renders ESI fallbacks and grid lock toggles", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Down"
    assert html =~ "sticky"
    assert html =~ ~s|id="lock-button"|
    assert html =~ ~s|data-grid-locked="true"|

    view |> element("#lock-button") |> render_click()
    assert render(view) =~ ~s|data-grid-locked="false"|
    refute Settings.get().grid_locked

    view |> element("#lock-button") |> render_click()
    assert render(view) =~ ~s|data-grid-locked="true"|
    assert Settings.get().grid_locked
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
    assert view |> element("#system-search") |> render() =~ ~s|value=""|
    assert view |> element("#system-search") |> render() =~ ~s|placeholder="Search systems"|
  end

  test "selecting a search suggestion resets the search box", %{conn: conn, character: character} do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element(~s|nav form[phx-submit="system-search-submit"]|)
    |> render_change(%{search: "j15"})

    view
    |> element(~s|nav button[title="Select J150321"]|)
    |> render_click()

    assert view |> element("#topbar-system") |> render() =~ "J150321"
    assert view |> element("#system-search") |> render() =~ ~s|value=""|
    assert view |> element("#system-search") |> render() =~ ~s|placeholder="Search systems"|
  end

  test "system search suggests systems outside the map", %{conn: conn, character: character} do
    {_mask, map, _system} = setup_with_system(%{character: character}, "J150321")
    seed_catalog([%{solar_system_id: 30_001_385, name: "Rancer", security: 0.3}])

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element(~s|nav form[phx-submit="system-search-submit"]|)
    |> render_change(%{search: "ranc"})

    suggestion = view |> element(~s|nav button[title="Select Rancer"]|) |> render()
    assert suggestion =~ "Rancer"
    assert suggestion =~ ~s|phx-click="system-search-pick"|

    view |> element(~s|nav button[title="Select Rancer"]|) |> render_click()

    assert_patch(view, "/Rancer")
    assert view |> element("#topbar-system") |> render() =~ "Rancer"
    assert view |> element("#system-container") |> render() =~ "Rancer"
    assert length(Mapping.list_systems(map.id)) == 1
    assert view |> element("#system-search") |> render() =~ ~s|value=""|
  end

  test "submitting an outside k-space system name shows its statistics", %{
    conn: conn,
    character: character
  } do
    {_mask, map, _system} = setup_with_system(%{character: character}, "J150321")
    seed_catalog([%{solar_system_id: 30_001_385, name: "Rancer", security: 0.3}])

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element(~s|nav form[phx-submit="system-search-submit"]|)
    |> render_submit(%{search: "Rancer"})

    assert_patch(view, "/Rancer")
    assert view |> element("#topbar-system") |> render() =~ "Rancer"
    assert view |> element("#system-container") |> render() =~ "Rancer"
    assert length(Mapping.list_systems(map.id)) == 1
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

  test "the notes add button slides the composer open and a submit closes it", %{
    conn: conn,
    character: character
  } do
    {_mask, _map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element("#system-container button[title='Select system J150321']")
    |> render_click()

    assert has_element?(view, "#note-composer[data-open='false']")
    refute render(view) =~ "grid-rows-[1fr]"

    view |> element("#note-compose-toggle") |> render_click()

    assert has_element?(view, "#note-composer[data-open='true']")
    assert has_element?(view, "#note-compose-toggle[aria-expanded='true']")
    assert render(view) =~ "grid-rows-[1fr]"

    view
    |> element(~s|#note-composer form[phx-submit="comment-submit"]|)
    |> render_submit(%{comment: "slid in"})

    assert has_element?(view, "#note-composer[data-open='false']")
    assert has_element?(view, "#note-compose-toggle[aria-expanded='false']")

    html = render(view)
    assert html =~ "slid in"
    assert html =~ "1 notes"
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

  test "known space reveals detached chains at level 0", %{
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

    view |> element("#map-edit") |> render_click()

    assert render(view) =~ "Known space"

    view
    |> element("#map-modal form[phx-submit='save-map-settings']")
    |> render_submit(%{"map" => %{"home" => "J150321", "show_all" => "true"}})

    html = render(view)
    assert html =~ "J150323"
    assert html =~ "J150324"
    assert Settings.get().show_all

    assert Mapping.get_system!(home.id).y == 60.0
    assert Mapping.get_system!(child.id).y == 220.0
    assert Mapping.get_system!(detached.id).y == 60.0
    assert Mapping.get_system!(lone.id).y == 60.0

    xs = Enum.map([home, detached, lone], &Mapping.get_system!(&1.id).x)
    assert xs == Enum.uniq(xs)
  end

  test "the edit map modal renames the map and its tab", %{conn: conn, character: character} do
    {_mask, map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#map-edit") |> render_click()

    view
    |> element("#map-modal form[phx-submit='save-map-settings']")
    |> render_submit(%{"map" => %{"name" => "Rolling Hole", "home" => "J150321"}})

    assert Mapping.get_map!(map.id).name == "Rolling Hole"

    html = render(view)
    assert html =~ "Map saved"
    refute has_element?(view, "#map-modal")
    assert has_element?(view, "#chainTabs button[title='Rolling Hole']")

    view |> element("#map-edit") |> render_click()

    assert has_element?(
             view,
             "#map-modal input[name='map[name]'][value='Rolling Hole']"
           )
  end

  test "the edit map modal rejects a blank map name", %{conn: conn, character: character} do
    {_mask, map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#map-edit") |> render_click()

    view
    |> element("#map-modal form[phx-submit='save-map-settings']")
    |> render_submit(%{"map" => %{"name" => "   ", "home" => "J150321"}})

    assert render(view) =~ "name can&#39;t be blank"
    assert has_element?(view, "#map-modal")
    assert Mapping.get_map!(map.id).name == "Home"
  end

  test "the edit map modal deletes the selected map and opens the next one", %{
    conn: conn,
    character: character
  } do
    {mask, first, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, second} = Mapping.create_map(%{name: "Chain 2", mask_id: mask.id})
    {:ok, other} = Mapping.add_system_to_map(second, %{solar_system_id: 2, name: "J150322"})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#map-edit") |> render_click()
    assert has_element?(view, "#map-modal #delete-map")

    view |> element("#map-modal #delete-map") |> render_click()

    assert [remaining] = Mapping.list_maps_for_mask(mask.id)
    assert remaining.id == second.id
    assert Mapping.get_system(system.id) == nil
    assert Mapping.get_system(other.id)

    html = render(view)
    assert html =~ "Deleted #{first.name}"
    refute has_element?(view, "#map-modal")
    refute has_element?(view, "#chainTabs button[title='#{first.name}']")
    assert has_element?(view, "#chainTabs button[title='Chain 2']")
    assert html =~ "J150322"
  end

  test "deleting a map that is not selected keeps the current map open", %{
    conn: conn,
    character: character
  } do
    {mask, map, system} = setup_with_system(%{character: character}, "J150321")
    {:ok, spare} = Mapping.create_map(%{name: "Chain 2", mask_id: mask.id})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#map-edit") |> render_click()
    view |> element("#chainTabs button[title='Chain 2']") |> render_click()
    view |> element("#map-edit") |> render_click()
    view |> element("#map-modal #delete-map") |> render_click()

    assert [remaining] = Mapping.list_maps_for_mask(mask.id)
    assert remaining.id == map.id
    refute Enum.any?(Mapping.list_maps_for_mask(mask.id), &(&1.id == spare.id))

    html = render(view)
    assert html =~ "Deleted Chain 2"
    assert html =~ "J150321"
    assert Mapping.get_system(system.id)
  end

  test "deleting the only map restores the default Jita map", %{
    conn: conn,
    character: character
  } do
    {mask, map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#map-edit") |> render_click()
    view |> element("#map-modal #delete-map") |> render_click()

    assert [restored] = Mapping.list_maps_for_mask(mask.id)
    assert restored.id != map.id
    assert restored.name == "Home"
    assert Enum.any?(Mapping.list_systems(restored.id), &(&1.name == "Jita"))

    html = render(view)
    assert html =~ "Deleted Home"
    assert html =~ "Jita"
    assert has_element?(view, "#chainTabs button[title='Home']")
  end

  test "deleting the only demo map reseeds it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    {:ok, demo_mask} = Masks.ensure_demo_mask()
    [demo_map] = Mapping.list_maps_for_mask(demo_mask.id)

    view |> element("#map-edit") |> render_click()
    view |> element("#map-modal #delete-map") |> render_click()

    assert [restored] = Mapping.list_maps_for_mask(demo_mask.id)
    assert restored.id != demo_map.id

    systems = Mapping.list_systems(restored.id)
    assert Enum.any?(systems, &(&1.alias == "Home"))
    assert length(systems) > 1

    assert render(view) =~ "Deleted #{demo_map.name}"
  end

  test "a locked map refuses to delete itself", %{conn: conn, character: character} do
    {mask, map, _system} = setup_with_system(%{character: character}, "J150321")

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#map-edit") |> render_click()
    view |> element("#toggle-lock") |> render_click()
    view |> element("#map-modal #delete-map") |> render_click()

    assert [remaining] = Mapping.list_maps_for_mask(mask.id)
    assert remaining.id == map.id
    assert render(view) =~ "Map is locked"
  end

  test "only the home map renders until known space is enabled", %{
    conn: conn,
    character: character
  } do
    {_mask, map, home} = setup_with_system(%{character: character}, "J150321")

    {:ok, map} =
      Mapping.update_map(map, %{
        home_solar_system_id: home.solar_system_id,
        home_name: home.name
      })

    {:ok, child} = Mapping.add_system_to_map(map, %{solar_system_id: 2, name: "J150322"})
    {:ok, orphan} = Mapping.add_system_to_map(map, %{solar_system_id: 3, name: "J150323"})
    {:ok, _, _} = Mapping.upsert_connection(map.id, home.id, child.id)

    {:ok, view, html} = live(login(conn, character), ~p"/dashboard")

    assert html =~ "J150321"
    assert html =~ "J150322"
    assert has_element?(view, "#node-#{home.id}")
    assert has_element?(view, "#node-#{child.id}")
    refute has_element?(view, "#node-#{orphan.id}")

    {:ok, _} = Settings.update(%{show_all: true})

    {:ok, all_view, _html} = live(login(conn, character), ~p"/dashboard")

    assert has_element?(all_view, "#node-#{home.id}")
    assert has_element?(all_view, "#node-#{orphan.id}")
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
    assert Settings.get().map_layout == "bottom"
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

  test "auto-tracker toggle is enabled and on for a character with SSO credentials", %{
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
      assert toggle_html =~ "Stop auto-tracking this character"
      assert Tripwire.Tracking.tracking?(character)
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

  test "topbar character dropdown adds and switches characters", %{
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

      assert has_element?(
               view,
               "nav button[phx-click='switch-character'][phx-value-id='#{other.id}']"
             )

      refute has_element?(view, "nav button[phx-click='remove-character']")

      assert html =~ "Manage masks"

      view |> element("#settings-button") |> render_click()
      render_click(view, "settings-tab", %{"tab" => "account"})

      view
      |> element(~s|#character-card-#{other.id} button[title="Remove Second Char"]|)
      |> render_click()

      html = render(view)
      assert html =~ "Removed Second Char"
      refute html =~ "Remove Second Char"

      refute has_element?(
               view,
               "button[phx-click='switch-character'][phx-value-id='#{other.id}']"
             )

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

  test "topbar mask dropdown shows the selected mask name", %{conn: conn, character: character} do
    {:ok, character} =
      Accounts.update_character(character, %{
        corporation_id: 98_000_001,
        corporation_name: "Test Corp"
      })

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    personal = Enum.find(Masks.list_masks_for_character(character.id), &(&1.kind == "personal"))

    corporation =
      Enum.find(Masks.list_masks_for_character(character.id), &(&1.kind == "corporation"))

    assert view |> element("#topbar-mask") |> render() =~ personal.name

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{corporation.id}"]|)
    |> render_click()

    assert view |> element("#topbar-mask") |> render() =~ "Test Corp"
  end

  test "topbar mask dropdown lists every mask but the demo mask", %{
    conn: conn,
    character: character
  } do
    {:ok, other_mask} = Masks.create_mask(%{name: "Other Corp", kind: "corporation"})
    {:ok, demo_mask} = Masks.ensure_demo_mask()

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    refute Enum.any?(Masks.list_masks_for_character(character.id), &(&1.id == other_mask.id))

    assert has_element?(
             view,
             ~s|button[phx-click="switch-mask"][phx-value-id="#{other_mask.id}"]|
           )

    refute has_element?(
             view,
             ~s|button[phx-click="switch-mask"][phx-value-id="#{demo_mask.id}"]|
           )

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{other_mask.id}"]|)
    |> render_click()

    assert view |> element("#topbar-mask") |> render() =~ "Other Corp"

    view |> element("#settings-button") |> render_click()
    assert has_element?(view, "#mask-card-#{other_mask.id}")
    refute has_element?(view, "#mask-card-#{demo_mask.id}")
  end

  test "a new mask map starts with a Jita node holding the welcome notes", %{
    conn: conn,
    character: character
  } do
    {:ok, mask} = Masks.create_mask(%{name: "Fresh Corp", kind: "corporation"})
    {:ok, _} = Masks.add_membership(mask, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{mask.id}"]|)
    |> render_click()

    [map] = Mapping.list_maps_for_mask(mask.id)
    jita = Enum.find(Mapping.list_systems(map.id), &(&1.name == "Jita"))

    assert jita
    assert [%{body: shortcuts}, %{body: markdown}] = Mapping.list_comments(jita.id)
    assert shortcuts =~ "# Shortcuts"
    assert markdown =~ "**Bold**"
  end

  test "switching to a mask with an empty map seeds the Jita notes", %{
    conn: conn,
    character: character
  } do
    {:ok, mask} = Masks.create_mask(%{name: "Old Corp", kind: "corporation"})
    {:ok, _} = Masks.add_membership(mask, character)
    {:ok, map} = Mapping.create_map(%{name: "Home", mask_id: mask.id})

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{mask.id}"]|)
    |> render_click()

    jita = Enum.find(Mapping.list_systems(map.id), &(&1.name == "Jita"))

    assert jita
    assert [%{body: shortcuts}, %{body: markdown}] = Mapping.list_comments(jita.id)
    assert shortcuts =~ "# Shortcuts"
    assert markdown =~ "**Bold**"
  end

  test "removing the last character of a corporation prunes its mask", %{
    conn: conn,
    character: character
  } do
    {:ok, other} =
      Accounts.upsert_character(%{
        eve_id: 43_500,
        name: "Corp Pilot",
        corporation_id: 98_000_044,
        corporation_name: "Leaving Corp"
      })

    {:ok, corp_mask} = Masks.ensure_corporation_mask(other)

    session =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id, other.eve_id]
      })

    {:ok, view, _html} = live(session, ~p"/dashboard")

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{corp_mask.id}"]|)
    |> render_click()

    assert view |> element("#topbar-mask") |> render() =~ "Leaving Corp"

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "account"})

    view
    |> element(~s|#character-card-#{other.id} button[title="Remove Corp Pilot"]|)
    |> render_click()

    refute has_element?(
             view,
             ~s|button[phx-click="switch-mask"][phx-value-id="#{corp_mask.id}"]|
           )

    assert view |> element("#topbar-mask") |> render() =~ "Private"
    refute Enum.any?(Masks.list_masks(), &(&1.id == corp_mask.id))
    assert Mapping.list_maps_for_mask(corp_mask.id) == []
  end

  test "the personal mask is shared by every character", %{conn: conn, character: character} do
    {:ok, other} = Accounts.upsert_character(%{eve_id: 44_100, name: "Other Pilot"})

    {:ok, personal} = Masks.ensure_personal_mask(character)
    {:ok, same} = Masks.ensure_personal_mask(other)

    assert personal.id == same.id
    assert personal.name == "Private"

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    assert view |> element("#topbar-mask") |> render() =~ "Private"
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

  test "account cards show every character's ship and location and switch on selection", %{
    conn: conn,
    character: character
  } do
    {:ok, other} = Accounts.upsert_character(%{eve_id: 43_100, name: "lostcoastwizard"})

    session =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id, other.eve_id]
      })

    {:ok, view, _html} = live(session, ~p"/dashboard")

    send(view.pid, {
      :topbar_loaded,
      %{
        tq_online: true,
        tq_players: 1000,
        current_system_name: "Jita",
        character_online: true,
        ship_type_id: 587,
        presences: %{
          character.eve_id => %{
            system_name: "Jita",
            online: true,
            ship_name: "Rifter",
            ship_type_id: 587
          },
          other.eve_id => %{
            system_name: "J231710",
            online: false,
            ship_name: "/",
            ship_type_id: 81_047,
            ship_type_name: "Torrent"
          }
        },
        now: DateTime.utc_now()
      }
    })

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "account"})

    current_card = view |> element("#character-card-#{character.id}") |> render()
    other_card = view |> element("#character-card-#{other.id}") |> render()

    assert current_card =~ "Rifter · Jita"
    assert current_card =~ "https://images.evetech.net/types/587/render?size=64"
    assert current_card =~ "avatar avatar-online"
    assert current_card =~ "border-success"
    refute current_card =~ "Current"

    assert other_card =~ "Torrent · J231710"
    assert other_card =~ "https://images.evetech.net/types/81047/render?size=64"
    assert other_card =~ ~s(class="size-8 object-contain")
    assert other_card =~ "Offline"
    assert other_card =~ "avatar avatar-offline"
    refute other_card =~ "border-success"

    assert other_card =~
             ~s(phx-click="switch-character")

    assert other_card =~ ~s(phx-value-id="#{other.id}")
  end

  test "account character cards keep session order and expose keyboard navigation", %{
    conn: conn,
    character: character
  } do
    {:ok, other} = Accounts.upsert_character(%{eve_id: 43_200, name: "Second Char"})

    session =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => other.eve_id, "name" => other.name},
        "character_ids" => [character.eve_id, other.eve_id]
      })

    {:ok, view, _html} = live(session, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    html = render_click(view, "settings-tab", %{"tab" => "account"})

    {first, _} = :binary.match(html, "character-card-#{character.id}")
    {second, _} = :binary.match(html, "character-card-#{other.id}")

    assert first < second
    assert html =~ ~s(phx-hook="CardGrid")
    assert html =~ "data-card-grid"

    assert view |> element("#character-card-#{other.id}") |> render() =~
             ~s(role="button")

    assert has_element?(view, "#character-card-#{other.id}[data-card][tabindex='0']")
    assert has_element?(view, "#character-card-#{character.id}[data-card][tabindex='-1']")
    assert has_element?(view, "#character-card-#{other.id}[aria-current='true']")
    refute has_element?(view, "#character-card-#{character.id}[aria-current='true']")
  end

  test "switching characters from the account tab keeps settings open", %{
    conn: conn,
    character: character
  } do
    {:ok, other} = Accounts.upsert_character(%{eve_id: 43_400, name: "Live Switch"})
    eve_id = other.eve_id

    session =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "character_ids" => [character.eve_id, other.eve_id]
      })

    {:ok, view, _html} = live(session, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "account"})

    view
    |> element("#character-card-#{other.id} button[phx-click='switch-character']")
    |> render_click()

    assert has_element?(view, "#settings-widget")
    assert has_element?(view, "#character-card-#{other.id}.border-success")
    refute has_element?(view, "#character-card-#{character.id}.border-success")

    assert_push_event(view, "character-switched", %{eve_id: ^eve_id})
  end

  test "the selected mask survives a reload", %{conn: conn, character: character} do
    {:ok, mask} = Masks.create_mask(%{name: "Persisted Corp", kind: "corporation"})
    {:ok, _} = Masks.add_membership(mask, character)

    session =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{"id" => character.eve_id, "name" => character.name},
        "mask_id" => mask.id
      })

    {:ok, view, _html} = live(session, ~p"/dashboard")

    assert view |> element("#topbar-mask") |> render() =~ "Persisted Corp"
    assert [map] = Mapping.list_maps_for_mask(mask.id)
    assert Enum.any?(Mapping.list_systems(map.id), &(&1.name == "Jita"))
  end

  test "switching masks stores the choice in the session", %{
    conn: conn,
    character: character
  } do
    {:ok, mask} = Masks.create_mask(%{name: "Remember Me", kind: "corporation"})
    {:ok, _} = Masks.add_membership(mask, character)
    mask_id = mask.id

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view
    |> element(~s|button[phx-click="switch-mask"][phx-value-id="#{mask.id}"]|)
    |> render_click()

    assert view |> element("#topbar-mask") |> render() =~ "Remember Me"
    assert_push_event(view, "mask-switched", %{mask_id: ^mask_id})
  end

  test "mask cards switch the active mask when selected", %{conn: conn, character: character} do
    {:ok, personal} = Masks.ensure_personal_mask(character)

    {:ok, other_mask} =
      Masks.create_mask(%{
        name: "Corp Ops",
        kind: "corporation",
        owner_character_id: character.id
      })

    {:ok, _} = Masks.add_membership(other_mask, character)

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "account"})

    assert has_element?(view, "#mask-card-#{personal.id}.border-success")
    assert has_element?(view, "#mask-card-#{personal.id} .avatar-online")
    refute has_element?(view, "#mask-card-#{other_mask.id}.border-success")

    view
    |> element("#mask-card-#{other_mask.id} button[phx-click='switch-mask']")
    |> render_click()

    assert has_element?(view, "#mask-card-#{other_mask.id}.border-success")
    assert has_element?(view, "#mask-card-#{other_mask.id} .avatar-online")
    refute has_element?(view, "#mask-card-#{personal.id}.border-success")
    refute has_element?(view, "#mask-card-#{personal.id} .avatar-online")
  end

  test "mask cards show corporation logos and a placeholder for the personal mask", %{
    conn: conn,
    character: character
  } do
    {:ok, personal} = Masks.ensure_personal_mask(character)

    {:ok, corp} =
      Masks.create_mask(%{
        name: "Corp Ops",
        kind: "corporation",
        eve_owner_id: 98_000_002
      })

    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "account"})

    assert view |> element("#mask-card-#{corp.id}") |> render() =~
             "https://images.evetech.net/corporations/98000002/logo?size=64"

    assert view |> element("#mask-card-#{personal.id}") |> render() =~
             "/images/alliance-default.png"
  end

  test "removing the current character from the account tab navigates away", %{
    conn: conn,
    character: character
  } do
    {:ok, view, _html} = live(login(conn, character), ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    render_click(view, "settings-tab", %{"tab" => "account"})

    assert {_, {:live_redirect, %{to: "/dashboard"}}} =
             view
             |> element(
               ~s|#character-card-#{character.id} button[title="Remove #{character.name}"]|
             )
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
