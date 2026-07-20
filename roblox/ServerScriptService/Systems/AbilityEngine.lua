--[[
	AbilityEngine  (ModuleScript)
	WHERE IT GOES: ServerScriptService > Systems > AbilityEngine  (replace the old contents)

	The ONE place that knows how to PERFORM abilities. It reads an ability
	"definition" (a table from MasteryData / CharacterData / CharacterKits /
	construct kits) and runs it with server-authoritative hit detection plus
	layered VFX. You never touch this to add characters -- you only add data.

	ABILITY TYPES:
	  melee, aoe, dash, projectile, buff, beam, teleport, vortex   (core)
	  barrage   - burst of projectiles with spread (gatling, missiles, shuriken)
	  shield    - force field around the caster (block %, untouchable, damage
	              aura, slow aura, radial burst when it ends)
	  wall      - solid barrier / pillars that block movement and shots
	  zone      - persistent ground area (spike field, poison cloud, radiation,
	              darkness dome, slow/time field, heal or regen field)
	  strike    - telegraphed sky attack at the cursor (meteor, mortar, comet,
	              orbital laser, water smash-down)
	  chain     - lightning that arcs between targets
	  bind      - chains/grab/cage: roots and stuns targets in place
	  force     - radial gravity pull or push (EMP, air cannon, magnetism)
	  tendrils  - tentacles from the ground or the caster's back that lash
	              nearby enemies (vines, roots, shadow tendrils, ground hands)
	  breath    - cone channel (flamethrower, ice breath, water jet, acid,
	              sonic scream)
	  slam      - ground slam, optionally with a leap (dive bomb, mega stomp)
	  clones    - decoy copies of the caster that enemies can hit
	  turret    - summoned sentry that shoots the nearest enemy (mech, drone)
	  counter   - parry stance: the next hit is reflected back at the attacker
	  phase     - brief intangibility/invisibility (dodge phase, energy state)

	UNIVERSAL OPTIONAL FIELDS (work on any damaging type):
	  stunDuration  - roots + disables jump on hit
	  dotDamage / dotDuration - burn/poison damage over time after the hit
	  lifesteal     - fraction of damage healed back to the caster
	  color / style - VFX palette ("energy","fire","ice","shadow","cosmic",
	                  "physical","nature"); keywords in name/styleKey auto-pick
	Per-type extras are documented next to each handler and in CharacterKits.

	VFX: the server builds the replicated core (projectiles, beams, rings,
	blooms, cages, tentacles); the AbilityVFXClient LocalScript adds camera
	shake, flashes, debris, dust and cracks via the auto-created "AbilityFX"
	RemoteEvent. Everything still works if that LocalScript is missing.
]]

local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityEngine = {}
local rng = Random.new()

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

-- pure-cosmetic parts live here; raycasts and hitboxes ignore this folder
local fxFolder = workspace:FindFirstChild("AbilityFXParts")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "AbilityFXParts"
	fxFolder.Parent = workspace
end
-- gameplay-relevant summons (walls, clones) live here so shots DO hit them
local structFolder = workspace:FindFirstChild("AbilityStructures")
if not structFolder then
	structFolder = Instance.new("Folder")
	structFolder.Name = "AbilityStructures"
	structFolder.Parent = workspace
end

-- guaranteed built-in textures (no uploads needed, can never fail to load)
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FIRE  = "rbxasset://textures/particles/fire_main.dds"

-------------------------------------------------------------------
-- STYLE PALETTES
-------------------------------------------------------------------
local PALETTES = {
	energy   = { main = Color3.fromRGB( 60, 180, 255), accent = Color3.fromRGB(190, 235, 255) },
	physical = { main = Color3.fromRGB(255, 170,  70), accent = Color3.fromRGB(255, 225, 170) },
	shadow   = { main = Color3.fromRGB(140,  40, 255), accent = Color3.fromRGB( 80,   0, 160) },
	cosmic   = { main = Color3.fromRGB(255, 225, 120), accent = Color3.fromRGB(200, 140, 255) },
	fire     = { main = Color3.fromRGB(255, 110,  40), accent = Color3.fromRGB(255, 215, 120) },
	ice      = { main = Color3.fromRGB(150, 220, 255), accent = Color3.fromRGB(235, 250, 255) },
	nature   = { main = Color3.fromRGB(110, 230, 120), accent = Color3.fromRGB(220, 255, 200) },
	water    = { main = Color3.fromRGB( 40, 130, 235), accent = Color3.fromRGB(170, 220, 255) },
	gold     = { main = Color3.fromRGB(255, 200,  40), accent = Color3.fromRGB(255, 245, 190) },
	storm    = { main = Color3.fromRGB(255, 250, 140), accent = Color3.fromRGB(170, 190, 255) },
}
local KEYWORDS = {
	{ words = { "ice", "frost", "freez", "snow", "cryo", "zero" },        key = "ice" },
	{ words = { "fire", "flame", "ember", "burn", "magma", "lava" },      key = "fire" },
	{ words = { "shadow", "void", "dark", "curse", "grim", "night" },     key = "shadow" },
	{ words = { "god", "cosmic", "star", "divine", "omega" },             key = "cosmic" },
	{ words = { "gold", "holy", "chain" },                                key = "gold" },
	{ words = { "rock", "stone", "earth", "titan", "onix" },              key = "physical" },
	{ words = { "toxic", "venom", "nature", "leaf", "acid", "radiat" },   key = "nature" },
	{ words = { "water", "tide", "wave", "sea", "aqua" },                 key = "water" },
	{ words = { "storm", "volt", "lightning", "thunder", "electr", "emp" }, key = "storm" },
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
local function flatDir(dir, fallback)
	local f = Vector3.new(dir.X, 0, dir.Z)
	return f.Magnitude > 0.01 and f.Unit or fallback
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
-- clamp a cursor point to a max range from the caster
local function clampAim(from, aim, maxRange)
	if isBadVector(aim) then return nil end
	local off = aim - from
	if off.Magnitude > maxRange then return from + off.Unit * maxRange end
	return aim
end

-------------------------------------------------------------------
-- VFX BUILDING BLOCKS (server side, replicated to everyone)
-------------------------------------------------------------------
local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false      -- raycasts/hitboxes automatically ignore FX
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or fxFolder
	return p
end

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

-- the full layered explosion look, shared by aoe / strike / slam / vortex-end
local function blastFX(pos, palette, radius, power, ignoreChar)
	local ground = groundBelow(pos, ignoreChar)
	bloomSphere(pos, palette.main, radius * 0.9, 0.35)
	shockwaveRing(ground, palette.main, radius * 1.15, 0.5)
	shockwaveRing(ground, palette.accent, radius * 0.7, 0.35)
	emit(pos, palette.main, 26, radius * 1.6, 1.4, 180, 0.6, TEX_FIRE)
	emit(ground, Color3.fromRGB(120, 110, 100), 18, radius, 2.4, 80, 1.1, TEX_SMOKE)
	fxAll("blast", { pos = ground, color = palette.main, radius = radius, power = power })
end

-- jagged lightning bolt between two points
local function boltFX(a, b, color)
	local prev = a
	local segs = 3
	for i = 1, segs do
		local target = a:Lerp(b, i / segs)
		if i < segs then
			target += Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5))
		end
		local d = (target - prev).Magnitude
		if d > 0.1 then
			local seg = makePart({ Color = color, Size = Vector3.new(0.25, 0.25, d), CFrame = safeLookAt((prev + target) / 2, target) })
			TweenService:Create(seg, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			Debris:AddItem(seg, 0.25)
		end
		prev = target
	end
	bloomSphere(b, color, 3, 0.2)
end

-------------------------------------------------------------------
-- SPEED / STATUS MODEL
-- WalkSpeed = BaseWalkSpeed * SpeedBuffMult * SlowMult * StunMult
-- (character attributes, generation counters -> overlaps refresh cleanly)
-------------------------------------------------------------------
local function refreshSpeed(char)
	local hum = getHumanoid(char)
	if not hum then return end
	local base = char:GetAttribute("BaseWalkSpeed")
	if not base then
		base = hum.WalkSpeed
		char:SetAttribute("BaseWalkSpeed", base)
	end
	hum.WalkSpeed = base * (char:GetAttribute("SpeedBuffMult") or 1)
		* (char:GetAttribute("SlowMult") or 1) * (char:GetAttribute("StunMult") or 1)
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

-- full root: no walking, no jumping, "Stunned" attribute for other systems
local function applyStun(char, duration)
	local hum = getHumanoid(char)
	if not hum then return end
	if char:GetAttribute("BaseJumpPower") == nil then
		char:SetAttribute("BaseJumpPower", hum.JumpPower)
		char:SetAttribute("BaseJumpHeight", hum.JumpHeight)
	end
	local gen = (char:GetAttribute("StunGen") or 0) + 1
	char:SetAttribute("StunGen", gen)
	char:SetAttribute("Stunned", true)
	hum.JumpPower = 0
	hum.JumpHeight = 0
	applySpeedMult(char, "StunMult", 0, duration + 0.05)
	local root = getRoot(char)
	if root then emit(root.Position + Vector3.new(0, 3.2, 0), Color3.fromRGB(255, 230, 90), 8, 6, 0.45, 180, math.min(duration, 1)) end
	task.delay(duration, function()
		if char.Parent and char:GetAttribute("StunGen") == gen then
			char:SetAttribute("Stunned", nil)
			local h = getHumanoid(char)
			if h then
				h.JumpPower = char:GetAttribute("BaseJumpPower") or 50
				h.JumpHeight = char:GetAttribute("BaseJumpHeight") or 7.2
			end
		end
	end)
end

-- burn/poison over time (refreshes instead of stacking infinitely)
local function applyDot(char, hum, dps, duration, color)
	local gen = (char:GetAttribute("DotGen") or 0) + 1
	char:SetAttribute("DotGen", gen)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			task.wait(0.5)
			elapsed += 0.5
			if not char.Parent or char:GetAttribute("DotGen") ~= gen or hum.Health <= 0 then return end
			hum:TakeDamage(dps * 0.5)
			local root = getRoot(char)
			if root then emit(root.Position, color or Color3.fromRGB(255, 120, 40), 4, 6, 0.5, 120, 0.35, TEX_FIRE) end
		end
	end)
