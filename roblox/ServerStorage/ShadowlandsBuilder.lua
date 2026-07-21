--[[
	ShadowlandsBuilder  (ModuleScript)
	WHERE IT GOES: ServerStorage > ShadowlandsBuilder

	Season 3's map: THE SHADOWLANDS ("Orders From Above") — the dark domain of
	Null, master of the army of darkness. Sixth built map; look pulled from the
	WorldAtlas "shadow" biome (near-black ground, purple void accents, eclipse
	sky). Ground-based. Ends at Null's Throne.

	Same output shape as the other builders (workspace.Shadowlands.Districts /
	.Campaign), so the shared CampaignController + route module run it unchanged.

	Route (Season 3 → Null):
	  1 Broken Gate · 2 Ashen Wastes · 3 Shadow Spires · 4 The Dark Bastion ·
	  5 Throne Approach · 6 Null's Throne (boss)

	build(parent, opts) -> Model    (opts.seed, opts.campaign)
	Bake:  require(game.ServerStorage.ShadowlandsBuilder).build(workspace)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShadowlandsBuilder = {}

local c   = Color3.fromRGB
local V   = Vector3.new
local CF  = CFrame.new
local ANG = CFrame.Angles

local function loadBiome()
	local ok, atlas = pcall(function() return require(ReplicatedStorage.Campaign.WorldAtlas) end)
	if ok and atlas and atlas.biome then local b = atlas.biome("shadow"); if b then return b end end
	return { material = "SmoothPlastic", ground = { 22, 20, 28 }, accent = { 120, 60, 255 }, sky = "eclipse" }
end
local BIOME = loadBiome()
local function rgb(t) return c(t[1], t[2], t[3]) end

local PAL = {
	ground   = rgb(BIOME.ground),
	groundDk = c(12, 10, 16),
	accent   = rgb(BIOME.accent),
	shadow   = c(16, 12, 22),
	shadow2  = c(28, 20, 38),
	purple   = c(150, 60, 255),
	violet   = c(110, 40, 210),
	pink     = c(210, 70, 220),
	bone     = c(180, 170, 185),
	stone    = c(40, 36, 48),
	white    = c(230, 225, 240),
}

local SECTORS = {
	{ stage = 1, name = "Broken Gate",     x = 0,    z = 380,  theme = "gate",    color = PAL.purple,
	  objective = "Breach the broken gate.",              villainObjective = "Seal the broken gate behind you." },
	{ stage = 2, name = "Ashen Wastes",    x = -260, z = 210,  theme = "wastes",  color = PAL.pink,
	  objective = "Cross the ashen wastes.",              villainObjective = "Drive the heroes off the ashen wastes." },
	{ stage = 3, name = "Shadow Spires",   x = 260,  z = 210,  theme = "spires",  color = PAL.purple,
	  objective = "Climb through the shadow spires.",     villainObjective = "Ambush the heroes among the spires." },
	{ stage = 4, name = "The Dark Bastion", x = -300, z = -90,  theme = "bastion", color = PAL.violet,
	  objective = "Storm the Dark Bastion.",              villainObjective = "Hold the Dark Bastion." },
	{ stage = 5, name = "Throne Approach", x = 300,  z = -90,  theme = "approach", color = PAL.pink,
	  objective = "Fight up the throne approach.",        villainObjective = "Guard the throne approach." },
	{ stage = 6, name = "Null's Throne",   x = 0,    z = -430, theme = "boss",    color = PAL.purple,
	  objective = "Null's Throne — end the darkness.",    villainObjective = "Null's Throne — destroy the Golden Knight.", boss = true },
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
	local board = deco({ Size = size, CFrame = cframe, Color = PAL.shadow, Material = Enum.Material.SmoothPlastic, Parent = parent or fxParent })
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28; gui.LightInfluence = 0; gui.Parent = board
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(0.92, 0.82); lbl.Position = UDim2.fromScale(0.04, 0.09)
	lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = color or PAL.white
	lbl.TextScaled = true; lbl.Parent = gui
	return board
end

-------------------------------------------------------------------
-- SHADOW PROPS
-------------------------------------------------------------------
local function spire(x, z, h, color)
	part({ Size = V(rng:NextInteger(4, 8), h, rng:NextInteger(4, 8)), Color = PAL.shadow, Material = Enum.Material.Slate,
		CFrame = CF(x, h / 2, z) * ANG(math.rad(rng:NextInteger(-6, 6)), math.rad(rng:NextInteger(0, 360)), math.rad(rng:NextInteger(-6, 6))), Parent = structParent })
	part({ Size = V(2.5, h * 0.5, 2.5), Color = PAL.shadow2, Material = Enum.Material.Slate,
		CFrame = CF(x, h + h * 0.2, z) * ANG(math.rad(rng:NextInteger(-12, 12)), 0, math.rad(rng:NextInteger(-12, 12))), Parent = structParent })
	neon({ Size = V(0.6, h * 0.7, 0.6), Color = color or PAL.purple, Transparency = 0.2, CFrame = CF(x, h / 2, z + 2.6) })
end
local function darkCrystal(x, z, s, color)
	local cr = neon({ Size = V(2, 8, 2) * (s or 1), Color = color or PAL.purple, Transparency = 0.15,
		CFrame = CF(x, 4 * (s or 1), z) * ANG(math.rad(rng:NextInteger(-18, 18)), math.rad(rng:NextInteger(0, 360)), math.rad(rng:NextInteger(-18, 18))) })
	light(cr, color or PAL.purple, 14 * (s or 1), 1.8)
end
local function shadowFire(x, z)
	local core = neon({ Shape = Enum.PartType.Ball, Size = V(1.5, 2, 1.5), Color = PAL.purple, Transparency = 0.2, CFrame = CF(x, 1.5, z) })
	light(core, PAL.purple, 18, 2)
	local f = Instance.new("Fire"); f.Size = 7; f.Heat = 4; f.Color = PAL.purple; f.SecondaryColor = PAL.pink; f.Parent = core
end
local function voidRift(x, z, r)
	deco({ Shape = Enum.PartType.Cylinder, Size = V(2, r * 2, r * 2), Color = PAL.groundDk, CanCollide = true,
		CFrame = CF(x, 0.4, z) * ANG(0, 0, math.rad(90)) })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, r * 2 - 2, r * 2 - 2), Color = PAL.purple, Transparency = 0.5, CFrame = CF(x, 0.9, z) * ANG(0, 0, math.rad(90)) })
