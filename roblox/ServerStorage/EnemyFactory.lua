--[[
	EnemyFactory  (ModuleScript)
	WHERE IT GOES: ServerStorage > EnemyFactory

	Spawns the campaign's enemies as simple part-built R6 rigs with a real
	Humanoid — so your EXISTING AbilityEngine already damages and knocks them
	around with zero extra wiring (it hits any model with a Humanoid +
	HumanoidRootPart that isn't the caster).

	Two kinds:
	  * spawnGuard(pos, opts)  - a Manderin Security grunt: chases the nearest
	                             player and melees them.
	  * spawnBoss(pos, opts)   - Manderin: bigger, tanky, and CASTS real abilities
	                             through your AbilityEngine (slam, tentacles,
	                             barrage, force push, aoe) aimed at the nearest
	                             player, so the boss fight uses the same VFX as
	                             everything else.

	opts (both):
	  health, walkSpeed, meleeDamage, meleeRange, aggro, onDeath(model)
	spawnBoss extra opts:
	  abilityEngine (the required AbilityEngine module — enables ability casting),
	  castInterval

	Returns the character Model (parented to opts.parent or workspace).
]]

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")

local EnemyFactory = {}

local GUARD_COLOR = Color3.fromRGB(40, 44, 54)
local GUARD_TRIM  = Color3.fromRGB(60, 150, 255)
local BOSS_COLOR  = Color3.fromRGB(20, 22, 28)
local BOSS_TRIM   = Color3.fromRGB(230, 60, 60)

-------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------
local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function limb(name, size, color, model)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- build a blocky R6-style rig around a HumanoidRootPart at `pos`
local function buildRig(name, pos, scale, color, trim, health)
	local model = Instance.new("Model")
	model.Name = name

	local hrp = limb("HumanoidRootPart", Vector3.new(2, 2, 1) * scale, color, model)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CFrame = CFrame.new(pos)
	model.PrimaryPart = hrp

	local torso = limb("Torso", Vector3.new(2, 2, 1) * scale, color, model)
	torso.CFrame = hrp.CFrame
	weld(torso, hrp)

	local head = limb("Head", Vector3.new(1.3, 1.3, 1.3) * scale, color, model)
	head.CFrame = hrp.CFrame * CFrame.new(0, 1.7 * scale, 0)
	weld(head, hrp)
	-- glowing visor
	local visor = limb("Visor", Vector3.new(1.35, 0.35, 1.35) * scale, trim, model)
	visor.Material = Enum.Material.Neon
	visor.CFrame = head.CFrame * CFrame.new(0, 0.1 * scale, 0)
	weld(visor, head)

	for _, side in ipairs({ -1, 1 }) do
		local arm = limb("Arm", Vector3.new(1, 2, 1) * scale, color, model)
		arm.CFrame = hrp.CFrame * CFrame.new(side * 1.5 * scale, 0, 0)
		weld(arm, hrp)
		local leg = limb("Leg", Vector3.new(1, 2, 1) * scale, Color3.fromRGB(24, 26, 32), model)
		leg.CFrame = hrp.CFrame * CFrame.new(side * 0.5 * scale, -2 * scale, 0)
		weld(leg, hrp)
	end
	-- chest trim + M
	local chest = limb("Chest", Vector3.new(1.2, 0.5, 0.2) * scale, trim, model)
	chest.Material = Enum.Material.Neon
	chest.CFrame = torso.CFrame * CFrame.new(0, 0.2 * scale, -0.55 * scale)
	weld(chest, torso)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = health
	hum.Health = health
	hum.WalkSpeed = 12
	hum.DisplayName = name
	hum.RigType = Enum.HumanoidRigType.R6
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.Parent = model

	return model, hrp, hum
end

-- name/health billboard so players can read the target
local function nameplate(model, hum, text, color)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = head
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = text
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextColor3 = color
	nameLbl.TextScaled = true
	nameLbl.Parent = bb
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.9, 0, 0.2, 0)
	barBg.Position = UDim2.new(0.05, 0, 0.62, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = barBg
	hum.HealthChanged:Connect(function(h)
		bar.Size = UDim2.new(math.clamp(h / hum.MaxHealth, 0, 1), 0, 1, 0)
	end)
end

local function nearestPlayerChar(fromPos, range)
	local best, bestRoot, bestDist
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			local d = (root.Position - fromPos).Magnitude
			if d <= range and (not bestDist or d < bestDist) then
				best, bestRoot, bestDist = char, root, d
			end
		end
	end
	return best, bestRoot, bestDist
end

-- melee that respects the player's Blocking attribute (same as the engine)
local function meleePlayer(attackerRoot, targetChar, dmg, knock)
	local hum = targetChar:FindFirstChildOfClass("Humanoid")
	local root = targetChar:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end
	local plr = Players:GetPlayerFromCharacter(targetChar)
	if plr and plr:GetAttribute("Blocking") then dmg = dmg * 0.3; knock = knock * 0.2 end
	hum:TakeDamage(dmg)
	local dir = (root.Position - attackerRoot.Position)
	dir = dir.Magnitude > 0 and dir.Unit or attackerRoot.CFrame.LookVector
	root.AssemblyLinearVelocity = dir * knock + Vector3.new(0, 8, 0)
end

local function attachDeath(model, hum, onDeath)
	local done = false
	hum.Died:Connect(function()
		if done then return end
		done = true
		if onDeath then task.spawn(onDeath, model) end
		Debris:AddItem(model, 4)
		task.delay(0.1, function()
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), 12, math.random(-10, 10))
				end
			end
		end)
	end)