end

-- ShieldBlock attribute: fraction of incoming damage blocked (1 = untouchable)
local function setShieldBlock(char, fraction, duration)
	local gen = (char:GetAttribute("ShieldBlockGen") or 0) + 1
	char:SetAttribute("ShieldBlockGen", gen)
	char:SetAttribute("ShieldBlock", fraction)
	task.delay(duration, function()
		if char.Parent and char:GetAttribute("ShieldBlockGen") == gen then
			char:SetAttribute("ShieldBlock", nil)
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

-- Dedupe: a character is damaged ONCE per swing no matter how many limbs are
-- inside the box. Your own decoy clones are never valid targets for you.
local function forEachTarget(parts, attackerChar, seen, fn)
	seen = seen or {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= attackerChar and not seen[model]
			and not (attackerChar and model:GetAttribute("CloneOwner") == attackerChar.Name) then
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

local function nearestTarget(fromPos, range, attackerChar, alreadyHit)
	local best, bestHum, bestRoot, bestDist
	forEachTarget(getHitboxParts(fromPos, Vector3.new(range * 2, range * 2, range * 2), attackerChar), attackerChar, nil, function(m, h, r)
		if alreadyHit and alreadyHit[m] then return end
		local d = (r.Position - fromPos).Magnitude
		if d <= range and (not bestDist or d < bestDist) then
			best, bestHum, bestRoot, bestDist = m, h, r, d
		end
	end)
	return best, bestHum, bestRoot
end

-- first target along the caster's aim line (grabs, chains, binds)
local function findTargetAlongAim(char, root, aim, range)
	local dir = aimDirection(root.Position + Vector3.new(0, 1, 0), aim, root.CFrame.LookVector)
	for d = 6, range, 6 do
		local fm, fh, fr
		forEachTarget(getHitboxParts(root.Position + dir * d, Vector3.new(8, 8, 8), char), char, nil, function(m, h, r)
			fm, fh, fr = fm or m, fh or h, fr or r
		end)
		if fm then return fm, fh, fr end
	end
	return nil
end

-- Central damage: COUNTER > SHIELD > BLOCK > TRUE GOLD/SILVER, knockback, FX.
-- Returns the target Player (if any) so callers can hook XP drops.
local function damageModel(attackerChar, model, hum, root, damage, knockback, up, palette)
	damage = damage or 0
	knockback = knockback or 0

	-- COUNTER stance: reflect the hit back at the attacker instead
	local counterUntil = model:GetAttribute("CounterUntil")
	if counterUntil and os.clock() < counterUntil and attackerChar and damage > 0 then
		model:SetAttribute("CounterUntil", 0)
		local aHum, aRoot = getHumanoid(attackerChar), getRoot(attackerChar)
		if aHum and aHum.Health > 0 then
			aHum:TakeDamage(damage * (model:GetAttribute("CounterReflect") or 1))
			if aRoot then impactFX(aRoot.Position, { main = Color3.new(1, 1, 1), accent = Color3.fromRGB(255, 240, 180) }, true) end
		end
		bloomSphere(root.Position, Color3.new(1, 1, 1), 7, 0.25)
		fxAll("shake", { pos = root.Position, intensity = 0.4, radius = 45 })
		return Players:GetPlayerFromCharacter(model)
	end

	-- ability SHIELD (force fields / phase): fraction blocked, 1 = untouchable
	local shieldBlock = model:GetAttribute("ShieldBlock")
	if shieldBlock then
		if shieldBlock >= 1 then
			emit(root.Position, Color3.fromRGB(200, 240, 255), 6, 10, 0.5, 180, 0.3, TEX_SPARK)
			return Players:GetPlayerFromCharacter(model)
		end
		damage = damage * (1 - shieldBlock)
		knockback = knockback * (1 - shieldBlock)
	end

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

-- def-aware hit: damage + knockback + stun + burn/poison DoT + lifesteal.
-- percentDamage adds a fraction of the target's CURRENT health on top
-- (Nejhora's 90% drain, Apocalypso's death touch) - still reducible by
-- shields/blocking/forms like any other damage.
local function hitTarget(attackerChar, model, hum, root, def, dmg, palette)
	if def.percentDamage then
		dmg = (dmg or 0) + hum.Health * def.percentDamage
	end
	local tp = damageModel(attackerChar, model, hum, root, dmg, def.knockback, def.up, palette)
	if hum.Health > 0 then
		if def.stunDuration then applyStun(model, def.stunDuration) end
		if def.dotDamage then applyDot(model, hum, def.dotDamage, def.dotDuration or 3, palette and palette.main) end
	end
	if def.lifesteal and dmg and dmg > 0 then
		local aHum = getHumanoid(attackerChar)
		if aHum and aHum.Health > 0 then
			aHum.Health = math.min(aHum.MaxHealth, aHum.Health + dmg * def.lifesteal)
		end
	end
	return tp
end

-------------------------------------------------------------------
-- SHARED TICK
-- One Heartbeat connection drives every live projectile, beam, vortex,
-- zone, breath, turret and tendril set; disconnects when idle.
-------------------------------------------------------------------
local activeProjectiles = {}
local activeBeams = {}      -- player -> beam state
local activeVortexes = {}
local activeZones = {}
local activeBreaths = {}
local activeTurrets = {}
local activeTendrils = {}
local stepProjectiles, stepBeams, stepVortexes, stepZones, stepBreaths, stepTurrets, stepTendrils
local tickConn = nil

local function anyActive()
	return #activeProjectiles > 0 or next(activeBeams) ~= nil or #activeVortexes > 0
		or #activeZones > 0 or #activeBreaths > 0 or #activeTurrets > 0 or #activeTendrils > 0
end
local function ensureTick()
	if tickConn then return end
	tickConn = RunService.Heartbeat:Connect(function(dt)
		stepProjectiles(dt)
		stepBeams(dt)
		stepVortexes(dt)
		stepZones(dt)
		stepBreaths(dt)
		stepTurrets(dt)
		stepTendrils(dt)
		if not anyActive() then
			tickConn:Disconnect()
			tickConn = nil
		end
	end)
end

-------------------------------------------------------------------
-- PROJECTILE CORE (used by projectile, barrage, shield bursts, turrets)
-------------------------------------------------------------------
local function spawnProjectileRaw(char, player, def, palette, origin, dir)
	local size = typeof(def.size) == "Vector3" and def.size or Vector3.new(2.4, 2.4, 2.4)
	local radius = math.max(size.X, size.Y, size.Z) * 0.5

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
end

-------------------------------------------------------------------
-- ABILITY TYPE HANDLERS
-------------------------------------------------------------------
local handlers = {}

-- melee extras: hits (flurry count), hitInterval
handlers.melee = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local hits = def.hits or 1
	local function swing()
		local r = getRoot(char)
		if not r then return end
		local range = def.range or 5
		local size = def.size or Vector3.new(7, 7, 7)
		local dir = flatDir(aimDirection(r.Position, aim, r.CFrame.LookVector), r.CFrame.LookVector)
		local center = r.Position + dir * range

		local hitAny = false
		forEachTarget(getHitboxParts(safeLookAt(center, center + dir), size, char), char, nil, function(model, hum, tRoot)
			hitAny = true
			hitTarget(char, model, hum, tRoot, def, def.damage, palette)
		end)

		local arc = makePart({
			Size = Vector3.new(range + 3, 0.25, 1.6),
			Color = palette.main,
			Transparency = 0.1,
			CFrame = safeLookAt(r.Position + dir * (range * 0.5) + Vector3.new(0, 0.5, 0), center)
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
	if hits <= 1 then
		swing()
	else
		task.spawn(function()
			for _ = 1, hits do
				if not char.Parent then return end
				swing()
				task.wait(def.hitInterval or 0.14)
			end
		end)
	end
end

handlers.aoe = function(char, root, def, player)
	local palette = paletteFor(def)
	local radius = def.radius or 20
	local size = Vector3.new(radius * 2, def.height or 12, radius * 2)
	forEachTarget(getHitboxParts(root.Position, size, char), char, nil, function(model, hum, tRoot)
		hitTarget(char, model, hum, tRoot, def, def.damage, palette)
	end)
	local power = math.clamp((def.damage or 25) / 50 + radius / 40, 0.4, 1.6)
	blastFX(root.Position, palette, radius, power, char)
end

handlers.dash = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local dir = flatDir(aimDirection(root.Position, aim, root.CFrame.LookVector), root.CFrame.LookVector)
	local from = root.Position
	local distance = def.distance or 0

	if distance > 0 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, fxFolder }
		local hit = workspace:Raycast(from, dir * distance, params)
		if hit then distance = math.max((hit.Position - from).Magnitude - 2.5, 0) end

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
		local seen = {}
		for d = 0, math.max(distance, 0.1), 6 do
			forEachTarget(getHitboxParts(from + dir * d, Vector3.new(9, 8, 9), char), char, seen, function(model, hum, tRoot)
				hitTarget(char, model, hum, tRoot, def, def.damage, palette)
			end)
		end
		forEachTarget(getHitboxParts(root.Position, Vector3.new(9, 8, 9), char), char, seen, function(model, hum, tRoot)
			hitTarget(char, model, hum, tRoot, def, def.damage, palette)
		end)
	end
end

-- projectile extras: splashRadius, rampPer (damage grows with distance flown),
-- stunEvery (every Nth hit stuns, e.g. Looney's finger gun)
handlers.projectile = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local origin = root.Position + Vector3.new(0, 0.8, 0)
	local dir = aimDirection(origin, aim, root.CFrame.LookVector)
	origin += dir * 3
	spawnProjectileRaw(char, player, def, palette, origin, dir)
	emit(origin, palette.accent, 6, 10, 0.5, 180, 0.3, TEX_SPARK)
end

-- barrage extras: count, interval, spread (degrees)
handlers.barrage = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local count = def.count or 5
	local interval = def.interval or 0.1
	local spread = math.rad(def.spread or 6)
	task.spawn(function()
		for _ = 1, count do
			local r = getRoot(char)
			local hum = getHumanoid(char)
			if not r or not hum or hum.Health <= 0 then return end
			local origin = r.Position + Vector3.new(0, 0.8, 0)
			local base = aimDirection(origin, aim, r.CFrame.LookVector)
			local right = base:Cross(Vector3.yAxis)
			right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
			local upv = right:Cross(base).Unit
			local dir = (base + right * rng:NextNumber(-spread, spread) + upv * rng:NextNumber(-spread, spread)).Unit
			spawnProjectileRaw(char, player, def, palette, origin + dir * 3, dir)
			emit(origin + dir * 3, palette.accent, 3, 8, 0.4, 160, 0.2, TEX_SPARK)
			task.wait(interval)
		end
	end)
end

handlers.buff = function(char, root, def, player)
	local hum = getHumanoid(char)
	if not hum then return end
	local palette = paletteFor(def)
	local duration = def.duration or 5

	if def.stat == "walkSpeed" then
		applySpeedMult(char, "SpeedBuffMult", def.amount or 1.5, duration)
	elseif def.stat == "damageMult" and player then
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

-- teleport extras: damage + radius = exit burst (teleport strike)
handlers.teleport = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local maxRange = def.range or def.distance or 40
	local from = root.Position
	local target
	local clamped = clampAim(from, aim, maxRange)
	if clamped then
		target = clamped + Vector3.new(0, 3, 0)
	else
		target = from + root.CFrame.LookVector * maxRange
	end

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

	if def.damage and def.damage > 0 then
		local r = def.radius or 8
		forEachTarget(getHitboxParts(target, Vector3.new(r * 2, r * 2, r * 2), char), char, nil, function(model, hum, tRoot)
			hitTarget(char, model, hum, tRoot, def, def.damage, palette)
		end)
		shockwaveRing(groundBelow(target, char), palette.main, r, 0.35)
	end
	fxAll("teleport", { from = from, to = target, color = palette.main })
end

-- vortex extras: endDamage/endRadius/endKnockback = black hole explosion
handlers.vortex = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local radius = def.radius or 14
	local center
	local clamped = clampAim(root.Position, aim, 60)
	if clamped then
		center = clamped + Vector3.new(0, radius * 0.4, 0)
	else
		center = root.Position + root.CFrame.LookVector * 15 + Vector3.new(0, 4, 0)
	end

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
		center = center, radius = radius, parts = parts, char = char, palette = palette, def = def,
		pull = def.pull or 60,
		tickDamage = def.tickDamage, tickTimer = 0, tickRate = def.tickRate or 0.5,
		endTime = os.clock() + math.clamp(def.duration or 4, 1, 10),
	})
	ensureTick()
	fxAll("shake", { pos = center, intensity = 0.4, radius = radius + 40 })
end

-- shield extras: block (fraction, default 0.7), untouchable, radius, duration,
-- auraDamage/auraRate, auraSlow, burst = {count,damage,speed} radial shots on end
handlers.shield = function(char, root, def, player)
	local palette = paletteFor(def)
	local duration = def.duration or 6
	local radius = def.radius or 8

	setShieldBlock(char, def.untouchable and 1 or (def.block or 0.7), duration)

	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Material = Enum.Material.ForceField
	sphere.Color = palette.main
	sphere.Transparency = 0.25
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.CanCollide = false; sphere.CanQuery = false; sphere.CanTouch = false
	sphere.Massless = true
	sphere.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = sphere; weld.Part1 = root; weld.Parent = sphere
	sphere.Parent = fxFolder
	Debris:AddItem(sphere, duration)
	bloomSphere(root.Position, palette.main, radius * 1.6, 0.35)

	if def.auraDamage or def.auraSlow then
		table.insert(activeZones, {
			followRoot = root, ownerChar = char, ownerPlayer = player, palette = palette,
			radius = radius + 4, tickDamage = def.auraDamage, slowAmount = def.auraSlow,
			tickRate = def.auraRate or 0.6, tickTimer = 0, def = def,
			endTime = os.clock() + duration, parts = {},
		})
		ensureTick()
	end

	if def.burst then
		task.delay(duration, function()
			local r = getRoot(char)
			if not r then return end
			local b = def.burst
			local count = b.count or 8
			for i = 1, count do
				local ang = (i / count) * math.pi * 2
				local dir = Vector3.new(math.cos(ang), 0.05, math.sin(ang)).Unit
				spawnProjectileRaw(char, player, {
					damage = b.damage or 10, speed = b.speed or 90, knockback = b.knockback or 25,
					size = Vector3.new(1.4, 1.4, 1.4), life = 2,
					slowAmount = b.slowAmount, stunDuration = b.stunDuration, dotDamage = b.dotDamage,
				}, palette, r.Position + dir * 3, dir)
			end
			shockwaveRing(groundBelow(r.Position, char), palette.main, radius * 2, 0.4)
			if b.push then
				forEachTarget(getHitboxParts(r.Position, Vector3.new(60, 24, 60), char), char, nil, function(m, h, tr)
					local d = flatDir(tr.Position - r.Position, r.CFrame.LookVector)
					tr.AssemblyLinearVelocity = d * b.push + Vector3.new(0, 25, 0)
					if b.damage then damageModel(char, m, h, tr, b.damage, 0, 0, palette) end
				end)
			end
		end)
	end
end

-- wall extras: width, height, thickness, duration, pillars (count -> pillar arc)
handlers.wall = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local dir = flatDir(aimDirection(root.Position, aim, root.CFrame.LookVector), root.CFrame.LookVector)
	local basePos = clampAim(root.Position, aim, 40) or (root.Position + dir * 9)
	basePos = groundBelow(basePos, char)
	local width = def.width or 14
	local height = def.height or 9
	local thick = def.thickness or 2.5
	local duration = def.duration or 8

	local function riseBlock(size, cf)
		local block = Instance.new("Part")
		block.Anchored = true
		block.CanCollide = true         -- blocks movement AND (CanQuery) beams/projectiles
		block.Material = def.material or Enum.Material.Glass
		block.Color = palette.main
		block.Transparency = 0.25
		block.Size = size
		block.CFrame = cf * CFrame.new(0, -size.Y, 0)
		block.Parent = structFolder
		TweenService:Create(block, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = cf }):Play()
		task.delay(duration, function()
			if block.Parent then
				TweenService:Create(block, TweenInfo.new(0.4), { Transparency = 1, CFrame = cf * CFrame.new(0, -size.Y, 0) }):Play()
				Debris:AddItem(block, 0.45)
			end
		end)
		emit(cf.Position - Vector3.new(0, size.Y / 2, 0), Color3.fromRGB(130, 120, 110), 10, 8, 1.4, 70, 0.8, TEX_SMOKE)
		return block
	end

	if def.pillars then
		local count = def.pillars
		for i = 1, count do
			local ang = ((i - 0.5) / count - 0.5) * math.rad(120)
			local pdir = (CFrame.fromAxisAngle(Vector3.yAxis, ang) * dir)
			local pos = groundBelow(basePos + pdir * (def.spacing or 6) * (i % 2 == 0 and 1.4 or 0.7), char)
			riseBlock(Vector3.new(3, height + rng:NextNumber(-1, 2), 3), safeLookAt(pos + Vector3.new(0, height / 2, 0), pos + Vector3.new(0, height / 2, 0) + pdir))
		end
	else
		local cf = safeLookAt(basePos + Vector3.new(0, height / 2, 0), basePos + Vector3.new(0, height / 2, 0) + dir)
		riseBlock(Vector3.new(width, height, thick), cf)
	end
	fxAll("shake", { pos = basePos, intensity = 0.3, radius = 40 })
end

-- zone extras: radius, duration, tickDamage, tickRate, slowAmount, healPerTick,
-- pull (whirlpool), atSelf (center on caster instead of cursor)
handlers.zone = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local radius = def.radius or 14
	local duration = math.clamp(def.duration or 6, 1, 20)
	local center
	if def.atSelf then
		center = root.Position
	else
		center = clampAim(root.Position, aim, 50) or (root.Position + root.CFrame.LookVector * 12)
	end
	center = groundBelow(center, char)

	local disc = makePart({
		Shape = Enum.PartType.Cylinder,
		Color = palette.main,
		Transparency = 0.65,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local field = makePart({ Size = Vector3.new(radius * 2, 1, radius * 2), Transparency = 1, CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) })
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(palette.accent)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ kp(0, 0.5), kp(1, 0) })
	motes.Lifetime = NumberRange.new(0.8, 1.4)
	motes.Speed = NumberRange.new(2, 4)
	motes.Rate = math.clamp(radius * 1.5, 10, 40)
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Parent = field

	table.insert(activeZones, {
		center = center, radius = radius, ownerChar = char, ownerPlayer = player, palette = palette,
		tickDamage = def.tickDamage, slowAmount = def.slowAmount, healPerTick = def.healPerTick,
		pull = def.pull, tickRate = def.tickRate or 0.5, tickTimer = 0, def = def,
		endTime = os.clock() + duration, parts = { disc, field },
	})
	ensureTick()
	shockwaveRing(center, palette.main, radius, 0.4)
