# Static data

## `wormholes.json`

Wormhole type database: mass, life, jump limits and destination classes per hole code, used by `Tripwire.Wormholes`.

## `wormhole_statics.json`

Static wormholes for 2605 Anoikis systems, keyed by system name (`J231710` → `["H900","C247"]`).

Source: `tools/statics.json` from the upstream Tripwire repository
(<https://github.com/astriania/tripwire>, MIT licence, earlier home
<https://bitbucket.org/daimian/tripwire>). Statics are player-collected data; the
SDE has no official source for them.

## `wormhole_systems.json`

Generated per-system class, system-wide effect and static wormholes, keyed by
solar system id:

```json
{"31001663":{"class":"C4","effect":"Magnetar","name":"J231710","statics":["C247","H900"]}}
```

Rebuild it with `mix tripwire.build_wormhole_systems` after downloading the SDE
(`task setup` keeps `priv/sde/eve-online-static-data-latest-jsonl.zip` current).

- Class: `wormholeClassID` from the SDE `mapConstellations.jsonl`
  (`1..6` → `C1..C6`, `12` → `Thera`, `13` → `C13`, `25` → `Trig`,
  `19..23` → `Drifter`).
- Effect: `mapSecondarySuns.jsonl` → `types.jsonl` (`groupID` 995).
- Statics: `priv/data/wormhole_statics.json`.
- Name: the SDE system name, used to refuse the data for synthetic systems that
  reuse a real solar id (the demo seed).

EVE's static data export has no statics and does not expose the class for the
new Redoubt/Vanguard regions except through those class ids, so entries can have
a class with no effect or statics.
