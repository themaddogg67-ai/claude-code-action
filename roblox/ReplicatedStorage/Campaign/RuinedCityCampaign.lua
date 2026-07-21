--[[
	RuinedCityCampaign  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > RuinedCityCampaign

	Season 7's route module — "Omega's Chaos", a devastated city. Same contract
	as the other route modules so the shared CampaignController runs it unchanged.
	Boss is Omega, who fights with his real CharacterKits moveset and wears his
	themed model.

	Marker names match RuinedCityBuilder's beacons under
	workspace.RuinedCity.Campaign.Objectives: "Stage<id>_<DistrictNoSpaces>".
]]

local RuinedCityCampaign = {}

RuinedCityCampaign.CityName      = "Ruined City"
RuinedCityCampaign.RunBy         = "Omega (rampage)"
RuinedCityCampaign.CityModelName = "RuinedCity"
RuinedCityCampaign.MapBuilder    = "RuinedCityBuilder"
RuinedCityCampaign.Season        = 7

RuinedCityCampaign.EnemyName = "Rioter"
RuinedCityCampaign.BossName  = "Omega"
-- VILLAIN side: spread Omega's chaos, fighting the peacekeepers trying to save
-- the city — and Patriot, the super-soldier defender, is your final foe.
RuinedCityCampaign.VillainEnemyName = "Peacekeeper"
RuinedCityCampaign.VillainBoss      = "Patriot"
RuinedCityCampaign.VillainObjectives = {
	[1] = "Cut off the evacuation.",
	[2] = "Tear through the streets.",
	[3] = "Level the collapsed plaza.",
	[4] = "Spread the fires further.",
	[5] = "Break the last barricade.",
	[6] = "Ground Zero — destroy Patriot.",
}

RuinedCityCampaign.Stages = {
	{ id = 1, district = "Evacuation Zone",  markerName = "Stage1_EvacuationZone",  enemies = 4, objective = "Cover the evacuation as the city falls." },
	{ id = 2, district = "Broken Streets",   markerName = "Stage2_BrokenStreets",   enemies = 5, objective = "Push through the wrecked streets." },
	{ id = 3, district = "Collapsed Plaza",  markerName = "Stage3_CollapsedPlaza",  enemies = 5, objective = "Cross the collapsed central plaza." },
	{ id = 4, district = "Burning District", markerName = "Stage4_BurningDistrict", enemies = 6, objective = "Fight through the burning district." },
	{ id = 5, district = "The Barricade",    markerName = "Stage5_TheBarricade",    enemies = 6, objective = "Hold the barricade — the last line." },
	{ id = 6, district = "Ground Zero",      markerName = "Stage6_GroundZero",      enemies = 0, objective = "Ground Zero — stop Omega.", boss = true },
}

function RuinedCityCampaign.finalStage()
	return RuinedCityCampaign.Stages[#RuinedCityCampaign.Stages]
end

function RuinedCityCampaign.enableCheckpoint(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("RuinedCity")
	if not city then return nil end
	local spawns = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Spawns")
	if not spawns then return nil end
	local sp = spawns:FindFirstChild("Checkpoint_" .. stageId)
	if sp then sp.Enabled = true end
	return sp
end

function RuinedCityCampaign.getBeacon(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("RuinedCity")
	if not city then return nil end
	local objs = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Objectives")
	if not objs then return nil end
	for _, b in ipairs(objs:GetChildren()) do
		if b:GetAttribute("Stage") == stageId then return b end
	end
	return nil
end

return RuinedCityCampaign
