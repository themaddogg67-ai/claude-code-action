--[[
	AbilityEngine  (ModuleScript)
	WHERE IT GOES: ServerScriptService > Systems > AbilityEngine  (replace the old contents)

	The ONE place that knows how to PERFORM abilities. It reads an ability
	"definition" (a table from MasteryData / CharacterData / construct kits)
	and runs it with server-authoritative hit detection plus layered VFX.
	You never touch this to add masteries -- you only add data.

	FIXED vs your old version (everything stays backward compatible):
	  * startBeam / updateBeamAim / stopBeam now actually exist. AbilityManager
	    was already calling them, so any beam press -- and every PlayerRemoving --
	    threw "attempt to call a nil value".
	  * Every hit now dedupes per CHARACTER. The old code damaged once per limb
	    inside the hitbox, so one swing could deal 10x+ damage on R15 rigs.
	  * AOE no longer spawns a real Explosion instance. Even with BlastPressure=0
	    an Explosion still breaks joints inside half its radius = instant kill.
	  * Projectiles are anchored + Spherecast-stepped: no deprecated BodyVelocity,
	    no tunneling through targets at high speed, and exploiters can never get
	    network ownership of them.
	  * Dash raycasts first so you can't clip through walls.
	  * Speed buffs/slows share one multiplier model, so overlapping buffs can't
	    permanently corrupt WalkSpeed anymore.
	  * The client's aim (mouse position) is validated (type/NaN/magnitude) and
	    actually USED -- projectiles, beams, melee, dash and teleports aim at it.
	  * New data-driven types: "teleport" and "vortex" (your old TeleportWarp and
	    FrameSucker effects, rebuilt as real abilities). Optional def fields are
	    documented at the bottom of this file.

	VFX architecture (layered, multiplayer-cheap):
	  * The server builds the gameplay-critical core -- projectile bodies, beam
	    core + glow, shockwave rings, blooms, warps, lights, particle bursts.
	    These are replicated Instances; particle SIMULATION always runs on each
	    client, so this is cheap for the server.
	  * For client-only polish (camera shake, screen flash, FOV kicks, debris,
	    dust, ground cracks) the engine fires the "AbilityFX" RemoteEvent
	    (auto-created below). The AbilityVFXClient LocalScript renders those.
	    If that LocalScript is missing, everything still works -- you just lose
	    the client-only layer.
]]

local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityEngine = {}

-------------------------------------------------------------------
-- FX PLUMBING
-------------------------------------------------------------------
local fxRemote = ReplicatedStorage:FindFirstChild("AbilityFX")
if not fxRemote then
	fxRemote = Instance.new("RemoteEvent")
	fxRemote.Name = "AbilityFX"
	fxRemote.Parent = ReplicatedStorage
end
local function fxAll(kind, data) fxRemote:FireAllClients(kind, data) end
local function fxFor(player, kind, data) fxRemote:FireClient(player, kind, data) end

-- one tidy container for every temporary FX part (also lets raycasts skip them)
local fxFolder = workspace:FindFirstChild("AbilityFXParts")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "AbilityFXParts"
	fxFolder.Parent = workspace
end

-- guaranteed built-in textures (no uploads needed, can never fail to load)
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FIRE  = "rbxasset://textures/particles/fire_main.dds"

-------------------------------------------------------------------
-- STYLE PALETTES
-- def.style picks a palette; keywords in styleKey/name refine it
-- (so "IceBeam" reads icy without any data changes); def.color overrides.
-------------------------------------------------------------------
local PALETTES = {
	energy   = { main = Color3.fromRGB( 60, 180, 255), accent = Color3.fromRGB(190, 235, 255) },
	physical = { main = Color3.fromRGB(255, 170,  70), accent = Color3.fromRGB(255, 225, 170) },
	shadow   = { main = Color3.fromRGB(140,  40, 255), accent = Color3.fromRGB( 80,   0, 160) },
	cosmic   = { main = Color3.fromRGB(255, 225, 120), accent = Color3.fromRGB(200, 140, 255) },
	fire     = { main = Color3.fromRGB(255, 110,  40), accent = Color3.fromRGB(255, 215, 120) },
	ice      = { main = Color3.fromRGB(150, 220, 255), accent = Color3.fromRGB(235, 250, 255) },
	nature   = { main = Color3.fromRGB(110, 230, 120), accent = Color3.fromRGB(220, 255, 200) },
}
local KEYWORDS = {
	{ words = { "ice", "frost", "freez", "snow", "cryo" },              key = "ice" },
	{ words = { "fire", "flame", "ember", "burn", "magma", "lava" },    key = "fire" },
	{ words = { "shadow", "void", "dark", "curse", "grim", "death" },   key = "shadow" },
	{ words = { "god", "holy", "gold", "cosmic", "star", "divine" },    key = "cosmic" },
	{ words = { "rock", "stone", "earth", "titan" },                    key = "physical" },
	{ words = { "toxic", "venom", "nature", "leaf" },                   key = "nature" },
}
local function paletteFor(def)
	local hint = string.lower((def.styleKey or "") .. " " .. (def.name or ""))
	for _, group in ipairs(KEYWORDS) do
		for _, w in ipairs(group.words) do
			if string.find(hint, w, 1, true) then
				local p = PALETTES[group.key]
				return { main = def.color or p.main, accent = p.accent }
			end
		end
	end
	local p = PALETTES[def.style] or PALETTES.energy
	return { main = def.color or p.main, accent = p.accent }
