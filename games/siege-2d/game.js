/*
 * SIEGE 2D — a top-down tactical shooter inspired by Rainbow Six Siege.
 *
 * You play the attacker breaching a building held by AI defenders. Core Siege
 * ideas translated to 2D: reinforced vs destructible walls, breaching gadgets,
 * cover props, line-of-sight fog of war, and a defuser to plant. Eliminate every
 * defender or plant and arm the defuser before the timer runs out.
 *
 * Pure browser game, no build step — open index.html directly.
 */

(() => {
  "use strict";

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------
  const TILE = 26;
  const COLS = 36;
  const ROWS = 24;
  const W = COLS * TILE;
  const H = ROWS * TILE;

  // Tile types
  const EXT = 0; // exterior ground (passable)
  const FLOOR = 1; // interior floor (passable)
  const REINF = 2; // reinforced wall (indestructible, blocks all)
  const SOFT = 3; // wooden wall (destructible, blocks move + sight)
  const RUBBLE = 4; // breached wall (passable, no sight/bullet block)
  const WINDOW = 5; // barricade (blocks move, allows sight/bullets, breakable)

  const SOFT_HP = 60;
  const WINDOW_HP = 40;

  // ---------------------------------------------------------------------------
  // Palette — a deliberately chosen tactical scheme with warm/cool room tints.
  // ---------------------------------------------------------------------------
  const COL = {
    ext: "#1b2a1e", // exterior grass/dirt
    extAlt: "#22331f",
    floor: "#2b2f3a",
    rubble: "#33291f",
    reinf: "#4a5560",
    reinfEdge: "#6b7885",
    reinfRivet: "#9aa8b5",
    wood: "#7a5230",
    woodEdge: "#9c6a3c",
    woodPlank: "#5e3d22",
    window: "#3d5a66",
    windowEdge: "#5f8b9c",
    // room tints, blended onto the floor per quadrant
    roomA: "#4a4275", // top-left — lounge (purple)
    roomB: "#2f5a6b", // top-right — office (teal)
    roomC: "#5c4636", // bottom-left — kitchen (warm)
    roomD: "#5e343c", // bottom-right — strongroom (red)
  };

  // ---------------------------------------------------------------------------
  // Operators
  // ---------------------------------------------------------------------------
  const OPERATORS = {
    sledge: {
      name: "Sledge",
      role: "Breacher",
      color: "#f2b134",
      vest: "#4a3a1a",
      hp: 130,
      speed: 145,
      blurb:
        "Tanky. Breaching hammer smashes soft walls in a wide arc instantly.",
      gadget: "hammer",
      gadgetLabel: "Breach Hammer",
      gadgetUses: 8,
      weapon: {
        name: "Shotgun",
        pellets: 6,
        spread: 0.35,
        damage: 12,
        range: 260,
        fireInterval: 620,
        mag: 7,
        reload: 2600,
      },
    },
    ash: {
      name: "Ash",
      role: "Assault",
      color: "#e5533c",
      vest: "#4a1f18",
      hp: 100,
      speed: 185,
      blurb: "Fast and aggressive. Breaching rounds destroy walls at range.",
      gadget: "grenade",
      gadgetLabel: "Breach Rounds",
      gadgetUses: 3,
      weapon: {
        name: "R4-C Rifle",
        pellets: 1,
        spread: 0.03,
        damage: 24,
        range: 460,
        fireInterval: 90,
        mag: 30,
        reload: 2100,
      },
    },
    thermite: {
      name: "Thermite",
      role: "Hard Breacher",
      color: "#48c0e8",
      vest: "#173a45",
      hp: 105,
      speed: 155,
      blurb:
        "Only operator who can breach REINFORCED walls. Charge burns through.",
      gadget: "charge",
      gadgetLabel: "Exothermic Charge",
      gadgetUses: 2,
      weapon: {
        name: "M1014 Rifle",
        pellets: 1,
        spread: 0.05,
        damage: 22,
        range: 430,
        fireInterval: 115,
        mag: 30,
        reload: 2300,
      },
    },
    montagne: {
      name: "Montagne",
      role: "Shield",
      color: "#6ad06a",
      vest: "#1d4a1d",
      hp: 120,
      speed: 135,
      blurb: "Extendable shield blocks frontal fire. Hold gadget to guard.",
      gadget: "shield",
      gadgetLabel: "Extendable Shield",
      gadgetUses: Infinity,
      weapon: {
        name: "P9 Pistol",
        pellets: 1,
        spread: 0.04,
        damage: 20,
        range: 380,
        fireInterval: 260,
        mag: 12,
        reload: 1800,
      },
    },
  };

  // Balanced loadout used by both sides in the local 1v1 duel.
  const DUEL_WEAPON = {
    name: "Duel Rifle",
    pellets: 1,
    spread: 0.06,
    damage: 18,
    range: 480,
    fireInterval: 130,
    mag: 30,
    reload: 1900,
  };
  const DUEL_P1 = {
    name: "Player 1 · Attacker",
    color: "#f2b134",
    vest: "#4a3a1a",
    hp: 110,
    speed: 168,
    weapon: DUEL_WEAPON,
  };
  const DUEL_P2 = {
    name: "Player 2 · Defender",
    color: "#48c0e8",
    vest: "#173a45",
    hp: 110,
    speed: 168,
    weapon: DUEL_WEAPON,
  };

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const rand = (a, b) => a + Math.random() * (b - a);
  const dist2 = (ax, ay, bx, by) => {
    const dx = ax - bx,
      dy = ay - by;
    return dx * dx + dy * dy;
  };
  const angLerp = (a, b, t) => {
    let d = ((b - a + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
    return a + d * t;
  };
  const tileAt = (grid, px, py) => {
    const tx = Math.floor(px / TILE),
      ty = Math.floor(py / TILE);
    if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return REINF;
    return grid[ty][tx];
  };
  const blocksMove = (t) => t === REINF || t === SOFT || t === WINDOW;
  const blocksSight = (t) => t === REINF || t === SOFT;

  // Shared input state, fed by keyboard/mouse AND by the on-screen touch controls.
  const Input = {
    moveX: 0, // analog move vector (-1..1), from the left joystick
    moveY: 0,
    aiming: false, // right joystick engaged → aim + auto-fire
    aimAngle: 0,
    fire: false,
  };

  // ---------------------------------------------------------------------------
  // Audio (tiny WebAudio synth — no assets)
  // ---------------------------------------------------------------------------
  const Audio = (() => {
    let ctx = null;
    let enabled = true;
    const ensure = () => {
      if (!ctx) {
        try {
          ctx = new (window.AudioContext || window.webkitAudioContext)();
        } catch (e) {
          enabled = false;
        }
      }
      return ctx;
    };
    const blip = (freq, dur, type, vol) => {
      if (!enabled) return;
      const c = ensure();
      if (!c) return;
      const o = c.createOscillator();
      const g = c.createGain();
      o.type = type || "square";
      o.frequency.value = freq;
      g.gain.value = vol || 0.05;
      o.connect(g);
      g.connect(c.destination);
      const now = c.currentTime;
      g.gain.setValueAtTime(g.gain.value, now);
      g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
      o.start(now);
      o.stop(now + dur);
    };
    return {
      shoot: () => blip(rand(180, 240), 0.08, "square", 0.04),
      enemyShoot: () => blip(rand(120, 150), 0.09, "sawtooth", 0.03),
      hit: () => blip(rand(90, 110), 0.12, "triangle", 0.06),
      breach: () => {
        blip(70, 0.35, "sawtooth", 0.09);
        blip(140, 0.2, "square", 0.05);
      },
      melee: () => blip(rand(80, 120), 0.14, "square", 0.07),
      plant: () => blip(520, 0.06, "sine", 0.04),
      reload: () => blip(320, 0.05, "sine", 0.03),
      win: () => {
        blip(440, 0.15, "sine", 0.06);
        setTimeout(() => blip(660, 0.25, "sine", 0.06), 150);
      },
      lose: () => {
        blip(220, 0.3, "sawtooth", 0.06);
        setTimeout(() => blip(140, 0.4, "sawtooth", 0.06), 200);
      },
      resume: () => {
        const c = ensure();
        if (c && c.state === "suspended") c.resume();
      },
    };
  })();

  // ---------------------------------------------------------------------------
  // Map generation
  // ---------------------------------------------------------------------------
  function generateMap() {
    const grid = [];
    for (let y = 0; y < ROWS; y++) grid.push(new Array(COLS).fill(EXT));

    const bx0 = 5,
      by0 = 3,
      bx1 = 30,
      by1 = 20;

    // Outer reinforced shell
    for (let x = bx0; x <= bx1; x++) {
      grid[by0][x] = REINF;
      grid[by1][x] = REINF;
    }
    for (let y = by0; y <= by1; y++) {
      grid[y][bx0] = REINF;
      grid[y][bx1] = REINF;
    }
    // Interior floor
    for (let y = by0 + 1; y < by1; y++)
      for (let x = bx0 + 1; x < bx1; x++) grid[y][x] = FLOOR;

    // Door openings in the outer shell
    grid[by0][12] = FLOOR;
    grid[by1][20] = FLOOR;
    // Windows (breakable barricades)
    grid[8][bx0] = WINDOW;
    grid[15][bx0] = WINDOW;
    grid[7][bx1] = WINDOW;
    grid[16][bx1] = WINDOW;

    // Interior vertical wooden divider with two door gaps
    const vx = 18;
    for (let y = by0 + 1; y < by1; y++) grid[y][vx] = SOFT;
    grid[by0 + 3][vx] = FLOOR;
    grid[by0 + 12][vx] = FLOOR;

    // Interior horizontal wooden divider with two door gaps
    const hy = 11;
    for (let x = bx0 + 1; x < bx1; x++)
      if (grid[hy][x] === FLOOR) grid[hy][x] = SOFT;
    grid[hy][9] = FLOOR;
    grid[hy][25] = FLOOR;

    // A reinforced strongroom (only Thermite can breach the reinforced sides).
    const rx0 = 24,
      ry0 = 14,
      rx1 = 29,
      ry1 = 19;
    for (let x = rx0; x <= rx1; x++) {
      grid[ry0][x] = REINF;
      grid[ry1][x] = REINF;
    }
    for (let y = ry0; y <= ry1; y++) {
      grid[y][rx0] = REINF;
      grid[y][rx1] = REINF;
    }
    grid[ry1][rx0 + 2] = SOFT; // wooden doorway into the strongroom

    // Candidate interior floor tiles for spawns/objectives/props
    const floors = [];
    for (let y = by0 + 1; y < by1; y++)
      for (let x = bx0 + 1; x < bx1; x++)
        if (grid[y][x] === FLOOR) floors.push({ x, y });

    const centerPx = (t) => ({
      x: t.x * TILE + TILE / 2,
      y: t.y * TILE + TILE / 2,
    });

    // Player spawns outside, approaching from the left.
    const playerSpawn = { x: 2 * TILE + TILE / 2, y: (ROWS / 2) * TILE };

    // Two bomb sites: one in the reinforced strongroom, one in the top-right office.
    const objectives = [
      { ...centerPx({ x: 26, y: 16 }), label: "A" },
      { ...centerPx({ x: 25, y: 6 }), label: "B" },
    ];

    // Enemy spawns: interior tiles reasonably far from the player entrance.
    const farFloors = floors.filter(
      (t) =>
        dist2(t.x * TILE, t.y * TILE, playerSpawn.x, playerSpawn.y) >
        (13 * TILE) ** 2,
    );
    const enemySpawns = [];
    const shuffled = farFloors.slice().sort(() => Math.random() - 0.5);
    for (let i = 0; i < shuffled.length && enemySpawns.length < 5; i++) {
      const c = centerPx(shuffled[i]);
      if (
        enemySpawns.every((e) => dist2(e.x, e.y, c.x, c.y) > (3 * TILE) ** 2)
      ) {
        enemySpawns.push(c);
      }
    }

    // Cover props — crates (destructible), tables & lockers (solid), barrels.
    const props = [];
    const propTiles = [
      { x: 9, y: 6, kind: "crate" },
      { x: 10, y: 6, kind: "crate" },
      { x: 14, y: 8, kind: "table" },
      { x: 8, y: 14, kind: "locker" },
      { x: 11, y: 16, kind: "crate" },
      { x: 15, y: 5, kind: "barrel" },
      { x: 22, y: 8, kind: "table" },
      { x: 27, y: 5, kind: "crate" },
      { x: 21, y: 15, kind: "crate" },
      { x: 26, y: 17, kind: "barrel" },
      { x: 13, y: 13, kind: "table" },
      { x: 23, y: 12, kind: "locker" },
    ];
    const occupied = (tx, ty) =>
      objectives.some(
        (o) => Math.floor(o.x / TILE) === tx && Math.floor(o.y / TILE) === ty,
      ) ||
      enemySpawns.some(
        (e) => Math.floor(e.x / TILE) === tx && Math.floor(e.y / TILE) === ty,
      );
    for (const p of propTiles) {
      if (grid[p.y] && grid[p.y][p.x] === FLOOR && !occupied(p.x, p.y)) {
        const cx = p.x * TILE + TILE / 2,
          cy = p.y * TILE + TILE / 2;
        const kind = p.kind;
        const half =
          kind === "barrel"
            ? TILE * 0.32
            : kind === "table"
              ? TILE * 0.42
              : TILE * 0.38;
        props.push({
          x: cx,
          y: cy,
          hw: half,
          hh: half,
          kind,
          hp: kind === "crate" ? 45 : Infinity,
          round: kind === "barrel",
          dead: false,
        });
      }
    }

    return { grid, playerSpawn, enemySpawns, objectives, props, vx, hy };
  }

  // Room tint by quadrant relative to the interior dividers.
  function roomTint(tx, ty, vx, hy) {
    if (ty < hy) return tx < vx ? COL.roomA : COL.roomB;
    return tx < vx ? COL.roomC : COL.roomD;
  }

  // ---------------------------------------------------------------------------
  // Line of sight (pixel-space DDA across the tile grid)
  // ---------------------------------------------------------------------------
  function losClear(grid, x0, y0, x1, y1) {
    const dx = x1 - x0,
      dy = y1 - y0;
    const steps = Math.ceil(Math.hypot(dx, dy) / (TILE * 0.4));
    if (steps === 0) return true;
    const sx = dx / steps,
      sy = dy / steps;
    let px = x0,
      py = y0;
    for (let i = 1; i < steps; i++) {
      px += sx;
      py += sy;
      if (blocksSight(tileAt(grid, px, py))) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Entities
  // ---------------------------------------------------------------------------
  class Bullet {
    // team: 0 = Player 1, 1 = Player 2, -1 = AI defender.
    constructor(x, y, ang, speed, damage, range, team) {
      this.x = x;
      this.y = y;
      this.vx = Math.cos(ang) * speed;
      this.vy = Math.sin(ang) * speed;
      this.damage = damage;
      this.range = range;
      this.traveled = 0;
      this.team = team;
      this.fromAI = team === -1;
      this.dead = false;
    }
  }

  class Enemy {
    constructor(x, y) {
      this.x = x;
      this.y = y;
      this.hp = 100;
      this.radius = TILE * 0.34;
      this.angle = rand(0, Math.PI * 2);
      this.speed = 95;
      this.state = "patrol";
      this.target = null;
      this.fireCd = rand(300, 900);
      this.alertTimer = 0;
      this.wander = { x, y, t: 0, a: 0 };
      this.revealTimer = 0;
      this.muzzle = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Game
  // ---------------------------------------------------------------------------
  class Game {
    constructor(canvas, opKey, opts) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      opts = opts || {};
      this.mode = opts.mode || "solo"; // "solo" (vs AI) | "duel" (local 1v1)
      this.twoPlayer = this.mode === "duel";
      this.op = opKey ? OPERATORS[opKey] : null;
      this.reset();
      this.bindInput();
    }

    makeFighter(op, spawn, team, controls, aimMode) {
      return {
        x: spawn.x,
        y: spawn.y,
        radius: TILE * 0.34,
        hp: op.hp,
        maxHp: op.hp,
        angle: team === 1 ? Math.PI : 0,
        speed: op.speed,
        ammo: op.weapon.mag,
        mag: op.weapon.mag,
        reloading: false,
        reloadEnd: 0,
        fireReady: 0,
        gadgetUses: op.gadgetUses === undefined ? 0 : op.gadgetUses,
        shieldUp: false,
        legPhase: 0,
        team,
        op,
        color: op.color,
        vest: op.vest,
        name: op.name,
        controls,
        aimMode,
        alive: true,
      };
    }

    reset() {
      const map = generateMap();
      this.grid = map.grid;
      this.vx = map.vx;
      this.hy = map.hy;
      this.props = map.props;
      this.softHp = {};
      this.bullets = [];
      this.particles = [];
      this.floaters = [];
      this.charges = [];
      this.time = this.twoPlayer ? 99 : 150;
      this.state = "playing";
      this.shake = 0;
      this.vis = null;
      this.msg = "";
      this.msgT = 0;
      this.meleeCd = 0;
      this.duelWinner = undefined;
      this.last = performance.now();

      if (this.twoPlayer) {
        // Local 1v1: two human fighters, no AI, no fog, no objective.
        this.objectives = [];
        this.enemies = [];
        const rightSpawn = {
          x: (COLS - 3) * TILE + TILE / 2,
          y: (ROWS / 2) * TILE,
        };
        const p1Controls = {
          up: "w",
          left: "a",
          down: "s",
          right: "d",
          shoot: " ",
        };
        const p2Controls = {
          up: "arrowup",
          left: "arrowleft",
          down: "arrowdown",
          right: "arrowright",
          shoot: "enter",
        };
        this.player = this.makeFighter(
          DUEL_P1,
          map.playerSpawn,
          0,
          p1Controls,
          "move",
        );
        this.player2 = this.makeFighter(
          DUEL_P2,
          rightSpawn,
          1,
          p2Controls,
          "move",
        );
        this.fighters = [this.player, this.player2];
        return;
      }

      // Solo vs AI (original mode).
      this.objectives = map.objectives.map((o) => ({
        ...o,
        radius: TILE * 0.5,
      }));
      const p1Controls = { up: "w", left: "a", down: "s", right: "d" };
      this.player = this.makeFighter(
        this.op,
        map.playerSpawn,
        0,
        p1Controls,
        "mouse",
      );
      this.fighters = [this.player];

      this.enemies = map.enemySpawns.map((s) => new Enemy(s.x, s.y));
      // Two defenders actively hunt you so a fight always comes to you.
      const roamers = this.enemies
        .slice()
        .sort(() => Math.random() - 0.5)
        .slice(0, 2);
      for (const e of roamers) {
        e.roamer = true;
        e.state = "alert";
        e.target = { x: this.player.x, y: map.playerSpawn.y };
      }

      // Objective / defuser state
      this.plantProgress = 0;
      this.planted = false;
      this.plantedSite = null;
      this.armTimer = 20;
    }

    // ----- input --------------------------------------------------------------
    bindInput() {
      this.keys = {};
      this.mouse = { x: W / 2, y: H / 2, down: false };

      this._kd = (e) => {
        const k = e.key.toLowerCase();
        // Stop the page scrolling/submitting on the keys the game uses.
        if (
          [
            "r",
            "e",
            "f",
            " ",
            "enter",
            "arrowup",
            "arrowdown",
            "arrowleft",
            "arrowright",
          ].includes(k)
        )
          e.preventDefault();
        if (!this.keys[k]) {
          // edge-triggered actions (single-player gadget/melee/reload only)
          if (!this.twoPlayer) {
            if (k === "r") this.startReload();
            if (k === "e") this.useGadget();
            if (k === "f") this.interactEdge();
          }
        }
        this.keys[k] = true;
      };
      this._ku = (e) => {
        this.keys[e.key.toLowerCase()] = false;
      };
      const toCanvas = (e) => {
        const r = this.canvas.getBoundingClientRect();
        this.mouse.x = ((e.clientX - r.left) / r.width) * W;
        this.mouse.y = ((e.clientY - r.top) / r.height) * H;
      };
      this._mm = (e) => toCanvas(e);
      this._md = (e) => {
        toCanvas(e);
        this.mouse.down = true;
        Audio.resume();
      };
      this._mu = () => {
        this.mouse.down = false;
      };

      window.addEventListener("keydown", this._kd);
      window.addEventListener("keyup", this._ku);
      this.canvas.addEventListener("mousemove", this._mm);
      this.canvas.addEventListener("mousedown", this._md);
      window.addEventListener("mouseup", this._mu);
    }

    destroy() {
      window.removeEventListener("keydown", this._kd);
      window.removeEventListener("keyup", this._ku);
      this.canvas.removeEventListener("mousemove", this._mm);
      this.canvas.removeEventListener("mousedown", this._md);
      window.removeEventListener("mouseup", this._mu);
    }

    // ----- tile helpers -------------------------------------------------------
    tileKey(tx, ty) {
      return tx + "," + ty;
    }

    damageTile(tx, ty, dmg) {
      if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return;
      const t = this.grid[ty][tx];
      if (t !== SOFT && t !== WINDOW) return;
      const key = this.tileKey(tx, ty);
      if (this.softHp[key] === undefined)
        this.softHp[key] = t === SOFT ? SOFT_HP : WINDOW_HP;
      this.softHp[key] -= dmg;
      if (this.softHp[key] <= 0) {
        this.grid[ty][tx] = RUBBLE;
        this.spawnDebris(
          tx * TILE + TILE / 2,
          ty * TILE + TILE / 2,
          COL.woodEdge,
        );
      }
    }

    breachTile(tx, ty) {
      if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return false;
      const t = this.grid[ty][tx];
      if (t === SOFT || t === WINDOW) {
        this.grid[ty][tx] = RUBBLE;
        this.spawnDebris(
          tx * TILE + TILE / 2,
          ty * TILE + TILE / 2,
          COL.woodEdge,
        );
        return true;
      }
      return false;
    }

    breachReinforced(tx, ty) {
      if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return false;
      if (this.grid[ty][tx] === REINF) {
        this.grid[ty][tx] = RUBBLE;
        this.spawnDebris(
          tx * TILE + TILE / 2,
          ty * TILE + TILE / 2,
          COL.reinfRivet,
        );
        return true;
      }
      return false;
    }

    // ----- combat -------------------------------------------------------------
    startReload(f) {
      f = f || this.player;
      if (f.reloading || f.ammo === f.op.weapon.mag) return;
      f.reloading = true;
      f.reloadEnd = performance.now() + f.op.weapon.reload;
      Audio.reload();
    }

    shoot(f) {
      f = f || this.player;
      const now = performance.now();
      if (f.reloading || f.shieldUp) return;
      if (now < f.fireReady || f.ammo <= 0) {
        if (f.ammo <= 0) this.startReload(f);
        return;
      }
      const wpn = f.op.weapon;
      f.fireReady = now + wpn.fireInterval;
      f.ammo--;
      for (let i = 0; i < wpn.pellets; i++) {
        const a = f.angle + rand(-wpn.spread, wpn.spread);
        this.bullets.push(
          new Bullet(
            f.x + Math.cos(f.angle) * f.radius,
            f.y + Math.sin(f.angle) * f.radius,
            a,
            760,
            wpn.damage,
            wpn.range,
            f.team,
          ),
        );
      }
      this.spawnMuzzle(f.x, f.y, f.angle, "#ffd25a");
      this.shake = Math.min(this.shake + (wpn.pellets > 1 ? 6 : 2.5), 12);
      Audio.shoot();
      for (const e of this.enemies) {
        if (
          dist2(e.x, e.y, f.x, f.y) < (9 * TILE) ** 2 &&
          e.state === "patrol"
        ) {
          e.state = "alert";
          e.target = { x: f.x, y: f.y };
          e.alertTimer = 4;
        }
      }
    }

    // The tile directly in front of the player (for melee / gadgets).
    frontTile() {
      const p = this.player;
      const fx = p.x + Math.cos(p.angle) * TILE * 0.8;
      const fy = p.y + Math.sin(p.angle) * TILE * 0.8;
      return { tx: Math.floor(fx / TILE), ty: Math.floor(fy / TILE), fx, fy };
    }

    // F pressed: plant (if on a site) is handled while held in update; otherwise
    // this edge does a melee breach of the wall / crate in front.
    interactEdge() {
      if (this.state !== "playing") return;
      if (this.onObjective()) return; // planting handled in update while F held
      this.meleeBreach();
    }

    meleeBreach() {
      if (this.meleeCd > 0) return;
      const p = this.player;
      const { tx, ty, fx, fy } = this.frontTile();
      this.meleeCd = 0.35;
      this.spawnMuzzle(p.x, p.y, p.angle, "#cfd6dd"); // swing arc puff
      Audio.melee();

      // Break a crate prop in front?
      for (const pr of this.props) {
        if (pr.dead || pr.kind !== "crate") continue;
        if (
          Math.abs(pr.x - fx) < pr.hw + 8 &&
          Math.abs(pr.y - fy) < pr.hh + 8
        ) {
          pr.dead = true;
          this.spawnDebris(pr.x, pr.y, COL.woodEdge);
          this.shake = 6;
          this.flash("Crate smashed");
          return;
        }
      }

      const t = this.grid[ty] && this.grid[ty][tx];
      if (t === SOFT || t === WINDOW) {
        this.breachTile(tx, ty);
        this.shake = 7;
        Audio.breach();
        this.flash("Wooden wall breached!");
      } else if (t === REINF) {
        this.flash("Reinforced — need Thermite's charge");
      } else {
        this.flash("Nothing to breach here");
      }
    }

    useGadget() {
      if (this.state !== "playing") return;
      const p = this.player;
      const g = this.op.gadget;

      if (g === "shield") {
        p.shieldUp = !p.shieldUp;
        this.flash(p.shieldUp ? "Shield UP" : "Shield DOWN");
        return;
      }

      if (p.gadgetUses <= 0) {
        this.flash("No gadget charges left");
        return;
      }

      const { tx, ty } = this.frontTile();

      if (g === "hammer") {
        // Sledge smashes the front tile plus its two neighbours (wide arc).
        const perp = p.angle + Math.PI / 2;
        const spots = [
          { tx, ty },
          {
            tx: Math.floor(
              (p.x + Math.cos(p.angle) * TILE * 0.8 + Math.cos(perp) * TILE) /
                TILE,
            ),
            ty: Math.floor(
              (p.y + Math.sin(p.angle) * TILE * 0.8 + Math.sin(perp) * TILE) /
                TILE,
            ),
          },
          {
            tx: Math.floor(
              (p.x + Math.cos(p.angle) * TILE * 0.8 - Math.cos(perp) * TILE) /
                TILE,
            ),
            ty: Math.floor(
              (p.y + Math.sin(p.angle) * TILE * 0.8 - Math.sin(perp) * TILE) /
                TILE,
            ),
          },
        ];
        let any = false;
        for (const s of spots) if (this.breachTile(s.tx, s.ty)) any = true;
        if (any) {
          p.gadgetUses--;
          this.shake = 10;
          Audio.breach();
          this.flash("SMASH! Walls breached");
        } else {
          this.flash("No wooden wall in front");
        }
      } else if (g === "charge") {
        const t = this.grid[ty][tx];
        if (t === REINF || t === SOFT || t === WINDOW) {
          p.gadgetUses--;
          this.charges.push({ tx, ty, t: 1.4, reinforced: t === REINF });
          this.flash("Charge placed — stand clear");
        } else {
          this.flash("Aim at a wall to place charge");
        }
      } else if (g === "grenade") {
        p.gadgetUses--;
        this.charges.push({
          projectile: true,
          x: p.x,
          y: p.y,
          vx: Math.cos(p.angle) * 520,
          vy: Math.sin(p.angle) * 520,
          life: 1.2,
        });
        Audio.shoot();
        this.flash("Breaching round fired");
      }
    }

    flash(text) {
      this.msg = text;
      this.msgT = 2.2;
    }

    // ----- particles ----------------------------------------------------------
    spawnMuzzle(x, y, ang, color) {
      for (let i = 0; i < 5; i++) {
        const a = ang + rand(-0.3, 0.3);
        const s = rand(120, 260);
        this.particles.push({
          x: x + Math.cos(ang) * 14,
          y: y + Math.sin(ang) * 14,
          vx: Math.cos(a) * s,
          vy: Math.sin(a) * s,
          life: rand(0.05, 0.16),
          max: 0.16,
          color,
          r: rand(1.5, 3),
        });
      }
    }

    spawnBlood(x, y) {
      for (let i = 0; i < 10; i++) {
        const a = rand(0, Math.PI * 2);
        const s = rand(40, 200);
        this.particles.push({
          x,
          y,
          vx: Math.cos(a) * s,
          vy: Math.sin(a) * s,
          life: rand(0.2, 0.5),
          max: 0.5,
          color: "#c0392b",
          r: rand(1.5, 3.5),
        });
      }
    }

    spawnDebris(x, y, color) {
      for (let i = 0; i < 16; i++) {
        const a = rand(0, Math.PI * 2);
        const s = rand(60, 260);
        this.particles.push({
          x,
          y,
          vx: Math.cos(a) * s,
          vy: Math.sin(a) * s,
          life: rand(0.3, 0.7),
          max: 0.7,
          color,
          r: rand(1.5, 4),
        });
      }
    }

    // ----- movement -----------------------------------------------------------
    moveCircle(ent, nx, ny) {
      const r = ent.radius;
      let tx = ent.x;
      if (!this.solidAt(nx, ent.y, r)) tx = nx;
      let ty = ent.y;
      if (!this.solidAt(tx, ny, r)) ty = ny;
      ent.x = clamp(tx, r, W - r);
      ent.y = clamp(ty, r, H - r);
    }

    solidAt(px, py, r) {
      const pts = [
        [px - r, py],
        [px + r, py],
        [px, py - r],
        [px, py + r],
      ];
      for (const [x, y] of pts)
        if (blocksMove(tileAt(this.grid, x, y))) return true;
      // props (circle vs rect)
      for (const pr of this.props) {
        if (pr.dead) continue;
        const cx = clamp(px, pr.x - pr.hw, pr.x + pr.hw);
        const cy = clamp(py, pr.y - pr.hh, pr.y + pr.hh);
        if (dist2(px, py, cx, cy) < r * r) return true;
      }
      return false;
    }

    onObjective() {
      const p = this.player;
      for (const o of this.objectives)
        if (dist2(p.x, p.y, o.x, o.y) < (TILE * 0.85) ** 2) return o;
      return null;
    }

    // ----- update -------------------------------------------------------------
    update(dt) {
      if (this.state !== "playing") return;
      if (this.msgT > 0) this.msgT -= dt;
      if (this.meleeCd > 0) this.meleeCd -= dt;
      if (this.shake > 0) this.shake = Math.max(0, this.shake - dt * 40);

      if (this.twoPlayer) return this.updateDuel(dt);

      this.time -= dt;
      if (this.time <= 0 && !this.planted) {
        this.time = 0;
        return this.end(false, "Time ran out before you armed the defuser.");
      }

      this.updateFighter(this.player, dt);
      this.updateEnemies(dt);
      this.updateBullets(dt);
      this.updateCharges(dt);
      this.updateParticles(dt);
      this.updateObjective(dt);
      this.computeVisibility();

      if (this.enemies.length === 0 && !this.planted)
        this.end(true, "All defenders eliminated.");
      if (this.player.hp <= 0) this.end(false, "You were killed.");
    }

    updateDuel(dt) {
      this.time -= dt;
      for (const f of this.fighters) this.updateFighter(f, dt);
      this.updateBullets(dt);
      this.updateParticles(dt);

      const alive = this.fighters.filter((f) => f.alive);
      if (alive.length <= 1) {
        const w = alive[0] || null;
        this.state = "over";
        this.duelWinner = w; // null → draw
      } else if (this.time <= 0) {
        this.time = 0;
        this.state = "over";
        // Higher HP wins on timeout; equal HP is a draw.
        const [a, b] = this.fighters;
        this.duelWinner = a.hp === b.hp ? null : a.hp > b.hp ? a : b;
      }
    }

    updateFighter(f, dt) {
      if (!f.alive) return;
      const c = f.controls;

      // Movement input: this fighter's keys, plus touch left-stick for solo P1.
      let dx = 0,
        dy = 0;
      if (this.keys[c.up]) dy -= 1;
      if (this.keys[c.down]) dy += 1;
      if (this.keys[c.left]) dx -= 1;
      if (this.keys[c.right]) dx += 1;
      if (!this.twoPlayer && (Input.moveX || Input.moveY)) {
        dx += Input.moveX;
        dy += Input.moveY;
      }

      const shielded = f.shieldUp;
      const sp = f.speed * (shielded ? 0.55 : 1);
      const mag = Math.hypot(dx, dy);
      if (mag > 0.01) {
        const scale = Math.min(mag, 1);
        this.moveCircle(
          f,
          f.x + (dx / mag) * sp * scale * dt,
          f.y + (dy / mag) * sp * scale * dt,
        );
        f.legPhase += dt * 12;
        if (f.aimMode === "move") f.angle = Math.atan2(dy, dx); // face where you walk
      }

      // Aim for mouse/touch fighters (solo P1).
      if (f.aimMode === "mouse") {
        if (Input.aiming) f.angle = Input.aimAngle;
        else f.angle = Math.atan2(this.mouse.y - f.y, this.mouse.x - f.x);
      }

      if (f.reloading && performance.now() >= f.reloadEnd) {
        f.reloading = false;
        f.ammo = f.op.weapon.mag;
      }

      // Fire
      let firing = false;
      if (f.aimMode === "mouse")
        firing = this.mouse.down || (Input.aiming && Input.fire);
      if (c.shoot && this.keys[c.shoot]) firing = true;
      if (firing) this.shoot(f);

      // Auto-reload in the duel to keep the control scheme minimal.
      if (this.twoPlayer && f.ammo <= 0 && !f.reloading) this.startReload(f);
    }

    updateEnemies(dt) {
      const p = this.player;
      for (const e of this.enemies) {
        const canSee =
          dist2(e.x, e.y, p.x, p.y) < (11 * TILE) ** 2 &&
          losClear(this.grid, e.x, e.y, p.x, p.y);
        e.canSee = canSee;

        if (canSee) {
          e.state = "engage";
          e.target = { x: p.x, y: p.y };
          e.alertTimer = 4;
          e.revealTimer = 1.2;
        } else if (e.revealTimer > 0) {
          e.revealTimer -= dt;
        }

        if (e.state === "engage") {
          e.angle = angLerp(e.angle, Math.atan2(p.y - e.y, p.x - e.x), 0.15);
          const d = Math.hypot(p.x - e.x, p.y - e.y);
          const want = 5 * TILE;
          let mvx = 0,
            mvy = 0;
          const toward = d > want ? 1 : d < want - TILE ? -1 : 0;
          mvx += Math.cos(e.angle) * toward;
          mvy += Math.sin(e.angle) * toward;
          const strafe = Math.sin(performance.now() / 500 + e.x) * 0.6;
          mvx += Math.cos(e.angle + Math.PI / 2) * strafe;
          mvy += Math.sin(e.angle + Math.PI / 2) * strafe;
          const l = Math.hypot(mvx, mvy) || 1;
          this.moveCircle(
            e,
            e.x + (mvx / l) * e.speed * dt,
            e.y + (mvy / l) * e.speed * dt,
          );

          e.fireCd -= dt * 1000;
          if (e.fireCd <= 0 && canSee) {
            e.fireCd = rand(650, 1100);
            const a = e.angle + rand(-0.14, 0.14);
            this.bullets.push(
              new Bullet(e.x, e.y, a, 620, 14, 12 * TILE, false),
            );
            e.muzzle = 0.08;
            this.spawnMuzzle(e.x, e.y, e.angle, "#ff8866");
            Audio.enemyShoot();
          }
          if (!canSee) {
            e.alertTimer -= dt;
            if (e.alertTimer <= 0) e.state = "alert";
          }
        } else if (e.state === "alert" && e.target) {
          const d = Math.hypot(e.target.x - e.x, e.target.y - e.y);
          if (d > TILE) {
            const a = Math.atan2(e.target.y - e.y, e.target.x - e.x);
            e.angle = angLerp(e.angle, a, 0.1);
            this.moveCircle(
              e,
              e.x + Math.cos(a) * e.speed * dt,
              e.y + Math.sin(a) * e.speed * dt,
            );
          } else {
            e.state = "patrol";
            e.target = null;
          }
        } else {
          // Patrol. Roamers actively hunt — they re-path toward the player's
          // general area, so combat always comes to you.
          e.wander.t -= dt;
          if (e.wander.t <= 0) {
            e.wander.t = rand(1.5, 3.5);
            if (e.roamer) {
              e.wander.a = Math.atan2(p.y - e.y, p.x - e.x) + rand(-0.7, 0.7);
            } else {
              e.wander.a = rand(0, Math.PI * 2);
            }
          }
          const a = e.wander.a;
          const wanderSpeed = e.roamer ? 0.7 : 0.4;
          e.angle = angLerp(e.angle, a, 0.05);
          this.moveCircle(
            e,
            e.x + Math.cos(a) * e.speed * wanderSpeed * dt,
            e.y + Math.sin(a) * e.speed * wanderSpeed * dt,
          );
        }
        if (e.muzzle > 0) e.muzzle -= dt;
      }
    }

    hitsProp(x, y) {
      for (const pr of this.props) {
        if (pr.dead) continue;
        if (Math.abs(x - pr.x) < pr.hw && Math.abs(y - pr.y) < pr.hh) return pr;
      }
      return null;
    }

    updateBullets(dt) {
      const p = this.player;
      for (const b of this.bullets) {
        const steps = 3;
        for (let s = 0; s < steps && !b.dead; s++) {
          const nx = b.x + (b.vx * dt) / steps;
          const ny = b.y + (b.vy * dt) / steps;
          b.traveled += Math.hypot(nx - b.x, ny - b.y);
          b.x = nx;
          b.y = ny;
          if (b.traveled > b.range) b.dead = true;
          if (b.x < 0 || b.y < 0 || b.x > W || b.y > H) b.dead = true;

          const t = tileAt(this.grid, b.x, b.y);
          const tx = Math.floor(b.x / TILE),
            ty = Math.floor(b.y / TILE);
          if (t === REINF) {
            b.dead = true;
            this.spawnDebris(b.x, b.y, COL.reinfEdge);
          } else if (t === SOFT || t === WINDOW) {
            this.damageTile(tx, ty, b.damage * 0.9);
            b.dead = true;
          }
          if (b.dead) break;

          // props
          const pr = this.hitsProp(b.x, b.y);
          if (pr) {
            b.dead = true;
            if (pr.kind === "crate") {
              pr.hp -= b.damage;
              this.spawnDebris(b.x, b.y, COL.woodEdge);
              if (pr.hp <= 0) {
                pr.dead = true;
                this.spawnDebris(pr.x, pr.y, COL.woodEdge);
              }
            } else {
              this.spawnDebris(b.x, b.y, "#8892a0");
            }
            break;
          }

          if (!b.fromAI) {
            // A fighter's bullet: hits AI defenders...
            for (const e of this.enemies) {
              if (dist2(b.x, b.y, e.x, e.y) < e.radius * e.radius) {
                e.hp -= b.damage;
                b.dead = true;
                this.spawnBlood(b.x, b.y);
                Audio.hit();
                if (e.hp <= 0) {
                  this.spawnBlood(e.x, e.y);
                  this.floaters.push({
                    x: e.x,
                    y: e.y,
                    t: 1,
                    text: "✖",
                    color: "#e5533c",
                  });
                }
                break;
              }
            }
            // ...and any OTHER-team fighter (the opponent in a duel).
            if (!b.dead) {
              for (const f of this.fighters) {
                if (!f.alive || f.team === b.team) continue;
                if (this.bulletHitsFighter(b, f)) break;
              }
            }
          } else {
            // AI bullet: hits any fighter.
            for (const f of this.fighters) {
              if (!f.alive) continue;
              if (this.bulletHitsFighter(b, f)) break;
            }
          }
        }
      }
      this.enemies = this.enemies.filter((e) => e.hp > 0);
      this.bullets = this.bullets.filter((b) => !b.dead);
    }

    bulletHitsFighter(b, f) {
      if (dist2(b.x, b.y, f.x, f.y) >= f.radius * f.radius) return false;
      if (f.shieldUp) {
        const toB = Math.atan2(b.y - f.y, b.x - f.x);
        const diff = Math.abs(
          ((toB - f.angle + Math.PI * 3) % (Math.PI * 2)) - Math.PI,
        );
        if (diff < 1.1) {
          b.dead = true;
          this.spawnDebris(b.x, b.y, "#6ad06a");
          return true;
        }
      }
      f.hp -= b.damage;
      b.dead = true;
      this.spawnBlood(b.x, b.y);
      this.shake = Math.min(this.shake + 5, 14);
      Audio.hit();
      if (f.hp <= 0) {
        f.hp = 0;
        f.alive = false;
        this.spawnBlood(f.x, f.y);
        this.floaters.push({
          x: f.x,
          y: f.y,
          t: 1.2,
          text: "✖",
          color: f.color,
        });
      }
      return true;
    }

    updateCharges(dt) {
      for (const c of this.charges) {
        if (c.projectile) {
          const steps = 4;
          for (let s = 0; s < steps && !c.done; s++) {
            c.x += (c.vx * dt) / steps;
            c.y += (c.vy * dt) / steps;
            const t = tileAt(this.grid, c.x, c.y);
            const tx = Math.floor(c.x / TILE),
              ty = Math.floor(c.y / TILE);
            if (t === SOFT || t === WINDOW) {
              this.breachTile(tx, ty);
              this.breachTile(tx, ty - 1);
              this.breachTile(tx, ty + 1);
              c.done = true;
              this.shake = 8;
              Audio.breach();
              this.flash("Wall blown open!");
            } else if (
              t === REINF ||
              c.x < 0 ||
              c.x > W ||
              c.y < 0 ||
              c.y > H
            ) {
              c.done = true;
              this.spawnDebris(c.x, c.y, COL.reinfEdge);
            }
          }
          c.life -= dt;
          if (c.life <= 0) c.done = true;
        } else {
          c.t -= dt;
          if (c.t <= 0 && !c.done) {
            c.done = true;
            let ok = c.reinforced
              ? this.breachReinforced(c.tx, c.ty)
              : this.breachTile(c.tx, c.ty);
            if (ok) {
              this.shake = 12;
              Audio.breach();
              this.flash(
                c.reinforced ? "REINFORCED wall breached!" : "Wall breached!",
              );
            }
          }
        }
      }
      this.charges = this.charges.filter((c) => !c.done);
    }

    updateParticles(dt) {
      for (const pt of this.particles) {
        pt.x += pt.vx * dt;
        pt.y += pt.vy * dt;
        pt.vx *= 0.9;
        pt.vy *= 0.9;
        pt.life -= dt;
      }
      this.particles = this.particles.filter((p) => p.life > 0);
      for (const f of this.floaters) {
        f.y -= 20 * dt;
        f.t -= dt;
      }
      this.floaters = this.floaters.filter((f) => f.t > 0);
    }

    updateObjective(dt) {
      const p = this.player;
      if (this.planted) {
        this.armTimer -= dt;
        if (this.armTimer <= 0)
          this.end(true, "Defuser detonated — site destroyed. You win!");
        return;
      }
      const site = this.onObjective();
      this._onSite = site;
      if (site && this.keys["f"]) {
        this.plantProgress += dt;
        if (
          Math.floor(this.plantProgress * 4) !==
          Math.floor((this.plantProgress - dt) * 4)
        )
          Audio.plant();
        if (this.plantProgress >= 3) {
          this.planted = true;
          this.plantedSite = site;
          this.flash("DEFUSER ARMED — defend it!");
        }
      } else {
        this.plantProgress = Math.max(0, this.plantProgress - dt * 1.5);
      }
    }

    computeVisibility() {
      const p = this.player;
      const R = 10;
      const vis = {};
      const ptx = Math.floor(p.x / TILE),
        pty = Math.floor(p.y / TILE);
      for (let ty = pty - R; ty <= pty + R; ty++) {
        for (let tx = ptx - R; tx <= ptx + R; tx++) {
          if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) continue;
          const cx = tx * TILE + TILE / 2,
            cy = ty * TILE + TILE / 2;
          if (dist2(cx, cy, p.x, p.y) > (R * TILE) ** 2) continue;
          if (losClear(this.grid, p.x, p.y, cx, cy)) vis[tx + "," + ty] = true;
        }
      }
      this.vis = vis;
    }

    isVisible(px, py) {
      if (this.twoPlayer) return true; // shared-screen duel: no fog
      const tx = Math.floor(px / TILE),
        ty = Math.floor(py / TILE);
      return this.vis && this.vis[tx + "," + ty];
    }

    end(won, reason) {
      if (this.state !== "playing") return;
      this.state = won ? "won" : "lost";
      this.endReason = reason;
      if (won) Audio.win();
      else Audio.lose();
      if (this.onEnd) this.onEnd(won, reason);
    }

    // ----- render -------------------------------------------------------------
    render() {
      const ctx = this.ctx;
      ctx.save();
      if (this.shake > 0) {
        ctx.translate(
          rand(-this.shake, this.shake),
          rand(-this.shake, this.shake),
        );
      }

      ctx.fillStyle = "#0d0f12";
      ctx.fillRect(-20, -20, W + 40, H + 40);

      this.renderTiles(ctx);
      this.renderProps(ctx);
      this.renderBullets(ctx);

      if (this.twoPlayer) {
        for (const f of this.fighters) if (f.alive) this.renderFighter(ctx, f);
        this.renderParticles(ctx);
        this.renderFloaters(ctx);
        ctx.restore();
        this.renderDuelHUD(ctx);
        return;
      }

      this.renderCharges(ctx);
      this.renderEnemies(ctx);
      this.renderFighter(ctx, this.player);
      this.renderParticles(ctx);
      this.renderFog(ctx);
      // Objective beacons + the guide to them draw ON TOP of fog so the plant
      // sites are always findable across the whole map.
      this.renderGuide(ctx);
      this.renderObjectives(ctx);
      this.renderFloaters(ctx);
      this.renderWaypoint(ctx);
      this.renderThreat(ctx);

      ctx.restore();
      this.renderHUD(ctx);
    }

    renderTiles(ctx) {
      for (let ty = 0; ty < ROWS; ty++) {
        for (let tx = 0; tx < COLS; tx++) {
          const t = this.grid[ty][tx];
          const x = tx * TILE,
            y = ty * TILE;

          if (t === EXT) {
            ctx.fillStyle = (tx + ty) % 2 ? COL.ext : COL.extAlt;
            ctx.fillRect(x, y, TILE, TILE);
          } else if (t === FLOOR || t === RUBBLE) {
            // room-tinted floor with a checker sheen
            const base =
              t === RUBBLE ? COL.rubble : roomTint(tx, ty, this.vx, this.hy);
            ctx.fillStyle = base;
            ctx.fillRect(x, y, TILE, TILE);
            ctx.fillStyle =
              (tx + ty) % 2 ? "rgba(255,255,255,0.04)" : "rgba(0,0,0,0.10)";
            ctx.fillRect(x, y, TILE, TILE);
            if (t === RUBBLE) {
              ctx.fillStyle = "rgba(0,0,0,0.35)";
              ctx.fillRect(x + 5, y + 6, 5, 4);
              ctx.fillRect(x + 15, y + 13, 6, 5);
            }
          } else if (t === REINF) {
            ctx.fillStyle = COL.reinf;
            ctx.fillRect(x, y, TILE, TILE);
            ctx.strokeStyle = COL.reinfEdge;
            ctx.lineWidth = 2;
            ctx.strokeRect(x + 1.5, y + 1.5, TILE - 3, TILE - 3);
            ctx.fillStyle = COL.reinfRivet;
            for (const [rx, ry] of [
              [5, 5],
              [TILE - 5, 5],
              [5, TILE - 5],
              [TILE - 5, TILE - 5],
            ]) {
              ctx.beginPath();
              ctx.arc(x + rx, y + ry, 1.6, 0, Math.PI * 2);
              ctx.fill();
            }
          } else if (t === SOFT) {
            ctx.fillStyle = COL.wood;
            ctx.fillRect(x, y, TILE, TILE);
            // plank lines
            ctx.strokeStyle = COL.woodPlank;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x, y + TILE / 3);
            ctx.lineTo(x + TILE, y + TILE / 3);
            ctx.moveTo(x, y + (2 * TILE) / 3);
            ctx.lineTo(x + TILE, y + (2 * TILE) / 3);
            ctx.stroke();
            ctx.strokeStyle = COL.woodEdge;
            ctx.strokeRect(x + 0.5, y + 0.5, TILE - 1, TILE - 1);
            this.renderCracks(ctx, tx, ty, x, y, SOFT_HP);
          } else if (t === WINDOW) {
            ctx.fillStyle = COL.window;
            ctx.fillRect(x, y, TILE, TILE);
            ctx.strokeStyle = COL.windowEdge;
            ctx.lineWidth = 2;
            // criss-cross barricade planks
            ctx.beginPath();
            ctx.moveTo(x + 2, y + 5);
            ctx.lineTo(x + TILE - 2, y + 9);
            ctx.moveTo(x + 2, y + TILE - 9);
            ctx.lineTo(x + TILE - 2, y + TILE - 5);
            ctx.stroke();
            this.renderCracks(ctx, tx, ty, x, y, WINDOW_HP);
          }
        }
      }
    }

    renderCracks(ctx, tx, ty, x, y, max) {
      const hp = this.softHp[tx + "," + ty];
      if (hp === undefined) return;
      const frac = hp / max;
      ctx.strokeStyle = "rgba(0,0,0," + 0.6 * (1 - frac) + ")";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(x + 3, y + 3);
      ctx.lineTo(x + TILE - 5, y + TILE - 7);
      ctx.moveTo(x + TILE - 4, y + 5);
      ctx.lineTo(x + 6, y + TILE - 4);
      ctx.stroke();
    }

    renderProps(ctx) {
      for (const pr of this.props) {
        if (pr.dead) continue;
        if (!this.isVisible(pr.x, pr.y)) continue;
        const x = pr.x - pr.hw,
          y = pr.y - pr.hh,
          w = pr.hw * 2,
          h = pr.hh * 2;
        // shadow
        ctx.fillStyle = "rgba(0,0,0,0.35)";
        ctx.fillRect(x + 2, y + 3, w, h);
        if (pr.kind === "crate") {
          ctx.fillStyle = "#8a5a2e";
          ctx.fillRect(x, y, w, h);
          ctx.strokeStyle = "#5e3d1f";
          ctx.lineWidth = 2;
          ctx.strokeRect(x + 1, y + 1, w - 2, h - 2);
          ctx.beginPath();
          ctx.moveTo(x, y);
          ctx.lineTo(x + w, y + h);
          ctx.moveTo(x + w, y);
          ctx.lineTo(x, y + h);
          ctx.stroke();
        } else if (pr.kind === "table") {
          ctx.fillStyle = "#5a4636";
          ctx.fillRect(x, y, w, h);
          ctx.strokeStyle = "#3a2c22";
          ctx.lineWidth = 2;
          ctx.strokeRect(x + 1, y + 1, w - 2, h - 2);
          ctx.fillStyle = "#6f5844";
          ctx.fillRect(x + 3, y + 3, w - 6, h - 6);
        } else if (pr.kind === "locker") {
          ctx.fillStyle = "#5b6470";
          ctx.fillRect(x, y, w, h);
          ctx.strokeStyle = "#39414a";
          ctx.lineWidth = 2;
          ctx.strokeRect(x + 1, y + 1, w - 2, h - 2);
          ctx.beginPath();
          ctx.moveTo(pr.x, y + 2);
          ctx.lineTo(pr.x, y + h - 2);
          ctx.stroke();
        } else if (pr.kind === "barrel") {
          ctx.fillStyle = "#b8442e";
          ctx.beginPath();
          ctx.arc(pr.x, pr.y, pr.hw, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = "#7a2a1c";
          ctx.lineWidth = 2;
          ctx.stroke();
          ctx.strokeStyle = "#e0a090";
          ctx.beginPath();
          ctx.arc(pr.x, pr.y, pr.hw * 0.5, 0, Math.PI * 2);
          ctx.stroke();
        }
      }
    }

    // Bright, always-on-top bomb-site beacons so you can always see where to plant.
    renderObjectives(ctx) {
      const nearest = this.nearestSite();
      for (const o of this.objectives) {
        const armed = this.planted && this.plantedSite === o;
        const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 300);
        const c = armed ? "#ff3b30" : "#ffd25a";
        ctx.save();
        ctx.translate(o.x, o.y);
        // outer glow
        ctx.fillStyle =
          "rgba(255,210,90," + (armed ? 0.22 : 0.16) * (1 + pulse) + ")";
        ctx.beginPath();
        ctx.arc(0, 0, TILE * (0.7 + 0.22 * pulse), 0, Math.PI * 2);
        ctx.fill();
        // ring + rotating ticks
        ctx.strokeStyle = c;
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.arc(0, 0, TILE * 0.44, 0, Math.PI * 2);
        ctx.stroke();
        const spin = performance.now() / 900;
        ctx.beginPath();
        for (let a = 0; a < 4; a++) {
          const ang = (a * Math.PI) / 2 + spin;
          ctx.moveTo(Math.cos(ang) * TILE * 0.46, Math.sin(ang) * TILE * 0.46);
          ctx.lineTo(Math.cos(ang) * TILE * 0.6, Math.sin(ang) * TILE * 0.6);
        }
        ctx.stroke();
        // letter
        ctx.fillStyle = c;
        ctx.font = "bold 16px monospace";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(armed ? "⏱" : o.label, 0, -1);
        // tag under the site
        ctx.font = "bold 8px monospace";
        ctx.fillStyle = "rgba(0,0,0,0.55)";
        const tag = armed ? "ARMED" : "PLANT HERE";
        const tw = ctx.measureText(tag).width + 8;
        ctx.fillRect(-tw / 2, TILE * 0.6, tw, 11);
        ctx.fillStyle = c;
        ctx.fillText(tag, 0, TILE * 0.6 + 6);
        // highlight the nearest un-armed site
        if (!this.planted && o === nearest) {
          ctx.strokeStyle = "rgba(255,255,255,0.5)";
          ctx.lineWidth = 1;
          ctx.setLineDash([3, 3]);
          ctx.beginPath();
          ctx.arc(0, 0, TILE * 0.66, 0, Math.PI * 2);
          ctx.stroke();
          ctx.setLineDash([]);
        }
        ctx.restore();
      }
    }

    nearestSite() {
      const p = this.player;
      let best = null,
        bd = Infinity;
      for (const o of this.objectives) {
        const d = dist2(p.x, p.y, o.x, o.y);
        if (d < bd) {
          bd = d;
          best = o;
        }
      }
      return best;
    }

    // Faint gold guide line from the player to the nearest un-armed site.
    renderGuide(ctx) {
      if (this.planted) return;
      const site = this.nearestSite();
      if (!site) return;
      const p = this.player;
      ctx.save();
      ctx.strokeStyle = "rgba(255,210,90,0.28)";
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 10]);
      ctx.lineDashOffset = -(performance.now() / 60) % 16;
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(site.x, site.y);
      ctx.stroke();
      ctx.restore();
    }

    renderCharges(ctx) {
      for (const c of this.charges) {
        if (c.projectile) {
          ctx.fillStyle = "#ffb347";
          ctx.beginPath();
          ctx.arc(c.x, c.y, 4, 0, Math.PI * 2);
          ctx.fill();
        } else {
          const x = c.tx * TILE,
            y = c.ty * TILE;
          const blink = Math.sin(performance.now() / 80) > 0;
          ctx.fillStyle = blink ? "#ff3b30" : "#661010";
          ctx.fillRect(x + TILE / 2 - 4, y + TILE / 2 - 4, 8, 8);
          ctx.strokeStyle = "#ff8866";
          ctx.strokeRect(x + 2, y + 2, TILE - 4, TILE - 4);
        }
      }
    }

    // Detailed top-down operator sprite.
    drawFighter(
      ctx,
      x,
      y,
      angle,
      bodyColor,
      vestColor,
      radius,
      moving,
      legPhase,
    ) {
      ctx.save();
      ctx.translate(x, y);
      // shadow
      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.beginPath();
      ctx.ellipse(
        0,
        radius * 0.5,
        radius * 1.05,
        radius * 0.7,
        0,
        0,
        Math.PI * 2,
      );
      ctx.fill();
      ctx.rotate(angle);

      // legs (subtle walk bob)
      const legOff = moving ? Math.sin(legPhase || 0) * radius * 0.35 : 0;
      ctx.fillStyle = "#2a2d33";
      ctx.fillRect(
        -radius * 0.15,
        -radius * 0.7 + legOff,
        radius * 0.3,
        radius * 0.5,
      );
      ctx.fillRect(
        -radius * 0.15,
        radius * 0.2 - legOff,
        radius * 0.3,
        radius * 0.5,
      );

      // body / vest
      ctx.fillStyle = vestColor;
      ctx.beginPath();
      ctx.arc(0, 0, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = bodyColor;
      ctx.beginPath();
      ctx.arc(0, 0, radius * 0.72, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,0.45)";
      ctx.lineWidth = 2;
      ctx.stroke();

      // arms holding the gun
      ctx.fillStyle = vestColor;
      ctx.fillRect(radius * 0.2, -radius * 0.55, radius * 0.5, radius * 0.3);
      ctx.fillRect(radius * 0.2, radius * 0.25, radius * 0.5, radius * 0.3);

      // gun
      ctx.fillStyle = "#15171b";
      ctx.fillRect(radius * 0.5, -radius * 0.14, radius * 1.15, radius * 0.28);
      ctx.fillStyle = "#2b2f36";
      ctx.fillRect(radius * 0.5, -radius * 0.14, radius * 0.3, radius * 0.28);

      // head
      ctx.fillStyle = "#c9a27a";
      ctx.beginPath();
      ctx.arc(radius * 0.18, 0, radius * 0.34, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = bodyColor;
      ctx.beginPath();
      ctx.arc(radius * 0.05, 0, radius * 0.3, -Math.PI / 2, Math.PI / 2);
      ctx.fill();

      ctx.restore();
    }

    renderEnemies(ctx) {
      for (const e of this.enemies) {
        const shown = this.isVisible(e.x, e.y) || e.revealTimer > 0;
        if (!shown) continue;
        this.drawFighter(
          ctx,
          e.x,
          e.y,
          e.angle,
          "#d64545",
          "#3a1414",
          e.radius,
          true,
          e.x + performance.now() / 120,
        );
        if (e.muzzle > 0) {
          ctx.fillStyle = "#ffd25a";
          ctx.beginPath();
          ctx.arc(
            e.x + Math.cos(e.angle) * 18,
            e.y + Math.sin(e.angle) * 18,
            5,
            0,
            Math.PI * 2,
          );
          ctx.fill();
        }
        const w = 22;
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(e.x - w / 2, e.y - e.radius - 11, w, 4);
        ctx.fillStyle = "#e5533c";
        ctx.fillRect(e.x - w / 2, e.y - e.radius - 11, w * (e.hp / 100), 4);
      }
    }

    renderBullets(ctx) {
      for (const b of this.bullets) {
        ctx.strokeStyle = b.friendly ? "#ffe08a" : "#ff6b5a";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(b.x, b.y);
        ctx.lineTo(b.x - b.vx * 0.012, b.y - b.vy * 0.012);
        ctx.stroke();
      }
    }

    renderFighter(ctx, p) {
      const c = p.controls;
      const moving = !!(
        this.keys[c.up] ||
        this.keys[c.down] ||
        this.keys[c.left] ||
        this.keys[c.right] ||
        (p.aimMode === "mouse" && (Input.moveX || Input.moveY))
      );
      this.drawFighter(
        ctx,
        p.x,
        p.y,
        p.angle,
        p.color,
        p.vest,
        p.radius,
        moving,
        p.legPhase,
      );

      ctx.strokeStyle = "rgba(255,255,255,0.16)";
      ctx.setLineDash([4, 6]);
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(p.x + Math.cos(p.angle) * 70, p.y + Math.sin(p.angle) * 70);
      ctx.stroke();
      ctx.setLineDash([]);

      // In the duel, tag each fighter with its player number so they're easy to tell apart.
      if (this.twoPlayer) {
        ctx.fillStyle = p.color;
        ctx.font = "bold 11px monospace";
        ctx.textAlign = "center";
        ctx.fillText("P" + (p.team + 1), p.x, p.y - p.radius - 8);
        const w = 26;
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(p.x - w / 2, p.y - p.radius - 6, w, 4);
        ctx.fillStyle = p.color;
        ctx.fillRect(p.x - w / 2, p.y - p.radius - 6, w * (p.hp / p.maxHp), 4);
      }

      if (p.shieldUp) {
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.angle);
        ctx.fillStyle = "rgba(106,208,106,0.30)";
        ctx.strokeStyle = "#6ad06a";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(p.radius + 4, 0, p.radius + 8, -1.1, 1.1);
        ctx.stroke();
        ctx.restore();
      }
    }

    renderParticles(ctx) {
      for (const pt of this.particles) {
        ctx.globalAlpha = clamp(pt.life / pt.max, 0, 1);
        ctx.fillStyle = pt.color;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, pt.r, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }

    renderFloaters(ctx) {
      for (const f of this.floaters) {
        ctx.globalAlpha = clamp(f.t, 0, 1);
        ctx.fillStyle = f.color;
        ctx.font = "bold 18px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(f.text, f.x, f.y);
      }
      ctx.globalAlpha = 1;
    }

    renderFog(ctx) {
      for (let ty = 0; ty < ROWS; ty++) {
        for (let tx = 0; tx < COLS; tx++) {
          if (!this.vis || !this.vis[tx + "," + ty]) {
            ctx.fillStyle = "rgba(6,7,9,0.55)";
            ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
          }
        }
      }
    }

    // A chevron near the player pointing toward the nearest un-armed bomb site.
    renderWaypoint(ctx) {
      if (this.planted) return;
      const p = this.player;
      const best = this.nearestSite();
      if (!best || this._onSite) return; // hide arrow once you're on the site
      const ang = Math.atan2(best.y - p.y, best.x - p.x);
      const r = p.radius + 28;
      const cx = p.x + Math.cos(ang) * r,
        cy = p.y + Math.sin(ang) * r;

      // arrow head
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(ang);
      ctx.fillStyle = "rgba(255,210,90,0.95)";
      ctx.beginPath();
      ctx.moveTo(11, 0);
      ctx.lineTo(-4, -7);
      ctx.lineTo(-4, 7);
      ctx.closePath();
      ctx.fill();
      ctx.restore();

      // label: "SITE A · 12m", kept upright and offset just past the arrow
      const dist = Math.round(
        Math.sqrt(dist2(p.x, p.y, best.x, best.y)) / TILE,
      );
      const label = "SITE " + best.label + " · " + dist + "m";
      const lx = p.x + Math.cos(ang) * (r + 16);
      const ly = p.y + Math.sin(ang) * (r + 16);
      ctx.font = "bold 11px monospace";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      const tw = ctx.measureText(label).width + 10;
      ctx.fillStyle = "rgba(0,0,0,0.6)";
      ctx.fillRect(lx - tw / 2, ly - 8, tw, 16);
      ctx.fillStyle = "#ffd25a";
      ctx.fillText(label, lx, ly);
    }

    // Red chevron pointing to the nearest defender that currently has eyes on
    // you — so you know where incoming fire is coming from and can fight back.
    renderThreat(ctx) {
      const p = this.player;
      let threat = null,
        bd = Infinity;
      for (const e of this.enemies) {
        if (!e.canSee) continue;
        const d = dist2(e.x, e.y, p.x, p.y);
        if (d < bd) {
          bd = d;
          threat = e;
        }
      }
      if (!threat) return;
      const ang = Math.atan2(threat.y - p.y, threat.x - p.x);
      const r = p.radius + 40;
      const pulse = 0.6 + 0.4 * Math.sin(performance.now() / 120);
      ctx.save();
      ctx.translate(p.x + Math.cos(ang) * r, p.y + Math.sin(ang) * r);
      ctx.rotate(ang);
      ctx.fillStyle = "rgba(255,60,50," + pulse + ")";
      ctx.beginPath();
      ctx.moveTo(9, 0);
      ctx.lineTo(-3, -6);
      ctx.lineTo(-3, 6);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    // Canvas HUD for the local 1v1 duel: a health/ammo panel for each player.
    renderDuelHUD(ctx) {
      const panel = (f, x, align) => {
        const barW = 150;
        const bx = align === "right" ? x - barW : x;
        ctx.textAlign = align === "right" ? "right" : "left";
        ctx.font = "bold 12px monospace";
        ctx.fillStyle = f.color;
        ctx.fillText(f.name, x, 22);
        // health bar
        ctx.fillStyle = "rgba(0,0,0,0.55)";
        ctx.fillRect(bx, 28, barW, 12);
        ctx.fillStyle = f.alive ? f.color : "#555";
        ctx.fillRect(bx, 28, barW * clamp(f.hp / f.maxHp, 0, 1), 12);
        ctx.strokeStyle = "rgba(255,255,255,0.25)";
        ctx.lineWidth = 1;
        ctx.strokeRect(bx + 0.5, 28.5, barW - 1, 11);
        ctx.fillStyle = "#cfd6dd";
        ctx.font = "11px monospace";
        const ammo = f.reloading
          ? "RELOADING"
          : f.ammo + " / " + f.op.weapon.mag;
        ctx.fillText(ammo + "   HP " + Math.max(0, Math.ceil(f.hp)), x, 54);
      };
      panel(this.player, 16, "left");
      panel(this.player2, W - 46, "right"); // clear of the ? help button

      // round timer, centered
      const s = Math.ceil(this.time);
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(0,0,0,0.55)";
      ctx.fillRect(W / 2 - 34, 12, 68, 26);
      ctx.fillStyle = "#e8ebf0";
      ctx.font = "bold 16px monospace";
      ctx.fillText("0:" + (s < 10 ? "0" : "") + s, W / 2, 30);
    }

    renderHUD(ctx) {
      const p = this.player;

      // Plant prompt + progress when standing on a site.
      if (this._onSite && !this.planted) {
        const o = this._onSite;
        const frac = clamp(this.plantProgress / 3, 0, 1);
        ctx.save();
        ctx.translate(o.x, o.y - 34);
        ctx.strokeStyle = "rgba(0,0,0,0.7)";
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.arc(0, 0, 15, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = "#ffd25a";
        ctx.beginPath();
        ctx.arc(0, 0, 15, -Math.PI / 2, -Math.PI / 2 + frac * Math.PI * 2);
        ctx.stroke();
        ctx.restore();
        ctx.fillStyle = "rgba(0,0,0,0.7)";
        ctx.fillRect(W / 2 - 160, H - 70, 320, 30);
        ctx.fillStyle = "#ffd25a";
        ctx.font = "bold 15px monospace";
        ctx.textAlign = "center";
        ctx.fillText(
          frac > 0 ? "PLANTING… hold [F]" : "Hold [F] to plant the defuser",
          W / 2,
          H - 50,
        );
      }

      // flash message
      if (this.msgT > 0 && this.msg) {
        ctx.globalAlpha = clamp(this.msgT, 0, 1);
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(W / 2 - 160, 12, 320, 30);
        ctx.fillStyle = "#ffd25a";
        ctx.font = "bold 15px monospace";
        ctx.textAlign = "center";
        ctx.fillText(this.msg, W / 2, 32);
        ctx.globalAlpha = 1;
      }

      // DOM HUD sync
      const setW = (id, frac, color) => {
        const el = document.getElementById(id);
        if (el) {
          el.style.width = clamp(frac * 100, 0, 100) + "%";
          if (color) el.style.background = color;
        }
      };
      const setT = (id, txt) => {
        const el = document.getElementById(id);
        if (el) el.textContent = txt;
      };
      setW(
        "hp-fill",
        p.hp / p.maxHp,
        p.hp / p.maxHp < 0.3 ? "#e5533c" : "#6ad06a",
      );
      setT("hp-num", Math.max(0, Math.ceil(p.hp)));
      setT(
        "ammo-num",
        p.reloading ? "RELOADING" : p.ammo + " / " + this.op.weapon.mag,
      );
      setT("enemies-num", this.enemies.length);
      if (this.planted) {
        setT("timer-num", "ARMED " + Math.ceil(this.armTimer) + "s");
        const el = document.getElementById("timer-num");
        if (el) el.style.color = "#ff5c4d";
      } else {
        const m = Math.floor(this.time / 60),
          s = Math.floor(this.time % 60);
        setT("timer-num", m + ":" + (s < 10 ? "0" : "") + s);
      }
      const uses = this.op.gadgetUses === Infinity ? "∞" : p.gadgetUses;
      setT("gadget-num", this.op.gadgetLabel + " (" + uses + ")");
    }
  }

  // ---------------------------------------------------------------------------
  // Boot / UI wiring
  // ---------------------------------------------------------------------------
  const canvas = document.getElementById("game");
  canvas.width = W;
  canvas.height = H;

  let game = null;
  let raf = null;

  function show(id) {
    document
      .querySelectorAll(".screen")
      .forEach((s) => s.classList.add("hidden"));
    if (id) {
      document.getElementById(id).classList.remove("hidden");
      document.body.classList.remove("playing");
    } else {
      // show(null) is only used when a round starts — enable in-game overlays.
      document.body.classList.add("playing");
    }
  }

  function loop(now) {
    const dt = Math.min(0.05, (now - game.last) / 1000);
    game.last = now;
    game.update(dt);
    game.render();
    if (game.state === "playing") {
      raf = requestAnimationFrame(loop);
    } else if (game.twoPlayer) {
      showEndDuel(game.duelWinner);
    } else {
      showEnd(game.state === "won", game.endReason);
    }
  }

  function resetInput() {
    Input.moveX = 0;
    Input.moveY = 0;
    Input.aiming = false;
    Input.fire = false;
  }

  function startGame(opKey) {
    if (game) game.destroy();
    if (raf) cancelAnimationFrame(raf);
    resetInput();
    Audio.resume();
    game = new Game(canvas, opKey);
    show(null);
    document.getElementById("hud").classList.remove("hidden");
    document.getElementById("op-name").textContent =
      OPERATORS[opKey].name + " · " + OPERATORS[opKey].role;
    const tn = document.getElementById("timer-num");
    if (tn) tn.style.color = "";
    game.last = performance.now();
    window.SIEGE_GAME = game; // debug handle (harmless)
    raf = requestAnimationFrame(loop);
  }

  function showEnd(won, reason) {
    resetInput();
    document.getElementById("hud").classList.add("hidden");
    const el = document.getElementById("end");
    el.classList.remove("hidden");
    document.getElementById("end-title").textContent = won
      ? "MISSION COMPLETE"
      : "MISSION FAILED";
    document.getElementById("end-title").style.color = won
      ? "#6ad06a"
      : "#e5533c";
    document.getElementById("end-reason").textContent = reason || "";
  }

  function startDuel() {
    if (game) game.destroy();
    if (raf) cancelAnimationFrame(raf);
    resetInput();
    Audio.resume();
    game = new Game(canvas, null, { mode: "duel" });
    show(null);
    document.getElementById("hud").classList.add("hidden"); // duel draws its own HUD
    game.last = performance.now();
    window.SIEGE_GAME = game;
    raf = requestAnimationFrame(loop);
  }

  function showEndDuel(winner) {
    resetInput();
    document.getElementById("hud").classList.add("hidden");
    const el = document.getElementById("end");
    el.classList.remove("hidden");
    const title = document.getElementById("end-title");
    if (winner) {
      title.textContent = "PLAYER " + (winner.team + 1) + " WINS";
      title.style.color = winner.color;
    } else {
      title.textContent = "DRAW";
      title.style.color = "#8b93a1";
    }
    document.getElementById("end-reason").textContent =
      winner && winner.team === 0
        ? "Attacker takes the round."
        : winner && winner.team === 1
          ? "Defender holds the round."
          : "Both operators down — nobody wins.";
  }

  const opList = document.getElementById("op-list");
  Object.entries(OPERATORS).forEach(([key, op]) => {
    const card = document.createElement("button");
    card.className = "op-card";
    card.style.setProperty("--accent", op.color);
    card.innerHTML =
      '<div class="op-badge" style="background:' +
      op.color +
      '">' +
      op.name[0] +
      "</div>" +
      '<div class="op-info"><div class="op-title">' +
      op.name +
      ' <span class="op-role">' +
      op.role +
      "</span></div>" +
      '<div class="op-blurb">' +
      op.blurb +
      "</div>" +
      '<div class="op-stats">❤ ' +
      op.hp +
      " · 🔫 " +
      op.weapon.name +
      " · 🧰 " +
      op.gadgetLabel +
      "</div></div>";
    card.addEventListener("click", () => startGame(key));
    opList.appendChild(card);
  });

  document
    .getElementById("btn-replay")
    .addEventListener("click", () => show("menu"));
  document
    .getElementById("btn-start")
    .addEventListener("click", () => show("select"));
  document
    .getElementById("btn-back")
    .addEventListener("click", () => show("menu"));
  const btnDuel = document.getElementById("btn-duel");
  if (btnDuel) btnDuel.addEventListener("click", () => startDuel());

  // ---------------------------------------------------------------------------
  // Help overlay (works on desktop and mobile)
  // ---------------------------------------------------------------------------
  const helpBtn = document.getElementById("btn-help");
  const helpScreen = document.getElementById("help");
  const helpClose = document.getElementById("btn-help-close");
  if (helpBtn)
    helpBtn.addEventListener("click", () =>
      helpScreen.classList.remove("hidden"),
    );
  if (helpClose)
    helpClose.addEventListener("click", () =>
      helpScreen.classList.add("hidden"),
    );
  window.addEventListener("keydown", (e) => {
    const k = e.key.toLowerCase();
    if (k === "h") helpScreen.classList.toggle("hidden");
    if (k === "escape") helpScreen.classList.add("hidden");
  });

  // ---------------------------------------------------------------------------
  // Touch controls — twin-stick: left stick moves, right stick aims & fires,
  // plus RELOAD / GADGET / ACTION buttons. Shown only on touch devices.
  // ---------------------------------------------------------------------------
  function setupTouch() {
    const coarse =
      window.matchMedia && window.matchMedia("(pointer: coarse)").matches;
    const isTouch =
      coarse || "ontouchstart" in window || navigator.maxTouchPoints > 0;
    if (!isTouch) return;
    document.body.classList.add("touch");

    const stick = (baseId, thumbId, onVec) => {
      const base = document.getElementById(baseId);
      const thumb = document.getElementById(thumbId);
      if (!base) return;
      let id = null,
        cx = 0,
        cy = 0;
      const R = 46;
      const start = (t) => {
        id = t.identifier;
        const r = base.getBoundingClientRect();
        cx = r.left + r.width / 2;
        cy = r.top + r.height / 2;
        move(t);
      };
      const move = (t) => {
        let dx = t.clientX - cx,
          dy = t.clientY - cy;
        const mag = Math.hypot(dx, dy) || 1;
        const cl = Math.min(mag, R);
        const nx = (dx / mag) * cl,
          ny = (dy / mag) * cl;
        thumb.style.transform = `translate(${nx}px, ${ny}px)`;
        onVec(dx / R, dy / R, mag); // may exceed 1; consumer clamps
      };
      const end = () => {
        id = null;
        thumb.style.transform = "translate(0,0)";
        onVec(0, 0, 0);
      };
      base.addEventListener(
        "touchstart",
        (e) => {
          e.preventDefault();
          Audio.resume();
          start(e.changedTouches[0]);
        },
        { passive: false },
      );
      base.addEventListener(
        "touchmove",
        (e) => {
          e.preventDefault();
          for (const t of e.changedTouches) if (t.identifier === id) move(t);
        },
        { passive: false },
      );
      const onEnd = (e) => {
        for (const t of e.changedTouches) if (t.identifier === id) end();
      };
      base.addEventListener("touchend", onEnd);
      base.addEventListener("touchcancel", onEnd);
    };

    // left stick → analog movement
    stick("stick-move", "stick-move-thumb", (x, y) => {
      const mag = Math.hypot(x, y);
      Input.moveX = mag > 1 ? x / mag : x;
      Input.moveY = mag > 1 ? y / mag : y;
    });
    // right stick → aim + auto-fire (only fires past a small deadzone)
    stick("stick-aim", "stick-aim-thumb", (x, y, mag) => {
      if (mag > 8) {
        Input.aiming = true;
        Input.aimAngle = Math.atan2(y, x);
        Input.fire = true;
      } else {
        Input.aiming = false;
        Input.fire = false;
      }
    });

    const tapBtn = (id, fn) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.addEventListener(
        "touchstart",
        (e) => {
          e.preventDefault();
          Audio.resume();
          if (window.SIEGE_GAME) fn(window.SIEGE_GAME);
          el.classList.add("pressed");
        },
        { passive: false },
      );
      el.addEventListener("touchend", () => el.classList.remove("pressed"));
    };
    tapBtn("tb-reload", (g) => g.startReload());
    tapBtn("tb-gadget", (g) => g.useGadget());
    // ACTION: hold to plant when on a site, tap to melee-breach otherwise.
    const act = document.getElementById("tb-action");
    if (act) {
      act.addEventListener(
        "touchstart",
        (e) => {
          e.preventDefault();
          Audio.resume();
          const g = window.SIEGE_GAME;
          if (!g) return;
          g.keys["f"] = true; // held → planting works in update()
          g.interactEdge(); // edge → melee breach when not on a site
          act.classList.add("pressed");
        },
        { passive: false },
      );
      const release = () => {
        const g = window.SIEGE_GAME;
        if (g) g.keys["f"] = false;
        act.classList.remove("pressed");
      };
      act.addEventListener("touchend", release);
      act.addEventListener("touchcancel", release);
    }
  }
  setupTouch();

  show("menu");
})();
