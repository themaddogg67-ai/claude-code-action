--[[
	SwamplandsBuilder  (ModuleScript)
	WHERE IT GOES: ServerStorage > SwamplandsBuilder

	Season 1's map: THE SWAMPLANDS ("Rise of Minus") — a murky bayou where the
	campaign begins, ending at the den of Minus, the gator general of Minus's
	army. Fifth built map; look pulled from the WorldAtlas "swamp" biome (murky
	green water, mud, mangroves). Ground-based.

	Same output shape as the other builders (workspace.Swamplands.Districts /
	.Campaign), so the shared CampaignController + route module run it unchanged.

	Route (Season 1 → Minus):
	  1 Muddy Banks · 2 Mangrove Maze · 3 Sunken Village · 4 Poison Marsh ·
	  5 The War Camp · 6 Gator's Den (boss)

	build(parent, opts) -> Model    (opts.seed number, opts.campaign bool=true)
	Bake:  require(game.ServerStorage.SwamplandsBuilder).build(workspace)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwamplandsBuilder = {}

local c   = Color3.fromRGB
local V   = Vector3.new
local CF  = CFrame.new
local ANG = CFrame.Angles

local function loadBiome()
	local ok, atlas = pcall(function() return require(ReplicatedStorage.Campaign.WorldAtlas) end)
	if ok and atlas and atlas.biome then local b = atlas.biome("swamp"); if b then return b end end
	return { material = "Mud", ground = { 60, 66, 46 }, accent = { 120, 160, 90 }, sky = "murky" }
end
local BIOME = loadBiome()
local function rgb(t) return c(t[1], t[2], t[3]) end

local PAL = {
	ground   = rgb(BIOME.ground),
	mud      = c(70, 60, 40),
	mudDark  = c(52, 44, 30),
	water    = c(46, 70, 52),
	waterDk  = c(34, 54, 40),
	trunk    = c(70, 56, 42),
	trunkDk  = c(52, 42, 32),
	leaf     = c(70, 120, 66),
	leafDk   = c(50, 92, 50),
	reed     = c(120, 140, 80),
	wood     = c(96, 74, 48),
	glow     = rgb(BIOME.accent),
	toxic    = c(150, 220, 90),
	fire     = c(255, 150, 60),
	banner   = c(120, 40, 40),
	gator    = c(60, 96, 58),
	white    = c(235, 240, 230),
}

local SECTORS = {
	{ stage = 1, name = "Muddy Banks",    x = 0,    z = 380,  theme = "banks",   color = PAL.glow,
	  objective = "Wade in through the muddy banks." },
	{ stage = 2, name = "Mangrove Maze",  x = -260, z = 210,  theme = "mangrove", color = PAL.leaf,
	  objective = "Find your way through the mangrove maze." },
	{ stage = 3, name = "Sunken Village",  x = 260, z = 210,  theme = "village", color = PAL.wood,
	  objective = "Search the sunken stilt village." },
	{ stage = 4, name = "Poison Marsh",   x = -300, z = -90,  theme = "marsh",   color = PAL.toxic,
	  objective = "Cross the poison marsh." },
	{ stage = 5, name = "The War Camp",   x = 300,  z = -90,  theme = "camp",    color = PAL.fire,
	  objective = "Raid Minus's war camp." },
	{ stage = 6, name = "Gator's Den",    x = 0,    z = -420, theme = "boss",    color = PAL.gator,
	  objective = "Enter the Gator's Den — defeat Minus.", boss = true },
}

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
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range or 14; l.Brightness = bright or 1.6; l.Parent = parent; return l
end
local function sign(cframe, size, text, color, parent)
	local board = deco({ Size = size, CFrame = cframe, Color = PAL.wood, Material = Enum.Material.Wood, Parent = parent or fxParent })
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28; gui.LightInfluence = 0; gui.Parent = board
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(0.92, 0.82); lbl.Position = UDim2.fromScale(0.04, 0.09)
	lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = color or PAL.white
	lbl.TextScaled = true; lbl.Parent = gui
	return board
end

-------------------------------------------------------------------
-- SWAMP PROPS
-------------------------------------------------------------------
local function waterPool(x, z, sx, sz, color)
	deco({ Size = V(sx, 3, sz), Color = color or PAL.water, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.12,
		CanCollide = true, CFrame = CF(x, -0.6, z) })
end
local function mangrove(x, z, scale)
	scale = scale or 1
	local h = (16 + rng:NextInteger(0, 10)) * scale
	deco({ Size = V(3 * scale, h, 3 * scale), Color = PAL.trunk, Material = Enum.Material.Wood,
		CFrame = CF(x, h / 2, z) * ANG(math.rad(rng:NextInteger(-6, 6)), 0, math.rad(rng:NextInteger(-6, 6))) })
	-- prop roots
	for i = 1, 4 do
		local a = math.rad(i * 90 + rng:NextInteger(-20, 20))
		deco({ Size = V(0.8, 6 * scale, 0.8), Color = PAL.trunkDk, Material = Enum.Material.Wood, CanCollide = true,
			CFrame = CF(x, 2.5 * scale, z) * ANG(math.rad(40), a, 0) })
	end
	-- canopy
	for i = 0, 1 do
		local r = (14 - i * 4) * scale
		deco({ Shape = Enum.PartType.Ball, Size = V(r, r * 0.7, r), Color = (i % 2 == 0) and PAL.leaf or PAL.leafDk, Material = Enum.Material.Grass,
			CFrame = CF(x + rng:NextInteger(-3, 3), h + i * 4 * scale, z + rng:NextInteger(-3, 3)) })
	end
	-- hanging moss
	if rng:NextNumber() < 0.6 then
		deco({ Size = V(0.4, rng:NextInteger(4, 9), 0.4), Color = PAL.leafDk, Material = Enum.Material.Grass, CFrame = CF(x + rng:NextInteger(-4, 4), h - 4, z + rng:NextInteger(-4, 4)) })
	end
end
local function reeds(x, z)
	for i = 1, 5 do
		deco({ Size = V(0.3, rng:NextInteger(4, 7), 0.3), Color = PAL.reed, Material = Enum.Material.Grass,
			CFrame = CF(x + rng:NextInteger(-3, 3), 3, z + rng:NextInteger(-3, 3)) * ANG(math.rad(rng:NextInteger(-14, 14)), 0, math.rad(rng:NextInteger(-14, 14))) })
	end
end
local function lilyPad(x, z)
	deco({ Shape = Enum.PartType.Cylinder, Size = V(0.3, 4, 4), Color = PAL.leaf, Material = Enum.Material.Grass, CanCollide = true,
		CFrame = CF(x, 0.5, z) * ANG(0, 0, math.rad(90)) })
end
local function firefly(x, z)
	local b = neon({ Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), Color = PAL.glow, Transparency = 0.1, CFrame = CF(x, rng:NextInteger(3, 8), z) })
	light(b, PAL.glow, 8, 1)
end
local function stiltHut(x, z, m)
	for _, o in ipairs({ V(-4, 0, -4), V(4, 0, -4), V(-4, 0, 4), V(4, 0, 4) }) do
		part({ Size = V(1, 8, 1), Color = PAL.wood, Material = Enum.Material.Wood, CFrame = CF(x + o.X, 4, z + o.Z), Parent = m })
	end
	part({ Size = V(11, 5, 11), Color = PAL.wood, Material = Enum.Material.WoodPlanks, CFrame = CF(x, 9.5, z) * ANG(math.rad(rng:NextInteger(-4, 4)), 0, 0), Parent = m })
	for i = 0, 3 do
		deco({ Size = V(13 - i * 3, 1.4, 13 - i * 3), Color = PAL.trunkDk, Material = Enum.Material.Wood, CFrame = CF(x, 12.5 + i * 1.2, z) * ANG(0, math.rad(45), 0) })
	end
end
local function boardwalk(x1, z1, x2, z2, m)
	local a, b = V(x1, 1, z1), V(x2, 1, z2)
	local mid = (a + b) / 2; local len = (b - a).Magnitude
	if len < 1 then return end
	part({ Size = V(6, 0.8, len), Color = PAL.wood, Material = Enum.Material.WoodPlanks, CFrame = CFrame.lookAt(mid, b), Parent = m })
end

-------------------------------------------------------------------
-- ENVIRONMENT
-------------------------------------------------------------------
local function buildGround()
	part({ Size = V(1300, 6, 1300), Color = PAL.ground, Material = Enum.Material.Mud, CFrame = CF(0, -3, 0), Parent = structParent })
	-- big water areas + mud islands
	for _ = 1, 22 do
		waterPool(rng:NextInteger(-480, 480), rng:NextInteger(-480, 480), rng:NextInteger(40, 90), rng:NextInteger(40, 90))
	end
	for _ = 1, 16 do
		deco({ Shape = Enum.PartType.Ball, Size = V(rng:NextInteger(30, 60), rng:NextInteger(6, 12), rng:NextInteger(30, 60)), Color = PAL.mud, Material = Enum.Material.Mud,
			CanCollide = true, CFrame = CF(rng:NextInteger(-460, 460), -1, rng:NextInteger(-460, 460)) })
	end
	-- perimeter mangroves
	for i = 0, 60 do
		local a = math.rad(i / 60 * 360); local rr = 560 + rng:NextInteger(-20, 20)
		mangrove(math.cos(a) * rr, math.sin(a) * rr, 1.3)
	end
end
local function scatterSwamp()
	for _ = 1, 60 do
		local x, z = rng:NextInteger(-470, 470), rng:NextInteger(-470, 470)
		if math.abs(x) > 26 or math.abs(z) > 26 then
			local r = rng:NextNumber()
			if r < 0.4 then mangrove(x, z, rng:NextNumber(0.8, 1.2))
			elseif r < 0.6 then reeds(x, z)
			elseif r < 0.75 then lilyPad(x, z)
			elseif r < 0.9 then firefly(x, z)
			else deco({ Shape = Enum.PartType.Ball, Size = V(5, 3, 4), Color = PAL.mudDark, Material = Enum.Material.Rock, CanCollide = true, CFrame = CF(x, 1, z) }) end
		end
	end
end

-------------------------------------------------------------------
-- SECTOR BUILDS
-------------------------------------------------------------------
local function buildBanks(s, m)
	boardwalk(s.x, s.z + 20, s.x, s.z - 20, m)
	for i = 1, 4 do reeds(s.x + rng:NextInteger(-20, 20), s.z + rng:NextInteger(-20, 20)) end
	waterPool(s.x, s.z, 70, 70)
end
local function buildMangrove(s, m)
	for i = 1, 10 do mangrove(s.x + rng:NextInteger(-28, 28), s.z + rng:NextInteger(-28, 28), rng:NextNumber(0.9, 1.3)) end
	for i = 1, 4 do firefly(s.x + rng:NextInteger(-24, 24), s.z + rng:NextInteger(-24, 24)) end
end
local function buildVillage(s, m)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		stiltHut(s.x + math.cos(a) * 26, s.z + math.sin(a) * 26, m)
	end
	boardwalk(s.x - 26, s.z, s.x + 26, s.z, m); boardwalk(s.x, s.z - 26, s.x, s.z + 26, m)
	waterPool(s.x, s.z, 80, 80)
end
local function buildMarsh(s, m)
	waterPool(s.x, s.z, 90, 90, PAL.toxic)
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, 80, 80), Color = PAL.toxic, Transparency = 0.7, CFrame = CF(s.x, 0.6, s.z) * ANG(0, 0, math.rad(90)) })
	-- bubbling toxic pods
	for i = 1, 6 do
		local a = math.rad(i * 60)
		local pod = neon({ Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = PAL.toxic, Transparency = 0.2, CFrame = CF(s.x + math.cos(a) * 20, 1.5, s.z + math.sin(a) * 20) })
		light(pod, PAL.toxic, 12, 1.4)
	end
	for i = 1, 5 do lilyPad(s.x + rng:NextInteger(-30, 30), s.z + rng:NextInteger(-30, 30)) end