end

-------------------------------------------------------------------
-- SMALL HELPERS
-------------------------------------------------------------------
local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end
local function getRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end
local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function getMuzzle(char)
	return char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or getRoot(char)
end

-- aim comes from the client: reject non-vectors, NaN and absurd values
local function isBadVector(v)
	if typeof(v) ~= "Vector3" then return true end
	if v ~= v then return true end          -- NaN components make a vector unequal to itself
	if v.Magnitude > 10000 then return true end
	return false
end
local function aimDirection(origin, aim, fallback)
	if not isBadVector(aim) then
		local d = aim - origin
		if d.Magnitude > 0.05 then return d.Unit end
	end
	return fallback
end
local function safeLookAt(from, to)
	local d = to - from
	if d.Magnitude < 0.05 then return CFrame.new(from) end
	local up = math.abs(d.Unit:Dot(Vector3.yAxis)) > 0.99 and Vector3.xAxis or Vector3.yAxis
	return CFrame.lookAt(from, to, up)
end
local function groundBelow(pos, ignoreChar)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { fxFolder }
	if ignoreChar then table.insert(filter, ignoreChar) end
	params.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -16, 0), params)
	return hit and (hit.Position + Vector3.new(0, 0.15, 0)) or pos
end

-------------------------------------------------------------------
-- VFX BUILDING BLOCKS (server side, replicated to everyone)
-------------------------------------------------------------------
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false      -- raycasts/hitboxes automatically ignore FX
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = fxFolder
	return p
end

-- one-shot particle burst at a position
local function emit(pos, color, count, speed, size, spread, lifetime, texture)
	local holder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.9
	e.Size = NumberSequence.new({ kp(0, size), kp(1, 0) })
	e.Transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) })
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Drag = 2
	e.Rate = 0
	if texture then e.Texture = texture end
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, lifetime + 0.5)
end

-- expanding flat ring (cylinder length runs along X, so tip it upright)
local function shockwaveRing(pos, color, radius, duration)
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = 0.15,
		Size = Vector3.new(0.35, 1, 1),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
	})
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.35, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, duration + 0.1)
end

