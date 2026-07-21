--[[
	BuildModelGallery  (Script)
	WHERE IT GOES: ServerScriptService > BuildModelGallery

	A viewer for the character models. It does NOTHING on its own (SHOW = false)
	so it never clutters a live game. To see every modeled character lined up as
	labeled display statues:

	  * flip SHOW to true and playtest, OR
	  * run this in the Studio Command Bar:
	        require(game.ServerStorage.CharacterModelFactory).gallery(workspace, CFrame.new(0, 5, 300))

	The statues are anchored (no physics) and purely for looking at the designs.
]]

local ServerStorage = game:GetService("ServerStorage")

local SHOW = false
local ORIGIN = CFrame.new(0, 5, 300)   -- where the gallery appears

if not SHOW then return end

local factory = ServerStorage:FindFirstChild("CharacterModelFactory")
if not factory then
	warn("BuildModelGallery: ServerStorage.CharacterModelFactory missing.")
	return
end

local ok, err = pcall(function()
	require(factory).gallery(workspace, ORIGIN)
end)
if ok then
	print("BuildModelGallery: character gallery built at", ORIGIN.Position)
else
	warn("BuildModelGallery: failed — " .. tostring(err))
end
