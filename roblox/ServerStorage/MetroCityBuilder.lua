--[[
	MetroCityBuilder  (ModuleScript)
	WHERE IT GOES: ServerStorage > MetroCityBuilder

	Procedurally builds "Metro City" — Manderin's futuristic capital from the
	concept art — entirely out of parts, no uploaded models or textures needed.
	Branding uses SurfaceGui text ("M", "MANDERIN"), so nothing to import.

	ALL 11 districts from the concept sheet:
	  1  Central Plaza      - open plaza + Manderin monument (statue/orb)
	  2  Manderin Tower     - the tallest tower, HQ (campaign boss site)
	  3  Tech District      - purple/cyan neon labs & "MANDERIN TECH" towers
	  4  Industrial District- factories, tanks, smokestacks, pipes
	  5  Residential Area   - clean mid-rise blocks, trees, lamps
	  6  Docks              - water, pier, cranes, ship, containers
	  7  Security Checkpoints- scanner gates at each wall entrance
	  8  Sky Bridges        - elevated bridges linking the tall towers
	  9  Undercity          - hidden purple underground under the plaza
	  10 Manderin Arena     - domed high-tech fighting arena
	  11 City Walls         - massive perimeter walls, corner towers, main gate

	HOW TO USE (two options):
	  A) BAKE ONCE (recommended). In Studio, open the Command Bar and run:
	         require(game.ServerStorage.MetroCityBuilder).build(workspace)
	     The city appears under workspace.MetroCity. Save the place — it's now
	     permanent, editable geometry and never rebuilds at runtime.
	  B) RUNTIME. Keep the BuildMetroCity Script (ServerScriptService); it builds
	     the city on server start if workspace.MetroCity doesn't already exist.

	Everything is Anchored. Decorative parts are CanQuery=false so they never
	interfere with ability hitboxes/raycasts. Turn on StreamingEnabled
	(Workspace) for best performance with a map this size.

	build(parent, opts) -> Model   (opts.seed number, opts.campaign bool=true)
]]

local MetroCityBuilder = {}

local c   = Color3.fromRGB
local V   = Vector3.new
local CF  = CFrame.new
local ANG = CFrame.Angles

-------------------------------------------------------------------
-- PALETTE + LAYOUT CONSTANTS
-------------------------------------------------------------------
local PAL = {
	road      = c(38, 40, 46),
	roadLine  = c(230, 200, 90),
	sidewalk  = c(120, 122, 130),
	plaza     = c(150, 152, 160),
	plazaDark = c(70, 72, 80),
	glassDark = c(28, 32, 42),
	glassMid  = c(52, 58, 72),
	glassLite = c(90, 100, 120),
	manderin  = c(18, 20, 26),
	neonBlue  = c(60, 150, 255),
	neonCyan  = c(130, 220, 255),
	neonPurp  = c(160, 60, 255),
	neonPink  = c(230, 70, 220),
	warm      = c(255, 210, 130),
	wall      = c(46, 50, 60),
	wallTrim  = c(230, 200, 120),
	steel     = c(70, 74, 84),
	steelDark = c(48, 50, 58),
	tree      = c(74, 160, 84),
	treeDark  = c(56, 120, 66),
	trunk     = c(92, 70, 52),
	water     = c(30, 92, 150),
	white     = c(245, 248, 255),
	container = { c(200, 70, 60), c(60, 130, 200), c(210, 170, 60), c(80, 170, 90), c(150, 90, 190) },
}

local WALL   = 540      -- half-extent of the city inside the walls
local GROUND = 1300     -- ground plane size
local PLAZA_R = 110     -- plaza clear radius
local AVENUE = 44       -- main avenue width
local RING   = 340      -- ring-road distance from center

-- district center points (top-down X,Z)
local LOC = {
	plaza     = V(0, 0, 0),
	tower     = V(0, 0, -215),
	tech      = V(-300, 0, -250),
	industrial= V(320, 0, 70),
	residential= V(-40, 0, 300),
	docks     = V(-380, 0, 40),
	arena     = V(300, 0, -260),
	underAccess = V(70, 0, 70),
}

-------------------------------------------------------------------
-- CORE HELPERS
-------------------------------------------------------------------
local rng = Random.new()
local root            -- the MetroCity model (set in build)
local fxParent        -- decorative folder
local structParent    -- collidable structures folder

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

-- decorative part: no collision, no raycast interference
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