local function bloomSphere(pos, color, endSize, duration)
	local s = makePart({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pos) })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 4
	light.Range = math.min(endSize * 2.5, 60)
	light.Parent = s
	TweenService:Create(s, TweenInfo.new(duration, Enum.EasingStyle.Quart), {
		Size = Vector3.new(endSize, endSize, endSize),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(duration), { Brightness = 0 }):Play()
	Debris:AddItem(s, duration + 0.1)
end

local function impactFX(pos, palette, big)
	bloomSphere(pos, palette.main, big and 9 or 4, 0.25)
	emit(pos, palette.accent, big and 22 or 10, big and 38 or 22, big and 1.1 or 0.6, 180, 0.45, TEX_SPARK)
	fxAll("impact", { pos = pos, color = palette.main, big = big or false })
end

local function teleWarp(pos, palette)
	local warp = makePart({ Shape = Enum.PartType.Ball, Color = palette.main, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(pos) })
	TweenService:Create(warp, TweenInfo.new(0.25), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
	emit(pos, palette.accent, 14, 20, 0.7, 180, 0.4, TEX_SPARK)
	Debris:AddItem(warp, 0.5)
end

-------------------------------------------------------------------
-- SPEED MODEL
-- WalkSpeed = BaseWalkSpeed * SpeedBuffMult * SlowMult (character attributes).
-- Generation counters make overlapping buffs/slows refresh cleanly instead of
-- permanently corrupting speed (the old buff handler restored a stale "base").
-------------------------------------------------------------------
local function refreshSpeed(char)
	local hum = getHumanoid(char)
	if not hum then return end
	local base = char:GetAttribute("BaseWalkSpeed")
	if not base then
		base = hum.WalkSpeed
		char:SetAttribute("BaseWalkSpeed", base)
	end
	hum.WalkSpeed = base * (char:GetAttribute("SpeedBuffMult") or 1) * (char:GetAttribute("SlowMult") or 1)
end
local function applySpeedMult(char, multAttr, amount, duration)
	local hum = getHumanoid(char)
	if not hum then return end
	if not char:GetAttribute("BaseWalkSpeed") then char:SetAttribute("BaseWalkSpeed", hum.WalkSpeed) end
	local genAttr = multAttr .. "Gen"
	local gen = (char:GetAttribute(genAttr) or 0) + 1
	char:SetAttribute(genAttr, gen)
	char:SetAttribute(multAttr, amount)
	refreshSpeed(char)
	task.delay(duration, function()
		if char.Parent and char:GetAttribute(genAttr) == gen then
			char:SetAttribute(multAttr, 1)
			refreshSpeed(char)
		end
	end)
end

-------------------------------------------------------------------
-- TARGETING + CENTRAL DAMAGE
-------------------------------------------------------------------
local function getHitboxParts(cframeOrPos, size, ignoreChar)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignoreChar, fxFolder }
	local cf = typeof(cframeOrPos) == "CFrame" and cframeOrPos or CFrame.new(cframeOrPos)
	return workspace:GetPartBoundsInBox(cf, size, params)
end

-- Dedupe: a character is damaged ONCE per swing no matter how many of its
-- limbs sit inside the hitbox. Pass the same `seen` table across several
-- boxes (dash sweep, splash) to keep the dedupe over the whole attack.
local function forEachTarget(parts, attackerChar, seen, fn)
	seen = seen or {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= attackerChar and not seen[model] then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				seen[model] = true
				fn(model, hum, root)
			end
		end
	end
	return seen
end

-- Central damage: BLOCK + TRUE GOLD / TRUE SILVER reduction, knockback, hit FX.
-- Returns the target Player (if any) so callers can hook XP drops.
local function damageModel(attackerChar, model, hum, root, damage, knockback, up, palette)
	damage = damage or 0
	knockback = knockback or 0

	local targetPlayer = Players:GetPlayerFromCharacter(model)

	-- BLOCK reduction (your existing system)
	if targetPlayer and targetPlayer:GetAttribute("Blocking") then
		damage = damage * 0.3
		knockback = knockback * 0.2
		fxAll("blocked", { pos = root.Position })
	end

	-- TRUE GOLD / TRUE SILVER reduction (set by PlayerDataManager)
	if targetPlayer then
		local form = targetPlayer:GetAttribute("Form")
		if form == "Gold" then
			damage = damage * 0.05      -- reduces 95%
		elseif form == "Silver" then
			damage = damage * 0.25      -- reduces 75%
		end
	end

	if damage > 0 then hum:TakeDamage(damage) end

	local aRoot = getRoot(attackerChar)
	if aRoot and knockback ~= 0 then
		local dir = root.Position - aRoot.Position
		dir = dir.Magnitude > 0 and dir.Unit or aRoot.CFrame.LookVector
		root.AssemblyLinearVelocity = dir * knockback + Vector3.new(0, up or 0, 0)
	end

	if palette and damage > 0 then
		emit(root.Position, palette.main, 8, 16, 0.5, 180, 0.35, TEX_SPARK)
	end
	return targetPlayer
end

-------------------------------------------------------------------
-- SHARED TICK
-- One Heartbeat connection drives every live projectile, beam and vortex.
-- It connects only while something is active and disconnects when idle.
-------------------------------------------------------------------
local activeProjectiles = {}
local activeBeams = {}      -- player -> beam state
local activeVortexes = {}
local stepProjectiles, stepBeams, stepVortexes
local tickConn = nil

local function anyActive()
	return #activeProjectiles > 0 or next(activeBeams) ~= nil or #activeVortexes > 0
end
local function ensureTick()
	if tickConn then return end
	tickConn = RunService.Heartbeat:Connect(function(dt)
		stepProjectiles(dt)
		stepBeams(dt)
		stepVortexes(dt)
		if not anyActive() then
			tickConn:Disconnect()
			tickConn = nil
		end
	end)
end

-------------------------------------------------------------------
-- ABILITY TYPE HANDLERS
-- Add a new "type" here only if you invent a brand-new KIND of move.
-------------------------------------------------------------------
local handlers = {}

handlers.melee = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local range = def.range or 5
	local size = def.size or Vector3.new(7, 7, 7)
	local dir = aimDirection(root.Position, aim, root.CFrame.LookVector)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.01 and dir.Unit or root.CFrame.LookVector
	local center = root.Position + dir * range

	local hitAny = false
	forEachTarget(getHitboxParts(safeLookAt(center, center + dir), size, char), char, nil, function(model, hum, tRoot)
		hitAny = true
		damageModel(char, model, hum, tRoot, def.damage, def.knockback, def.up, palette)
	end)

	-- slash arc that sweeps across the swing
	local arc = makePart({
		Size = Vector3.new(range + 3, 0.25, 1.6),
		Color = palette.main,
		Transparency = 0.1,
		CFrame = safeLookAt(root.Position + dir * (range * 0.5) + Vector3.new(0, 0.5, 0), center)
			* CFrame.Angles(0, math.rad(55), 0),
	})
	TweenService:Create(arc, TweenInfo.new(0.16, Enum.EasingStyle.Quart), {
		CFrame = arc.CFrame * CFrame.Angles(0, math.rad(-110), 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(arc, 0.25)
	emit(center, palette.accent, 5, 10, 0.4, 160, 0.25, TEX_SPARK)
	if hitAny then fxAll("shake", { pos = center, intensity = 0.35, radius = 30 }) end
end

handlers.aoe = function(char, root, def, player)
	local palette = paletteFor(def)
	local radius = def.radius or 20
	local size = Vector3.new(radius * 2, def.height or 12, radius * 2)
	forEachTarget(getHitboxParts(root.Position, size, char), char, nil, function(model, hum, tRoot)
		damageModel(char, model, hum, tRoot, def.damage, def.knockback, def.up, palette)
	end)

	-- layered blast: core flash + double shockwave + fire + rolling ground smoke,
	-- then the client adds debris, dust, cracks, refraction and camera shake.
	local ground = groundBelow(root.Position, char)
	bloomSphere(root.Position, palette.main, radius * 0.9, 0.35)
	shockwaveRing(ground, palette.main, radius * 1.15, 0.5)
	shockwaveRing(ground, palette.accent, radius * 0.7, 0.35)
	emit(root.Position, palette.main, 26, radius * 1.6, 1.4, 180, 0.6, TEX_FIRE)
	emit(ground, Color3.fromRGB(120, 110, 100), 18, radius, 2.4, 80, 1.1, TEX_SMOKE)
	local power = math.clamp((def.damage or 25) / 50 + radius / 40, 0.4, 1.6)
	fxAll("blast", { pos = ground, color = palette.main, radius = radius, power = power })
end

handlers.dash = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local dir = aimDirection(root.Position, aim, root.CFrame.LookVector)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.01 and dir.Unit or root.CFrame.LookVector
	local from = root.Position
	local distance = def.distance or 0

	if distance > 0 then
		-- raycast so the dash stops at walls instead of clipping through them
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, fxFolder }
		local hit = workspace:Raycast(from, dir * distance, params)
		if hit then distance = math.max((hit.Position - from).Magnitude - 2.5, 0) end

		-- afterglow ribbon while moving
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1, 0); a0.Parent = root
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1, 0); a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(palette.main)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = root
		Debris:AddItem(trail, 0.8); Debris:AddItem(a0, 0.8); Debris:AddItem(a1, 0.8)

		root.CFrame = safeLookAt(from + dir * distance, from + dir * (distance + 5))
		emit(from, palette.accent, 10, 14, 0.7, 120, 0.4)
		if player then fxFor(player, "fovKick", { amount = 9, time = 0.3 }) end
	end

	if def.damage and def.damage > 0 then
		-- sweep the whole path so you can't dash THROUGH someone without hitting them
		local seen = {}
		for d = 0, math.max(distance, 0.1), 6 do
			forEachTarget(getHitboxParts(from + dir * d, Vector3.new(9, 8, 9), char), char, seen, function(model, hum, tRoot)
				damageModel(char, model, hum, tRoot, def.damage, def.knockback, def.up, palette)
			end)
		end
		forEachTarget(getHitboxParts(root.Position, Vector3.new(9, 8, 9), char), char, seen, function(model, hum, tRoot)
			damageModel(char, model, hum, tRoot, def.damage, def.knockback, def.up, palette)
		end)
	end
end

handlers.projectile = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local size = typeof(def.size) == "Vector3" and def.size or Vector3.new(2.4, 2.4, 2.4)
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local origin = root.Position + Vector3.new(0, 0.8, 0)
	local dir = aimDirection(origin, aim, root.CFrame.LookVector)
	origin += dir * 3

	local ball = makePart({ Shape = Enum.PartType.Ball, Color = palette.main, Size = size, CFrame = safeLookAt(origin, origin + dir) })
	local light = Instance.new("PointLight")
	light.Color = palette.main; light.Brightness = 3; light.Range = 14; light.Parent = ball
	local tail = Instance.new("ParticleEmitter")
	tail.Color = ColorSequence.new(palette.accent)
	tail.LightEmission = 1
	tail.Size = NumberSequence.new({ kp(0, radius * 0.9), kp(1, 0) })
	tail.Lifetime = NumberRange.new(0.25, 0.4)
	tail.Rate = 40
	tail.Speed = NumberRange.new(2)
	tail.Texture = TEX_FIRE
	tail.Parent = ball
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, radius * 0.6, 0); a0.Parent = ball
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -radius * 0.6, 0); a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(palette.main)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = ball

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, fxFolder }

	table.insert(activeProjectiles, {
		part = ball, pos = origin, dir = dir, radius = radius,
		speed = def.speed or 110,
		maxDist = (def.speed or 110) * (def.life or 5),
		traveled = 0,
		def = def, char = char, player = player, palette = palette, params = params,
	})
	ensureTick()
	emit(origin, palette.accent, 6, 10, 0.5, 180, 0.3, TEX_SPARK)  -- muzzle pop
