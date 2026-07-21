# Heroes & Villains — Ability Core

Server-authoritative ability system for the Roblox game, upgraded from the
original `AbilityEngine.lua` / `AbilityManager_2.lua`.

## Where each script goes in Roblox Studio

| File                                                    | Studio location                                           | Script type                     |
| ------------------------------------------------------- | --------------------------------------------------------- | ------------------------------- |
| `ServerScriptService/Systems/AbilityEngine.lua`         | `ServerScriptService > Systems > AbilityEngine`           | ModuleScript (replace contents) |
| `ServerScriptService/Systems/AbilityManager.server.lua` | `ServerScriptService > Systems > AbilityManager`          | Script (replace contents)       |
| `StarterPlayerScripts/AbilityVFXClient.client.lua`      | `StarterPlayer > StarterPlayerScripts > AbilityVFXClient` | LocalScript (new)               |
| `ReplicatedStorage/Characters/CharacterKits.lua`        | `ReplicatedStorage > Characters > CharacterKits`          | ModuleScript (new)              |

## External requirements (already in the game)

- `ReplicatedStorage.UseAbility` — RemoteEvent fired by the existing InputClient
  (`"Q"/"E"/"R"/"F"` slot presses, `"BEAM_AIM"` while holding, `"BEAM_STOP"` on release).
- `ReplicatedStorage.Masteries.MasteryData`, `ReplicatedStorage.Characters.CharacterData` —
  ability definition data.
- `ServerScriptService.Systems.DataManager`, `AbilityRegistry`, and
  `CharacterKits` are optional; all are loaded defensively.
- `ReplicatedStorage.AbilityFX` — RemoteEvent, **auto-created by AbilityEngine**; no setup.

Ability types supported by the engine: `melee`, `aoe`, `dash`, `projectile`,
`buff`, `beam`, `teleport`, `vortex`, `barrage`, `shield`, `wall`, `zone`,
`strike`, `chain`, `bind`, `force`, `tendrils`, `breath`, `slam`, `clones`,
`turret`, `counter`, `phase`, `storm`, `stormcontrol`, `disaster`, plus
`construct` (handled by the manager).

### Weather & natural disasters

`storm`, `stormcontrol` and `disaster` are restricted to characters the design
doc says can manipulate storms or natural disasters. A live storm is registered
in a shared weather system, so `stormcontrol` can **seize the nearest existing
storm — including an enemy's — and redirect + amplify it**, or brew a fresh one
if none is nearby ("create storms and manipulate them whenever there is one").
`disaster` covers `tsunami` (rolling water wall), `tornado` (drifting funnel
that pulls/lifts), `earthquake` (radial stun + rising rock) and `volcano`
(crater damage, lava pool, lava bombs). Characters wired for it:

| Character              | Storm creation    | Storm control                           | Natural disaster    |
| ---------------------- | ----------------- | --------------------------------------- | ------------------- |
| Liberty                | ✓ (Command Storm) | ✓ seize/steer any storm                 | Tornado             |
| Megalodon              | ✓ Hurricane       | — (his hurricane is seizable by others) | Tsunami             |
| Infinity               | ✓ (Command Storm) | ✓ seize/steer any storm                 | Earthquake, Tsunami |
| Heat Wave / Fahrenheit | —                 | —                                       | Volcano             |
| Prometheus             | —                 | —                                       | Tsunami             |

Universal fields on any damaging def: `stunDuration`, `dotDamage`/`dotDuration`
(burn/poison), `lifesteal`, `percentDamage` (fraction of the target's current
health — Nejhora's 90% drain, Apocalypso's death touch), `color`/`style`
palettes. Per-type fields are documented next to each handler in
`AbilityEngine.lua`.

`CharacterKits.lua` holds full Q/E/R/F movesets for **169 characters** from the
design doc (checked before `CharacterData`; kit keys must match each player's
`CharacterName` attribute exactly). Pure lore/non-combatant entries (armies,
factions, celestial concepts) are intentionally omitted. Every kit and every
ability type is validated by the harness in `scratchpad/harness.lua`.

---

# Metro City — campaign map

