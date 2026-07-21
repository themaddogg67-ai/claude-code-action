--[[
	RuinedCityBuilder  (ModuleScript)
	WHERE IT GOES: ServerStorage > RuinedCityBuilder

	Season 7's map: RUINED CITY ("Omega's Chaos") — a devastated Earth city torn
	apart as Omega rampages through it. Fourth map on the framework; its look is
	pulled from the WorldAtlas "ruin" biome (ash-grey concrete, ember-orange
	accents) with a red doomsday sky glow. Ends at Ground Zero against Omega.

	Same output shape as the other builders (workspace.RuinedCity.Districts /
	.Campaign), so the shared CampaignController + route module run it unchanged.

	Route (Season 7 → Omega):
	  1 Evacuation Zone · 2 Broken Streets · 3 Collapsed Plaza ·
	  4 Burning District · 5 The Barricade · 6 Ground Zero (boss)

	build(parent, opts) -> Model    (opts.seed number, opts.campaign bool=true)
	Bake:  require(game.ServerStorage.RuinedCityBuilder).build(workspace)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuinedCityBuilder = {}

local c   = Color3.fromRGB
local V   = Vector3.new
local CF  = CFrame.new
local ANG = CFrame.Angles

local function loadBiome()
	local ok, atlas = pcall(function() return require(ReplicatedStorage.Campaign.WorldAtlas) end)
	if ok and atlas and atlas.biome then local b = atlas.biome("ruin"); if b then return b end end
	return { material = "Concrete", ground = { 60, 56, 50 }, accent = { 120, 110, 100 }, sky = "decay" }
end
local BIOME = loadBiome()
local function rgb(t) return c(t[1], t[2], t[3]) end

local PAL = {
	ground   = rgb(BIOME.ground),
	ash      = c(46, 42, 40),
	concrete = c(110, 104, 96),
	concreteDk = c(72, 68, 62),
	rebar    = c(90, 70, 50),
	glass    = c(40, 46, 54),
	fire     = c(255, 130, 50),
	ember    = c(255, 90, 30),
	smoke    = c(40, 38, 36),
	rust     = c(120, 70, 40),
	sky      = c(180, 70, 40),      -- red doomsday glow
	omega    = c(235, 50, 40),
	white    = c(235, 235, 240),
}

local SECTORS = {
	{ stage = 1, name = "Evacuation Zone",  x = 0,    z = 380,  theme = "evac",     color = rgb(BIOME.accent),
	  objective = "Cover the evacuation as the city falls." },
	{ stage = 2, name = "Broken Streets",   x = -260, z = 200,  theme = "streets",  color = PAL.fire,
	  objective = "Push through the wrecked streets." },
	{ stage = 3, name = "Collapsed Plaza",  x = 260,  z = 200,  theme = "plaza",    color = PAL.concrete,
	  objective = "Cross the collapsed central plaza." },
	{ stage = 4, name = "Burning District", x = -300, z = -80,  theme = "burning",  color = PAL.fire,
	  objective = "Fight through the burning district." },
	{ stage = 5, name = "The Barricade",    x = 300,  z = -80,  theme = "barricade", color = rgb(BIOME.accent),
	  objective = "Hold the barricade — the last line." },
	{ stage = 6, name = "Ground Zero",      x = 0,    z = -420, theme = "boss",     color = PAL.omega,
	  objective = "Ground Zero — stop Omega.", boss = true },
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
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range or 16; l.Brightness = bright or 2; l.Parent = parent; return l
end
local function sign(cframe, size, text, color, parent)
	local board = deco({ Size = size, CFrame = cframe, Color = PAL.ash, Material = Enum.Material.Concrete, Parent = parent or fxParent })
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28; gui.LightInfluence = 0; gui.Parent = board
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(0.92, 0.82); lbl.Position = UDim2.fromScale(0.04, 0.09)
	lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = color or PAL.white
	lbl.TextScaled = true; lbl.Parent = gui
	return board
end

-------------------------------------------------------------------
-- RUIN PROPS
-------------------------------------------------------------------
local function fireProp(x, z, s)
	s = s or 1
	local core = neon({ Shape = Enum.PartType.Ball, Size = V(1.5, 2, 1.5) * s, Color = PAL.fire, Transparency = 0.2, CFrame = CF(x, 1.5 * s, z) })
	light(core, PAL.fire, 20 * s, 2.4)
	local f = Instance.new("Fire"); f.Size = 8 * s; f.Heat = 8; f.Color = PAL.fire; f.SecondaryColor = PAL.ember; f.Parent = core
end
local function smokeColumn(x, z)
	local anchor = deco({ Size = V(2, 2, 2), Transparency = 1, CFrame = CF(x, 4, z) })
	local att = Instance.new("Attachment"); att.Parent = anchor
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Color = ColorSequence.new(PAL.smoke)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 28) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 5); smoke.Rate = 7; smoke.Speed = NumberRange.new(5, 9); smoke.Parent = att
end
local function rubble(x, z, spread)
	spread = spread or 12
	for _ = 1, 6 do
		deco({ Size = V(rng:NextInteger(2, 6), rng:NextInteger(1, 3), rng:NextInteger(2, 6)),
			Color = (rng:NextNumber() < 0.5) and PAL.concrete or PAL.concreteDk, Material = Enum.Material.Concrete, CanCollide = true,
			CFrame = CF(x + rng:NextInteger(-spread, spread), 1, z + rng:NextInteger(-spread, spread)) * ANG(math.rad(rng:NextInteger(-20, 20)), math.rad(rng:NextInteger(0, 360)), math.rad(rng:NextInteger(-20, 20))) })
	end
end
local function wreckedCar(x, z)
	local body = part({ Size = V(6, 3, 12), Color = c(rng:NextInteger(40, 90), rng:NextInteger(40, 70), rng:NextInteger(40, 70)), Material = Enum.Material.CorrodedMetal,
		CFrame = CF(x, 1.5, z) * ANG(math.rad(rng:NextInteger(-8, 8)), math.rad(rng:NextInteger(0, 360)), math.rad(rng:NextInteger(-6, 20))), Parent = structParent })
	deco({ Size = V(5, 2.4, 6), Color = PAL.glass, Transparency = 0.4, CFrame = body.CFrame * CF(0, 2.2, -1) })
	if rng:NextNumber() < 0.35 then fireProp(x, z, 0.7) end
end
-- a broken skyscraper: tilted main box + a sheared, offset top and exposed floors
local function ruinedTower(x, z, w, h, color)
	local tilt = ANG(math.rad(rng:NextInteger(-8, 8)), math.rad(rng:NextInteger(0, 360)), math.rad(rng:NextInteger(-8, 8)))
	local body = part({ Size = V(w, h, w), Color = PAL.concreteDk, Material = Enum.Material.Concrete,
		CFrame = CF(x, h / 2, z) * tilt, Parent = structParent })
	-- exposed rebar / broken top
	local topH = rng:NextInteger(6, 16)
	part({ Size = V(w * 0.7, topH, w * 0.6), Color = PAL.concrete, Material = Enum.Material.Concrete,
		CFrame = body.CFrame * CF(rng:NextInteger(-3, 3), h / 2 + topH / 2 - 3, rng:NextInteger(-3, 3)) * ANG(math.rad(rng:NextInteger(-14, 14)), 0, math.rad(rng:NextInteger(-14, 14))), Parent = structParent })
	for i = 1, 3 do
		deco({ Size = V(0.4, rng:NextInteger(3, 7), 0.4), Color = PAL.rebar, Material = Enum.Material.Metal,
			CFrame = body.CFrame * CF(rng:NextInteger(-w / 3, w / 3), h / 2 + 2, rng:NextInteger(-w / 3, w / 3)) })
	end
	-- flickering window remnants
	for _ = 1, 4 do
		neon({ Size = V(1.6, 1.2, 0.3), Color = (rng:NextNumber() < 0.5) and PAL.fire or color, Transparency = 0.3,
			CFrame = body.CFrame * CF(w / 2 + 0.1, rng:NextInteger(-h / 3, h / 3), rng:NextInteger(-w / 3, w / 3)) })
	end
	if rng:NextNumber() < 0.5 then smokeColumn(x, z) end
end

-------------------------------------------------------------------
-- ENVIRONMENT
-------------------------------------------------------------------
local function buildGround()
	part({ Size = V(1300, 6, 1300), Color = PAL.ground, Material = Enum.Material.Concrete, CFrame = CF(0, -3, 0), Parent = structParent })
	-- scorched patches + ash
	for _ = 1, 30 do
		deco({ Size = V(rng:NextInteger(20, 60), 0.4, rng:NextInteger(20, 60)), Color = PAL.ash, Material = Enum.Material.Ground,
			CFrame = CF(rng:NextInteger(-500, 500), 0.3, rng:NextInteger(-500, 500)) })
	end
	-- broken road cross
	for _, rot in ipairs({ 0, 90 }) do
		deco({ Size = V(40, 0.4, 1080), Color = PAL.concreteDk, Material = Enum.Material.Asphalt, CFrame = CF(0, 0.35, 0) * ANG(0, math.rad(rot), 0) })
	end
	-- perimeter of collapsed towers
	for i = 0, 40 do
		local a = math.rad(i / 40 * 360)
		local rr = 560 + rng:NextInteger(-25, 25)
		ruinedTower(math.cos(a) * rr, math.sin(a) * rr, rng:NextInteger(22, 40), rng:NextInteger(80, 200), PAL.fire)
	end
end

local function scatterDebris()
	for _ = 1, 40 do
		local x, z = rng:NextInteger(-460, 460), rng:NextInteger(-460, 460)
		if math.abs(x) > 26 or math.abs(z) > 26 then
			local r = rng:NextNumber()
			if r < 0.4 then rubble(x, z)
			elseif r < 0.65 then wreckedCar(x, z)
			elseif r < 0.85 then ruinedTower(x, z, rng:NextInteger(20, 34), rng:NextInteger(60, 150), PAL.fire)
			else fireProp(x, z, rng:NextNumber(0.7, 1.3)) end
		end
	end
end

-------------------------------------------------------------------
-- SECTOR BUILDS
-------------------------------------------------------------------
local function buildEvac(s, m)
	-- buses + barricades + supply crates
	for i = -1, 1 do
		part({ Size = V(8, 6, 22), Color = c(200, 180, 60), Material = Enum.Material.CorrodedMetal,
			CFrame = CF(s.x + i * 20, 3, s.z + rng:NextInteger(-6, 6)) * ANG(0, math.rad(rng:NextInteger(-10, 10)), 0), Parent = m })
	end
	for i = -2, 2 do
		part({ Size = V(6, 3, 2), Color = PAL.concrete, Material = Enum.Material.Concrete, CFrame = CF(s.x + i * 8, 1.5, s.z + 16), Parent = m })
	end
	fireProp(s.x - 14, s.z - 10); smokeColumn(s.x + 16, s.z + 8)
end
local function buildStreets(s, m)
	for i = 1, 5 do wreckedCar(s.x + rng:NextInteger(-24, 24), s.z + rng:NextInteger(-24, 24)) end
	rubble(s.x, s.z, 26); rubble(s.x + 18, s.z - 14, 16)
	fireProp(s.x + 10, s.z + 12)
end
local function buildPlaza(s, m)
	-- a giant toppled tower lying across the plaza + a crater
	part({ Size = V(24, 24, 120), Color = PAL.concreteDk, Material = Enum.Material.Concrete,
		CFrame = CF(s.x, 10, s.z) * ANG(math.rad(6), math.rad(30), 0), Parent = m })
	deco({ Shape = Enum.PartType.Cylinder, Size = V(3, 60, 60), Color = PAL.ash, CanCollide = true,
		CFrame = CF(s.x - 30, 0.4, s.z + 20) * ANG(0, 0, math.rad(90)) })
	rubble(s.x + 30, s.z, 22); smokeColumn(s.x, s.z)
end
local function buildBurning(s, m)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		ruinedTower(s.x + math.cos(a) * 24, s.z + math.sin(a) * 24, rng:NextInteger(18, 28), rng:NextInteger(50, 110), PAL.fire)
		fireProp(s.x + math.cos(a) * 14, s.z + math.sin(a) * 14, 1.2)
	end
	smokeColumn(s.x, s.z)
end
local function buildBarricade(s, m)
	-- sandbag + concrete last-stand line
	for i = -3, 3 do
		part({ Size = V(6, 3.5, 3), Color = PAL.rust, Material = Enum.Material.Sand, CFrame = CF(s.x + i * 6, 1.75, s.z) * ANG(0, 0, math.rad(rng:NextInteger(-4, 4))), Parent = m })
		part({ Size = V(4, 5, 2), Color = PAL.concrete, Material = Enum.Material.Concrete, CFrame = CF(s.x + i * 6 + 3, 2.5, s.z + 5), Parent = m })
	end
	fireProp(s.x - 20, s.z - 8); fireProp(s.x + 20, s.z - 8)
	rubble(s.x, s.z + 14, 18)
end
local function buildGroundZero(s, m)
	-- a massive impact crater, ringed with debris and a red devastation glow
	deco({ Shape = Enum.PartType.Cylinder, Size = V(4, 170, 170), Color = PAL.ash, Material = Enum.Material.Ground, CanCollide = true,
		CFrame = CF(s.x, 0.4, s.z) * ANG(0, 0, math.rad(90)) })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, 150, 150), Color = PAL.omega, Transparency = 0.55, CFrame = CF(s.x, 1, s.z) * ANG(0, 0, math.rad(90)) })
	for i = 1, 12 do
		local a = math.rad(i * 30)
		part({ Size = V(rng:NextInteger(6, 12), rng:NextInteger(16, 34), rng:NextInteger(6, 12)), Color = PAL.concreteDk, Material = Enum.Material.Concrete,
			CFrame = CF(s.x + math.cos(a) * 62, 12, s.z + math.sin(a) * 62) * ANG(math.rad(rng:NextInteger(-20, 20)), 0, math.rad(rng:NextInteger(-20, 20))), Parent = m })
		if i % 2 == 0 then fireProp(s.x + math.cos(a) * 44, s.z + math.sin(a) * 44, 1.4) end
	end
	local glow = neon({ Shape = Enum.PartType.Ball, Size = V(10, 10, 10), Color = PAL.omega, Transparency = 0.2, CanCollide = false, CFrame = CF(s.x, 20, s.z), Parent = m })
	light(glow, PAL.omega, 80, 4)
	smokeColumn(s.x - 30, s.z); smokeColumn(s.x + 30, s.z + 20)
