--[[
	CampaignHud  (LocalScript)
	WHERE IT GOES: StarterPlayer > StarterPlayerScripts > CampaignHud

	Shows the current campaign objective: stage x/9, the district, the objective
	line, and a live status (enemies remaining / "reach the marker" / boss /
	victory). Driven entirely by the server's CampaignEvent RemoteEvent, so it
	needs no configuration.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("CampaignEvent", 30)
if not event then return end

local ACCENT = Color3.fromRGB(60, 150, 255)
local GOLD   = Color3.fromRGB(230, 195, 100)
local RED    = Color3.fromRGB(255, 90, 80)
local GREEN  = Color3.fromRGB(90, 255, 150)

-- ---- UI ----
local gui = Instance.new("ScreenGui")
gui.Name = "CampaignHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 420, 0, 92)
panel.Position = UDim2.new(0.5, -210, 0, 18)
panel.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT; stroke.Thickness = 1.5; stroke.Transparency = 0.4; stroke.Parent = panel
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0, 4, 1, -16); accentBar.Position = UDim2.new(0, 0, 0, 8)
accentBar.BackgroundColor3 = ACCENT; accentBar.BorderSizePixel = 0; accentBar.Parent = panel
local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(0, 4); barCorner.Parent = accentBar

local eyebrow = Instance.new("TextLabel")
eyebrow.Size = UDim2.new(1, -28, 0, 16); eyebrow.Position = UDim2.new(0, 16, 0, 12)
eyebrow.BackgroundTransparency = 1; eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.Font = Enum.Font.GothamBold; eyebrow.TextSize = 12
eyebrow.TextColor3 = Color3.fromRGB(150, 170, 200)
eyebrow.Text = "OBJECTIVE"; eyebrow.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -28, 0, 24); title.Position = UDim2.new(0, 16, 0, 28)
title.BackgroundTransparency = 1; title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold; title.TextSize = 18; title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.Text = "Awaiting deployment…"; title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -28, 0, 18); status.Position = UDim2.new(0, 16, 0, 56)
status.BackgroundTransparency = 1; status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham; status.TextSize = 14; status.TextColor3 = Color3.fromRGB(170, 185, 210)
status.Text = ""; status.Parent = panel

local progress = Instance.new("TextLabel")
progress.Size = UDim2.new(0, 90, 0, 16); progress.Position = UDim2.new(1, -104, 0, 12)
progress.BackgroundTransparency = 1; progress.TextXAlignment = Enum.TextXAlignment.Right
progress.Font = Enum.Font.GothamBold; progress.TextSize = 12; progress.TextColor3 = ACCENT
progress.Text = ""; progress.Parent = panel

-- big centered banner for stage changes / victory
local banner = Instance.new("TextLabel")
banner.Size = UDim2.new(1, 0, 0, 60); banner.Position = UDim2.new(0, 0, 0.32, 0)
banner.BackgroundTransparency = 1; banner.Font = Enum.Font.GothamBlack; banner.TextSize = 44
banner.TextColor3 = GOLD; banner.TextTransparency = 1; banner.TextStrokeTransparency = 0.5
banner.Text = ""; banner.Parent = gui

local function flashBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color or GOLD
	banner.TextTransparency = 1
	banner.Position = UDim2.new(0, 0, 0.30, 0)
	TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	task.delay(1.9, function()
		TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	end)
end

