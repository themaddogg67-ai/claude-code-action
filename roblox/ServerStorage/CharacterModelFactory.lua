--[[
	CharacterModelFactory  (ModuleScript)
	WHERE IT GOES: ServerStorage > CharacterModelFactory

	Builds themed R6 character rigs out of parts from an appearance SPEC — the
	looks pulled straight from the roster art (capes, back-tentacles, TV-heads,
	hoods, glowing eyes, chest emblems, elemental auras). No uploaded assets.

	One factory serves two jobs:
	  * CAMPAIGN BOSSES — the controller builds a boss's themed model here and
	    hands it to EnemyFactory.spawnBoss as opts.rig, so Manderin looks like
	    Manderin, the Void Overlord like the Void Overlord, etc.
	  * DISPLAY MODELS — spawn any character as an anchored statue (opts.display)
	    for a lobby / character-select / gallery.

	Every rig is a valid Humanoid R6 (HumanoidRootPart/Torso/Head/limbs), so the
	AbilityEngine damages it and the boss AI drives it with no special-casing.

	API:
	  build(nameOrSpec, position, opts) -> Model
	     opts: display(bool, anchors as a statue), health, scale, parent
	  gallery(parent, originCFrame)     -> Folder  (all specs lined up as statues)

	Specs live in ReplicatedStorage.Characters.CharacterModels (loaded defensively);
	you can also pass a spec table directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterModelFactory = {}

local function C(t) return t and Color3.fromRGB(t[1], t[2], t[3]) or nil end

local Models
do
	local ok, m = pcall(function() return require(ReplicatedStorage.Characters.CharacterModels) end)
	Models = ok and m or {}
end

-------------------------------------------------------------------
-- PART HELPERS
-------------------------------------------------------------------
local function weld(a, b)
	local w = Instance.new("WeldConstraint"); w.Part0 = a; w.Part1 = b; w.Parent = a
end
local function limb(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Color = color or Color3.fromRGB(120, 120, 120)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local function neonPart(model, name, size, color, cframe)
	local p = limb(model, name, size, color, Enum.Material.Neon)
	p.CanCollide = false; p.CFrame = cframe
	return p
end

-------------------------------------------------------------------
-- APPEARANCE FEATURES
-------------------------------------------------------------------
local function addHair(model, head, spec, s)
	local col = C(spec.hair)
	-- spiky anime hair: a cluster of angled wedges/blocks on top of the head
	for i = 1, 6 do
		local a = math.rad((i - 3.5) * 40)
		local spike = limb(model, "Hair", Vector3.new(0.55, 1.6, 0.55) * s, col, Enum.Material.SmoothPlastic)
		spike.CanCollide = false
		spike.CFrame = head.CFrame * CFrame.new(math.sin(a) * 0.5 * s, 0.75 * s, math.cos(a) * 0.5 * s - 0.1)
			* CFrame.Angles(math.rad(-30), a, 0)
		weld(spike, head)
	end
end

local function addHood(model, head, spec, s)
	local col = C(spec.hood)
	local cowl = limb(model, "Hood", Vector3.new(1.7, 1.7, 1.7) * s, col, Enum.Material.SmoothPlastic)
	cowl.CanCollide = false
	cowl.CFrame = head.CFrame * CFrame.new(0, 0.25 * s, 0.15 * s)
	weld(cowl, head)
	-- shadowed face
	local face = neonPart(model, "HoodShadow", Vector3.new(1.1, 1.1, 0.2) * s, Color3.fromRGB(6, 6, 10),
		head.CFrame * CFrame.new(0, 0, -0.75 * s))
	face.Material = Enum.Material.SmoothPlastic
	weld(face, head)
	if spec.hoodGlow then
		local g = neonPart(model, "HoodEyes", Vector3.new(0.8, 0.18, 0.12) * s, C(spec.hoodGlow),
			head.CFrame * CFrame.new(0, 0.05 * s, -0.83 * s))
		weld(g, head)
	end
end

local function addEyes(model, head, spec, s)
	local col = C(spec.eyes)
	if spec.eyeStyle == "single" then
		local e = neonPart(model, "Eye", Vector3.new(0.7, 0.7, 0.14) * s, col, head.CFrame * CFrame.new(0, 0.05 * s, -0.62 * s))
		weld(e, head)
	elseif spec.eyeStyle == "visor" then
		local v = neonPart(model, "Visor", Vector3.new(1.25, 0.28, 0.14) * s, col, head.CFrame * CFrame.new(0, 0.05 * s, -0.62 * s))
		weld(v, head)
	else -- dual
		for _, side in ipairs({ -1, 1 }) do
			local e = neonPart(model, "Eye", Vector3.new(0.28, 0.16, 0.12) * s, col, head.CFrame * CFrame.new(side * 0.3 * s, 0.06 * s, -0.62 * s))
			weld(e, head)
		end
	end
end

local function addTvHead(model, hrp, spec, s)
	-- Channel-style monitor head
	local box = limb(model, "Head", Vector3.new(2.2, 1.8, 1.6) * s, C(spec.body) or Color3.fromRGB(30, 32, 38), Enum.Material.Metal)
	box.CFrame = hrp.CFrame * CFrame.new(0, 1.7 * s, 0)
	weld(box, hrp)
	local screen = neonPart(model, "Screen", Vector3.new(1.7, 1.3, 0.12) * s, C(spec.screen) or Color3.fromRGB(180, 210, 220),
		box.CFrame * CFrame.new(0, 0, -0.82 * s))
	screen.Transparency = 0.05
	weld(screen, box)
	-- a hand pressing through the static (SurfaceGui)
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.Adornee = screen
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud = 40; gui.Parent = screen
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
	lbl.Text = "🖐"; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(20, 20, 25); lbl.TextScaled = true; lbl.Parent = gui
	local antenna = limb(model, "Antenna", Vector3.new(0.12, 1.4, 0.12) * s, Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	antenna.CanCollide = false; antenna.CFrame = box.CFrame * CFrame.new(0.5 * s, 1.1 * s, 0) * CFrame.Angles(0, 0, math.rad(20)); weld(antenna, box)
	return box
end

local function addEmblem(model, torso, spec, s)
	local em = spec.emblem
	local plate = limb(model, "Emblem", Vector3.new(1.2, 1.2, 0.16) * s, C(em.plate) or Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic)
	plate.CanCollide = false
	plate.CFrame = torso.CFrame * CFrame.new(0, 0.15 * s, -0.55 * s)
	weld(plate, torso)
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.Adornee = plate
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud = 40; gui.Parent = plate
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(0.9, 0.9); lbl.Position = UDim2.fromScale(0.05, 0.05)
	lbl.BackgroundTransparency = 1; lbl.Text = em.text or "M"; lbl.Font = Enum.Font.GothamBlack
	lbl.TextColor3 = C(em.color) or Color3.fromRGB(30, 90, 200); lbl.TextScaled = true; lbl.Parent = gui
end

local function addCape(model, torso, spec, s)
	local col = C(spec.cape)
	local cape = limb(model, "Cape", Vector3.new(2.1, 3.2, 0.2) * s, col, Enum.Material.SmoothPlastic)
	cape.CanCollide = false
	cape.CFrame = torso.CFrame * CFrame.new(0, -0.4 * s, 0.62 * s) * CFrame.Angles(math.rad(8), 0, 0)
	weld(cape, torso)
	-- flared lower hem
	local hem = limb(model, "CapeHem", Vector3.new(2.6, 1.4, 0.2) * s, col, Enum.Material.SmoothPlastic)
	hem.CanCollide = false
	hem.CFrame = cape.CFrame * CFrame.new(0, -2.2 * s, 0.1 * s) * CFrame.Angles(math.rad(14), 0, 0)
	weld(hem, cape)
end

local function addTentacles(model, torso, spec, s)
	local col = C(spec.tentacleColor or spec.body) or Color3.fromRGB(30, 32, 40)
	local tip = C(spec.tentacleTip or spec.aura and spec.auraColor) or Color3.fromRGB(60, 150, 255)
	local n = spec.tentacles
	for i = 1, n do
		local base = torso.CFrame * CFrame.new(((i - (n + 1) / 2) * 0.7) * s, 0.6 * s, 0.55 * s)
		local prev, prevSize = base, 0.7 * s
		for seg = 1, 3 do
			local len = (2.6 - seg * 0.4) * s
			local part = limb(model, "Tentacle", Vector3.new(prevSize, len, prevSize), col, Enum.Material.SmoothPlastic)
			part.CanCollide = false
			part.CFrame = prev * CFrame.new(0, len / 2, 0) * CFrame.Angles(math.rad(28 + seg * 8), math.rad((i % 2 == 0) and 12 or -12), 0)
			weld(part, torso)
			prev = part.CFrame * CFrame.new(0, len / 2, 0)
			prevSize = prevSize * 0.8
		end
		neonPart(model, "TentacleTip", Vector3.new(0.5, 0.5, 0.5) * s, tip, prev)
	end
end

local AURA = {
	fire     = { tex = "rbxasset://textures/particles/fire_main.dds",     color = { 255, 120, 40 } },
	electric = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 130, 200, 255 } },
	void     = { tex = "rbxasset://textures/particles/smoke_main.dds",    color = { 150, 60, 255 } },
	energy   = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 90, 200, 255 } },
	holy     = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 255, 240, 180 } },
	gold     = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 255, 210, 90 } },
	ice      = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 170, 230, 255 } },
	green    = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 90, 240, 120 } },
	cosmic   = { tex = "rbxasset://textures/particles/sparkles_main.dds", color = { 200, 140, 255 } },
}
local function addAura(model, hrp, spec, s)
	local a = AURA[spec.aura]; if not a then return end
	local col = C(spec.auraColor) or Color3.fromRGB(a.color[1], a.color[2], a.color[3])
	local att = Instance.new("Attachment"); att.Parent = hrp
	local e = Instance.new("ParticleEmitter")
	e.Texture = a.tex; e.Color = ColorSequence.new(col); e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * s), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Rate = 22
	e.Speed = NumberRange.new(1, 4)
	e.SpreadAngle = Vector2.new(30, 30)
	e.Acceleration = Vector3.new(0, spec.aura == "fire" and 6 or 2, 0)
	e.Parent = att
	local light = Instance.new("PointLight"); light.Color = col; light.Range = 12; light.Brightness = 2; light.Parent = hrp
