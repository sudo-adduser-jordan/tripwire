# zTripwire

## Logging

Structured wide-event logging via `Ztripwire.Log` (`lib/ztripwire/log.ex`).

- One wide event per request via `ZtripwireWeb.Plugs.WideEvent`, enriched through the request lifecycle and emitted once at the end.
- JSONL log files under `./logs/`:
  - `./logs/test/YYYY-MM-DD.jsonl` for debug and info events
  - `./logs/errors/YYYY-MM-DD.jsonl` for warning and error events
- Console output is pretty printed with colors for levels, keys, values, and value types (string, number, boolean, nil, map, list).
- Tail sampling in `Ztripwire.Log.keep?/2`: errors, warnings, events with an `error` field, and requests slower than 2000 ms are always kept; everything else is sampled at the configured `sample_rate`.
- Configuration in `config/config.exs` under `config :ztripwire, Ztripwire.Log` with `service`, `sample_rate`, `test_path`, and `error_path`.

## Task Automation

Automation uses `Taskfile.yml` (Task v3); server lifecycle tasks run inline shell commands.

| Task | Description |
|---|---|
| `task install` | Install Elixir, Node, and asset dependencies |
| `task update` | Update Elixir and Node dependencies |
| `task remove` | Remove build artifacts and installed dependencies |
| `task setup` | First-time setup of database, assets, SDE, and log directories; downloads the official JSONL SDE to `priv/sde/`, rebuilds `priv/data/wormhole_systems.json`, then syncs the `sde_*` tables; safe to run while the server is up |
| `task migrate` | Run database migrations for dev and test, backfill missing system class/effect/statics, then sync the `sde_*` tables |
| `task start` | Restart the production server in the background (`DATABASE_PATH` defaults to `./priv/db/ztripwire-prod.db`), sync the `sde_*` tables, and wait until it answers before printing the URL |
| `task stop` | Stop the background production server |
| `task dev` | Stop the production server, run dev migrations, then boot `MIX_ENV=dev mix phx.server` attached on port `4000` with live reload; Ctrl-C stops it |

In dev, `MIX_ENV=dev` also starts the Erlang `:os_mon` application, so the LiveDashboard at `/dev/dashboard` serves CPU, memory, and disk data on its `/dev/dashboard/os_mon` page. `:os_mon` stays off in test and prod.

## Demo Mode

zTripwire needs no configuration to try it. When `EVESSO_CLIENT_ID` or `EVESSO_CLIENT_SECRET` is missing, the landing page still opens at `/` with the EVE SSO button disabled; a **Demo Mask** button enters the demo dashboard (`/dashboard`) backed by an in-memory fixture. The demo never reads or writes the database: its character, mask, map, signatures and notes are built per visitor, edits are ephemeral and reset on reload, and no demo rows are stored. Set both variables to enable EVE SSO login and personal maps.

The chain map hides systems that drop out of the chain. **Edit Map → Known space** persists a per-map flag that also renders detached chains, single-node chains, and systems missing from the database that a tracked character is in, each rooted at level 0 beside the home chain; the setting survives reloads and lives in `user_settings.show_all`. Connections that close a loop are not drawn as lines — the newest link in the cycle is the one left out, and only its endpoints (the scanned system and its candidate peer) get the dashed outline and glow, leaving the existing chain untouched. A paste that only links systems keeps the tree exactly where it was; only removals (dropped connections or hidden systems) re-level the remaining nodes. A scanned wormhole with no connection yet gets an empty unknown placeholder node at the end of the chain — class, name, and signature lines stay blank like an unscanned Tripwire node — which becomes the real system once the hole is jumped or linked, or as soon as a signature's **Leads** points the hole at the real system. The demo fixture map is rooted at its `Home` system (J150321) and ships two of these empty leaf nodes, so pasting a scan and confirming **delete missing sigs** collapses the detached branches exactly as on a configured map, and a removed wormhole signature also clears its paired signature on the far side. It also carries one looped hole (`J150325` ↔ `Amarr`), so the demo shows the loop hint on two nodes. Demo presence adds ten corp mates to the tracked Demo User: three stack at `Home`, two at Jita, and one each at Amarr, Dodixie, Rens, `J150323` and `J150334`, which exercises the shared badge, its count bubble and the multi-row character tooltip. The map panel fills the window height by default and refits when the window resizes, so the chain is laid out at a readable size no matter how tall the screen is.

