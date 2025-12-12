defmodule TripwireWeb.DashboardHTML do
  use TripwireWeb, :html
  embed_templates "../pages/dashboard.html"

  def users do
    [
      %{id: 1, username: "alice"},
      %{id: 2, username: "bob"},
      %{id: 3, username: "charlie"},
      %{id: 4, username: "diana"},
      %{id: 5, username: "eve"}
    ]
  end

  def post do
  %{title: "Sample post", views: 123}
  end

end
