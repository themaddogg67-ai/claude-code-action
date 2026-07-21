--[[
	WorldAtlas  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > WorldAtlas

	A code-usable catalog of the whole Aroraverse from the omniverse design doc,
	built as MAP-MAKING REFERENCE. Every location carries a `biome` tag, and each
	biome maps to a palette/material hint — so a future biome-driven map builder
	(or I, when building the next map) can pull a consistent look from data
	instead of guessing.

	Pure data (no Roblox globals) — colors are {r,g,b} so a builder converts with
	Color3.fromRGB(unpack(hint.accent)). Loads anywhere, cheap to require.

	Contents:
	  Hierarchy      - Planet → … → Aroraverse
	  Biomes         - biome tag -> { ground material, accent rgb, sky mood }
	  StoryLocations - the named places seasons actually visit (map-relevant)
	  Planets        - the 100 catalog worlds, tier + biome tagged
	  Verses         - themed universes (Order, Time, Infinity, Mirror, …)
	  EnemyUniverses - the 5 existential-threat realms
	  ImperiumWorlds - Manderin's controlled worlds & fleet
	  WarZones       - contested all-faction battlefields
	  SeasonLocations- season id -> canonical location name

	Helpers: get(name), byBiome(tag), byTier(tier), biome(tag),
	         locationForSeason(id), buildableList()
]]

local WorldAtlas = {}

-- scale of existence (smallest -> largest), straight from the doc
WorldAtlas.Hierarchy = {
	"Planet", "Solar System", "Galaxy", "Universe",
	"Multiverse", "Omniverse", "Omegaverse", "Aroraverse",
}

