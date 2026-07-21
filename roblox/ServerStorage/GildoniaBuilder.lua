--[[
	GildoniaBuilder  (ModuleScript)
	WHERE IT GOES: ServerStorage > GildoniaBuilder

	Season 5's map: GILDONIA — the jungle planet of undeveloped civilizations
	where the Warriors of the World make their doomed stand. Third map on the
	multi-map framework and the first NON-city, ground-based world — its look is
	pulled from the WorldAtlas "jungle" biome, proving biome-driven maps across
	very different environments.

	Same output shape as the other builders, so the shared CampaignController +
	route module run it unchanged:
	    workspace.Gildonia.Districts / .Campaign(.Spawns/.Objectives)

	Route (Season 5 → Void Overlord):
	  1 Crash Site · 2 Jungle Path · 3 Native Village · 4 Ancient Ruins ·
	  5 River Crossing · 6 Overgrown Temple · 7 Sacred Grove ·
	  8 Corrupted Clearing (boss)

	build(parent, opts) -> Model    (opts.seed number, opts.campaign bool=true)
	Bake:  require(game.ServerStorage.GildoniaBuilder).build(workspace)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GildoniaBuilder = {}

local c   = Color3.fromRGB
local V   = Vector3.new
local CF  = CFrame.new
local ANG = CFrame.Angles

-------------------------------------------------------------------
-- PALETTE — seeded from WorldAtlas "jungle" biome (falls back if absent)
-------------------------------------------------------------------
local function loadBiome()
	local ok, atlas = pcall(function() return require(ReplicatedStorage.Campaign.WorldAtlas) end)
	if ok and atlas and atlas.biome then
		local b = atlas.biome("jungle")
		if b then return b end
	end
	return { material = "Grass", ground = { 38, 78, 44 }, accent = { 80, 170, 90 }, sky = "overgrown" }
end
local BIOME = loadBiome()
local function rgb(t) return c(t[1], t[2], t[3]) end

local PAL = {
	ground    = rgb(BIOME.ground),
	groundDark = c(28, 58, 34),
	accent    = rgb(BIOME.accent),
	leaf      = c(74, 160, 84),
	leafDark  = c(52, 116, 62),
	leafLite  = c(120, 200, 110),
	trunk     = c(92, 66, 44),
	trunkDark = c(66, 46, 30),
	stone     = c(120, 116, 104),
	stoneDark = c(84, 80, 70),
	thatch    = c(150, 120, 70),
	wood      = c(110, 80, 50),
	water     = c(46, 130, 150),
	rock      = c(96, 92, 84),
	fire      = c(255, 150, 60),
	glow      = c(150, 255, 170),     -- bioluminescent flora
	corrupt   = c(150, 60, 255),      -- Void Overlord corruption
	corruptDk = c(40, 16, 60),
	white     = c(240, 245, 240),
}

-- ground-based sectors (planet surface, Y≈0)
local SECTORS = {
	{ stage = 1, name = "Crash Site",        x = 0,    z = 400,  theme = "crash",   color = PAL.accent,
	  objective = "Regroup at the downed Warrior ship." },
	{ stage = 2, name = "Jungle Path",       x = -270, z = 250,  theme = "jungle",  color = PAL.leafLite,
	  objective = "Cut through the overgrown jungle path." },
	{ stage = 3, name = "Native Village",    x = 270,  z = 250,  theme = "village", color = PAL.fire,
	  objective = "Defend the native village from the assault." },
	{ stage = 4, name = "Ancient Ruins",     x = -360, z = -40,  theme = "ruins",   color = PAL.stone,
	  objective = "Search the ancient ruins for a way through." },
	{ stage = 5, name = "River Crossing",    x = 360,  z = -40,  theme = "river",   color = PAL.water,
	  objective = "Hold the river crossing." },
	{ stage = 6, name = "Overgrown Temple",  x = -210, z = -330, theme = "temple",  color = PAL.glow,
	  objective = "Breach the overgrown temple." },
	{ stage = 7, name = "Sacred Grove",      x = 210,  z = -330, theme = "grove",   color = PAL.glow,
	  objective = "Pass the glowing Sacred Grove." },
	{ stage = 8, name = "Corrupted Clearing", x = 0,   z = -500, theme = "boss",    color = PAL.corrupt,
	  objective = "Face the Void Overlord in the corrupted clearing.", boss = true },
}

-------------------------------------------------------------------
-- CORE HELPERS
-------------------------------------------------------------------
local rng = Random.new()
local root, fxParent, structParent

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = true; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent or structParent
	props.Parent = nil
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function deco(props)
	props.CanCollide = props.CanCollide == true
	props.CanQuery = false; props.CanTouch = false
	props.Parent = props.Parent or fxParent
	return part(props)
end
local function neon(props) props.Material = Enum.Material.Neon; return deco(props) end
local function light(parent, color, range, bright)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range or 16; l.Brightness = bright or 2; l.Parent = parent; return l
end
local function sign(cframe, size, text, opts)
	opts = opts or {}
	local board = deco({ Size = size, CFrame = cframe, Color = opts.boardColor or PAL.wood,
		Material = Enum.Material.Wood, Parent = opts.parent or fxParent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = opts.face or Enum.NormalId.Front; gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28; gui.LightInfluence = 0; gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.82); label.Position = UDim2.fromScale(0.04, 0.09)
	label.BackgroundTransparency = 1; label.Text = text; label.Font = opts.font or Enum.Font.GothamBold
	label.TextColor3 = opts.color or PAL.white; label.TextScaled = true; label.Parent = gui
	return board
end

-------------------------------------------------------------------
-- JUNGLE PROPS
-------------------------------------------------------------------
local function bigTree(x, z, scale)
	scale = scale or 1
	local h = (18 + rng:NextInteger(0, 10)) * scale
	deco({ Size = V(3.5 * scale, h, 3.5 * scale), Color = PAL.trunk, Material = Enum.Material.Wood,
		CFrame = CF(x, h / 2, z) * ANG(math.rad(rng:NextInteger(-4, 4)), 0, math.rad(rng:NextInteger(-4, 4))) })
	-- layered canopy
	for i = 0, 2 do
		local r = (16 - i * 3) * scale
		deco({ Shape = Enum.PartType.Ball, Size = V(r, r * 0.8, r), Color = (i % 2 == 0) and PAL.leaf or PAL.leafDark,
			Material = Enum.Material.Grass, CFrame = CF(x + rng:NextInteger(-3, 3), h + i * 4 * scale, z + rng:NextInteger(-3, 3)) })
	end
end
local function bush(x, z, color)
	deco({ Shape = Enum.PartType.Ball, Size = V(6, 4, 6), Color = color or PAL.leaf, Material = Enum.Material.Grass,
		CFrame = CF(x, 1.5, z) })
end
local function fern(x, z)
	for i = 1, 4 do
		local a = math.rad(i * 90 + rng:NextInteger(-20, 20))
		deco({ Size = V(0.5, 5, 2.5), Color = PAL.leafLite, Material = Enum.Material.Grass,
			CFrame = CF(x, 2.5, z) * ANG(math.rad(35), a, 0) })
	end
end
local function vine(x, z, y, len)
	deco({ Size = V(0.4, len, 0.4), Color = PAL.leafDark, Material = Enum.Material.Grass, CFrame = CF(x, y - len / 2, z) })
end
local function rock(x, z, s)
	deco({ Shape = Enum.PartType.Ball, Size = V(6, 4, 5) * (s or 1), Color = PAL.rock, Material = Enum.Material.Rock,
		CanCollide = true, CFrame = CF(x, 1.5 * (s or 1), z) * ANG(math.rad(rng:NextInteger(-10, 10)), math.rad(rng:NextInteger(0, 360)), 0) })
end
local function glowFlora(x, z, color)
	deco({ Size = V(0.4, 4, 0.4), Color = PAL.leafDark, Material = Enum.Material.Grass, CFrame = CF(x, 2, z) })
	local bud = neon({ Shape = Enum.PartType.Ball, Size = V(2, 2, 2), Color = color or PAL.glow, Transparency = 0.1,
		CFrame = CF(x, 4.5, z) })
	light(bud, color or PAL.glow, 12, 1.6)
end
local function torch(x, z)
	deco({ Size = V(0.5, 6, 0.5), Color = PAL.wood, Material = Enum.Material.Wood, CFrame = CF(x, 3, z) })
	local flame = neon({ Shape = Enum.PartType.Ball, Size = V(1.6, 2.2, 1.6), Color = PAL.fire, Transparency = 0.1, CFrame = CF(x, 6.4, z) })
	light(flame, PAL.fire, 18, 2.2)
	local fire = Instance.new("Fire"); fire.Heat = 6; fire.Size = 4; fire.Color = PAL.fire; fire.Parent = flame
end
local function hut(x, z, m)
	-- primitive stilt hut: posts + walls + conical thatch roof
	for _, o in ipairs({ V(-4, 0, -4), V(4, 0, -4), V(-4, 0, 4), V(4, 0, 4) }) do
		part({ Size = V(1, 6, 1), Color = PAL.wood, Material = Enum.Material.Wood, CFrame = CF(x + o.X, 3, z + o.Z), Parent = m })
	end
	part({ Size = V(11, 5, 11), Color = PAL.wood, Material = Enum.Material.WoodPlanks, CFrame = CF(x, 8, z), Parent = m })
	-- thatch roof (stacked shrinking wedges approximated by cones of boxes)
	for i = 0, 3 do
		local s = 13 - i * 3
		deco({ Size = V(s, 1.6, s), Color = PAL.thatch, Material = Enum.Material.Grass, CFrame = CF(x, 11 + i * 1.4, z) * ANG(0, math.rad(45), 0) })
	end
end
local function ruinPillar(x, z, h)
	part({ Size = V(4, h, 4), Color = PAL.stone, Material = Enum.Material.Slate, CFrame = CF(x, h / 2, z) * ANG(math.rad(rng:NextInteger(-6, 6)), 0, math.rad(rng:NextInteger(-6, 6))), Parent = structParent })
	deco({ Size = V(5, 1.5, 5), Color = PAL.stoneDark, CFrame = CF(x, h, z) })
end

-------------------------------------------------------------------
-- ENVIRONMENT
-------------------------------------------------------------------
local function buildGround()
	part({ Size = V(1300, 6, 1300), Color = PAL.ground, Material = Enum.Material.Grass, CFrame = CF(0, -3, 0), Parent = structParent })
	-- gentle dirt patches + hills
	for _ = 1, 26 do
		local x, z = rng:NextInteger(-500, 500), rng:NextInteger(-500, 500)
		deco({ Shape = Enum.PartType.Ball, Size = V(rng:NextInteger(30, 70), rng:NextInteger(8, 18), rng:NextInteger(30, 70)),
			Color = (rng:NextNumber() < 0.5) and PAL.groundDark or PAL.ground, Material = Enum.Material.Grass,
			CanCollide = true, CFrame = CF(x, -2, z) })
	end
	-- dense perimeter jungle (a wall of trees) so the playable area reads bounded
	for i = 0, 84 do
		local a = math.rad(i / 84 * 360)
		local rr = 560 + rng:NextInteger(-20, 20)
		bigTree(math.cos(a) * rr, math.sin(a) * rr, 1.4)
	end
end

local function scatterFoliage()
	for _ = 1, 70 do
		local x, z = rng:NextInteger(-470, 470), rng:NextInteger(-470, 470)
		if math.abs(x) > 30 or math.abs(z) > 30 then
			local r = rng:NextNumber()
			if r < 0.4 then bigTree(x, z, rng:NextNumber(0.8, 1.3))
			elseif r < 0.7 then bush(x, z)
			elseif r < 0.85 then fern(x, z)
			else rock(x, z, rng:NextNumber(0.7, 1.4)) end
		end
	end
end

-- central hub: a great ancient tree in a clearing
local function buildHeartTree()
	local h = 60
	part({ Size = V(12, h, 12), Color = PAL.trunkDark, Material = Enum.Material.Wood, CFrame = CF(0, h / 2, 0), Parent = structParent })
	for i = 0, 3 do
		local r = 40 - i * 7
		deco({ Shape = Enum.PartType.Ball, Size = V(r, r * 0.7, r), Color = (i % 2 == 0) and PAL.leaf or PAL.leafDark,
			Material = Enum.Material.Grass, CFrame = CF(rng:NextInteger(-4, 4), h + i * 8, rng:NextInteger(-4, 4)) })
	end
	-- roots + glowing runes at the base
	for i = 1, 8 do
		local a = math.rad(i * 45)
		deco({ Size = V(3, 2, 12), Color = PAL.trunk, Material = Enum.Material.Wood, CFrame = CF(math.cos(a) * 9, 1, math.sin(a) * 9) * ANG(math.rad(20), -a, 0) })
		glowFlora(math.cos(a) * 20, math.sin(a) * 20, PAL.glow)
	end
end

-------------------------------------------------------------------
-- SECTOR BUILDS
-------------------------------------------------------------------
local function buildCrashSite(s, m)
	-- the downed Warrior ship: a broken, tilted metal hull with smoke
	local x, z = s.x, s.z
	part({ Size = V(30, 12, 70), Color = c(70, 74, 84), Material = Enum.Material.Metal, CFrame = CF(x, 5, z) * ANG(math.rad(-12), math.rad(18), math.rad(6)), Parent = m })
	part({ Size = V(20, 14, 24), Color = c(48, 52, 62), Material = Enum.Material.Metal, CFrame = CF(x + 4, 12, z + 18) * ANG(math.rad(-12), math.rad(18), 0), Parent = m })
	-- broken hull panels + scorch
	for i = 1, 6 do
		deco({ Size = V(rng:NextInteger(4, 8), 1, rng:NextInteger(4, 8)), Color = c(60, 64, 74), Material = Enum.Material.Metal, CanCollide = true,
			CFrame = CF(x + rng:NextInteger(-20, 20), 0.6, z + rng:NextInteger(-24, 24)) * ANG(0, math.rad(rng:NextInteger(0, 360)), 0) })
	end
	local smokeAnchor = deco({ Size = V(2, 2, 2), Transparency = 1, CFrame = CF(x - 6, 12, z - 20) })
	local att = Instance.new("Attachment"); att.Parent = smokeAnchor
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Color = ColorSequence.new(c(50, 50, 55))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3.5); smoke.Rate = 8; smoke.Speed = NumberRange.new(6, 10); smoke.Parent = att
	sign(CF(x, 9, z - 36), V(16, 5, 0.4), "WARRIOR SHIP", { color = s.color, parent = m })
end

local function buildVillage(s, m)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		hut(s.x + math.cos(a) * 28, s.z + math.sin(a) * 28, m)
	end
	torch(s.x - 10, s.z); torch(s.x + 10, s.z)
	-- central campfire
	local fire = neon({ Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = PAL.fire, Transparency = 0.1, CFrame = CF(s.x, 2, s.z) })
	light(fire, PAL.fire, 26, 3)
	local f = Instance.new("Fire"); f.Size = 8; f.Heat = 10; f.Color = PAL.fire; f.Parent = fire
end

local function buildRuins(s, m)
	local heights = { 18, 12, 22, 9, 16, 20, 11 }
	for i, h in ipairs(heights) do
		local a = math.rad(i / #heights * 360)
		ruinPillar(s.x + math.cos(a) * 26, s.z + math.sin(a) * 26, h)
	end
	-- broken archway + vines
	part({ Size = V(24, 4, 4), Color = PAL.stone, Material = Enum.Material.Slate, CFrame = CF(s.x, 20, s.z), Parent = m })
	vine(s.x - 8, s.z, 18, 12); vine(s.x + 6, s.z, 18, 15)
end

local function buildRiver(s, m)
	-- a winding water strip through the sector
	for i = -3, 3 do
		deco({ Size = V(40, 3, 60), Color = PAL.water, Material = Enum.Material.Glass, Transparency = 0.3, Reflectance = 0.2, CanCollide = true,
			CFrame = CF(s.x + i * 8, -1, s.z + i * 34) * ANG(0, math.rad(i * 6), 0) })
	end
	-- stepping-stone logs
	for i = -2, 2 do
		part({ Size = V(6, 2, 14), Color = PAL.wood, Material = Enum.Material.Wood, CFrame = CF(s.x + i * 14, 1, s.z + i * 12), Parent = m })
	end
	bush(s.x - 30, s.z + 20); bush(s.x + 30, s.z - 20)
end

local function buildTemple(s, m)
	-- stepped stone pyramid with an entrance + glowing glyphs
	for i = 0, 5 do
		local w = 44 - i * 7
		part({ Size = V(w, 5, w), Color = (i % 2 == 0) and PAL.stone or PAL.stoneDark, Material = Enum.Material.Slate,
			CFrame = CF(s.x, 2.5 + i * 5, s.z), Parent = m })
	end
	part({ Size = V(8, 10, 6), Color = c(20, 24, 20), CFrame = CF(s.x, 5, s.z + 20), Parent = m })  -- dark doorway
	for _, o in ipairs({ -22, 22 }) do glowFlora(s.x + o, s.z + 22, s.color) end
	-- moss/vines
	vine(s.x - 14, s.z + 18, 12, 10); vine(s.x + 14, s.z + 18, 12, 8)
end

local function buildGrove(s, m)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		bigTree(s.x + math.cos(a) * 26, s.z + math.sin(a) * 26, 1.1)
		glowFlora(s.x + math.cos(a) * 14, s.z + math.sin(a) * 14, s.color)
	end
	-- glowing pond in the center
	deco({ Shape = Enum.PartType.Cylinder, Size = V(2, 24, 24), Color = s.color, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = true,
		CFrame = CF(s.x, 0.5, s.z) * ANG(0, 0, math.rad(90)) })
end

local function buildBossClearing(s, m)
	-- Void Overlord's corruption: blighted ground, dead trees, purple void crystals
	deco({ Shape = Enum.PartType.Cylinder, Size = V(2, 150, 150), Color = PAL.corruptDk, Material = Enum.Material.Ground, CanCollide = true,
		CFrame = CF(s.x, 0.4, s.z) * ANG(0, 0, math.rad(90)) })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, 140, 140), Color = PAL.corrupt, Transparency = 0.4, CFrame = CF(s.x, 0.9, s.z) * ANG(0, 0, math.rad(90)) })
	for i = 1, 10 do
		local a = math.rad(i * 36)
		-- twisted dead trees
		part({ Size = V(3, 30 + rng:NextInteger(0, 12), 3), Color = c(30, 24, 30), Material = Enum.Material.Wood,
			CFrame = CF(s.x + math.cos(a) * 55, 16, s.z + math.sin(a) * 55) * ANG(math.rad(rng:NextInteger(-14, 14)), 0, math.rad(rng:NextInteger(-14, 14))), Parent = m })
		-- void crystals
		local cr = neon({ Size = V(3, 12, 3), Color = PAL.corrupt, Transparency = 0.15,
			CFrame = CF(s.x + math.cos(a) * 38, 6, s.z + math.sin(a) * 38) * ANG(math.rad(rng:NextInteger(-20, 20)), 0, math.rad(rng:NextInteger(-20, 20))) })
		light(cr, PAL.corrupt, 20, 2)
	end
	local core = neon({ Shape = Enum.PartType.Ball, Size = V(8, 8, 8), Color = PAL.corrupt, Transparency = 0.1, CanCollide = false, CFrame = CF(s.x, 18, s.z), Parent = m })
	light(core, PAL.corrupt, 60, 4)