end
local function buildCamp(s, m)
	-- Minus's war camp: tents, banners, watchfire, weapon racks
	for i = -1, 1 do
		local tx = s.x + i * 18
		part({ Size = V(12, 8, 12), Color = c(70, 60, 46), Material = Enum.Material.Fabric, CFrame = CF(tx, 4, s.z) * ANG(0, math.rad(45), 0), Parent = m })
		-- banner
		part({ Size = V(0.4, 12, 0.4), Color = PAL.trunkDk, Material = Enum.Material.Wood, CFrame = CF(tx, 6, s.z - 8), Parent = m })
		deco({ Size = V(4, 6, 0.3), Color = PAL.banner, Material = Enum.Material.Fabric, CFrame = CF(tx, 9, s.z - 8) })
	end
	-- watchfire
	local fire = neon({ Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = PAL.fire, Transparency = 0.1, CFrame = CF(s.x, 2, s.z + 20), Parent = m })
	light(fire, PAL.fire, 24, 3); local f = Instance.new("Fire"); f.Size = 8; f.Heat = 8; f.Color = PAL.fire; f.Parent = fire
end
local function buildGatorDen(s, m)
	-- a raised mud-and-bone throne mound in dark water, ringed with torches
	deco({ Shape = Enum.PartType.Cylinder, Size = V(3, 150, 150), Color = PAL.waterDk, Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.1, CanCollide = true,
		CFrame = CF(s.x, -0.8, s.z) * ANG(0, 0, math.rad(90)) })
	part({ Shape = Enum.PartType.Cylinder, Size = V(4, 60, 60), Color = PAL.mud, Material = Enum.Material.Mud, CFrame = CF(s.x, 1.5, s.z) * ANG(0, 0, math.rad(90)), Parent = m })
	-- throne
	part({ Size = V(14, 12, 6), Color = PAL.mudDark, Material = Enum.Material.Rock, CFrame = CF(s.x, 7, s.z - 12), Parent = m })
	-- bone spikes + torches ringing the mound
	for i = 1, 10 do
		local a = math.rad(i * 36)
		part({ Size = V(1.4, rng:NextInteger(8, 16), 1.4), Color = c(210, 205, 185), Material = Enum.Material.Slate,
			CFrame = CF(s.x + math.cos(a) * 30, 6, s.z + math.sin(a) * 30) * ANG(math.rad(rng:NextInteger(-14, 14)), 0, math.rad(rng:NextInteger(-14, 14))), Parent = m })
		if i % 2 == 0 then
			local t = neon({ Shape = Enum.PartType.Ball, Size = V(1.6, 2, 1.6), Color = PAL.fire, Transparency = 0.1, CFrame = CF(s.x + math.cos(a) * 34, 5, s.z + math.sin(a) * 34) })
			light(t, PAL.fire, 16, 2); local fr = Instance.new("Fire"); fr.Size = 5; fr.Color = PAL.fire; fr.Parent = t
		end
	end
	local glow = neon({ Shape = Enum.PartType.Ball, Size = V(6, 6, 6), Color = PAL.gator, Transparency = 0.3, CanCollide = false, CFrame = CF(s.x, 16, s.z - 12), Parent = m })
	light(glow, PAL.gator, 40, 2.5)
