--[[
	QuantumCityBuilder  (ModuleScript)
	WHERE IT GOES: ServerStorage > QuantumCityBuilder

	Season 10's map: QUANTUM CITY — a digital city floating inside Blue's loops in
	space, built out of parts with no uploaded assets (branding via SurfaceGui
	text). This is the second map on the multi-map framework, and it PULLS ITS
	LOOK from the WorldAtlas "digital" biome palette — the proof that a location's
	biome drives its map.

	A floating archipelago over the void: a central Nexus Core (Blue's loop) with
	radial sector platforms linked by light bridges, ending at the Anonymous's
	Sanctum. Same output shape as MetroCityBuilder, so the shared
	CampaignController + route module run it unchanged:
	    workspace.QuantumCity.Districts / .Campaign(.Spawns/.Objectives)

	Route (Season 10 → The Anonymous):
	  1 Docking Ring · 2 Data Market · 3 The Grid · 4 Server Spire ·
	  5 Firewall Checkpoint · 6 Loop Gardens · 7 The Undernet ·
	  8 Nexus Core · 9 Anonymous Sanctum (boss)

	build(parent, opts) -> Model    (opts.seed number, opts.campaign bool=true)

	Bake once in Studio:  require(game.ServerStorage.QuantumCityBuilder).build(workspace)
	Or set CampaignRegistry.ActiveSeason = 10 and the controller builds it.
]]

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuantumCityBuilder = {}

local c   = Color3.fromRGB
local V   = Vector3.new
local CF  = CFrame.new
local ANG = CFrame.Angles

-------------------------------------------------------------------
-- PALETTE — seeded from the WorldAtlas "digital" biome (falls back if absent)
-------------------------------------------------------------------
local function loadBiome()
	local ok, atlas = pcall(function()
		return require(ReplicatedStorage.Campaign.WorldAtlas)
	end)
	if ok and atlas and atlas.biome then
		local b = atlas.biome("digital")
		if b then return b end
	end
	return { material = "SmoothPlastic", ground = { 18, 24, 30 }, accent = { 60, 220, 200 }, sky = "grid" }
end

local BIOME = loadBiome()
local function rgb(t) return c(t[1], t[2], t[3]) end

local PAL = {
	platform  = rgb(BIOME.ground),
	platformLo = c(10, 14, 20),
	accent    = rgb(BIOME.accent),          -- teal/cyan, from the biome
	neonBlue  = c(60, 150, 255),
	neonTeal  = c(60, 220, 200),
	neonGreen = c(80, 255, 180),
	neonPurp  = c(160, 60, 255),            -- the Anonymous / void zones
	neonPink  = c(230, 70, 220),
	void      = c(6, 8, 14),
	steel     = c(70, 78, 92),
	glass     = c(24, 30, 42),
	white     = c(238, 250, 255),
}

-- layout: floating platforms (X, Z) at ~Y=0, a couple lower
local SECTORS = {
	{ stage = 1, name = "Docking Ring",        x = 0,    z = 430,  y = 0,   r = 70, color = PAL.neonBlue,
	  objective = "Dock and breach Quantum City's outer ring." },
	{ stage = 2, name = "Data Market",         x = -300, z = 240,  y = 0,   r = 66, color = PAL.neonTeal,
	  objective = "Fight through the Data Market's neon stalls." },
	{ stage = 3, name = "The Grid",            x = 300,  z = 240,  y = 0,   r = 66, color = PAL.neonGreen,
	  objective = "Cross the holographic Grid platforms." },
	{ stage = 4, name = "Server Spire",        x = -380, z = -60,  y = 0,   r = 60, color = PAL.neonTeal,
	  objective = "Scale the Server Spire's data towers." },
	{ stage = 5, name = "Firewall Checkpoint",  x = 380, z = -60,  y = 0,   r = 60, color = PAL.neonBlue,
	  objective = "Break the Firewall Checkpoint." },
	{ stage = 6, name = "Loop Gardens",        x = -200, z = -330, y = 0,   r = 62, color = PAL.neonGreen,
	  objective = "Pass Blue's shifting Loop Gardens." },
	{ stage = 7, name = "The Undernet",        x = 200,  z = -330, y = -90, r = 60, color = PAL.neonPurp,
	  objective = "Drop into the glitching Undernet." },
	{ stage = 8, name = "Nexus Core",          x = 0,    z = 0,    y = 0,   r = 96, color = PAL.neonBlue,
	  objective = "Reach the Nexus Core at the city's heart." },
	{ stage = 9, name = "Anonymous Sanctum",    x = 0,   z = -560, y = -30, r = 84, color = PAL.neonPurp,
	  objective = "Enter the Sanctum — defeat the Anonymous.", boss = true },
}

-------------------------------------------------------------------
-- CORE HELPERS
-------------------------------------------------------------------
local rng = Random.new()
local root, fxParent, structParent

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent or structParent
	props.Parent = nil
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function deco(props)
	props.CanCollide = props.CanCollide == true
	props.CanQuery = false
	props.CanTouch = false
	props.Parent = props.Parent or fxParent
	return part(props)
end
local function neon(props)
	props.Material = Enum.Material.Neon
	return deco(props)
end
local function light(parent, color, range, bright)
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range or 18; l.Brightness = bright or 2; l.Parent = parent
	return l
end
local function sign(cframe, size, text, opts)
	opts = opts or {}
	local board = deco({ Size = size, CFrame = cframe, Color = opts.boardColor or PAL.glass,
		Material = Enum.Material.SmoothPlastic, Parent = opts.parent or fxParent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = opts.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = opts.font or Enum.Font.GothamBold
	label.TextColor3 = opts.color or PAL.white
	label.TextScaled = true
	label.Parent = gui
	local strokeCol = opts.color or PAL.accent
	local st = Instance.new("UIStroke")
	st.Color = strokeCol; st.Thickness = 2; st.Transparency = 0.25; st.Parent = label
	return board
end

-------------------------------------------------------------------
-- ENVIRONMENT: the void + starfield below the floating city
-------------------------------------------------------------------
local function buildVoid()
	-- distant dark floor with a faint neon grid (reads as "deep space grid")
	local floorY = -260
	deco({ Size = V(4000, 6, 4000), Color = PAL.void, Material = Enum.Material.SmoothPlastic,
		CanCollide = false, CFrame = CF(0, floorY, 0) })
	for i = -12, 12 do
		neon({ Size = V(2400, 0.4, 1.2), Color = PAL.accent, Transparency = 0.82,
			CFrame = CF(0, floorY + 3.2, i * 100) })
		neon({ Size = V(1.2, 0.4, 2400), Color = PAL.accent, Transparency = 0.82,
			CFrame = CF(i * 100, floorY + 3.2, 0) })
	end
	-- starfield motes floating around the city
	for _ = 1, 130 do
		local col = (rng:NextNumber() < 0.5) and PAL.neonTeal or PAL.neonBlue
		neon({ Shape = Enum.PartType.Ball, Size = V(1, 1, 1) * rng:NextNumber(1, 2.6),
			Color = col, Transparency = 0.25, CanCollide = false,
			CFrame = CF(rng:NextNumber(-900, 900), rng:NextNumber(-200, 160), rng:NextNumber(-900, 900)) })
	end
end

-- a floating island platform: disc top + tapered underside + glowing rim
local function platform(x, z, y, r, color, m)
	part({ Shape = Enum.PartType.Cylinder, Size = V(6, r * 2, r * 2), Color = PAL.platform,
		Material = Enum.Material.SmoothPlastic, CFrame = CF(x, y - 3, z) * ANG(0, 0, math.rad(90)), Parent = m })
	-- tapered underside
	part({ Shape = Enum.PartType.Ball, Size = V(r * 1.7, r * 1.1, r * 1.7), Color = PAL.platformLo,
		CanCollide = false, CFrame = CF(x, y - r * 0.5, z), Parent = m })
	-- glowing rim + surface grid
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.6, r * 2 + 2, r * 2 + 2), Color = color,
		Transparency = 0.1, CFrame = CF(x, y + 0.2, z) * ANG(0, 0, math.rad(90)) })
	for i = -3, 3 do
		local w = math.sqrt(math.max(r * r - (i * r / 4) ^ 2, 0)) * 2
		if w > 4 then
			neon({ Size = V(w, 0.3, 0.5), Color = color, Transparency = 0.72, CFrame = CF(x, y + 0.35, z + i * r / 4) })
			neon({ Size = V(0.5, 0.3, w), Color = color, Transparency = 0.72, CFrame = CF(x + i * r / 4, y + 0.35, z) })
		end
	end
