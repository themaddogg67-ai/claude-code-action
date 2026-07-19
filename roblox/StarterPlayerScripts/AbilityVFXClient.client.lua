--[[
	AbilityVFXClient  (LocalScript)
	WHERE IT GOES: StarterPlayer > StarterPlayerScripts > AbilityVFXClient   (NEW script)

	Client-side polish layer for every ability: camera shake, screen flash,
	FOV kicks, flying debris, dust rings, ground cracks and blast refraction.
	The server (AbilityEngine) fires the "AbilityFX" RemoteEvent, which the
	engine auto-creates — nothing to set up manually.

	Everything here is COSMETIC ONLY. Damage, knockback and hit detection all
	stay on the server; if this script is deleted the game still plays fine.
	FX farther than 300 studs from your camera are skipped, and debris is
	hard-capped, so a 20-player fight can't tank your frame rate.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local Debris            = game:GetService("Debris")

local fx = ReplicatedStorage:WaitForChild("AbilityFX")
local rng = Random.new()

local CULL_DISTANCE = 300
local function far(pos)
	local camera = workspace.CurrentCamera
	return pos ~= nil and camera ~= nil and (camera.CFrame.Position - pos).Magnitude > CULL_DISTANCE
end

------------------------------------------------
-- CAMERA SHAKE (trauma model: impulses stack and decay smoothly, never snap)
------------------------------------------------
local trauma = 0
local function addShake(intensity, pos, radius)
	local scale = 1
	if pos then
		local camera = workspace.CurrentCamera
		if not camera then return end
		local d = (camera.CFrame.Position - pos).Magnitude
		local r = radius or 60
		if d > r then return end
		scale = 1 - d / r
	end
	trauma = math.min(trauma + intensity * scale, 1)
end

RunService:BindToRenderStep("AbilityShake", Enum.RenderPriority.Camera.Value + 10, function(dt)
	if trauma <= 0 then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	trauma = math.max(trauma - dt * 1.6, 0)
	local t = os.clock() * 17
	local s = trauma * trauma
	local offset = CFrame.new(math.noise(t, 5) * 0.6 * s, math.noise(5, t) * 0.6 * s, 0)
		* CFrame.Angles(math.noise(t, 0) * 0.055 * s, math.noise(0, t) * 0.055 * s, 0)
	camera.CFrame = camera.CFrame * offset
end)

------------------------------------------------
-- SCREEN FLASH (big hits tint + brighten the screen for a beat)
------------------------------------------------
local flashFx = Instance.new("ColorCorrectionEffect")
flashFx.Name = "AbilityFlash"
flashFx.Parent = Lighting
local function flash(color, strength)
	strength = math.min(strength or 1, 1.5)
	flashFx.TintColor = Color3.new(1, 1, 1):Lerp(color or Color3.new(1, 1, 1), 0.25 * strength)
	flashFx.Brightness = 0.12 * strength
	TweenService:Create(flashFx, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Brightness = 0,
		TintColor = Color3.new(1, 1, 1),
	}):Play()
end

------------------------------------------------
-- FOV KICK (dashes feel fast)
------------------------------------------------
local baseFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local fovTween
local function fovKick(amount, time)
	local camera = workspace.CurrentCamera
	if not camera then return end
	if fovTween then fovTween:Cancel() end
	camera.FieldOfView = baseFov + (amount or 8)
	fovTween = TweenService:Create(camera, TweenInfo.new(time or 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		FieldOfView = baseFov,
	})
	fovTween:Play()
end

------------------------------------------------
-- DEBRIS (client-local rocks: real physics for you, zero server cost)
------------------------------------------------
local debrisCount = 0
local MAX_DEBRIS = 60
local function spawnDebris(pos, color, count, power)
	color = color or Color3.fromRGB(200, 200, 200)
	local rockColor = Color3.fromRGB(105, 100, 95):Lerp(color, 0.25)
	count = math.min(count, MAX_DEBRIS - debrisCount)
	for _ = 1, count do
		debrisCount += 1
		local rock = Instance.new("Part")
		rock.Size = Vector3.new(rng:NextNumber(0.4, 1.2), rng:NextNumber(0.4, 1.2), rng:NextNumber(0.4, 1.2))
		rock.Color = rockColor
		rock.Material = Enum.Material.Slate
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CastShadow = false
		rock.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), 1, rng:NextNumber(-2, 2)))
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		rock.Parent = workspace
		local dir = (Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) + Vector3.new(0, rng:NextNumber(0.8, 1.6), 0)).Unit
		rock.AssemblyLinearVelocity = dir * power
		rock.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		task.delay(1.6, function() TweenService:Create(rock, TweenInfo.new(0.7), { Transparency = 1 }):Play() end)
		task.delay(2.4, function()
			rock:Destroy()
			debrisCount -= 1
		end)
	end
