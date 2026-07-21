--[[
	MetroCityCampaign  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > MetroCityCampaign

	Data-only description of the Metro City campaign: the ordered mission stages
	that run through the 11 districts, with the marker names the map generator
	places under workspace.MetroCity.Campaign. Your campaign controller reads
	this to drive objectives, advance checkpoints, and know where the boss is.

	It intentionally contains NO gameplay logic — it's the contract between the
	map (MetroCityBuilder) and whatever campaign/quest system you run. Both use
	the same district names and Stage ids, so nothing is hard-coded twice.

	Example (server campaign controller):
		local Camp = require(ReplicatedStorage.Campaign.MetroCityCampaign)
		local markers = workspace.MetroCity.Campaign.Objectives
		local stage = Camp.Stages[currentIndex]
		local beacon = markers[stage.markerName]           -- glowing objective
		-- ...detect players reaching `beacon`, then:
		Camp.enableCheckpoint(workspace, stage.id)          -- advance the spawn
]]

local MetroCityCampaign = {}

MetroCityCampaign.CityName = "Metro City"
MetroCityCampaign.RunBy    = "Manderin"
-- route-module contract (the CampaignController reads these generically):
MetroCityCampaign.CityModelName = "MetroCity"   -- workspace child the builder creates
MetroCityCampaign.MapBuilder    = "MetroCityBuilder"  -- ServerStorage builder ModuleScript
MetroCityCampaign.Season        = 8
MetroCityCampaign.Summary  =
	"A futuristic city of skyscrapers and Manderin Tech — clean, high-secured, " ..
	"and run under Manderin's order. The campaign fights inward from the streets " ..
	"to the top of Manderin Tower."

-- district reference (matches the concept sheet + the map's District models)
MetroCityCampaign.Districts = {
	{ id = 1,  name = "Central Plaza",        desc = "The heart of Metro City. A large open plaza with Manderin's statue in the center." },
	{ id = 2,  name = "Manderin Tower",       desc = "The tallest building and Manderin's HQ. Only the highest ranked are allowed inside." },
	{ id = 3,  name = "Tech District",        desc = "Advanced laboratories, research centers, and tech stores." },
	{ id = 4,  name = "Industrial District",  desc = "Factories and plants that produce Manderin Tech and machinery." },
	{ id = 5,  name = "Residential Area",     desc = "Where citizens live. Clean, organized, and constantly monitored." },
	{ id = 6,  name = "Docks",                desc = "Handles all imports and exports. Heavily protected." },
	{ id = 7,  name = "Security Checkpoints",  desc = "Scanner gates at every entrance. No one enters without scanning." },
	{ id = 8,  name = "Sky Bridges",          desc = "Bridges linking the tall towers for fast travel across the city." },
	{ id = 9,  name = "Undercity",            desc = "The hidden underground. Black markets, secret labs, and where criminals hide." },
	{ id = 10, name = "Manderin Arena",       desc = "A high-tech arena where fights, tournaments, and special events are held." },
	{ id = 11, name = "City Walls",           desc = "Massive walls around Metro City, controlled by Manderin's military." },
}

-- who you fight through the campaign
MetroCityCampaign.EnemyName = "Manderin Security"
MetroCityCampaign.BossName  = "Manderin"
-- VILLAIN side: enforce Manderin's regime, hunting the resistance — and Looney,
-- the hero who keeps saving the city, is your final foe.
MetroCityCampaign.VillainEnemyName = "Resistance Fighter"
MetroCityCampaign.VillainBoss      = "Looney"
MetroCityCampaign.Briefing =
	"Manderin has crowned himself dictator of Metro City. Fight in from the streets, free the districts, and pull him down from the top of Manderin Tower."
MetroCityCampaign.VillainBriefing =
	"Metro City is Manderin's, and you enforce his order. The resistance stirs in every district, and the hero Looney keeps saving them. Crush the uprising and end Looney."
MetroCityCampaign.VillainObjectives = {
	[1] = "Round up the residential dissidents.",
	[2] = "Secure the plaza for Manderin.",
	[3] = "Lock down the security checkpoint.",
	[4] = "Purge the tech district rebels.",
	[5] = "Seize the industrial plants.",
	[6] = "Clear the docks of smugglers.",
	[7] = "Sweep the undercity hideouts.",
	[8] = "Win the arena for the regime.",
	[9] = "Manderin Tower — put down Looney.",
}

-- ordered mission route (marker names match beacons the builder creates:
-- "Stage<id>_<DistrictWithoutSpaces>"). `enemies` = guards to defeat before the
-- objective marker unlocks; `boss` stages spawn Manderin instead.
MetroCityCampaign.Stages = {
	{ id = 1, district = "Residential Area",    markerName = "Stage1_ResidentialArea",     enemies = 3, objective = "Escape the monitored residential blocks." },
	{ id = 2, district = "Central Plaza",       markerName = "Stage2_CentralPlaza",         enemies = 4, objective = "Reach Manderin's monument in Central Plaza." },
	{ id = 3, district = "Security Checkpoints", markerName = "Stage3_SecurityCheckpoints",  enemies = 4, objective = "Break through a Manderin Security checkpoint." },
	{ id = 4, district = "Tech District",       markerName = "Stage4_TechDistrict",         enemies = 5, objective = "Sabotage the labs in the Tech District." },
	{ id = 5, district = "Industrial District", markerName = "Stage5_IndustrialDistrict",   enemies = 5, objective = "Shut down the Industrial District plants." },
	{ id = 6, district = "Docks",               markerName = "Stage6_Docks",                enemies = 5, objective = "Intercept a shipment at the Docks." },
	{ id = 7, district = "Undercity",           markerName = "Stage7_Undercity",            enemies = 6, objective = "Fight through the Undercity black market." },
	{ id = 8, district = "Manderin Arena",      markerName = "Stage8_ManderinArena",        enemies = 6, objective = "Win the trial in the Manderin Arena." },
	{ id = 9, district = "Manderin Tower",      markerName = "Stage9_ManderinTower",        enemies = 0, objective = "Storm Manderin Tower — defeat Manderin.", boss = true },
}

-- helper: the final boss stage (Manderin at the top of his tower)
function MetroCityCampaign.finalStage()
	return MetroCityCampaign.Stages[#MetroCityCampaign.Stages]
end

-- helper: flip on a stage's checkpoint SpawnLocation so respawns move forward.
-- Safe to call from the server; returns the SpawnLocation or nil.
function MetroCityCampaign.enableCheckpoint(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("MetroCity")
	if not city then return nil end
	local spawns = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Spawns")
	if not spawns then return nil end
	local sp = spawns:FindFirstChild("Checkpoint_" .. stageId)
	if sp then sp.Enabled = true end
	return sp
end

-- helper: look up a live objective beacon part for a stage id
function MetroCityCampaign.getBeacon(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("MetroCity")
	if not city then return nil end
	local objs = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Objectives")
	if not objs then return nil end
	for _, b in ipairs(objs:GetChildren()) do
		if b:GetAttribute("Stage") == stageId then return b end
	end
	return nil
end

return MetroCityCampaign
