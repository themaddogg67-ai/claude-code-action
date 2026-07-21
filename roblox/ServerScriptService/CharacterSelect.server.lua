--[[
	CharacterSelect  (Script)
	WHERE IT GOES: ServerScriptService > CharacterSelect

	Applies the player's chosen FACTION (Hero or Villain) + character: it sets
	CharacterName (so the ability system uses that kit), skins the avatar with
	the character's themed look (CharacterModelFactory.applyTo), and — for the
	starting VILLAINS — applies an "at their weakest" damage penalty via the
	ArmorDamageMult attribute the ability system already reads. Works for solo
	and multiplayer campaign alike. The pick sticks across respawns.

	Rosters (must match CharacterKits + CharacterModels keys):
	  Heroes:   Looney, Leon, Chasm, Frost, Water Woman
	  Villains: Bulldozer, Reddon, Erik, Toxic   (start weakened)

	Protocol (auto-created ReplicatedStorage.CharacterSelectEvent RemoteEvent):
	  server -> client "rosters" { heroes = {...}, villains = {...} }   (on join)
	  client -> server { name = "Erik", faction = "villain" }           (the pick)
	  server -> client "chosen" <name>                                  (confirm)
]]

local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HERO_STARTERS    = { "Looney", "Leon", "Chasm", "Frost", "Water Woman" }
local VILLAIN_STARTERS = { "Bulldozer", "Reddon", "Erik", "Toxic" }
local DEFAULT_HERO     = "Looney"
local VILLAIN_WEAK     = 0.6   -- starting villains deal 60% damage ("at their weakest")

local function safeRequire(inst)
	if not inst then return nil end
	local ok, m = pcall(require, inst)
	return ok and m or nil
end
local Factory = safeRequire(ServerStorage:FindFirstChild("CharacterModelFactory"))
local Shop = safeRequire(ReplicatedStorage:FindFirstChild("Campaign")
	and ReplicatedStorage.Campaign:FindFirstChild("ShopCatalog"))
local Warriors = safeRequire(ReplicatedStorage:FindFirstChild("Campaign")
	and ReplicatedStorage.Campaign:FindFirstChild("WarriorsOfTheWorld"))

local event = ReplicatedStorage:FindFirstChild("CharacterSelectEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "CharacterSelectEvent"
	event.Parent = ReplicatedStorage
end

local chosen = {}   -- player -> { character = name, faction = "hero"|"villain" }

local function inList(list, name)
	for _, n in ipairs(list) do if n == name then return true end end
	return false
end

-- names the player has unlocked in the shop, split from the "OwnedCharacters"
-- attribute CampaignMenu writes ("Name1,Name2"), filtered to a faction.
local function ownedFor(player, faction)
	local out = {}
	if not Shop then return out end
	local raw = player:GetAttribute("OwnedCharacters")
	if type(raw) ~= "string" or raw == "" then return out end
	for name in string.gmatch(raw, "[^,]+") do
		if Shop.factionOf(name) == faction then out[#out + 1] = name end
	end
	return out
end

-- full pickable roster for a faction = free starters + any owned extras
local function rosterFor(faction, player)
	local base = (faction == "villain") and VILLAIN_STARTERS or HERO_STARTERS
	local list = {}
	for _, n in ipairs(base) do list[#list + 1] = n end
	if player then
		for _, n in ipairs(ownedFor(player, faction)) do
			if not inList(list, n) then list[#list + 1] = n end
		end
	end
	return list
end
-- the "Warriors of the World" are heroes unlocked by playing Season 3+, pickable
-- while the season you're starting is inside each Warrior's story window.
local function warriorAllowed(name, faction, seasonId)
	if not Warriors or faction ~= "hero" then return false end
	return Warriors.isAvailable(name, seasonId)
end
local function isAllowed(name, faction, player, seasonId)
	if inList(rosterFor(faction, player), name) then return true end
	return warriorAllowed(name, faction, seasonId)
end

-- outgoing-damage multiplier from PowerLevel (set by CampaignMenu's XP system).
-- Villains climb from their weak start toward full strength; heroes get a mild
-- scaling bonus. Applied via ArmorDamageMult, which the ability system reads.
local function powerMult(faction, level)
	level = level or 1
	if faction == "villain" then return math.clamp(VILLAIN_WEAK + (level - 1) * 0.08, VILLAIN_WEAK, 1.0) end
	return math.clamp(1 + (level - 1) * 0.03, 1, 1.3)
end

-- set attributes + skin the live character to the chosen faction/character
local function skin(player, character)
	local pick = chosen[player]
	local name = (pick and pick.character) or DEFAULT_HERO
	local faction = (pick and pick.faction) or "hero"
	player:SetAttribute("CharacterName", name)             -- ability kit
	player:SetAttribute("Faction", faction)
	-- villain "at their weakest", scaling up with PowerLevel — a persistent
	-- outgoing-damage multiplier the ability system multiplies in (separate from
	-- buff-driven DamageMult).
	player:SetAttribute("ArmorDamageMult", powerMult(faction, player:GetAttribute("PowerLevel")))
	if Factory then
		character:WaitForChild("HumanoidRootPart", 5)
		character:WaitForChild("Head", 5)
		pcall(function() Factory.applyTo(character, name) end)
	end
end

local function onCharacter(player, character)
	task.defer(skin, player, character)
end
local function sendRosters(player)
	event:FireClient(player, "rosters", {
		heroes = rosterFor("hero", player),
		villains = rosterFor("villain", player),
	})
end
local function setup(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then onCharacter(player, player.Character) end
	-- re-apply the damage multiplier live when the player levels up
	player:GetAttributeChangedSignal("PowerLevel"):Connect(function()
		local faction = player:GetAttribute("Faction") or "hero"
		player:SetAttribute("ArmorDamageMult", powerMult(faction, player:GetAttribute("PowerLevel")))
	end)
	-- refresh the roster whenever the player unlocks a new character in the shop
	player:GetAttributeChangedSignal("OwnedCharacters"):Connect(function() sendRosters(player) end)
	task.defer(function() sendRosters(player) end)
end

event.OnServerEvent:Connect(function(player, payload)
	local name, faction, seasonId
	if type(payload) == "table" then
		name = payload.name; faction = payload.faction; seasonId = payload.seasonId
	elseif type(payload) == "string" then
		name = payload; faction = "hero"
	end
	if type(name) ~= "string" then return end
	faction = (faction == "villain") and "villain" or "hero"
	if not isAllowed(name, faction, player, seasonId) then return end

	chosen[player] = { character = name, faction = faction }
	event:FireClient(player, "chosen", name)

	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then skin(player, player.Character) else player:LoadCharacter() end
	else
		player:LoadCharacter()
	end
end)

Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerRemoving:Connect(function(p) chosen[p] = nil end)