A procedural generator that builds Metro City (Manderin's capital) from the
concept art — all 11 districts — out of parts, with no uploaded models or
textures. Branding ("M", "MANDERIN", "MANDERIN TECH") is drawn with SurfaceGui
text. It executes to ~1,067 parts / ~1,200 instances (validated end-to-end).

## Where each file goes

| File                                               | Studio location                                    | Script type        |
| -------------------------------------------------- | -------------------------------------------------- | ------------------ |
| `ServerStorage/MetroCityBuilder.lua`               | `ServerStorage > MetroCityBuilder`                 | ModuleScript (new) |
| `ServerScriptService/BuildMetroCity.server.lua`    | `ServerScriptService > BuildMetroCity`             | Script (new)       |
| `ReplicatedStorage/Campaign/MetroCityCampaign.lua` | `ReplicatedStorage > Campaign > MetroCityCampaign` | ModuleScript (new) |

## Building the map

**Bake once (recommended).** In Studio, open the Command Bar and run:

```lua
require(game.ServerStorage.MetroCityBuilder).build(workspace)
```

`workspace.MetroCity` appears as real, editable geometry. Save the place — it
never rebuilds. Then set `BUILD_AT_RUNTIME = false` in `BuildMetroCity` (or
delete that Script). Leaving it `true` is safe: it only builds when `MetroCity`
is missing. Turn on `Workspace.StreamingEnabled` for a map this size.

## The 11 districts

Central Plaza (Manderin monument) · Manderin Tower (tallest — campaign boss) ·
Tech District (purple/cyan neon) · Industrial District (smokestacks + tanks) ·
Residential Area · Docks (water, cranes, ship, containers) · Security
Checkpoints (scanner gates) · Sky Bridges · Undercity (hidden purple level under
the plaza, reached by a stair shaft) · Manderin Arena (domed) · City Walls
(perimeter, corner towers, main gate). Each is a named Model under
`workspace.MetroCity.Districts` with a `District` attribute.

## Campaign integration

`build()` also creates `workspace.MetroCity.Campaign` with:

- `Spawns/CampaignStart` — the stage-1 SpawnLocation, plus one disabled
  `Checkpoint_<n>` per stage (enable as the player advances).
- `Objectives/Stage<n>_<District>` — a glowing beacon per mission stage, tagged
  with `Stage`, `District`, and `Objective` attributes.

`MetroCityCampaign` (ReplicatedStorage) is the data contract: the ordered
9-stage route (Residential → Central Plaza → Security → Tech → Industrial →
Docks → Undercity → Arena → **Manderin Tower** boss), district descriptions
from the concept, and helpers `enableCheckpoint(workspace, stageId)` and
`getBeacon(workspace, stageId)`. Your campaign controller reads the stages and
drives objectives off the beacons — no positions hard-coded twice.

## Campaign gameplay (controller + enemies + boss)

Beyond the map, four files run the campaign as shared co-op progression:

| File                                                | Studio location                                      | Type               |
| --------------------------------------------------- | ---------------------------------------------------- | ------------------ |
| `ServerStorage/EnemyFactory.lua`                    | `ServerStorage > EnemyFactory`                       | ModuleScript (new) |
| `ServerScriptService/CampaignController.server.lua` | `ServerScriptService > CampaignController`           | Script (new)       |
| `StarterPlayerScripts/CampaignHud.client.lua`       | `StarterPlayer > StarterPlayerScripts > CampaignHud` | LocalScript (new)  |
| `ReplicatedStorage/Campaign/MetroCityCampaign.lua`  | (updated — adds per-stage enemy counts)              | ModuleScript       |

**Flow:** each stage spawns Manderin Security guards at that district's beacon →
players defeat them with their normal abilities → the marker turns green →
a player reaches it → the checkpoint advances → next stage. The finale spawns
**Manderin** at the tower, and the stage ends when he falls.

**Enemies use your existing systems, not new ones.** Guards and the boss are
part-built R6 rigs with real Humanoids, so `AbilityEngine` already damages and
knocks them around — nothing extra to wire. The boss _casts through the same
engine_: `AbilityEngine.run(nil, bossChar, def, targetPos)` drives an Aegis
Slam, Tentacle Lash, Laser Barrage, Force Repulse and Power Nova with full VFX.

**HUD** shows stage x/9, the district, the objective, and live status (enemies
remaining / "reach the marker" / boss / victory), driven by the auto-created
`ReplicatedStorage.CampaignEvent`. Everything loads defensively — a missing
piece warns and no-ops instead of erroring. Tune enemy counts in
`MetroCityCampaign.Stages` and enemy/boss stats in the `EnemyFactory` calls.

## Multi-season framework (built for more maps)

The campaign is a 30-season saga, so the controller is map-agnostic. Two more
files make adding a map a data change, not a rewrite:

| File                                               | Studio location                                            | Type               |
| -------------------------------------------------- | ---------------------------------------------------------- | ------------------ |
| `ReplicatedStorage/Campaign/CampaignRegistry.lua`  | `ReplicatedStorage > Campaign > CampaignRegistry`          | ModuleScript (new) |
| `ReplicatedStorage/Campaign/MetroCityCampaign.lua` | (updated — adds `CityModelName` / `MapBuilder` / `Season`) | ModuleScript       |

`CampaignRegistry` indexes every season (id, title, boss, summary) and points
the built ones at their map builder + route module. `ActiveSeason` selects which
one runs — **Metro City is Season 8** (Manderin's dictatorship). The controller
reads the active season, builds its map if absent, and runs its route.

**Bosses fight with their real kit.** For each boss the controller derives its
attacks from `CharacterKits[bossName]` (skipping player-only `beam`/`construct`,
capping damage, stripping `percentDamage`), so Minus fights as Minus, Null as
Null, Omega as Omega — every villain already has a kit in the roster.

**To add a season's map:** write a builder in `ServerStorage` (like
`MetroCityBuilder`) and a route module in `ReplicatedStorage.Campaign` matching
the `MetroCityCampaign` contract (`Stages`, `getBeacon`, `enableCheckpoint`,
`EnemyName`, `BossName`, `CityModelName`, `MapBuilder`), then point that season's
registry entry at them and set `ActiveSeason`. Nothing in the controller,
enemies, HUD, or boss logic changes.

## World Atlas (map-making reference)

`WorldAtlas.lua` (`ReplicatedStorage > Campaign > WorldAtlas`, ModuleScript)
catalogs the whole Aroraverse from the omniverse doc as **map-making data** —
pure data, no Roblox globals, cheap to require:

- **100 planets** tagged by tier (core/mid/exotic/ultra/god) and **biome**.
- **26 biomes**, each mapped to a palette hint — `{ material, ground rgb,
accent rgb, sky mood }` — so any location becomes a themeable map from data
  instead of guesswork (`WorldAtlas.biome("volcanic")` → Basalt ground, orange
  accent, ashen sky).
- **Story locations** the seasons visit (Metro City, Quantum City, Gildonia,
  Valhalla, Planet Sparta, the Gold/Silver Fountains) with `builder`/`route`/
  `mapReady` fields — Metro City is the one built so far.
- The 8-level **hierarchy** (Planet → … → Aroraverse), **12 themed universes**,
  the **5 enemy universes**, Manderin's Imperium worlds, and contested war zones.
- `SeasonLocations` links a season id to its canonical place.

Helpers: `get(name)`, `byBiome(tag)`, `byTier(tier)`, `biome(tag)`,
`locationForSeason(id)`, `buildableList()`. This is the bridge for the next
maps: pick a location, read its biome palette, generate.

---

# Quantum City — Season 10 map (proof of the multi-map framework)

The second map, and the proof the framework scales: a digital city floating in
Blue's loops in space, whose look is **pulled from the WorldAtlas `digital`
biome** (teal/cyan neon, dark platforms). It plugs into the same controller,
enemies, HUD, and boss system with zero changes to them.

| File                                                 | Studio location                                      | Type               |
| ---------------------------------------------------- | ---------------------------------------------------- | ------------------ |
| `ServerStorage/QuantumCityBuilder.lua`               | `ServerStorage > QuantumCityBuilder`                 | ModuleScript (new) |
| `ReplicatedStorage/Campaign/QuantumCityCampaign.lua` | `ReplicatedStorage > Campaign > QuantumCityCampaign` | ModuleScript (new) |

Floating archipelago over the void: a central **Nexus Core** (Blue's loop) with
radial sector platforms — Docking Ring, Data Market, The Grid, Server Spire,
Firewall Checkpoint, Loop Gardens, the lower **Undernet**, and the **Anonymous
Sanctum** — linked by light bridges. ~813 parts. Boss: **The Anonymous**, who
fights with his real CharacterKits moveset.

**To play it:** set `CampaignRegistry.ActiveSeason = 10`. The controller builds
`workspace.QuantumCity` and runs the 9-stage route automatically (or bake it:
`require(game.ServerStorage.QuantumCityBuilder).build(workspace)`). Optionally
disable `BuildMetroCity` so only the active season's map builds.

Both built maps now: **Season 8 Metro City** (city biome) and **Season 10
Quantum City** (digital biome). Adding the next one — Gildonia (jungle),
Valhalla (stone), any of the 100 atlas planets — is a builder + route + a
registry flip.