end

-- strike extras: count, delay (telegraph), interval, spreadRadius, radius,
-- mode = "meteor" (default) | "laser" (instant sky beam)
handlers.strike = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local count = def.count or 1
	local radius = def.radius or 10
	local targetPos = clampAim(root.Position, aim, 70) or (root.Position + root.CFrame.LookVector * 25)
	targetPos = groundBelow(targetPos, char)

	for i = 1, count do
		task.delay((i - 1) * (def.interval or 0.35), function()
			local pos = targetPos
			if i > 1 or def.spreadRadius then
				local spreadR = def.spreadRadius or radius
				local ang = rng:NextNumber(0, math.pi * 2)
				pos = groundBelow(targetPos + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(0, spreadR), char)
			end
			-- telegraph ring so targets get a beat to react
			local warn = makePart({
				Shape = Enum.PartType.Cylinder, Color = palette.main, Transparency = 0.5,
				Size = Vector3.new(0.25, radius * 2, radius * 2),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			})
			TweenService:Create(warn, TweenInfo.new(def.delay or 0.9), { Transparency = 0.15 }):Play()
			Debris:AddItem(warn, (def.delay or 0.9) + 0.05)

			task.delay(def.delay or 0.9, function()
				if def.mode == "laser" then
					local column = makePart({ Color = palette.accent, Transparency = 0.1, Size = Vector3.new(radius * 0.7, 160, radius * 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 80, 0)) })
					TweenService:Create(column, TweenInfo.new(0.35), { Size = Vector3.new(0.5, 160, 0.5), Transparency = 1 }):Play()
					Debris:AddItem(column, 0.4)
				else
					local meteor = makePart({ Shape = Enum.PartType.Ball, Color = palette.main, Size = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-8, 8), 55, rng:NextNumber(-8, 8))) })
					local mt = Instance.new("ParticleEmitter")
					mt.Color = ColorSequence.new(palette.accent); mt.LightEmission = 1
					mt.Size = NumberSequence.new({ kp(0, radius * 0.3), kp(1, 0) })
					mt.Lifetime = NumberRange.new(0.3, 0.5); mt.Rate = 60; mt.Texture = TEX_FIRE
					mt.Parent = meteor
					TweenService:Create(meteor, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos) }):Play()
					Debris:AddItem(meteor, 0.3)
				end
				task.delay(def.mode == "laser" and 0.05 or 0.22, function()
					forEachTarget(getHitboxParts(pos, Vector3.new(radius * 2, math.max(radius, 12), radius * 2), char), char, nil, function(m, h, r)
						hitTarget(char, m, h, r, def, def.damage, palette)
					end)
					blastFX(pos, palette, radius, math.clamp((def.damage or 30) / 45, 0.5, 1.5), char)
				end)
			end)
		end)
	end
