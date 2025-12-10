defmodule TripwireWeb.SettingsController do
  use TripwireWeb, :controller

  def settings(conn, %{"user" => user}) do
    render(conn, :settings, user: user)
  end
end
