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
-- His description explicitly names a tsunami-sized wave, so R is a real
-- tsunami natural disaster (a rolling wall of water that sweeps the field).
Kits["Prometheus"] = { style = "water", styleKey = "sea king", abilities = {
	Q = { name = "Riptide Beam",  type = "beam", tickDamage = 6, tickRate = 0.25, range = 70, knockback = 10, energyPerSecond = 10, maxDuration = 7, cooldown = 1 },
	E = { name = "Deluge Orbs",   type = "barrage", count = 4, interval = 0.14, spread = 5, damage = 16, speed = 125, size = V(2.2, 2.2, 2.2), knockback = 35, cooldown = 6 },
	R = { name = "Tsunami",       type = "disaster", disaster = "tsunami", damage = 34, width = 30, height = 17, speed = 44, distance = 80, knockback = 85, cooldown = 24, energy = 45 },
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

-- ================================================================
-- BATCH 2 — the rest of the roster. Movesets are read from each
-- character's described powers/attacks in the design doc. Characters
-- the doc lists as "same as X" share that kit by reference.
-- ================================================================

-- ESTISS — the discoverer of mastery; switches between combat, impact, blue's
-- and royal guard's masteries. Royal guard makes him nearly impenetrable.
Kits["Estiss"] = { style = "cosmic", styleKey = "estiss mastery", abilities = {
	Q = { name = "Combat Mastery",     type = "melee", hits = 3, hitInterval = 0.12, range = 6, damage = 12, knockback = 20, cooldown = 4 },
	E = { name = "Impact Mastery",     type = "force", mode = "push", radius = 15, strength = 95, damage = 22, upBoost = 25, cooldown = 7 },
	R = { name = "Blue's Mastery",     type = "projectile", damage = 26, speed = 150, size = V(2.6, 2.6, 2.6), knockback = 40, cooldown = 5 },
	F = { name = "Royal Guard's Ward", type = "shield", duration = 6, block = 0.9, radius = 8, cooldown = 22, energy = 40 },
}}
-- ELDER (idea 2) is an older, wiser Estiss — same masteries.
Kits["The Elder"] = Kits["Estiss"]

-- LEGEND — one of the original 5 students, mastery second only to Leon.
Kits["Legend"] = { style = "cosmic", styleKey = "legend mastery", abilities = {
	Q = { name = "Mastery Strike",  type = "melee", range = 6, damage = 26, knockback = 35, cooldown = 4 },
	E = { name = "Mastery Bolt",    type = "projectile", damage = 24, speed = 145, size = V(2.4, 2.4, 2.4), knockback = 35, cooldown = 4 },
	R = { name = "Mastery Barrage", type = "barrage", count = 5, interval = 0.1, spread = 6, damage = 9, speed = 150, size = V(1.3, 1.3, 1.3), cooldown = 8 },
	F = { name = "Guard Stance",    type = "counter", duration = 1.5, reflect = 1.3, cooldown = 13 },
}}
Kits["Monk"] = { style = "nature", styleKey = "monk chi", abilities = {
	Q = { name = "Chi Palm",     type = "melee", hits = 3, hitInterval = 0.12, range = 5.5, damage = 11, knockback = 18, cooldown = 4 },
	E = { name = "Chi Blast",    type = "projectile", damage = 22, speed = 130, size = V(2.2, 2.2, 2.2), knockback = 35, cooldown = 5 },
	R = { name = "Chi Ward",     type = "shield", duration = 5, block = 0.75, radius = 8, cooldown = 16 },
	F = { name = "Chi Rush",     type = "dash", distance = 32, damage = 24, knockback = 30, cooldown = 7 },
}}

-- CONQUEST — dedicated to combat, uses the ten paths with mastery.
Kits["Conquest"] = { style = "cosmic", styleKey = "conquest combat", abilities = {
	Q = { name = "Ten Paths Flurry", type = "melee", hits = 4, hitInterval = 0.1, range = 6, damage = 11, knockback = 16, cooldown = 5 },
	E = { name = "Path Impact",      type = "force", mode = "push", radius = 15, strength = 100, damage = 24, upBoost = 28, cooldown = 7 },
	R = { name = "Conquering Dash",  type = "dash", distance = 36, damage = 28, knockback = 40, up = 12, cooldown = 8 },
	F = { name = "Warlord's Guard",  type = "counter", duration = 1.6, reflect = 1.5, cooldown = 13 },
}}

-- DRAGON / THE ONI GIRI — Leon's future-self enemy; a blade that cuts through
-- masteries, every mastery, plus time & reality mastery.
Kits["Dragon"] = { style = "shadow", styleKey = "dragon oni reality", abilities = {
	Q = { name = "Mastery Cleave",  type = "melee", range = 8, size = V(12, 8, 8), damage = 32, knockback = 45, cooldown = 4 },
	E = { name = "Reality Slash",   type = "projectile", damage = 30, speed = 150, size = V(3, 3, 3), splashRadius = 8, knockback = 45, cooldown = 6 },
	R = { name = "Time Stop Field", type = "zone", radius = 18, duration = 6, slowAmount = 0.2, tickDamage = 4, tickRate = 0.4, cooldown = 26, energy = 45 },
	F = { name = "Dimension Cut",   type = "aoe", radius = 16, damage = 50, knockback = 60, up = 30, cooldown = 30, energy = 50 },
}}
Kits["The Oni Giri"] = Kits["Dragon"]

-- CONDOR — 9ft demon king, super strength, teleportation, swordsman.
Kits["Condor"] = { style = "shadow", styleKey = "condor demon", abilities = {
	Q = { name = "Demon Slash",   type = "melee", range = 8, size = V(11, 9, 8), damage = 30, knockback = 42, cooldown = 4 },
	E = { name = "Shadow Blink",  type = "teleport", range = 42, damage = 24, radius = 8, knockback = 38, cooldown = 7 },
	R = { name = "Cross Slash",   type = "melee", hits = 2, hitInterval = 0.16, range = 8, size = V(12, 9, 8), damage = 18, knockback = 30, cooldown = 6 },
	F = { name = "Demon King's Wrath", type = "aoe", radius = 16, damage = 44, knockback = 55, up = 25, cooldown = 24, energy = 45 },
}}

-- ZEPHYR — the greatest swordsman ever.
Kits["Zephyr"] = { style = "energy", styleKey = "zephyr blade wind", abilities = {
	Q = { name = "Blade Rush",    type = "dash", distance = 30, damage = 26, knockback = 32, cooldown = 5 },
	E = { name = "Wind Slash",    type = "projectile", damage = 22, speed = 165, size = V(3, 1, 3), knockback = 30, cooldown = 4 },
	R = { name = "Blade Flurry",  type = "melee", hits = 5, hitInterval = 0.09, range = 6.5, damage = 8, knockback = 12, cooldown = 7 },
	F = { name = "Iai Counter",   type = "counter", duration = 1.4, reflect = 1.6, cooldown = 12 },
}}
-- JULY TROOPER — a master swordsman too.
Kits["July Trooper"] = Kits["Zephyr"]

-- CATALYST — swordsman with phantom/purpurs/sovereign mastery, kills "gods".
Kits["Catalyst"] = { style = "cosmic", styleKey = "catalyst phantom", abilities = {
	Q = { name = "Phantom Slash",   type = "melee", range = 8, size = V(11, 8, 8), damage = 28, knockback = 40, cooldown = 4 },
	E = { name = "Sovereign Wave",  type = "projectile", damage = 26, speed = 150, size = V(3, 2, 3), splashRadius = 7, knockback = 38, cooldown = 6 },
	R = { name = "Phantom Step",    type = "phase", duration = 1.4, speedMult = 1.6, cooldown = 12 },
	F = { name = "God Slayer",      type = "melee", range = 7, size = V(10, 9, 8), damage = 40, knockback = 55, up = 20, cooldown = 16, energy = 40 },
}}
-- TRUE — like Catalyst but one sword; Catalyst's student.
Kits["True"] = { style = "cosmic", styleKey = "true blade", abilities = {
	Q = { name = "Single Slash",  type = "melee", range = 7, size = V(10, 8, 7), damage = 26, knockback = 38, cooldown = 4 },
	E = { name = "Slash Wave",    type = "projectile", damage = 24, speed = 150, size = V(2.8, 2, 2.8), knockback = 35, cooldown = 5 },
	R = { name = "Blade Dash",    type = "dash", distance = 32, damage = 24, knockback = 32, cooldown = 7 },
	F = { name = "Riposte",       type = "counter", duration = 1.5, reflect = 1.4, cooldown = 13 },
}}
-- JAKE — Catalyst's student; solid swordsman baseline.
Kits["Jake"] = Kits["True"]

-- LUKE GRAM — master of combat, harnesses chi (bloody soldier's brother).
Kits["Luke Gram"] = { style = "nature", styleKey = "luke chi combat", abilities = {
	Q = { name = "Chi Flurry",   type = "melee", hits = 4, hitInterval = 0.1, range = 6, damage = 10, knockback = 15, cooldown = 5 },
	E = { name = "Chi Cannon",   type = "projectile", damage = 26, speed = 135, size = V(2.6, 2.6, 2.6), knockback = 40, cooldown = 5 },
	R = { name = "Chi Barrier",  type = "shield", duration = 5, block = 0.75, radius = 8, cooldown = 16 },
	F = { name = "Rising Chi",   type = "slam", leap = true, radius = 13, damage = 30, knockback = 45, up = 28, cooldown = 12 },
}}

-- IMPULSE — propels things forward at insane speeds.
Kits["Impulse"] = { style = "energy", styleKey = "impulse propel", abilities = {
	Q = { name = "Propelled Fist", type = "melee", range = 6, damage = 24, knockback = 70, up = 15, cooldown = 4 },
	E = { name = "Kinetic Shove",  type = "force", mode = "push", radius = 14, strength = 120, damage = 16, cooldown = 7 },
	R = { name = "Overdrive",      type = "buff", stat = "walkSpeed", amount = 1.8, duration = 6, cooldown = 16 },
	F = { name = "Slingshot Rush", type = "dash", distance = 44, damage = 26, knockback = 55, cooldown = 8 },
}}
-- GENZO — impulse's father, gravity manipulation.
Kits["Genzo"] = { style = "cosmic", styleKey = "genzo gravity", abilities = {
	Q = { name = "Gravity Pull",  type = "force", mode = "pull", radius = 20, strength = 90, damage = 8, cooldown = 7 },
	E = { name = "Gravity Slam",  type = "bind", range = 26, duration = 2, dps = 10, cooldown = 10 },
	R = { name = "Gravity Well",  type = "vortex", radius = 15, duration = 4, pull = 72, tickDamage = 3, endDamage = 30, cooldown = 22 },
	F = { name = "Crushing Field", type = "force", mode = "push", radius = 18, strength = 110, damage = 20, upBoost = 30, cooldown = 9 },
}}

-- MERCY — Leon's brother, cursed energy, every cursed mastery, stronger.
Kits["Mercy"] = { style = "shadow", styleKey = "mercy cursed", abilities = {
	Q = { name = "Cursed Bolt",    type = "projectile", damage = 26, speed = 140, size = V(2.6, 2.6, 2.6), dotDamage = 4, dotDuration = 3, knockback = 35, cooldown = 4 },
	E = { name = "Cursed Slash",   type = "melee", range = 7, size = V(10, 8, 7), damage = 28, knockback = 35, dotDamage = 3, dotDuration = 2, cooldown = 5 },
	R = { name = "Cursed Domain",  type = "zone", radius = 18, duration = 7, tickDamage = 8, tickRate = 0.5, slowAmount = 0.4, cooldown = 26, energy = 45 },
	F = { name = "Cursed Chains",  type = "bind", range = 30, duration = 3, damage = 20, cooldown = 12 },
}}

-- SUGORO — most powerful demon, 14 eyes, 8 rings, 4 arms; full power of the eyes.
Kits["Sugoro"] = { style = "shadow", styleKey = "sugoro demon eyes", abilities = {
	Q = { name = "Eye Beam",      type = "beam", tickDamage = 7, tickRate = 0.2, range = 75, energyPerSecond = 11, maxDuration = 6, cooldown = 1 },
	E = { name = "Four-Arm Flurry", type = "melee", hits = 6, hitInterval = 0.08, range = 6, damage = 8, knockback = 12, cooldown = 6 },
	R = { name = "Cursed Enclosure", type = "zone", radius = 20, duration = 7, tickDamage = 9, tickRate = 0.45, slowAmount = 0.5, cooldown = 28, energy = 50 },
	F = { name = "Wrath of the Eyes", type = "aoe", radius = 20, damage = 55, knockback = 65, up = 30, cooldown = 32, energy = 55 },
}}

-- TADACHI — strongest impact mastery + only defiance mastery.
Kits["Tadachi"] = { style = "physical", styleKey = "tadachi impact", abilities = {
	Q = { name = "Impact Palm",   type = "melee", range = 6, damage = 28, knockback = 75, up = 18, cooldown = 4 },
	E = { name = "Impact Wave",   type = "force", mode = "push", radius = 16, strength = 110, damage = 24, cooldown = 7 },
	R = { name = "Defiance Guard", type = "counter", duration = 1.8, reflect = 1.6, cooldown = 14 },
	F = { name = "Shattering Blow", type = "slam", radius = 15, damage = 34, knockback = 55, up = 30, stunDuration = 0.8, cooldown = 12 },
}}

-- JHAUNJU — Leon's son, inherits every mastery but weaker than Leon.
Kits["Jhaunju"] = { style = "cosmic", styleKey = "jhaunju ruler", abilities = {
	Q = { name = "Ruler's Burst",   type = "projectile", damage = 18, speed = 135, size = V(2.3, 2.3, 2.3), knockback = 32, cooldown = 3.5 },
	E = { name = "Impact Palm",     type = "melee", range = 5.5, damage = 20, knockback = 48, up = 15, cooldown = 5 },
	R = { name = "Mastery Barrage", type = "barrage", count = 5, interval = 0.1, spread = 6, damage = 6, speed = 145, size = V(1.2, 1.2, 1.2), cooldown = 9 },
	F = { name = "Guard Stance",    type = "counter", duration = 1.3, reflect = 1.2, cooldown = 15 },
}}

-- MEGABOT — cosmic manipulation, reality warping, one-shot eye laser.
Kits["Megabot"] = { style = "cosmic", styleKey = "megabot cosmic laser", abilities = {
	Q = { name = "Cosmic Bolt",   type = "projectile", damage = 26, speed = 150, size = V(2.8, 2.8, 2.8), splashRadius = 6, knockback = 40, cooldown = 4 },
	E = { name = "Warp Field",    type = "force", mode = "pull", radius = 20, strength = 95, damage = 14, cooldown = 8 },
	R = { name = "Reality Ward",  type = "shield", duration = 6, block = 0.85, radius = 9, cooldown = 20 },
	F = { name = "Eye Laser",     type = "beam", tickDamage = 12, tickRate = 0.18, range = 90, color = Color3.fromRGB(120, 0, 255), energyPerSecond = 14, maxDuration = 5, cooldown = 20, energy = 55 },
}}
Kits["Champion Bot"] = Kits["Megabot"]

-- THE BLUE TITAN / NEJHORA — his one attack takes 90% of an enemy's health.
Kits["Nejhora"] = { style = "cosmic", styleKey = "blue titan cosmic", abilities = {
	Q = { name = "Titan Strike",   type = "melee", range = 7, damage = 30, knockback = 45, up = 15, cooldown = 5 },
	E = { name = "Cosmic Bolt",    type = "projectile", damage = 26, speed = 140, size = V(3, 3, 3), knockback = 45, cooldown = 5 },
	R = { name = "Titan Guard",    type = "shield", duration = 6, block = 0.85, radius = 9, cooldown = 20 },
	F = { name = "Sovereign Decree", type = "melee", range = 8, size = V(9, 9, 8), damage = 5, percentDamage = 0.9, knockback = 20, cooldown = 60, energy = 60 },
}}
Kits["The Blue Titan"] = Kits["Nejhora"]

-- APOCALYPSO — anything he touches dies (needs more power for sentient things).
Kits["Apocalypso"] = { style = "shadow", styleKey = "apocalypso death", abilities = {
	Q = { name = "Death Touch",   type = "melee", range = 4, size = V(5, 6, 5), damage = 10, percentDamage = 0.5, knockback = 10, cooldown = 6 },
	E = { name = "Decay Bolt",    type = "projectile", damage = 8, percentDamage = 0.2, speed = 120, size = V(2.2, 2.2, 2.2), dotDamage = 5, dotDuration = 4, knockback = 20, cooldown = 6 },
	R = { name = "Death Field",   type = "zone", radius = 16, duration = 6, tickDamage = 8, tickRate = 0.5, cooldown = 24, energy = 45 },
	F = { name = "Annihilation",  type = "melee", range = 5, size = V(6, 7, 6), damage = 20, percentDamage = 0.85, knockback = 15, cooldown = 45, energy = 55 },
}}

-- ANTI-MAN — antimatter; anything that touches him dissipates.
Kits["Anti-Man"] = { style = "shadow", styleKey = "anti matter void", abilities = {
	Q = { name = "Antimatter Touch", type = "melee", range = 4.5, damage = 12, percentDamage = 0.4, knockback = 15, cooldown = 5 },
	E = { name = "Void Bolt",        type = "projectile", damage = 26, speed = 140, size = V(2.4, 2.4, 2.4), knockback = 35, cooldown = 4 },
	R = { name = "Dissipation Field", type = "shield", duration = 5, block = 1, untouchable = true, radius = 7, cooldown = 26, energy = 45 },
	F = { name = "Annihilation Wave", type = "aoe", radius = 15, damage = 20, percentDamage = 0.3, knockback = 50, up = 20, cooldown = 24, energy = 45 },
}}

-- CRUSHER — crushes things; awakening crushes organic matter.
Kits["Crusher"] = { style = "physical", styleKey = "crusher", abilities = {
	Q = { name = "Crushing Grip", type = "bind", range = 26, duration = 2.4, dps = 12, cooldown = 9 },
	E = { name = "Crush Slam",    type = "slam", radius = 14, damage = 30, knockback = 45, up = 20, cooldown = 9 },
	R = { name = "Pressure Field", type = "shield", duration = 5, block = 0.6, radius = 10, auraDamage = 7, auraRate = 0.5, cooldown = 18 },
	F = { name = "Vice Crush",    type = "bind", range = 28, duration = 3, dps = 16, radius = 10, cooldown = 24, energy = 45 },
}}

-- SINISTER — manipulates matter molecularly, limitless strength.
Kits["Sinister"] = { style = "shadow", styleKey = "sinister matter", abilities = {
	Q = { name = "Matter Spikes", type = "barrage", count = 5, interval = 0.1, spread = 7, damage = 10, speed = 140, size = V(1.3, 1.3, 1.3), knockback = 18, cooldown = 6 },
	E = { name = "Molecular Grip", type = "bind", range = 28, duration = 2.6, dps = 11, cooldown = 11 },
	R = { name = "Spike Field",   type = "zone", radius = 15, duration = 6, tickDamage = 7, tickRate = 0.5, cooldown = 20 },
	F = { name = "Limitless Blow", type = "melee", range = 6, damage = 45, knockback = 85, up = 30, cooldown = 16, energy = 45 },
}}

-- NEMESIS — mind control, reality warp, teleport, regen, gets stronger in gloom.
Kits["Nemesis"] = { style = "shadow", styleKey = "nemesis nightmare", abilities = {
	Q = { name = "Dread Bolt",     type = "projectile", damage = 24, speed = 135, size = V(2.5, 2.5, 2.5), dotDamage = 3, dotDuration = 2, knockback = 30, cooldown = 4 },
	E = { name = "Mind Grip",      type = "bind", range = 28, duration = 2.5, dps = 9, cooldown = 11 },
	R = { name = "Gloom Field",    type = "zone", radius = 18, duration = 7, tickDamage = 6, tickRate = 0.5, slowAmount = 0.5, healPerTick = 4, cooldown = 24, energy = 45 },
	F = { name = "Reality Warp",   type = "aoe", radius = 16, damage = 40, knockback = 55, up = 25, cooldown = 26, energy = 50 },
}}

-- PUPPET MASTER — turns people into dolls, controls them, reality warp, teleport.
Kits["Puppet Master"] = { style = "shadow", styleKey = "puppet strings", abilities = {
	Q = { name = "String Pull",   type = "force", mode = "pull", radius = 20, strength = 90, damage = 10, cooldown = 7 },
	E = { name = "Doll Curse",    type = "bind", range = 28, duration = 3, damage = 16, cooldown = 11 },
	R = { name = "Teleport",      type = "teleport", range = 45, cooldown = 6 },
	F = { name = "Mass Puppetry", type = "bind", range = 40, radius = 14, duration = 2.5, damage = 12, cooldown = 24, energy = 45 },
}}

-- MR BLACKIE — darkness that disables and drains enemies in its area.
Kits["Mr Blackie"] = { style = "shadow", styleKey = "blackie darkness", abilities = {
	Q = { name = "Dark Bolt",    type = "projectile", damage = 22, speed = 130, size = V(2.4, 2.4, 2.4), knockback = 30, cooldown = 4 },
	E = { name = "Smother",      type = "bind", range = 26, duration = 2.4, dps = 8, cooldown = 10 },
	R = { name = "Blackout Field", type = "zone", radius = 18, duration = 7, tickDamage = 6, tickRate = 0.5, slowAmount = 0.55, cooldown = 24, energy = 45 },
	F = { name = "Consuming Dark", type = "shield", duration = 5, block = 0.75, radius = 10, auraDamage = 7, auraSlow = 0.4, auraRate = 0.5, cooldown = 20 },
}}

-- EMPEROR GREVIOUS — the god of darkness.
Kits["Emperor Grevious"] = { style = "shadow", styleKey = "dark emperor god", abilities = {
	Q = { name = "Darkness Beam", type = "beam", tickDamage = 6, tickRate = 0.22, range = 70, energyPerSecond = 10, maxDuration = 7, cooldown = 1 },
	E = { name = "Void Orbs",     type = "barrage", count = 4, interval = 0.14, spread = 6, damage = 15, speed = 120, size = V(2.2, 2.2, 2.2), knockback = 28, cooldown = 6 },
	R = { name = "Dark Empire",   type = "zone", radius = 20, duration = 7, tickDamage = 8, tickRate = 0.5, slowAmount = 0.5, cooldown = 26, energy = 50 },
	F = { name = "God of Darkness", type = "vortex", radius = 18, duration = 4, pull = 80, tickDamage = 5, endDamage = 45, endKnockback = 100, cooldown = 32, energy = 55 },
}}

-- THE ANONYMOUS — mind control, shadow realm, void/shadow/darkness.
Kits["The Anonymous"] = { style = "shadow", styleKey = "anonymous void mind", abilities = {
	Q = { name = "Mind Spike",    type = "projectile", damage = 24, speed = 140, size = V(2.4, 2.4, 2.4), knockback = 30, cooldown = 4 },
	E = { name = "Shadow Grip",   type = "bind", range = 30, duration = 2.6, dps = 10, cooldown = 11 },
	R = { name = "Shadow Realm",  type = "zone", radius = 20, duration = 7, tickDamage = 8, tickRate = 0.5, slowAmount = 0.5, cooldown = 26, energy = 50 },
	F = { name = "Void Collapse", type = "vortex", radius = 18, duration = 4, pull = 85, tickDamage = 5, endDamage = 48, endKnockback = 105, cooldown = 34, energy = 55 },
}}

-- BLOODY SOLDIER — blood manipulation, blood monster, regen from a drop.
Kits["Bloody Soldier"] = { style = "fire", styleKey = "bloody blood", color = Color3.fromRGB(180, 20, 20), abilities = {
	Q = { name = "Blood Spikes",  type = "barrage", count = 5, interval = 0.1, spread = 7, damage = 10, speed = 140, size = V(1.2, 1.2, 1.2), knockback = 18, cooldown = 6 },
	E = { name = "Blood Lash",    type = "tendrils", count = 4, duration = 6, range = 22, tickDamage = 6, tickRate = 0.7, follow = true, cooldown = 14 },
	R = { name = "Crimson Feast", type = "beam", tickDamage = 5, tickRate = 0.25, range = 55, lifesteal = 0.6, energyPerSecond = 9, maxDuration = 6, cooldown = 1 },
	F = { name = "Blood Monster", type = "buff", stat = "damageMult", amount = 1.6, duration = 8, cooldown = 26, energy = 45 },
}}

-- CARNAGE — "god of fear", metallic alien: strength, agility, fear pheromones.
Kits["Carnage"] = { style = "shadow", styleKey = "carnage fear", color = Color3.fromRGB(150, 20, 30), abilities = {
	Q = { name = "Claw Flurry",   type = "melee", hits = 4, hitInterval = 0.1, range = 5.5, damage = 9, knockback = 12, cooldown = 5 },
	E = { name = "Pounce",        type = "dash", distance = 32, damage = 24, knockback = 30, up = 12, cooldown = 7 },
	R = { name = "Fear Pheromone", type = "zone", atSelf = true, radius = 15, duration = 6, tickDamage = 4, tickRate = 0.5, slowAmount = 0.5, cooldown = 20 },
	F = { name = "Frenzy",        type = "buff", stat = "damageMult", amount = 1.6, duration = 7, cooldown = 24 },
}}

-- MEGALODON — "create storms like hurricanes or tsunamis", bends water/blood,
-- bloodlust. E summons a hurricane; R hurls a tsunami. His hurricane is a live
-- storm, so Liberty (or he himself) can seize and steer it with stormcontrol.
Kits["Megalodon"] = { style = "storm", styleKey = "megalodon sea storm hurricane", abilities = {
	Q = { name = "Razor Bite",  type = "melee", range = 6, damage = 30, knockback = 40, cooldown = 4 },
	E = { name = "Hurricane",   type = "storm", stormKind = "hurricane", radius = 26, duration = 10, strikeDamage = 15, strikeRate = 1, pull = 60, cooldown = 22, energy = 45 },
	R = { name = "Tsunami",     type = "disaster", disaster = "tsunami", damage = 36, width = 32, height = 18, speed = 46, distance = 85, knockback = 90, cooldown = 26, energy = 50 },
	F = { name = "Bloodlust",   type = "buff", stat = "damageMult", amount = 1.6, duration = 8, cooldown = 26, energy = 45 },
}}

-- MR.UNIVERSE — the omniforce: infinite anything, every power ever.
Kits["Mr Universe"] = { style = "cosmic", styleKey = "universe omniforce infinite", abilities = {
	Q = { name = "Infinite Bolt",  type = "projectile", damage = 30, speed = 160, size = V(3, 3, 3), splashRadius = 7, knockback = 45, cooldown = 4 },
	E = { name = "Omni Beam",      type = "beam", tickDamage = 9, tickRate = 0.2, range = 85, energyPerSecond = 12, maxDuration = 6, cooldown = 1 },
	R = { name = "Infinite Guard", type = "shield", duration = 6, block = 0.9, radius = 9, cooldown = 22, energy = 40 },
	F = { name = "Omniforce Nova", type = "aoe", radius = 20, damage = 55, knockback = 70, up = 35, cooldown = 30, energy = 55 },
}}
Kits["Mr Sinister"] = Kits["Mr Universe"]

-- ARMAGEDDON — titan powers + god armor; evil Mr.Universe.
Kits["Armageddon"] = { style = "shadow", styleKey = "armageddon titan god", abilities = {
	Q = { name = "Rage Bolt",      type = "projectile", damage = 30, speed = 155, size = V(3.2, 3.2, 3.2), splashRadius = 8, knockback = 48, cooldown = 4 },
	E = { name = "Destruction Wave", type = "force", mode = "push", radius = 18, strength = 115, damage = 26, upBoost = 30, cooldown = 8 },
	R = { name = "God Armor Guard", type = "shield", duration = 6, block = 0.9, radius = 9, auraDamage = 6, auraRate = 0.6, cooldown = 24, energy = 40 },
	F = { name = "Omniversal Ruin", type = "strike", count = 8, interval = 0.25, delay = 0.8, radius = 9, spreadRadius = 16, damage = 22, knockback = 40, cooldown = 34, energy = 60 },
}}

-- ZERO — power of the cosmos, center of the omniverse.
Kits["Zero"] = { style = "cosmic", styleKey = "zero cosmos", abilities = {
	Q = { name = "Cosmos Bolt",  type = "projectile", damage = 28, speed = 155, size = V(3, 3, 3), knockback = 42, cooldown = 4 },
	E = { name = "Star Beam",    type = "beam", tickDamage = 8, tickRate = 0.2, range = 80, energyPerSecond = 11, maxDuration = 6, cooldown = 1 },
	R = { name = "Cosmic Ward",  type = "shield", duration = 6, block = 0.85, radius = 9, cooldown = 20 },
	F = { name = "Supernova",    type = "aoe", radius = 20, damage = 52, knockback = 68, up = 32, cooldown = 30, energy = 55 },
}}
Kits["Cosmo"] = Kits["Zero"]

-- OMEGA VARIANTS — Old Man Omega (strongest) & Ultramega (second strongest).
Kits["Old Man Omega"] = { style = "cosmic", styleKey = "omega", abilities = {
	Q = { name = "Telekinetic Crush", type = "bind", range = 32, duration = 2.6, dps = 15, cooldown = 9 },
	E = { name = "Telekinetic Throw", type = "force", mode = "push", radius = 18, strength = 125, damage = 22, upBoost = 40, cooldown = 8 },
	R = { name = "Heat Vision",       type = "beam", tickDamage = 9, tickRate = 0.18, range = 85, color = Color3.fromRGB(255, 60, 40), energyPerSecond = 12, maxDuration = 6, cooldown = 1 },
	F = { name = "Planet Breaker",    type = "melee", range = 6, damage = 70, knockback = 100, up = 40, cooldown = 12, energy = 45 },
}}
Kits["Ultramega"] = Kits["Omega"]

-- PATRIOT — super strength, flight, heat lasers.
Kits["Patriot"] = { style = "energy", styleKey = "patriot", color = Color3.fromRGB(60, 120, 255), abilities = {
	Q = { name = "Super Punch",  type = "melee", range = 6, damage = 28, knockback = 55, up = 18, cooldown = 4 },
	E = { name = "Sky Charge",   type = "dash", distance = 40, damage = 22, knockback = 45, up = 18, cooldown = 7 },
	R = { name = "Heat Lasers",  type = "beam", tickDamage = 6, tickRate = 0.2, range = 75, color = Color3.fromRGB(255, 70, 50), energyPerSecond = 10, maxDuration = 6, cooldown = 1 },
	F = { name = "Star Slam",    type = "slam", radius = 15, damage = 30, knockback = 45, up = 25, cooldown = 12 },
}}
-- SUPER GUY — off-brand superman, homelander strength.
Kits["Super Guy"] = Kits["Patriot"]

-- STAR MAN — light beams from hands, super strength, flight.
Kits["Star Man"] = { style = "gold", styleKey = "starman light", abilities = {
	Q = { name = "Light Beam",   type = "beam", tickDamage = 6, tickRate = 0.22, range = 70, energyPerSecond = 10, maxDuration = 6, cooldown = 1 },
	E = { name = "Star Bolt",    type = "projectile", damage = 24, speed = 145, size = V(2.6, 2.6, 2.6), knockback = 35, cooldown = 4 },
	R = { name = "Starfall",     type = "strike", count = 5, interval = 0.3, delay = 0.8, radius = 8, spreadRadius = 12, damage = 18, knockback = 30, cooldown = 22, energy = 40 },
	F = { name = "Light Burst",  type = "aoe", radius = 16, damage = 34, knockback = 50, up = 25, cooldown = 16 },
}}

-- THE LIGHT EMPEROR — god of light: light beams, laser eyes, flight, invisibility in light.
Kits["The Light Emperor"] = { style = "gold", styleKey = "light emperor holy", abilities = {
	Q = { name = "Light Beam",   type = "beam", tickDamage = 7, tickRate = 0.2, range = 75, energyPerSecond = 11, maxDuration = 6, cooldown = 1 },
	E = { name = "Laser Eyes",   type = "barrage", count = 2, interval = 0.12, spread = 3, damage = 18, speed = 170, size = V(1.1, 1.1, 1.1), knockback = 20, cooldown = 5 },
	R = { name = "Radiant Ward", type = "shield", duration = 5, block = 0.85, radius = 9, cooldown = 18 },
	F = { name = "Solar Flare",  type = "aoe", radius = 18, damage = 40, knockback = 55, up = 28, cooldown = 24, energy = 45 },
}}

-- GOLDEN KNIGHT — super strength + holy chains.
Kits["Golden Knight"] = { style = "gold", styleKey = "golden knight holy chain", abilities = {
	Q = { name = "Holy Slash",   type = "melee", range = 7, size = V(9, 8, 7), damage = 26, knockback = 40, cooldown = 4 },
	E = { name = "Holy Chains",  type = "bind", range = 30, duration = 3, damage = 18, cooldown = 10 },
	R = { name = "Golden Ward",  type = "shield", duration = 5, block = 0.85, radius = 8, cooldown = 18 },
	F = { name = "Chain Prison", type = "bind", range = 34, radius = 14, duration = 2.8, damage = 16, cooldown = 24, energy = 45 },
}}

-- GALE (student of Catalyst) — manipulates his own energy. Distinct from the
-- librarian Gale above, so keyed separately to avoid a name clash.
Kits["Gale Student"] = { style = "energy", styleKey = "gale energy", abilities = {
	Q = { name = "Energy Bolt",  type = "projectile", damage = 24, speed = 145, size = V(2.4, 2.4, 2.4), knockback = 32, cooldown = 4 },
	E = { name = "Energy Blade", type = "melee", range = 7, size = V(9, 8, 7), damage = 24, knockback = 30, cooldown = 5 },
	R = { name = "Energy Ward",  type = "shield", duration = 5, block = 0.75, radius = 8, cooldown = 16 },
	F = { name = "Energy Nova",  type = "aoe", radius = 15, damage = 32, knockback = 45, up = 22, cooldown = 16 },
}}

-- GOLDEN GIRL — gold skin, strength, flight, fire manipulation, gold form.
Kits["Golden Girl"] = { style = "gold", styleKey = "golden girl fire", abilities = {
	Q = { name = "Golden Fist",  type = "melee", range = 6, damage = 26, knockback = 50, up = 16, dotDamage = 3, dotDuration = 2, cooldown = 4 },
	E = { name = "Fire Ball",    type = "projectile", damage = 22, speed = 120, splashRadius = 7, dotDamage = 4, dotDuration = 3, knockback = 28, cooldown = 5 },
	R = { name = "Gold Skin",    type = "shield", duration = 6, block = 0.8, radius = 7, cooldown = 18 },
	F = { name = "Flare Slam",   type = "slam", radius = 14, damage = 30, knockback = 45, up = 25, dotDamage = 4, dotDuration = 2, cooldown = 12 },
}}

-- GOLDDON — flaming gold skin, hand/eye lasers, power-removing chest blast.
Kits["Golddon"] = { style = "gold", styleKey = "golddon gold laser", abilities = {
	Q = { name = "Hand Lasers",  type = "barrage", count = 3, interval = 0.12, spread = 4, damage = 14, speed = 165, size = V(1.2, 1.2, 1.2), knockback = 18, cooldown = 5 },
	E = { name = "Eye Beam",     type = "beam", tickDamage = 6, tickRate = 0.2, range = 72, color = Color3.fromRGB(255, 220, 40), energyPerSecond = 10, maxDuration = 6, cooldown = 1 },
	R = { name = "Mind Detonation", type = "strike", count = 3, interval = 0.3, delay = 0.7, radius = 8, spreadRadius = 10, damage = 22, knockback = 40, cooldown = 16 },
	F = { name = "Nullify Blast", type = "projectile", damage = 30, speed = 130, size = V(3.5, 3.5, 3.5), knockback = 45, stunDuration = 1.5, cooldown = 22, energy = 45 },
}}

-- HEAT WAVE — "god of fire": fire, lava, heat waves, sun flares. He commands
-- lava/magma (a natural disaster) but NOT storms, so he gets a Volcano and no
-- storm-control ability. R erupts a volcano: crater damage, a lingering lava
-- pool, and lava bombs raining outward.
Kits["Heat Wave"] = { style = "fire", styleKey = "heatwave lava sun magma", abilities = {
	Q = { name = "Fire Ball",  type = "projectile", damage = 24, speed = 120, splashRadius = 8, dotDamage = 4, dotDuration = 3, knockback = 30, cooldown = 4 },
	E = { name = "Heat Wave",  type = "breath", duration = 2.2, range = 20, angle = 34, tickDamage = 6, tickRate = 0.22, dotDamage = 3, dotDuration = 2, cooldown = 9 },
	R = { name = "Volcano",    type = "disaster", disaster = "volcano", tickDamage = 9, poolDamage = 6, poolRadius = 13, bombDamage = 13, duration = 8, eruptRate = 0.7, cooldown = 26, energy = 50 },
	F = { name = "Sun Flare",  type = "strike", mode = "laser", count = 1, delay = 0.7, radius = 12, damage = 40, knockback = 45, dotDamage = 5, dotDuration = 3, cooldown = 22, energy = 45 },
}}
-- FAHRENHEIT — god of fire, lava, and magma; same domain, stronger tier.
Kits["Fahrenheit"] = Kits["Heat Wave"]
-- BLAZE — controls fire (baseline fire user).
Kits["Blaze"] = Kits["Ember"]

-- CELCIUS — god of ice.
Kits["Celcius"] = { style = "ice", styleKey = "celcius ice god", abilities = {
	Q = { name = "Ice Beam",     type = "beam", tickDamage = 5, tickRate = 0.25, range = 70, slowAmount = 0.35, slowDuration = 1.5, energyPerSecond = 9, maxDuration = 7, cooldown = 1 },
	E = { name = "Glacier Ball", type = "projectile", damage = 24, speed = 115, splashRadius = 8, slowAmount = 0.45, slowDuration = 1.6, knockback = 28, cooldown = 5 },
	R = { name = "Ice Wall",     type = "wall", width = 18, height = 11, thickness = 3, duration = 8, material = Enum.Material.Ice, cooldown = 10 },
	F = { name = "Absolute Zero", type = "zone", radius = 22, duration = 6, tickDamage = 8, tickRate = 0.5, slowAmount = 0.15, cooldown = 40, energy = 50 },
}}

-- INFINITY — controls water, fire, earth, air (all elements of reality), so she
-- commands weather AND disasters: E summons/steers a storm, R quakes the earth,
-- F floods a tsunami. Q keeps her signature fireball.
Kits["Infinity"] = { style = "storm", styleKey = "infinity elements storm", abilities = {
	Q = { name = "Fire Ball",      type = "projectile", damage = 22, speed = 120, splashRadius = 7, dotDamage = 3, dotDuration = 2, knockback = 28, cooldown = 4 },
	E = { name = "Command Storm",  type = "stormcontrol", radius = 24, duration = 9, strikeDamage = 14, strikeRate = 1.1, stormKind = "storm", controlRange = 65, moveSpeed = 42, maxRadius = 44, extend = 7, range = 90, cooldown = 14, energy = 40 },
	R = { name = "Earthquake",     type = "disaster", disaster = "earthquake", radius = 22, duration = 5, tickDamage = 8, tickRate = 0.55, stunDuration = 0.7, cooldown = 24, energy = 45 },
	F = { name = "Tsunami",        type = "disaster", disaster = "tsunami", damage = 32, width = 30, height = 16, speed = 44, distance = 78, knockback = 80, cooldown = 26, energy = 50 },
}}

-- LIBERTY — "the power to control storms." The dedicated storm-master: E is
-- the create-OR-command ability (brews a thunderstorm, or seizes and steers the
-- nearest existing one and doubles its intensity), R is a tornado disaster.
-- She can hijack ANY live storm on the field — including an enemy's.
Kits["Liberty"] = { style = "storm", styleKey = "liberty storm lightning", abilities = {
	Q = { name = "Lightning Bolt", type = "chain", damage = 24, jumps = 1, range = 45, stunDuration = 0.5, cooldown = 5 },
	E = { name = "Command Storm",  type = "stormcontrol", radius = 24, duration = 9, strikeDamage = 15, strikeRate = 1, stormKind = "storm", controlRange = 70, moveSpeed = 45, maxRadius = 46, extend = 7, range = 95, cooldown = 12, energy = 35 },
	R = { name = "Tornado",        type = "disaster", disaster = "tornado", radius = 15, duration = 6, tickDamage = 7, tickRate = 0.4, pull = 70, lift = 58, travel = 36, moveSpeed = 12, cooldown = 22, energy = 45 },
	F = { name = "Chain Lightning", type = "chain", damage = 18, jumps = 5, jumpRange = 20, falloff = 0.82, range = 40, cooldown = 12, energy = 40 },
}}

-- BATTLE SQUID — massive mace that controls lightning.
Kits["Battle Squid"] = { style = "storm", styleKey = "battle squid lightning", abilities = {
	Q = { name = "Mace Swing",     type = "melee", range = 7, size = V(9, 8, 7), damage = 28, knockback = 45, cooldown = 4 },
	E = { name = "Charged Smash",  type = "slam", radius = 13, damage = 26, knockback = 40, stunDuration = 0.8, cooldown = 9 },
	R = { name = "Chain Lightning", type = "chain", damage = 18, jumps = 4, jumpRange = 18, range = 40, cooldown = 9 },
	F = { name = "Tentacle Lash",  type = "tendrils", count = 4, duration = 6, range = 22, tickDamage = 6, tickRate = 0.7, follow = true, cooldown = 16 },
}}

-- ALIEN X — strength/speed/flight, lightning from body, telekinesis.
Kits["Alien X"] = { style = "storm", styleKey = "alienx lightning", abilities = {
	Q = { name = "Charged Fist",   type = "melee", range = 6, damage = 26, knockback = 45, up = 15, cooldown = 4 },
	E = { name = "Lightning Bolt", type = "chain", damage = 22, jumps = 2, jumpRange = 16, range = 42, stunDuration = 0.5, cooldown = 6 },
	R = { name = "Telekinetic Throw", type = "force", mode = "push", radius = 16, strength = 105, damage = 18, upBoost = 32, cooldown = 8 },
	F = { name = "Storm Nova",     type = "aoe", radius = 17, damage = 34, knockback = 50, up = 25, cooldown = 16 },
}}

-- BEAST — sacrifices abilities for 1000x strength, huge jumps, absorbs electricity.
Kits["Beast"] = { style = "storm", styleKey = "beast electric", abilities = {
	Q = { name = "Brutal Smash",  type = "melee", range = 6.5, damage = 34, knockback = 65, up = 20, cooldown = 4 },
	E = { name = "Seismic Leap",  type = "slam", leap = true, radius = 16, damage = 32, knockback = 50, up = 30, cooldown = 10 },
	R = { name = "Charge Up",     type = "buff", stat = "damageMult", amount = 1.6, duration = 8, cooldown = 22 },
	F = { name = "Rampage",       type = "aoe", radius = 16, damage = 40, knockback = 60, up = 30, stunDuration = 0.8, cooldown = 18, energy = 45 },
}}

-- RED EYE — duplication, teleportation, laser eyes, strength, flight, absorption.
Kits["Red Eye"] = { style = "energy", styleKey = "redeye laser", color = Color3.fromRGB(255, 40, 40), abilities = {
	Q = { name = "Laser Eyes",   type = "barrage", count = 2, interval = 0.12, spread = 3, damage = 18, speed = 170, size = V(1.1, 1.1, 1.1), knockback = 20, cooldown = 5 },
	E = { name = "Blink",        type = "teleport", range = 42, damage = 18, radius = 7, knockback = 30, cooldown = 6 },
	R = { name = "Duplicate",    type = "clones", count = 2, duration = 10, health = 55, cooldown = 22 },
	F = { name = "Absorb Blast", type = "beam", tickDamage = 6, tickRate = 0.25, range = 60, lifesteal = 0.5, energyPerSecond = 10, maxDuration = 6, cooldown = 1 },
}}

-- VOLT — first rift-stone user: reality manipulation, teleport, strength, phase, flight, invisibility.
Kits["Volt"] = { style = "energy", styleKey = "volt rift reality", abilities = {
	Q = { name = "Rift Bolt",   type = "projectile", damage = 24, speed = 145, size = V(2.5, 2.5, 2.5), knockback = 35, cooldown = 4 },
	E = { name = "Rift Step",   type = "teleport", range = 48, cooldown = 6 },
	R = { name = "Phase Shift", type = "phase", duration = 2, speedMult = 1.4, cooldown = 16 },
	F = { name = "Reality Nova", type = "aoe", radius = 16, damage = 36, knockback = 52, up = 25, cooldown = 18, energy = 45 },
}}

-- RED EYE variants that trade abilities/kits: PHASE & GHOST.
Kits["Phase"] = { style = "energy", styleKey = "phase intangible", abilities = {
	Q = { name = "Heavy Punch", type = "melee", range = 6, damage = 26, knockback = 45, up = 15, cooldown = 4 },
	E = { name = "Phase Dash",  type = "dash", distance = 34, damage = 22, knockback = 28, cooldown = 6 },
	R = { name = "Intangible",  type = "phase", duration = 1.8, speedMult = 1.4, cooldown = 14 },
	F = { name = "Ground Pound", type = "slam", radius = 13, damage = 28, knockback = 42, up = 22, cooldown = 11 },
}}
Kits["Ghost"] = { style = "shadow", styleKey = "ghost invisible", abilities = {
	Q = { name = "Spectral Punch", type = "melee", range = 6, damage = 24, knockback = 40, up = 15, cooldown = 4 },
	E = { name = "Teleport",       type = "teleport", range = 42, cooldown = 6 },
	R = { name = "Vanish",         type = "phase", duration = 2.4, transparency = 0.92, speedMult = 1.3, cooldown = 18 },
	F = { name = "Haunt Slam",     type = "slam", radius = 13, damage = 26, knockback = 40, up = 20, cooldown = 11 },
}}

-- WILDCARD — makes things explode on touch, portals, teleport, good fortune.
Kits["Wildcard"] = { style = "energy", styleKey = "wildcard explode", color = Color3.fromRGB(0, 220, 220), abilities = {
	Q = { name = "Explosive Touch", type = "melee", range = 4.5, damage = 22, knockback = 40, up = 15, cooldown = 4 },
	E = { name = "Detonation",      type = "projectile", damage = 24, speed = 120, size = V(2.4, 2.4, 2.4), splashRadius = 9, knockback = 40, cooldown = 5 },
	R = { name = "Portal Step",     type = "teleport", range = 55, cooldown = 6 },
	F = { name = "House Edge",      type = "buff", stat = "damageMult", amount = 1.5, duration = 8, cooldown = 20 },
}}

-- WILD STYLE — "god of torture": strength, speed, ultanium claws, regen.
Kits["Wild Style"] = { style = "physical", styleKey = "wildstyle claws", abilities = {
	Q = { name = "Claw Flurry",  type = "melee", hits = 5, hitInterval = 0.09, range = 5.5, damage = 8, knockback = 10, cooldown = 5 },
	E = { name = "Lunge Slash",  type = "dash", distance = 30, damage = 24, knockback = 30, cooldown = 6 },
	R = { name = "Regenerate",   type = "buff", stat = "heal", amount = 45, cooldown = 20 },
	F = { name = "Torture Frenzy", type = "melee", hits = 8, hitInterval = 0.08, range = 5.5, damage = 7, knockback = 8, lifesteal = 0.3, cooldown = 14, energy = 40 },
}}
-- APEX — bultranium claws, enhanced senses, strength, speed.
Kits["Apex"] = { style = "physical", styleKey = "apex claws", abilities = {
	Q = { name = "Claw Flurry",  type = "melee", hits = 4, hitInterval = 0.1, range = 5.5, damage = 9, knockback = 12, cooldown = 5 },
	E = { name = "Pounce",       type = "dash", distance = 32, damage = 24, knockback = 30, up = 12, cooldown = 6 },
	R = { name = "Heightened Senses", type = "buff", stat = "walkSpeed", amount = 1.5, duration = 6, cooldown = 16 },
	F = { name = "Savage Rend",  type = "melee", hits = 6, hitInterval = 0.08, range = 5.5, damage = 8, knockback = 10, cooldown = 12 },
}}

-- SCREAM — metallic demon: strength, flight, speed, claws.
Kits["Scream"] = { style = "shadow", styleKey = "scream demon", abilities = {
	Q = { name = "Claw Strike", type = "melee", range = 6, damage = 26, knockback = 40, up = 15, cooldown = 4 },
	E = { name = "Demon Dive",  type = "dash", distance = 36, damage = 24, knockback = 35, up = 12, cooldown = 7 },
	R = { name = "Terror Screech", type = "force", mode = "push", radius = 16, strength = 90, damage = 18, stunDuration = 0.7, cooldown = 9 },
	F = { name = "Wing Slam",   type = "slam", leap = true, radius = 14, damage = 30, knockback = 45, up = 25, cooldown = 12 },
}}

-- RYNOX THE CONQUEROR — super strength, flight, insane durability.
Kits["Rynox"] = { style = "physical", styleKey = "rynox conqueror", color = Color3.fromRGB(220, 40, 40), abilities = {
	Q = { name = "Conqueror's Fist", type = "melee", range = 6, damage = 30, knockback = 58, up = 18, cooldown = 4 },
	E = { name = "Flying Charge",    type = "dash", distance = 42, damage = 26, knockback = 48, up = 16, cooldown = 7 },
	R = { name = "Iron Will",        type = "shield", duration = 6, block = 0.8, radius = 8, cooldown = 18 },
	F = { name = "Conquest Slam",    type = "slam", radius = 16, damage = 34, knockback = 50, up = 28, cooldown = 12 },
}}

-- CAPED CRUSADER — shadow blade, super strength.
Kits["Caped Crusader"] = { style = "shadow", styleKey = "caped crusader shadow blade", abilities = {
	Q = { name = "Shadow Slash",  type = "melee", range = 7, size = V(9, 8, 7), damage = 26, knockback = 40, cooldown = 4 },
	E = { name = "Shadow Wave",   type = "projectile", damage = 22, speed = 150, size = V(2.8, 1.5, 2.8), knockback = 32, cooldown = 5 },
	R = { name = "Blade Dash",    type = "dash", distance = 32, damage = 24, knockback = 30, cooldown = 7 },
	F = { name = "Shadow Barrage", type = "barrage", count = 5, interval = 0.1, spread = 6, damage = 9, speed = 150, size = V(1.4, 1, 1.4), cooldown = 10 },
}}

-- BONE CRUSHER — super strength + spiked bone shields.
Kits["Bone Crusher"] = { style = "physical", styleKey = "bonecrusher bone", abilities = {
	Q = { name = "Bone Bash",    type = "melee", range = 6, damage = 28, knockback = 48, up = 16, cooldown = 4 },
	E = { name = "Bone Spikes",  type = "barrage", count = 4, interval = 0.1, spread = 6, damage = 11, speed = 135, size = V(1.3, 1.3, 1.3), knockback = 18, cooldown = 6 },
	R = { name = "Bone Guard",   type = "shield", duration = 5, block = 0.8, radius = 7, cooldown = 16 },
	F = { name = "Shield Charge", type = "dash", distance = 34, damage = 26, knockback = 45, up = 12, cooldown = 8 },
}}

-- IRON PIRATE — indestructible armor, giant mech, super strength.
Kits["Iron Pirate"] = { style = "physical", styleKey = "iron pirate armor", abilities = {
	Q = { name = "Iron Fist",    type = "melee", range = 6, damage = 28, knockback = 52, up = 16, cooldown = 4 },
	E = { name = "Cannon Shot",  type = "projectile", damage = 24, speed = 120, size = V(3, 3, 3), splashRadius = 8, knockback = 40, cooldown = 6 },
	R = { name = "Indestructible", type = "shield", duration = 6, block = 0.85, radius = 8, cooldown = 20 },
	F = { name = "Pirate Mech",  type = "turret", duration = 14, fireRate = 0.7, damage = 10, range = 48, projectileSpeed = 130, scale = 1.8, cooldown = 24, energy = 45 },
}}

-- BARBARIAN — Spartan, mace, strong, durable. (El Primo Libre shares this feel.)
Kits["Barbarian"] = { style = "physical", styleKey = "barbarian mace", abilities = {
	Q = { name = "Mace Swing",   type = "melee", range = 7, size = V(9, 8, 7), damage = 28, knockback = 45, cooldown = 4 },
	E = { name = "War Cry",      type = "buff", stat = "damageMult", amount = 1.4, duration = 6, cooldown = 16 },
	R = { name = "Ground Smash", type = "slam", radius = 14, damage = 28, knockback = 42, up = 22, cooldown = 10 },
	F = { name = "Berserk Charge", type = "dash", distance = 36, damage = 26, knockback = 45, up = 12, cooldown = 8 },
}}
Kits["El Primo Libre"] = { style = "gold", styleKey = "primo wrestler gold", abilities = {
	Q = { name = "Golden Knuckle", type = "melee", range = 6, damage = 28, knockback = 50, up = 16, cooldown = 4 },
	E = { name = "Grapple",        type = "bind", range = 20, duration = 1.6, damage = 16, launchUp = 90, cooldown = 9 },
	R = { name = "Body Slam",      type = "slam", leap = true, radius = 13, damage = 30, knockback = 45, up = 25, cooldown = 11 },
	F = { name = "Wrestler's Rage", type = "buff", stat = "damageMult", amount = 1.5, duration = 7, cooldown = 20 },
}}
Kits["Ares"] = Kits["Barbarian"]
Kits["Kratos"] = { style = "physical", styleKey = "kratos god butcher", abilities = {
	Q = { name = "Blade Sweep",  type = "melee", range = 8, size = V(11, 8, 8), damage = 28, knockback = 42, cooldown = 4 },
	E = { name = "Chain Pull",   type = "force", mode = "pull", radius = 22, strength = 100, damage = 14, cooldown = 7 },
	R = { name = "Spartan Rage", type = "buff", stat = "damageMult", amount = 1.6, duration = 7, cooldown = 22 },
	F = { name = "Rage Slam",    type = "slam", radius = 16, damage = 36, knockback = 55, up = 30, cooldown = 13, energy = 40 },
}}

-- CHAMPION — best marksman: sniper, grenades, pistol, stab.
Kits["Champion"] = { style = "physical", styleKey = "champion marksman", abilities = {
	Q = { name = "Pistol Shots", type = "barrage", count = 3, interval = 0.1, spread = 3, damage = 12, speed = 200, size = V(0.8, 0.8, 0.8), knockback = 10, cooldown = 4 },
	E = { name = "Sniper Shot",  type = "projectile", damage = 40, speed = 260, size = V(0.9, 0.9, 0.9), knockback = 30, cooldown = 7 },
	R = { name = "Grenade",      type = "projectile", damage = 26, speed = 90, size = V(1.4, 1.4, 1.4), splashRadius = 10, knockback = 45, cooldown = 8 },
	F = { name = "Combat Knife", type = "melee", range = 5, damage = 24, knockback = 20, cooldown = 5 },
}}
-- KUNAI — ninja with kunai and shurikens.
Kits["Kunai"] = { style = "physical", styleKey = "kunai ninja shuriken", abilities = {
	Q = { name = "Shuriken Toss", type = "barrage", count = 4, interval = 0.08, spread = 6, damage = 9, speed = 175, size = V(0.9, 0.9, 0.9), knockback = 10, cooldown = 4 },
	E = { name = "Kunai Throw",   type = "projectile", damage = 20, speed = 190, size = V(0.8, 0.8, 0.8), knockback = 18, cooldown = 4 },
	R = { name = "Smoke Vanish",  type = "phase", duration = 2, transparency = 0.9, speedMult = 1.4, cooldown = 16 },
	F = { name = "Blade Flurry",  type = "melee", hits = 5, hitInterval = 0.09, range = 5, damage = 8, knockback = 10, cooldown = 8 },
}}
-- 2Z — super speed + 4 spider legs.
Kits["2z"] = { style = "energy", styleKey = "2z speed spider", abilities = {
	Q = { name = "Leg Flurry",   type = "melee", hits = 4, hitInterval = 0.1, range = 6, damage = 9, knockback = 14, cooldown = 5 },
	E = { name = "Speed Dash",   type = "dash", distance = 42, damage = 20, knockback = 28, cooldown = 5 },
	R = { name = "Web Pin",      type = "bind", range = 26, duration = 2.2, damage = 12, cooldown = 10 },
	F = { name = "Cyclone Rush", type = "zone", atSelf = true, radius = 10, duration = 2, tickDamage = 7, tickRate = 0.3, cooldown = 12 },
}}

-- WATER / STORM / ELEMENT extra gods, monsters, and utility fighters
Kits["Toxic"] = { style = "nature", styleKey = "toxic poison acid", abilities = {
	Q = { name = "Acid Spray",   type = "breath", duration = 2, range = 18, angle = 30, tickDamage = 5, tickRate = 0.22, dotDamage = 4, dotDuration = 3, cooldown = 8 },
	E = { name = "Poison Bolt",  type = "projectile", damage = 16, speed = 125, size = V(2.2, 2.2, 2.2), dotDamage = 5, dotDuration = 4, knockback = 22, cooldown = 5 },
	R = { name = "Poison Cloud", type = "zone", radius = 15, duration = 7, tickDamage = 5, tickRate = 0.5, dotDamage = 3, dotDuration = 2, slowAmount = 0.3, cooldown = 20 },
	F = { name = "Toxic Nova",   type = "aoe", radius = 15, damage = 26, knockback = 30, dotDamage = 5, dotDuration = 4, cooldown = 18 },
}}

-- ROCKY / ECHO — sound: cosmic guitar blasts, reality warp by frequency.
Kits["Rocky"] = { style = "energy", styleKey = "rocky echo sound sonic", abilities = {
	Q = { name = "Sound Blast",  type = "projectile", damage = 22, speed = 150, size = V(3, 2, 3), knockback = 40, cooldown = 4 },
	E = { name = "Sonic Scream", type = "breath", duration = 1.8, range = 20, angle = 36, tickDamage = 6, tickRate = 0.22, knockback = 8, cooldown = 8 },
	R = { name = "Shockwave Riff", type = "force", mode = "push", radius = 18, strength = 100, damage = 20, stunDuration = 0.6, cooldown = 9 },
	F = { name = "Frequency Break", type = "aoe", radius = 17, damage = 34, knockback = 50, up = 25, stunDuration = 0.7, cooldown = 18, energy = 45 },
}}
Kits["Echo"] = Kits["Rocky"]

-- GREEN GRENADE — explode objects, blasts from body.
Kits["Green Grenade"] = { style = "nature", styleKey = "green grenade explode", color = Color3.fromRGB(90, 220, 90), abilities = {
	Q = { name = "Explosive Bolt", type = "projectile", damage = 22, speed = 125, size = V(2.2, 2.2, 2.2), splashRadius = 8, knockback = 38, cooldown = 4 },
	E = { name = "Body Blast",     type = "aoe", radius = 13, damage = 24, knockback = 45, up = 20, cooldown = 7 },
	R = { name = "Grenade Volley", type = "barrage", count = 4, interval = 0.14, spread = 8, damage = 12, speed = 95, size = V(1.4, 1.4, 1.4), splashRadius = 6, cooldown = 9 },
	F = { name = "Critical Overload", type = "aoe", radius = 18, damage = 45, knockback = 65, up = 30, cooldown = 26, energy = 50 },
}}

-- MIDAS — turns things to gold by touch (bind + gold visual).
Kits["Midas"] = { style = "gold", styleKey = "midas gold touch", abilities = {
	Q = { name = "Golden Touch", type = "melee", range = 4.5, damage = 14, stunDuration = 1.5, knockback = 10, cooldown = 6 },
	E = { name = "Gold Bolt",    type = "projectile", damage = 22, speed = 135, size = V(2.3, 2.3, 2.3), stunEvery = 3, knockback = 25, cooldown = 4 },
	R = { name = "Gild",         type = "bind", range = 26, duration = 3, damage = 16, cooldown = 12 },
	F = { name = "Golden Prison", type = "bind", range = 30, radius = 12, duration = 2.6, damage = 14, cooldown = 22, energy = 45 },
}}

-- METAMORPH — changes state of matter (versatile buff/phase fighter).
Kits["Metamorph"] = { style = "energy", styleKey = "metamorph matter", abilities = {
	Q = { name = "Solid Fist",   type = "melee", range = 6, damage = 24, knockback = 40, up = 15, cooldown = 4 },
	E = { name = "Liquid Bolt",  type = "projectile", damage = 20, speed = 130, size = V(2.3, 2.3, 2.3), knockback = 28, cooldown = 4 },
	R = { name = "Gas Form",     type = "phase", duration = 2, transparency = 0.85, speedMult = 1.4, cooldown = 16 },
	F = { name = "Hardened Guard", type = "shield", duration = 5, block = 0.8, radius = 7, cooldown = 18 },
}}

-- MONSTER BOY — shapeshifts into monsters (rage striker). Scar = king of monsters.
Kits["Monster Boy"] = { style = "nature", styleKey = "monster shapeshift", abilities = {
	Q = { name = "Beast Claw",   type = "melee", hits = 3, hitInterval = 0.12, range = 6, damage = 11, knockback = 16, cooldown = 5 },
	E = { name = "Lunge",        type = "dash", distance = 32, damage = 24, knockback = 32, up = 12, cooldown = 6 },
	R = { name = "Monstrous Roar", type = "force", mode = "push", radius = 16, strength = 90, damage = 16, stunDuration = 0.7, cooldown = 9 },
	F = { name = "Transform",    type = "buff", stat = "damageMult", amount = 1.6, duration = 8, cooldown = 24 },
}}
Kits["Scar"] = Kits["Monster Boy"]
-- THE ANACONDA — omnipotent creature, divine powers.
Kits["The Anaconda"] = { style = "cosmic", styleKey = "anaconda divine", abilities = {
	Q = { name = "Divine Bolt",  type = "projectile", damage = 28, speed = 155, size = V(3, 3, 3), knockback = 42, cooldown = 4 },
	E = { name = "Divine Beam",  type = "beam", tickDamage = 8, tickRate = 0.2, range = 80, energyPerSecond = 11, maxDuration = 6, cooldown = 1 },
	R = { name = "Divine Ward",  type = "shield", duration = 6, block = 0.88, radius = 9, cooldown = 20 },
	F = { name = "Divine Judgment", type = "strike", mode = "laser", count = 3, interval = 0.3, delay = 0.7, radius = 11, damage = 34, knockback = 45, cooldown = 24, energy = 55 },
}}

-- VALKERY — super strength, runs fast.
Kits["Valkery"] = { style = "storm", styleKey = "valkery warrior", abilities = {
	Q = { name = "Spear Thrust", type = "melee", range = 7, damage = 26, knockback = 42, up = 15, cooldown = 4 },
	E = { name = "Valkyrie Rush", type = "dash", distance = 38, damage = 24, knockback = 35, cooldown = 6 },
	R = { name = "Spear Throw",  type = "projectile", damage = 26, speed = 170, size = V(1, 1, 4), knockback = 35, cooldown = 6 },
	F = { name = "War Slam",     type = "slam", radius = 14, damage = 30, knockback = 45, up = 25, cooldown = 12 },
}}

-- WIPEOUT — blasts from chest/body, absorption.
Kits["Wipeout"] = { style = "energy", styleKey = "wipeout blast absorb", abilities = {
	Q = { name = "Chest Blast",  type = "projectile", damage = 24, speed = 130, size = V(3, 3, 3), knockback = 50, cooldown = 5 },
	E = { name = "Body Burst",   type = "aoe", radius = 13, damage = 22, knockback = 42, up = 18, cooldown = 7 },
	R = { name = "Absorb Beam",  type = "beam", tickDamage = 6, tickRate = 0.25, range = 60, lifesteal = 0.5, energyPerSecond = 10, maxDuration = 6, cooldown = 1 },
	F = { name = "Overload Blast", type = "aoe", radius = 17, damage = 38, knockback = 58, up = 28, cooldown = 20, energy = 45 },
}}
-- ATOM's father FISSION already done; ADAM's radiation covered. RADIATION twins.

-- POWERNOID — Manderin's old power armor: strength + weapons.
Kits["Powernoid"] = { style = "energy", styleKey = "powernoid armor", abilities = {
	Q = { name = "Armor Punch",  type = "melee", range = 6, damage = 26, knockback = 48, up = 16, cooldown = 4 },
	E = { name = "Arm Cannon",   type = "projectile", damage = 24, speed = 130, size = V(2.6, 2.6, 2.6), splashRadius = 6, knockback = 38, cooldown = 5 },
	R = { name = "Armor Field",  type = "shield", duration = 5, block = 0.8, radius = 8, cooldown = 18 },
	F = { name = "Missile Barrage", type = "barrage", count = 5, interval = 0.15, spread = 8, damage = 12, speed = 105, size = V(1.4, 1.4, 1.4), splashRadius = 6, cooldown = 12 },
}}

-- PUNISHER — omega strength/durability/flight + red lightning that removes powers.
Kits["Punisher"] = { style = "storm", styleKey = "punisher red lightning", color = Color3.fromRGB(220, 30, 30), abilities = {
	Q = { name = "Omega Fist",   type = "melee", range = 6, damage = 30, knockback = 58, up = 18, cooldown = 4 },
	E = { name = "Red Lightning", type = "chain", damage = 22, jumps = 3, jumpRange = 18, range = 42, stunDuration = 1, cooldown = 7 },
	R = { name = "Flight Charge", type = "dash", distance = 42, damage = 24, knockback = 45, up = 16, cooldown = 8 },
	F = { name = "Power Nullifier", type = "projectile", damage = 28, speed = 140, size = V(3, 3, 3), stunDuration = 1.6, knockback = 40, cooldown = 22, energy = 45 },
}}

-- COCKROACH — strength + adapts to attacks (defensive counter fighter).
Kits["Cockroach"] = { style = "nature", styleKey = "cockroach adapt", abilities = {
	Q = { name = "Chitin Strike", type = "melee", range = 6, damage = 24, knockback = 38, up = 14, cooldown = 4 },
	E = { name = "Skitter Dash",  type = "dash", distance = 34, damage = 20, knockback = 28, cooldown = 6 },
	R = { name = "Adapt",         type = "shield", duration = 6, block = 0.8, radius = 7, cooldown = 18 },
	F = { name = "Counter Reflex", type = "counter", duration = 1.6, reflect = 1.4, cooldown = 13 },
}}

-- HELA — she heals. ALIEN JESUS heals too. Support kit.
Kits["Hela"] = { style = "nature", styleKey = "hela heal", color = Color3.fromRGB(120, 255, 150), abilities = {
	Q = { name = "Bolt",         type = "projectile", damage = 18, speed = 130, size = V(2.2, 2.2, 2.2), knockback = 25, cooldown = 4 },
	E = { name = "Heal Pulse",   type = "buff", stat = "heal", amount = 40, cooldown = 12 },
	R = { name = "Regen Field",  type = "zone", atSelf = true, radius = 14, duration = 6, healPerTick = 5, tickRate = 0.6, cooldown = 20 },
	F = { name = "Restoration",  type = "buff", stat = "heal", amount = 80, cooldown = 30, energy = 45 },
}}
Kits["Alien Jesus"] = Kits["Hela"]
Kits["Paranorm"] = { style = "shadow", styleKey = "paranorm ghost dead", abilities = {
	Q = { name = "Spirit Bolt",  type = "projectile", damage = 22, speed = 135, size = V(2.3, 2.3, 2.3), knockback = 28, cooldown = 4 },
	E = { name = "Ghost Grip",   type = "bind", range = 26, duration = 2.2, dps = 8, cooldown = 10 },
	R = { name = "Possession",   type = "buff", stat = "damageMult", amount = 1.5, duration = 7, cooldown = 20 },
	F = { name = "Revive Pulse", type = "buff", stat = "heal", amount = 70, cooldown = 30, energy = 45 },
}}

-- BLUE — Chasm's father: energy, blue tentacles, force fields, teleport, cosmic energy.
Kits["Blue"] = { style = "energy", styleKey = "blue energy cosmic", abilities = {
	Q = { name = "Energy Bolt",   type = "projectile", damage = 24, speed = 145, size = V(2.5, 2.5, 2.5), knockback = 35, cooldown = 4 },
	E = { name = "Blue Tentacles", type = "tendrils", count = 4, duration = 6, range = 22, tickDamage = 6, tickRate = 0.7, follow = true, cooldown = 14 },
	R = { name = "Force Field",   type = "shield", duration = 6, block = 0.82, radius = 8, cooldown = 18 },
	F = { name = "Cosmic Teleport", type = "teleport", range = 50, damage = 20, radius = 8, knockback = 32, cooldown = 8 },
}}

-- BARRIER BOY — indestructible barriers and force fields on self or others.
Kits["Barrier Boy"] = { style = "energy", styleKey = "barrier boy shield", color = Color3.fromRGB(120, 200, 255), abilities = {
	Q = { name = "Barrier Bash", type = "melee", range = 6, damage = 22, knockback = 45, up = 15, cooldown = 4 },
	E = { name = "Barrier Wall", type = "wall", width = 16, height = 10, thickness = 2.5, duration = 8, cooldown = 8 },
	R = { name = "Self Domain",  type = "shield", duration = 6, block = 0.9, radius = 7, cooldown = 20 },
	F = { name = "Crushing Cage", type = "bind", range = 28, radius = 12, duration = 2.6, damage = 14, cooldown = 22, energy = 45 },
}}

-- THE COLLECTOR — portals, super strength.
Kits["The Collector"] = { style = "cosmic", styleKey = "collector portal", abilities = {
	Q = { name = "Heavy Punch",  type = "melee", range = 6, damage = 26, knockback = 48, up = 16, cooldown = 4 },
	E = { name = "Portal Bolt",  type = "projectile", damage = 22, speed = 140, size = V(2.4, 2.4, 2.4), knockback = 32, cooldown = 4 },
	R = { name = "Portal Step",  type = "teleport", range = 55, cooldown = 6 },
	F = { name = "Collection Pull", type = "force", mode = "pull", radius = 20, strength = 95, damage = 16, cooldown = 10 },
}}

-- BLUE JAY — falcon + iron-man Ram Tech suit.
Kits["Blue Jay"] = { style = "energy", styleKey = "bluejay tech flight", color = Color3.fromRGB(60, 140, 255), abilities = {
	Q = { name = "Wing Blades",  type = "barrage", count = 4, interval = 0.09, spread = 6, damage = 9, speed = 165, size = V(1, 1, 1), knockback = 12, cooldown = 4 },
	E = { name = "Repulsor",     type = "projectile", damage = 24, speed = 140, size = V(2.4, 2.4, 2.4), knockback = 40, cooldown = 5 },
	R = { name = "Dive Bomb",    type = "slam", leap = true, radius = 13, damage = 28, knockback = 42, up = 22, cooldown = 11 },
	F = { name = "Missile Lock", type = "barrage", count = 5, interval = 0.14, spread = 7, damage = 12, speed = 110, size = V(1.3, 1.3, 1.3), splashRadius = 6, cooldown = 12 },
}}
-- YELLOW JACKET — shrink and fly Ram Tech suit.
Kits["Yellow Jacket"] = { style = "gold", styleKey = "yellowjacket shrink", abilities = {
	Q = { name = "Sting Barrage", type = "barrage", count = 5, interval = 0.08, spread = 8, damage = 7, speed = 170, size = V(0.8, 0.8, 0.8), knockback = 8, cooldown = 4 },
	E = { name = "Shrink Dash",   type = "dash", distance = 34, damage = 18, knockback = 24, cooldown = 5 },
	R = { name = "Tiny Vanish",   type = "phase", duration = 2, transparency = 0.92, speedMult = 1.4, cooldown = 16 },
	F = { name = "Grow Slam",     type = "slam", radius = 13, damage = 30, knockback = 45, up = 25, cooldown = 12 },
}}
-- BULLDOZER — stolen Ram Clan dozer armor.
Kits["Bulldozer"] = { style = "physical", styleKey = "bulldozer armor", abilities = {
	Q = { name = "Dozer Punch",  type = "melee", range = 6, damage = 28, knockback = 55, up = 16, cooldown = 4 },
	E = { name = "Plow Charge",  type = "dash", distance = 38, damage = 26, knockback = 50, up = 12, cooldown = 7 },
	R = { name = "Dozer Guard",  type = "shield", duration = 5, block = 0.82, radius = 8, cooldown = 18 },
	F = { name = "Crushing Slam", type = "slam", radius = 15, damage = 32, knockback = 48, up = 26, cooldown = 12 },
}}

-- SLIMEY — a man made of slime.
Kits["Slimey"] = { style = "nature", styleKey = "slime goo", color = Color3.fromRGB(120, 220, 90), abilities = {
	Q = { name = "Slime Punch",  type = "melee", range = 6, damage = 22, knockback = 35, slowAmount = 0.5, cooldown = 4 },
	E = { name = "Goo Blob",     type = "projectile", damage = 18, speed = 110, size = V(2.6, 2.6, 2.6), slowAmount = 0.5, slowDuration = 2, knockback = 20, cooldown = 5 },
	R = { name = "Slime Pool",   type = "zone", radius = 14, duration = 6, tickDamage = 4, tickRate = 0.5, slowAmount = 0.5, cooldown = 18 },
	F = { name = "Absorb Reform", type = "phase", duration = 1.6, transparency = 0.75, cooldown = 16 },
}}

-- THE SQUELCH — absorbs liquids and shoots them from fingertips.
Kits["The Squelch"] = { style = "water", styleKey = "squelch liquid", abilities = {
	Q = { name = "Liquid Jet",   type = "breath", duration = 1.8, range = 18, angle = 22, tickDamage = 5, tickRate = 0.22, knockback = 6, cooldown = 7 },
	E = { name = "Pressure Shot", type = "projectile", damage = 22, speed = 150, size = V(1.8, 1.8, 1.8), knockback = 40, cooldown = 5 },
	R = { name = "Water Barrier", type = "wall", width = 14, height = 9, thickness = 2.5, duration = 7, cooldown = 9 },
	F = { name = "Flood Burst",  type = "force", mode = "push", radius = 16, strength = 95, damage = 20, cooldown = 12 },
}}

-- HERM THE WORM / CHEESEMAN / BUTCHER — Circus gang oddballs, playable kits.
Kits["Herm the Worm"] = { style = "nature", styleKey = "worm burrow", abilities = {
	Q = { name = "Worm Whip",    type = "tendrils", count = 3, duration = 5, range = 20, tickDamage = 5, tickRate = 0.7, cooldown = 12 },
	E = { name = "Burrow Bolt",  type = "projectile", damage = 20, speed = 120, size = V(2.2, 2.2, 2.2), knockback = 25, cooldown = 4 },
	R = { name = "Ground Grip",  type = "bind", range = 24, duration = 2.2, dps = 7, cooldown = 10 },
	F = { name = "Swarm",        type = "zone", radius = 14, duration = 6, tickDamage = 5, tickRate = 0.5, cooldown = 18 },
}}
Kits["Cheeseman"] = { style = "gold", styleKey = "cheese ray", color = Color3.fromRGB(255, 210, 60), abilities = {
	Q = { name = "Cheese Ray",   type = "beam", tickDamage = 5, tickRate = 0.25, range = 55, slowAmount = 0.4, slowDuration = 1, energyPerSecond = 8, maxDuration = 6, cooldown = 1 },
	E = { name = "Cheese Wheel", type = "projectile", damage = 20, speed = 120, size = V(2.6, 2.6, 2.6), knockback = 30, cooldown = 5 },
	R = { name = "Cheese Wall",  type = "wall", width = 14, height = 8, thickness = 2.5, duration = 7, cooldown = 9 },
	F = { name = "Fondue Pool",  type = "zone", radius = 13, duration = 6, tickDamage = 5, tickRate = 0.5, slowAmount = 0.5, cooldown = 18 },
}}
Kits["Butcher the Clown"] = { style = "shadow", styleKey = "butcher clown club", abilities = {
	Q = { name = "Club Smash",   type = "melee", range = 7, size = V(9, 8, 7), damage = 26, knockback = 45, cooldown = 4 },
	E = { name = "Clone Decoys", type = "clones", count = 2, duration = 9, health = 50, cooldown = 20 },
	R = { name = "Mad Dash",     type = "dash", distance = 32, damage = 22, knockback = 30, cooldown = 6 },
	F = { name = "Big Top Slam", type = "slam", radius = 14, damage = 30, knockback = 45, up = 25, cooldown = 12 },
}}

-- DAVINCHI JR — drawings come to life (summoner).
Kits["Davinchi Jr"] = { style = "energy", styleKey = "davinchi drawing", abilities = {
	Q = { name = "Ink Bolt",     type = "projectile", damage = 22, speed = 140, size = V(2.4, 2.4, 2.4), knockback = 30, cooldown = 4 },
	E = { name = "Sketch Sentry", type = "turret", duration = 12, fireRate = 0.8, damage = 8, range = 42, projectileSpeed = 135, cooldown = 18 },
	R = { name = "Drawn Wall",   type = "wall", width = 15, height = 9, thickness = 2.5, duration = 7, cooldown = 9 },
	F = { name = "Living Beast", type = "turret", duration = 14, fireRate = 0.7, damage = 10, range = 45, projectileSpeed = 130, scale = 1.6, cooldown = 24, energy = 45 },
}}

-- EDDIE FRANKENBERRIE — what he says comes true (reality striker).
Kits["Eddie Frankenberrie"] = { style = "cosmic", styleKey = "eddie word reality", abilities = {
	Q = { name = "Command Bolt", type = "projectile", damage = 24, speed = 145, size = V(2.5, 2.5, 2.5), knockback = 35, cooldown = 4 },
	E = { name = "Decree",       type = "force", mode = "push", radius = 16, strength = 100, damage = 18, cooldown = 7 },
	R = { name = "Fortify",      type = "shield", duration = 5, block = 0.82, radius = 8, cooldown = 18 },
	F = { name = "Rewrite",      type = "aoe", radius = 16, damage = 36, knockback = 50, up = 25, cooldown = 20, energy = 45 },
}}

-- DANIEL STORM / UNI-MAN — strongest telepath, belief becomes reality.
Kits["Daniel Storm"] = { style = "cosmic", styleKey = "storm telepath mind", abilities = {
	Q = { name = "Psychic Bolt", type = "projectile", damage = 26, speed = 150, size = V(2.6, 2.6, 2.6), knockback = 38, cooldown = 4 },
	E = { name = "Mind Crush",   type = "bind", range = 30, duration = 2.5, dps = 11, cooldown = 11 },
	R = { name = "Absolute Belief", type = "shield", duration = 6, block = 0.9, radius = 9, cooldown = 22, energy = 40 },
	F = { name = "Reality Overwrite", type = "aoe", radius = 18, damage = 46, knockback = 60, up = 30, cooldown = 30, energy = 55 },
}}
Kits["Uni-Man"] = Kits["Daniel Storm"]

-- ORYIOX — electromagnetic manipulation, barriers, energy.
Kits["Oryiox"] = { style = "storm", styleKey = "oryiox electromagnetic", abilities = {
	Q = { name = "EM Bolt",      type = "chain", damage = 22, jumps = 2, jumpRange = 16, range = 42, cooldown = 5 },
	E = { name = "Rail Shot",    type = "projectile", damage = 28, speed = 200, size = V(1, 1, 1), knockback = 35, cooldown = 6 },
	R = { name = "EM Barrier",   type = "shield", duration = 5, block = 0.82, radius = 8, cooldown = 18 },
	F = { name = "Overcharge",   type = "force", mode = "push", radius = 18, strength = 100, damage = 22, stunDuration = 1, cooldown = 12 },
}}

-- CHANNEL — traps people in reflections/screens (shadow trapper).
Kits["Channel"] = { style = "shadow", styleKey = "channel screen reflect", abilities = {
	Q = { name = "Static Bolt",  type = "projectile", damage = 22, speed = 145, size = V(2.4, 2.4, 2.4), knockback = 30, cooldown = 4 },
	E = { name = "Screen Trap",  type = "bind", range = 28, duration = 2.6, damage = 14, cooldown = 11 },
	R = { name = "Glass Wall",   type = "wall", width = 15, height = 9, thickness = 2, duration = 7, cooldown = 9 },
	F = { name = "Reflection Realm", type = "zone", radius = 17, duration = 6, tickDamage = 6, tickRate = 0.5, slowAmount = 0.45, cooldown = 24, energy = 45 },
}}

-- THE ONE WHO LAUGHS — cursed laughter, warps reality (omniversal threat).
Kits["The One Who Laughs"] = { style = "shadow", styleKey = "onewholaughs reality", abilities = {
	Q = { name = "Cackle Bolt", type = "projectile", damage = 24, speed = 145, size = V(2.5, 2.5, 2.5), dotDamage = 3, dotDuration = 2, knockback = 35, cooldown = 4 },
	E = { name = "Madness Grip", type = "bind", range = 28, duration = 2.4, dps = 9, cooldown = 11 },
	R = { name = "Chaos Field",  type = "zone", radius = 18, duration = 7, tickDamage = 7, tickRate = 0.5, slowAmount = 0.4, cooldown = 24, energy = 45 },
	F = { name = "Reality Fracture", type = "aoe", radius = 18, damage = 42, knockback = 58, up = 28, cooldown = 28, energy = 50 },
}}

-- BLOODBATH — the more damage he takes the stronger he gets (bruiser).
Kits["Bloodbath"] = { style = "fire", styleKey = "bloodbath blood rage", color = Color3.fromRGB(190, 20, 20), abilities = {
	Q = { name = "Brutal Smash", type = "melee", range = 6.5, damage = 30, knockback = 55, up = 18, cooldown = 4 },
	E = { name = "Blood Charge", type = "dash", distance = 36, damage = 26, knockback = 45, up = 12, cooldown = 7 },
	R = { name = "Bloodlust",    type = "buff", stat = "damageMult", amount = 1.6, duration = 8, cooldown = 24 },
	F = { name = "Crimson Slam", type = "slam", radius = 15, damage = 34, knockback = 52, up = 28, lifesteal = 0.3, cooldown = 14, energy = 40 },
}}

-- MINUS — alligator-person: massive slash, lunge & slash, flurry, tail whip, chomp.
Kits["Minus"] = { style = "nature", styleKey = "minus alligator", abilities = {
	Q = { name = "Massive Slash", type = "melee", range = 8, size = V(11, 8, 8), damage = 28, knockback = 42, cooldown = 4 },
	E = { name = "Lunge & Slash", type = "dash", distance = 30, damage = 26, knockback = 35, up = 10, cooldown = 6 },
	R = { name = "Tail Whip",     type = "force", mode = "push", radius = 12, strength = 90, damage = 20, knockback = 45, cooldown = 8 },
	F = { name = "Chomp",         type = "melee", range = 5, damage = 34, knockback = 30, stunDuration = 1, cooldown = 9 },
}}

-- PURPURS / THE PURPLE TITAN — giant winged titan with a massive blade.
Kits["Purpurs"] = { style = "shadow", styleKey = "purple titan supremacy", color = Color3.fromRGB(150, 40, 220), abilities = {
	Q = { name = "Titan Cleave", type = "melee", range = 9, size = V(13, 10, 9), damage = 32, knockback = 50, cooldown = 4 },
	E = { name = "Judgment Wave", type = "projectile", damage = 28, speed = 150, size = V(4, 3, 4), splashRadius = 9, knockback = 45, cooldown = 6 },
	R = { name = "Supremacy Guard", type = "shield", duration = 6, block = 0.85, radius = 10, cooldown = 20 },
	F = { name = "Titan Slam",   type = "slam", leap = true, radius = 18, damage = 40, knockback = 60, up = 32, cooldown = 16, energy = 50 },
}}
Kits["The Purple Titan"] = Kits["Purpurs"]

-- PURITIES / MIXERS — cosmic reality-warpers that reshape matter.
Kits["Purities"] = { style = "cosmic", styleKey = "purities cosmic reality", abilities = {
	Q = { name = "Cosmic Bolt",  type = "projectile", damage = 24, speed = 150, size = V(2.6, 2.6, 2.6), knockback = 35, cooldown = 4 },
	E = { name = "Matter Reshape", type = "force", mode = "push", radius = 16, strength = 100, damage = 18, cooldown = 7 },
	R = { name = "Cosmic Ward",  type = "shield", duration = 5, block = 0.85, radius = 8, cooldown = 18 },
	F = { name = "Reality Warp", type = "aoe", radius = 16, damage = 36, knockback = 52, up = 26, cooldown = 22, energy = 45 },
}}
Kits["Mixers"] = Kits["Purities"]

-- SCRAPATRON — giant robot from garbage. ULTRATRON / OMNICRON evil robots.
Kits["Scrapatron"] = { style = "physical", styleKey = "scrapatron robot junk", abilities = {
	Q = { name = "Scrap Smash",  type = "melee", range = 7, damage = 28, knockback = 48, up = 16, cooldown = 4 },
	E = { name = "Junk Toss",    type = "projectile", damage = 22, speed = 110, size = V(3, 3, 3), splashRadius = 7, knockback = 40, cooldown = 6 },
	R = { name = "Scrap Turret", type = "turret", duration = 12, fireRate = 0.8, damage = 8, range = 42, projectileSpeed = 125, scale = 1.5, cooldown = 20 },
	F = { name = "Demolish",     type = "slam", radius = 16, damage = 32, knockback = 50, up = 28, cooldown = 14 },
}}
Kits["Ultratron"] = Kits["Scrapatron"]
Kits["Omnicron"] = { style = "shadow", styleKey = "omnicron robot overlord", abilities = {
	Q = { name = "Overlord Bolt", type = "projectile", damage = 26, speed = 150, size = V(3, 3, 3), splashRadius = 7, knockback = 42, cooldown = 4 },
	E = { name = "Crush Field",   type = "force", mode = "pull", radius = 20, strength = 100, damage = 16, cooldown = 8 },
	R = { name = "Planet Guard",  type = "shield", duration = 6, block = 0.88, radius = 10, cooldown = 22 },
	F = { name = "Annihilation Beam", type = "beam", tickDamage = 11, tickRate = 0.18, range = 90, energyPerSecond = 13, maxDuration = 5, cooldown = 20, energy = 55 },
}}
-- ALIEN — Manderin's AI/organic specimen: controls metal, super strong, scans.
Kits["Alien"] = { style = "physical", styleKey = "alien metal specimen", abilities = {
	Q = { name = "Metal Strike", type = "melee", range = 6, damage = 26, knockback = 45, up = 16, cooldown = 4 },
	E = { name = "Metal Shards", type = "barrage", count = 5, interval = 0.1, spread = 7, damage = 10, speed = 145, size = V(1.2, 1.2, 1.2), knockback = 16, cooldown = 6 },
	R = { name = "Metal Guard",  type = "shield", duration = 5, block = 0.82, radius = 8, cooldown = 18 },
	F = { name = "Magnetize",    type = "force", mode = "pull", radius = 20, strength = 95, damage = 16, cooldown = 10 },
}}

-- JUGGERNAUT ROBOT / JUGGERNAUT — heavily armored bruisers.
Kits["Juggernaut"] = { style = "physical", styleKey = "juggernaut armor", abilities = {
	Q = { name = "Heavy Punch",  type = "melee", range = 6, damage = 30, knockback = 58, up = 16, cooldown = 4 },
	E = { name = "Unstoppable Charge", type = "dash", distance = 40, damage = 28, knockback = 52, up = 12, cooldown = 8 },
	R = { name = "Armor Plating", type = "shield", duration = 6, block = 0.85, radius = 8, cooldown = 20 },
	F = { name = "Quake Slam",   type = "slam", radius = 16, damage = 34, knockback = 50, up = 28, stunDuration = 0.7, cooldown = 13 },
}}
Kits["Juggernaut Robot"] = Kits["Juggernaut"]

-- WOLF — human hunter out to kill supes: gadgets and guns.
Kits["Wolf"] = { style = "physical", styleKey = "wolf hunter gun", abilities = {
	Q = { name = "Rifle Burst",  type = "barrage", count = 3, interval = 0.09, spread = 3, damage = 12, speed = 200, size = V(0.8, 0.8, 0.8), knockback = 10, cooldown = 4 },
	E = { name = "Frag Grenade", type = "projectile", damage = 24, speed = 95, size = V(1.4, 1.4, 1.4), splashRadius = 9, knockback = 42, cooldown = 8 },
	R = { name = "Combat Roll",  type = "dash", distance = 26, damage = 0, cooldown = 6 },
	F = { name = "Knife Combo",  type = "melee", hits = 3, hitInterval = 0.12, range = 5, damage = 12, knockback = 15, cooldown = 6 },
}}

-- VIRGIL — teleport, summon heroes, invisible, shooting.
Kits["Virgil"] = { style = "energy", styleKey = "virgil summon", abilities = {
	Q = { name = "Pistol Shots", type = "barrage", count = 3, interval = 0.1, spread = 3, damage = 12, speed = 190, size = V(0.8, 0.8, 0.8), knockback = 10, cooldown = 4 },
	E = { name = "Summon Ally",  type = "turret", duration = 12, fireRate = 0.8, damage = 8, range = 44, projectileSpeed = 135, cooldown = 18 },
	R = { name = "Teleport",     type = "teleport", range = 46, cooldown = 6 },
	F = { name = "Vanish",       type = "phase", duration = 2.4, transparency = 0.9, speedMult = 1.3, cooldown = 18 },
}}

-- DARK LOONEY — a Looney variant that never holds back (harder-hitting Looney).
Kits["Dark Looney"] = { style = "shadow", styleKey = "dark looney toon", abilities = {
	Q = { name = "Slingshot",    type = "dash", distance = 36, damage = 30, knockback = 55, up = 14, cooldown = 6 },
	E = { name = "Thunder Clap", type = "force", mode = "push", radius = 15, strength = 100, damage = 26, upBoost = 24, cooldown = 7 },
	R = { name = "Arm Gatling",  type = "barrage", count = 12, interval = 0.06, spread = 8, damage = 6, speed = 160, size = V(1, 1, 1), knockback = 10, cooldown = 9 },
	F = { name = "Finger Gun",   type = "projectile", damage = 10, speed = 170, size = V(0.9, 0.9, 0.9), knockback = 12, stunEvery = 3, cooldown = 1 },
}}
-- BLUE BULLET — Red Rocket's son with adrenaline boost (faster Red Rocket).
Kits["Blue Bullet"] = { style = "fire", styleKey = "blue bullet flame speed", color = Color3.fromRGB(60, 140, 255), abilities = {
	Q = { name = "Flaming Fist",    type = "melee", range = 6, damage = 30, knockback = 58, up = 20, dotDamage = 4, dotDuration = 3, cooldown = 4 },
	E = { name = "Adrenaline Charge", type = "dash", distance = 48, damage = 26, knockback = 45, up = 15, dotDamage = 3, dotDuration = 2, cooldown = 6 },
	R = { name = "Adrenaline Rush", type = "buff", stat = "walkSpeed", amount = 1.8, duration = 6, cooldown = 16 },
	F = { name = "Sonic Clap",      type = "force", mode = "push", radius = 16, strength = 95, damage = 22, cooldown = 8 },
}}

-- SINISTER-VERSE / GODS — Sugoro done; Anonymous done. THORN senses fighter.
Kits["Thorn"] = { style = "physical", styleKey = "thorn senses", abilities = {
	Q = { name = "Precise Strike", type = "melee", range = 6, damage = 24, knockback = 38, up = 14, cooldown = 4 },
	E = { name = "Quick Dash",     type = "dash", distance = 32, damage = 20, knockback = 28, cooldown = 6 },
	R = { name = "Focus",          type = "buff", stat = "damageMult", amount = 1.4, duration = 6, cooldown = 16 },
	F = { name = "Counter Sense",  type = "counter", duration = 1.5, reflect = 1.4, cooldown = 13 },
}}

-- COSMIC / MONSTER apex predators from the Animal Table already: Megalodon done.

-- REDDON — red speedster (Dead Dash's brother), two batons, body regen.
Kits["Reddon"] = { style = "energy", styleKey = "reddon red speedster", color = Color3.fromRGB(230, 40, 40), abilities = {
	Q = { name = "Baton Rush",   type = "dash", distance = 44, damage = 20, knockback = 30, cooldown = 4 },
	E = { name = "Baton Flurry", type = "melee", hits = 5, hitInterval = 0.1, range = 5.5, damage = 6, knockback = 8, cooldown = 6 },
	R = { name = "Regenerate",   type = "buff", stat = "heal", amount = 40, cooldown = 18 },
	F = { name = "Cyclone Rush", type = "zone", atSelf = true, radius = 10, duration = 2.2, tickDamage = 7, tickRate = 0.3, cooldown = 12 },
}}

-- RAMPAGE — bounty hunter with immortality and the power to adapt to anything.
Kits["Rampage"] = { style = "physical", styleKey = "rampage adapt", abilities = {
	Q = { name = "Brutal Combo", type = "melee", hits = 3, hitInterval = 0.12, range = 6, damage = 11, knockback = 16, cooldown = 5 },
	E = { name = "Hunter's Charge", type = "dash", distance = 36, damage = 26, knockback = 40, up = 12, cooldown = 7 },
	R = { name = "Adapt",        type = "shield", duration = 6, block = 0.8, radius = 7, cooldown = 18 },
	F = { name = "Regen Surge",  type = "buff", stat = "heal", amount = 55, cooldown = 24 },
}}

-- MANGLED — cursed with complete immortality; a relentless pumpkin-headed bruiser.
Kits["Mangled"] = { style = "nature", styleKey = "mangled pumpkin", color = Color3.fromRGB(230, 130, 30), abilities = {
	Q = { name = "Wild Swing",   type = "melee", range = 6.5, damage = 26, knockback = 42, up = 14, cooldown = 4 },
	E = { name = "Reckless Charge", type = "dash", distance = 34, damage = 24, knockback = 38, up = 12, cooldown = 6 },
	R = { name = "Undying",      type = "buff", stat = "heal", amount = 50, cooldown = 20 },
	F = { name = "Harvest Slam", type = "slam", radius = 14, damage = 30, knockback = 45, up = 25, cooldown = 12 },
}}

return Kits
