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
local Shop = safeRequire(ReplicatedStorage:FindFirstChild("Campaign")
	and ReplicatedStorage.Campaign:FindFirstChild("ShopCatalog"))

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
local grantXpEvent = ensureBindable("GrantXP")   -- controller -> menu: (amount) per kill

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
local xpOf = {}       -- player -> accumulated campaign XP
local coinsOf = {}    -- player -> currency wallet
local ownedOf = {}    -- player -> { [characterName] = true } extra characters bought

local XP_PER_LEVEL   = 120
local XP_PER_KILL    = 6
local XP_PER_SEASON  = 120
local COINS_PER_KILL   = Shop and Shop.CoinsPerKill or 3
local COINS_PER_SEASON = Shop and Shop.CoinsPerSeason or 250
local function levelFromXp(xp) return 1 + math.floor((xp or 0) / XP_PER_LEVEL) end

-- owned set <-> "Name1,Name2" attribute string (attributes can't hold tables),
-- so CharacterSelect can read the player's unlocked roster additions.
local function ownedToString(set)
	local names = {}
	for name in pairs(set or {}) do names[#names + 1] = name end
	table.sort(names)
	return table.concat(names, ",")
end
local function pushOwnedAttr(player)
	player:SetAttribute("OwnedCharacters", ownedToString(ownedOf[player]))
end

local function loadProgress(player)
	local p, xp, coins, owned = 1, 0, 0, {}
	if store then
		local ok, data = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok then
			if type(data) == "number" then p = math.max(1, data)          -- legacy record
			elseif type(data) == "table" then
				p = math.max(1, data.progress or 1)
				xp = math.max(0, data.xp or 0)
				coins = math.max(0, data.coins or 0)
				if type(data.owned) == "table" then
					for _, name in ipairs(data.owned) do owned[name] = true end
				end
			end
		end
	end
	progress[player] = math.clamp(p, 1, #LADDER)
	xpOf[player] = xp
	coinsOf[player] = coins
	ownedOf[player] = owned
	player:SetAttribute("CampaignProgress", progress[player])
	player:SetAttribute("CampaignXP", xp)
	player:SetAttribute("PowerLevel", levelFromXp(xp))
	player:SetAttribute("Coins", coins)
	pushOwnedAttr(player)
end

local function saveProgress(player)
	if store and progress[player] then
		local ownedList = {}
		for name in pairs(ownedOf[player] or {}) do ownedList[#ownedList + 1] = name end
		pcall(function()
			store:SetAsync("p_" .. player.UserId, {
				progress = progress[player],
				xp = xpOf[player] or 0,
				coins = coinsOf[player] or 0,
				owned = ownedList,
			})
		end)
	end
end

-- award XP; persist only on level-up (DataStore rate limits — kills are frequent)
local function addXp(player, amount)
	if not xpOf[player] then return end
	local before = levelFromXp(xpOf[player])
	xpOf[player] = xpOf[player] + amount
	player:SetAttribute("CampaignXP", xpOf[player])
	local after = levelFromXp(xpOf[player])
	if after ~= before then
		player:SetAttribute("PowerLevel", after)   -- CharacterSelect re-reads this live
		saveProgress(player)
		menuEvent:FireClient(player, "leveled", { level = after, xp = xpOf[player] })
	end
end

-- award currency; live attribute + client HUD update, persisted lazily
local function addCoins(player, amount)
	if not coinsOf[player] or not amount or amount <= 0 then return end
	coinsOf[player] = coinsOf[player] + amount
	player:SetAttribute("Coins", coinsOf[player])
	menuEvent:FireClient(player, "coins", coinsOf[player])
end

-- route modules carry the per-faction mission briefings; cache the ones we load
local campaignFolder = ReplicatedStorage:FindFirstChild("Campaign")
local routeCache = {}
local function routeModule(routeName)
	if not routeName then return nil end
	if routeCache[routeName] ~= nil then return routeCache[routeName] or nil end
	local mod = safeRequire(campaignFolder and campaignFolder:FindFirstChild(routeName))
	routeCache[routeName] = mod or false
	return mod
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
		local route = (s.status == "built") and routeModule(s.route) or nil
		out[#out + 1] = {
			id = s.id, title = s.title, boss = s.boss, summary = s.summary,
			built = s.status == "built",
			ladderPos = pos,
			unlocked = (pos ~= nil) and (pos <= unlocked) or false,
			-- per-faction story briefing shown on the faction-select card
			briefing = route and route.Briefing or nil,
			villainBriefing = route and route.VillainBriefing or nil,
			heroBoss = route and route.BossName or s.boss,
			villainBoss = route and route.VillainBoss or nil,
		}
	end
	return out
end

-- payload the shop GUI renders: catalog items flagged owned/affordable
local function shopPayload(player)
	local owned = ownedOf[player] or {}
	local coins = coinsOf[player] or 0
	local out = { coins = coins, currency = Shop and Shop.Currency or "Coins", items = {} }
	if Shop then
		for _, item in ipairs(Shop.Items) do
			out.items[#out.items + 1] = {
				name = item.name, faction = item.faction, price = item.price, blurb = item.blurb,
				owned = owned[item.name] == true,
				affordable = coins >= item.price,
			}
		end
	end
	return out
end

-------------------------------------------------------------------
-- EVENTS
-------------------------------------------------------------------
menuEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "requestSeasons" then
		menuEvent:FireClient(player, "seasons", seasonsPayload(player))
	elseif action == "requestShop" then
		menuEvent:FireClient(player, "shop", shopPayload(player))
	elseif action == "buy" and Shop then
		local name = (type(payload) == "table") and payload.name or payload
		local item = (type(name) == "string") and Shop.get(name) or nil
		if not item then
			menuEvent:FireClient(player, "buyResult", { name = name, ok = false, reason = "unknown" })
		elseif (ownedOf[player] or {})[item.name] then
			menuEvent:FireClient(player, "buyResult", { name = item.name, ok = false, reason = "owned" })
		elseif (coinsOf[player] or 0) < item.price then
			menuEvent:FireClient(player, "buyResult", { name = item.name, ok = false, reason = "poor" })
		else
			coinsOf[player] = coinsOf[player] - item.price
			ownedOf[player][item.name] = true
			player:SetAttribute("Coins", coinsOf[player])
			pushOwnedAttr(player)                     -- CharacterSelect picks it up live
			saveProgress(player)                      -- purchases are worth a write
			menuEvent:FireClient(player, "buyResult", { name = item.name, ok = true, coins = coinsOf[player] })
			menuEvent:FireClient(player, "shop", shopPayload(player))
		end
	elseif action == "start" and type(payload) == "table" then
		local seasonId = payload.seasonId
		local faction = (payload.faction == "villain") and "villain" or "hero"
		local pos = ladderPos(seasonId)
		if pos and pos <= (progress[player] or 1) then
			startSeasonEvent:Fire(player, seasonId, faction)   -- the controller loads + runs it
		else
			menuEvent:FireClient(player, "denied", seasonId)
		end
	end
end)

-- controller reports a season cleared -> unlock the next ladder entry + award XP
seasonCompletedEvent.Event:Connect(function(seasonId)
	local pos = ladderPos(seasonId)
	if not pos then return end
	for _, player in ipairs(Players:GetPlayers()) do
		addXp(player, XP_PER_SEASON)
		addCoins(player, COINS_PER_SEASON)
		local cur = progress[player] or 1
		if pos >= cur and pos + 1 <= #LADDER then
			progress[player] = pos + 1
			player:SetAttribute("CampaignProgress", progress[player])
		end
		saveProgress(player)
		menuEvent:FireClient(player, "unlocked", { seasonId = seasonId, seasons = seasonsPayload(player) })
	end
end)

-- controller reports an enemy defeated -> small XP to everyone in the fight
grantXpEvent.Event:Connect(function(amount)
	for _, player in ipairs(Players:GetPlayers()) do
		addXp(player, amount or XP_PER_KILL)
		addCoins(player, COINS_PER_KILL)
	end
end)

Players.PlayerAdded:Connect(function(player)
	loadProgress(player)
	menuEvent:FireClient(player, "seasons", seasonsPayload(player))
end)
for _, p in ipairs(Players:GetPlayers()) do loadProgress(p) end
Players.PlayerRemoving:Connect(function(p) saveProgress(p); progress[p] = nil end)
