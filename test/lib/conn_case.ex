defmodule TripwireWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint TripwireWeb.Endpoint

      use TripwireWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import TripwireWeb.ConnCase
    end
  end

  setup tags do
    Tripwire.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
