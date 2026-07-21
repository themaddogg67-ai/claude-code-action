--[[
	CampaignController  (Script)
	WHERE IT GOES: ServerScriptService > CampaignController

	Runs the Metro City campaign as shared co-op progression:
	  spawn a stage's enemies -> players defeat them -> the objective marker
	  unlocks -> a player reaches it -> advance the checkpoint -> next stage,
	  ending with the Manderin boss fight at Manderin Tower.

	It reads the ordered route from ReplicatedStorage.Campaign.MetroCityCampaign
	and the live markers the map generator placed under
	workspace.MetroCity.Campaign, so nothing is positioned twice. Enemies are
	built by ServerStorage.EnemyFactory and are damaged by your normal
	AbilityEngine; the boss casts through that same engine.

	Progress + objective text are pushed to clients over the auto-created
	ReplicatedStorage.CampaignEvent RemoteEvent (see CampaignHud LocalScript).

	Safe if pieces are missing: it warns and no-ops rather than erroring.
]]

local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- ---- dependencies (all loaded defensively) ----
local function safeRequire(inst)
	if not inst then return nil end
	local ok, mod = pcall(require, inst)
	return ok and mod or nil
end

local campaignFolder = ReplicatedStorage:FindFirstChild("Campaign")
local EnemyFactory = safeRequire(ServerStorage:FindFirstChild("EnemyFactory"))
local AbilityEngine = safeRequire(ServerStorage:FindFirstChild("AbilityEngine")
	or (game.ServerScriptService:FindFirstChild("Systems")
		and game.ServerScriptService.Systems:FindFirstChild("AbilityEngine")))
local CharacterKits = safeRequire(ReplicatedStorage:FindFirstChild("Characters")
	and ReplicatedStorage.Characters:FindFirstChild("CharacterKits"))
local CharacterModelFactory = safeRequire(ServerStorage:FindFirstChild("CharacterModelFactory"))

-- Pick the ACTIVE season from the registry (multi-map ready); fall back to
-- Metro City directly so a missing registry still runs the built map.
local Registry = safeRequire(campaignFolder and campaignFolder:FindFirstChild("CampaignRegistry"))
local activeSeason = Registry and Registry.getActive() or nil
local routeName = (activeSeason and activeSeason.route) or "MetroCityCampaign"
local Campaign = safeRequire(campaignFolder and campaignFolder:FindFirstChild(routeName))

if not Campaign or not EnemyFactory then
	warn("CampaignController: missing route module (" .. routeName .. ") or EnemyFactory — campaign disabled.")
	return
end

