# User Generated

## Tools
- never use sleep

## Ask

- Always use the ask feature when presenting options, choices, or decisions to the user.
- Never present options as plain text, markdown lists, or chat output when the ask tool is available.

## Comments

- No comments in source code.
- Do not create comments in the codebase.
- Documentation lives in the project's markdown files.

## Logging

Reference: https://loggingsucks.com/

- Default log paths under `./logs/`:
  - `./logs/test`
  - `./logs/errors`
- Use JSONL for log files.
- Pretty print logs.
- Color logs, keys, values, and value types.

## Task Automation

Reference: https://taskfile.dev/docs/reference/schema

- Do not use external scripts.
- Use default command set:
  - `install`
  - `update`
  - `remove`
  - `setup`
  - `migrate`
  - `start`
  - `stop`
  - `dev`

- add colored logging
- [command] content

## Commits

- never write descriptions
- use user defined commit message format
- `tag: statement of change`
```sh
add: 
update: 
remove: 
move: 
feature:
fix:
```
- if a tag does not exist in the above list, suggest one

- always commit to current branch
- never create a new branch unless asked
- do not push

# End User Generated

# Project Reference

- similar to https://bitbucket.org/daimian/tripwire

## Stack

- Elixir (~> 1.19) with Phoenix (~> 1.8), Ecto + SQLite (`ecto_sqlite3`), Bandit adapter, LiveView, Swoosh mailer, Cloak vault, Ueberauth EVE Online.
- Compiled paths: `lib`, `web`, plus `test` under `MIX_ENV=test` (`mix.exs` `elixirc_paths`).
- Mix aliases: `setup` (deps.get, ecto.setup, assets.setup, assets.build), `ecto.setup`, `ecto.reset`, `test` (create, migrate, test), `assets.setup/build/deploy`, `precommit` (compile warnings-as-errors, deps.unlock, format, test).

## Layout

- `lib/tripwire/` contexts: `accounts`, `esi`, `mapping`, `masks`, `signatures`, `tracking`, plus `sync_server`, `vault`, `repo`, `mailer`.
- `lib/tripwire/log.ex`: `Tripwire.Log` wide-event logger.
- `web/`: `endpoint.ex`, `router.ex`, `telemetry.ex`, `controllers/`, `live/`, `components/`, `plugs/wide_event.ex`.
- `config/`: `config.exs` base plus `dev.exs`, `test.exs`, `prod.exs`, `runtime.exs` (prod requires `DATABASE_PATH`; EVE SSO is optional).
- `priv/repo/` migrations and seeds; `assets/` Node front end (`package.json` deploy runs `mix assets.deploy`); `test/` mirrors `lib` and `web`.
- Runtime log dirs (gitignored): `logs/test/`, `logs/errors/`.

## Logging

- `Tripwire.Log.new/1` builds a wide event (`timestamp`, `service`, `node`, `pid` merged with caller fields); `put/3` and `merge/2` enrich it.
- `Tripwire.Log.emit/2` accepts `:debug | :info | :warning | :error` with a map or binary message, appends one JSON object per line to `logs/test/YYYY-MM-DD.jsonl` (debug, info) or `logs/errors/YYYY-MM-DD.jsonl` (warning, error), then pretty prints a colored line to stdout.
- `Tripwire.Log.keep?/2` always keeps errors, warnings, events carrying an `error` field, and events with `duration_ms > 2000`; the rest sample at the configured `sample_rate`.
- Config (`config/config.exs`, `config :tripwire, Tripwire.Log`): `service`, `sample_rate`, `test_path`, `error_path`.
- `TripwireWeb.Plugs.WideEvent` (`web/plugs/wide_event.ex`) runs after `Plug.RequestId` in `TripwireWeb.Endpoint`, seeds the event (request_id, method, path, remote_ip, user_agent), and emits status, `duration_ms`, and outcome on `register_before_send`. Use `enrich/2` in controllers or LiveViews to add business context.
- Tests: `test/tripwire/log_test.exs` redirects paths to a tmp dir via `Application.put_env(:tripwire, Tripwire.Log, ...)` and restores afterwards.

## Task Automation

`Taskfile.yml` (Task v3, `silent: true`, `output: group`, `set: [errexit, nounset, pipefail]`, `dotenv: [.env]`). Server lifecycle tasks run inline shell commands and write `tmp/tripwire-prod.pid` plus `logs/prod.log`; other tasks print colored `[name]` prefixes before commands.

| Task | Runs |
|---|---|
| `task install` | `mix deps.get`, `mix assets.setup`, `npm ci --prefix assets` |
| `task update` | `mix deps.update --all`, `npm update --prefix assets` |
| `task remove` | `rm -rf _build deps assets/node_modules priv/static/assets cover tmp` |
| `task setup` | `mkdir -p logs/test logs/errors`, `mix deps.get`, `mix ecto.setup`, `mix assets.setup`, `mix assets.build` |
| `task migrate` | `mix ecto.migrate`, `MIX_ENV=test mix ecto.migrate` |
| `task start` | `task stop`, then launch detached with `DATABASE_PATH` defaulting to `./priv/db/tripwire-prod.db`; block until `logs/prod.log` reports a running endpoint, then print the URL (fails with the log tail if the server dies while booting) |
| `task stop` | stop the managed production process group recorded in `tmp/tripwire-prod.pid`, then wait for the process and port to be released |
| `task dev` | attach to `logs/prod.log`; Ctrl-C detaches without stopping the server |

Server lifecycle blocks run under `sh -c` because Task's built-in shell does not implement `$!` or `kill`.

## Conventions

- No `#` comments in Elixir, Taskfile, or other source files; `#{...}` interpolation inside strings is not a comment. Document in `README.md` or this file instead.
- Tests run with `mix test`; single file with `mix test <path>`. Log tests must not write to real `./logs/`.
- Commits use `tag: statement of change` with one of `add`, `update`, `remove`, `move`, `feature`, `fix`, no body, on the current branch, without pushing.