end

handlers.buff = function(char, root, def, player)
	local hum = getHumanoid(char)
	if not hum then return end
	local palette = paletteFor(def)
	local duration = def.duration or 5

	if def.stat == "walkSpeed" then
		applySpeedMult(char, "SpeedBuffMult", def.amount or 1.5, duration)
	elseif def.stat == "damageMult" and player then
		-- generation counter: overlapping uses refresh instead of restoring early
		local gen = (player:GetAttribute("DamageMultGen") or 0) + 1
		player:SetAttribute("DamageMultGen", gen)
		player:SetAttribute("DamageMult", def.amount or 1.5)
		task.delay(duration, function()
			if player.Parent and player:GetAttribute("DamageMultGen") == gen then
				player:SetAttribute("DamageMult", 1)
			end
		end)
	elseif def.stat == "heal" then
		hum.Health = math.min(hum.MaxHealth, hum.Health + (def.amount or 25))
	end

	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(palette.main)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ kp(0, 0.35), kp(1, 0) })
	aura.Lifetime = NumberRange.new(0.6, 1)
	aura.Speed = NumberRange.new(2, 4)
	aura.Rate = 14
	aura.SpreadAngle = Vector2.new(25, 25)
	aura.Parent = root
	Debris:AddItem(aura, def.stat == "heal" and 1.2 or duration)
	bloomSphere(root.Position, palette.main, 6, 0.3)