end

-- chain extras: jumps, jumpRange, falloff, range (to first target)
handlers.chain = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local model, hum, tRoot = findTargetAlongAim(char, root, aim, def.range or 40)
	if not model then
		-- whiff: show the bolt anyway so it feels responsive
		local dir = aimDirection(root.Position, aim, root.CFrame.LookVector)
		boltFX(root.Position + Vector3.new(0, 1.5, 0), root.Position + dir * (def.range or 40) * 0.5, palette.main)
		return
	end
	local dmg = def.damage or 18
	local hitSet = {}
	local fromPos = root.Position + Vector3.new(0, 1.5, 0)
	local jumps = def.jumps or 4
	for _ = 1, jumps do
		hitSet[model] = true
		boltFX(fromPos, tRoot.Position, palette.main)
		hitTarget(char, model, hum, tRoot, def, dmg, palette)
		fxAll("shake", { pos = tRoot.Position, intensity = 0.25, radius = 35 })
		fromPos = tRoot.Position
		dmg = dmg * (def.falloff or 0.85)
		model, hum, tRoot = nearestTarget(fromPos, def.jumpRange or 18, char, hitSet)
		if not model then break end
	end
end

-- bind extras: duration, damage, dps, radius (cage everyone in radius instead
-- of one grabbed target), launchUp (fling skyward when the bind ends)
handlers.bind = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local duration = math.clamp(def.duration or 2, 0.5, 8)

	local function bindOne(model, hum, tRoot)
		applyStun(model, duration)
		if def.damage then hitTarget(char, model, hum, tRoot, { knockback = 0 }, def.damage, palette) end
		if def.dps then
			task.spawn(function()
				local elapsed = 0
				while elapsed < duration do
					task.wait(0.5)
					elapsed += 0.5
					if not model.Parent or hum.Health <= 0 then return end
					damageModel(char, model, hum, tRoot, def.dps * 0.5, 0, 0, nil)
				end
			end)
		end
		-- shackle visual: glyph + chain bars around the target
		local glyph = makePart({
			Shape = Enum.PartType.Cylinder, Color = palette.main, Transparency = 0.4,
			Size = Vector3.new(0.25, 8, 8),
			CFrame = CFrame.new(groundBelow(tRoot.Position, model)) * CFrame.Angles(0, 0, math.rad(90)),
		})
		Debris:AddItem(glyph, duration)
		for i = 1, 4 do
			local ang = (i / 4) * math.pi * 2
			local off = Vector3.new(math.cos(ang), 0, math.sin(ang)) * 2.2
			local bar = makePart({ Color = palette.main, Transparency = 0.15, Size = Vector3.new(0.45, 6.5, 0.45), CFrame = CFrame.new(tRoot.Position + off) * CFrame.Angles(0, ang, math.rad(12)) })
			Debris:AddItem(bar, duration)
		end
		emit(tRoot.Position, palette.accent, 12, 12, 0.6, 180, 0.4, TEX_SPARK)
		if def.launchUp then
			task.delay(duration, function()
				if model.Parent and hum.Health > 0 then
					tRoot.AssemblyLinearVelocity = Vector3.new(0, def.launchUp, 0)
					emit(tRoot.Position, palette.main, 10, 15, 0.7, 120, 0.4)
				end
			end)
		end
	end

	if def.radius then
		local center = clampAim(root.Position, aim, 50) or (root.Position + root.CFrame.LookVector * 12)
		forEachTarget(getHitboxParts(center, Vector3.new(def.radius * 2, 14, def.radius * 2), char), char, nil, bindOne)
	else
		local model, hum, tRoot = findTargetAlongAim(char, root, aim, def.range or 26)
		if model then
			boltFX(root.Position + Vector3.new(0, 1.5, 0), tRoot.Position, palette.main)
			bindOne(model, hum, tRoot)
		end
	end
