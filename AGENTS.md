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

## EVE SSO

- `ueberauth` 0.11 generates the OAuth `state`, keeps it in the signed `ueberauth.state_param` cookie, and exposes it as `conn.private[:ueberauth_state_param]` only during the request phase; `ueberauth_eve_online` 1.0.4 re-checks the callback state against that private value and falls back to the raw signed cookie, which never matches. `AuthController` therefore reseeds the private param from the verified cookie (`Tripwire.SSO.state_param/1`) in a `:restore_state_param` plug before `plug Ueberauth`, keeping both CSRF checks working.
- Failures whose message key is `csrf_attack` or `invalid_state` flash "login session expired, sign in again" (the wide event still logs the raw keys and messages); a stale cookie only needs a browser retry. Other failures are trimmed to their first line and `@detail_limit` characters before they reach the flash or the log, because EVE answers a bad code with a full HTML error page that overflows the session cookie.
- Authorized ESI goes through `Tripwire.ESI.valid_access_token/2`. It reads the SSO client id and secret from `Tripwire.SSO.client_id/0` / `client_secret/0` (environment variables), not the `:ueberauth` app config, which stores `{:system, var}` tuples for Ueberauth to resolve; `refresh_access_token/1` needs the real values. Access tokens live in `Tripwire.ESI.TokenCache`, a `:public` named ETS table because `put/2` and `delete/1` run from LiveViews and tracking pollers, and the rotated refresh token is written back to the character row so an app restart does not fall back to an already-rotated token.
- The registered redirect URI is `http://localhost:4000/auth/evesso/callback`, so browse `localhost`, not `127.0.0.1`. Dev and prod share port 4000 with different `secret_key_base` values, so a cookie left by `task start` makes the first `task dev` login attempt fail once.
- Session payloads go through `TripwireWeb.SessionUser`: `put/2` writes `%{"current_user" => %{"id" => eve_id, "name" => name}}` and merges `"character_ids"`, `get/1` also accepts legacy nested atom-keyed values, and `ids/1` feeds the topbar character list. LiveView receives `Plug.Conn.get_session/1` unchanged, so `DashboardLive.mount/3` must not pattern match atom-keyed nested maps — doing that silently fell back to the demo dashboard for logged-in users. Only anonymous visitors mount the demo; a session user whose character row is gone is redirected to `/` with a "Session expired" flash.
- Settings → Admin is gated on `is_admin`. `Accounts.admin_exists?/0` counts every admin except the seeded Demo User (`Tripwire.Demo.character_eve_id/0`), and when none exists a logged-in non-admin sees the claim modal on a hard dashboard load plus a persistent banner; the first "Make admin" press promotes the character through `Accounts.claim_admin/1` (later presses flash "An admin already exists"). The ESI CEO/Director/Tripwire Admin grant at login is unchanged.

## Layout

