defmodule Ztripwire.Repo do
  use Ecto.Repo,
    otp_app: :ztripwire,
    adapter: Ecto.Adapters.SQLite3
end