end

-- holographic data tower (thin, glowing edges, floating cube segments)
local function dataTower(x, z, y, h, color, m)
	local w = 6 + rng:NextInteger(0, 4)
	part({ Size = V(w, h, w), Color = PAL.glass, Material = Enum.Material.Glass, Reflectance = 0.2,
		Transparency = 0.35, CFrame = CF(x, y + h / 2, z), Parent = m })
	for _, e in ipairs({ V(w / 2, 0, w / 2), V(-w / 2, 0, w / 2), V(w / 2, 0, -w / 2), V(-w / 2, 0, -w / 2) }) do
		neon({ Size = V(0.4, h, 0.4), Color = color, Transparency = 0.1, CFrame = CF(x + e.X, y + h / 2, z + e.Z) })
	end
	neon({ Size = V(w + 0.6, 0.5, w + 0.6), Color = color, Transparency = 0.15, CFrame = CF(x, y + h, z) })
	light(part({ Size = V(1, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.2,
		CanCollide = false, CFrame = CF(x, y + h + 1, z), Parent = m }), color, 18, 2)
end

local function lamp(x, z, y, color)
	deco({ Size = V(0.4, 8, 0.4), Color = PAL.steel, Material = Enum.Material.Metal, CFrame = CF(x, y + 4, z) })
	local head = neon({ Size = V(1.2, 1.2, 1.2), Color = color, Transparency = 0.05, CFrame = CF(x, y + 8, z) })
	light(head, color, 16, 2)
end

-- a light bridge linking two platforms (walkable deck + neon rails)
local function bridge(a, b, m)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	if len < 1 then return end
	local look = CFrame.lookAt(mid, b)
	part({ Size = V(10, 1, len), Color = PAL.glass, Material = Enum.Material.Glass, Transparency = 0.25,
		Reflectance = 0.15, CFrame = look, Parent = m })
	neon({ Size = V(0.5, 0.5, len), Color = PAL.accent, Transparency = 0.15, CFrame = look * CF(4.8, 0.6, 0) })
	neon({ Size = V(0.5, 0.5, len), Color = PAL.accent, Transparency = 0.15, CFrame = look * CF(-4.8, 0.6, 0) })
	neon({ Size = V(8, 0.2, len), Color = PAL.accent, Transparency = 0.75, CFrame = look * CF(0, 0.55, 0) })
end

-------------------------------------------------------------------
-- SECTORS (districts) + special builds
-------------------------------------------------------------------
local function buildNexusCore(s, m)
	-- Blue's loop: a big glowing vertical ring + a core orb, slowly implied motion
	local x, z, y = s.x, s.z, s.y
	for i = 1, 28 do
		local a = (i / 28) * math.pi * 2
		local rr = 46
		neon({ Size = V(4, 4, 2.4), Shape = Enum.PartType.Ball, Color = PAL.neonBlue, Transparency = 0.1,
			CFrame = CF(x + math.cos(a) * rr, y + 34 + math.sin(a) * rr, z) })
	end
	local coreP = neon({ Shape = Enum.PartType.Ball, Size = V(20, 20, 20), Color = PAL.neonTeal,
		Transparency = 0.1, CanCollide = false, CFrame = CF(x, y + 34, z), Parent = m })
	light(coreP, PAL.neonTeal, 90, 5)
	sign(CF(x, y + 70, z), V(0.1, 0.1, 0.1), "BLUE", { color = PAL.neonBlue, parent = m })
	for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		sign(CF(x, y + 12, z + 22), V(16, 8, 0.4), "QUANTUM CITY", { color = PAL.neonTeal, face = f, parent = m })
	end
end

local function buildSanctum(s, m)
	-- the Anonymous: a dark void platform, purple grid, a raised dais + glyph
	local x, z, y = s.x, s.z, s.y
	part({ Shape = Enum.PartType.Cylinder, Size = V(2, 40, 40), Color = c(14, 8, 22),
		Material = Enum.Material.SmoothPlastic, CFrame = CF(x, y + 2, z) * ANG(0, 0, math.rad(90)), Parent = m })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, 44, 44), Color = PAL.neonPurp, Transparency = 0.1,
		CFrame = CF(x, y + 2.6, z) * ANG(0, 0, math.rad(90)) })
	-- shadow spires ringing the dais
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		part({ Size = V(3, 30 + rng:NextInteger(0, 14), 3), Color = c(20, 12, 30),
			CFrame = CF(x + math.cos(a) * 34, y + 16, z + math.sin(a) * 34), Parent = m })
		neon({ Size = V(0.5, 24, 0.5), Color = PAL.neonPurp, Transparency = 0.2,
			CFrame = CF(x + math.cos(a) * 34, y + 16, z + math.sin(a) * 34 - 1.8) })
	end
	local orb = neon({ Shape = Enum.PartType.Ball, Size = V(10, 10, 10), Color = PAL.neonPurp,
		Transparency = 0.1, CanCollide = false, CFrame = CF(x, y + 20, z), Parent = m })
	light(orb, PAL.neonPurp, 70, 4)
	for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		sign(CF(x, y + 20, z), V(0.1, 0.1, 0.1), "A", { color = PAL.neonPink, face = f, parent = m })
	end