end

local function buildSector(s, districts)
	local m = Instance.new("Model")
	m.Name = (s.name:gsub("%s", ""))
	m.Parent = districts
	m:SetAttribute("District", s.name)
	if s.theme == "crash" then buildCrashSite(s, m)
	elseif s.theme == "village" then buildVillage(s, m)
	elseif s.theme == "ruins" then buildRuins(s, m)
	elseif s.theme == "river" then buildRiver(s, m)
	elseif s.theme == "temple" then buildTemple(s, m)
	elseif s.theme == "grove" then buildGrove(s, m)
	elseif s.theme == "boss" then buildBossClearing(s, m)
	else -- jungle path
		for i = 1, 10 do bigTree(s.x + rng:NextInteger(-30, 30), s.z + rng:NextInteger(-30, 30), rng:NextNumber(0.9, 1.3)) end
		for i = 1, 6 do fern(s.x + rng:NextInteger(-26, 26), s.z + rng:NextInteger(-26, 26)) end
	end
	if s.theme ~= "boss" then
		sign(CF(s.x, 8, s.z + 34), V(20, 6, 0.4), string.upper(s.name), { color = s.color, parent = m })
	end
	return m
end

-------------------------------------------------------------------
-- CAMPAIGN SCAFFOLDING (shared shape)
-------------------------------------------------------------------
local function spawnAt(pos, name, parent, enabled)
	local sp = Instance.new("SpawnLocation")
	sp.Name = name; sp.Size = V(12, 1, 12); sp.Anchored = true; sp.CanCollide = true
	sp.Neutral = true; sp.Duration = 0; sp.Enabled = enabled ~= false
	sp.Color = PAL.accent; sp.Material = Enum.Material.Neon; sp.Transparency = 0.3
	sp.TopSurface = Enum.SurfaceType.Smooth; sp.CFrame = CF(pos.X, 1, pos.Z); sp.Parent = parent
	return sp