end

-------------------------------------------------------------------
-- BUILD A RIG
-------------------------------------------------------------------
local function resolveSpec(nameOrSpec)
	if type(nameOrSpec) == "table" then return nameOrSpec end
	return Models[nameOrSpec]
end

function CharacterModelFactory.build(nameOrSpec, position, opts)
	opts = opts or {}
	local spec = resolveSpec(nameOrSpec) or {}
	local name = spec.name or (type(nameOrSpec) == "string" and nameOrSpec) or "Character"
	local s = opts.scale or spec.scale or 1
	local body = C(spec.body) or Color3.fromRGB(60, 64, 74)
	local limbs = C(spec.limbs) or body
	local skin = C(spec.skin) or Color3.fromRGB(215, 180, 150)
	local mat = spec.material and Enum.Material[spec.material] or Enum.Material.SmoothPlastic
	position = position or Vector3.new(0, 5, 0)

	local model = Instance.new("Model"); model.Name = name

	local hrp = limb(model, "HumanoidRootPart", Vector3.new(2, 2, 1) * s, body, mat)
	hrp.Transparency = 1; hrp.CanCollide = false; hrp.CFrame = CFrame.new(position)
	model.PrimaryPart = hrp

	local torso = limb(model, "Torso", Vector3.new(2, 2, 1) * s, body, mat)
	torso.CFrame = hrp.CFrame; weld(torso, hrp)

	local head
	if spec.tvHead then
		head = addTvHead(model, hrp, spec, s)
	else
		head = limb(model, "Head", Vector3.new(1.35, 1.35, 1.35) * s, skin, mat)
		head.CFrame = hrp.CFrame * CFrame.new(0, 1.7 * s, 0); weld(head, hrp)
		if spec.hair then addHair(model, head, spec, s) end
		if spec.hood then addHood(model, head, spec, s) end
		if spec.eyes then addEyes(model, head, spec, s) end
	end

	for _, side in ipairs({ -1, 1 }) do
		local arm = limb(model, "Arm", Vector3.new(1, 2, 1) * s, limbs, mat)
		arm.CFrame = hrp.CFrame * CFrame.new(side * 1.5 * s, 0, 0); weld(arm, hrp)
		local leg = limb(model, "Leg", Vector3.new(1, 2, 1) * s, C(spec.legs) or limbs, mat)
		leg.CFrame = hrp.CFrame * CFrame.new(side * 0.5 * s, -2 * s, 0); weld(leg, hrp)
	end

	if spec.cape then addCape(model, torso, spec, s) end
	if spec.tentacles then addTentacles(model, torso, spec, s) end
	if spec.emblem then addEmblem(model, torso, spec, s) end
	if spec.chestEye then
		local ce = neonPart(model, "ChestEye", Vector3.new(0.9, 0.9, 0.14) * s, C(spec.chestEye), torso.CFrame * CFrame.new(0, 0.1 * s, -0.55 * s))
		weld(ce, torso)
	end
	if spec.aura then addAura(model, hrp, spec, s) end

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = opts.health or spec.health or 100
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = opts.walkSpeed or spec.walkSpeed or 14
	hum.DisplayName = name
	hum.RigType = Enum.HumanoidRigType.R6
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.Parent = model

	if opts.display then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
	end

	model.Parent = opts.parent or workspace
	return model
