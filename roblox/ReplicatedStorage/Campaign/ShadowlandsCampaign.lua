--[[
	ShadowlandsCampaign  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > ShadowlandsCampaign

	Season 3's route module — "Orders From Above", the Shadowlands of Null. Same
	contract as the other route modules. Hero boss is Null; villain side sides
	with the darkness and faces the light-wielding Golden Knight.

	Marker names match ShadowlandsBuilder's beacons under
	workspace.Shadowlands.Campaign.Objectives: "Stage<id>_<DistrictNoSpaces>".
]]

local ShadowlandsCampaign = {}

ShadowlandsCampaign.CityName      = "The Shadowlands"
ShadowlandsCampaign.RunBy         = "Null (army of darkness)"
ShadowlandsCampaign.CityModelName = "Shadowlands"
ShadowlandsCampaign.MapBuilder    = "ShadowlandsBuilder"
ShadowlandsCampaign.Season        = 3

ShadowlandsCampaign.EnemyName = "Darkness Thrall"
ShadowlandsCampaign.BossName  = "Null"
ShadowlandsCampaign.VillainEnemyName = "Lightbringer"
ShadowlandsCampaign.VillainBoss      = "Golden Knight"

ShadowlandsCampaign.Briefing =
	"The Warriors learn Minus only served a greater master — Null, who commands an army of darkness. Descend into his Shadowlands and end him."
ShadowlandsCampaign.VillainBriefing =
	"You march for Null. The light's champions have breached the Shadowlands to reach the throne — hold the darkness and cut them down."

ShadowlandsCampaign.Stages = {
	{ id = 1, district = "Broken Gate",     markerName = "Stage1_BrokenGate",    enemies = 3,
	  objective = "Breach the broken gate.",             villainObjective = "Seal the broken gate behind you." },
	{ id = 2, district = "Ashen Wastes",    markerName = "Stage2_AshenWastes",   enemies = 4,
	  objective = "Cross the ashen wastes.",             villainObjective = "Drive the heroes off the ashen wastes." },
	{ id = 3, district = "Shadow Spires",   markerName = "Stage3_ShadowSpires",  enemies = 5,
	  objective = "Climb through the shadow spires.",    villainObjective = "Ambush the heroes among the spires." },
	{ id = 4, district = "The Dark Bastion", markerName = "Stage4_TheDarkBastion", enemies = 5,
	  objective = "Storm the Dark Bastion.",             villainObjective = "Hold the Dark Bastion." },
	{ id = 5, district = "Throne Approach", markerName = "Stage5_ThroneApproach", enemies = 6,
	  objective = "Fight up the throne approach.",       villainObjective = "Guard the throne approach." },
	{ id = 6, district = "Null's Throne",   markerName = "Stage6_NullsThrone",   enemies = 0, boss = true,
	  objective = "Null's Throne — end the darkness.",   villainObjective = "Null's Throne — destroy the Golden Knight." },
}

function ShadowlandsCampaign.finalStage()
	return ShadowlandsCampaign.Stages[#ShadowlandsCampaign.Stages]
end

function ShadowlandsCampaign.enableCheckpoint(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("Shadowlands")
	if not city then return nil end
	local spawns = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Spawns")
	if not spawns then return nil end
	local sp = spawns:FindFirstChild("Checkpoint_" .. stageId)
	if sp then sp.Enabled = true end
	return sp
end

function ShadowlandsCampaign.getBeacon(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("Shadowlands")
	if not city then return nil end
	local objs = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Objectives")
	if not objs then return nil end
	for _, b in ipairs(objs:GetChildren()) do
		if b:GetAttribute("Stage") == stageId then return b end
	end
	return nil
end

return ShadowlandsCampaign
