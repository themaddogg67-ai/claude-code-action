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
local function rosterFor(faction) return (faction == "villain") and VILLAIN_STARTERS or HERO_STARTERS end
local function isAllowed(name, faction) return inList(rosterFor(faction), name) end

-- set attributes + skin the live character to the chosen faction/character
local function skin(player, character)
	local pick = chosen[player]
	local name = (pick and pick.character) or DEFAULT_HERO
	local faction = (pick and pick.faction) or "hero"
	player:SetAttribute("CharacterName", name)             -- ability kit
	player:SetAttribute("Faction", faction)
	-- villain "at their weakest": a persistent outgoing-damage multiplier the
	-- ability system multiplies in (separate from buff-driven DamageMult).
	player:SetAttribute("ArmorDamageMult", (faction == "villain") and VILLAIN_WEAK or 1)
	if Factory then
		character:WaitForChild("HumanoidRootPart", 5)
		character:WaitForChild("Head", 5)
		pcall(function() Factory.applyTo(character, name) end)
	end
end

local function onCharacter(player, character)
	task.defer(skin, player, character)
end
local function setup(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then onCharacter(player, player.Character) end
	task.defer(function() event:FireClient(player, "rosters", { heroes = HERO_STARTERS, villains = VILLAIN_STARTERS }) end)
end

event.OnServerEvent:Connect(function(player, payload)
	local name, faction
	if type(payload) == "table" then
		name = payload.name; faction = payload.faction
	elseif type(payload) == "string" then
		name = payload; faction = "hero"
	end
	if type(name) ~= "string" then return end
	faction = (faction == "villain") and "villain" or "hero"
	if not isAllowed(name, faction) then return end

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
