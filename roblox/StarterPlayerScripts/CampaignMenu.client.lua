--[[
	CampaignMenu  (LocalScript)
	WHERE IT GOES: StarterPlayer > StarterPlayerScripts > CampaignMenu

	The front-end flow: a main menu with CAMPAIGN → season select (only unlocked
	seasons are playable; completing one unlocks the next) → character select →
	the season begins.

	Data comes from the server: CampaignMenuEvent ("seasons"/"unlocked") for the
	season ladder + unlock state, and CharacterSelectEvent ("list") for the
	starting-character roster. Picking a hero fires CharacterSelectEvent (so the
	existing CharacterSelect morph runs) and CampaignMenuEvent "start".
	Replaces the standalone CharacterSelectGui.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local menuEvent = ReplicatedStorage:WaitForChild("CampaignMenuEvent", 30)
local charEvent = ReplicatedStorage:WaitForChild("CharacterSelectEvent", 30)
if not menuEvent then return end

local INK    = Color3.fromRGB(240, 245, 255)
local MUTED  = Color3.fromRGB(150, 165, 190)
local ACCENT = Color3.fromRGB(80, 160, 255)
local GOLD   = Color3.fromRGB(235, 195, 100)
local LOCK   = Color3.fromRGB(90, 96, 110)
local PANEL  = Color3.fromRGB(16, 20, 30)

local TINT = {
	Looney = Color3.fromRGB(240, 200, 60), Leon = Color3.fromRGB(255, 200, 120),
	Chasm = Color3.fromRGB(60, 170, 255), Frost = Color3.fromRGB(150, 220, 255),
	["Water Woman"] = Color3.fromRGB(60, 150, 235),
}
local CHAR_BLURB = {
	Looney = "Rubber & toon force — slingshot, gatling arms, stunning finger gun.",
	Leon = "Ruler's mastery from hands & feet, and future-sight counters.",
	Chasm = "Kinetic energy balls that grow, rifts, and an untouchable state.",
	Frost = "Ice beam that slows then freezes, ice balls, a shattering ward.",
	["Water Woman"] = "Water beam, water spheres, a tide ward, lashing tentacles.",
}

local seasonsData, roster = nil, nil
local chosenSeason = nil

-- ---------------- UI scaffold ----------------
local gui = Instance.new("ScreenGui")
gui.Name = "CampaignMenu"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
gui.DisplayOrder = 60; gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1); dim.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
dim.BackgroundTransparency = 0.15; dim.BorderSizePixel = 0; dim.Parent = gui

local function label(parent, text, size, color, y, font)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, size + 6); l.Position = UDim2.new(0, 0, 0, y)
	l.BackgroundTransparency = 1; l.Font = font or Enum.Font.GothamBold; l.TextSize = size
	l.TextColor3 = color or INK; l.Text = text; l.Parent = parent
	return l
end
local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = inst; return c end
local function stroke(inst, col, t) local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = 1.5; s.Transparency = t or 0.4; s.Parent = inst; return s end

-- panels
local mainP = Instance.new("Frame"); mainP.Size = UDim2.fromScale(1, 1); mainP.BackgroundTransparency = 1; mainP.Parent = dim
local seasonP = Instance.new("Frame"); seasonP.Size = UDim2.fromScale(1, 1); seasonP.BackgroundTransparency = 1; seasonP.Visible = false; seasonP.Parent = dim
local charP = Instance.new("Frame"); charP.Size = UDim2.fromScale(1, 1); charP.BackgroundTransparency = 1; charP.Visible = false; charP.Parent = dim

local function show(panel)
	mainP.Visible = (panel == mainP); seasonP.Visible = (panel == seasonP); charP.Visible = (panel == charP)
	gui.Enabled = true
end

-- ---------------- MAIN ----------------
label(mainP, "WARRIORS & VILLAINS", 30, GOLD, 0, Enum.Font.GothamBlack).Position = UDim2.new(0, 0, 0.26, 0)
label(mainP, "OF THE OMNIVERSE", 22, INK, 0).Position = UDim2.new(0, 0, 0.26, 40)
local playBtn = Instance.new("TextButton")
playBtn.Size = UDim2.new(0, 300, 0, 64); playBtn.Position = UDim2.new(0.5, -150, 0.5, 20); playBtn.AutoButtonColor = false
playBtn.BackgroundColor3 = ACCENT; playBtn.Text = "CAMPAIGN"; playBtn.Font = Enum.Font.GothamBlack; playBtn.TextSize = 26
playBtn.TextColor3 = Color3.fromRGB(8, 12, 20); playBtn.Parent = mainP
corner(playBtn, 12)
playBtn.MouseEnter:Connect(function() TweenService:Create(playBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(120, 185, 255) }):Play() end)
playBtn.MouseLeave:Connect(function() TweenService:Create(playBtn, TweenInfo.new(0.12), { BackgroundColor3 = ACCENT }):Play() end)
playBtn.Activated:Connect(function()
	menuEvent:FireServer("requestSeasons")
	show(seasonP)
end)