Map data belongs to the mask rather than to a map tab. Every tab of a mask reads and writes the same systems, connections, signatures and notes, so a scan pasted once appears on all of them; each tab keeps only its name, home system and node positions (`map_view_systems`), which means tabs can render the same chain from different roots and layouts without duplicating signature data.

The signature widget lists every signature with its wormhole Mass state, its Age (time since the scan), and its Life state derived from the remaining lifetime: **Stable** above four hours, **EOL** under four hours, **Critical** under one hour, and **Expired** at zero, with the exact countdown kept in the Life tooltip. Clicking a row keeps its highlight; Ctrl/Cmd+click toggles rows into a multi-selection, and Ctrl/Cmd+A selects every row while the widget has focus.

Node and signature fields are editable in place. Clicking a node's name or signature line opens the signature editor for that node's signature — a node with no signature opens the add dialog, so an unmapped hole is pointed at the real system through **Leads** instead of renaming the node; the system security, effect and static wormhole codes stay read-only because they describe the solar system rather than the map, and the effect shows its icon beside the name. There is no separate system editor. The signature row's pencil opens **Edit Signature**, laid out like upstream Tripwire: a three-letter/three-digit ID pair beside the signature-type select (Unknown, Combat, Wormhole, Ore, Data, Gas, Relic), a days/hours/minutes length, and — for wormholes only — a **Type** code (quick picks fill eligible codes), a **Leads** field with class chips (C1–C6, HS, LS, NS, Trig, Drifter), a free-text **Name**, **Life** radios (Stable / EOL / <1h) and **Mass** radios (Stable / <50% / <10%), followed by an **Other Side** panel with its own ID, code and name. Picking a code fills the length from the hole type, and Leads re-points, adds or relabels the far side. Saving re-stamps the scan time (the dialog has no scan-time field), and the Age, Life and pruning state follow it; the ESI type ID and bookmark are preserved invisibly.

## System data

Wormhole space systems carry their class (`C1`–`C6`, `Thera`, `C13`, `Trig`, `Drifter`), system-wide effect (Magnetar, Pulsar, …) and static wormhole codes. The data is built once from the downloaded SDE plus the vendored statics list into `priv/data/wormhole_systems.json` (see `priv/data/README.md`) and stored on each map system.

- `mix ztripwire.build_wormhole_systems` rebuilds the dataset from `priv/sde/eve-online-static-data-latest-jsonl.zip` and `priv/data/wormhole_statics.json`; `task setup` runs it after refreshing the SDE.
- Chain-map effect glyphs reuse the icon outlines from the upstream Tripwire project's MIT-licensed icon font (`public/fonts/tripwire.json`); the paths are inlined and tinted with upstream's per-effect colours.

### SDE tables

`mix ztripwire.sync_sde` loads the static data export into the read-only `sde_*` tables: `sde_systems` (name, security, region/constellation ids, star class/temperature/luminosity/radius, planet/moon/belt/station counts and map flags), `sde_regions`, `sde_constellations`, `sde_gates` (both directions), `sde_stations` (owner, operation, type and services), `sde_types` (ships, structures and every type the stations reference), `sde_factions`, and `sde_version` with the archive's build number.

- It skips the sync when `sde_version.build_number` already matches the archive; pass `--force` to reload, or `--sde path` to read another archive.
- `task setup`, `task migrate`, `task start` and `task dev` run it after migrations; the web application also reads `mapStargates.jsonl` and `mapSolarSystems.jsonl` from the archive at boot for gate neighbours and system search.
- The tables are reference data only. A map system keeps its own `sys_class`, `effect` and `statics` for mapper edits.