end

local function buildSector(s, districts)
	local m = Instance.new("Model"); m.Name = (s.name:gsub("%s", "")); m.Parent = districts
	m:SetAttribute("District", s.name)
	if s.theme == "evac" then buildEvac(s, m)
	elseif s.theme == "streets" then buildStreets(s, m)
	elseif s.theme == "plaza" then buildPlaza(s, m)
	elseif s.theme == "burning" then buildBurning(s, m)
	elseif s.theme == "barricade" then buildBarricade(s, m)
	elseif s.theme == "boss" then buildGroundZero(s, m) end
	if s.theme ~= "boss" then sign(CF(s.x, 8, s.z + 30), V(20, 6, 0.4), string.upper(s.name), s.color, m) end
	return m
end

-------------------------------------------------------------------
-- CAMPAIGN SCAFFOLDING
-------------------------------------------------------------------
local function spawnAt(pos, name, parent, enabled)
	local sp = Instance.new("SpawnLocation")
	sp.Name = name; sp.Size = V(12, 1, 12); sp.Anchored = true; sp.CanCollide = true
	sp.Neutral = true; sp.Duration = 0; sp.Enabled = enabled ~= false
	sp.Color = PAL.fire; sp.Material = Enum.Material.Neon; sp.Transparency = 0.3
	sp.TopSurface = Enum.SurfaceType.Smooth; sp.CFrame = CF(pos.X, 1, pos.Z); sp.Parent = parent
	return sp
