--[[
	AbilityManager  (Script)
	WHERE IT GOES: ServerScriptService > Systems > AbilityManager  (replace the old contents)

	Routes every UseAbility press to the right ability definition and runs it
	through AbilityEngine:
	    press -> resolve (construct kit > loadout > equipped mastery > character kit)
	          -> cooldown + energy checks -> AbilityEngine
	The remote protocol is unchanged, so your existing InputClient keeps working:
	    slot string ("Q"/"E"/"R"/"F"), "BEAM_AIM" while holding, "BEAM_STOP" on release.

	FIXED vs your old version:
	  * PlayerRemoving called AbilityEngine.stopBeam, which didn't exist in the old
	    engine -> a server error EVERY time anyone left (and any beam press errored
	    too). The engine now implements beams; this script keeps the same calls.
	  * Cooldown used to be committed BEFORE the energy check, so pressing with low
	    energy burned the full cooldown and did nothing. All checks now happen
	    before either cost is committed.
	  * DamageMult/ArmorDamageMult now also apply to beam tickDamage.
	  * Constructs end on death, respawn and leave (they used to linger), and
	    activeConstructs no longer leaks entries for players who left.
	  * resolve() no longer errors when a profile has no unlockedMasteries table.
	  * Exploit guards: non-string ability names are rejected (a table would have
	    crashed the string concat), and dead players can't cast.
	  * Removed dead code: the old local VFX/damage helpers that nothing called
	    (teleport warp / explosion bloom / frame sucker now live in AbilityEngine
	    as real ability types "teleport" and "vortex"), and the UseMastery branch
	    that did the exact same call as the line below it.
]]
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local event = ReplicatedStorage:WaitForChild("UseAbility")

-- current systems (kits + masteries + loadouts)
local MasteryData   = require(ReplicatedStorage.Masteries.MasteryData)
local CharacterData = require(ReplicatedStorage.Characters.CharacterData)
local AbilityEngine = require(game.ServerScriptService.Systems.AbilityEngine)

-- AbilityRegistry is OPTIONAL (only needed for the inventory/loadout system).
-- Load it safely so a missing/broken registry can NEVER stop abilities from working.
local function findRegistryModule()
	for _, inst in ipairs(ReplicatedStorage:GetChildren()) do
		if inst:IsA("ModuleScript") and inst.Name:lower():gsub("%s+", "") == "abilityregistry" then return inst end
	end
	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		if inst:IsA("ModuleScript") and inst.Name:lower():gsub("%s+", "") == "abilityregistry" then return inst end
	end
	return nil
end
local Registry
do
	local ok, mod = pcall(function()
		local inst = findRegistryModule()
		return inst and require(inst) or nil
	end)
	if ok and mod then Registry = mod
	else warn("AbilityManager: AbilityRegistry not loaded — loadouts disabled, abilities still work.") end
end
local okData, PlayerData = pcall(function() return require(game.ServerScriptService.Systems.DataManager) end)
if not okData then PlayerData = nil end

-- CharacterKits (ReplicatedStorage > Characters > CharacterKits) holds the
-- doc-based roster kits. Loaded defensively: if it's missing or broken,
-- everything still works off CharacterData alone.
local okKits, CharacterKits = pcall(function()
	return require(ReplicatedStorage.Characters.CharacterKits)
end)
if not okKits then
	CharacterKits = nil
	warn("AbilityManager: CharacterKits not loaded — falling back to CharacterData only.")
end

local categoryStyle = { normal = "energy", fusion = "energy", cursed = "shadow", animal = "physical", god = "cosmic", grim = "shadow" }

------------------------------------------------
-- ENERGY: every ability costs energy; it regenerates over time
------------------------------------------------
local function initEnergy(player)
	if player:GetAttribute("MaxEnergy") then return end
	player:SetAttribute("MaxEnergy", 100)
	player:SetAttribute("Energy", 100)
	task.spawn(function()
		while player.Parent do
			local e = player:GetAttribute("Energy") or 0
			local m = player:GetAttribute("MaxEnergy") or 100
			if e < m then player:SetAttribute("Energy", math.min(m, e + 6)) end
			task.wait(0.5)
		end
	end)