end

-- force extras: mode = "pull"|"push", radius, strength, upBoost
handlers.force = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local radius = def.radius or 18
	local strength = def.strength or 80
	local center = root.Position
	local pull = def.mode == "pull"

	forEachTarget(getHitboxParts(center, Vector3.new(radius * 2, radius * 1.5, radius * 2), char), char, nil, function(model, hum, tRoot)
		local dir = pull and (center - tRoot.Position) or (tRoot.Position - center)
		dir = flatDir(dir, root.CFrame.LookVector)
		tRoot.AssemblyLinearVelocity = dir * strength + Vector3.new(0, def.upBoost or 25, 0)
		if def.damage then
			hitTarget(char, model, hum, tRoot, { stunDuration = def.stunDuration, dotDamage = def.dotDamage, knockback = 0 }, def.damage, palette)
		elseif def.stunDuration then
			applyStun(model, def.stunDuration)
		end
	end)
	shockwaveRing(groundBelow(center, char), palette.main, radius, pull and 0.55 or 0.4)
	bloomSphere(center, palette.accent, 8, 0.3)
	fxAll("blast", { pos = center, color = palette.main, radius = radius * 0.7, power = 0.7 })
end

-- tendrils extras: count, duration, range, tickDamage, tickRate, follow
-- (follow=true mounts them on the caster's back, e.g. Manderin/Blue)
handlers.tendrils = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local count = math.clamp(def.count or 4, 1, 8)
	local follow = def.follow == true
	local center
	if follow then
		center = root.Position
	else
		center = clampAim(root.Position, aim, 45) or (root.Position + root.CFrame.LookVector * 10)
		center = groundBelow(center, char)
	end

	local parts, offsets, tips = {}, {}, {}
	local baseCF = follow and root.CFrame or CFrame.new(center)
	for i = 1, count do
		local ang = (i / count) * math.pi * 2
		local sideOff = CFrame.new(math.cos(ang) * 3, follow and 1 or 0, math.sin(ang) * 3)
		local segLen = { 3.2, 2.6, 2 }
		local segCF = sideOff * CFrame.Angles(math.rad(-20 - (follow and 25 or 0)), ang, 0)
		local cursor = segCF
		for s = 1, 3 do
			local size = Vector3.new(0.9 - s * 0.2, segLen[s], 0.9 - s * 0.2)
			cursor = cursor * CFrame.new(0, segLen[s] / 2, 0)
			local part = makePart({ Color = palette.main, Transparency = 0.1, Size = size, CFrame = baseCF * cursor })
			table.insert(parts, part)
			table.insert(offsets, { part = part, offset = cursor })
			cursor = cursor * CFrame.new(0, segLen[s] / 2, 0) * CFrame.Angles(math.rad(18), 0, 0)
			if s == 3 then table.insert(tips, { offset = cursor }) end
		end
	end

	table.insert(activeTendrils, {
		char = char, root = root, player = player, palette = palette, def = def,
		center = center, follow = follow, parts = parts, offsets = offsets, tips = tips,
		range = def.range or 22, tickDamage = def.tickDamage or 6,
		tickRate = def.tickRate or 0.8, tickTimer = 0.3, lashIndex = 1,
		endTime = os.clock() + math.clamp(def.duration or 6, 1, 15),
	})
	ensureTick()
	if not follow then
		emit(center, Color3.fromRGB(120, 110, 100), 14, 10, 1.6, 80, 0.9, TEX_SMOKE)
	end
end

-- breath extras: duration, range, angle (cone half-angle), tickDamage,
-- tickRate, slowAmount, dotDamage
handlers.breath = function(char, root, def, player)
	local palette = paletteFor(def)
	local muzzle = getMuzzle(char)
	local range = def.range or 18

	local nozzle = Instance.new("Part")
	nozzle.Size = Vector3.new(0.4, 0.4, 0.4)
	nozzle.Transparency = 1
	nozzle.CanCollide = false; nozzle.CanQuery = false; nozzle.CanTouch = false
	nozzle.Massless = true
	nozzle.CFrame = CFrame.lookAt(muzzle.Position, muzzle.Position + root.CFrame.LookVector)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = nozzle; weld.Part1 = muzzle; weld.Parent = nozzle
	nozzle.Parent = fxFolder

	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(palette.main, palette.accent)
	spray.LightEmission = 0.8
	spray.Size = NumberSequence.new({ kp(0, 1), kp(1, 3.2) })
	spray.Transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) })
	spray.Lifetime = NumberRange.new(0.35, 0.5)
	spray.Speed = NumberRange.new(range * 1.8, range * 2.2)
	spray.SpreadAngle = Vector2.new(def.angle or 14, def.angle or 14)
	spray.EmissionDirection = Enum.NormalId.Front
	spray.Rate = 90
	spray.Texture = TEX_FIRE
	spray.Parent = nozzle

	table.insert(activeBreaths, {
		char = char, root = root, player = player, palette = palette, def = def,
		nozzle = nozzle, range = range, angle = math.rad(def.angle or 30),
		tickRate = def.tickRate or 0.25, tickTimer = 0,
		endTime = os.clock() + math.clamp(def.duration or 2, 0.5, 6),
	})
	ensureTick()