end

-- NEW: blink to the cursor (your old TeleportWarp visual, now a real ability)
handlers.teleport = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local maxRange = def.range or def.distance or 40
	local from = root.Position
	local target
	if not isBadVector(aim) then
		local offset = aim - from
		if offset.Magnitude > maxRange then aim = from + offset.Unit * maxRange end
		target = aim + Vector3.new(0, 3, 0)
	else
		target = from + root.CFrame.LookVector * maxRange
	end

	-- snap to the floor below the destination so you never blink into the ground
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, fxFolder }
	local down = workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), params)
	if down then target = down.Position + Vector3.new(0, 3, 0) end

	teleWarp(from, palette)
	local look = root.CFrame.LookVector
	root.CFrame = safeLookAt(target, target + Vector3.new(look.X, 0, look.Z))
	root.AssemblyLinearVelocity = Vector3.zero
	teleWarp(target, palette)

	if def.damage and def.damage > 0 then  -- optional exit burst
		local r = def.radius or 8
		forEachTarget(getHitboxParts(target, Vector3.new(r * 2, r * 2, r * 2), char), char, nil, function(model, hum, tRoot)
			damageModel(char, model, hum, tRoot, def.damage, def.knockback or 25, def.up, palette)
		end)
		shockwaveRing(groundBelow(target, char), palette.main, r, 0.35)
	end
	fxAll("teleport", { from = from, to = target, color = palette.main })
end

