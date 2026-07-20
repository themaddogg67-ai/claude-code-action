--[[
	BuildMetroCity  (Script)
	WHERE IT GOES: ServerScriptService > BuildMetroCity

	Builds Metro City on server start IF it isn't already in the place.

	RECOMMENDED WORKFLOW — bake the map once, then disable this:
	  1. Put MetroCityBuilder (ModuleScript) in ServerStorage.
	  2. In Studio, open the Command Bar (View > Command Bar) and run:
	         require(game.ServerStorage.MetroCityBuilder).build(workspace)
	  3. workspace.MetroCity now exists as real, editable geometry. Save the place.
	  4. Set BUILD_AT_RUNTIME below to false (or delete this Script) so the server
	     never spends time rebuilding — it just uses the saved geometry.

	Leaving BUILD_AT_RUNTIME = true is fine too: it only builds when MetroCity is
	missing, so a baked map is never rebuilt.

	Turn on Workspace.StreamingEnabled for best performance with a city this size.
]]

local ServerStorage = game:GetService("ServerStorage")

local BUILD_AT_RUNTIME = true

if not BUILD_AT_RUNTIME then return end
if workspace:FindFirstChild("MetroCity") then return end

local builderModule = ServerStorage:FindFirstChild("MetroCityBuilder")
if not builderModule then
	warn("BuildMetroCity: ServerStorage.MetroCityBuilder is missing — city not built.")
	return
end

local ok, err = pcall(function()
	local MetroCityBuilder = require(builderModule)
	MetroCityBuilder.build(workspace, { seed = 20250720, campaign = true })
end)

if ok then
	print("BuildMetroCity: Metro City generated (11 districts).")
else
	warn("BuildMetroCity: build failed — " .. tostring(err))
end