-- ---------------- SEASON SELECT ----------------
label(seasonP, "SELECT A SEASON", 26, INK, 0, Enum.Font.GothamBlack).Position = UDim2.new(0, 0, 0.1, 0)
label(seasonP, "Complete a season to unlock the next.", 15, MUTED, 0, Enum.Font.Gotham).Position = UDim2.new(0, 0, 0.1, 34)
local seasonRow = Instance.new("Frame")
seasonRow.Size = UDim2.new(0, 1120, 0, 260); seasonRow.Position = UDim2.new(0.5, -560, 0.5, -100); seasonRow.BackgroundTransparency = 1; seasonRow.Parent = seasonP
local sLayout = Instance.new("UIListLayout")
sLayout.FillDirection = Enum.FillDirection.Horizontal; sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sLayout.VerticalAlignment = Enum.VerticalAlignment.Center; sLayout.Padding = UDim.new(0, 12); sLayout.Parent = seasonRow
local sBack = Instance.new("TextButton")
sBack.Size = UDim2.new(0, 120, 0, 34); sBack.Position = UDim2.new(0.5, -60, 1, -70); sBack.BackgroundColor3 = PANEL
sBack.Text = "◀ Back"; sBack.Font = Enum.Font.GothamBold; sBack.TextSize = 15; sBack.TextColor3 = MUTED; sBack.Parent = seasonP
corner(sBack, 8); sBack.Activated:Connect(function() show(mainP) end)