-- NEW: your old FrameSucker cage, rebuilt as a data-driven ability
handlers.vortex = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local radius = def.radius or 14
	local center
	if not isBadVector(aim) then
		local off = aim - root.Position
		if off.Magnitude > 60 then aim = root.Position + off.Unit * 60 end
		center = aim + Vector3.new(0, radius * 0.4, 0)
	else
		center = root.Position + root.CFrame.LookVector * 15 + Vector3.new(0, 4, 0)
	end

	-- the glowing cube cage (all 12 edges), palette-colored
	local parts = {}
	local side = radius * 1.4
	local h, t = side / 2, 0.3
	local function edge(sizeVec, offset)
		table.insert(parts, makePart({ Size = sizeVec, Color = palette.main, Transparency = 0.1, CFrame = CFrame.new(center + offset) }))
	end
	for _, y in ipairs({ -h, h }) do
		for _, z in ipairs({ -h, h }) do edge(Vector3.new(side, t, t), Vector3.new(0, y, z)) end
		for _, x in ipairs({ -h, h }) do edge(Vector3.new(t, t, side), Vector3.new(x, y, 0)) end
	end
	for _, x in ipairs({ -h, h }) do
		for _, z in ipairs({ -h, h }) do edge(Vector3.new(t, side, t), Vector3.new(x, 0, z)) end
	end
	local swirlHolder = makePart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(center) })
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(palette.accent)
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new({ kp(0, 1.2), kp(1, 0) })
	swirl.Lifetime = NumberRange.new(0.5, 0.9)
	swirl.Speed = NumberRange.new(radius * 0.8)
	swirl.SpreadAngle = Vector2.new(360, 360)
	swirl.Rate = 60
	swirl.Drag = 1
	swirl.Parent = swirlHolder
	table.insert(parts, swirlHolder)

	table.insert(activeVortexes, {
		center = center, radius = radius, parts = parts, char = char,
		pull = def.pull or 60,
		tickDamage = def.tickDamage, tickTimer = 0, tickRate = def.tickRate or 0.5,
		endTime = os.clock() + math.clamp(def.duration or 4, 1, 10),
	})
	ensureTick()
	fxAll("shake", { pos = center, intensity = 0.4, radius = radius + 40 })
end

-------------------------------------------------------------------
-- TICK STEPPERS
-------------------------------------------------------------------
stepProjectiles = function(dt)
	for i = #activeProjectiles, 1, -1 do
		local p = activeProjectiles[i]
		if not p.part.Parent then
			table.remove(activeProjectiles, i)
		else
			local stepDist = p.speed * dt
			-- Spherecast = the projectile's real radius does the hitting; nothing tunnels
			local result = workspace:Spherecast(p.pos, p.radius, p.dir * stepDist, p.params)
			if result then
				local hitPos = result.Position
				local seen = {}
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model ~= p.char then
					local hum = model:FindFirstChildOfClass("Humanoid")
					local hroot = model:FindFirstChild("HumanoidRootPart")
					if hum and hroot and hum.Health > 0 then
						seen[model] = true
						damageModel(p.char, model, hum, hroot, p.def.damage, p.def.knockback, p.def.up, p.palette)
					end
				end
				if p.def.splashRadius then
					local r = p.def.splashRadius
					forEachTarget(getHitboxParts(hitPos, Vector3.new(r * 2, r * 2, r * 2), p.char), p.char, seen, function(m, h, rt)
						damageModel(p.char, m, h, rt, (p.def.damage or 20) * 0.6, (p.def.knockback or 20) * 0.7, p.def.up, p.palette)
					end)
					shockwaveRing(groundBelow(hitPos), p.palette.main, r, 0.4)
				end
				impactFX(hitPos, p.palette, (p.def.damage or 0) >= 35 or p.def.splashRadius ~= nil)
				fxAll("shake", { pos = hitPos, intensity = p.def.splashRadius and 0.7 or 0.35, radius = 55 })
				p.part:Destroy()
				table.remove(activeProjectiles, i)
			else
				p.pos += p.dir * stepDist
				p.traveled += stepDist
				p.part.CFrame = safeLookAt(p.pos, p.pos + p.dir)
				if p.traveled >= p.maxDist then
					emit(p.pos, p.palette.accent, 6, 8, 0.5, 180, 0.3)
					p.part:Destroy()
					table.remove(activeProjectiles, i)
				end
			end
		end
	end
end

