--[[
	Pathfinder  (ModuleScript)
	WHERE IT GOES: ServerStorage > Pathfinder

	Lightweight navigation wrapper around Roblox PathfindingService for the
	campaign NPCs. Each NPC gets a Pathfinder that follows a moving target along
	computed waypoints (so guards route around walls / rubble instead of shoving
	into them), recomputing only when the target moves or the cached path goes
	stale — cheap enough for a stageful of enemies.

	If PathfindingService can't find a route (e.g. across a gap on the floating
	Quantum City platforms), it falls back to a direct MoveTo so the NPC never
	freezes.

	Usage (from EnemyFactory):
	    local pf = Pathfinder.new(model, humanoid, humanoidRootPart)
	    -- each AI tick:
	    pf:step(targetPosition)
]]

local PathfindingService = game:GetService("PathfindingService")

local Pathfinder = {}
Pathfinder.__index = Pathfinder

local RECOMPUTE_EVERY = 0.7   -- seconds between path recomputes
local TARGET_DRIFT     = 10   -- recompute early if the target moved this far
local WAYPOINT_REACHED = 4    -- advance to the next waypoint within this range

function Pathfinder.new(model, humanoid, root, opts)
	opts = opts or {}
	local self = setmetatable({}, Pathfinder)
	self.model = model
	self.hum = humanoid
	self.root = root
	self.waypoints = nil
	self.index = 1
	self.lastCompute = 0
	self.lastTarget = nil
	self.path = PathfindingService:CreatePath({
		AgentRadius = opts.agentRadius or 2.6,
		AgentHeight = opts.agentHeight or 5,
		AgentCanJump = opts.agentCanJump ~= false,
		AgentJumpHeight = opts.agentJumpHeight or 7,
		AgentMaxSlope = opts.agentMaxSlope or 60,
		WaypointSpacing = opts.waypointSpacing or 6,
	})
	return self
end

local function directMove(self, targetPos)
	self.hum:MoveTo(targetPos)
end

function Pathfinder:recompute(targetPos)
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, targetPos)
	end)
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.index = 2   -- waypoint 1 is the NPC's own position
		self.lastTarget = targetPos
		self.lastCompute = os.clock()
		return true
	end
	self.waypoints = nil
	self.lastCompute = os.clock()
	return false
end

-- move one step toward targetPos along the current path (recomputes as needed)
function Pathfinder:step(targetPos)
	if not self.root.Parent or self.hum.Health <= 0 then return end
	local now = os.clock()
	local stale = (now - self.lastCompute) > RECOMPUTE_EVERY
	local drifted = self.lastTarget == nil or (targetPos - self.lastTarget).Magnitude > TARGET_DRIFT
	if not self.waypoints or stale or drifted then
		if not self:recompute(targetPos) then
			directMove(self, targetPos)   -- no route — head straight there
			return
		end
	end

	local wps = self.waypoints
	if not wps or self.index > #wps then
		directMove(self, targetPos)
		return
	end

	local wp = wps[self.index]
	if wp.Action == Enum.PathWaypointAction.Jump then
		self.hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	self.hum:MoveTo(wp.Position)
	if (self.root.Position - wp.Position).Magnitude <= WAYPOINT_REACHED then
		self.index = self.index + 1
	end
end

return Pathfinder