- `lib/tripwire/` contexts and support modules: `accounts`, `esi` (+ `esi/token_cache`), `layouts` (core and saved dashboard widget layouts), `mapping` (+ `mapping/system_data` backfill), `masks`, `settings` (single-row user preferences), `signatures` (scan-paste parser), `systems` (class/color tables, `systems/catalog` SDE search index), `wormhole_systems` (per-system class/effect/statics), `tracking` (ESI location pollers and chain upkeep), `wormholes` (hole type database), `eve_images`, `zkill`, `sso`, `notifier`, `markdown`, `log`, plus `sync_server` (background jobs), `vault`, `repo`, `mailer`, `ecto_types`.
- `lib/tripwire/log.ex`: `Tripwire.Log` wide-event logger.
- `web/`: `endpoint.ex`, `router.ex`, `telemetry.ex`, `controllers/` (api, auth, home), `live/` (DashboardLive orchestrator), `live_components/` (Map, Signatures, System, Notes, Navigation, Settings plus `settings/` account/admin/layouts/map/statistics/themes/widgets), `components/` (presentational Core/Flash/Table/List/Input/Icon/Button/Header), `plugs/wide_event.ex`.
- `config/`: `config.exs` base plus `dev.exs`, `test.exs`, `prod.exs`, `runtime.exs` (prod requires `DATABASE_PATH`; EVE SSO is optional).
- `priv/repo/` migrations and seeds; `priv/data/wormholes.json` hole type database; `assets/` Node front end (`package.json` deploy runs `mix assets.deploy`); `test/` mirrors `lib` and `web`.
- Runtime log dirs (gitignored): `logs/test/`, `logs/errors/`.
- The topbar character dropdown (`web/live_components/navigation_live.ex`) lays every character row out as ship toggle, large portrait toggle, name button (character removal lives in Settings → Account): the ship and portrait icons hide/show that character's ship and character on chain through `web/components/character_visibility_component.ex` (`character_ship_toggle/1`, `character_portrait_toggle/1`), and the name fires `switch-character`. Settings → Account cards reuse the same toggles, add the character's ship name and location, and are selected by clicking anywhere on the card (character cards fire `switch-character`, mask cards fire `switch-mask`); both use a full-card overlay under a `pointer-events-none` content layer so the toggles and Remove buttons keep their own clicks. Switching happens in place, so Settings stays open: `switch-character` re-ensures the character's personal/corporation/alliance memberships, resets the view to the shared personal mask and its first map, reloads the topbar presence and pushes `character-switched`, which the `CharacterSwitch` hook (`assets/js/characterSwitch.js`, mounted on the topbar nav) turns into `GET /auth/session/:eve_id` to store the choice in the session cookie without a redirect. Cards keep the session `character_ids` order (the current character is appended only when missing), so switching characters never reorders them, and mark the current character or mask with a green portrait dot plus a green border/ring instead of a Current badge; the `CardGrid` hook (`assets/js/cardGrid.js`) makes the card itself the single tab stop (`data-card`, roving `tabindex`, overlay `tabindex="-1"`), moves focus with the arrow keys within each grid, and selects the focused card with Enter or Space by clicking its `[data-card-action]` element. `DashboardLive` refreshes a per-character presence map (`system_name`, `ship_name`, `ship_type_name`, `ship_type_id`, `online` from ESI location, ship, type and online endpoints) on the topbar tick, which also feeds the ship renders for characters other than the current one; a missing type render falls back to the type icon and then the cube icon.
- The topbar mask dropdown (`#topbar-mask` in `web/live_components/navigation_live.ex`) lists every non-demo mask in the database for signed-in characters (`Masks.list_masks/0`: personal → corporation → alliance, name breaks ties), not just the character's memberships, so any character can switch into any mask's chains; `switch-mask` still validates the id against the rendered list and creates a `Home` map for a mask that has none. Settings → Account shows the same full list as cards. The single personal mask is global: `Masks.ensure_personal_mask/1` ignores the character and returns the one row named `Private` with a nil `owner_character_id`, shared by every character, and `priv/repo/migrations/20261119000028_merge_personal_masks.exs` moves maps, comments, flares, permissions and memberships from old per-character personal masks into the survivor and deletes the rest. Demo mode is a separate standalone user and only ever sees the Demo mask, which `Masks.list_masks/0` filters out so it never appears in a signed-in dropdown or Account card; Settings → Admin keeps the membership-scoped list (`:admin_masks`) for mask administration. Corp and alliance masks use their EVE logos in both mask pickers through `web/components/mask_avatar_component.ex` (`mask_avatar/1`), while personal, demo and other kinds fall back to `/images/alliance-default.png`. A character is not auto-added as a member when switching to a foreign mask, so the Admin list stays membership-only.
- The topbar system search (`NavigationLive`) autocompletes from the map's chain systems first, then from `Tripwire.Systems.Catalog`, which loads `mapSolarSystems.jsonl` from the SDE zip in `priv/sde` into an ETS table at boot (empty and map-only when the file is missing; tests run with `path: nil`). Picking an on-map suggestion selects it through `select-system`; a catalog-only pick fires `system-search-pick` and only patches `/:system_name`, so `handle_params` falls back to the preferred system. Submitting a name resolves map systems first and then the catalog the same way.
- User preferences live in one `user_settings` row (`priv/repo/migrations/20261119000026_create_user_settings.exs`, `lib/tripwire/settings.ex`): map layout and view flags (row guides/counts, angled lines, jump lines, line glow, node badges, line weight, node spacing, scale, background), widget visibility, grid lock, chart range/series, and the chain flags `include_thera` and `show_all`. `Tripwire.Settings.get/0` lazily inserts row 1, `assigns/0` returns the LiveView assigns, and `DashboardLive` applies them after `assign_topbar_defaults/1` on both the demo and logged-in mounts, re-runs `apply_tree_layout/2` with the stored layout, and pushes `map-zoom` for a stored scale. Every control writes through `put_setting/3` (best-effort `Settings.update/1`, failures logged as `user_settings_update_failed`), so the settings are identical for every character and mask; the theme is still handled client-side in `localStorage`. `home_solar_system_id`/`home_name` stay on `maps` (a map's home is map data) and `ship_on_chain`/`character_on_chain` stay on `characters`.
- Widget layouts live in Settings → Layouts (`web/live_components/settings/settings_layouts_live.ex`, `lib/tripwire/layouts.ex`): four immutable core presets (`core:default`, `core:map-focus`, `core:signatures-focus`, `core:compact`) plus saved rows in the `layouts` table (`name`, `widgets` JSON map with `x`/`y`/`w`/`h`/`visible` for system, notes, signatures and map). `layouts` is global, and `user_settings.active_layout` stores the applied id (`core:*` or `saved:<id>`); mount resolves it and applies its positions and visibility before the first render, so a reload reopens the last applied layout. `settings-tab` includes `layouts`; apply/save/remove go through `apply-layout`, `save-layout` → `layout-capture` → `layout-captured` (gridstack snapshot from `assets/js/gridStack.js`, visibility merged server-side), and `delete-layout`, which rejects core ids and falls back to Default when the active saved layout is removed. Toggling a widget or a gridstack `change` event clears the active marker through `layout-changed`; `GridWidget`/`GridStack` push `layout-apply` positions for already mounted nodes, while newly rendered widgets read their server `gs-*` attributes. The settings panel is not part of a layout, and the map height stays viewport-fit (`gs-h` is rendered but there is no stored map height).
- The landing page (`web/pages/home.html.heex`) always shows the Demo button linking to `/Jita`; in demo mode it takes autofocus, otherwise the EVE SSO link does. The dev-only Metrics link to `/dev/dashboard` lives in Settings → Admin (`web/live_components/settings/settings_admin_live.ex`), rendered only when `dev_routes` is enabled, so non-admin dev users must type the URL.

## Map and signature sync

- Pasting a scan (`global-paste`) upserts signatures, flags missing ones in the stale toast, and runs `Mapping.sync_map_after_signature_change/2`.
- `sync_map_after_signature_change/2` drops connections whose `hole_type` matches a deleted wormhole signature, auto-links newly scanned holes to other map systems (same `sig_id` + hole code first, then a hole code present on exactly one other system; a connection dropped in the same sync is never re-created), and hides systems left with no connection or no longer reachable from the map's home system.
- Orphaned nodes are hidden with `map_systems.hidden_at`, not deleted; the home system itself is never hidden and `Mapping.upsert_connection/4` unhides endpoints, so any re-created connection brings nodes back. Map views render `Mapping.list_chain_systems/2`, whose `show_all` argument comes from the user settings row (not the map) and is labelled **Known space** in Edit Map: `false` renders only the home chain — unhidden systems reachable from the map's `home_solar_system_id` via `reachable_system_ids/2`, so the view has exactly one root, the home system set in Edit Map (a map with no home falls back to every unhidden system) — and `true` renders every system, including detached chains, single-node chains and systems missing from the database that a tracked character is in, where extra level-0 roots are expected. `MapLive` draws only connections whose two endpoints are rendered, so hidden and filtered components leave no floating edges.
- `Mapping.tree_layout/5` roots every component that does not reach the home system at level 0 beside the home tree (including isolated nodes), so re-laying out after a paste or a chain edit keeps detached chains on the home row instead of stacking them under the chain. Without a `root_id` it picks one root per connected component (lowest id among the component's systems with no incoming connection, else the lowest id), so a chain scanned from both ends never splits into two level-0 rows; `depth_layers/2` uses the same roots for the radial layout.
- Paste sync and stale deletes reload the map through `DashboardLive.reload_map_from_sync/4`: only drops and hides re-run the tree layout (rebalancing the remaining nodes); a paste that merely links systems keeps every node position and just refreshes the loop hint.
- `Mapping.delete_signature/2` removes a wormhole signature together with the paired signature on the connected system (same hole code, like official Tripwire's wormhole removal), so deleting missing signatures clears both ends of the hole.
- Maps are renamed and deleted from the Edit Map modal (`#map-modal` in `web/live/dashboard_live.html.heex`, opened by `#map-edit` in `web/live_components/map_live.ex`); `save-map-settings` writes `map[name]` through `Mapping.update_map/2` (a blank name comes back as a changeset error in `@map_errors`) and refreshes the tab labels from `Mapping.list_maps_for_mask/1`. The `#delete-map` button fires `delete-map`, which only matches ids from `Mapping.list_maps_for_mask/1` for the current mask, refuses a locked map, and runs `Mapping.delete_map_full/1` (connection jumps, signatures, comments, flares, stats, connections and systems, then the map; `map_permissions` goes with the FK cascade). Deleting the open map moves the view to the next one, and deleting the last one recreates the default — the reseeded demo chain in demo mode (`Mapping.ensure_demo_map/1`), otherwise a `Home` map holding the Jita node (`personal_map/1` plus `ensure_jita_system/2`). `DashboardLive.assign_active_map/2` re-subscribes the map topic and resets the selection for `new-map`, `switch-map` and `delete-map`; when the deleted map was the first one of the personal mask, tracked pollers are restarted so they re-resolve their map instead of writing into the deleted row.
- `Mapping.ensure_demo_map/1` points the demo map's home at the system aliased `Home` (J150321), so the demo chain prunes detached branches and supports Known space like a configured map.
- A scanned wormhole signature with no connection gets an unknown placeholder node (`map_systems.unknown`, no class/name/signature of its own) linked to the scanned system, so the chain shows an empty end node until the hole is mapped. Placeholders render as empty Tripwire-style nodes, stay out of the system list and search, are deleted when their connection drops (`Mapping.delete_unlinked_unknowns/1`), and are converted in place by a tracked jump (`Mapping.convert_unknown_system/2`) or replaced by the real target when a later scan links the hole (`auto_link_wormholes/2` re-points the placeholder connection).
- The chain map hides the connection that closes a loop (`Mapping.cycle_connection_ids/2`, which unions connections in creation order so the newest link in a cycle is left out); only that link's endpoints — the scanned system and its candidate peer — keep the dashed outline and glow, so the existing chain stays exactly as drawn.
- `Tracking.apply_location_change/5` labels a jump-created connection with the scanned hole code when exactly one wormhole signature in the origin system is eligible to lead into the destination class (`Tracking.wormholes_for_jump/3`, mirroring official Tripwire's automapper); existing hole types are never relabeled and ambiguous matches stay blank.
- `Mapping.prune_expired_signatures/1` drops connections backed by expired wormhole signatures, hides orphans, and broadcasts `{:map_updated, map_id}` on the map's PubSub topic so open dashboards refresh.
- `Tripwire.Systems.display_class/1` prefers a stored `sys_class`, then the per-system dataset, then `W` for unmapped W-space ids (`31_000_000..34_999_999`, covering Thera, shattered and the new Redoubt/Vanguard ranges) instead of deriving `NS` from the `-1.0` security ESI reports for wormholes; `security_label/1` returns "W-Space" for those ids. `Wormholes.eligible_types/2` sees `W` as no match, so an unclassified hole is not auto-labeled until the mapper sets the class.
- `priv/data/wormhole_systems.json` is generated by `mix tripwire.build_wormhole_systems` from the SDE zip (`mapConstellations.jsonl` class ids `1..6 → C1..C6`, `12 → Thera`, `13 → C13`, `25 → Trig`, `19..23 → Drifter`; `mapSecondarySuns.jsonl` + `types.jsonl` group 995 for the effect; system name for the guard) plus `priv/data/wormhole_statics.json` (upstream Tripwire statics, MIT). It is committed so runtime works offline; regenerate it after `task setup` refreshes the SDE. `Mapping.add_system_to_map/2` and `convert_unknown_system/2` fill `sys_class`, `effect` and `statics` for known solar ids when the name matches (`fill?: false` for the demo seed), and `mix tripwire.backfill_system_data` fills blanks on existing rows (the `add_statics_to_map_systems` migration backfills once; `task migrate`/`task start` re-run the task, `--force` overwrites). `Systems.display_effect/1` and `system_statics/1` use the stored fields; the class-level static table is only a fallback for synthetic systems.
- `Mapping.update_comment/3` rewrites a note body and bumps the `comments_updated` stat counter; the notes widget (`web/live_components/notes_live.ex`) uses it for the inline editor that the per-note edit button opens, keeping the note on its system and cancelling back to the rendered markdown.
- The signatures widget sorts on column-header click (status, ID, type, name, mass, age, life; a second click flips the direction and selecting another system clears the sort) and reorders columns by dragging a header (`assets/js/columnReorder.js`, data columns only, actions stay last, session-only order; the default order is status, ID, age, type, name, life, mass, and `@columns` order also defines the fallback order for keys missing from a reorder). Header and body cells share the ordered column list, and data rows highlight on hover. Those events re-render only the widget subtree, so `GridWidget.updated/0` refreshes the grid afterwards and re-asserts the item's size, drag/resize classes and handles (morphdom drops what gridstack wrote onto the item root).
- The map widget fills the window minus one row: `assets/js/gridStack.js` sizes `#map` to `round(innerHeight / cellHeight) - 1` rows on init and refits on window resize, so the `gs-h` rendered from a layout is only the pre-JS fallback. `itemSignature/1` reads live engine values where a node is registered so LiveView patches keep the light-touch refresh path instead of re-laying out the grid, and `#grid-stack.grid-stack-loading` reserves `100vh` before the grid initializes. Layout save/apply reuse the same engine through `TripwireGridStack.snapshot/0` and `apply/1`, bound to the `GridStack` hook's `layout-capture`, `layout-apply` and `layout-changed` events.
- The chain map's default view is the `1000x700` world at `Mapping.default_zoom/0` (0.8), drawn as a `1250x875` viewBox in `MapLive` and labelled `100%` (`assets/js/mapDrag.js` divides the live zoom by `DEFAULT_ZOOM` for the label). `Mapping.node_size/0` is the single source for the node box (`140x88`): `MapLive` draws the rect, text anchors, corner occupant/activity dots and edge endpoints from it, and `home_center/2` centers on half of it. `Mapping.home_center/2` centers the map's home system horizontally in that view (the top clamp still wins vertically) and seeds `pan_x`/`pan_y` plus every `reset-pan` push, so page load, Reset Zoom, layout and spacing changes, chain-settings saves, paste relayouts and add-favorites all reopen centered on home; switching map tabs keeps the current view.
- `MapLive` marks each system with tracked characters (from `Tracking.list_occupants/1`) using a `28x28` portrait badge on the node's top-right corner and an `r=8` count bubble when more than one character is there; with several occupants the badge switches to the unknown character portrait (`EveImages.unknown_character_portrait/1`, EVE character `1`) and the count bubble carries the total. Hovering the badge reveals an HTML tooltip inside a `<foreignObject>` (CSS `group`/`group-hover` only, no roundtrip, `pointer-events-none`), one row per occupant with the ship render (`EveImages.type_render/2`, type-icon then cube fallback), the character portrait and `Name - Ship`; the ship name is omitted when `ship_on_chain` is off. Its width is fixed in map units and it opens below the node; it only flips above the badge when the tooltip would pass the bottom row *and* the node has room above, so a lone root node (no room above, nothing below) still opens downward. `list_occupants/1` therefore carries `ship_type_id`, which `Tracking.Poller` and `Tracking.DemoPresence` read from the same `/characters/{id}/ship/` response as `ship_name`. Occupants are matched to the open map by the poller's last `solar_system_id` (not by the poller's own map id), so any character in a system the open chain contains is shown, and characters with `character_on_chain: false` are dropped. `DashboardLive.refresh_occupants/1` then scopes the list to the mask: a corporation mask keeps only characters whose `corporation_id` is the mask's `eve_owner_id`, an alliance mask the matching `alliance_id`, and personal/demo/custom masks keep every occupant. Every session character with a refresh token gets a poller on mount (`ensure_character_pollers/1`), so all of your characters report presence instead of just the one you logged in with; the tracker toggle in the signatures widget still turns a single character's poller off.

## Testing

- `mix test` covers contexts (`test/tripwire/`), LiveViews (`test/web/live/`), and controllers (`test/web/controllers/`). Tests run inside the SQL sandbox against `priv/db/tripwire-test.db`.
- Context tests build their own maps (`Masks.ensure_demo_mask/0` + `Mapping.ensure_demo_map/1` seeds the 27-system demo chain with signatures and notes, including two scanned-but-unmapped leaf holes that end in empty unknown nodes; the demo paste lives in a comment on the Home system).
- Dashboard LiveView tests drive the widgets (signature paste, stale toast, chain map rendering, settings tabs) through `TripwireWeb.LiveComponents` events; select systems via `#system-container button[title='Select system …']`.
- The upstream reference (daimian/tripwire, PHP) ships no test suite. Its maintained fork's suites (mocha `app/js-test`, Playwright `e2e/`, `tests/php/note-html.test.php`) are the comparison baseline; behaviors already ported: signature paste parsing, wormhole eligibility and rendering, automapper jump labeling, mask kinds, note sanitization (as markdown escaping), and stat counters. Known upstream gaps not present in this port: faction-warfare conditional gates, mass dialog parsing, Drifter/C13–C18 generic system types, EVE-Scout Thera link supplier, and client-side pathfinding (routes come from ESI here).

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
| `task setup` | `mkdir -p priv/sde logs/test logs/errors`, `curl` official JSONL SDE to `priv/sde/eve-online-static-data-latest-jsonl.zip` with ETag conditional fetch, `mix tripwire.build_wormhole_systems`, `mix deps.get`, `mix ecto.setup`, `mix assets.setup`, `mix assets.build` |
| `task migrate` | `mix ecto.migrate` + `mix tripwire.backfill_system_data`, `MIX_ENV=test mix ecto.migrate`, `MIX_ENV=prod` variants |
| `task start` | `task stop`, prod migrations plus `mix tripwire.backfill_system_data`, then launch detached with `DATABASE_PATH` defaulting to `./priv/db/tripwire-prod.db`; block until `logs/prod.log` reports a running endpoint, then print the URL (fails with the log tail if the server dies while booting) |
| `task stop` | stop the managed production process group recorded in `tmp/tripwire-prod.pid`, then wait for the process and port to be released |
| `task dev` | `task stop`, `mkdir -p logs/test logs/errors priv/sde`, `mix ecto.migrate`, `mix tripwire.reset_demo`, then `MIX_ENV=dev mix phx.server` attached on port `PORT` (default `4000`) with live reload and the `config/dev.exs` watchers; Ctrl-C stops it |

Server lifecycle blocks run under `sh -c` because Task's built-in shell does not implement `$!` or `kill`.

Dev starts the Erlang `:os_mon` application (`mix.exs` `extra_applications` for `MIX_ENV=dev` only), so the LiveDashboard mounted at `/dev/dashboard` serves the OS Data page at `/dev/dashboard/os_mon`. The same dashboard's Ecto Stats page is backed by the dev-only `ecto_sqlite3_extras` dependency and an explicit `ecto_repos: [Tripwire.Repo]` route option, and reports total/table/index size, sequence numbers, PRAGMA and compile options, and integrity checks for `priv/db/tripwire-dev.db`.

## Conventions

- No `#` comments in Elixir, Taskfile, or other source files; `#{...}` interpolation inside strings is not a comment. Document in `README.md` or this file instead.
- Tests run with `mix test`; single file with `mix test <path>`. Log tests must not write to real `./logs/`.
- Commits use `tag: statement of change` with one of `add`, `update`, `remove`, `move`, `feature`, `fix`, no body, on the current branch, without pushing.