-------------------------------------------------------------------
-- BIOME PALETTE HINTS  (the bridge from lore to a map's look)
--   material = a Roblox Enum.Material name (string)
--   accent   = {r,g,b} neon/signage accent
--   ground   = {r,g,b} dominant terrain color
--   sky      = one-word mood for lighting/atmosphere
-------------------------------------------------------------------
WorldAtlas.Biomes = {
	city     = { material = "Concrete",     ground = { 70, 72, 80 },   accent = { 60, 150, 255 }, sky = "night-neon" },
	volcanic = { material = "Basalt",       ground = { 46, 38, 36 },   accent = { 255, 90, 40 },  sky = "ashen" },
	forge    = { material = "CorrodedMetal", ground = { 60, 52, 48 },  accent = { 255, 140, 60 }, sky = "foundry" },
	ocean    = { material = "Sand",         ground = { 210, 200, 170 }, accent = { 40, 130, 235 }, sky = "open-sea" },
	ice      = { material = "Glacier",      ground = { 200, 225, 240 }, accent = { 150, 220, 255 }, sky = "blizzard" },
	crystal  = { material = "Glass",        ground = { 90, 100, 130 },  accent = { 180, 130, 255 }, sky = "prismatic" },
	forest   = { material = "LeafyGrass",   ground = { 46, 96, 56 },    accent = { 110, 230, 120 }, sky = "canopy" },
	jungle   = { material = "Grass",        ground = { 38, 78, 44 },    accent = { 80, 170, 90 },   sky = "overgrown" },
	sky      = { material = "SmoothPlastic", ground = { 150, 175, 210 }, accent = { 170, 210, 255 }, sky = "cloud" },
	desert   = { material = "Sandstone",    ground = { 205, 175, 120 }, accent = { 230, 200, 120 }, sky = "sunbaked" },
	storm    = { material = "Slate",        ground = { 44, 46, 54 },    accent = { 255, 250, 140 }, sky = "thunder" },
	void     = { material = "SmoothPlastic", ground = { 16, 14, 22 },   accent = { 140, 40, 255 },  sky = "void" },
	shadow   = { material = "SmoothPlastic", ground = { 22, 20, 28 },   accent = { 120, 60, 255 },  sky = "eclipse" },
	digital  = { material = "SmoothPlastic", ground = { 18, 24, 30 },   accent = { 60, 220, 200 },  sky = "grid" },
	metal    = { material = "DiamondPlate", ground = { 70, 74, 84 },    accent = { 120, 150, 190 }, sky = "industrial" },
	solar    = { material = "Neon",         ground = { 120, 70, 30 },   accent = { 255, 200, 80 },  sky = "plasma" },
	gas      = { material = "SmoothPlastic", ground = { 160, 130, 110 }, accent = { 200, 150, 120 }, sky = "gasgiant" },
	swamp    = { material = "Mud",          ground = { 60, 66, 46 },    accent = { 120, 160, 90 },  sky = "murky" },
	cosmic   = { material = "Neon",         ground = { 24, 20, 40 },    accent = { 200, 140, 255 }, sky = "starfield" },
	temporal = { material = "Glass",        ground = { 40, 60, 90 },    accent = { 120, 200, 255 }, sky = "timeflux" },
	mind     = { material = "SmoothPlastic", ground = { 40, 20, 46 },   accent = { 230, 70, 220 },  sky = "dream" },
	light    = { material = "Neon",         ground = { 210, 205, 180 }, accent = { 255, 245, 190 }, sky = "radiant" },
	gravity  = { material = "SmoothPlastic", ground = { 34, 30, 52 },   accent = { 160, 120, 255 }, sky = "warped" },
	ruin     = { material = "Concrete",     ground = { 60, 56, 50 },    accent = { 120, 110, 100 }, sky = "decay" },
	stone    = { material = "Rock",         ground = { 96, 88, 76 },    accent = { 150, 130, 100 }, sky = "canyon" },
	hive     = { material = "Slate",        ground = { 70, 58, 34 },    accent = { 200, 160, 60 },  sky = "tunnels" },
}

-------------------------------------------------------------------
-- STORY LOCATIONS — the named places the campaign actually visits
-- (map-relevant fields: kind, biome, controller, season, mapReady, builder)
-------------------------------------------------------------------
WorldAtlas.StoryLocations = {
	{ name = "Metro City",       kind = "city",     biome = "city",    controller = "Manderin", season = 8,
	  mapReady = true, builder = "MetroCityBuilder", route = "MetroCityCampaign",
	  note = "Manderin's clean, high-secured capital. Season 8 — built." },
	{ name = "Quantum City",     kind = "city",     biome = "digital", controller = "Blue", season = 10,
	  mapReady = true, builder = "QuantumCityBuilder", route = "QuantumCityCampaign",
	  note = "A digital city inside Blue's loops in space; gateway to the Anonymous. Season 10 — built." },
	{ name = "Gildonia",         kind = "planet",   biome = "jungle",  controller = nil, season = 5,
	  mapReady = true, builder = "GildoniaBuilder", route = "GildoniaCampaign",
	  note = "Undeveloped civilizations. The disastrous battle planet where the Warriors fall. Season 5 — built." },
	{ name = "Ruined City",      kind = "city",     biome = "ruin",    controller = "Omega", season = 7,
	  mapReady = true, builder = "RuinedCityBuilder", route = "RuinedCityCampaign",
	  note = "An Earth city devastated as Omega rampages. Season 7 — built." },
	{ name = "The Swamplands",   kind = "region",   biome = "swamp",   controller = "Minus", season = 1,
	  mapReady = true, builder = "SwamplandsBuilder", route = "SwamplandsCampaign",
	  note = "The bayou where the campaign begins; den of Minus, the gator general. Season 1 — built." },
	{ name = "The Shadowlands",  kind = "region",   biome = "shadow",  controller = "Null", season = 3,
	  mapReady = true, builder = "ShadowlandsBuilder", route = "ShadowlandsCampaign",
	  note = "Null's dark domain — army of darkness, shadow spires, the throne. Season 3 — built." },
	{ name = "Valhalla",         kind = "planet",   biome = "stone",   controller = "Valkery", season = nil,
	  note = "A planet full of Vikings — Valkery's homeworld." },
	{ name = "Planet Sparta",    kind = "planet",   biome = "desert",  controller = "Ares", season = nil,
	  note = "Spartans and Athenians. Barbarian, Ares and Kratos hail from here." },
	{ name = "Fountain of Gold",  kind = "landmark", biome = "solar",  controller = nil, season = nil,
	  note = "Turns you into your True Gold state. On the most dangerous planet." },
	{ name = "Fountain of Silver", kind = "landmark", biome = "ice",   controller = nil, season = nil,
	  note = "Turns you into your True Silver state." },
}

-------------------------------------------------------------------
-- THE 100 CATALOG PLANETS  (name, tier, biome)
--   tiers: core (1-30), mid (31-40), exotic (41-60), ultra (61-80), god (81-100)
-------------------------------------------------------------------
local function P(name, tier, biome) return { name = name, tier = tier, biome = biome } end
WorldAtlas.Planets = {
	-- core species worlds
	P("Virelon", "core", "crystal"),  P("Korvax Prime", "core", "metal"),  P("Elystra", "core", "sky"),
	P("Nargoth", "core", "volcanic"), P("Xeloria", "core", "ocean"),       P("Threxon", "core", "hive"),
	P("Orinthal", "core", "sky"),     P("Gravemire", "core", "shadow"),    P("Solaryn", "core", "solar"),
	P("Brontallis", "core", "stone"), P("Zyrentha", "core", "storm"),      P("Myrkos", "core", "forest"),
	P("Vanthell", "core", "gas"),     P("Krythos", "core", "shadow"),      P("Ulmoria", "core", "crystal"),
	P("Draxion", "core", "forge"),    P("Aerolith", "core", "sky"),        P("Vor'Kael", "core", "shadow"),
	P("Zenithar", "core", "digital"), P("Umbrixa", "core", "void"),        P("Cindralis", "core", "volcanic"),
	P("Velmora", "core", "sky"),      P("Kharzun", "core", "stone"),       P("Liorath", "core", "light"),
	P("Dravenn", "core", "jungle"),   P("Oblex", "core", "swamp"),         P("Pyrion", "core", "volcanic"),
	P("Crythalis", "core", "ice"),    P("Nexara", "core", "digital"),      P("Ghorath", "core", "jungle"),
	-- mid-tier cosmic
	P("Valcora", "mid", "metal"),     P("Ithrael", "mid", "light"),        P("Ruk'Taal", "mid", "stone"),
	P("Sorynth", "mid", "mind"),      P("Belmora", "mid", "ruin"),         P("Xandros", "mid", "metal"),
	P("Ecliptus", "mid", "void"),     P("Zorvath", "mid", "void"),         P("Myzelia", "mid", "forest"),
	P("Orvessa", "mid", "mind"),
	-- exotic physics
	P("Kirell", "exotic", "gravity"), P("Voranth", "exotic", "temporal"),  P("Nymora", "exotic", "ocean"),
	P("Thalvex", "exotic", "storm"),  P("Drexium", "exotic", "metal"),     P("Ulkor", "exotic", "void"),
	P("Pyralis", "exotic", "solar"),  P("Krynnal", "exotic", "ice"),       P("Selnox", "exotic", "shadow"),
	P("Vireth", "exotic", "crystal"), P("Orlux", "exotic", "void"),        P("Zenthra", "exotic", "digital"),
	P("Bravok", "exotic", "metal"),   P("Xythera", "exotic", "storm"),     P("Morthis", "exotic", "ruin"),
	P("Elvaron", "exotic", "jungle"), P("Drakmire", "exotic", "ocean"),    P("Solvyr", "exotic", "forge"),
	P("Nyxara", "exotic", "shadow"),  P("Kaelith", "exotic", "mind"),
	-- ultra-cosmic / abstract
	P("Orynth Prime", "ultra", "cosmic"), P("Vexoria", "ultra", "digital"), P("Lumora", "ultra", "light"),
	P("Kryos Prime", "ultra", "ice"),  P("Zephyria", "ultra", "sky"),      P("Threx Prime", "ultra", "hive"),
	P("Umbraxis", "ultra", "shadow"),  P("Solnix", "ultra", "solar"),      P("Eryndor", "ultra", "forest"),
	P("Valtrex", "ultra", "jungle"),   P("Orbis Null", "ultra", "void"),   P("Nythra", "ultra", "mind"),
	P("Zoriel", "ultra", "void"),      P("Krython", "ultra", "metal"),     P("Velthar", "ultra", "crystal"),
	P("Pyrryx", "ultra", "volcanic"),  P("Omnara", "ultra", "cosmic"),     P("Xelthos", "ultra", "mind"),
	P("Darnox", "ultra", "void"),      P("Lythros", "ultra", "mind"),
	-- god-tier / omniversal scale
	P("Aetherion", "god", "cosmic"),   P("Nullspire", "god", "void"),      P("Chronara", "god", "temporal"),
	P("Solmire Supreme", "god", "solar"), P("Vortexia", "god", "void"),    P("Oblivion Reach", "god", "void"),
	P("Genesis Core", "god", "light"), P("Tenebris Prime", "god", "shadow"), P("Lux Aeterna", "god", "light"),
	P("Gravitas", "god", "gravity"),   P("Parallax", "god", "void"),       P("Ethergrave", "god", "ruin"),
	P("Nexus Omnia", "god", "cosmic"), P("Zareph", "god", "cosmic"),       P("Voidheart", "god", "void"),
	P("Stellaron", "god", "cosmic"),   P("Mytherra", "god", "cosmic"),     P("Omnireach", "god", "cosmic"),
	P("Infinity Spire", "god", "cosmic"), P("Ultimara", "god", "cosmic"),
}

-------------------------------------------------------------------
-- THEMED UNIVERSES  (name -> one-line + biome hint)
-------------------------------------------------------------------
WorldAtlas.Verses = {
	{ name = "Chaos Universe",     biome = "void",     note = "Nothing follows fixed laws; reality is unstable." },
	{ name = "Order Universe",     biome = "digital",  note = "Perfect laws; time never branches, nothing by accident." },
	{ name = "Time Universe",      biome = "temporal", note = "Every timeline originates here; the Time Keepers tend billions of futures." },
	{ name = "Infinity Universe",  biome = "cosmic",   note = "Infinite in every direction; every possible civilization exists." },
	{ name = "Null Universe",      biome = "void",     note = "A universe consuming itself; origin of the Null Consortium." },
	{ name = "Genesis Universe",   biome = "light",    note = "The first living universe; every planet is conscious." },
	{ name = "Evolution Universe", biome = "jungle",   note = "Everything evolves continuously and mutates." },
	{ name = "Mirror Universe",    biome = "shadow",   note = "Every person has an opposite; heroes and villains reversed." },
	{ name = "Primordial Universe", biome = "volcanic", note = "Oldest surviving universe; home of the First Dragons, Titans, Gods." },
	{ name = "Sovereign Universe", biome = "light",    note = "Where universe-ruling beings gather; diplomacy decides lower realities." },
	{ name = "True Gold Universe",  biome = "solar",   note = "Home tier of the True Gold state (Fountain of Gold)." },
	{ name = "True Silver Universe", biome = "ice",    note = "Home tier of the True Silver state (Fountain of Silver)." },
}

-------------------------------------------------------------------
-- THE 5 ENEMY UNIVERSES  (existential threats rivaling Manderin)
-------------------------------------------------------------------
WorldAtlas.EnemyUniverses = {
	{ name = "Vorax Absence Realm", species = "Voraxi",        biome = "void",
	  goal = "Erase structured existence; beings are holes in reality." },
	{ name = "Chrono Tyrant Domain", species = "Chronovores",  biome = "temporal",
	  goal = "Rewrite Manderin out of every timeline; they eat futures." },
	{ name = "Living Equation Cosmos", species = "Equation Lords", biome = "digital",
	  goal = "Replace reality with pure mathematical certainty." },
	{ name = "Dream Eater Realm",   species = "Oneirophages",  biome = "mind",
	  goal = "Control consciousness; cities built inside sleeping gods." },
	{ name = "Null God Consortium", species = "Null Deities",  biome = "void",
	  goal = "Undo everything powerful, eventually including themselves." },
}

-- Manderin's controlled worlds + fleet (Order of the Crown)
WorldAtlas.ImperiumWorlds = {
	"Manderin Prime", "Forgeworld Omega", "Echo Realm", "Lux Null Star", "Archive World",
	"Nullbone World", "Ark Ship", "Devourer of Realms", "Infinity Forge Ship",
	"Time Spiral Cruiser", "Omega Mirror Fleet", "Void Seed Transporter", "Mandarium Core",
}

-- constantly-contested all-faction battlefields
WorldAtlas.WarZones = { "Omnara", "Nexus Omnia", "Infinity Spire", "Parallax", "Stellaron" }

-- season id -> canonical location name (drives which map a season builds)
WorldAtlas.SeasonLocations = {
	[1] = "The Swamplands",
	[3] = "The Shadowlands",
	[5] = "Gildonia",
	[7] = "Ruined City",
	[8] = "Metro City",
	[10] = "Quantum City",
	[11] = "Quantum City",
}

-------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------
function WorldAtlas.biome(tag)
	return WorldAtlas.Biomes[tag]
end

function WorldAtlas.get(name)
	for _, loc in ipairs(WorldAtlas.StoryLocations) do
		if loc.name == name then return loc, "story" end
	end
	for _, p in ipairs(WorldAtlas.Planets) do
		if p.name == name then return p, "planet" end
	end
	return nil
end

function WorldAtlas.byBiome(tag)
	local out = {}
	for _, p in ipairs(WorldAtlas.Planets) do
		if p.biome == tag then out[#out + 1] = p end
	end
	return out
end

function WorldAtlas.byTier(tier)
	local out = {}
	for _, p in ipairs(WorldAtlas.Planets) do
		if p.tier == tier then out[#out + 1] = p end
	end
	return out
end

function WorldAtlas.locationForSeason(id)
	local name = WorldAtlas.SeasonLocations[id]
	return name and (WorldAtlas.get(name)) or nil
end

-- locations that already have a built map + route
function WorldAtlas.buildableList()
	local out = {}
	for _, loc in ipairs(WorldAtlas.StoryLocations) do
		if loc.mapReady then out[#out + 1] = loc end
	end
	return out
end

return WorldAtlas