stepBeams = function(dt)
	for player, b in pairs(activeBeams) do
		local stop = false
		if not player.Parent or not b.char.Parent or b.hum.Health <= 0 then stop = true end
		if not stop and os.clock() > b.endTime then stop = true end

		if not stop then
			-- energy drain (Energy/MaxEnergy attributes are owned by AbilityManager)
			b.drainAcc += b.dps * dt
			if b.drainAcc >= 1 then
				local spend = math.floor(b.drainAcc)
				local e = player:GetAttribute("Energy") or 0
				if e < spend then
					stop = true
				else
					player:SetAttribute("Energy", e - spend)
					b.drainAcc -= spend
				end
			end
		end

		local origin
		if not stop then
			origin = (b.muzzleAtt.Parent and b.muzzleAtt.WorldPosition)
				or (b.root.Parent and b.root.Position)
			if not origin then stop = true end
		end

		if stop then
			AbilityEngine.stopBeam(player)
		else
			local fallback = b.root.CFrame.LookVector
			local dir = b.aim and aimDirection(origin, b.aim, fallback) or fallback
			local ray = workspace:Raycast(origin, dir * b.range, b.params)
			local endPos = ray and ray.Position or (origin + dir * b.range)

			local dist = (endPos - origin).Magnitude
			if dist > 0.5 then
				b.core.Size = Vector3.new(dist, 0.35, 0.35)
				b.core.CFrame = safeLookAt((origin + endPos) / 2, endPos) * CFrame.Angles(0, math.rad(90), 0)
			end
			b.tip.CFrame = CFrame.new(endPos)

			b.tickTimer -= dt
			if b.tickTimer <= 0 then
				b.tickTimer = b.tickRate
				local seen = {}
				if ray then
					local model = ray.Instance:FindFirstAncestorOfClass("Model")
					if model and model ~= b.char then
						local hum = model:FindFirstChildOfClass("Humanoid")
						local hroot = model:FindFirstChild("HumanoidRootPart")
						if hum and hroot and hum.Health > 0 then
							seen[model] = true
							damageModel(b.char, model, hum, hroot, b.def.tickDamage or 3, b.def.knockback or 0, 0, nil)
							if b.def.slowAmount then applySpeedMult(model, "SlowMult", b.def.slowAmount, b.def.slowDuration or 1) end
							emit(endPos, b.palette.main, 4, 10, 0.45, 180, 0.3, TEX_SPARK)
						end
					end
				end
				-- small splash at the endpoint so grazing hits still count
				forEachTarget(getHitboxParts(endPos, Vector3.new(6, 6, 6), b.char), b.char, seen, function(m, h, rt)
					damageModel(b.char, m, h, rt, (b.def.tickDamage or 3) * 0.5, 0, 0, nil)
					if b.def.slowAmount then applySpeedMult(m, "SlowMult", b.def.slowAmount, b.def.slowDuration or 1) end
				end)
				fxFor(player, "shake", { intensity = 0.06 })  -- subtle rumble for the shooter
			end
		end
	end
end

stepVortexes = function(dt)
	for i = #activeVortexes, 1, -1 do
		local v = activeVortexes[i]
		if os.clock() > v.endTime then
			for _, part in ipairs(v.parts) do
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				Debris:AddItem(part, 0.35)
			end
			table.remove(activeVortexes, i)
		else
			for _, plr in ipairs(Players:GetPlayers()) do
				local pchar = plr.Character
				if pchar and pchar ~= v.char then  -- the caster is immune to their own vortex
					local hrp = pchar:FindFirstChild("HumanoidRootPart")
					if hrp then
						local offset = v.center - hrp.Position
						if offset.Magnitude < v.radius then
							hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(offset.Unit * v.pull, 0.25)
						end
					end
				end
			end
			if v.tickDamage then
				v.tickTimer -= dt
				if v.tickTimer <= 0 then
					v.tickTimer = v.tickRate
					forEachTarget(getHitboxParts(v.center, Vector3.new(v.radius * 2, v.radius * 2, v.radius * 2), v.char), v.char, nil, function(m, h, rt)
						damageModel(v.char, m, h, rt, v.tickDamage, 0, 0, nil)
					end)
				end
			end
		end
	end
end