end

-- slam extras: radius, leap (jump toward cursor first), leapTime
handlers.slam = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local radius = def.radius or 14

	local function boom()
		local r = getRoot(char)
		if not r then return end
		forEachTarget(getHitboxParts(r.Position, Vector3.new(radius * 2, math.max(radius, 12), radius * 2), char), char, nil, function(m, h, tr)
			hitTarget(char, m, h, tr, def, def.damage, palette)
		end)
		blastFX(r.Position, palette, radius, math.clamp((def.damage or 30) / 40 + radius / 40, 0.6, 1.6), char)
	end

	if def.leap then
		local target = clampAim(root.Position, aim, 45) or (root.Position + root.CFrame.LookVector * 20)
		local offset = target - root.Position
		local leapTime = def.leapTime or 0.55
		root.AssemblyLinearVelocity = Vector3.new(offset.X / leapTime, 55, offset.Z / leapTime)
		emit(root.Position, palette.accent, 8, 12, 0.6, 120, 0.4)
		task.delay(leapTime, function()
			local r = getRoot(char)
			if r then r.AssemblyLinearVelocity = Vector3.new(0, -140, 0) end
			task.delay(0.12, boom)
		end)
	else
		boom()
	end
end

-- clones extras: count, duration, health, explodeOnDeath = {damage, radius}
handlers.clones = function(char, root, def, player)
	local palette = paletteFor(def)
	local count = math.clamp(def.count or 2, 1, 4)
	local duration = math.clamp(def.duration or 8, 2, 20)

	char.Archivable = true
	for i = 1, count do
		local clone = char:Clone()
		if not clone then break end
		clone.Name = char.Name
		clone:SetAttribute("CloneOwner", char.Name)
		for _, inst in ipairs(clone:GetDescendants()) do
			if inst:IsA("BaseScript") or inst:IsA("Tool") then inst:Destroy() end
		end
		local cHum = clone:FindFirstChildOfClass("Humanoid")
		local cRoot = clone:FindFirstChild("HumanoidRootPart")
		if not cHum or not cRoot then clone:Destroy() break end
		cHum.MaxHealth = def.health or 50
		cHum.Health = cHum.MaxHealth
		local side = (i % 2 == 0) and 1 or -1
		local offset = root.CFrame * CFrame.new(side * (3 + i), 0, 2)
		clone:PivotTo(offset)
		clone.Parent = structFolder
		teleWarp(offset.Position, palette)

		local dead = false
		cHum.Died:Connect(function()
			if dead then return end
			dead = true
			if def.explodeOnDeath then
				local e = def.explodeOnDeath
				forEachTarget(getHitboxParts(cRoot.Position, Vector3.new((e.radius or 10) * 2, 12, (e.radius or 10) * 2), char), char, nil, function(m, h, tr)
					damageModel(char, m, h, tr, e.damage or 25, e.knockback or 35, 15, palette)
				end)
				blastFX(cRoot.Position, palette, e.radius or 10, 0.8, char)
			else
				teleWarp(cRoot.Position, palette)
			end
			clone:Destroy()
		end)

		-- simple decoy wander
		task.spawn(function()
			local elapsed = 0
			while elapsed < duration and clone.Parent and cHum.Health > 0 do
				local owner = getRoot(char)
				local around = owner and owner.Position or cRoot.Position
				cHum:MoveTo(around + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
				task.wait(1.3)
				elapsed += 1.3
			end
			if clone.Parent and not dead then
				dead = true
				teleWarp(cRoot.Position, palette)
				clone:Destroy()
			end
		end)
	end
	char.Archivable = false
end

-- turret extras: duration, fireRate, damage, range, projectileSpeed, scale
handlers.turret = function(char, root, def, player, aim)
	local palette = paletteFor(def)
	local scale = def.scale or 1
	local pos = (clampAim(root.Position, aim, 25) or (root.Position + root.CFrame.LookVector * 6)) + Vector3.new(0, 4 * scale, 0)

	local body = makePart({ Shape = Enum.PartType.Ball, Color = palette.main, Transparency = 0.1, Size = Vector3.new(2.4, 2.4, 2.4) * scale, CFrame = CFrame.new(pos) })
	local ringFin = makePart({ Shape = Enum.PartType.Cylinder, Color = palette.accent, Transparency = 0.3, Size = Vector3.new(0.3, 4.2 * scale, 4.2 * scale), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
	local light = Instance.new("PointLight")
	light.Color = palette.main; light.Brightness = 2; light.Range = 12; light.Parent = body
	local hoverInfo = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(body, hoverInfo, { CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) }):Play()
	TweenService:Create(ringFin, hoverInfo, { CFrame = ringFin.CFrame + Vector3.new(0, 1, 0) }):Play()
	teleWarp(pos, palette)

	table.insert(activeTurrets, {
		char = char, player = player, palette = palette, def = def,
		body = body, ringFin = ringFin, pos = pos,
		range = def.range or 40, fireRate = def.fireRate or 0.8, fireTimer = 0.4,
		endTime = os.clock() + math.clamp(def.duration or 10, 2, 30),
	})
	ensureTick()
end

-- counter extras: duration, reflect (damage multiplier back at the attacker)
handlers.counter = function(char, root, def, player)
	local palette = paletteFor(def)
	char:SetAttribute("CounterUntil", os.clock() + (def.duration or 1.25))
	char:SetAttribute("CounterReflect", def.reflect or 1)
	shockwaveRing(root.Position, palette.main, 5, 0.3)
	local stance = Instance.new("ParticleEmitter")
	stance.Color = ColorSequence.new(palette.main)
	stance.LightEmission = 1
	stance.Size = NumberSequence.new({ kp(0, 0.4), kp(1, 0) })
	stance.Lifetime = NumberRange.new(0.3, 0.5)
	stance.Speed = NumberRange.new(3, 5)
	stance.Rate = 25
	stance.Parent = root
	Debris:AddItem(stance, def.duration or 1.25)
end

-- phase extras: duration, speedMult, transparency (0.95 = near-invisible cloak)
handlers.phase = function(char, root, def, player)
	local palette = paletteFor(def)
	local duration = math.clamp(def.duration or 1.2, 0.3, 10)
	setShieldBlock(char, 1, duration)
	if def.speedMult then applySpeedMult(char, "SpeedBuffMult", def.speedMult, duration) end

	local gen = (char:GetAttribute("PhaseGen") or 0) + 1
	char:SetAttribute("PhaseGen", gen)
	local ghost = def.transparency or 0.65
	local restore = {}
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Transparency < 0.95 then
			restore[inst] = inst.Transparency
			inst.Transparency = ghost
		elseif inst:IsA("Decal") then
			restore[inst] = inst.Transparency
			inst.Transparency = ghost
		end
	end
	teleWarp(root.Position, palette)
	task.delay(duration, function()
		if char.Parent and char:GetAttribute("PhaseGen") == gen then
			for inst, t in pairs(restore) do
				if inst.Parent then inst.Transparency = t end
			end
		end
	end)
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
			local result = workspace:Spherecast(p.pos, p.radius, p.dir * stepDist, p.params)
			if result then
				local hitPos = result.Position
				local seen = {}
				local dmg = p.def.damage
				-- Chasm-style ramp: the farther it flew, the harder it hits
				if dmg and p.def.rampPer then
					dmg = math.min(dmg * (1 + p.traveled / p.def.rampPer), dmg * 3)
				end
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model ~= p.char then
					local hum = model:FindFirstChildOfClass("Humanoid")
					local hroot = model:FindFirstChild("HumanoidRootPart")
					if hum and hroot and hum.Health > 0
						and model:GetAttribute("CloneOwner") ~= p.char.Name then
						seen[model] = true
						hitTarget(p.char, model, hum, hroot, p.def, dmg, p.palette)
						if p.def.slowAmount then applySpeedMult(model, "SlowMult", p.def.slowAmount, p.def.slowDuration or 1.2) end
						-- every-Nth-hit stun (Looney's finger gun)
						if p.def.stunEvery and p.player then
							local key = "HitCount_" .. (p.def.name or "shot")
							local n = (p.player:GetAttribute(key) or 0) + 1
							p.player:SetAttribute(key, n)
							if n % p.def.stunEvery == 0 then applyStun(model, 1.2) end
						end
					end
				end
				if p.def.splashRadius then
					local r = p.def.splashRadius
					forEachTarget(getHitboxParts(hitPos, Vector3.new(r * 2, r * 2, r * 2), p.char), p.char, seen, function(m, h, rt)
						hitTarget(p.char, m, h, rt, p.def, (dmg or 20) * 0.6, p.palette)
					end)
					shockwaveRing(groundBelow(hitPos), p.palette.main, r, 0.4)
				end
				impactFX(hitPos, p.palette, (dmg or 0) >= 35 or p.def.splashRadius ~= nil)
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
							if b.def.dotDamage then applyDot(model, hum, b.def.dotDamage, b.def.dotDuration or 2, b.palette.main) end
							if b.def.lifesteal then
								local aHum = getHumanoid(b.char)
								if aHum and aHum.Health > 0 then aHum.Health = math.min(aHum.MaxHealth, aHum.Health + (b.def.tickDamage or 3) * b.def.lifesteal) end
							end
							emit(endPos, b.palette.main, 4, 10, 0.45, 180, 0.3, TEX_SPARK)
						end
					end
				end
				forEachTarget(getHitboxParts(endPos, Vector3.new(6, 6, 6), b.char), b.char, seen, function(m, h, rt)
					damageModel(b.char, m, h, rt, (b.def.tickDamage or 3) * 0.5, 0, 0, nil)
					if b.def.slowAmount then applySpeedMult(m, "SlowMult", b.def.slowAmount, b.def.slowDuration or 1) end
				end)
				fxFor(player, "shake", { intensity = 0.06 })
			end
		end
	end
end

stepVortexes = function(dt)
	for i = #activeVortexes, 1, -1 do
		local v = activeVortexes[i]
		if os.clock() > v.endTime then
			-- black-hole style detonation
			if v.def.endDamage then
				local r = v.def.endRadius or (v.radius + 6)
				forEachTarget(getHitboxParts(v.center, Vector3.new(r * 2, r * 2, r * 2), v.char), v.char, nil, function(m, h, tr)
					local dir = tr.Position - v.center
					dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.yAxis
					h:TakeDamage(v.def.endDamage)
					tr.AssemblyLinearVelocity = dir * (v.def.endKnockback or 70) + Vector3.new(0, 35, 0)
				end)
				blastFX(v.center, v.palette, r, 1.2, v.char)
			end
			for _, part in ipairs(v.parts) do
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				Debris:AddItem(part, 0.35)
			end
			table.remove(activeVortexes, i)
		else
			for _, plr in ipairs(Players:GetPlayers()) do
				local pchar = plr.Character
				if pchar and pchar ~= v.char then
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

stepZones = function(dt)
	for i = #activeZones, 1, -1 do
		local z = activeZones[i]
		local expired = os.clock() > z.endTime
		if z.followRoot then
			if z.followRoot.Parent then
				z.center = z.followRoot.Position
			else
				expired = true
			end
		end
		if expired then
			for _, part in ipairs(z.parts) do
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				Debris:AddItem(part, 0.45)
			end
			table.remove(activeZones, i)
		else
			z.tickTimer -= dt
			if z.tickTimer <= 0 then
				z.tickTimer = z.tickRate
				forEachTarget(getHitboxParts(z.center, Vector3.new(z.radius * 2, 14, z.radius * 2), z.ownerChar), z.ownerChar, nil, function(m, h, rt)
					if z.tickDamage then
						damageModel(z.ownerChar, m, h, rt, z.tickDamage, 0, 0, nil)
						if z.def and z.def.dotDamage then applyDot(m, h, z.def.dotDamage, z.def.dotDuration or 2, z.palette.main) end
					end
					if z.slowAmount then applySpeedMult(m, "SlowMult", z.slowAmount, z.tickRate + 0.35) end
					if z.pull then
						local dir = z.center - rt.Position
						if dir.Magnitude > 2 then
							rt.AssemblyLinearVelocity = rt.AssemblyLinearVelocity:Lerp(dir.Unit * z.pull, 0.3)
						end
					end
				end)
				if z.healPerTick then
					local oHum = getHumanoid(z.ownerChar)
					local oRoot = getRoot(z.ownerChar)
					if oHum and oHum.Health > 0 and oRoot and (oRoot.Position - z.center).Magnitude <= z.radius + 5 then
						oHum.Health = math.min(oHum.MaxHealth, oHum.Health + z.healPerTick)
						emit(oRoot.Position, Color3.fromRGB(140, 255, 160), 5, 6, 0.4, 160, 0.4, TEX_SPARK)
					end
				end
			end
		end
	end
end

stepBreaths = function(dt)
	for i = #activeBreaths, 1, -1 do
		local b = activeBreaths[i]
		local hum = getHumanoid(b.char)
		if os.clock() > b.endTime or not b.char.Parent or not hum or hum.Health <= 0 or not b.root.Parent then
			if b.nozzle then
				local spray = b.nozzle:FindFirstChildOfClass("ParticleEmitter")
				if spray then spray.Enabled = false end
				Debris:AddItem(b.nozzle, 0.6)
			end
			table.remove(activeBreaths, i)
		else
			b.tickTimer -= dt
			if b.tickTimer <= 0 then
				b.tickTimer = b.tickRate
				local look = b.root.CFrame.LookVector
				local origin = b.root.Position
				forEachTarget(getHitboxParts(origin + look * (b.range * 0.5), Vector3.new(b.range, 12, b.range), b.char), b.char, nil, function(m, h, rt)
					local off = rt.Position - origin
					if off.Magnitude <= b.range and off.Magnitude > 0.1 and off.Unit:Dot(look) >= math.cos(b.angle) then
						damageModel(b.char, m, h, rt, b.def.tickDamage or 5, b.def.knockback or 6, 0, nil)
						if b.def.slowAmount then applySpeedMult(m, "SlowMult", b.def.slowAmount, 0.8) end
						if b.def.dotDamage then applyDot(m, h, b.def.dotDamage, b.def.dotDuration or 2, b.palette.main) end
					end
				end)
			end
		end
	end
end

stepTurrets = function(dt)
	for i = #activeTurrets, 1, -1 do
		local t = activeTurrets[i]
		if os.clock() > t.endTime or not t.body.Parent then
			if t.body.Parent then teleWarp(t.body.Position, t.palette) end
			t.body:Destroy()
			t.ringFin:Destroy()
			table.remove(activeTurrets, i)
		else
			t.fireTimer -= dt
			if t.fireTimer <= 0 then
				t.fireTimer = t.fireRate
				local firePos = t.body.Position
				local _, _, targetRoot = nearestTarget(firePos, t.range, t.char, nil)
				if targetRoot then
					local dir = (targetRoot.Position - firePos)
					if dir.Magnitude > 0.5 then
						dir = dir.Unit
						emit(firePos + dir * 2, t.palette.accent, 4, 8, 0.4, 90, 0.2, TEX_SPARK)
						spawnProjectileRaw(t.char, t.player, {
							name = t.def.name, damage = t.def.damage or 8,
							speed = t.def.projectileSpeed or 130, knockback = t.def.knockback or 12,
							size = Vector3.new(1.2, 1.2, 1.2) * (t.def.scale or 1), life = 2.5,
							dotDamage = t.def.dotDamage, slowAmount = t.def.slowAmount,
						}, t.palette, firePos + dir * 2.5, dir)
					end
				end
			end
		end
	end
end

stepTendrils = function(dt)
	for i = #activeTendrils, 1, -1 do
		local e = activeTendrils[i]
		local rootGone = e.follow and not e.root.Parent
		if os.clock() > e.endTime or rootGone then
			for _, part in ipairs(e.parts) do
				TweenService:Create(part, TweenInfo.new(0.35), { Transparency = 1, CFrame = part.CFrame * CFrame.new(0, -2, 0) }):Play()
				Debris:AddItem(part, 0.4)
			end
			table.remove(activeTendrils, i)
		else
			if e.follow and e.root.Parent then
				e.center = e.root.Position
				local baseCF = e.root.CFrame
				for _, entry in ipairs(e.offsets) do
					entry.part.CFrame = baseCF * entry.offset
				end
			end
			e.tickTimer -= dt
			if e.tickTimer <= 0 then
				e.tickTimer = e.tickRate
				local struck = 0
				forEachTarget(getHitboxParts(e.center, Vector3.new(e.range * 2, 16, e.range * 2), e.char), e.char, nil, function(m, h, rt)
					if struck >= #e.tips then return end
					struck += 1
					local tip = e.tips[(e.lashIndex % #e.tips) + 1]
					e.lashIndex += 1
					local baseCF = e.follow and e.root.CFrame or CFrame.new(e.center)
					local tipPos = (baseCF * tip.offset).Position
					boltFX(tipPos, rt.Position, e.palette.main)
					hitTarget(e.char, m, h, rt, e.def, e.tickDamage, e.palette)
				end)
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
	if b.tip then b.tip:Destroy() end
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

return AbilityEngine