local function renderSeasons(data)
	for _, ch in ipairs(seasonRow:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
	-- built seasons ordered by ladder position
	local built = {}
	for _, s in ipairs(data) do if s.ladderPos then built[#built + 1] = s end end
	table.sort(built, function(a, b) return a.ladderPos < b.ladderPos end)
	for _, s in ipairs(built) do
		local card = Instance.new("TextButton")
		card.Size = UDim2.new(0, 210, 0, 230); card.AutoButtonColor = false
		card.BackgroundColor3 = PANEL; card.Text = ""; card.Parent = seasonRow
		corner(card, 12)
		local playable = s.unlocked
		local edge = playable and ACCENT or LOCK
		local st = stroke(card, edge, 0.35)
		label(card, "SEASON " .. s.ladderPos, 14, playable and ACCENT or LOCK, 14, Enum.Font.GothamBlack)
		local ttl = label(card, s.title, 18, playable and INK or LOCK, 40); ttl.TextWrapped = true; ttl.Size = UDim2.new(1, -20, 0, 44); ttl.Position = UDim2.new(0, 10, 0, 40)
		label(card, "Boss: " .. (s.boss or "?"), 13, MUTED, 92, Enum.Font.Gotham)
		local body = Instance.new("TextLabel")
		body.Size = UDim2.new(1, -20, 0, 70); body.Position = UDim2.new(0, 10, 0, 118); body.BackgroundTransparency = 1
		body.Font = Enum.Font.Gotham; body.TextSize = 12; body.TextColor3 = MUTED; body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left; body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = playable and (s.summary or "") or "🔒  Locked — clear the previous season."; body.Parent = card
		if playable then
			card.MouseEnter:Connect(function() TweenService:Create(st, TweenInfo.new(0.12), { Transparency = 0 }):Play() end)
			card.MouseLeave:Connect(function() TweenService:Create(st, TweenInfo.new(0.12), { Transparency = 0.35 }):Play() end)
			card.Activated:Connect(function() chosenSeason = s.id; show(charP) end)
		end
	end
	-- a "coming soon" card if planned seasons exist
	local planned = 0
	for _, s in ipairs(data) do if not s.built then planned = planned + 1 end end
	if planned > 0 then
		local soon = Instance.new("Frame")
		soon.Size = UDim2.new(0, 210, 0, 230); soon.BackgroundColor3 = Color3.fromRGB(12, 14, 20); soon.Parent = seasonRow
		corner(soon, 12); stroke(soon, LOCK, 0.6)
		label(soon, "MORE", 14, LOCK, 90, Enum.Font.GothamBlack)
		label(soon, planned .. " seasons coming soon", 13, MUTED, 116, Enum.Font.Gotham)
	end
end

-- ---------------- CHARACTER SELECT ----------------
label(charP, "CHOOSE YOUR HERO", 26, INK, 0, Enum.Font.GothamBlack).Position = UDim2.new(0, 0, 0.12, 0)
label(charP, "Your pick sets your look and your abilities.", 15, MUTED, 0, Enum.Font.Gotham).Position = UDim2.new(0, 0, 0.12, 34)
local charRow = Instance.new("Frame")
charRow.Size = UDim2.new(0, 1000, 0, 280); charRow.Position = UDim2.new(0.5, -500, 0.5, -100); charRow.BackgroundTransparency = 1; charRow.Parent = charP
local cLayout = Instance.new("UIListLayout")
cLayout.FillDirection = Enum.FillDirection.Horizontal; cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cLayout.VerticalAlignment = Enum.VerticalAlignment.Center; cLayout.Padding = UDim.new(0, 14); cLayout.Parent = charRow
local cBack = Instance.new("TextButton")
cBack.Size = UDim2.new(0, 120, 0, 34); cBack.Position = UDim2.new(0.5, -60, 1, -70); cBack.BackgroundColor3 = PANEL
cBack.Text = "◀ Back"; cBack.Font = Enum.Font.GothamBold; cBack.TextSize = 15; cBack.TextColor3 = MUTED; cBack.Parent = charP
corner(cBack, 8); cBack.Activated:Connect(function() show(seasonP) end)

local charBuilt = false
local function renderCharacters()
	if charBuilt or not roster then return end
	charBuilt = true
	for _, name in ipairs(roster) do
		local tint = TINT[name] or ACCENT
		local card = Instance.new("TextButton")
		card.Size = UDim2.new(0, 184, 0, 250); card.AutoButtonColor = false; card.BackgroundColor3 = PANEL; card.Text = ""; card.Parent = charRow
		corner(card, 12); local st = stroke(card, tint, 0.4)
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(1, -20, 0, 110); swatch.Position = UDim2.new(0, 10, 0, 12); swatch.BackgroundColor3 = tint; swatch.BackgroundTransparency = 0.15; swatch.Parent = card
		corner(swatch, 10)
		local ini = Instance.new("TextLabel"); ini.Size = UDim2.fromScale(1, 1); ini.BackgroundTransparency = 1; ini.Font = Enum.Font.GothamBlack
		ini.TextSize = 56; ini.TextColor3 = Color3.fromRGB(12, 14, 20); ini.Text = string.sub(name, 1, 1); ini.Parent = swatch
		label(card, name, 18, INK, 130).Position = UDim2.new(0, 10, 0, 130)
		local body = Instance.new("TextLabel")
		body.Size = UDim2.new(1, -16, 0, 84); body.Position = UDim2.new(0, 8, 0, 158); body.BackgroundTransparency = 1
		body.Font = Enum.Font.Gotham; body.TextSize = 13; body.TextColor3 = MUTED; body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left; body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = CHAR_BLURB[name] or ""; body.Parent = card
		card.MouseEnter:Connect(function() TweenService:Create(st, TweenInfo.new(0.12), { Transparency = 0 }):Play() end)
		card.MouseLeave:Connect(function() TweenService:Create(st, TweenInfo.new(0.12), { Transparency = 0.4 }):Play() end)
		card.Activated:Connect(function()
			if charEvent then charEvent:FireServer(name) end                 -- morph + set kit
			menuEvent:FireServer("start", { seasonId = chosenSeason, character = name })
			gui.Enabled = false
		end)
	end
end

-- ---------------- season-complete overlay ----------------
local function seasonComplete()
	local ov = label(dim, "SEASON COMPLETE", 40, GOLD, 0, Enum.Font.GothamBlack)
	ov.Position = UDim2.new(0, 0, 0.34, 0); ov.Parent = gui
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 240, 0, 52); btn.Position = UDim2.new(0.5, -120, 0.5, 20); btn.BackgroundColor3 = GOLD
	btn.Text = "RETURN TO MENU"; btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.TextColor3 = Color3.fromRGB(20, 16, 8); btn.Parent = gui
	corner(btn, 10)
	gui.Enabled = true
	btn.Activated:Connect(function() ov:Destroy(); btn:Destroy(); charBuilt = false; show(mainP) end)
end

-- ---------------- wiring ----------------
menuEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "seasons" then
		seasonsData = data; renderSeasons(data)
	elseif kind == "unlocked" then
		seasonsData = data.seasons; if seasonP.Visible then renderSeasons(seasonsData) end
	end
end)
if charEvent then
	charEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "list" then roster = data; renderCharacters() end
	end)
end
-- listen for victory (from CampaignHud's CampaignEvent) to offer return-to-menu
local campEvent = ReplicatedStorage:FindFirstChild("CampaignEvent")
if campEvent then
	campEvent.OnClientEvent:Connect(function(d)
		if type(d) == "table" and d.state == "victory" then task.delay(2.5, seasonComplete) end
	end)
end

show(mainP)
