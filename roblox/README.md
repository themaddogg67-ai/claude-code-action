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

---

# Character models & themed bosses

`CharacterModelFactory` (`ServerStorage`, ModuleScript) builds themed R6 rigs out
of parts from an appearance SPEC — the looks read off the roster art. Specs live
in `CharacterModels` (`ReplicatedStorage > Characters > CharacterModels`,
ModuleScript, pure data). **39 characters** modeled so far.

| File                                               | Studio location                                    | Type               |
| -------------------------------------------------- | -------------------------------------------------- | ------------------ |
| `ServerStorage/CharacterModelFactory.lua`          | `ServerStorage > CharacterModelFactory`            | ModuleScript (new) |
| `ReplicatedStorage/Characters/CharacterModels.lua` | `ReplicatedStorage > Characters > CharacterModels` | ModuleScript (new) |
| `ServerScriptService/BuildModelGallery.server.lua` | `ServerScriptService > BuildModelGallery`          | Script (new)       |

**Appearance features** (all data-driven, no assets): spiky anime hair, glowing
eyes (dual / single / visor), shadowed hoods with glowing eyes, Channel's TV
head, chest emblems (Manderin `M`, Looney `E`, Red Rocket `RR`, Omega `Ω`, Mr
Universe `∞`, Dead Dash `⚡`), Red Eye's chest eye, capes, back-tentacles
(Manderin / The Engineer / Void Overlord), and elemental auras (fire, electric,
void, cosmic, holy, gold, ice, green, energy).

**Themed bosses.** Every rig is a valid Humanoid, so the campaign boss now wears
its real look: the controller builds the boss's model via the factory and hands
it to `EnemyFactory.spawnBoss` as `opts.rig` (falling back to the default rig if
a boss has no spec). Manderin fights as Manderin, the Void Overlord as the Void
Overlord — with the CharacterKits moveset already wired in. Bosses with models:
Manderin, The Anonymous, Void Overlord, Nemesis, Minus, Null, Omega, Armageddon,
Dragon, Rynox, Sugoro, Channel.

**View them all.** Run in the Studio Command Bar:

```lua
require(game.ServerStorage.CharacterModelFactory).gallery(workspace, CFrame.new(0, 5, 300))
```

Every modeled character appears as a labeled display statue.

## Starting-character select (spawn as your character)

Players pick a starting character for the campaign and **spawn as them** — the
avatar is skinned with the character's themed look and their `CharacterName`
attribute is set so the ability system uses that character's CharacterKit.

| File                                                 | Studio location                                             | Type              |
| ---------------------------------------------------- | ----------------------------------------------------------- | ----------------- |
| `ServerScriptService/CharacterSelect.server.lua`     | `ServerScriptService > CharacterSelect`                     | Script (new)      |
| `StarterPlayerScripts/CharacterSelectGui.client.lua` | `StarterPlayer > StarterPlayerScripts > CharacterSelectGui` | LocalScript (new) |

Starting roster: **Looney, Leon, Chasm, Frost, Water Woman**. On join a picker
appears; clicking a card spawns you as that hero. The pick sticks across
respawns. It works by _skinning the real character_ (`CharacterModelFactory.applyTo`,
R6 **and** R15) — recolor + welded accessories — so movement, camera and
animation are never disrupted, and re-picking strips the previous look instead
of stacking it. To change the roster, edit `STARTERS` in `CharacterSelect`.

Model additions this pass: **Leon** and **Chasm** (starting heroes), **Old Man
Omega** (normal Omega greyed with a beard — new `beard` feature), and **Carnage**
(modeled from his _description_ — metallic blood-red "god of fear" with horns via
the new `horns` feature — not an image). 43 characters modeled total.

## Enemy pathfinding

`Pathfinder` (`ServerStorage`, ModuleScript) wraps `PathfindingService` so
campaign NPCs route around walls and rubble instead of beelining. `EnemyFactory`
loads it defensively — guards and the boss each get a `Pathfinder` that follows
the target along computed waypoints (recomputing only when the target drifts or
the path goes stale), and falls back to direct `MoveTo` when no route exists
(e.g. across gaps on the floating Quantum City platforms). Put `Pathfinder` in
`ServerStorage` next to `EnemyFactory`.