end
local function buildCampaign(m)
	local camp = Instance.new("Folder"); camp.Name = "Campaign"; camp.Parent = m
	local spawns = Instance.new("Folder"); spawns.Name = "Spawns"; spawns.Parent = camp
	local objectives = Instance.new("Folder"); objectives.Name = "Objectives"; objectives.Parent = camp
	spawnAt(V(SECTORS[1].x, 0, SECTORS[1].z - 24), "CampaignStart", spawns, true)
	for _, s in ipairs(SECTORS) do
		local beacon = part({ Shape = Enum.PartType.Cylinder, Size = V(30, 8, 8), Color = PAL.accent,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true,
			CFrame = CF(s.x, 15, s.z) * ANG(0, 0, math.rad(90)), Parent = objectives })
		beacon.Name = "Stage" .. s.stage .. "_" .. (s.name:gsub("%s", ""))
		beacon:SetAttribute("Stage", s.stage); beacon:SetAttribute("District", s.name); beacon:SetAttribute("Objective", s.objective)
		light(beacon, PAL.accent, 26, 2)
		local sp = spawnAt(V(s.x, 0, s.z), "Checkpoint_" .. s.stage, spawns, false); sp.Enabled = false
	end
	return camp
end

-------------------------------------------------------------------
-- PUBLIC
-------------------------------------------------------------------
function GildoniaBuilder.build(parent, opts)
	opts = opts or {}
	parent = parent or workspace
	rng = Random.new(opts.seed or 50005)
	local existing = parent:FindFirstChild("Gildonia")
	if existing then existing:Destroy() end

	root = Instance.new("Model"); root.Name = "Gildonia"
	fxParent = Instance.new("Folder"); fxParent.Name = "Decor"; fxParent.Parent = root
	structParent = Instance.new("Folder"); structParent.Name = "Structures"; structParent.Parent = root
	local districts = Instance.new("Folder"); districts.Name = "Districts"; districts.Parent = root

	buildGround()
	buildHeartTree()
	scatterFoliage()
	for _, s in ipairs(SECTORS) do buildSector(s, districts) end

	if opts.campaign ~= false then buildCampaign(root) end
	root:SetAttribute("Biome", "jungle")
	root:SetAttribute("Sectors", #SECTORS)
	root.Parent = parent
	return root
end

return GildoniaBuilder
