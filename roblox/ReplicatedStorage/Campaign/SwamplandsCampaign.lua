--[[
	SwamplandsCampaign  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > SwamplandsCampaign

	Season 1's route module — "Rise of Minus", the bayou. Same contract as the
	other route modules so the shared CampaignController runs it unchanged. Boss
	is Minus (gator general), with his themed model + CharacterKits moveset.

	Marker names match SwamplandsBuilder's beacons under
	workspace.Swamplands.Campaign.Objectives: "Stage<id>_<DistrictNoSpaces>".
	(Apostrophes are also stripped, e.g. "Gator's Den" -> "GatorsDen".)
]]

local SwamplandsCampaign = {}

SwamplandsCampaign.CityName      = "The Swamplands"
SwamplandsCampaign.RunBy         = "Minus (army)"
SwamplandsCampaign.CityModelName = "Swamplands"
SwamplandsCampaign.MapBuilder    = "SwamplandsBuilder"
SwamplandsCampaign.Season        = 1

SwamplandsCampaign.EnemyName = "Swamp Raider"
SwamplandsCampaign.BossName  = "Minus"

SwamplandsCampaign.Stages = {
	{ id = 1, district = "Muddy Banks",    markerName = "Stage1_MuddyBanks",    enemies = 3, objective = "Wade in through the muddy banks." },
	{ id = 2, district = "Mangrove Maze",  markerName = "Stage2_MangroveMaze",  enemies = 4, objective = "Find your way through the mangrove maze." },
	{ id = 3, district = "Sunken Village",  markerName = "Stage3_SunkenVillage", enemies = 4, miniBoss = "El Primo Libre", miniBossHealth = 1100, objective = "Sunken village — beat down El Primo Libre." },
	{ id = 4, district = "Poison Marsh",   markerName = "Stage4_PoisonMarsh",   enemies = 5, objective = "Cross the poison marsh." },
	{ id = 5, district = "The War Camp",   markerName = "Stage5_TheWarCamp",    enemies = 6, objective = "Raid Minus's war camp." },
	{ id = 6, district = "Gator's Den",    markerName = "Stage6_GatorsDen",     enemies = 0, objective = "Enter the Gator's Den — defeat Minus.", boss = true },
}

function SwamplandsCampaign.finalStage()
	return SwamplandsCampaign.Stages[#SwamplandsCampaign.Stages]
end

function SwamplandsCampaign.enableCheckpoint(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("Swamplands")
	if not city then return nil end
	local spawns = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Spawns")
	if not spawns then return nil end
	local sp = spawns:FindFirstChild("Checkpoint_" .. stageId)
	if sp then sp.Enabled = true end
	return sp
end

function SwamplandsCampaign.getBeacon(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("Swamplands")
	if not city then return nil end
	local objs = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Objectives")
	if not objs then return nil end
	for _, b in ipairs(objs:GetChildren()) do
		if b:GetAttribute("Stage") == stageId then return b end
	end
	return nil
end

return SwamplandsCampaign