end

------------------------------------------------
-- DUST / CRACKS / REFRACTION
------------------------------------------------
local function dust(pos, radius, color)
	local holder = Instance.new("Part")
	holder.Anchored = true; holder.CanCollide = false; holder.CanQuery = false; holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(pos)
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(160, 150, 140):Lerp(color or Color3.new(1, 1, 1), 0.15))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.35),
		NumberSequenceKeypoint.new(1, radius * 0.7),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(radius * 0.6, radius)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Drag = 3
	e.Rate = 0
	e.Parent = holder
	e:Emit(math.clamp(math.floor(radius * 1.2), 10, 30))
	Debris:AddItem(holder, 2)
end

local function cracks(pos, power)
	local ray = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0))
	if not ray then return end
	local base = ray.Position + Vector3.new(0, 0.06, 0)
	local n = math.clamp(math.floor(4 + power * 4), 4, 9)
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = rng:NextNumber(3, 6) * math.max(power, 0.6)
		local crack = Instance.new("Part")
		crack.Anchored = true; crack.CanCollide = false; crack.CanQuery = false; crack.CanTouch = false
		crack.CastShadow = false
		crack.Color = Color3.fromRGB(15, 15, 15)
		crack.Material = Enum.Material.Concrete
		crack.Size = Vector3.new(rng:NextNumber(0.25, 0.45), 0.08, len)
		crack.CFrame = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -len / 2)
		crack.Parent = workspace
		task.delay(2.2, function() TweenService:Create(crack, TweenInfo.new(0.8), { Transparency = 1 }):Play() end)
		Debris:AddItem(crack, 3.1)
	end
end

local function refraction(pos, radius)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true; ball.CanCollide = false; ball.CanQuery = false; ball.CanTouch = false
	ball.Material = Enum.Material.Glass
	ball.Color = Color3.new(1, 1, 1)
	ball.Transparency = 0.7
	ball.Size = Vector3.new(1, 1, 1)
	ball.CFrame = CFrame.new(pos)
	ball.Parent = workspace
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {
		Size = Vector3.new(radius * 1.6, radius * 1.6, radius * 1.6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.4)
end

------------------------------------------------
-- EVENT HANDLERS (kind -> composition of the primitives above)
------------------------------------------------
local handlers = {}

handlers.shake = function(d)
	if far(d.pos) then return end
	addShake(d.intensity or 0.4, d.pos, d.radius)
end

handlers.impact = function(d)
	if far(d.pos) then return end
	addShake(d.big and 0.45 or 0.2, d.pos, 60)
	if d.big then
		spawnDebris(d.pos, d.color, 6, 34)
		dust(d.pos, 8, d.color)
	end
end

handlers.blast = function(d)
	if far(d.pos) then return end
	local power = d.power or 1
	addShake(0.35 + 0.35 * power, d.pos, (d.radius or 20) + 60)
	dust(d.pos, (d.radius or 20) * 0.8, d.color)
	spawnDebris(d.pos, d.color, math.floor(6 + power * 6), 30 + power * 25)
	cracks(d.pos, power)
	refraction(d.pos, (d.radius or 20) * 0.8)
	if power >= 0.9 then flash(d.color, power) end
end

handlers.teleport = function(d)
	if far(d.to) and far(d.from) then return end
	addShake(0.15, d.to, 40)
end

handlers.blocked = function(d)
	if far(d.pos) then return end
	addShake(0.1, d.pos, 25)
end

handlers.fovKick = function(d)
	fovKick(d.amount, d.time)
end

fx.OnClientEvent:Connect(function(kind, data)
	local handler = handlers[kind]
	if handler then handler(data or {}) end
end)
