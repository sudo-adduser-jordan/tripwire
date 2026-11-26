defmodule TripwireWeb.DemoNoDbTest do
  use TripwireWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    handler = {__MODULE__, self()}
    parent = self()

    :telemetry.attach(
      handler,
      [:tripwire, :repo, :query],
      fn _event, _measurements, metadata, _config ->
        send(parent, {:repo_query, metadata[:source], metadata[:query]})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)
    :ok
  end

  test "anonymous demo never queries the repo", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#settings-button") |> render_click()
    view |> element("#toggle-row-guides") |> render_click()
    view |> element("#lock-button") |> render_click()

    render_click(view, "toggle-collapse", %{"id" => "10"})
    render_click(view, "expand-all", %{})

    render_click(view, "global-paste", %{
      "text" => "NEW-001\tCosmic Signature\tUnstable Wormhole (K162)\t100.00%\t1.00 AU"
    })

    view |> element("#note-compose-toggle") |> render_click()

    view
    |> element("form[phx-submit='comment-submit']")
    |> render_submit(%{"comment" => "demo note"})

    render_click(view, "toggle-favorite", %{})

    view
    |> element("#chain-map text[phx-click='open-system']", "Home")
    |> render_click()

    view
    |> element("#sys-modal button[phx-click='close-sys-modal']")
    |> render_click()

    view
    |> element("#signatures button.font-mono[title='Edit signature']", "ABC-123")
    |> render_click()

    assert render(view) =~ "Edit Signature"

    view
    |> element("#sig-modal form[phx-submit='save-signature']")
    |> render_submit(%{
      "sig" => %{
        "sig_id" => "ABC-123",
        "kind" => "signature",
        "site_type" => "wormhole",
        "type_name" => "Unstable Wormhole (O477)",
        "type_id" => "30744",
        "life_length" => "259200",
        "scanned_at" => "2026-01-01T08:00",
        "bookmark" => "Demo"
      }
    })

    refute render(view) =~ "sig-modal"

    view
    |> element("#chain-map text[phx-click='open-system']", "Home")
    |> render_click()

    view
    |> element("#sys-modal form[phx-submit='update-system']")
    |> render_submit(%{"system" => %{"name" => "J150321", "alias" => "Home Base"}})

    refute render(view) =~ "sys-modal"
    assert render(view) =~ "Home Base"

    view |> element("#newTab") |> render_click()
    view |> element("#map-edit") |> render_click()
    view |> element("#map-modal #delete-map") |> render_click()

    render_click(view, "toggle-character-visibility", %{"id" => "1"})
    render_click(view, "toggle-ship-visibility", %{"id" => "1"})

    view |> element("#map-edit") |> render_click()
    render_submit(view, "save-map-settings", %{"map" => %{"name" => "Demo", "home" => "Home"}})

    render_click(view, "apply-layout", %{"id" => "core:compact"})
    render_click(view, "reset-layout", %{})
    render_click(view, "delete-layout", %{"id" => "core:compact"})

    render_click(view, "settings-tab", %{"tab" => "statistics"})
    render_click(view, "settings-tab", %{"tab" => "admin"})

    queries = collect_queries([])
    assert queries == []
  end

  defp collect_queries(acc) do
    receive do
      {:repo_query, source, query} -> collect_queries([{source, query} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