-------------------------------------------------------------------
-- PUBLIC: hold-to-fire beams (protocol used by InputClient via AbilityManager:
-- press slot -> startBeam, "BEAM_AIM" -> updateBeamAim, release -> "BEAM_STOP")
-------------------------------------------------------------------
function AbilityEngine.startBeam(player, char, def, aim)
	if activeBeams[player] then
		AbilityEngine.updateBeamAim(player, aim)
		return
	end
	local root, hum = getRoot(char), getHumanoid(char)
	if not root or not hum or hum.Health <= 0 then return end
	if (player:GetAttribute("Energy") or 0) < 5 then return end

	local palette = paletteFor(def)
	local muzzle = getMuzzle(char)

	local a0 = Instance.new("Attachment")
	a0.Name = "BeamMuzzle"
	a0.Parent = muzzle

	local tip = makePart({ Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1, CFrame = root.CFrame })
	local a1 = Instance.new("Attachment"); a1.Parent = tip

	-- layered: soft outer glow (Beam) + crisp neon core (cylinder) + tip sparks + light
	local glow = Instance.new("Beam")
	glow.Attachment0 = a0
	glow.Attachment1 = a1
	glow.Color = ColorSequence.new(palette.main)
	glow.Transparency = NumberSequence.new(0.35)
	glow.Width0 = 0.7
	glow.Width1 = 1.6
	glow.LightEmission = 1
	glow.FaceCamera = true
	glow.Segments = 1
	glow.Parent = tip

	local core = makePart({ Color = palette.accent, Transparency = 0.05, Size = Vector3.new(1, 0.35, 0.35), CFrame = root.CFrame })

	local tipEmit = Instance.new("ParticleEmitter")
	tipEmit.Color = ColorSequence.new(palette.main)
	tipEmit.LightEmission = 1
	tipEmit.Size = NumberSequence.new({ kp(0, 0.9), kp(1, 0) })
	tipEmit.Lifetime = NumberRange.new(0.2, 0.45)
	tipEmit.Speed = NumberRange.new(8, 18)
	tipEmit.SpreadAngle = Vector2.new(180, 180)
	tipEmit.Rate = 45
	tipEmit.Texture = TEX_SPARK
	tipEmit.Parent = tip
	local light = Instance.new("PointLight")
	light.Color = palette.main; light.Brightness = 3; light.Range = 16; light.Parent = tip

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, fxFolder }

	activeBeams[player] = {
		char = char, hum = hum, root = root, def = def, palette = palette,
		aim = (not isBadVector(aim)) and aim or nil,
		muzzleAtt = a0, tip = tip, core = core, params = params,
		tickTimer = 0, drainAcc = 0,
		dps = def.energyPerSecond or math.max((def.tickDamage or 3) * 2.5, 4),
		tickRate = def.tickRate or 0.25,
		range = def.range or 60,
		endTime = os.clock() + (def.maxDuration or 8),
	}
	ensureTick()
	fxAll("shake", { pos = root.Position, intensity = 0.25, radius = 45 })
end

function AbilityEngine.updateBeamAim(player, aim)
	local b = activeBeams[player]
	if b and not isBadVector(aim) then b.aim = aim end
end

function AbilityEngine.stopBeam(player)
	local b = activeBeams[player]
	if not b then return end
	activeBeams[player] = nil
	if b.muzzleAtt then b.muzzleAtt:Destroy() end
	if b.core then b.core:Destroy() end
	if b.tip then b.tip:Destroy() end   -- glow Beam, tip emitter and light are its children
end

-- call on PlayerRemoving so nothing owned by a leaving player keeps running
function AbilityEngine.cleanupPlayer(player)
	AbilityEngine.stopBeam(player)
end

-------------------------------------------------------------------
-- PUBLIC: run an ability definition
-- aim = Vector3 world position under the caster's cursor (optional; validated)
-------------------------------------------------------------------
function AbilityEngine.run(player, char, def, aim)
	if not def then return end
	local root = getRoot(char)
	if not root then return end
	local h = handlers[def.type]
	if h then
		h(char, root, def, player, aim)
	else
		warn("AbilityEngine: unknown ability type '" .. tostring(def.type) .. "'")
	end
end

--[[
	OPTIONAL DEF FIELDS (all optional -- every existing definition keeps working):
	  any type:    color = Color3 (overrides the palette),
	               style = "energy"|"fire"|"ice"|"shadow"|"cosmic"|"physical"|"nature"
	  projectile:  speed, life, size = Vector3, splashRadius (AoE on impact @60% damage)
	  beam:        tickDamage, tickRate (0.25), range (60), maxDuration (8),
	               energyPerSecond, slowAmount (0.45 = targets move at 45% speed), slowDuration
	  teleport:    range (or distance), plus damage + radius for an optional exit burst
	  vortex:      radius (14), duration (4), pull (60), tickDamage, tickRate (0.5)
	  buff:        stat = "walkSpeed"|"damageMult"|"heal", amount, duration
]]

return AbilityEngine