end

local function buildSector(s, districts)
	local m = Instance.new("Model"); m.Name = (s.name:gsub("[%s']", "")); m.Parent = districts
	m:SetAttribute("District", s.name)
	if s.theme == "banks" then buildBanks(s, m)
	elseif s.theme == "mangrove" then buildMangrove(s, m)
	elseif s.theme == "village" then buildVillage(s, m)
	elseif s.theme == "marsh" then buildMarsh(s, m)
	elseif s.theme == "camp" then buildCamp(s, m)
	elseif s.theme == "boss" then buildGatorDen(s, m) end
	if s.theme ~= "boss" then sign(CF(s.x, 8, s.z + 32), V(20, 6, 0.4), string.upper(s.name), s.color, m) end
	return m
end

-------------------------------------------------------------------
-- CAMPAIGN SCAFFOLDING
-------------------------------------------------------------------
local function spawnAt(pos, name, parent, enabled)
	local sp = Instance.new("SpawnLocation")
	sp.Name = name; sp.Size = V(12, 1, 12); sp.Anchored = true; sp.CanCollide = true
	sp.Neutral = true; sp.Duration = 0; sp.Enabled = enabled ~= false
	sp.Color = PAL.glow; sp.Material = Enum.Material.Neon; sp.Transparency = 0.3
	sp.TopSurface = Enum.SurfaceType.Smooth; sp.CFrame = CF(pos.X, 2, pos.Z); sp.Parent = parent
	return sp
