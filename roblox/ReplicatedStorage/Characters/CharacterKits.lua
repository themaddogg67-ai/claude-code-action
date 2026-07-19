--[[
	CharacterKits  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Characters > CharacterKits   (NEW module,
	next to your existing CharacterData)

	Q/E/R/F kits for the Heroes & Villains roster, built from each character's
	"main attacks" in the design doc and powered by the AbilityEngine types
	(projectile, beam, barrage, shield, wall, zone, strike, chain, bind, force,
	tendrils, breath, slam, clones, turret, counter, phase, teleport, vortex...).

	AbilityManager loads this module and checks it BEFORE CharacterData, so
	these kits take effect immediately. To keep an old hand-made kit instead,
	either delete that character's entry here or swap the lookup order in
	AbilityManager.resolve (it's one commented line).

	IMPORTANT: keys must exactly match the player's "CharacterName" attribute
	(e.g. "Ice Man" with the space). Adjust spellings here if yours differ.

	Balance is all data -- tune damage/cooldown/energy freely. Any def without
	an explicit `energy` uses the automatic cost formula in AbilityManager.
]]

local Kits = {}
local V = Vector3.new

-- MANDERIN — armored genius: 4 back tentacles that grab and fire lasers,
-- an "untouchable" force field, and teleportation.
Kits["Manderin"] = { style = "energy", styleKey = "manderin", abilities = {
	Q = { name = "Tentacle Grab",   type = "bind", range = 28, duration = 2.2, damage = 14, cooldown = 8 },
	E = { name = "Tentacle Lasers", type = "barrage", count = 4, interval = 0.12, spread = 4, damage = 12, speed = 170, size = V(1.2, 1.2, 1.2), knockback = 18, cooldown = 6 },
	R = { name = "Aegis Protocol",  type = "shield", duration = 5, untouchable = true, radius = 9, cooldown = 35, energy = 45 },
	F = { name = "Translocate",     type = "teleport", range = 45, cooldown = 6 },
}}

-- LOONEY / ELASTIMAN — rubber slingshot, clap smash, arm gatling, and the
-- finger gun that stuns on every 3rd hit.
Kits["Looney"] = { style = "energy", styleKey = "looney toon", abilities = {
	Q = { name = "Slingshot",   type = "dash", distance = 34, damage = 24, knockback = 45, up = 12, cooldown = 6 },
	E = { name = "Thunder Clap", type = "force", mode = "push", radius = 14, strength = 85, damage = 20, upBoost = 20, cooldown = 7 },
	R = { name = "Arm Gatling", type = "barrage", count = 10, interval = 0.07, spread = 7, damage = 5, speed = 150, size = V(1, 1, 1), knockback = 8, cooldown = 9 },
	F = { name = "Finger Gun",  type = "projectile", damage = 7, speed = 160, size = V(0.9, 0.9, 0.9), knockback = 10, stunEvery = 3, cooldown = 1.2 },
}}

-- TITAN — raw strength, speed and flight: punch, launch charge, ground smash,
-- headbutt.
Kits["Titan"] = { style = "physical", styleKey = "titan", abilities = {
	Q = { name = "Mega Punch",   type = "melee", range = 6, damage = 30, knockback = 55, up = 18, cooldown = 4 },
	E = { name = "Sky Launch",   type = "dash", distance = 40, damage = 22, knockback = 50, up = 20, cooldown = 7 },
	R = { name = "Ground Smash", type = "slam", radius = 16, damage = 34, knockback = 45, up = 30, stunDuration = 0.8, cooldown = 10 },
	F = { name = "Headbutt",     type = "melee", range = 4, damage = 18, knockback = 30, stunDuration = 1, cooldown = 5 },
}}

-- RED ROCKET — ignites the air: flaming fists that send people flying and set
-- them on fire, a burning leap, and a shockwave clap.
Kits["Red Rocket"] = { style = "fire", styleKey = "red rocket flame", abilities = {
	Q = { name = "Flaming Fist",    type = "melee", range = 6, damage = 32, knockback = 60, up = 20, dotDamage = 5, dotDuration = 3, cooldown = 4 },
	E = { name = "Ignition Charge", type = "dash", distance = 46, damage = 26, knockback = 45, up = 15, dotDamage = 4, dotDuration = 2, cooldown = 7 },
	R = { name = "Sonic Clap",      type = "force", mode = "push", radius = 16, strength = 95, damage = 22, cooldown = 8 },
	F = { name = "Meteor Headbutt", type = "melee", range = 4.5, damage = 24, knockback = 40, stunDuration = 0.7, cooldown = 5 },
}}

-- DEAD DASH — 1000mph speedster: dashes through people, rapid-fire fists,
-- phasing, and circling flurries. (Bullet Train and Imprint reuse this kit.)
Kits["Dead Dash"] = { style = "energy", styleKey = "storm speedster", abilities = {
	Q = { name = "Blur Strike",  type = "dash", distance = 45, damage = 20, knockback = 30, cooldown = 4 },
	E = { name = "Machine-Gun Fists", type = "melee", hits = 5, hitInterval = 0.1, range = 5, damage = 6, knockback = 8, cooldown = 6 },
	R = { name = "Phase",        type = "phase", duration = 1.4, speedMult = 1.6, cooldown = 12 },
	F = { name = "Cyclone Rush", type = "zone", atSelf = true, radius = 10, duration = 2.2, tickDamage = 7, tickRate = 0.3, cooldown = 12 },
}}
Kits["Bullet Train"] = Kits["Dead Dash"]
Kits["Imprint"]      = Kits["Dead Dash"]

-- FROST — ice beam that slows then freezes, ice ball, and the shield that
-- shoots ice shards in a circle when it ends, plus ice structures.
Kits["Frost"] = { style = "ice", styleKey = "frost ice", abilities = {
	Q = { name = "Ice Beam",     type = "beam", tickDamage = 4, tickRate = 0.25, range = 65, slowAmount = 0.4, slowDuration = 1.4, energyPerSecond = 8, maxDuration = 6, cooldown = 1 },
	E = { name = "Ice Ball",     type = "projectile", damage = 22, speed = 110, splashRadius = 7, slowAmount = 0.5, slowDuration = 1.5, knockback = 25, cooldown = 5 },
	R = { name = "Glacier Ward", type = "shield", duration = 5, block = 0.8, radius = 8, auraSlow = 0.45, auraRate = 0.5, burst = { count = 10, damage = 12, speed = 100, slowAmount = 0.4 }, cooldown = 18 },
	F = { name = "Ice Wall",     type = "wall", width = 16, height = 10, thickness = 3, duration = 8, material = Enum.Material.Ice, cooldown = 10 },
}}

-- ICE MAN — Frost's son with more potential; his ultimate is the absolute-zero
-- domain where everything inside freezes.
Kits["Ice Man"] = { style = "ice", styleKey = "iceman zero", abilities = {
	Q = { name = "Ice Beam",      type = "beam", tickDamage = 5, tickRate = 0.25, range = 70, slowAmount = 0.35, slowDuration = 1.5, energyPerSecond = 9, maxDuration = 7, cooldown = 1 },
	E = { name = "Glacier Ball",  type = "projectile", damage = 26, speed = 115, splashRadius = 8, slowAmount = 0.45, slowDuration = 1.6, knockback = 28, cooldown = 5 },
	R = { name = "Glacier Ward",  type = "shield", duration = 5, block = 0.85, radius = 8, auraSlow = 0.4, auraRate = 0.5, burst = { count = 12, damage = 14, speed = 105, slowAmount = 0.4 }, cooldown = 18 },
	F = { name = "Absolute Zero", type = "zone", radius = 22, duration = 6, tickDamage = 8, tickRate = 0.5, slowAmount = 0.15, cooldown = 40, energy = 50 },
}}

-- WATER WOMAN — water beam, water balls, the shield that bursts into a wave,
-- and 4 water tentacles that keep attacking whoever they hold.
Kits["Water Woman"] = { style = "water", styleKey = "water tide", abilities = {
	Q = { name = "Water Beam",      type = "beam", tickDamage = 4, tickRate = 0.25, range = 60, knockback = 8, energyPerSecond = 8, maxDuration = 6, cooldown = 1 },
	E = { name = "Water Spheres",   type = "barrage", count = 3, interval = 0.15, spread = 5, damage = 14, speed = 120, size = V(2, 2, 2), knockback = 30, cooldown = 6 },
	R = { name = "Tide Ward",       type = "shield", duration = 5, block = 0.75, radius = 8, burst = { count = 8, damage = 10, speed = 95, push = 80 }, cooldown = 16 },
	F = { name = "Water Tentacles", type = "tendrils", count = 4, duration = 7, range = 24, tickDamage = 7, tickRate = 0.7, cooldown = 18 },
}}

-- PROMETHEUS — Atlantis royalty: everything Water Woman does but stronger,
-- with a tsunami-sized shield burst and water-portal travel.
Kits["Prometheus"] = { style = "water", styleKey = "sea king", abilities = {
	Q = { name = "Riptide Beam",  type = "beam", tickDamage = 6, tickRate = 0.25, range = 70, knockback = 10, energyPerSecond = 10, maxDuration = 7, cooldown = 1 },
	E = { name = "Deluge Orbs",   type = "barrage", count = 4, interval = 0.14, spread = 5, damage = 16, speed = 125, size = V(2.2, 2.2, 2.2), knockback = 35, cooldown = 6 },
	R = { name = "Tsunami Ward",  type = "shield", duration = 5, block = 0.85, radius = 9, burst = { count = 12, damage = 16, speed = 110, push = 110 }, cooldown = 22, energy = 40 },
	F = { name = "Ocean Portal",  type = "teleport", range = 55, damage = 20, radius = 9, knockback = 35, cooldown = 9 },
}}

-- JUMPER — teleports through people to detonate them, throws enemies into the
-- sky, and drops a black hole that sucks everything in and explodes.
Kits["Jumper"] = { style = "shadow", styleKey = "jumper rift", abilities = {
	Q = { name = "Blink Strike", type = "teleport", range = 40, damage = 26, radius = 8, knockback = 40, cooldown = 7 },
	E = { name = "Sky Exile",    type = "bind", range = 26, duration = 1, damage = 10, launchUp = 130, cooldown = 12 },
	R = { name = "Long Rift",    type = "teleport", range = 90, cooldown = 10 },
	F = { name = "Black Hole",   type = "vortex", radius = 16, duration = 3.5, pull = 75, tickDamage = 4, endDamage = 40, endKnockback = 95, cooldown = 30, energy = 50 },
}}

-- OMEGA — telekinetic crush and throw, twin heat-vision lasers, and
-- planet-breaking punches.
Kits["Omega"] = { style = "cosmic", styleKey = "omega", abilities = {
	Q = { name = "Telekinetic Crush", type = "bind", range = 30, duration = 2.5, dps = 12, cooldown = 10 },
	E = { name = "Telekinetic Throw", type = "force", mode = "push", radius = 16, strength = 110, damage = 18, upBoost = 35, cooldown = 8 },
	R = { name = "Heat Vision",       type = "beam", tickDamage = 7, tickRate = 0.2, range = 80, color = Color3.fromRGB(255, 60, 40), energyPerSecond = 11, maxDuration = 6, cooldown = 1 },
	F = { name = "Planet Breaker",    type = "melee", range = 6, damage = 55, knockback = 90, up = 35, cooldown = 12, energy = 40 },
}}

-- CHASM — kinetic balls that hit harder the farther they fly, rifts, the
-- untouchable energy state, and a detonating black hole.
Kits["Chasm"] = { style = "energy", styleKey = "chasm", abilities = {
	Q = { name = "Kinetic Ball",  type = "projectile", damage = 16, speed = 130, rampPer = 60, knockback = 35, cooldown = 3 },
	E = { name = "Rift Step",     type = "teleport", range = 50, cooldown = 6 },
	R = { name = "Energy State",  type = "phase", duration = 4, transparency = 0.55, cooldown = 30, energy = 45 },
	F = { name = "Black Hole",    type = "vortex", radius = 14, duration = 3, pull = 70, tickDamage = 3, endDamage = 34, endKnockback = 85, cooldown = 26, energy = 45 },
}}

-- EMBER — fireball, fire fists, the force field that ignites everyone inside,
-- and the meteor strike that rains fireballs. (Ash shares this kit.)
Kits["Ember"] = { style = "fire", styleKey = "ember flame", abilities = {
	Q = { name = "Fireball",    type = "projectile", damage = 24, speed = 120, splashRadius = 8, dotDamage = 4, dotDuration = 3, knockback = 30, cooldown = 4 },
	E = { name = "Fire Fists",  type = "melee", hits = 3, hitInterval = 0.14, range = 5, damage = 10, knockback = 15, dotDamage = 3, dotDuration = 2, cooldown = 6 },
	R = { name = "Flame Ward",  type = "shield", duration = 5, block = 0.7, radius = 8, auraDamage = 6, auraRate = 0.6, cooldown = 16 },
	F = { name = "Meteor Rain", type = "strike", count = 6, interval = 0.3, delay = 0.8, radius = 8, spreadRadius = 12, damage = 18, knockback = 30, dotDamage = 4, dotDuration = 2, cooldown = 24, energy = 45 },
}}
Kits["Ash"] = Kits["Ember"]

-- X — the half-dragon swordsman: dragon slash, fire breath, claw flurry, and
-- the lunging claw.
Kits["X"] = { style = "fire", styleKey = "dragon fire", abilities = {
	Q = { name = "Dragon Slash", type = "melee", range = 8, size = V(11, 8, 8), damage = 28, knockback = 40, cooldown = 4 },
	E = { name = "Fire Breath",  type = "breath", duration = 2.2, range = 20, angle = 32, tickDamage = 6, tickRate = 0.22, dotDamage = 3, dotDuration = 2, cooldown = 9 },
	R = { name = "Claw Flurry",  type = "melee", hits = 4, hitInterval = 0.11, range = 5, damage = 8, knockback = 10, cooldown = 6 },
	F = { name = "Lunging Claw", type = "dash", distance = 30, damage = 26, knockback = 35, up = 10, cooldown = 7 },
}}

-- NULL — darkness beam, shadow tendrils, a force field that damages everything
-- in its area, and the widespread dark enclosure.
Kits["Null"] = { style = "shadow", styleKey = "null darkness", abilities = {
	Q = { name = "Darkness Beam",   type = "beam", tickDamage = 5, tickRate = 0.25, range = 60, energyPerSecond = 9, maxDuration = 6, cooldown = 1 },
	E = { name = "Shadow Tendrils", type = "tendrils", count = 5, duration = 6, range = 22, tickDamage = 6, tickRate = 0.7, cooldown = 14 },
	R = { name = "Dark Ward",       type = "shield", duration = 5, block = 0.7, radius = 9, auraDamage = 7, auraRate = 0.6, cooldown = 18 },
	F = { name = "Dark Enclosure",  type = "zone", radius = 20, duration = 6, tickDamage = 7, tickRate = 0.5, slowAmount = 0.6, cooldown = 26, energy = 45 },
}}

-- VOID OVERLORD — void beam, void balls, the damaging void field, and a black
-- hole worthy of the king of the void.
Kits["Void Overlord"] = { style = "shadow", styleKey = "void overlord", abilities = {
	Q = { name = "Void Beam",  type = "beam", tickDamage = 6, tickRate = 0.25, range = 65, energyPerSecond = 10, maxDuration = 7, cooldown = 1 },
	E = { name = "Void Balls", type = "barrage", count = 4, interval = 0.15, spread = 6, damage = 14, speed = 115, size = V(2, 2, 2), knockback = 25, cooldown = 6 },
	R = { name = "Void Field", type = "shield", duration = 6, block = 0.75, radius = 10, auraDamage = 8, auraRate = 0.6, cooldown = 20 },
	F = { name = "Event Horizon", type = "vortex", radius = 18, duration = 4, pull = 80, tickDamage = 5, endDamage = 45, endKnockback = 100, cooldown = 32, energy = 55 },
}}

-- ONIX — limitless strength: giant punch, a leaping crater slam, the field
-- that hurts enemies from sheer pressure, and the one-shot infinite punch.
Kits["Onix"] = { style = "physical", styleKey = "onix stone gold", abilities = {
	Q = { name = "Power Punch",     type = "melee", range = 6, damage = 34, knockback = 65, up = 22, cooldown = 4 },
	E = { name = "Seismic Leap",    type = "slam", leap = true, radius = 15, damage = 30, knockback = 50, up = 30, cooldown = 10 },
	R = { name = "Strength Field",  type = "shield", duration = 6, block = 0.6, radius = 11, auraDamage = 8, auraRate = 0.5, cooldown = 20 },
	F = { name = "Infinite Punch",  type = "melee", range = 6, damage = 1000, knockback = 120, up = 40, cooldown = 90, energy = 60 },
}}

-- THE ENGINEER — laser, constructed sentry, force field, and invisibility.
Kits["The Engineer"] = { style = "energy", styleKey = "engineer tech", abilities = {
	Q = { name = "Fabricator Laser", type = "beam", tickDamage = 5, tickRate = 0.22, range = 65, energyPerSecond = 9, maxDuration = 6, cooldown = 1 },
	E = { name = "Sentry Turret",    type = "turret", duration = 12, fireRate = 0.7, damage = 8, range = 45, projectileSpeed = 140, cooldown = 18 },
	R = { name = "Force Field",      type = "shield", duration = 6, block = 0.85, radius = 8, cooldown = 18 },
	F = { name = "Optic Cloak",      type = "phase", duration = 3, transparency = 0.93, speedMult = 1.2, cooldown = 22 },
}}

-- PHOENIX — flaming spirit birds, fire beam, burning claw slashes, and the
-- massive firebird spirit.
Kits["Phoenix"] = { style = "fire", styleKey = "phoenix flame", abilities = {
	Q = { name = "Spirit Birds",   type = "barrage", count = 5, interval = 0.12, spread = 9, damage = 9, speed = 130, size = V(1.5, 1.5, 1.5), dotDamage = 2, dotDuration = 2, knockback = 15, cooldown = 6 },
	E = { name = "Fire Beam",      type = "beam", tickDamage = 5, tickRate = 0.25, range = 60, dotDamage = 2, energyPerSecond = 9, maxDuration = 6, cooldown = 1 },
	R = { name = "Flaming Claws",  type = "melee", hits = 3, hitInterval = 0.13, range = 5.5, damage = 9, knockback = 12, dotDamage = 3, dotDuration = 2, cooldown = 6 },
	F = { name = "Great Firebird", type = "projectile", damage = 36, speed = 100, size = V(5, 5, 5), splashRadius = 12, dotDamage = 5, dotDuration = 3, knockback = 50, up = 20, cooldown = 20, energy = 45 },
}}

-- ATOM — walking reactor: explosive punches, leaking radiation, atomic vision
-- that poisons, and a massive body-blast meltdown.
Kits["Atom"] = { style = "nature", styleKey = "atom radiation", abilities = {
	Q = { name = "Explosive Fist", type = "melee", range = 6, damage = 26, knockback = 45, up = 15, cooldown = 4 },
	E = { name = "Radiation Leak", type = "zone", atSelf = true, radius = 13, duration = 6, tickDamage = 5, tickRate = 0.6, dotDamage = 2, dotDuration = 2, cooldown = 16 },
	R = { name = "Atomic Vision",  type = "beam", tickDamage = 5, tickRate = 0.25, range = 70, dotDamage = 3, dotDuration = 3, energyPerSecond = 10, maxDuration = 6, cooldown = 1 },
	F = { name = "Meltdown",       type = "aoe", radius = 18, damage = 55, knockback = 70, up = 35, dotDamage = 4, dotDuration = 3, cooldown = 35, energy = 55 },
}}

-- FALLOUT — the ticking time bomb: explosive fists, radiation, a smash-down
-- explosion, and the point-blank self-detonation he survives.
Kits["Fallout"] = { style = "nature", styleKey = "fallout radiation", abilities = {
	Q = { name = "Explosive Fists", type = "melee", hits = 2, hitInterval = 0.18, range = 5.5, damage = 14, knockback = 30, cooldown = 5 },
	E = { name = "Radiation Leak",  type = "zone", atSelf = true, radius = 12, duration = 6, tickDamage = 5, tickRate = 0.6, cooldown = 16 },
	R = { name = "Smash-Down Blast", type = "slam", radius = 14, damage = 30, knockback = 45, up = 25, cooldown = 10 },
	F = { name = "Self-Detonate",   type = "aoe", radius = 13, damage = 200, knockback = 100, up = 45, cooldown = 75, energy = 60 },
}}

-- LOCKDOWN — chest blasts, crushing punches, the time-slow field, and the
-- stomp that slows speedsters and stuns everyone else.
Kits["Lockdown"] = { style = "energy", styleKey = "lockdown", abilities = {
	Q = { name = "Chest Blast",    type = "projectile", damage = 24, speed = 125, size = V(3, 3, 3), knockback = 55, up = 15, cooldown = 5 },
	E = { name = "Crushing Punch", type = "melee", range = 5.5, damage = 24, knockback = 30, stunDuration = 0.8, cooldown = 5 },
	R = { name = "Time Dilation",  type = "zone", atSelf = true, radius = 16, duration = 6, slowAmount = 0.35, tickRate = 0.4, cooldown = 22 },
	F = { name = "Seismic Stomp",  type = "slam", radius = 15, damage = 22, knockback = 25, stunDuration = 1.4, cooldown = 14 },
}}

-- FISSION — the ruler's-mastery sword: heavy slashes, explosive waves, the
-- decree that greatly slows everyone, and a smoke-bomb vanish.
Kits["Fission"] = { style = "cosmic", styleKey = "fission ruler", abilities = {
	Q = { name = "Ruler's Slash",   type = "melee", range = 8, size = V(12, 8, 7), damage = 30, knockback = 40, cooldown = 4 },
	E = { name = "Explosive Wave",  type = "projectile", damage = 26, speed = 115, size = V(3.5, 3.5, 3.5), splashRadius = 9, knockback = 40, cooldown = 6 },
	R = { name = "Ruler's Decree",  type = "zone", radius = 20, duration = 10, slowAmount = 0.4, tickRate = 0.4, cooldown = 30, energy = 45 },
	F = { name = "Smoke Bomb",      type = "phase", duration = 2.5, transparency = 0.92, speedMult = 1.3, cooldown = 18 },
}}

-- MECHAMANIAC — missiles, the mech's laser, a summoned sentry mech, and the
-- mega stomp that stuns its whole area.
Kits["MechaManiac"] = { style = "energy", styleKey = "mech tech", abilities = {
	Q = { name = "Missile Barrage", type = "barrage", count = 5, interval = 0.16, spread = 8, damage = 12, speed = 105, size = V(1.4, 1.4, 1.4), splashRadius = 6, knockback = 25, cooldown = 8 },
	E = { name = "Mech Laser",      type = "beam", tickDamage = 5, tickRate = 0.22, range = 65, energyPerSecond = 9, maxDuration = 6, cooldown = 1 },
	R = { name = "Deploy Mech",     type = "turret", duration = 14, fireRate = 0.6, damage = 10, range = 50, projectileSpeed = 135, scale = 1.8, cooldown = 24, energy = 45 },
	F = { name = "Mega Stomp",      type = "slam", radius = 17, damage = 26, knockback = 30, stunDuration = 1.5, cooldown = 16 },
}}

-- GALE (librarian) — golden chains that lock people in place, portals, the
-- eye-filled enclosure, and the touch that shows you everything at once.
Kits["Gale"] = { style = "gold", styleKey = "gale golden chain", abilities = {
	Q = { name = "Golden Chains",     type = "bind", range = 30, duration = 3, damage = 16, cooldown = 10 },
	E = { name = "Portal Step",       type = "teleport", range = 60, cooldown = 7 },
	R = { name = "Watching Enclosure", type = "zone", radius = 18, duration = 7, tickDamage = 6, tickRate = 0.5, slowAmount = 0.55, cooldown = 24, energy = 40 },
	F = { name = "Revelation Touch",  type = "melee", range = 4, size = V(5, 6, 5), damage = 150, knockback = 10, cooldown = 45, energy = 55 },
}}

-- MORBIUS (librarian) — chains, tentacle portals, mirror clones, and the
-- tentacle-swarmed enclosure.
Kits["Morbius"] = { style = "gold", styleKey = "morbius golden", abilities = {
	Q = { name = "Golden Chains",    type = "bind", range = 30, duration = 3, damage = 16, cooldown = 10 },
	E = { name = "Portal Tentacles", type = "tendrils", count = 5, duration = 7, range = 24, tickDamage = 6, tickRate = 0.7, cooldown = 15 },
	R = { name = "Mirror Clones",    type = "clones", count = 2, duration = 10, health = 60, cooldown = 22 },
	F = { name = "Tentacle Enclosure", type = "zone", radius = 20, duration = 7, tickDamage = 7, tickRate = 0.5, cooldown = 26, energy = 45 },
}}

-- NIGHTMARE — shadow tendrils, a paralyzing dread grip, the darkness dome,
-- and a life-draining swarm of bats.
Kits["Nightmare"] = { style = "shadow", styleKey = "nightmare dark", abilities = {
	Q = { name = "Shadow Tendrils", type = "tendrils", count = 5, duration = 6, range = 22, tickDamage = 6, tickRate = 0.7, cooldown = 14 },
	E = { name = "Dread Grip",      type = "bind", range = 28, duration = 2.5, dps = 8, cooldown = 11 },
	R = { name = "Night Dome",      type = "zone", radius = 19, duration = 7, tickDamage = 5, tickRate = 0.5, slowAmount = 0.5, cooldown = 24, energy = 40 },
	F = { name = "Bat Swarm",       type = "barrage", count = 6, interval = 0.1, spread = 10, damage = 7, speed = 110, size = V(1.1, 1.1, 1.1), lifesteal = 0.5, cooldown = 12 },
}}

-- LEON — ruler's mastery from his hands and feet, plus the future sight that
-- lets him counter anything.
Kits["Leon"] = { style = "cosmic", styleKey = "leon ruler", abilities = {
	Q = { name = "Ruler's Burst",   type = "projectile", damage = 24, speed = 140, size = V(2.6, 2.6, 2.6), knockback = 40, cooldown = 3.5 },
	E = { name = "Impact Palm",     type = "melee", range = 5.5, damage = 26, knockback = 60, up = 18, cooldown = 5 },
	R = { name = "Mastery Barrage", type = "barrage", count = 6, interval = 0.1, spread = 6, damage = 8, speed = 150, size = V(1.3, 1.3, 1.3), knockback = 15, cooldown = 9 },
	F = { name = "Future Sight",    type = "counter", duration = 1.6, reflect = 1.5, cooldown = 14 },
}}

-- ELECTRA — electricity: a single heavy bolt, arcing chain lightning, a storm
-- field, and a thunder crash. (Good template for Alien X / Battle Squid /
-- Liberty-style storm users.)
Kits["Electra"] = { style = "storm", styleKey = "electra lightning", abilities = {
	Q = { name = "Lightning Bolt",  type = "chain", damage = 26, jumps = 1, range = 45, stunDuration = 0.6, cooldown = 5 },
	E = { name = "Chain Lightning", type = "chain", damage = 18, jumps = 5, jumpRange = 20, falloff = 0.8, range = 40, cooldown = 9 },
	R = { name = "Storm Field",     type = "zone", radius = 16, duration = 6, tickDamage = 6, tickRate = 0.5, cooldown = 20 },
	F = { name = "Thunder Crash",   type = "slam", radius = 14, damage = 28, knockback = 35, stunDuration = 1, cooldown = 13 },
}}

-- ERIK — anger-fueled gravity: crushing pulls, a gravity well, and violent
-- repulsion.
Kits["Erik"] = { style = "cosmic", styleKey = "erik gravity", abilities = {
	Q = { name = "Gravity Pull",  type = "force", mode = "pull", radius = 20, strength = 90, damage = 10, cooldown = 7 },
	E = { name = "Gravity Crush", type = "bind", range = 28, duration = 2.2, dps = 10, cooldown = 11 },
	R = { name = "Gravity Well",  type = "vortex", radius = 15, duration = 4, pull = 70, tickDamage = 3, cooldown = 20 },
	F = { name = "Repulse",       type = "force", mode = "push", radius = 18, strength = 110, damage = 16, upBoost = 30, cooldown = 9 },
}}

-- MAGNUM — magnetism: yanking enemies in, storms of shrapnel, crushing them
-- from the inside, and a repulsion field.
Kits["Magnum"] = { style = "storm", styleKey = "magnum emp", abilities = {
	Q = { name = "Magnetic Pull",   type = "force", mode = "pull", radius = 22, strength = 95, cooldown = 7 },
	E = { name = "Shrapnel Storm",  type = "barrage", count = 8, interval = 0.08, spread = 9, damage = 6, speed = 145, size = V(1, 1, 1), knockback = 10, cooldown = 8 },
	R = { name = "Ferric Crush",    type = "bind", range = 28, duration = 2.4, dps = 9, cooldown = 12 },
	F = { name = "Repulsion Field", type = "shield", duration = 4, block = 0.8, radius = 8, burst = { count = 8, damage = 8, speed = 120, push = 95 }, cooldown = 18 },
}}

-- IMP — walking EMP: discharging pulses that shut people down.
Kits["Imp"] = { style = "storm", styleKey = "imp emp", abilities = {
	Q = { name = "EMP Pulse",     type = "force", mode = "push", radius = 16, strength = 70, damage = 12, stunDuration = 1, cooldown = 8 },
	E = { name = "Static Bolt",   type = "chain", damage = 20, jumps = 2, jumpRange = 16, range = 40, stunDuration = 0.5, cooldown = 6 },
	R = { name = "Dead Zone",     type = "zone", atSelf = true, radius = 15, duration = 6, tickDamage = 4, tickRate = 0.5, slowAmount = 0.45, cooldown = 22 },
	F = { name = "Total Discharge", type = "force", mode = "push", radius = 22, strength = 100, damage = 24, stunDuration = 1.6, upBoost = 30, cooldown = 26, energy = 50 },
}}

return Kits