end

local function buildSector(s, districts)
	local m = Instance.new("Model")
	m.Name = (s.name:gsub("%s", ""))
	m.Parent = districts
	m:SetAttribute("District", s.name)
	platform(s.x, s.z, s.y, s.r, s.color, m)

	if s.boss then
		buildSanctum(s, m)
	elseif s.stage == 8 then
		buildNexusCore(s, m)
		-- ring of data towers around the core
		for i = 0, 7 do
			local a = math.rad(i * 45)
			dataTower(s.x + math.cos(a) * (s.r - 18), s.z + math.sin(a) * (s.r - 18), s.y, 40 + rng:NextInteger(0, 40), s.color, m)
		end
	else
		-- generic sector: a few data towers, lamps, and a name sign
		local towers = 3 + rng:NextInteger(0, 2)
		for i = 1, towers do
			local a = math.rad(rng:NextInteger(0, 360))
			local rr = rng:NextNumber(s.r * 0.25, s.r * 0.7)
			dataTower(s.x + math.cos(a) * rr, s.z + math.sin(a) * rr, s.y, 26 + rng:NextInteger(0, 40), s.color, m)
		end
		for i = 0, 5 do
			local a = math.rad(i * 60)
			lamp(s.x + math.cos(a) * (s.r - 8), s.z + math.sin(a) * (s.r - 8), s.y, s.color)
		end
		sign(CF(s.x, s.y + 14, s.z + s.r - 6), V(22, 7, 0.4), string.upper(s.name),
			{ color = s.color, parent = m })
	end
	return m