end
local function buildCampaign(m)
	local camp = Instance.new("Folder"); camp.Name = "Campaign"; camp.Parent = m
	local spawns = Instance.new("Folder"); spawns.Name = "Spawns"; spawns.Parent = camp
	local objectives = Instance.new("Folder"); objectives.Name = "Objectives"; objectives.Parent = camp
	spawnAt(V(SECTORS[1].x, 0, SECTORS[1].z - 24), "CampaignStart", spawns, true)
	for _, s in ipairs(SECTORS) do
		local beacon = part({ Shape = Enum.PartType.Cylinder, Size = V(30, 8, 8), Color = PAL.glow,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true,
			CFrame = CF(s.x, 16, s.z) * ANG(0, 0, math.rad(90)), Parent = objectives })
		beacon.Name = "Stage" .. s.stage .. "_" .. (s.name:gsub("[%s']", ""))
		beacon:SetAttribute("Stage", s.stage); beacon:SetAttribute("District", s.name); beacon:SetAttribute("Objective", s.objective)
		light(beacon, PAL.glow, 26, 2)
		local sp = spawnAt(V(s.x, 0, s.z), "Checkpoint_" .. s.stage, spawns, false); sp.Enabled = false
	end
	return camp
end

function SwamplandsBuilder.build(parent, opts)
	opts = opts or {}
	parent = parent or workspace
	rng = Random.new(opts.seed or 10001)
	local existing = parent:FindFirstChild("Swamplands")
	if existing then existing:Destroy() end
	root = Instance.new("Model"); root.Name = "Swamplands"
	fxParent = Instance.new("Folder"); fxParent.Name = "Decor"; fxParent.Parent = root
	structParent = Instance.new("Folder"); structParent.Name = "Structures"; structParent.Parent = root
	local districts = Instance.new("Folder"); districts.Name = "Districts"; districts.Parent = root
	buildGround()
	scatterSwamp()
	for _, s in ipairs(SECTORS) do buildSector(s, districts) end
	if opts.campaign ~= false then buildCampaign(root) end
	root:SetAttribute("Biome", "swamp"); root:SetAttribute("Sectors", #SECTORS)
	root.Parent = parent
	return root
end

return SwamplandsBuilder