## Ruined City — Season 7 map ("Omega's Chaos")

Fourth built map: a devastated Earth city where **Omega** rampages, from the
WorldAtlas `ruin` biome (ash concrete, ember accents, red doomsday glow).
Toppled skyscrapers, wrecked cars, craters, fire and smoke across 6 sectors
(Evacuation Zone → Broken Streets → Collapsed Plaza → Burning District → The
Barricade → Ground Zero), ending against Omega with his themed model + phase-two.

| File                                                | Studio location                                     | Type               |
| --------------------------------------------------- | --------------------------------------------------- | ------------------ |
| `ServerStorage/Pathfinder.lua`                      | `ServerStorage > Pathfinder`                        | ModuleScript (new) |
| `ServerStorage/RuinedCityBuilder.lua`               | `ServerStorage > RuinedCityBuilder`                 | ModuleScript (new) |
| `ReplicatedStorage/Campaign/RuinedCityCampaign.lua` | `ReplicatedStorage > Campaign > RuinedCityCampaign` | ModuleScript (new) |

**Built maps: Season 5 Gildonia, Season 7 Ruined City, Season 8 Metro City,
Season 10 Quantum City.** Set `CampaignRegistry.ActiveSeason` to pick one.

## Ranged enemies, boss health bar, and the Swamplands (Season 1)

- **Ranged attackers** — `EnemyFactory.spawnRanged` builds a marksman that keeps
  its distance (kites when you close in) and fires AbilityEngine projectiles at
  you. The controller now makes **every 3rd stage enemy ranged**, so stages mix
  melee and ranged pressure.
- **Boss health bar** — the controller streams the active boss's HP to the HUD;
  `CampaignHud` shows a bottom-center boss bar (name + fraction) that turns
  orange and reads **ENRAGED** when phase-two triggers. It hides on non-boss
  stages and on victory.
- **The Swamplands — Season 1 ("Rise of Minus")** — a bayou where the campaign
  begins, from the WorldAtlas `swamp` biome: murky water, mangroves with prop
  roots, stilt villages, a poison marsh, Minus's war camp, and the **Gator's Den**
  boss lair. 6 sectors, ends against **Minus** (themed model + phase-two).

| File                                                | Studio location                                     | Type               |
| --------------------------------------------------- | --------------------------------------------------- | ------------------ |
| `ServerStorage/SwamplandsBuilder.lua`               | `ServerStorage > SwamplandsBuilder`                 | ModuleScript (new) |
| `ReplicatedStorage/Campaign/SwamplandsCampaign.lua` | `ReplicatedStorage > Campaign > SwamplandsCampaign` | ModuleScript (new) |

**Built maps (5, one per biome):** Season 1 Swamplands (swamp), Season 5
Gildonia (jungle), Season 7 Ruined City (ruin), Season 8 Metro City (city),
Season 10 Quantum City (digital). Set `CampaignRegistry.ActiveSeason` to pick.

## Campaign menu — season select with unlocks + character select

A front-end flow: **main menu → CAMPAIGN → season select → character select →
play**. Only Season 1 is playable for a new player; completing a season unlocks
the next. Progress persists per player (DataStore, with an in-memory fallback if
DataStores are off).

| File                                           | Studio location                                       | Type              |
| ---------------------------------------------- | ----------------------------------------------------- | ----------------- |
| `ServerScriptService/CampaignMenu.server.lua`  | `ServerScriptService > CampaignMenu`                  | Script (new)      |
| `StarterPlayerScripts/CampaignMenu.client.lua` | `StarterPlayer > StarterPlayerScripts > CampaignMenu` | LocalScript (new) |

The playable ladder is the **built seasons in order**, shown as Season 1–5 (Rise
of Minus → The Void Overlord → Omega's Chaos → Metro City → Blue's Loops).
Picking a season then a hero starts that season as the chosen character.