end

-------------------------------------------------------------------
-- CAMPAIGN SCAFFOLDING (same shape MetroCityBuilder produces)
-------------------------------------------------------------------
local function spawnAt(pos, name, parent, enabled)
	local sp = Instance.new("SpawnLocation")
	sp.Name = name
	sp.Size = V(12, 1, 12)
	sp.Anchored = true
	sp.CanCollide = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Enabled = enabled ~= false
	sp.Color = PAL.neonTeal
	sp.Material = Enum.Material.Neon
	sp.Transparency = 0.3
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.CFrame = CF(pos.X, pos.Y + 1, pos.Z)
	sp.Parent = parent
	return sp
end

local function buildCampaign(m)
	local camp = Instance.new("Folder"); camp.Name = "Campaign"; camp.Parent = m
	local spawns = Instance.new("Folder"); spawns.Name = "Spawns"; spawns.Parent = camp
	local objectives = Instance.new("Folder"); objectives.Name = "Objectives"; objectives.Parent = camp

	spawnAt(V(SECTORS[1].x, SECTORS[1].y, SECTORS[1].z - 20), "CampaignStart", spawns, true)

	for _, s in ipairs(SECTORS) do
		local beacon = part({
			Shape = Enum.PartType.Cylinder, Size = V(30, 8, 8), Color = PAL.neonTeal,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true,
			CFrame = CF(s.x, s.y + 16, s.z) * ANG(0, 0, math.rad(90)), Parent = objectives,
		})
		beacon.Name = "Stage" .. s.stage .. "_" .. (s.name:gsub("%s", ""))
		beacon:SetAttribute("Stage", s.stage)
		beacon:SetAttribute("District", s.name)
		beacon:SetAttribute("Objective", s.objective)
		light(beacon, PAL.neonTeal, 26, 2)

		local sp = spawnAt(V(s.x, s.y, s.z), "Checkpoint_" .. s.stage, spawns, false)
		sp.Enabled = false
	end
	return camp
end

-------------------------------------------------------------------
-- PUBLIC
-------------------------------------------------------------------
function QuantumCityBuilder.build(parent, opts)
	opts = opts or {}
	parent = parent or workspace
	rng = Random.new(opts.seed or 100010)

	local existing = parent:FindFirstChild("QuantumCity")
	if existing then existing:Destroy() end

	root = Instance.new("Model"); root.Name = "QuantumCity"
	fxParent = Instance.new("Folder"); fxParent.Name = "Decor"; fxParent.Parent = root
	structParent = Instance.new("Folder"); structParent.Name = "Structures"; structParent.Parent = root
	local districts = Instance.new("Folder"); districts.Name = "Districts"; districts.Parent = root

	buildVoid()
	for _, s in ipairs(SECTORS) do buildSector(s, districts) end

	-- light bridges: hub spokes + route links
	local bridgeFolder = Instance.new("Folder"); bridgeFolder.Name = "SkyBridges"; bridgeFolder.Parent = districts
	local hub = SECTORS[8]
	for _, s in ipairs(SECTORS) do
		if s.stage ~= 8 then
			bridge(V(hub.x, hub.y, hub.z), V(s.x, s.y, s.z), bridgeFolder)
		end
	end
	-- consecutive route links for a walkable path
	for i = 1, #SECTORS - 1 do
		local a, b = SECTORS[i], SECTORS[i + 1]
		bridge(V(a.x, a.y, a.z), V(b.x, b.y, b.z), bridgeFolder)
	end

	if opts.campaign ~= false then buildCampaign(root) end

	root:SetAttribute("Biome", "digital")
	root:SetAttribute("Sectors", #SECTORS)
	root.Parent = parent
	return root
end

return QuantumCityBuilder