-- ---- boss health bar (bottom center, shown only during a boss fight) ----
local bossWrap = Instance.new("Frame")
bossWrap.Size = UDim2.new(0, 620, 0, 54); bossWrap.Position = UDim2.new(0.5, -310, 1, -84)
bossWrap.BackgroundTransparency = 1; bossWrap.Visible = false; bossWrap.Parent = gui
local bossName = Instance.new("TextLabel")
bossName.Size = UDim2.new(1, 0, 0, 20); bossName.BackgroundTransparency = 1
bossName.Font = Enum.Font.GothamBold; bossName.TextSize = 16; bossName.TextColor3 = Color3.fromRGB(240, 245, 255)
bossName.Text = ""; bossName.Parent = bossWrap
local bossBg = Instance.new("Frame")
bossBg.Size = UDim2.new(1, 0, 0, 22); bossBg.Position = UDim2.new(0, 0, 0, 26)
bossBg.BackgroundColor3 = Color3.fromRGB(20, 12, 14); bossBg.BorderSizePixel = 0; bossBg.Parent = bossWrap
local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0, 6); bbc.Parent = bossBg
local bbs = Instance.new("UIStroke"); bbs.Color = Color3.fromRGB(120, 20, 24); bbs.Thickness = 1.5; bbs.Parent = bossBg
local bossFill = Instance.new("Frame")
bossFill.Size = UDim2.new(1, 0, 1, 0); bossFill.BackgroundColor3 = Color3.fromRGB(210, 45, 40)
bossFill.BorderSizePixel = 0; bossFill.Parent = bossBg
local bfc = Instance.new("UICorner"); bfc.CornerRadius = UDim.new(0, 6); bfc.Parent = bossFill
local function setBoss(name, frac, enraged)
	bossWrap.Visible = true
	bossName.Text = (enraged and "⚠ " or "") .. "★ " .. (name or "Boss") .. (enraged and "  —  ENRAGED" or "")
	bossName.TextColor3 = enraged and Color3.fromRGB(255, 120, 90) or Color3.fromRGB(240, 245, 255)
	bossFill.BackgroundColor3 = enraged and Color3.fromRGB(255, 90, 40) or Color3.fromRGB(210, 45, 40)
	TweenService:Create(bossFill, TweenInfo.new(0.25), { Size = UDim2.new(math.clamp(frac or 0, 0, 1), 0, 1, 0) }):Play()
end

local lastStage = -1

local function render(data)
	if not data or not data.stage and data.state ~= "bosshp" then return end
	if data.state == "bosshp" then
		setBoss(data.bossName, data.frac, data.enraged)
		return
	end
	if data.state == "victory" or data.state == "bossdown" or data.state == "cleared"
		or data.state == "fighting" then
		bossWrap.Visible = false
	end
	if data.state == "idle" then
		title.Text = "Awaiting deployment…"; status.Text = ""; progress.Text = ""
		return
	end
	if data.state == "victory" then
		eyebrow.Text = "CAMPAIGN COMPLETE"
		title.Text = "Metro City is free."
		status.Text = "Manderin has fallen."
		status.TextColor3 = GREEN
		progress.Text = "★"
		stroke.Color = GOLD; accentBar.BackgroundColor3 = GOLD
		flashBanner("METRO CITY IS FREE", GOLD)
		return
	end

	eyebrow.Text = data.boss and "FINAL CONFRONTATION" or ("DISTRICT — " .. string.upper(data.district or ""))
	title.Text = data.objective or ""
	progress.Text = "STAGE " .. data.stage .. "/" .. data.total

	if data.state == "cleared" then
		status.Text = "Area secured — reach the marker ►"
		status.TextColor3 = GREEN
		stroke.Color = GREEN; accentBar.BackgroundColor3 = GREEN
	elseif data.state == "boss" or data.boss then
		status.Text = "Manderin — HP bar above the boss"
		status.TextColor3 = RED
		stroke.Color = RED; accentBar.BackgroundColor3 = RED
	else
		status.Text = "Enemies remaining: " .. tostring(data.enemiesLeft or 0)
		status.TextColor3 = Color3.fromRGB(255, 160, 120)
		stroke.Color = ACCENT; accentBar.BackgroundColor3 = ACCENT
	end

	if data.stage ~= lastStage then
		lastStage = data.stage
		if data.boss then
			flashBanner("MANDERIN", RED)
		else
			flashBanner("STAGE " .. data.stage .. " — " .. (data.district or ""), ACCENT)
		end
	end
end

event.OnClientEvent:Connect(render)
-- ask the server for the current state on (re)spawn
task.defer(function() event:FireServer("requestState") end)