**How it's wired:** the controller is now **menu-driven** — it no longer
auto-starts. `CampaignMenu` validates the pick against saved progress and fires
the `StartCampaignSeason` BindableEvent (ServerStorage); the controller loads
that season's map + route and runs it. On victory the controller fires
`SeasonCompleted`, and the menu unlocks + saves the next season. (Both
BindableEvents auto-create.) The old standalone `CharacterSelectGui` is now a
no-op stub — the menu handles character picking; you can delete it. The
`CharacterSelect` server morph logic is unchanged.

## Mini-bosses

Any stage can name a `miniBoss` — a tougher, themed named enemy that spawns
alongside the stage's guards and counts toward the clear (it does NOT end the
season; only the final boss stage does). Mini-bosses use their CharacterKits
moveset + themed model and get phase-two enrage but summon no adds. The HUD
flashes a gold "MINI-BOSS — <name>" banner. **Season 1's mini-boss is El Primo
Libre** (gold-masked wrestler drug-lord) at the Sunken Village. Add one to any
stage: `miniBoss = "<CharacterKits name>", miniBossHealth = 1100`.

## Hero / Villain faction choice

The campaign menu now adds a **Pick Your Side** step (Season → Faction →
Character), for both solo and multiplayer campaign:

- **Heroes:** Looney, Leon, Chasm, Frost, Water Woman — at full strength.
- **Villains:** Bulldozer, Reddon, Erik, Toxic — **starting at their weakest**
  (a persistent `ArmorDamageMult = 0.6`, i.e. 40% weaker attacks, applied by
  `CharacterSelect`; raise it as they progress).

Picking sets `CharacterName` (kit), `Faction`, and the weakness attribute, then
skins the avatar to the chosen character. Both faction rosters have kits and
themed models. Edit `HERO_STARTERS` / `VILLAIN_STARTERS` / `VILLAIN_WEAK` in
`CharacterSelect` to change the lineups or the villain penalty.

## Villain-perspective campaign + XP / leveling

**Every fight flips by faction.** The campaign now runs from the chosen side's
perspective. Heroes fight the villain forces (e.g. Metro City: Manderin
Security, boss Manderin). Villains fight the _opposite_ — the heroes/law trying
to stop them — with a hero as their final boss and inverted objectives:

| Season         | Hero enemy → boss            | Villain enemy → boss            |
| -------------- | ---------------------------- | ------------------------------- |
| 1 Swamplands   | Swamp Raider → Minus         | Bayou Ranger → **Titan**        |
| 2 Gildonia     | Void Soldier → Void Overlord | World Warrior → **Red Rocket**  |
| 3 Ruined City  | Rioter → Omega               | Peacekeeper → **Patriot**       |
| 4 Metro City   | Manderin Security → Manderin | Resistance Fighter → **Looney** |
| 5 Quantum City | Quantum Sentinel → Anonymous | Hero Intruder → **Chasm**       |

Season 1 also flips its mini-boss: heroes beat down **El Primo Libre**; villains
take down the hero **Champion**. Each stage has a `villainObjective` (or a
route-level `VillainObjectives` map); the controller picks the faction's
enemies, boss, mini-boss, and objective text at runtime.

**XP / leveling.** Kills grant campaign XP (+6) and clearing a season grants more
(+120); `PowerLevel = 1 + XP/120`, saved per player. A starting villain's
`ArmorDamageMult` climbs from 0.6 toward 1.0 as they level (+0.08/level — full
strength by ~level 6), and heroes get a mild scaling bonus; the multiplier
updates live on level-up. A "LEVEL UP" toast shows in the menu.

## Season 3 map — The Shadowlands ("Orders From Above")

A third fully built map: a shadow-biome realm of near-black ground and purple
void light, six sectors deep, ending at **Null's Throne**. Same route-module
contract as every other map, so the shared controller runs it unchanged. Villain
side flips it — you fight the **Lightbringers** and their champion the **Golden
Knight** instead of Null.

| File                                                 | Studio location                                      | Type               |
| ---------------------------------------------------- | ---------------------------------------------------- | ------------------ |
| `ServerStorage/ShadowlandsBuilder.lua`               | `ServerStorage > ShadowlandsBuilder`                 | ModuleScript (new) |
| `ReplicatedStorage/Campaign/ShadowlandsCampaign.lua` | `ReplicatedStorage > Campaign > ShadowlandsCampaign` | ModuleScript (new) |

