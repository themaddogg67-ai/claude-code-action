# SIEGE 2D — Tactical Breach

A top-down tactical shooter inspired by **Rainbow Six Siege**, built as a single
self-contained browser game. You play the **attacker** breaching a building held
by AI **defenders**. No build step, no dependencies — just open the file.

## Play

Open `index.html` in any modern browser (double-click it, or serve the folder).

```
# optional: serve locally
cd games/siege-2d && python3 -m http.server 8000
# then visit http://localhost:8000
```

## Controls

| Input           | Action          |
| --------------- | --------------- |
| `W` `A` `S` `D` | Move            |
| Mouse           | Aim             |
| Left click      | Fire            |
| `R`             | Reload          |
| `E`             | Operator gadget |

## Objective

- **Eliminate every defender**, or
- **Stand on a `DEF` objective point for 4 seconds** to secure it.

Survive the two-minute round without dropping to 0 health.

## Siege mechanics translated to 2D

- **Line-of-sight fog of war** — you only see rooms you have an angle into;
  defenders stay hidden until revealed, and briefly after you lose sight.
- **Reinforced vs destructible walls** — soft walls (brown) can be shot through
  or breached; reinforced walls (grey, hatched) block everything.
- **Breaching** — gadgets open new sightlines and flanking routes, just like the
  real game. Only Thermite can breach _reinforced_ walls.
- **Windows / barricades** (teal) — block movement until broken, but you can
  shoot and see through them.
- **Alerted AI** — gunfire draws nearby defenders; they push your last known
  position, then return to patrol.

## Operators

| Operator     | Role          | Gadget                                                                          |
| ------------ | ------------- | ------------------------------------------------------------------------------- |
| **Sledge**   | Breacher      | Breach hammer — instantly smashes an adjacent soft wall. Extra health, shotgun. |
| **Ash**      | Assault       | Breaching rounds — destroy soft walls at range. Fast, rapid-fire rifle.         |
| **Thermite** | Hard Breacher | Exothermic charge — the only way to open **reinforced** walls.                  |
| **Montagne** | Shield        | Extendable shield blocks frontal fire (toggle with `E`); can't shoot while up.  |

## Structure

- `index.html` — canvas, HUD, and menu markup
- `style.css` — tactical dark theme
- `game.js` — all game logic (map generation, LOS, AI, combat, rendering)