end
local function tendril(x, z, h)
	local prev = CF(x, 0, z)
	for i = 1, 3 do
		local seg = neon({ Size = V(1 - i * 0.2, h / 3, 1 - i * 0.2), Color = PAL.violet, Transparency = 0.2,
			CFrame = prev * CF(0, h / 6, 0) * ANG(math.rad(20 + i * 10), math.rad(rng:NextInteger(-30, 30)), 0) })
		prev = seg.CFrame * CF(0, h / 6, 0)
	end
end

-------------------------------------------------------------------
-- ENVIRONMENT
-------------------------------------------------------------------
local function buildGround()
	part({ Size = V(1300, 6, 1300), Color = PAL.ground, Material = Enum.Material.Slate, CFrame = CF(0, -3, 0), Parent = structParent })
	for _ = 1, 26 do
		neon({ Size = V(rng:NextInteger(40, 120), 0.3, 0.8), Color = PAL.violet, Transparency = 0.8,
			CFrame = CF(rng:NextInteger(-500, 500), 0.3, rng:NextInteger(-500, 500)) * ANG(0, math.rad(rng:NextInteger(0, 360)), 0) })
	end
	for i = 0, 46 do
		local a = math.rad(i / 46 * 360); local rr = 560 + rng:NextInteger(-25, 25)
		spire(math.cos(a) * rr, math.sin(a) * rr, rng:NextInteger(70, 160), PAL.purple)
	end
end
local function scatter()
	for _ = 1, 55 do
		local x, z = rng:NextInteger(-470, 470), rng:NextInteger(-470, 470)
		if math.abs(x) > 26 or math.abs(z) > 26 then
			local r = rng:NextNumber()
			if r < 0.35 then spire(x, z, rng:NextInteger(30, 90), PAL.purple)
			elseif r < 0.6 then darkCrystal(x, z, rng:NextNumber(0.7, 1.4))
			elseif r < 0.8 then tendril(x, z, rng:NextInteger(8, 16))
			else shadowFire(x, z) end
		end
	end