end

-- has a themed spec for this name?
function CharacterModelFactory.has(name)
	return Models[name] ~= nil
end

-------------------------------------------------------------------
-- GALLERY — every modeled character lined up as a display statue
-------------------------------------------------------------------
function CharacterModelFactory.gallery(parent, originCFrame)
	parent = parent or workspace
	originCFrame = originCFrame or CFrame.new(0, 5, 0)
	local folder = Instance.new("Folder"); folder.Name = "CharacterGallery"; folder.Parent = parent

	local names = {}
	for n in pairs(Models) do names[#names + 1] = n end
	table.sort(names)

	local perRow, spacing = 10, 8
	for i, n in ipairs(names) do
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		local pos = originCFrame * CFrame.new(col * spacing, 0, row * spacing)
		local m = CharacterModelFactory.build(n, pos.Position, { display = true, parent = folder })
		-- pedestal + nameplate
		local base = Instance.new("Part")
		base.Anchored = true; base.Size = Vector3.new(6, 1, 6); base.Material = Enum.Material.SmoothPlastic
		base.Color = Color3.fromRGB(30, 34, 44); base.Position = pos.Position - Vector3.new(0, 3.5, 0); base.Parent = folder
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 120, 0, 26)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Adornee = m.PrimaryPart; bb.Parent = m.PrimaryPart
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
		t.Text = n; t.Font = Enum.Font.GothamBold; t.TextColor3 = Color3.fromRGB(240, 245, 255); t.TextScaled = true; t.Parent = bb
	end
	return folder
end

return CharacterModelFactory