end

-------------------------------------------------------------------
-- GUARD
-------------------------------------------------------------------
function EnemyFactory.spawnGuard(pos, opts)
	opts = opts or {}
	local model, hrp, hum = buildRig(opts.name or "Manderin Security", pos, 1,
		GUARD_COLOR, GUARD_TRIM, opts.health or 120)
	hum.WalkSpeed = opts.walkSpeed or 14
	model.Parent = opts.parent or workspace
	nameplate(model, hum, opts.name or "Manderin Security", GUARD_TRIM)
	attachDeath(model, hum, opts.onDeath)

	local meleeCd = 0
	local aggro = opts.aggro or 140
	local meleeRange = opts.meleeRange or 6.5
	task.spawn(function()
		while model.Parent and hum.Health > 0 do
			local _, targetRoot, dist = nearestPlayerChar(hrp.Position, aggro)
			if targetRoot then
				hum:MoveTo(targetRoot.Position)
				if dist <= meleeRange and os.clock() >= meleeCd then
					meleeCd = os.clock() + (opts.meleeCooldown or 1.1)
					local tchar = targetRoot.Parent
					meleePlayer(hrp, tchar, opts.meleeDamage or 8, opts.knockback or 24)
				end
			end
			task.wait(0.3)
		end
	end)
	return model
end

-------------------------------------------------------------------
-- BOSS: MANDERIN
-------------------------------------------------------------------
-- attack patterns the boss cycles through, run via AbilityEngine.run(nil, char, def, aimPos)
local BOSS_MOVES = {
	{ name = "Aegis Slam",       type = "slam", radius = 18, damage = 26, knockback = 45, up = 25, stunDuration = 0.6, style = "energy", styleKey = "manderin" },
	{ name = "Tentacle Lash",    type = "tendrils", count = 4, duration = 5, range = 24, tickDamage = 7, tickRate = 0.7, follow = true, style = "energy", styleKey = "manderin" },
	{ name = "Laser Barrage",    type = "barrage", count = 6, interval = 0.1, spread = 7, damage = 10, speed = 150, size = Vector3.new(1.4, 1.4, 1.4), knockback = 16, style = "energy", styleKey = "manderin" },
	{ name = "Force Repulse",    type = "force", mode = "push", radius = 18, strength = 105, damage = 20, upBoost = 28, style = "energy", styleKey = "manderin" },
	{ name = "Power Nova",       type = "aoe", radius = 20, damage = 30, knockback = 50, up = 20, style = "energy", styleKey = "manderin" },
}

function EnemyFactory.spawnBoss(pos, opts)
	opts = opts or {}
	local model, hrp, hum = buildRig(opts.name or "Manderin", pos, 1.6,
		BOSS_COLOR, BOSS_TRIM, opts.health or 2200)
	hum.WalkSpeed = opts.walkSpeed or 10
	model:SetAttribute("Boss", true)
	model.Parent = opts.parent or workspace
	nameplate(model, hum, "★ " .. (opts.name or "Manderin"), BOSS_TRIM)
	attachDeath(model, hum, opts.onDeath)

	-- four cosmetic tentacles off the back (Manderin's signature)
	local torso = model:FindFirstChild("Torso")
	for i = 1, 4 do
		local ang = math.rad((i - 2.5) * 22)
		local t = limb("BackTentacle", Vector3.new(0.6, 5, 0.6), BOSS_COLOR, model)
		t.CanCollide = false
		t.CFrame = torso.CFrame * CFrame.new((i - 2.5) * 0.7, 1.5, 1.3) * CFrame.Angles(math.rad(30), 0, ang)
		weld(t, torso)
		local tip = limb("TentacleTip", Vector3.new(0.7, 0.7, 0.7), BOSS_TRIM, model)
		tip.Material = Enum.Material.Neon
		tip.CFrame = t.CFrame * CFrame.new(0, 2.6, 0)
		weld(tip, t)
	end

	local engine = opts.abilityEngine
	local aggro = opts.aggro or 300
	local meleeRange = opts.meleeRange or 9
	local meleeCd, castCd = 0, os.clock() + 2
	local moveIndex = 0

	task.spawn(function()
		while model.Parent and hum.Health > 0 do
			local _, targetRoot, dist = nearestPlayerChar(hrp.Position, aggro)
			if targetRoot then
				hum:MoveTo(targetRoot.Position)
				-- melee when close
				if dist <= meleeRange and os.clock() >= meleeCd then
					meleeCd = os.clock() + 1.2
					meleePlayer(hrp, targetRoot.Parent, opts.meleeDamage or 16, opts.knockback or 40)
				end
				-- cast a real ability on a timer
				if engine and os.clock() >= castCd then
					castCd = os.clock() + (opts.castInterval or 3.2)
					moveIndex = (moveIndex % #BOSS_MOVES) + 1
					local def = BOSS_MOVES[moveIndex]
					local ok = pcall(function()
						engine.run(nil, model, def, targetRoot.Position)
					end)
					if not ok then castCd = os.clock() + 1 end
				end
			end
			task.wait(0.4)
		end
	end)
	return model
end

return EnemyFactory
