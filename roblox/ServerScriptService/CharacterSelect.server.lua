--[[
	CharacterSelect  (Script)
	WHERE IT GOES: ServerScriptService > CharacterSelect

	Lets a player pick a starting character for the campaign. On pick, the player
	spawns AS that character: their avatar is skinned with the character's themed
	look (CharacterModelFactory.applyTo) and their CharacterName attribute is set
	so the ability system uses that character's CharacterKit. The pick sticks
	across respawns.

	Movement/camera are never disrupted — we skin the player's real character
	rather than replacing the rig.

	Protocol (auto-created ReplicatedStorage.CharacterSelectEvent RemoteEvent):
	  server -> client "list"  { "Looney", "Leon", ... }   (offered on join)
	  client -> server <name>  (the player's choice)
	  server -> client "chosen" <name>                     (confirm)
]]

local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the campaign's starting roster (must match CharacterKits + CharacterModels keys)
local STARTERS = { "Looney", "Leon", "Chasm", "Frost", "Water Woman" }
local DEFAULT  = "Looney"

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

local chosen = {}   -- player -> character name

local function isAllowed(name)
	for _, n in ipairs(STARTERS) do if n == name then return true end end
	return false
end

-- apply the chosen character to a live character model
local function skin(player, character)
	local name = chosen[player] or DEFAULT
	player:SetAttribute("CharacterName", name)   -- the ability system reads this
	if Factory then
		-- the character may still be assembling; wait for the core parts
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
	-- offer the roster to the client
	task.defer(function() event:FireClient(player, "list", STARTERS) end)
end

event.OnServerEvent:Connect(function(player, choice)
	if type(choice) ~= "string" or not isAllowed(choice) then return end
	chosen[player] = choice
	player:SetAttribute("CharacterName", choice)
	event:FireClient(player, "chosen", choice)
	-- re-skin immediately (respawn also re-applies via CharacterAdded)
	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			skin(player, player.Character)
		else
			player:LoadCharacter()
		end
	else
		player:LoadCharacter()
	end
end)

Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerRemoving:Connect(function(p) chosen[p] = nil end)