end
local function buildCampaign(m)
	local camp = Instance.new("Folder"); camp.Name = "Campaign"; camp.Parent = m
	local spawns = Instance.new("Folder"); spawns.Name = "Spawns"; spawns.Parent = camp
	local objectives = Instance.new("Folder"); objectives.Name = "Objectives"; objectives.Parent = camp
	spawnAt(V(SECTORS[1].x, 0, SECTORS[1].z - 24), "CampaignStart", spawns, true)
	for _, s in ipairs(SECTORS) do
		local beacon = part({ Shape = Enum.PartType.Cylinder, Size = V(30, 8, 8), Color = PAL.fire,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true,
			CFrame = CF(s.x, 15, s.z) * ANG(0, 0, math.rad(90)), Parent = objectives })
		beacon.Name = "Stage" .. s.stage .. "_" .. (s.name:gsub("%s", ""))
		beacon:SetAttribute("Stage", s.stage); beacon:SetAttribute("District", s.name); beacon:SetAttribute("Objective", s.objective)
		light(beacon, PAL.fire, 26, 2)
		local sp = spawnAt(V(s.x, 0, s.z), "Checkpoint_" .. s.stage, spawns, false); sp.Enabled = false
	end
	return camp
end

function RuinedCityBuilder.build(parent, opts)
	opts = opts or {}
	parent = parent or workspace
	rng = Random.new(opts.seed or 70007)
	local existing = parent:FindFirstChild("RuinedCity")
	if existing then existing:Destroy() end
	root = Instance.new("Model"); root.Name = "RuinedCity"
	fxParent = Instance.new("Folder"); fxParent.Name = "Decor"; fxParent.Parent = root
	structParent = Instance.new("Folder"); structParent.Name = "Structures"; structParent.Parent = root
	local districts = Instance.new("Folder"); districts.Name = "Districts"; districts.Parent = root
	buildGround()
	scatterDebris()
	for _, s in ipairs(SECTORS) do buildSector(s, districts) end
	if opts.campaign ~= false then buildCampaign(root) end
	root:SetAttribute("Biome", "ruin"); root:SetAttribute("Sectors", #SECTORS)
	root.Parent = parent
	return root
end

return RuinedCityBuilder