local function pointLight(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 18
	l.Brightness = brightness or 2
	l.Parent = parent
	return l
end

-- a flat sign board with crisp SurfaceGui text (the Manderin branding)
local function sign(cframe, size, text, opts)
	opts = opts or {}
	local board = deco({
		Size = size, CFrame = cframe, Color = opts.boardColor or PAL.manderin,
		Material = opts.boardMaterial or Enum.Material.SmoothPlastic,
		Parent = opts.parent or fxParent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = opts.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.86)
	label.Position = UDim2.fromScale(0.04, 0.07)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = opts.font or Enum.Font.GothamBold
	label.TextColor3 = opts.color or PAL.white
	label.TextScaled = true
	label.Parent = gui
	if opts.glow then
		local stroke = Instance.new("UIStroke")
		stroke.Color = opts.color or PAL.neonBlue
		stroke.Thickness = 2
		stroke.Transparency = 0.2
		stroke.Parent = label
	end
	return board
end

-- vertical neon pinstripes + a top band: the "lit skyscraper" look, cheaply
local function windowGlow(cframe, w, d, h, color)
	local stripes = math.clamp(math.floor(w / 7), 2, 4)
	for _, face in ipairs({ 1, -1 }) do
		for i = 1, stripes do
			local x = (-w / 2) + (i / (stripes + 1)) * w
			neon({
				Size = V(0.6, h * 0.82, 0.4), Color = color, Transparency = 0.15,
				CFrame = cframe * CF(x, -h * 0.06, face * (d / 2 + 0.05)),
			})
		end
	end
	-- crown band
	neon({ Size = V(w + 0.4, 0.8, d + 0.4), Color = color, Transparency = 0.1,
		CFrame = cframe * CF(0, h / 2 - 2.5, 0) })
end

-- a futuristic tower. opts: neon color, sign ("M"/"MANDERIN TECH"/...), taper
local function tower(x, z, w, d, h, opts)
	opts = opts or {}
	local baseY = h / 2
	local body = part({
		Size = V(w, h, d), Color = opts.color or PAL.glassDark,
		Material = opts.material or Enum.Material.Glass, Reflectance = opts.reflect or 0.15,
		CFrame = CF(x, baseY, z) * ANG(0, opts.rot or 0, 0),
		Parent = structParent,
	})
	windowGlow(body.CFrame, w, d, h, opts.neon or PAL.neonBlue)
	-- optional tapered upper section
	if opts.taper then
		local w2, d2, h2 = w * 0.7, d * 0.7, h * 0.35
		part({
			Size = V(w2, h2, d2), Color = opts.color or PAL.glassDark,
			Material = opts.material or Enum.Material.Glass, Reflectance = opts.reflect or 0.15,
			CFrame = CF(x, h + h2 / 2, z) * ANG(0, opts.rot or 0, 0),
			Parent = structParent,
		})
		windowGlow(CF(x, h + h2 / 2, z) * ANG(0, opts.rot or 0, 0), w2, d2, h2, opts.neon or PAL.neonBlue)
	end
	-- rooftop sign
	if opts.sign then
		local topY = opts.taper and (h + h * 0.35) or h
		local sw = math.min(w * 0.8, #opts.sign > 2 and w * 0.9 or 10)
		sign(CF(x, topY + 6, z + d / 2 + 0.3) * ANG(0, opts.rot or 0, 0), V(sw, 8, 0.4), opts.sign,
			{ color = opts.neon or PAL.neonCyan, glow = true })
	end
	return body
end

local function streetLamp(x, z)
	local pole = deco({ Size = V(0.5, 11, 0.5), Color = PAL.steelDark, Material = Enum.Material.Metal,
		CFrame = CF(x, 5.5, z) })
	local head = neon({ Size = V(1.6, 0.8, 1.6), Color = PAL.warm, Transparency = 0.05,
		CFrame = CF(x, 11.2, z) })
	pointLight(head, PAL.warm, 20, 2.2)
	return pole
end

-- blocky low-poly tree matching the concept's voxel foliage
local function tree(x, z, scale)
	scale = scale or 1
	deco({ Size = V(1.2, 4 * scale, 1.2) * scale, Color = PAL.trunk, Material = Enum.Material.Wood,
		CFrame = CF(x, 2 * scale, z) })
	deco({ Size = V(6, 5, 6) * scale, Color = PAL.tree, Material = Enum.Material.Grass,
		CFrame = CF(x, (4 + 2.5) * scale, z) })
	deco({ Size = V(4.4, 3.6, 4.4) * scale, Color = PAL.treeDark, Material = Enum.Material.Grass,
		CFrame = CF(x, (4 + 5.6) * scale, z) })
end

local function planter(x, z)
	deco({ Size = V(7, 1.4, 7), Color = PAL.plazaDark, CFrame = CF(x, 0.7, z) })
	tree(x, z, 1)
end

-------------------------------------------------------------------
-- GROUND + ROADS
-------------------------------------------------------------------
local function buildGround()
	part({ Size = V(GROUND, 4, GROUND), Color = c(24, 26, 32), Material = Enum.Material.Slate,
		CFrame = CF(0, -2, 0), Parent = structParent })
	-- grass apron outside the walls
	deco({ Size = V(GROUND, 0.2, GROUND), Color = c(46, 96, 56), Material = Enum.Material.Grass,
		CanCollide = false, CFrame = CF(0, 0.1, 0) })
end

local function roadStrip(cframe, length, width)
	deco({ Size = V(width, 0.3, length), Color = PAL.road, Material = Enum.Material.Asphalt,
		CFrame = cframe })
	-- dashed center line
	local dashes = math.floor(length / 16)
	for i = 0, dashes do
		local o = -length / 2 + 8 + i * 16
		neon({ Size = V(1, 0.35, 5), Color = PAL.roadLine, Transparency = 0.2,
			CFrame = cframe * CF(0, 0.05, o) })
	end
end

local function buildRoads()
	-- main cross avenues through the plaza
	roadStrip(CF(0, 0.25, 0), WALL * 2, AVENUE)                       -- N-S
	roadStrip(CF(0, 0.25, 0) * ANG(0, math.rad(90), 0), WALL * 2, AVENUE) -- E-W
	-- ring road (4 straight segments)
	roadStrip(CF(0, 0.24, -RING), RING * 2, 30)
	roadStrip(CF(0, 0.24, RING), RING * 2, 30)
	roadStrip(CF(-RING, 0.24, 0) * ANG(0, math.rad(90), 0), RING * 2, 30)
	roadStrip(CF(RING, 0.24, 0) * ANG(0, math.rad(90), 0), RING * 2, 30)
	-- sidewalks flanking the avenues
	for _, s in ipairs({ -1, 1 }) do
		deco({ Size = V(6, 0.5, WALL * 2), Color = PAL.sidewalk, Material = Enum.Material.Concrete,
			CFrame = CF(s * (AVENUE / 2 + 3), 0.3, 0) })
		deco({ Size = V(WALL * 2, 0.5, 6), Color = PAL.sidewalk, Material = Enum.Material.Concrete,
			CFrame = CF(0, 0.3, s * (AVENUE / 2 + 3)) })
	end
end

-------------------------------------------------------------------
-- 1. CENTRAL PLAZA + MONUMENT
-------------------------------------------------------------------
local function buildMonument(m)
	local x, z = LOC.plaza.X, LOC.plaza.Z
	-- stepped circular base
	for i = 0, 3 do
		local r = 26 - i * 5
		part({ Shape = Enum.PartType.Cylinder, Size = V(2, r * 2, r * 2), Color = PAL.plazaDark,
			Material = Enum.Material.Concrete, CFrame = CF(x, 1 + i * 2, z) * ANG(0, 0, math.rad(90)),
			Parent = m })
	end
	-- horned orb (the concept's dark sphere with an M and horns)
	local orb = part({ Shape = Enum.PartType.Ball, Size = V(16, 16, 16), Color = PAL.manderin,
		Material = Enum.Material.SmoothPlastic, CFrame = CF(x, 18, z), Parent = m })
	for _, a in ipairs({ -35, 35 }) do
		deco({ Size = V(2, 6, 2), Color = PAL.manderin, CanCollide = false,
			CFrame = CF(x, 25, z) * ANG(0, 0, math.rad(a)) * CF(0, 4, 0), Parent = m })
	end
	sign(CF(x, 18, z + 8.1), V(10, 10, 0.4), "M", { color = PAL.white, glow = true, parent = m })
	-- tall pillar with vertical neon + MANDERIN plate
	local pillarH = 150
	part({ Size = V(10, pillarH, 10), Color = PAL.glassDark, Material = Enum.Material.Glass,
		Reflectance = 0.2, CFrame = CF(x, 26 + pillarH / 2, z), Parent = m })
	neon({ Size = V(1.2, pillarH * 0.9, 0.5), Color = PAL.neonBlue, Transparency = 0.1,
		CFrame = CF(x, 26 + pillarH / 2, z + 5.1), Parent = m })
	neon({ Size = V(1.2, pillarH * 0.9, 0.5), Color = PAL.neonBlue, Transparency = 0.1,
		CFrame = CF(x, 26 + pillarH / 2, z - 5.1), Parent = m })
	sign(CF(x, 26 + pillarH - 14, z + 5.2), V(8, 12, 0.4), "MANDERIN",
		{ color = PAL.white, font = Enum.Font.GothamBlack, parent = m })
	-- crowning M cube
	local cap = part({ Size = V(18, 18, 18), Color = PAL.manderin, Material = Enum.Material.SmoothPlastic,
		CFrame = CF(x, 26 + pillarH + 9, z), Parent = m })
	pointLight(cap, PAL.neonBlue, 40, 3)
	for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		sign(cap.CFrame, V(0.1, 0.1, 0.1), "M", { color = PAL.white, glow = true, face = f, parent = m })
	end
end

local function buildPlaza(districts)
	local m = Instance.new("Model")
	m.Name = "CentralPlaza"
	m.Parent = districts
	-- plaza floor tiles
	deco({ Shape = Enum.PartType.Cylinder, Size = V(1, PLAZA_R * 2, PLAZA_R * 2), Color = PAL.plaza,
		Material = Enum.Material.Marble, CanCollide = true, CFrame = CF(0, 0.5, 0) * ANG(0, 0, math.rad(90)),
		Parent = m })
	for i = 1, 3 do
		deco({ Shape = Enum.PartType.Cylinder, Size = V(1.05, (PLAZA_R - i * 26) * 2, (PLAZA_R - i * 26) * 2),
			Color = PAL.plazaDark, CanCollide = false, CFrame = CF(0, 0.55, 0) * ANG(0, 0, math.rad(90)),
			Parent = m })
	end
	buildMonument(m)
	-- ring of lamps + planters around the plaza
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local px, pz = math.cos(a) * (PLAZA_R - 12), math.sin(a) * (PLAZA_R - 12)
		streetLamp(px, pz)
		if i % 2 == 0 then planter(math.cos(a) * (PLAZA_R - 30), math.sin(a) * (PLAZA_R - 30)) end
	end
	m:SetAttribute("District", "Central Plaza")
	return m
end

-------------------------------------------------------------------
-- 2. MANDERIN TOWER (tallest — HQ / boss site)
-------------------------------------------------------------------
local function buildManderinTower(districts)
	local m = Instance.new("Model")
	m.Name = "ManderinTower"
	m.Parent = districts
	local x, z = LOC.tower.X, LOC.tower.Z
	-- wide podium
	part({ Size = V(90, 16, 90), Color = PAL.glassMid, Material = Enum.Material.SmoothPlastic,
		CFrame = CF(x, 8, z), Parent = m })
	-- stacked, tapering tower
	local levels = { { 56, 200 }, { 44, 140 }, { 30, 90 } }
	local y = 16
	for _, lv in ipairs(levels) do
		local size, hh = lv[1], lv[2]
		part({ Size = V(size, hh, size), Color = PAL.glassDark, Material = Enum.Material.Glass,
			Reflectance = 0.18, CFrame = CF(x, y + hh / 2, z), Parent = m })
		windowGlow(CF(x, y + hh / 2, z), size, size, hh, PAL.neonBlue)
		y = y + hh
	end
	-- MANDERIN nameplate near the top and an M crown
	sign(CF(x, 16 + 200 - 30, z + 28.2), V(40, 16, 0.5), "MANDERIN",
		{ color = PAL.white, font = Enum.Font.GothamBlack, glow = true, parent = m })
	local crown = part({ Size = V(34, 34, 34), Color = PAL.manderin, CFrame = CF(x, y + 17, z), Parent = m })
	pointLight(crown, PAL.neonCyan, 80, 4)
	for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		sign(crown.CFrame, V(0.1, 0.1, 0.1), "M", { color = PAL.white, glow = true, face = f, parent = m })
	end
	-- antenna
	deco({ Size = V(1.5, 60, 1.5), Color = PAL.steel, Material = Enum.Material.Metal,
		CFrame = CF(x, y + 34 + 30, z), Parent = m })
	neon({ Size = V(2, 2, 2), Shape = Enum.PartType.Ball, Color = PAL.neonPink,
		CFrame = CF(x, y + 34 + 61, z), Parent = m })
	m:SetAttribute("District", "Manderin Tower")
	m:SetAttribute("TopY", y + 34)
	return m
end

-------------------------------------------------------------------
-- DOWNTOWN SKYLINE (general dark-glass towers ringing the plaza)
-------------------------------------------------------------------
local function buildDowntown(districts)
	local m = Instance.new("Model")
	m.Name = "Downtown"
	m.Parent = districts
	local spots = {
		{ -150, -90, 46 }, { 150, -90, 42 }, { -170, 90, 40 }, { 170, 80, 44 },
		{ -90, 170, 38 }, { 110, 170, 42 }, { -230, -30, 40 }, { 220, -30, 46 },
		{ -60, -150, 36 }, { 70, -150, 40 },
	}
	for _, s in ipairs(spots) do
		local h = 120 + rng:NextInteger(0, 140)
		tower(s[1], s[2], s[3], s[3], h, {
			neon = (rng:NextNumber() < 0.5) and PAL.neonBlue or PAL.neonCyan,
			taper = rng:NextNumber() < 0.5, sign = (rng:NextNumber() < 0.4) and "M" or nil,
			rot = math.rad(rng:NextInteger(-12, 12)),
		})
	end
	m:SetAttribute("District", "Downtown")
	return m
end

-------------------------------------------------------------------
-- 3. TECH DISTRICT
-------------------------------------------------------------------
local function buildTech(districts)
	local m = Instance.new("Model")
	m.Name = "TechDistrict"
	m.Parent = districts
	local cx, cz = LOC.tech.X, LOC.tech.Z
	local signs = { "MANDERIN TECH", "M TECH", "TECH", "MANDERIN TECH" }
	local layout = { { -50, -40 }, { 55, -55 }, { -60, 55 }, { 50, 60 }, { 0, 0 } }
	for i, off in ipairs(layout) do
		local col = (i % 2 == 0) and PAL.neonPurp or PAL.neonCyan
		tower(cx + off[1], cz + off[2], 40, 40, 130 + rng:NextInteger(0, 90), {
			color = c(26, 26, 40), neon = col, taper = true,
			sign = signs[((i - 1) % #signs) + 1],
		})
	end
	-- neon store fronts + purple street glow along the block edge
	for i = -3, 3 do
		neon({ Size = V(18, 0.4, 3), Color = (i % 2 == 0) and PAL.neonPurp or PAL.neonPink,
			Transparency = 0.25, CFrame = CF(cx + i * 22, 0.3, cz + 90) })
	end
	for i = 0, 6 do
		streetLamp(cx - 66 + i * 22, cz + 80)
	end
	m:SetAttribute("District", "Tech District")
	return m
end

-------------------------------------------------------------------
-- 4. INDUSTRIAL DISTRICT
-------------------------------------------------------------------
local function buildIndustrial(districts)
	local m = Instance.new("Model")
	m.Name = "IndustrialDistrict"
	m.Parent = districts
	local cx, cz = LOC.industrial.X, LOC.industrial.Z
	-- factory sheds
	for i = -1, 1 do
		part({ Size = V(70, 40, 46), Color = PAL.steelDark, Material = Enum.Material.CorrodedMetal,
			CFrame = CF(cx + i * 80, 20, cz - 40), Parent = m })
		neon({ Size = V(70, 1, 0.5), Color = PAL.warm, Transparency = 0.2,
			CFrame = CF(cx + i * 80, 34, cz - 40 + 23.2) })
	end
	-- storage tanks
	for i = -1, 1 do
		part({ Shape = Enum.PartType.Cylinder, Size = V(34, 26, 26), Color = PAL.steel,
			Material = Enum.Material.Metal, CFrame = CF(cx + i * 40 - 10, 17, cz + 40) * ANG(0, 0, math.rad(90)),
			Parent = m })
	end
	-- smokestacks with smoke
	for i = 0, 3 do
		local sx, sz = cx - 90 + i * 24, cz + 6
		local stack = part({ Shape = Enum.PartType.Cylinder, Size = V(70, 8, 8), Color = c(60, 55, 52),
			Material = Enum.Material.Concrete, CFrame = CF(sx, 35, sz) * ANG(0, 0, math.rad(90)), Parent = m })
		neon({ Size = V(1, 8.2, 8.2), Shape = Enum.PartType.Cylinder, Color = PAL.warm, Transparency = 0.3,
			CFrame = CF(sx, 69.5, sz) * ANG(0, 0, math.rad(90)) })
		local att = Instance.new("Attachment"); att.Position = V(0, 35, 0); att.Parent = stack
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(c(90, 88, 84))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(2, 3)
		smoke.Rate = 6
		smoke.Speed = NumberRange.new(6, 10)
		smoke.VelocityInheritance = 0
		smoke.Parent = att
	end
	-- pipes
	for i = -2, 2 do
		deco({ Shape = Enum.PartType.Cylinder, Size = V(120, 2, 2), Color = PAL.steel,
			Material = Enum.Material.Metal, CFrame = CF(cx, 6 + (i + 2) * 2, cz + 70) * ANG(0, math.rad(90), math.rad(90)) })
	end
	sign(CF(cx, 44, cz - 40 - 23.4) * ANG(0, math.rad(180), 0), V(30, 8, 0.5), "M",
		{ color = PAL.neonBlue, glow = true, parent = m })
	m:SetAttribute("District", "Industrial District")
	return m
end

-------------------------------------------------------------------
-- 5. RESIDENTIAL AREA
-------------------------------------------------------------------
local function buildResidential(districts)
	local m = Instance.new("Model")
	m.Name = "ResidentialArea"
	m.Parent = districts
	local cx, cz = LOC.residential.X, LOC.residential.Z
	for gx = -2, 2 do
		for gz = 0, 2 do
			if not (gx == 0) then   -- leave the central avenue clear
				local bx, bz = cx + gx * 60, cz + gz * 60
				local h = 44 + rng:NextInteger(0, 40)
				part({ Size = V(34, h, 34), Color = PAL.glassMid, Material = Enum.Material.SmoothPlastic,
					CFrame = CF(bx, h / 2, bz), Parent = m })
				windowGlow(CF(bx, h / 2, bz), 34, 34, h, PAL.warm)
				tree(bx + 22, bz - 18, 0.8)
				if gz == 0 then streetLamp(bx + 22, bz + 20) end
			end
		end
	end
	m:SetAttribute("District", "Residential Area")
	return m
end

-------------------------------------------------------------------
-- 6. DOCKS
-------------------------------------------------------------------
local function buildDocks(districts)
	local m = Instance.new("Model")
	m.Name = "Docks"
	m.Parent = districts
	local cx, cz = LOC.docks.X, LOC.docks.Z
	-- water beyond the western wall
	deco({ Size = V(260, 8, 520), Color = PAL.water, Material = Enum.Material.Glass, Transparency = 0.35,
		Reflectance = 0.25, CanCollide = true, CFrame = CF(cx - 150, -1, cz), Parent = m })
	-- concrete pier
	part({ Size = V(120, 6, 260), Color = PAL.sidewalk, Material = Enum.Material.Concrete,
		CFrame = CF(cx, 1, cz), Parent = m })
	-- stacked shipping containers
	for i = 0, 5 do
		for j = 0, 2 do
			local col = PAL.container[rng:NextInteger(1, #PAL.container)]
			part({ Size = V(16, 8, 8), Color = col, Material = Enum.Material.Metal,
				CFrame = CF(cx + 30 + (i % 3) * 18, 4 + math.floor(i / 3) * 8 + j * 8, cz - 90 + j * 10),
				Parent = m })
		end
	end
	-- gantry cranes
	for _, oz in ipairs({ -40, 60 }) do
		local lx = cx - 30
		for _, ox in ipairs({ -18, 18 }) do
			deco({ Size = V(3, 60, 3), Color = PAL.wallTrim, Material = Enum.Material.Metal,
				CFrame = CF(lx + ox, 30, cz + oz), Parent = m })
		end
		part({ Size = V(44, 4, 4), Color = PAL.wallTrim, Material = Enum.Material.Metal,
			CFrame = CF(lx, 60, cz + oz), Parent = m })
		part({ Size = V(4, 4, 40), Color = PAL.wallTrim, Material = Enum.Material.Metal,
			CFrame = CF(lx - 22, 56, cz + oz), Parent = m })
	end
	-- a docked ship
	part({ Size = V(40, 16, 90), Color = c(60, 66, 78), Material = Enum.Material.Metal,
		CFrame = CF(cx - 90, 4, cz + 20), Parent = m })
	part({ Size = V(24, 18, 30), Color = c(40, 44, 54), Material = Enum.Material.Metal,
		CFrame = CF(cx - 90, 20, cz + 40), Parent = m })
	m:SetAttribute("District", "Docks")
	return m
end

-------------------------------------------------------------------
-- 10. MANDERIN ARENA
-------------------------------------------------------------------
local function buildArena(districts)
	local m = Instance.new("Model")
	m.Name = "ManderinArena"
	m.Parent = districts
	local cx, cz = LOC.arena.X, LOC.arena.Z
	-- outer ring wall (segments)
	local segs = 20
	local R = 70
	for i = 1, segs do
		local a = (i / segs) * math.pi * 2
		local px, pz = cx + math.cos(a) * R, cz + math.sin(a) * R
		part({ Size = V(24, 40, 6), Color = PAL.glassMid, Material = Enum.Material.SmoothPlastic,
			CFrame = CF(px, 20, pz) * ANG(0, -a + math.rad(90), 0), Parent = m })
		if i % 2 == 0 then
			neon({ Size = V(24, 1.2, 0.5), Color = PAL.neonPurp, Transparency = 0.1,
				CFrame = CF(px, 34, pz) * ANG(0, -a + math.rad(90), 0) * CF(0, 0, -3.2) })
		end
	end
	-- domed roof
	local dome = part({ Shape = Enum.PartType.Ball, Size = V(R * 2 + 6, R * 2 + 6, R * 2 + 6),
		Color = PAL.glassDark, Material = Enum.Material.Glass, Reflectance = 0.2, Transparency = 0.15,
		CFrame = CF(cx, 40 - R + 8, cz), Parent = m })
	dome.CanCollide = false
	-- interior floor + glowing fight ring
	part({ Shape = Enum.PartType.Cylinder, Size = V(2, (R - 6) * 2, (R - 6) * 2), Color = PAL.plazaDark,
		Material = Enum.Material.SmoothPlastic, CFrame = CF(cx, 1, cz) * ANG(0, 0, math.rad(90)), Parent = m })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.4, 60, 60), Color = PAL.neonPurp, Transparency = 0.1,
		CFrame = CF(cx, 2.1, cz) * ANG(0, 0, math.rad(90)) })
	neon({ Shape = Enum.PartType.Cylinder, Size = V(0.5, 40, 40), Color = PAL.neonCyan, Transparency = 0.2,
		CFrame = CF(cx, 2.2, cz) * ANG(0, 0, math.rad(90)) })
	pointLight(part({ Size = V(4, 4, 4), Color = PAL.neonPurp, Material = Enum.Material.Neon,
		Transparency = 0.2, CanCollide = false, CFrame = CF(cx, 60, cz), Parent = m }), PAL.neonPurp, 90, 4)
	-- floating M above the ring
	for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		sign(CF(cx, 48, cz), V(0.1, 0.1, 0.1), "M", { color = PAL.neonPink, glow = true, face = f, parent = m })
	end
	m:SetAttribute("District", "Manderin Arena")
	return m
end

-------------------------------------------------------------------
-- 11. CITY WALLS + gates + corner towers
-------------------------------------------------------------------
local function wallTowerAt(x, z, m)
	part({ Size = V(28, 80, 28), Color = PAL.wall, Material = Enum.Material.Concrete,
		CFrame = CF(x, 40, z), Parent = m })
	neon({ Size = V(29, 1.2, 29), Color = PAL.wallTrim, Transparency = 0.2, CFrame = CF(x, 74, z) })
	pointLight(part({ Size = V(3, 3, 3), Color = PAL.wallTrim, Material = Enum.Material.Neon,
		CanCollide = false, CFrame = CF(x, 82, z), Parent = m }), PAL.wallTrim, 30, 2)
end

local function buildWalls(districts)
	local m = Instance.new("Model")
	m.Name = "CityWalls"
	m.Parent = districts
	local H, T = 60, 10
	local gate = AVENUE + 20   -- opening where each avenue passes through
	-- build each side as two segments leaving a central gate gap
	local sides = {
		{ axis = "z", sign = -1 }, { axis = "z", sign = 1 },
		{ axis = "x", sign = -1 }, { axis = "x", sign = 1 },
	}
	for _, s in ipairs(sides) do
		local segLen = WALL - gate / 2
		for _, dir in ipairs({ -1, 1 }) do
			local off = (gate / 2 + segLen / 2) * dir
			if s.axis == "z" then
				part({ Size = V(segLen, H, T), Color = PAL.wall, Material = Enum.Material.Concrete,
					CFrame = CF(off, H / 2, s.sign * WALL), Parent = m })
				neon({ Size = V(segLen, 1.5, 0.6), Color = PAL.wallTrim, Transparency = 0.25,
					CFrame = CF(off, H - 6, s.sign * WALL + s.sign * (T / 2 + 0.1)) })
			else
				part({ Size = V(T, H, segLen), Color = PAL.wall, Material = Enum.Material.Concrete,
					CFrame = CF(s.sign * WALL, H / 2, off), Parent = m })
				neon({ Size = V(0.6, 1.5, segLen), Color = PAL.wallTrim, Transparency = 0.25,
					CFrame = CF(s.sign * WALL + s.sign * (T / 2 + 0.1), H - 6, off) })
			end
		end
	end
	-- corner + midpoint towers
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			wallTowerAt(sx * WALL, sz * WALL, m)
		end
	end
	-- grand main gate on the south avenue (Z = +WALL)
	local gz = WALL
	part({ Size = V(gate + 36, H + 24, T + 4), Color = PAL.manderin, Material = Enum.Material.Concrete,
		CFrame = CF(0, (H + 24) / 2, gz), Parent = m })
	-- carve the archway (a dark overlay + it stays open because avenue passes; players use the road)
	part({ Size = V(gate, H, T + 6), Color = c(10, 10, 14), Transparency = 0.4, CanCollide = false,
		Material = Enum.Material.SmoothPlastic, CFrame = CF(0, H / 2, gz), Parent = m })
	sign(CF(0, H + 6, gz + T / 2 + 2.2), V(50, 14, 0.6), "MANDERIN",
		{ color = PAL.wallTrim, font = Enum.Font.GothamBlack, glow = true, parent = m })
	m:SetAttribute("District", "City Walls")
	return m
end

-------------------------------------------------------------------
-- 7. SECURITY CHECKPOINTS (scanner gates at each avenue opening)
-------------------------------------------------------------------
local function checkpoint(x, z, rotDeg, m)
	local base = CF(x, 0, z) * ANG(0, math.rad(rotDeg), 0)
	for _, sd in ipairs({ -1, 1 }) do
		part({ Size = V(8, 26, 10), Color = PAL.glassMid, Material = Enum.Material.SmoothPlastic,
			CFrame = base * CF(sd * (AVENUE / 2 + 6), 13, 0), Parent = m })
	end
	part({ Size = V(AVENUE + 24, 8, 10), Color = PAL.manderin, CFrame = base * CF(0, 30, 0), Parent = m })
	sign(base * CF(0, 30, 5.2), V(30, 6, 0.4), "MANDERIN SECURITY",
		{ color = PAL.neonCyan, glow = true, parent = m })
	-- scanner arch (neon ring)
	neon({ Shape = Enum.PartType.Cylinder, Size = V(1, AVENUE + 20, AVENUE + 20), Color = PAL.neonCyan,
		Transparency = 0.4, CFrame = base * CF(0, 14, 0) * ANG(0, math.rad(90), 0) })
end

local function buildCheckpoints(districts)
	local m = Instance.new("Model")
	m.Name = "SecurityCheckpoints"
	m.Parent = districts
	local d = WALL - 40
	checkpoint(0, -d, 0, m)
	checkpoint(0, d, 0, m)
	checkpoint(-d, 0, 90, m)
	checkpoint(d, 0, 90, m)
	m:SetAttribute("District", "Security Checkpoints")
	return m
end

-------------------------------------------------------------------
-- 8. SKY BRIDGES (link tall towers)
-------------------------------------------------------------------
local function skyBridge(p1, p2, y, m)
	local a, b = V(p1[1], y, p1[2]), V(p2[1], y, p2[2])
	local mid = a:Lerp(b, 0.5)
	local len = (b - a).Magnitude
	local look = CFrame.lookAt(mid, b)
	part({ Size = V(8, 1.5, len), Color = PAL.glassMid, Material = Enum.Material.SmoothPlastic,
		CFrame = look, Parent = m })
	neon({ Size = V(0.4, 0.4, len), Color = PAL.neonBlue, Transparency = 0.15, CFrame = look * CF(3.8, 0.9, 0) })
	neon({ Size = V(0.4, 0.4, len), Color = PAL.neonBlue, Transparency = 0.15, CFrame = look * CF(-3.8, 0.9, 0) })
	-- glass roof
	part({ Size = V(9, 0.3, len), Color = PAL.glassDark, Material = Enum.Material.Glass, Transparency = 0.5,
		Reflectance = 0.2, CanCollide = false, CFrame = look * CF(0, 5, 0), Parent = m })
end

local function buildSkyBridges(districts)
	local m = Instance.new("Model")
	m.Name = "SkyBridges"
	m.Parent = districts
	skyBridge({ -150, -90 }, { -60, -150 }, 120, m)
	skyBridge({ 150, -90 }, { 70, -150 }, 130, m)
	skyBridge({ -230, -30 }, { -150, -90 }, 110, m)
	skyBridge({ 170, 80 }, { 220, -30 }, 115, m)
	skyBridge({ -300 - 50, -250 - 40 }, { -300 + 55, -250 - 55 }, 140, m)  -- across tech district
	m:SetAttribute("District", "Sky Bridges")
	return m
end

-------------------------------------------------------------------
-- 9. UNDERCITY (hidden underground under the plaza)
-------------------------------------------------------------------
local function buildUndercity(districts)
	local m = Instance.new("Model")
	m.Name = "Undercity"
	m.Parent = districts
	local floorY = -70
	local W2, D2, H2 = 260, 200, 26
	-- shell
	part({ Size = V(W2, 4, D2), Color = c(18, 16, 24), Material = Enum.Material.Concrete,
		CFrame = CF(0, floorY, 0), Parent = m })
	part({ Size = V(W2, 4, D2), Color = c(14, 12, 18), CFrame = CF(0, floorY + H2, 0), Parent = m })
	for _, s in ipairs({ -1, 1 }) do
		part({ Size = V(4, H2, D2), Color = c(20, 18, 26), CFrame = CF(s * W2 / 2, floorY + H2 / 2, 0), Parent = m })
		part({ Size = V(W2, H2, 4), Color = c(20, 18, 26), CFrame = CF(0, floorY + H2 / 2, s * D2 / 2), Parent = m })
	end
	-- purple neon grid on floor + ceiling strips
	for i = -5, 5 do
		neon({ Size = V(W2 - 10, 0.3, 0.6), Color = PAL.neonPurp, Transparency = 0.35,
			CFrame = CF(0, floorY + 2.2, i * 18) })
		neon({ Size = V(0.6, 0.3, D2 - 10), Color = PAL.neonPink, Transparency = 0.6,
			CFrame = CF(i * 24, floorY + H2 - 2.2, 0) })
	end
	-- black-market stalls + secret-lab pods
	for i = -3, 3 do
		local sx = i * 34
		part({ Size = V(16, 8, 10), Color = c(30, 26, 38), Material = Enum.Material.SmoothPlastic,
			CFrame = CF(sx, floorY + 6, -60), Parent = m })
		neon({ Size = V(16, 0.5, 0.4), Color = (i % 2 == 0) and PAL.neonPurp or PAL.neonPink,
			Transparency = 0.2, CFrame = CF(sx, floorY + 10.2, -55.2) })
		if i % 2 == 0 then
			local pod = part({ Shape = Enum.PartType.Cylinder, Size = V(12, 8, 8), Color = PAL.glassDark,
				Material = Enum.Material.Glass, Reflectance = 0.2, Transparency = 0.25,
				CFrame = CF(sx, floorY + 6, 60) * ANG(0, 0, math.rad(90)), Parent = m })
			pointLight(pod, PAL.neonCyan, 14, 2)
		end
	end
	for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		sign(CF(0, floorY + 18, 0), V(0.1, 0.1, 0.1), "M", { color = PAL.neonPurp, glow = true, face = f, parent = m })
	end
	-- access shaft + stairs from the plaza down to the undercity
	local ax, az = LOC.underAccess.X, LOC.underAccess.Z
	part({ Size = V(24, 4, 24), Color = PAL.manderin, CFrame = CF(ax, 0.5, az), Parent = m })   -- hatch surround
	local steps = 20
	for i = 0, steps do
		local y = -i * (70 / steps)
		part({ Size = V(14, 1.2, 4), Color = PAL.steelDark, Material = Enum.Material.Metal,
			CFrame = CF(ax, y, az - 10 - i * ((D2 / 2 - 12) / steps)), Parent = m })
	end
	m:SetAttribute("District", "Undercity")
	m:SetAttribute("AccessPoint", tostring(V(ax, 0, az)))
	return m
end

-------------------------------------------------------------------
-- CAMPAIGN SCAFFOLDING: spawns + objective markers per mission stage
-------------------------------------------------------------------
local function spawnAt(pos, name, parent, neutral)
	local sp = Instance.new("SpawnLocation")
	sp.Name = name
	sp.Size = V(12, 1, 12)
	sp.Anchored = true
	sp.CanCollide = true
	sp.Neutral = neutral ~= false
	sp.Duration = 0
	sp.Color = PAL.neonBlue
	sp.Material = Enum.Material.Neon
	sp.Transparency = 0.3
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.CFrame = CF(pos.X, 1, pos.Z)
	sp.Parent = parent
	return sp
end

-- ordered campaign route through the city, matched to the concept districts
local CAMPAIGN_STAGES = {
	{ id = 1,  district = "Residential Area",     pos = LOC.residential + V(0, 0, -30), objective = "Escape the monitored residential blocks." },
	{ id = 2,  district = "Central Plaza",        pos = V(0, 0, 60),                    objective = "Reach Manderin's monument in Central Plaza." },
	{ id = 3,  district = "Security Checkpoints",  pos = V(0, 0, WALL - 40),             objective = "Slip past a Manderin Security checkpoint." },
	{ id = 4,  district = "Tech District",        pos = LOC.tech + V(0, 0, 90),          objective = "Sabotage the labs in the Tech District." },
	{ id = 5,  district = "Industrial District",  pos = LOC.industrial + V(0, 0, 70),    objective = "Shut down the Industrial District plants." },
	{ id = 6,  district = "Docks",                pos = LOC.docks + V(60, 0, 0),         objective = "Intercept a shipment at the Docks." },
	{ id = 7,  district = "Undercity",            pos = LOC.underAccess,                 objective = "Descend into the Undercity black market." },
	{ id = 8,  district = "Manderin Arena",       pos = LOC.arena,                       objective = "Win the trial in the Manderin Arena." },
	{ id = 9,  district = "Manderin Tower",       pos = LOC.tower + V(0, 0, 60),         objective = "Storm Manderin Tower — final confrontation." },
}

local function buildCampaign(m)
	local camp = Instance.new("Folder")
	camp.Name = "Campaign"
	camp.Parent = m
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = camp
	-- main campaign spawn (stage 1)
	spawnAt(CAMPAIGN_STAGES[1].pos, "CampaignStart", spawns, true)

	local objectives = Instance.new("Folder")
	objectives.Name = "Objectives"
	objectives.Parent = camp
	for _, stage in ipairs(CAMPAIGN_STAGES) do
		-- a glowing objective beacon the campaign system can detect / toggle
		local beacon = part({
			Shape = Enum.PartType.Cylinder, Size = V(30, 8, 8), Color = PAL.neonCyan,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = true,
			CFrame = CF(stage.pos.X, 15, stage.pos.Z) * ANG(0, 0, math.rad(90)),
			Parent = objectives,
		})
		beacon.Name = "Stage" .. stage.id .. "_" .. string.gsub(stage.district, "%s", "")
		beacon:SetAttribute("Stage", stage.id)
		beacon:SetAttribute("District", stage.district)
		beacon:SetAttribute("Objective", stage.objective)
		pointLight(beacon, PAL.neonCyan, 26, 2)
		-- per-stage checkpoint spawn (disabled by default; enable as the player advances)
		local sp = spawnAt(stage.pos, "Checkpoint_" .. stage.id, spawns, true)
		sp.Enabled = false
	end
	return camp
end

-------------------------------------------------------------------
-- PUBLIC: build the whole city
-------------------------------------------------------------------
function MetroCityBuilder.build(parent, opts)
	opts = opts or {}
	parent = parent or workspace
	rng = Random.new(opts.seed or 20250720)

	-- clear a previous build so re-running is safe
	local existing = parent:FindFirstChild("MetroCity")
	if existing then existing:Destroy() end

	root = Instance.new("Model")
	root.Name = "MetroCity"

	fxParent = Instance.new("Folder")
	fxParent.Name = "Decor"
	fxParent.Parent = root
	structParent = Instance.new("Folder")
	structParent.Name = "Structures"
	structParent.Parent = root
	local districts = Instance.new("Folder")
	districts.Name = "Districts"
	districts.Parent = root

	buildGround()
	buildRoads()
	buildPlaza(districts)          -- 1
	buildManderinTower(districts)  -- 2
	buildDowntown(districts)       -- skyline
	buildTech(districts)           -- 3
	buildIndustrial(districts)     -- 4
	buildResidential(districts)    -- 5
	buildDocks(districts)          -- 6
	buildCheckpoints(districts)    -- 7
	buildSkyBridges(districts)     -- 8
	buildUndercity(districts)      -- 9
	buildArena(districts)          -- 10
	buildWalls(districts)          -- 11

	if opts.campaign ~= false then buildCampaign(root) end

	root:SetAttribute("Districts", 11)
	root.Parent = parent
	return root
end

return MetroCityBuilder
