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
| `task dev` | Stop the production server, run dev migrations, rebuild the demo seed with `mix tripwire.reset_demo`, then boot `MIX_ENV=dev mix phx.server` attached on port `4000` with live reload; Ctrl-C stops it |

In dev, `MIX_ENV=dev` also starts the Erlang `:os_mon` application, so the LiveDashboard at `/dev/dashboard` serves CPU, memory, and disk data on its `/dev/dashboard/os_mon` page. `:os_mon` stays off in test and prod.

## Demo Mode

Tripwire needs no configuration to try it. When `EVESSO_CLIENT_ID` or `EVESSO_SECRET_KEY` is missing, the landing page still opens at `/` with the EVE SSO button disabled; a **Demo** button enters the demo dashboard (`/dashboard`) backed by its own editable `demo` mask and map. Set both variables to enable EVE SSO login and personal maps.

The chain map hides systems that drop out of the chain. **Edit Chain → Show all chains** persists a per-map flag that also renders detached chains and single-node chains, each rooted at level 0 beside the home chain; the setting survives reloads and lives in `maps.show_all`. Connections that close a loop are not drawn as lines — the newest link in the cycle is the one left out, while loop systems keep their dashed outline and glow. The demo map is rooted at its `Home` system (J150321), so pasting a scan and confirming **delete missing sigs** collapses the detached branches exactly as on a configured map, and a removed wormhole signature also clears its paired signature on the far side.

## Deploy

Deploys run the server in `MIX_ENV=prod` and are driven by the `start` and `stop` tasks. `task dev` runs the development server instead.

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
   task start   # build + digest assets, boot in prod, log to logs/prod.log
   tail -f logs/prod.log
   task stop    # stop the background server
   ```

`task dev` stops the production server, runs dev migrations, and boots the development server in the foreground on port `4000`, with live reload and the esbuild/tailwind watchers from `config/dev.exs`; Ctrl-C stops it. `task start` rebuilds and digests assets before boot so `cache_static_manifest` resolves, then waits until the endpoint reports it is listening before printing the URL. If the port is already taken the task fails and prints the tail of `logs/prod.log`.

Production sets `force_ssl` with `rewrite_on: [:x_forwarded_proto]`, so terminate TLS in a reverse proxy (or a platform edge) and forward `X-Forwarded-Proto: https`. Plain `http://` requests to a non-loopback host are redirected to `https`.