When the selected system is k-space, the System widget's statistics selector also lists every one-jump stargate neighbour, whether or not it is already on the map, so activity around a high-sec or low-sec exit can be checked without adding it to the chain. The selector lists only systems connected to the selected one: the chain row holds its map connections (the selected system itself is not repeated), and the gate row holds the remaining stargate neighbours (a neighbour that is already a chain connection appears once). Clicking a gate neighbour that is already a map node selects that node, so signatures, notes and the favourite toggle follow; an off-chain gate system only switches the widget's statistics and the `/:system_name` URL and never creates a map node. The adjacency matrix is read from the SDE's `mapStargates.jsonl` at boot, and `task dev`/`task start` fetch and sync the SDE archive first.
- New systems are filled from the dataset when they are added or converted from an unknown placeholder.
- `mix ztripwire.backfill_system_data` fills missing values on existing systems (run by `task migrate`/`task start`); add `--force` to overwrite edited classes, effects and statics.

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
   | `DATABASE_PATH` | yes | SQLite file on a persistent volume, e.g. `/data/ztripwire-prod.db` |
   | `PHX_SECRET_KEY_BASE` | yes | Cookie/session signing secret; generate with `mix phx.gen.secret`. Changing it invalidates existing sessions |
   | `ZTRIPWIRE_CLOAK_KEY` | yes | Base64 32-byte key encrypting ESI refresh tokens at rest; generate with `openssl rand -base64 32`. Changing it makes stored tokens unreadable |
   | `PORT` | no | HTTP port, defaults to `4000` |
   | `POOL_SIZE` | no | Database pool size, defaults to `10` |
   | `PHX_HOST` | no | Public host used for generated URLs, defaults to `example.com` |
   | `EVESSO_CLIENT_ID` | no | EVE SSO client ID; login stays in demo mode when unset |
   | `EVESSO_CLIENT_SECRET` | no | EVE SSO client secret; login stays in demo mode when unset |
   | `EVESSO_CALLBACK_URL` | no | Public SSO callback URL, e.g. `https://example.com/auth/evesso/callback`; defaults to the request URL |
   | `EVESSO_SECRET_KEY` | no | Legacy alias for `EVESSO_CLIENT_SECRET` |
   | `ZTRIPWIRE_USER_AGENT` | no | ESI `User-Agent`; set it to the app version plus a contact address and source URL, e.g. `Ztripwire/1.0 (ops@example.com; +https://example.com/repo)` |
   | `ZTRIPWIRE_ESI_COMPATIBILITY_DATE` | no | ESI `X-Compatibility-Date`, defaults to `2026-05-18`; re-verify the routes when raising it |
   | `ZTRIPWIRE_ADMIN_CHARACTER_IDS` | no | Comma-separated EVE character ids promoted to admin at login; set it before deploying an upgrade so the current admin stays admin |
   | `ZTRIPWIRE_ADMIN_CORPORATION_IDS` | no | Comma-separated EVE corporation ids whose characters are promoted to admin at login |

3. Start the server:

   ```sh
   task start   # build + digest assets, boot in prod, log to logs/prod.log
   tail -f logs/prod.log
   task stop    # stop the background server
   ```

`task dev` stops the production server, runs dev migrations, and boots the development server in the foreground on port `4000`, with live reload and the esbuild/tailwind watchers from `config/dev.exs`; Ctrl-C stops it. `task start` rebuilds and digests assets before boot so `cache_static_manifest` resolves, then waits until the endpoint reports it is listening before printing the URL. If the port is already taken the task fails and prints the tail of `logs/prod.log`.

Production sets `force_ssl` with `rewrite_on: [:x_forwarded_proto]`, so terminate TLS in a reverse proxy (or a platform edge) and forward `X-Forwarded-Proto: https`. Plain `http://` requests to a non-loopback host are redirected to `https`.
