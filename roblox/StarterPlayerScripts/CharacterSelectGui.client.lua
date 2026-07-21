--[[
	CharacterSelectGui  (LocalScript)
	WHERE IT GOES: StarterPlayer > StarterPlayerScripts > CharacterSelectGui

	The starting-character picker for the campaign. Shows the roster the server
	offers (Looney, Leon, Chasm, Frost, Water Woman); clicking one tells the
	server, which spawns you as that character. Driven entirely by the
	CharacterSelectEvent RemoteEvent.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("CharacterSelectEvent", 30)
if not event then return end

-- accent tint per starting character (kept in sync with their theme)
local TINT = {
	Looney = Color3.fromRGB(240, 200, 60),
	Leon = Color3.fromRGB(255, 200, 120),
	Chasm = Color3.fromRGB(60, 170, 255),
	Frost = Color3.fromRGB(150, 220, 255),
	["Water Woman"] = Color3.fromRGB(60, 150, 235),
}
local BLURB = {
	Looney = "Rubber & toon force — slingshot, gatling arms, stunning finger gun.",
	Leon = "Ruler's mastery from hands & feet, and future-sight counters.",
	Chasm = "Kinetic energy balls that grow, rifts, and an untouchable energy state.",
	Frost = "Ice beam that slows then freezes, ice balls, and a shattering ward.",
	["Water Woman"] = "Water beam, water spheres, a tide ward, and lashing tentacles.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "CharacterSelectGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1); dim.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
dim.BackgroundTransparency = 0.25; dim.BorderSizePixel = 0; dim.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 46); title.Position = UDim2.new(0, 0, 0.12, 0)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextSize = 34
title.TextColor3 = Color3.fromRGB(240, 245, 255); title.Text = "CHOOSE YOUR HERO"; title.Parent = dim
local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, 0, 0, 22); sub.Position = UDim2.new(0, 0, 0.12, 46)
sub.BackgroundTransparency = 1; sub.Font = Enum.Font.Gotham; sub.TextSize = 15
sub.TextColor3 = Color3.fromRGB(150, 165, 190); sub.Text = "Your pick sets your look and your abilities."; sub.Parent = dim

local row = Instance.new("Frame")
row.Size = UDim2.new(0, 1000, 0, 300); row.Position = UDim2.new(0.5, -500, 0.5, -110)
row.AnchorPoint = Vector2.new(0, 0); row.BackgroundTransparency = 1; row.Parent = dim
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal; layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center; layout.Padding = UDim.new(0, 14); layout.Parent = row

local function makeCard(name)
	local tint = TINT[name] or Color3.fromRGB(90, 150, 255)
	local card = Instance.new("TextButton")
	card.Name = name; card.Size = UDim2.new(0, 184, 0, 268); card.AutoButtonColor = false
	card.BackgroundColor3 = Color3.fromRGB(16, 20, 30); card.BorderSizePixel = 0; card.Text = ""; card.Parent = row
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = card
	local stroke = Instance.new("UIStroke"); stroke.Color = tint; stroke.Thickness = 1.5; stroke.Transparency = 0.4; stroke.Parent = card
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(1, -20, 0, 120); swatch.Position = UDim2.new(0, 10, 0, 12)
	swatch.BackgroundColor3 = tint; swatch.BackgroundTransparency = 0.15; swatch.BorderSizePixel = 0; swatch.Parent = card
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 10); sc.Parent = swatch
	local initial = Instance.new("TextLabel")
	initial.Size = UDim2.fromScale(1, 1); initial.BackgroundTransparency = 1; initial.Font = Enum.Font.GothamBlack
	initial.TextSize = 64; initial.TextColor3 = Color3.fromRGB(12, 14, 20); initial.Text = string.sub(name, 1, 1); initial.Parent = swatch
	local nm = Instance.new("TextLabel")
	nm.Size = UDim2.new(1, -16, 0, 24); nm.Position = UDim2.new(0, 8, 0, 140); nm.BackgroundTransparency = 1
	nm.Font = Enum.Font.GothamBold; nm.TextSize = 18; nm.TextColor3 = Color3.fromRGB(240, 245, 255)
	nm.TextXAlignment = Enum.TextXAlignment.Left; nm.Text = name; nm.Parent = card
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -16, 0, 78); desc.Position = UDim2.new(0, 8, 0, 168); desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham; desc.TextSize = 13; desc.TextColor3 = Color3.fromRGB(160, 175, 200)
	desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true; desc.Text = BLURB[name] or ""; desc.Parent = card

	card.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0 }):Play()
		TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(24, 30, 44) }):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.4 }):Play()
		TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(16, 20, 30) }):Play()
	end)
	card.Activated:Connect(function()
		event:FireServer(name)
		gui.Enabled = false
	end)
	return card
end

local built = false
event.OnClientEvent:Connect(function(kind, data)
	if kind == "list" and not built then
		built = true
		for _, name in ipairs(data) do makeCard(name) end
		gui.Enabled = true
	elseif kind == "chosen" then
		gui.Enabled = false
	end
end)
