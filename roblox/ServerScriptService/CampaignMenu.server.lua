--[[
	CampaignMenu  (Script)
	WHERE IT GOES: ServerScriptService > CampaignMenu

	The season-select back end. Tracks each player's campaign PROGRESS (which
	seasons they've unlocked), serves the season list to the menu GUI, and starts
	the chosen season by handing off to the CampaignController.

	Progression: the playable "ladder" is the built seasons in order (Season 1
	Swamplands → 5 Gildonia → 7 Ruined City → 8 Metro City → 10 Quantum City). A
	new player has only the first unlocked; completing a season unlocks the next.
	Progress persists via DataStore (falls back to in-memory if DataStores are
	off, e.g. Studio without API access).

	Talks to the controller over two BindableEvents in ServerStorage
	(auto-created by the controller): fires StartCampaignSeason to begin, listens
	to SeasonCompleted to grant the next unlock.

	Client channel: ReplicatedStorage.CampaignMenuEvent (auto-created).
]]

local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

local function safeRequire(inst)
	if not inst then return nil end
	local ok, m = pcall(require, inst)
	return ok and m or nil
end
local Registry = safeRequire(ReplicatedStorage:FindFirstChild("Campaign")
	and ReplicatedStorage.Campaign:FindFirstChild("CampaignRegistry"))
if not Registry then
	warn("CampaignMenu: CampaignRegistry missing — menu disabled.")
	return
end

-- client + server channels
local menuEvent = ReplicatedStorage:FindFirstChild("CampaignMenuEvent")
if not menuEvent then
	menuEvent = Instance.new("RemoteEvent"); menuEvent.Name = "CampaignMenuEvent"; menuEvent.Parent = ReplicatedStorage
end
local function ensureBindable(name)
	local b = ServerStorage:FindFirstChild(name)
	if not b then b = Instance.new("BindableEvent"); b.Name = name; b.Parent = ServerStorage end
	return b
end
local startSeasonEvent = ensureBindable("StartCampaignSeason")
local seasonCompletedEvent = ensureBindable("SeasonCompleted")

-- DataStore (guarded — Studio without API access will error on GetAsync)
local store
pcall(function() store = DataStoreService:GetDataStore("CampaignProgress_v1") end)

-------------------------------------------------------------------
-- THE PLAYABLE LADDER (built seasons, in id order)
-------------------------------------------------------------------
local function buildLadder()
	local built = Registry.built()
	table.sort(built, function(a, b) return a.id < b.id end)
	return built
end
local LADDER = buildLadder()

local function ladderPos(seasonId)
	for i, s in ipairs(LADDER) do if s.id == seasonId then return i end end
	return nil
end

local progress = {}   -- player -> number of ladder entries unlocked (>=1)

local function loadProgress(player)
	local p = 1
	if store then
		local ok, data = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(data) == "number" then p = math.max(1, data) end
	end
	progress[player] = math.clamp(p, 1, #LADDER)
	player:SetAttribute("CampaignProgress", progress[player])
end

local function saveProgress(player)
	if store and progress[player] then
		pcall(function() store:SetAsync("p_" .. player.UserId, progress[player]) end)
	end
end

-- payload the menu GUI renders (every registry season, flagged)
local function seasonsPayload(player)
	local unlocked = progress[player] or 1
	local out = {}
	local all = {}
	for _, s in ipairs(Registry.Seasons) do all[#all + 1] = s end
	table.sort(all, function(a, b) return a.id < b.id end)
	for _, s in ipairs(all) do
		local pos = ladderPos(s.id)
		out[#out + 1] = {
			id = s.id, title = s.title, boss = s.boss, summary = s.summary,
			built = s.status == "built",
			ladderPos = pos,
			unlocked = (pos ~= nil) and (pos <= unlocked) or false,
		}
	end
	return out
end

-------------------------------------------------------------------
-- EVENTS
-------------------------------------------------------------------
menuEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "requestSeasons" then
		menuEvent:FireClient(player, "seasons", seasonsPayload(player))
	elseif action == "start" and type(payload) == "table" then
		local seasonId = payload.seasonId
		local pos = ladderPos(seasonId)
		if pos and pos <= (progress[player] or 1) then
			startSeasonEvent:Fire(player, seasonId)   -- the controller loads + runs it
		else
			menuEvent:FireClient(player, "denied", seasonId)
		end
	end
end)

-- controller reports a season cleared -> unlock the next ladder entry for everyone present
seasonCompletedEvent.Event:Connect(function(seasonId)
	local pos = ladderPos(seasonId)
	if not pos then return end
	for _, player in ipairs(Players:GetPlayers()) do
		local cur = progress[player] or 1
		if pos >= cur and pos + 1 <= #LADDER then
			progress[player] = pos + 1
			player:SetAttribute("CampaignProgress", progress[player])
			saveProgress(player)
			menuEvent:FireClient(player, "unlocked", { seasonId = seasonId, seasons = seasonsPayload(player) })
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	loadProgress(player)
	menuEvent:FireClient(player, "seasons", seasonsPayload(player))
end)
for _, p in ipairs(Players:GetPlayers()) do loadProgress(p) end
Players.PlayerRemoving:Connect(function(p) saveProgress(p); progress[p] = nil end)