end

local function energyCost(def)
	if def.energy then return def.energy end
	local d = def.damage or (def.tickDamage and def.tickDamage * 10) or 25
	return math.clamp(math.floor(d / 6) + math.floor((def.cooldown or 2) * 1.5), 5, 60)
end

-- checks AND deducts in one step; only call after the cooldown check passed
local function spendEnergy(player, def)
	initEnergy(player)
	local cost = energyCost(def)
	local e = player:GetAttribute("Energy") or 0
	if e < cost then return false end
	player:SetAttribute("Energy", e - cost)
	return true
end

------------------------------------------------
-- COOLDOWNS (check and commit are separate so a failed energy
-- check can no longer burn the cooldown for nothing)
------------------------------------------------
local cooldowns = {}
local function isOnCooldown(player, key)
	local t = cooldowns[player]
	return t ~= nil and t[key] == true
end
local function startCooldown(player, key, cd)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][key] = true
	task.delay(cd or 1, function()
		local t = cooldowns[player]
		if t then t[key] = nil end
	end)
end

------------------------------------------------
-- CONSTRUCTS
-- A construct conjures a weapon that TEMPORARILY REPLACES your moveset
-- (def.kit = {Q=..,E=..,R=..,F=..}) and shows a glowing weapon in your hand.
------------------------------------------------
local activeConstructs = {}   -- player -> {kit, style, styleKey, expires, model}

local function endConstruct(player)
	local c = activeConstructs[player]
	if not c then return end
	if c.model then c.model:Destroy() end
	activeConstructs[player] = nil
	if player then player:SetAttribute("Construct", nil) end
end

local function startConstruct(player, character, def)
	endConstruct(player)
	-- glowing weapon in the right hand
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local model
	if hand then
		model = Instance.new("Part")
		local w = def.weapon or "sword"
		model.Size = (w == "gun" and Vector3.new(0.6, 0.8, 3.2)) or (w == "blocks" and Vector3.new(1.6, 1.6, 1.6)) or Vector3.new(0.4, 4.2, 0.7)
		model.Material = Enum.Material.Neon
		model.Color = def.color or Color3.fromRGB(120, 200, 255)
		model.CanCollide = false; model.Massless = true
		model.CFrame = hand.CFrame * CFrame.new(0, -(model.Size.Y / 2) - 0.4, 0)
		local weld = Instance.new("WeldConstraint"); weld.Part0 = model; weld.Part1 = hand; weld.Parent = model
		model.Parent = character
	end
	activeConstructs[player] = {
		kit = def.kit or {}, style = def.style, styleKey = def.styleKey,
		expires = os.clock() + (def.duration or 12), model = model,
	}
	player:SetAttribute("Construct", def.name or "Construct")
	task.delay(def.duration or 12, function()
		local c = activeConstructs[player]
		if c and os.clock() >= c.expires then endConstruct(player) end
	end)
end

------------------------------------------------
-- RESOLVE: which definition does this slot press mean right now?
------------------------------------------------
local function resolve(player, slot)
	-- CONSTRUCT overrides everything while it lasts
	local c = activeConstructs[player]
	if c then
		if os.clock() >= c.expires then endConstruct(player)
		elseif c.kit[slot] then return c.kit[slot], c.style, c.styleKey end
	end
	-- LOADOUT (inventory/hotbar) takes priority: if you assigned an ability to this slot, use it
	do
		local profile = Registry and PlayerData and PlayerData.get(player)
		local cn = player:GetAttribute("CharacterName")
		if Registry and profile and profile.loadouts and cn and profile.loadouts[cn] then
			local id = profile.loadouts[cn][slot]
			if id then
				local e = Registry.get(id)
				if e then return e.def, e.style, e.styleKey end
			end
		end
	end
	-- SHOP MASTERY MODE (equip/swap)
	if player:GetAttribute("UseMastery") and PlayerData then
		local profile = PlayerData.get(player)
		local key = profile and profile.equippedMastery
		if key and profile.unlockedMasteries and profile.unlockedMasteries[key] then
			local m = MasteryData.Masteries[key]
			if m then
				local ab = m.abilities[slot]
				if ab then return ab, categoryStyle[m.category], (ab.styleKey or key) end
				return nil
			end
		end
	end
	-- CHARACTER KIT (Leon / Ice Man / Ember / Titan / Looney / Chasm / ...)
	-- CharacterKits (doc-based roster) is checked FIRST so the new movesets take
	-- effect immediately; swap these two blocks to prefer CharacterData instead.
	local charName = player:GetAttribute("CharacterName")
	if charName and CharacterKits and CharacterKits[charName] then
		local kit = CharacterKits[charName]
		local ab = kit.abilities[slot]
		if ab then return ab, kit.style, ab.styleKey or kit.styleKey end
	end
	local kit = charName and CharacterData[charName]
	if kit then
		local ab = kit.abilities[slot]
		if ab then return ab, kit.style, ab.styleKey end
	end
	return nil
