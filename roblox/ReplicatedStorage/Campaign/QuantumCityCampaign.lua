--[[
	QuantumCityCampaign  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > QuantumCityCampaign

	Season 10's route module — the same contract as MetroCityCampaign, so the
	shared CampaignController runs it with no changes. The boss is The Anonymous,
	who fights with his real CharacterKits moveset (derived by the controller).

	Marker names match the beacons QuantumCityBuilder places under
	workspace.QuantumCity.Campaign.Objectives: "Stage<id>_<DistrictNoSpaces>".
]]

local QuantumCityCampaign = {}

QuantumCityCampaign.CityName      = "Quantum City"
QuantumCityCampaign.RunBy         = "Blue (loops) / The Anonymous"
QuantumCityCampaign.CityModelName = "QuantumCity"       -- workspace child the builder creates
QuantumCityCampaign.MapBuilder    = "QuantumCityBuilder" -- ServerStorage builder ModuleScript
QuantumCityCampaign.Season        = 10

QuantumCityCampaign.EnemyName = "Quantum Sentinel"
QuantumCityCampaign.BossName  = "The Anonymous"
-- VILLAIN side: defend the loops for the Anonymous, repelling the heroes who
-- breach them — and Chasm, the energy hero, is your final foe.
QuantumCityCampaign.VillainEnemyName = "Hero Intruder"
QuantumCityCampaign.VillainBoss      = "Chasm"
QuantumCityCampaign.Briefing =
	"Blue's loops have trapped the heroes in the digital Quantum City. Breach the outer ring, cut through the Anonymous's sentinels, and reach the Sanctum to end him."
QuantumCityCampaign.VillainBriefing =
	"The loops are the Anonymous's fortress and you hold the walls. Heroes have breached the ring, led by Chasm. Repel every intruder and destroy him at the Sanctum."
QuantumCityCampaign.VillainObjectives = {
	[1] = "Repel the boarders at the docking ring.",
	[2] = "Purge intruders from the data market.",
	[3] = "Defend the holographic grid.",
	[4] = "Hold the server spire.",
	[5] = "Seal the firewall checkpoint.",
	[6] = "Guard the loop gardens.",
	[7] = "Trap them in the undernet.",
	[8] = "Fortify the nexus core.",
	[9] = "Anonymous Sanctum — destroy Chasm.",
}

QuantumCityCampaign.Stages = {
	{ id = 1, district = "Docking Ring",        markerName = "Stage1_DockingRing",       enemies = 3, objective = "Dock and breach Quantum City's outer ring." },
	{ id = 2, district = "Data Market",         markerName = "Stage2_DataMarket",        enemies = 4, objective = "Fight through the Data Market's neon stalls." },
	{ id = 3, district = "The Grid",            markerName = "Stage3_TheGrid",           enemies = 4, objective = "Cross the holographic Grid platforms." },
	{ id = 4, district = "Server Spire",        markerName = "Stage4_ServerSpire",       enemies = 5, objective = "Scale the Server Spire's data towers." },
	{ id = 5, district = "Firewall Checkpoint",  markerName = "Stage5_FirewallCheckpoint", enemies = 5, objective = "Break the Firewall Checkpoint." },
	{ id = 6, district = "Loop Gardens",        markerName = "Stage6_LoopGardens",       enemies = 5, objective = "Pass Blue's shifting Loop Gardens." },
	{ id = 7, district = "The Undernet",        markerName = "Stage7_TheUndernet",       enemies = 6, objective = "Drop into the glitching Undernet." },
	{ id = 8, district = "Nexus Core",          markerName = "Stage8_NexusCore",         enemies = 6, objective = "Reach the Nexus Core at the city's heart." },
	{ id = 9, district = "Anonymous Sanctum",    markerName = "Stage9_AnonymousSanctum",  enemies = 0, objective = "Enter the Sanctum — defeat the Anonymous.", boss = true },
}

function QuantumCityCampaign.finalStage()
	return QuantumCityCampaign.Stages[#QuantumCityCampaign.Stages]
end

function QuantumCityCampaign.enableCheckpoint(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("QuantumCity")
	if not city then return nil end
	local spawns = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Spawns")
	if not spawns then return nil end
	local sp = spawns:FindFirstChild("Checkpoint_" .. stageId)
	if sp then sp.Enabled = true end
	return sp
end

function QuantumCityCampaign.getBeacon(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("QuantumCity")
	if not city then return nil end
	local objs = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Objectives")
	if not objs then return nil end
	for _, b in ipairs(objs:GetChildren()) do
		if b:GetAttribute("Stage") == stageId then return b end
	end
	return nil
end

return QuantumCityCampaign