Sectors: Broken Gate → Ashen Wastes → Shadow Spires → The Dark Bastion → Throne
Approach → Null's Throne. It's registered as Season 3 `status = "built"` in
`CampaignRegistry` and added to `WorldAtlas` (`SeasonLocations[3]`).

## Faction story briefings on the season card

Every built route carries a `Briefing` (hero) and `VillainBriefing` (villain)
string. When you pick a season and reach **PICK YOUR SIDE**, each side's card now
shows that season's mission briefing and the final foe you'll face on that side
(hero boss vs. villain boss), so the two perspectives read differently before you
commit. `CampaignMenu.server` reads the strings from the route modules and sends
them in the season payload; `CampaignMenu.client` renders them per card.

## Currency + character shop (unlock extra characters)

Alongside XP, the campaign now pays out **Coins**: +3 per enemy defeated and +250
per season cleared (`ShopCatalog.CoinsPerKill` / `CoinsPerSeason`). Coins and the
set of owned characters persist in the same DataStore record as progress/XP.

The **SHOP** button on the main menu opens a catalog of 17 extra characters — 7
heroes (Champion, Jumper, Titan, Red Rocket, Patriot, Valkery, Mercy) and 10
villains (El Primo Libre, Carnage, Golden Knight, Minus, Void Overlord, Null,
Manderin, Nemesis, The Anonymous, Omega) — each a real boss/heavy with its own
`CharacterKits` moveset and `CharacterModels` look. Buying one (server validates
coins + ownership, then persists) unlocks it in **Character Select** under its
faction tab, next to the free starters. The roster refreshes live the moment a
purchase lands.

| File                                         | Studio location                              | Type               |
| -------------------------------------------- | -------------------------------------------- | ------------------ |
| `ReplicatedStorage/Campaign/ShopCatalog.lua` | `ReplicatedStorage > Campaign > ShopCatalog` | ModuleScript (new) |

`CampaignMenu.server` owns the coin wallet + purchase validation (single writer to
the DataStore record); `CharacterSelect.server` reads the player's owned set from
the `OwnedCharacters` attribute and folds it into the faction rosters;
`CampaignMenu.client` adds the shop panel, coin display, and buy buttons.

## Warriors of the World (Season 3 story unlock)

Starting a **Season 3** campaign unlocks the original **Warriors of the World** as
playable heroes — the strike team that descends into Null's Shadowlands and
defeats the Void Overlord on Gildonia. They're a **story** unlock (free, no
Coins), and each stays pickable only while the story keeps them alive: at the end
of Season 5 they follow a distress beacon to Omega's planet, where **Omega takes
out the entire team**, so the window closes at S5. That still lets you fight Null
(S3–4), the Void Overlord (S5), and Omega himself with the Warriors' real kits.

| Warrior     | Playable seasons | Notes                                 |
| ----------- | ---------------- | ------------------------------------- |
| Red Rocket  | 3 – 5            | Leader of the Warriors                |
| Dead Dash   | 3 – 5            |                                       |
| Water Woman | 3 – 5            | Also a free starter (always pickable) |
| Liberty     | 3 – 5            |                                       |
| Jumper      | 3 – 5            |                                       |
| Frost       | 3 – 5            | Also a free starter (always pickable) |
| Valkery     | 3 – 4            | Cut down by Null in the S4 hunt       |

From Season 6 on they're gone from the roster — Omega wiped them out. The
gold-badged Warrior cards show up on the hero side of Character Select only when
the season you're starting is in their window. Frost and Water Woman are also base
starters, so they stay pickable everywhere — they're listed here as canonical
members of the team.

| File                                                | Studio location                                     | Type               |
| --------------------------------------------------- | --------------------------------------------------- | ------------------ |
| `ReplicatedStorage/Campaign/WarriorsOfTheWorld.lua` | `ReplicatedStorage > Campaign > WarriorsOfTheWorld` | ModuleScript (new) |

Both `CampaignMenu.client` (shows the season's Warrior cards) and
`CharacterSelect.server` (validates the pick is a Warrior in-window for the season
being started) read this module, so the roster and story windows are defined once.
Edit `Members` there to change who's in the team or when they leave.
