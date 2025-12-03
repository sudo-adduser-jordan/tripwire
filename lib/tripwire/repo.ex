defmodule Tripwire.Repo do
  use Ecto.Repo,
    otp_app: :tripwire,
    adapter: Ecto.Adapters.Postgres
end