end

-------------------------------------------------------------------
-- SECTOR BUILDS
-------------------------------------------------------------------
local function buildGate(s, m)
	for _, side in ipairs({ -1, 1 }) do
		part({ Size = V(8, 44, 12), Color = PAL.stone, Material = Enum.Material.Slate, CFrame = CF(s.x + side * 16, 22, s.z) * ANG(0, 0, math.rad(side * 4)), Parent = m })
	end
	part({ Size = V(44, 8, 12), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x, 42, s.z) * ANG(math.rad(3), 0, 0), Parent = m })
	darkCrystal(s.x - 20, s.z, 1.2); darkCrystal(s.x + 20, s.z, 1.2)
	shadowFire(s.x - 14, s.z - 10); shadowFire(s.x + 14, s.z - 10)
end
local function buildWastes(s, m)
	for i = 1, 6 do voidRift(s.x + rng:NextInteger(-30, 30), s.z + rng:NextInteger(-30, 30), rng:NextInteger(6, 12)) end
	for i = 1, 5 do tendril(s.x + rng:NextInteger(-28, 28), s.z + rng:NextInteger(-28, 28), rng:NextInteger(10, 18)) end
end
local function buildSpires(s, m)
	for i = 0, 6 do
		local a = math.rad(i * 51)
		spire(s.x + math.cos(a) * 26, s.z + math.sin(a) * 26, rng:NextInteger(50, 120), PAL.purple)
	end
	darkCrystal(s.x, s.z, 1.6)
end
local function buildBastion(s, m)
	-- a dark keep: stacked black walls + a gate + crystal beacons
	for _, o in ipairs({ V(-24, 0, -24), V(24, 0, -24), V(-24, 0, 24), V(24, 0, 24) }) do
		part({ Size = V(8, 40, 8), Color = PAL.stone, Material = Enum.Material.Slate, CFrame = CF(s.x + o.X, 20, s.z + o.Z), Parent = m })
	end
	part({ Size = V(56, 26, 4), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x, 13, s.z - 24), Parent = m })
	part({ Size = V(56, 26, 4), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x, 13, s.z + 24), Parent = m })
	part({ Size = V(4, 26, 56), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x - 24, 13, s.z), Parent = m })
	part({ Size = V(4, 26, 20), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x + 24, 13, s.z - 18), Parent = m })
	part({ Size = V(4, 26, 20), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x + 24, 13, s.z + 18), Parent = m })
	darkCrystal(s.x, s.z, 2)
	for _, o in ipairs({ -24, 24 }) do shadowFire(s.x + o, s.z - 24) end
end
local function buildApproach(s, m)
	-- a stepped dark causeway lined with braziers + tendrils
	for i = -3, 3 do
		part({ Size = V(24, 3, 10), Color = PAL.stone, Material = Enum.Material.Slate, CFrame = CF(s.x, 1.5 + math.abs(i) * 0.5, s.z + i * 12), Parent = m })
		if i % 2 == 0 then shadowFire(s.x - 14, s.z + i * 12); shadowFire(s.x + 14, s.z + i * 12) end
	end
	tendril(s.x - 20, s.z, 16); tendril(s.x + 20, s.z, 16)
