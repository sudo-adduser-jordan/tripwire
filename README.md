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
| `task setup` | First-time setup of database, assets, and log directories |
| `task migrate` | Run database migrations for dev and test |
| `task start` | Restart the production server in the background (`DATABASE_PATH` defaults to `./priv/db/tripwire-prod.db`) |
| `task stop` | Stop the background production server |
| `task dev` | Attach to the last 100 lines and follow the server log; Ctrl-C detaches without stopping the server |

## Demo Mode

Tripwire needs no configuration to try it. When `EVESSO_CLIENT_ID` or `EVESSO_SECRET_KEY` is missing, the landing page sends visitors straight to the read-only demo dashboard (`/dashboard/User`). Set both variables to enable EVE SSO login and personal maps.
