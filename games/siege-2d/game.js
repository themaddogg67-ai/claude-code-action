/*
 * SIEGE 2D — a top-down tactical shooter inspired by Rainbow Six Siege.
 *
 * You play the attacker breaching a building held by AI defenders. Core Siege
 * ideas translated to 2D: reinforced vs destructible walls, breaching gadgets,
 * line-of-sight fog of war, and an objective to secure. Eliminate every
 * defender or defuse the objective before the timer runs out.
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
  const SOFT = 3; // soft wall (destructible, blocks move + sight)
  const RUBBLE = 4; // breached wall (passable, no sight/bullet block)
  const WINDOW = 5; // barricade (blocks move, allows sight/bullets, breakable)

  const SOFT_HP = 100;
  const WINDOW_HP = 45;

  // ---------------------------------------------------------------------------
  // Operators
  // ---------------------------------------------------------------------------
  const OPERATORS = {
    sledge: {
      name: "Sledge",
      role: "Breacher",
      color: "#f2b134",
      hp: 130,
      speed: 145,
      blurb: "Tanky. Breaching hammer smashes adjacent soft walls instantly.",
      gadget: "hammer",
      gadgetLabel: "Breach Hammer",
      gadgetUses: 6,
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
      hp: 100,
      speed: 185,
      blurb:
        "Fast and aggressive. Breaching rounds destroy soft walls at range.",
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

    // Interior vertical soft divider with two door gaps
    const vx = 18;
    for (let y = by0 + 1; y < by1; y++) grid[y][vx] = SOFT;
    grid[by0 + 3][vx] = FLOOR;
    grid[by0 + 12][vx] = FLOOR;

    // Interior horizontal soft divider with two door gaps
    const hy = 11;
    for (let x = bx0 + 1; x < bx1; x++)
      if (grid[hy][x] === FLOOR) grid[hy][x] = SOFT;
    grid[hy][9] = FLOOR;
    grid[hy][25] = FLOOR;

    // A reinforced strongroom (only Thermite can breach the reinforced sides).
    // Leave one soft-wall door so defenders/other operators can still enter.
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
    grid[ry1][rx0 + 2] = SOFT; // soft doorway into the strongroom

    // Candidate interior floor tiles for spawns/objectives
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

    // One objective inside the reinforced strongroom, one elsewhere.
    const objectives = [];
    objectives.push(centerPx({ x: 26, y: 16 }));
    const farFloors = floors.filter(
      (t) =>
        dist2(t.x * TILE, t.y * TILE, playerSpawn.x, playerSpawn.y) >
        (14 * TILE) ** 2,
    );
    const obj2 = farFloors[Math.floor(Math.random() * farFloors.length)];
    objectives.push(centerPx(obj2));

    // Enemy spawns: interior tiles reasonably far from the player entrance.
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

    return { grid, playerSpawn, enemySpawns, objectives };
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
    constructor(x, y, ang, speed, damage, range, friendly) {
      this.x = x;
      this.y = y;
      this.vx = Math.cos(ang) * speed;
      this.vy = Math.sin(ang) * speed;
      this.damage = damage;
      this.range = range;
      this.traveled = 0;
      this.friendly = friendly;
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
      this.state = "patrol"; // patrol | alert | engage
      this.target = null; // last known player pos
      this.fireCd = rand(300, 900);
      this.alertTimer = 0;
      this.wander = { x, y, t: 0 };
      this.revealTimer = 0; // stays visible briefly after last seen
      this.muzzle = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Game
  // ---------------------------------------------------------------------------
  class Game {
    constructor(canvas, opKey) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.op = OPERATORS[opKey];
      this.reset();
      this.bindInput();
    }

    reset() {
      const map = generateMap();
      this.grid = map.grid;
      this.objectives = map.objectives.map((o) => ({
        ...o,
        radius: TILE * 0.5,
        defused: false,
      }));
      this.softHp = {}; // "x,y" -> remaining hp for SOFT/WINDOW tiles

      const op = this.op;
      this.player = {
        x: map.playerSpawn.x,
        y: map.playerSpawn.y,
        radius: TILE * 0.34,
        hp: op.hp,
        maxHp: op.hp,
        angle: 0,
        speed: op.speed,
        ammo: op.weapon.mag,
        mag: op.weapon.mag,
        reloading: false,
        reloadEnd: 0,
        fireReady: 0,
        gadgetUses: op.gadgetUses,
        shieldUp: false,
      };

      this.enemies = map.enemySpawns.map((s) => new Enemy(s.x, s.y));
      this.bullets = [];
      this.particles = [];
      this.floaters = []; // floating text
      this.charges = []; // thermite/ash timed breaches

      this.time = 120; // seconds remaining
      this.state = "playing"; // playing | won | lost
      this.shake = 0;
      this.defuseProgress = 0;
      this.vis = null; // visibility grid, recomputed each frame
      this.msg = "";
      this.msgT = 0;
      this.last = performance.now();
    }

    // ----- input --------------------------------------------------------------
    bindInput() {
      this.keys = {};
      this.mouse = { x: W / 2, y: H / 2, down: false };

      this._kd = (e) => {
        this.keys[e.key.toLowerCase()] = true;
        if (["r", "e", " "].includes(e.key.toLowerCase())) e.preventDefault();
        if (e.key.toLowerCase() === "r") this.startReload();
        if (e.key.toLowerCase() === "e") this.useGadget();
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
        this.spawnDebris(tx * TILE + TILE / 2, ty * TILE + TILE / 2, "#8a7a5a");
      }
    }

    breachTile(tx, ty) {
      if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return false;
      const t = this.grid[ty][tx];
      if (t === SOFT || t === WINDOW) {
        this.grid[ty][tx] = RUBBLE;
        this.spawnDebris(tx * TILE + TILE / 2, ty * TILE + TILE / 2, "#8a7a5a");
        return true;
      }
      return false;
    }

    // Thermite can turn a REINF wall into rubble; others cannot.
    breachReinforced(tx, ty) {
      if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return false;
      if (this.grid[ty][tx] === REINF) {
        this.grid[ty][tx] = RUBBLE;
        this.spawnDebris(tx * TILE + TILE / 2, ty * TILE + TILE / 2, "#c0c0c0");
        return true;
      }
      return false;
    }

    // ----- combat -------------------------------------------------------------
    startReload() {
      const p = this.player;
      if (p.reloading || p.ammo === this.op.weapon.mag) return;
      p.reloading = true;
      p.reloadEnd = performance.now() + this.op.weapon.reload;
      Audio.reload();
    }

    shoot() {
      const p = this.player;
      const now = performance.now();
      if (p.reloading || p.shieldUp) return;
      if (now < p.fireReady || p.ammo <= 0) {
        if (p.ammo <= 0) this.startReload();
        return;
      }
      const wpn = this.op.weapon;
      p.fireReady = now + wpn.fireInterval;
      p.ammo--;
      for (let i = 0; i < wpn.pellets; i++) {
        const a = p.angle + rand(-wpn.spread, wpn.spread);
        this.bullets.push(
          new Bullet(
            p.x + Math.cos(p.angle) * p.radius,
            p.y + Math.sin(p.angle) * p.radius,
            a,
            760,
            wpn.damage,
            wpn.range,
            true,
          ),
        );
      }
      this.spawnMuzzle(p.x, p.y, p.angle, this.op.color);
      this.shake = Math.min(this.shake + (wpn.pellets > 1 ? 6 : 2.5), 12);
      Audio.shoot();
      // Gunfire alerts nearby defenders.
      for (const e of this.enemies) {
        if (
          dist2(e.x, e.y, p.x, p.y) < (9 * TILE) ** 2 &&
          e.state === "patrol"
        ) {
          e.state = "alert";
          e.target = { x: p.x, y: p.y };
          e.alertTimer = 4;
        }
      }
    }

    useGadget() {
      const p = this.player;
      const g = this.op.gadget;

      if (g === "shield") {
        // toggled/held elsewhere; E flips lock
        p.shieldUp = !p.shieldUp;
        this.flash(p.shieldUp ? "Shield UP" : "Shield DOWN");
        return;
      }

      if (p.gadgetUses <= 0) {
        this.flash("No gadget charges left");
        return;
      }

      const fx = p.x + Math.cos(p.angle) * TILE;
      const fy = p.y + Math.sin(p.angle) * TILE;
      const tx = Math.floor(fx / TILE),
        ty = Math.floor(fy / TILE);

      if (g === "hammer") {
        // Instant melee breach of the adjacent soft wall / window.
        if (this.breachTile(tx, ty)) {
          p.gadgetUses--;
          this.shake = 10;
          Audio.breach();
          this.flash("SMASH! Wall breached");
        } else {
          this.flash("No soft wall in front");
        }
      } else if (g === "charge") {
        // Thermite: place an exothermic charge that burns through ANY wall.
        const t = this.grid[ty][tx];
        if (t === REINF || t === SOFT || t === WINDOW) {
          p.gadgetUses--;
          this.charges.push({ tx, ty, t: 1.4, reinforced: t === REINF });
          this.flash("Charge placed — stand clear");
        } else {
          this.flash("Aim at a wall to place charge");
        }
      } else if (g === "grenade") {
        // Ash: fire a breaching round that destroys soft walls in a small radius.
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
          color: "#ffd25a",
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
      // Axis-separated collision against solid tiles.
      const r = ent.radius;
      // X axis
      let tx = ent.x;
      if (!this.solidAround(nx, ent.y, r)) tx = nx;
      // Y axis
      let ty = ent.y;
      if (!this.solidAround(tx, ny, r)) ty = ny;
      ent.x = clamp(tx, r, W - r);
      ent.y = clamp(ty, r, H - r);
    }

    solidAround(px, py, r) {
      // Sample the four cardinal edges of the entity circle.
      const pts = [
        [px - r, py],
        [px + r, py],
        [px, py - r],
        [px, py + r],
      ];
      for (const [x, y] of pts)
        if (blocksMove(tileAt(this.grid, x, y))) return true;
      return false;
    }

    // ----- update -------------------------------------------------------------
    update(dt) {
      if (this.state !== "playing") return;
      this.time -= dt;
      if (this.time <= 0) {
        this.time = 0;
        return this.end(false, "Time's up — objective held.");
      }
      if (this.msgT > 0) this.msgT -= dt;
      if (this.shake > 0) this.shake = Math.max(0, this.shake - dt * 40);

      this.updatePlayer(dt);
      this.updateEnemies(dt);
      this.updateBullets(dt);
      this.updateCharges(dt);
      this.updateParticles(dt);
      this.updateObjectives(dt);
      this.computeVisibility();

      if (this.enemies.length === 0)
        this.end(true, "All defenders eliminated.");
      if (this.player.hp <= 0) this.end(false, "You were killed.");
    }

    updatePlayer(dt) {
      const p = this.player;
      p.angle = Math.atan2(this.mouse.y - p.y, this.mouse.x - p.x);

      // Shield operator: holding right context — shield lock via E, held slows.
      const shielded = p.shieldUp;
      let sp = p.speed * (shielded ? 0.55 : 1);

      let dx = 0,
        dy = 0;
      if (this.keys["w"]) dy -= 1;
      if (this.keys["s"]) dy += 1;
      if (this.keys["a"]) dx -= 1;
      if (this.keys["d"]) dx += 1;
      if (dx || dy) {
        const l = Math.hypot(dx, dy);
        this.moveCircle(p, p.x + (dx / l) * sp * dt, p.y + (dy / l) * sp * dt);
      }

      if (p.reloading && performance.now() >= p.reloadEnd) {
        p.reloading = false;
        p.ammo = this.op.weapon.mag;
      }
      if (this.mouse.down) this.shoot();
    }

    updateEnemies(dt) {
      const p = this.player;
      for (const e of this.enemies) {
        const canSee =
          dist2(e.x, e.y, p.x, p.y) < (11 * TILE) ** 2 &&
          losClear(this.grid, e.x, e.y, p.x, p.y);

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
          // Keep at a fighting distance; strafe a little.
          const d = Math.hypot(p.x - e.x, p.y - e.y);
          const want = 5 * TILE;
          let mvx = 0,
            mvy = 0;
          const toward = d > want ? 1 : d < want - TILE ? -1 : 0;
          mvx += Math.cos(e.angle) * toward;
          mvy += Math.sin(e.angle) * toward;
          // strafe perpendicular
          const strafe = Math.sin(performance.now() / 500 + e.x) * 0.6;
          mvx += Math.cos(e.angle + Math.PI / 2) * strafe;
          mvy += Math.sin(e.angle + Math.PI / 2) * strafe;
          const l = Math.hypot(mvx, mvy) || 1;
          this.moveCircle(
            e,
            e.x + (mvx / l) * e.speed * dt,
            e.y + (mvy / l) * e.speed * dt,
          );

          // Fire
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
          // Move toward last known position, then resume patrol.
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
          // Patrol: lazy random wander around spawn.
          e.wander.t -= dt;
          if (e.wander.t <= 0) {
            e.wander.t = rand(1.5, 3.5);
            e.wander.a = rand(0, Math.PI * 2);
          }
          const a = e.wander.a || 0;
          e.angle = angLerp(e.angle, a, 0.05);
          this.moveCircle(
            e,
            e.x + Math.cos(a) * e.speed * 0.4 * dt,
            e.y + Math.sin(a) * e.speed * 0.4 * dt,
          );
        }
        if (e.muzzle > 0) e.muzzle -= dt;
      }
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
            this.spawnDebris(b.x, b.y, "#9aa0a6");
          } else if (t === SOFT || t === WINDOW) {
            this.damageTile(tx, ty, b.damage * 0.9);
            b.dead = true;
          }
          if (b.dead) break;

          // Entity hits
          if (b.friendly) {
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
          } else {
            // Enemy bullet vs player (shield blocks frontal fire).
            if (dist2(b.x, b.y, p.x, p.y) < p.radius * p.radius) {
              if (p.shieldUp) {
                const toB = Math.atan2(b.y - p.y, b.x - p.x);
                let diff = Math.abs(
                  ((toB - p.angle + Math.PI * 3) % (Math.PI * 2)) - Math.PI,
                );
                if (diff < 1.1) {
                  b.dead = true; // blocked by shield arc
                  this.spawnDebris(b.x, b.y, "#6ad06a");
                  break;
                }
              }
              p.hp -= b.damage;
              b.dead = true;
              this.spawnBlood(b.x, b.y);
              this.shake = Math.min(this.shake + 5, 14);
              Audio.hit();
              break;
            }
          }
        }
      }
      this.enemies = this.enemies.filter((e) => e.hp > 0);
      this.bullets = this.bullets.filter((b) => !b.dead);
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
              // Destroy a small cluster of soft walls.
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
              this.spawnDebris(c.x, c.y, "#c0c0c0");
            }
          }
          c.life -= dt;
          if (c.life <= 0) c.done = true;
        } else {
          c.t -= dt;
          if (c.t <= 0 && !c.done) {
            c.done = true;
            let ok;
            if (c.reinforced) ok = this.breachReinforced(c.tx, c.ty);
            else ok = this.breachTile(c.tx, c.ty);
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

    updateObjectives(dt) {
      const p = this.player;
      let onObj = null;
      for (const o of this.objectives) {
        if (!o.defused && dist2(p.x, p.y, o.x, o.y) < (TILE * 0.9) ** 2)
          onObj = o;
      }
      if (onObj) {
        this.defuseProgress += dt;
        if (this.defuseProgress >= 4) {
          onObj.defused = true;
          this.defuseProgress = 0;
          this.flash("Objective secured!");
          if (this.objectives.every((o) => o.defused))
            this.end(true, "All objectives secured.");
        }
      } else {
        this.defuseProgress = Math.max(0, this.defuseProgress - dt * 2);
      }
      this._onObj = onObj;
    }

    computeVisibility() {
      const p = this.player;
      const R = 10; // tile view radius
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

      // Background
      ctx.fillStyle = "#0d0f12";
      ctx.fillRect(-20, -20, W + 40, H + 40);

      this.renderTiles(ctx);
      this.renderObjectives(ctx);
      this.renderCharges(ctx);
      this.renderEnemies(ctx);
      this.renderBullets(ctx);
      this.renderPlayer(ctx);
      this.renderParticles(ctx);
      this.renderFog(ctx);
      this.renderFloaters(ctx);

      ctx.restore();
      this.renderHUD(ctx);
    }

    renderTiles(ctx) {
      for (let ty = 0; ty < ROWS; ty++) {
        for (let tx = 0; tx < COLS; tx++) {
          const t = this.grid[ty][tx];
          const x = tx * TILE,
            y = ty * TILE;
          let fill = null,
            stroke = null;
          if (t === EXT) fill = "#15181d";
          else if (t === FLOOR) fill = "#22262e";
          else if (t === RUBBLE) fill = "#2a2620";
          else if (t === REINF) {
            fill = "#3a4048";
            stroke = "#565f6b";
          } else if (t === SOFT) {
            fill = "#5a4a34";
            stroke = "#6f5a3f";
          } else if (t === WINDOW) {
            fill = "#334a55";
            stroke = "#4a6b78";
          }
          if (fill) {
            ctx.fillStyle = fill;
            ctx.fillRect(x, y, TILE, TILE);
          }
          if (t === FLOOR || t === EXT || t === RUBBLE) {
            ctx.strokeStyle = "rgba(255,255,255,0.03)";
            ctx.strokeRect(x + 0.5, y + 0.5, TILE - 1, TILE - 1);
          }
          if (stroke) {
            ctx.strokeStyle = stroke;
            ctx.lineWidth = 2;
            ctx.strokeRect(x + 1, y + 1, TILE - 2, TILE - 2);
            if (t === REINF) {
              // reinforced hatch marks
              ctx.strokeStyle = "rgba(120,140,160,0.4)";
              ctx.lineWidth = 1;
              ctx.beginPath();
              ctx.moveTo(x + 4, y + TILE / 2);
              ctx.lineTo(x + TILE - 4, y + TILE / 2);
              ctx.moveTo(x + TILE / 2, y + 4);
              ctx.lineTo(x + TILE / 2, y + TILE - 4);
              ctx.stroke();
            }
            // soft-wall damage cracks
            if (
              (t === SOFT || t === WINDOW) &&
              this.softHp[tx + "," + ty] !== undefined
            ) {
              const max = t === SOFT ? SOFT_HP : WINDOW_HP;
              const frac = this.softHp[tx + "," + ty] / max;
              ctx.strokeStyle = "rgba(0,0,0," + 0.6 * (1 - frac) + ")";
              ctx.lineWidth = 1.5;
              ctx.beginPath();
              ctx.moveTo(x + 3, y + 3);
              ctx.lineTo(x + TILE - 5, y + TILE - 7);
              ctx.moveTo(x + TILE - 4, y + 5);
              ctx.lineTo(x + 6, y + TILE - 4);
              ctx.stroke();
            }
          }
        }
      }
    }

    renderObjectives(ctx) {
      for (const o of this.objectives) {
        if (!this.isVisible(o.x, o.y)) continue;
        const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 300);
        ctx.save();
        ctx.translate(o.x, o.y);
        if (o.defused) {
          ctx.strokeStyle = "#6ad06a";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.arc(0, 0, TILE * 0.45, 0, Math.PI * 2);
          ctx.stroke();
          ctx.fillStyle = "#6ad06a";
          ctx.font = "16px sans-serif";
          ctx.textAlign = "center";
          ctx.fillText("✓", 0, 5);
        } else {
          ctx.fillStyle = "rgba(229,83,60," + (0.25 + 0.25 * pulse) + ")";
          ctx.beginPath();
          ctx.arc(0, 0, TILE * (0.5 + 0.15 * pulse), 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = "#e5533c";
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.arc(0, 0, TILE * 0.4, 0, Math.PI * 2);
          ctx.stroke();
          ctx.fillStyle = "#ffd25a";
          ctx.font = "bold 13px monospace";
          ctx.textAlign = "center";
          ctx.fillText("DEF", 0, 4);
        }
        ctx.restore();
      }
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

    drawFighter(ctx, x, y, angle, color, radius) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(angle);
      // body
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(0, 0, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,0.4)";
      ctx.lineWidth = 2;
      ctx.stroke();
      // gun barrel
      ctx.fillStyle = "#111";
      ctx.fillRect(radius - 2, -3, radius * 0.9, 6);
      ctx.restore();
    }

    renderEnemies(ctx) {
      for (const e of this.enemies) {
        const shown = this.isVisible(e.x, e.y) || e.revealTimer > 0;
        if (!shown) continue;
        this.drawFighter(ctx, e.x, e.y, e.angle, "#d64545", e.radius);
        if (e.muzzle > 0) {
          ctx.fillStyle = "#ffd25a";
          ctx.beginPath();
          ctx.arc(
            e.x + Math.cos(e.angle) * 16,
            e.y + Math.sin(e.angle) * 16,
            5,
            0,
            Math.PI * 2,
          );
          ctx.fill();
        }
        // health pip
        const w = 22;
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(e.x - w / 2, e.y - e.radius - 9, w, 4);
        ctx.fillStyle = "#e5533c";
        ctx.fillRect(e.x - w / 2, e.y - e.radius - 9, w * (e.hp / 100), 4);
      }
    }

    renderBullets(ctx) {
      for (const b of this.bullets) {
        ctx.strokeStyle = b.friendly ? "#ffd25a" : "#ff6b5a";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(b.x, b.y);
        ctx.lineTo(b.x - b.vx * 0.012, b.y - b.vy * 0.012);
        ctx.stroke();
      }
    }

    renderPlayer(ctx) {
      const p = this.player;
      this.drawFighter(ctx, p.x, p.y, p.angle, this.op.color, p.radius);
      // aim line
      ctx.strokeStyle = "rgba(255,255,255,0.15)";
      ctx.setLineDash([4, 6]);
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(p.x + Math.cos(p.angle) * 60, p.y + Math.sin(p.angle) * 60);
      ctx.stroke();
      ctx.setLineDash([]);
      // shield
      if (p.shieldUp) {
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.angle);
        ctx.fillStyle = "rgba(106,208,106,0.35)";
        ctx.strokeStyle = "#6ad06a";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(p.radius + 3, 0, p.radius + 6, -1.1, 1.1);
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
      // Darken tiles the player cannot currently see.
      for (let ty = 0; ty < ROWS; ty++) {
        for (let tx = 0; tx < COLS; tx++) {
          if (!this.vis || !this.vis[tx + "," + ty]) {
            ctx.fillStyle = "rgba(6,7,9,0.72)";
            ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
          }
        }
      }
    }

    renderHUD(ctx) {
      const p = this.player;
      // defuse progress ring
      if (this._onObj && this.defuseProgress > 0) {
        const frac = clamp(this.defuseProgress / 4, 0, 1);
        ctx.save();
        ctx.translate(this._onObj.x, this._onObj.y - 30);
        ctx.strokeStyle = "rgba(0,0,0,0.6)";
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.arc(0, 0, 14, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = "#6ad06a";
        ctx.beginPath();
        ctx.arc(0, 0, 14, -Math.PI / 2, -Math.PI / 2 + frac * Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      }

      // flash message
      if (this.msgT > 0 && this.msg) {
        ctx.globalAlpha = clamp(this.msgT, 0, 1);
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(W / 2 - 150, 12, 300, 30);
        ctx.fillStyle = "#ffd25a";
        ctx.font = "bold 15px monospace";
        ctx.textAlign = "center";
        ctx.fillText(this.msg, W / 2, 32);
        ctx.globalAlpha = 1;
      }

      // Sync DOM HUD
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
      const m = Math.floor(this.time / 60),
        s = Math.floor(this.time % 60);
      setT("timer-num", m + ":" + (s < 10 ? "0" : "") + s);
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
    if (id) document.getElementById(id).classList.remove("hidden");
  }

  function loop(now) {
    const dt = Math.min(0.05, (now - game.last) / 1000);
    game.last = now;
    game.update(dt);
    game.render();
    if (game.state === "playing") {
      raf = requestAnimationFrame(loop);
    } else {
      showEnd(game.state === "won", game.endReason);
    }
  }

  function startGame(opKey) {
    if (game) game.destroy();
    if (raf) cancelAnimationFrame(raf);
    Audio.resume();
    game = new Game(canvas, opKey);
    show(null);
    document.getElementById("hud").classList.remove("hidden");
    document.getElementById("op-name").textContent =
      OPERATORS[opKey].name + " · " + OPERATORS[opKey].role;
    game.last = performance.now();
    raf = requestAnimationFrame(loop);
  }

  function showEnd(won, reason) {
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

  // Build operator cards
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

  show("menu");
})();
