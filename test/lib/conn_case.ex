defmodule ZtripwireWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ZtripwireWeb.Endpoint

      use ZtripwireWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import ZtripwireWeb.ConnCase
    end
  end

  setup tags do
    Ztripwire.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
