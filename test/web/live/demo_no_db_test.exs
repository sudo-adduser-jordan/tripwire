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

    render_click(view, "global-paste", %{
      "text" => "NEW-001\tCosmic Signature\tUnstable Wormhole (K162)\t100.00%\t1.00 AU"
    })

    view |> element("#note-compose-toggle") |> render_click()

    view
    |> element("form[phx-submit='comment-submit']")
    |> render_submit(%{"comment" => "demo note"})

    render_click(view, "toggle-favorite", %{})

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
