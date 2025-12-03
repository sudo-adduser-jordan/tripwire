defmodule TripwireWeb.PageController do
  use TripwireWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
