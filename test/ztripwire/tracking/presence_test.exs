defmodule Ztripwire.Tracking.PresenceTest do
  use ExUnit.Case, async: false

  alias Ztripwire.Tracking.Presence

  setup do
    Presence.clear()
    on_exit(fn -> Presence.clear() end)
    :ok
  end

  test "counts viewers per character and removes them explicitly" do
    Presence.add_viewer(101, self())
    Presence.add_viewer(101, self())
    assert Presence.viewers(101) == 2

    Presence.remove_viewer(101, self())
    assert Presence.viewers(101) == 1

    Presence.remove_viewer(101, self())
    assert Presence.viewers(101) == 0
  end

  test "drops every viewer when the dashboard process dies" do
    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    Presence.add_viewer(102, pid)
    Presence.add_viewer(103, pid)
    assert Presence.viewers(102) == 1

    send(Presence, {:DOWN, make_ref(), :process, pid, :killed})
    Presence.sync()

    assert Presence.viewers(102) == 0
    assert Presence.viewers(103) == 0

    send(pid, :stop)
  end
end