end

------------------------------------------------
-- RUN
------------------------------------------------
local function runFromEngine(player, character, slot, aim)
	local def, style, styleKey = resolve(player, slot)
	if not def then return end
	local d = {}
	for k, v in pairs(def) do d[k] = v end
	if style    and not d.style    then d.style    = style end
	if styleKey and not d.styleKey then d.styleKey = styleKey end
	local mult = (player:GetAttribute("DamageMult") or 1) * (player:GetAttribute("ArmorDamageMult") or 1)
	if mult ~= 1 then
		if d.damage then d.damage = d.damage * mult end
		if d.tickDamage then d.tickDamage = d.tickDamage * mult end
	end
	-- CONSTRUCT: conjure the weapon + swap moveset instead of running an attack
	if d.type == "construct" then
		if isOnCooldown(player, "CONSTRUCT_" .. slot) then return end
		startCooldown(player, "CONSTRUCT_" .. slot, d.cooldown or 20)
		startConstruct(player, character, d)
		return
	end
	-- HOLD-TO-FIRE BEAM (e.g. Ice Man's Ice Beam): start it, don't run once.
	-- No upfront energy cost — the engine drains energy per second while held.
	if d.type == "beam" then
		if isOnCooldown(player, "BEAM_" .. slot) then return end
		startCooldown(player, "BEAM_" .. slot, 0.3)
		AbilityEngine.startBeam(player, character, d, aim)
		return
	end
	-- check everything BEFORE committing either cost
	if isOnCooldown(player, "ENG_" .. slot) then return end
	if not spendEnergy(player, def) then return end   -- not enough energy
	startCooldown(player, "ENG_" .. slot, def.cooldown or 1)
	AbilityEngine.run(player, character, d, aim)
end

------------------------------------------------
-- PLAYER LIFECYCLE
------------------------------------------------
local function onCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			endConstruct(player)
			AbilityEngine.stopBeam(player)
		end)
	end
end
local function initPlayer(player)
	initEnergy(player)
	player.CharacterAdded:Connect(function(c) onCharacter(player, c) end)
	player.CharacterRemoving:Connect(function()
		endConstruct(player)
		AbilityEngine.stopBeam(player)
	end)
	if player.Character then onCharacter(player, player.Character) end
end
Players.PlayerAdded:Connect(initPlayer)
for _, p in ipairs(Players:GetPlayers()) do initPlayer(p) end

Players.PlayerRemoving:Connect(function(p)
	cooldowns[p] = nil
	endConstruct(p)
	AbilityEngine.cleanupPlayer(p)
end)

------------------------------------------------
-- MAIN
------------------------------------------------
event.OnServerEvent:Connect(function(player, ability, aim)
	if typeof(ability) ~= "string" then return end   -- exploit guard: a table here used to crash the concat below

	-- hold-to-fire beam control messages (from InputClient while holding).
	-- These are allowed even mid-death so a beam can always be released cleanly.
	if ability == "BEAM_AIM"  then AbilityEngine.updateBeamAim(player, aim); return end
	if ability == "BEAM_STOP" then AbilityEngine.stopBeam(player); return end

	local character = player.Character
	if not character then return end
	if not character:FindFirstChild("HumanoidRootPart") then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end    -- dead players can't cast

	runFromEngine(player, character, ability, aim)
end)