-- Derive a boss's attacks from the villain's real CharacterKits entry, so each
-- season's boss fights with its own kit. Damage is capped so a villain's
-- one-shot ultimate can't instakill players, and player-only types are skipped.
local function deriveBossMoves(villainName)
	local kit = CharacterKits and villainName and CharacterKits[villainName]
	if not kit or not kit.abilities then return nil end
	local moves = {}
	for _, slot in ipairs({ "Q", "E", "R", "F" }) do
		local ab = kit.abilities[slot]
		if ab and ab.type ~= "beam" and ab.type ~= "construct" then
			local d = {}
			for k, v in pairs(ab) do d[k] = v end
			d.style = d.style or kit.style
			d.styleKey = d.styleKey or kit.styleKey
			if d.damage then d.damage = math.min(d.damage, 40) end
			if d.tickDamage then d.tickDamage = math.min(d.tickDamage, 10) end
			d.percentDamage = nil    -- never let a boss drain % HP
			d.lifesteal = nil
			d.cooldown = nil; d.energy = nil
			moves[#moves + 1] = d
		end
	end
	return #moves > 0 and moves or nil
end

-- ---- client channel ----
local event = ReplicatedStorage:FindFirstChild("CampaignEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "CampaignEvent"
	event.Parent = ReplicatedStorage
end

local REACH_RADIUS = 26          -- how close a player must get to the unlocked marker
local START_DELAY  = 4           -- seconds after the first player joins

-------------------------------------------------------------------
-- STATE
-------------------------------------------------------------------
local city                       -- workspace.MetroCity
local enemyFolder                -- container for spawned NPCs
local index = 0                  -- current stage index (1-based into Campaign.Stages)
local activeEnemies = 0
local stageCleared = false       -- enemies down, marker live
local running = false

local function broadcast(state)
	local stage = Campaign.Stages[index]
	event:FireAllClients({
		state = state,
		stage = index,
		total = #Campaign.Stages,
		district = stage and stage.district or "",
		objective = stage and stage.objective or "",
		enemiesLeft = activeEnemies,
		boss = stage and stage.boss or false,
	})
end

-- stream a boss's health fraction to the boss bar HUD
local function watchBossHealth(bossModel, bossName)
	if not bossModel then return end
	local hum = bossModel:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local function push()
		event:FireAllClients({
			state = "bosshp", bossName = bossName,
			frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
			enraged = bossModel:GetAttribute("Enraged") == true,
		})
	end
	push()
	hum.HealthChanged:Connect(push)
	bossModel:GetAttributeChangedSignal("Enraged"):Connect(push)
end

local function clearEnemies()
	if enemyFolder then enemyFolder:ClearAllChildren() end
	activeEnemies = 0
end

local function groundY(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { enemyFolder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return hit and (hit.Position.Y + 3.5) or pos.Y
end

local function markerFor(stage)
	return Campaign.getBeacon(workspace, stage.id)
end

-- set the objective beacon's look: red = enemies remain, green = go
local function setMarker(stage, live)
	local beacon = markerFor(stage)
	if not beacon then return end
	beacon.Color = live and Color3.fromRGB(80, 255, 150) or Color3.fromRGB(255, 90, 80)
	beacon.Transparency = live and 0.35 or 0.6
	local light = beacon:FindFirstChildOfClass("PointLight")
	if light then light.Color = beacon.Color end
end

-------------------------------------------------------------------
-- STAGE FLOW
-------------------------------------------------------------------
local completeStage   -- forward decl

local function onEnemyDown()
	activeEnemies = math.max(0, activeEnemies - 1)
	broadcast("fighting")
	if activeEnemies == 0 and not stageCleared then
		stageCleared = true
		local stage = Campaign.Stages[index]
		setMarker(stage, true)
		broadcast(stage.boss and "bossdown" or "cleared")
		if stage.boss then completeStage() end   -- boss dead = final victory
	end
end

local function startStage(i)
	index = i
	local stage = Campaign.Stages[i]
	if not stage then return end
	stageCleared = false
	clearEnemies()

	local beacon = markerFor(stage)
	local center = beacon and beacon.Position or Vector3.new(0, 0, 0)
	center = Vector3.new(center.X, groundY(center), center.Z)

	if stage.boss then
		activeEnemies = 1
		setMarker(stage, false)
		local bossName = Campaign.BossName or (activeSeason and activeSeason.boss) or "Manderin"
		-- build the boss's THEMED model (looks like his art) if a spec exists;
		-- otherwise the factory falls back to the default boss rig
		local rig
		if CharacterModelFactory and CharacterModelFactory.has(bossName) then
			rig = CharacterModelFactory.build(bossName, center + Vector3.new(0, 3, 0), { parent = enemyFolder })
		end
		local bossModel = EnemyFactory.spawnBoss(center + Vector3.new(0, 3, 0), {
			name = bossName, parent = enemyFolder, rig = rig,
			abilityEngine = AbilityEngine, onDeath = onEnemyDown,
			moves = deriveBossMoves(bossName),   -- his own kit; nil = factory default
		})
		broadcast("boss")
		watchBossHealth(bossModel, bossName)   -- stream HP to the boss bar
	else
		local n = stage.enemies or 3
		activeEnemies = n
		setMarker(stage, false)
		for k = 1, n do
			local ang = (k / n) * math.pi * 2
			local off = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (14 + (k % 3) * 6)
			local sp = center + off
			sp = Vector3.new(sp.X, groundY(sp) + 3, sp.Z)
			-- every 3rd enemy is a ranged attacker so stages aren't all melee
			if k % 3 == 0 then
				EnemyFactory.spawnRanged(sp, {
					name = Campaign.EnemyName .. " (Ranged)", parent = enemyFolder,
					health = 70 + i * 8, projectileDamage = 6 + i, abilityEngine = AbilityEngine,
					onDeath = onEnemyDown,
				})
			else
				EnemyFactory.spawnGuard(sp, {
					name = Campaign.EnemyName, parent = enemyFolder,
					health = 90 + i * 12, meleeDamage = 6 + i, walkSpeed = 14,
					onDeath = onEnemyDown,
				})
			end
		end
		broadcast("fighting")
	end
end

function completeStage()
	local stage = Campaign.Stages[index]
	Campaign.enableCheckpoint(workspace, stage.id)   -- respawns now move forward
	if index >= #Campaign.Stages then
		clearEnemies()
		broadcast("victory")
		running = false
		-- optional loop: restart the campaign after a breather
		task.delay(25, function()
			if #Players:GetPlayers() > 0 then
				running = true
				startStage(1)
			end
		end)
		return
	end
	startStage(index + 1)
end

-- watch for a player reaching the unlocked marker
RunService.Heartbeat:Connect(function()
	if not running or not stageCleared then return end
	local stage = Campaign.Stages[index]
	if stage.boss then return end        -- boss stages complete on death, not reach
	local beacon = markerFor(stage)
	if not beacon then return end
	local flat = Vector2.new(beacon.Position.X, beacon.Position.Z)
	for _, plr in ipairs(Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (Vector2.new(root.Position.X, root.Position.Z) - flat).Magnitude
			if d <= REACH_RADIUS then
				stageCleared = false
				completeStage()
				break
			end
		end
	end
end)

-------------------------------------------------------------------
-- BOOT
-------------------------------------------------------------------
local function begin()
	if running then return end
	local cityName = Campaign.CityModelName or "MetroCity"
	city = workspace:FindFirstChild(cityName)
	-- build the active season's map if it isn't in the place yet
	if not city then
		local builderName = Campaign.MapBuilder or (activeSeason and activeSeason.map)
		local builder = builderName and safeRequire(ServerStorage:FindFirstChild(builderName))
		if builder then
			pcall(function() builder.build(workspace) end)
			city = workspace:FindFirstChild(cityName)
		end
	end
	if not city then
		warn("CampaignController: '" .. cityName .. "' not found and no builder available — build the map first.")
		return
	end
	enemyFolder = city:FindFirstChild("CampaignEnemies")
	if not enemyFolder then
		enemyFolder = Instance.new("Folder")
		enemyFolder.Name = "CampaignEnemies"
		enemyFolder.Parent = city
	end
	running = true
	startStage(1)
	local label = activeSeason and ("Season " .. activeSeason.id .. " — " .. activeSeason.title)
		or (Campaign.CityName or cityName)
	print("CampaignController: " .. label .. " started (" .. #Campaign.Stages .. " stages).")
end

-- send current state to late joiners
event.OnServerEvent:Connect(function(player, msg)
	if msg == "requestState" then broadcast(running and "sync" or "idle") end
end)

Players.PlayerAdded:Connect(function()
	task.delay(START_DELAY, begin)
end)
if #Players:GetPlayers() > 0 then task.delay(START_DELAY, begin) end