end
local function buildThrone(s, m)
	deco({ Shape = Enum.PartType.Cylinder, Size = V(3, 150, 150), Color = PAL.groundDk, Material = Enum.Material.Slate, CanCollide = true,
		CFrame = CF(s.x, 0.4, s.z) * ANG(0, 0, math.rad(90)) })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, 140, 140), Color = PAL.purple, Transparency = 0.5, CFrame = CF(s.x, 0.9, s.z) * ANG(0, 0, math.rad(90)) })
	-- throne dais + a great dark throne
	part({ Shape = Enum.PartType.Cylinder, Size = V(4, 44, 44), Color = PAL.stone, Material = Enum.Material.Slate, CFrame = CF(s.x, 2, s.z - 20) * ANG(0, 0, math.rad(90)), Parent = m })
	part({ Size = V(16, 20, 6), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x, 12, s.z - 34), Parent = m })
	part({ Size = V(22, 6, 6), Color = PAL.shadow, Material = Enum.Material.Slate, CFrame = CF(s.x, 22, s.z - 34), Parent = m })
	-- ring of spires + crystals
	for i = 1, 10 do
		local a = math.rad(i * 36)
		spire(s.x + math.cos(a) * 55, s.z + math.sin(a) * 55, rng:NextInteger(40, 90), PAL.purple)
		if i % 2 == 0 then darkCrystal(s.x + math.cos(a) * 38, s.z + math.sin(a) * 38, 1.4) end
	end
	local core = neon({ Shape = Enum.PartType.Ball, Size = V(8, 8, 8), Color = PAL.purple, Transparency = 0.15, CanCollide = false, CFrame = CF(s.x, 20, s.z), Parent = m })
	light(core, PAL.purple, 70, 4)
end

local function buildSector(s, districts)
	local m = Instance.new("Model"); m.Name = (s.name:gsub("[%s']", "")); m.Parent = districts
	m:SetAttribute("District", s.name)
	if s.theme == "gate" then buildGate(s, m)
	elseif s.theme == "wastes" then buildWastes(s, m)
	elseif s.theme == "spires" then buildSpires(s, m)
	elseif s.theme == "bastion" then buildBastion(s, m)
	elseif s.theme == "approach" then buildApproach(s, m)
	elseif s.theme == "boss" then buildThrone(s, m) end
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
	sp.Color = PAL.purple; sp.Material = Enum.Material.Neon; sp.Transparency = 0.3
	sp.TopSurface = Enum.SurfaceType.Smooth; sp.CFrame = CF(pos.X, 2, pos.Z); sp.Parent = parent
	return sp
end
local function buildCampaign(m)
	local camp = Instance.new("Folder"); camp.Name = "Campaign"; camp.Parent = m
	local spawns = Instance.new("Folder"); spawns.Name = "Spawns"; spawns.Parent = camp
	local objectives = Instance.new("Folder"); objectives.Name = "Objectives"; objectives.Parent = camp
	spawnAt(V(SECTORS[1].x, 0, SECTORS[1].z - 24), "CampaignStart", spawns, true)
	for _, s in ipairs(SECTORS) do
		local beacon = part({ Shape = Enum.PartType.Cylinder, Size = V(30, 8, 8), Color = PAL.purple,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true,
			CFrame = CF(s.x, 16, s.z) * ANG(0, 0, math.rad(90)), Parent = objectives })
		beacon.Name = "Stage" .. s.stage .. "_" .. (s.name:gsub("[%s']", ""))
		beacon:SetAttribute("Stage", s.stage); beacon:SetAttribute("District", s.name); beacon:SetAttribute("Objective", s.objective)
		light(beacon, PAL.purple, 26, 2)
		local sp = spawnAt(V(s.x, 0, s.z), "Checkpoint_" .. s.stage, spawns, false); sp.Enabled = false
	end
	return camp
end

function ShadowlandsBuilder.build(parent, opts)
	opts = opts or {}
	parent = parent or workspace
	rng = Random.new(opts.seed or 30003)
	local existing = parent:FindFirstChild("Shadowlands")
	if existing then existing:Destroy() end
	root = Instance.new("Model"); root.Name = "Shadowlands"
	fxParent = Instance.new("Folder"); fxParent.Name = "Decor"; fxParent.Parent = root
	structParent = Instance.new("Folder"); structParent.Name = "Structures"; structParent.Parent = root
	local districts = Instance.new("Folder"); districts.Name = "Districts"; districts.Parent = root
	buildGround()
	scatter()
	for _, s in ipairs(SECTORS) do buildSector(s, districts) end
	if opts.campaign ~= false then buildCampaign(root) end
	root:SetAttribute("Biome", "shadow"); root:SetAttribute("Sectors", #SECTORS)
	root.Parent = parent
	return root
end

return ShadowlandsBuilder
