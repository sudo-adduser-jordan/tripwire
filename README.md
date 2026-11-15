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

Automation uses `Taskfile.yml` (Task v3). No external scripts; every task runs inline commands with colored log prefixes.

| Task | Description |
|---|---|
| `task install` | Install Elixir, Node, and asset dependencies |
| `task update` | Update Elixir and Node dependencies |
| `task remove` | Remove build artifacts and installed dependencies |
| `task setup` | First-time setup of database, assets, and log directories |
| `task migrate` | Run database migrations for dev and test |
| `task start` | Start the production server (requires `DATABASE_PATH`, `SECRET_KEY_BASE`, `TRIPWIRE_ENCRYPTION_KEY`) |
| `task stop` | Stop running Tripwire server processes |
| `task dev` | Start the development server with live reload |
