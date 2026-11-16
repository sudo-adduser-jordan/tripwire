# Tripwire

## Logging

Structured wide-event logging via `Tripwire.Log` (`lib/tripwire/log.ex`).

- One wide event per request via `TripwireWeb.Plugs.WideEvent`, enriched through the request lifecycle and emitted once at the end.
- JSONL log files under `./logs/`:
  - `./logs/test/YYYY-MM-DD.jsonl` for debug and info events
  - `./logs/errors/YYYY-MM-DD.jsonl` for warning and error events
- Console output is pretty printed with colors for levels, keys, values, and value types (string, number, boolean, nil, map, list).
- Tail sampling in `Tripwire.Log.keep?/2`: errors, warnings, events with an `error` field, and requests slower than 2000 ms are always kept; everything else is sampled at the configured `sample_rate`.
- Configuration in `config/config.exs` under `config :tripwire, Tripwire.Log` with `service`, `sample_rate`, `test_path`, and `error_path`.

## Task Automation

Automation uses `Taskfile.yml` (Task v3); server lifecycle tasks run inline shell commands.

| Task | Description |
|---|---|
| `task install` | Install Elixir, Node, and asset dependencies |
| `task update` | Update Elixir and Node dependencies |
| `task remove` | Remove build artifacts and installed dependencies |
| `task setup` | First-time setup of database, assets, SDE, and log directories; downloads the official JSONL SDE to `priv/sde/`; safe to run while the server is up |
| `task migrate` | Run database migrations for dev and test |
| `task start` | Restart the production server in the background (`DATABASE_PATH` defaults to `./priv/db/tripwire-prod.db`) and wait until it answers before printing the URL |
| `task stop` | Stop the background production server |
| `task dev` | Attach to the last 100 lines and follow the server log; Ctrl-C detaches without stopping the server |

## Demo Mode

Tripwire needs no configuration to try it. When `EVESSO_CLIENT_ID` or `EVESSO_SECRET_KEY` is missing, the landing page still opens at `/` with the EVE SSO button disabled; a **Demo** button enters the demo dashboard (`/dashboard/User`) backed by its own editable `demo` mask and map. Set both variables to enable EVE SSO login and personal maps.

## Deploy

Deploys run the server in `MIX_ENV=prod` and are driven by the `start`, `stop`, and `dev` tasks.

1. Install dependencies and prepare the database, logs, and assets:

   ```sh
   task install
   task setup
   MIX_ENV=prod mix ecto.migrate
   ```

2. Export the runtime configuration:

   | Variable | Required | Description |
   |---|---|---|
   | `DATABASE_PATH` | yes | SQLite file on a persistent volume, e.g. `/data/tripwire-prod.db` |
   | `PORT` | no | HTTP port, defaults to `4000` |
   | `POOL_SIZE` | no | Database pool size, defaults to `10` |
   | `PHX_HOST` | no | Public host used for generated URLs, defaults to `example.com` |
   | `EVESSO_CLIENT_ID` | no | EVE SSO client ID; login stays in demo mode when unset |
   | `EVESSO_SECRET_KEY` | no | EVE SSO client secret, alias of `EVESSO_CLIENT_SECRET` |

3. Start the server:

   ```sh
   task start   # digest assets, boot in prod, log to logs/prod.log
   task dev     # follow logs/prod.log
   task stop    # stop the background server
   ```

`task start` runs `mix phx.digest` before boot so `cache_static_manifest` resolves, then waits until the endpoint reports it is listening before printing the URL. If the port is already taken the task fails and prints the tail of `logs/prod.log`.

Production sets `force_ssl` with `rewrite_on: [:x_forwarded_proto]`, so terminate TLS in a reverse proxy (or a platform edge) and forward `X-Forwarded-Proto: https`. Plain `http://` requests to a non-loopback host are redirected to `https`.
