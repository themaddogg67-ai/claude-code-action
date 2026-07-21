--[[
	GildoniaCampaign  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > GildoniaCampaign

	Season 5's route module — the jungle planet Gildonia, same contract as the
	other route modules so the shared CampaignController runs it unchanged. Boss
	is the Void Overlord, who fights with his real CharacterKits moveset.

	Marker names match the beacons GildoniaBuilder places under
	workspace.Gildonia.Campaign.Objectives: "Stage<id>_<DistrictNoSpaces>".
]]

local GildoniaCampaign = {}

GildoniaCampaign.CityName      = "Gildonia"
GildoniaCampaign.RunBy         = "Void Overlord (invasion)"
GildoniaCampaign.CityModelName = "Gildonia"
GildoniaCampaign.MapBuilder    = "GildoniaBuilder"
GildoniaCampaign.Season        = 5

GildoniaCampaign.EnemyName = "Void Soldier"
GildoniaCampaign.BossName  = "Void Overlord"

GildoniaCampaign.Stages = {
	{ id = 1, district = "Crash Site",        markerName = "Stage1_CrashSite",        enemies = 3, objective = "Regroup at the downed Warrior ship." },
	{ id = 2, district = "Jungle Path",       markerName = "Stage2_JunglePath",       enemies = 4, objective = "Cut through the overgrown jungle path." },
	{ id = 3, district = "Native Village",    markerName = "Stage3_NativeVillage",    enemies = 5, objective = "Defend the native village from the assault." },
	{ id = 4, district = "Ancient Ruins",     markerName = "Stage4_AncientRuins",     enemies = 5, objective = "Search the ancient ruins for a way through." },
	{ id = 5, district = "River Crossing",    markerName = "Stage5_RiverCrossing",    enemies = 5, objective = "Hold the river crossing." },
	{ id = 6, district = "Overgrown Temple",  markerName = "Stage6_OvergrownTemple",  enemies = 6, objective = "Breach the overgrown temple." },
	{ id = 7, district = "Sacred Grove",      markerName = "Stage7_SacredGrove",      enemies = 6, objective = "Pass the glowing Sacred Grove." },
	{ id = 8, district = "Corrupted Clearing", markerName = "Stage8_CorruptedClearing", enemies = 0, objective = "Face the Void Overlord in the corrupted clearing.", boss = true },
}

function GildoniaCampaign.finalStage()
	return GildoniaCampaign.Stages[#GildoniaCampaign.Stages]
end

function GildoniaCampaign.enableCheckpoint(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("Gildonia")
	if not city then return nil end
	local spawns = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Spawns")
	if not spawns then return nil end
	local sp = spawns:FindFirstChild("Checkpoint_" .. stageId)
	if sp then sp.Enabled = true end
	return sp
end

function GildoniaCampaign.getBeacon(parentOrWorkspace, stageId)
	local city = parentOrWorkspace:FindFirstChild("Gildonia")
	if not city then return nil end
	local objs = city:FindFirstChild("Campaign") and city.Campaign:FindFirstChild("Objectives")
	if not objs then return nil end
	for _, b in ipairs(objs:GetChildren()) do
		if b:GetAttribute("Stage") == stageId then return b end
	end
	return nil
end

return GildoniaCampaign
