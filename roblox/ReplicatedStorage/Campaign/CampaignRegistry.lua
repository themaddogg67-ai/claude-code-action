--[[
	CampaignRegistry  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > CampaignRegistry

	The season index for the whole Heroes & Villains campaign. Each season is a
	map + a boss; this registry ties them together so the CampaignController can
	run whichever season is ACTIVE, and adding a new map later is just:
	  1. write a map builder ModuleScript in ServerStorage  (like MetroCityBuilder)
	  2. write a route ModuleScript in ReplicatedStorage.Campaign following the
	     same contract as MetroCityCampaign (Stages, getBeacon, enableCheckpoint,
	     EnemyName, BossName, CityModelName)
	  3. add/point a season entry here and set ActiveSeason

	`boss` names match keys in ReplicatedStorage.Characters.CharacterKits, so each
	season's boss automatically fights using that villain's real kit (the
	controller derives the boss's moves from it). Seasons without a built map are
	`status = "planned"` — they're story/boss metadata until their map exists.

	Story beats summarized from the campaign design doc (Seasons 1–30).
]]

local CampaignRegistry = {}

-- which season the CampaignController should run right now
CampaignRegistry.ActiveSeason = 8   -- Metro City (Manderin) is the built map

CampaignRegistry.Seasons = {
	{ id = 1,  title = "Rise of Minus",         boss = "Minus",         status = "planned",
	  summary = "Mid-tier villains all leading up to Minus and his army." },
	{ id = 2,  title = "The Army Attacks",      boss = "Minus",         status = "planned",
	  summary = "Minus's army attacks; the Warriors of the World and Looney take him down." },
	{ id = 3,  title = "Orders From Above",     boss = "Null",          status = "planned",
	  summary = "Minus was only a general — the Warriors learn he answered to Null." },
	{ id = 4,  title = "Hunt for Null",         boss = "Null",          status = "planned",
	  summary = "The Warriors hunt Null; Looney defends the city. Valkery is killed by Null." },
	{ id = 5,  title = "The Void Overlord",     boss = "Void Overlord", status = "planned",
	  summary = "The Warriors defeat Void Overlord, then answer a distress beacon to Omega's planet." },
	{ id = 6,  title = "Before the Storm",      boss = "Omega",         status = "planned",
	  summary = "Jumper warns Earth; cities raise force fields as Omega approaches." },
	{ id = 7,  title = "Omega's Chaos",         boss = "Omega",         status = "planned",
	  summary = "Omega breaks the fields; Looney unlocks his awakening and ends him." },
	{ id = 8,  title = "Manderin's Metro City", boss = "Manderin",      status = "built",
	  map = "MetroCityBuilder", route = "MetroCityCampaign",
	  summary = "Mark Manderin wins the presidency and turns dictator, resurrecting old villains and mind-controlling heroes to seize the world." },
	{ id = 9,  title = "Rehabilitation",        boss = "Void Overlord", status = "planned",
	  summary = "A secret villain-rehab center; only Omega turns good as Minus, Null and Void Overlord return." },
	{ id = 10, title = "Blue's Loops",          boss = "The Anonymous", status = "built",
	  map = "QuantumCityBuilder", route = "QuantumCityCampaign",
	  summary = "The heroes enter Blue's loops in space — the digital Quantum City — to reach the Anonymous." },
	{ id = 11, title = "Mind-Controlled World", boss = "The Anonymous", status = "planned",
	  summary = "With most minds seized, the few free heroes defend a burning Earth; Conqueror kills the Anonymous with all 5 stones." },
	{ id = 12, title = "The Armageddon",        boss = "Conquest",      status = "planned",
	  summary = "Conqueror dons the god armor and becomes an omniversal threat; Looney's full toon force ends him." },
	{ id = 13, title = "Armageddon Invades",    boss = "Armageddon",    status = "planned",
	  summary = "Armageddon crosses from a conquered omniverse wielding sins, stones and titan gems. Leon ends him by Season 16." },
	{ id = 17, title = "The Oni Giri",          boss = "Dragon",        status = "planned",
	  summary = "The world government's leader is revealed as the Oni Giri; Leon kills him." },
	{ id = 19, title = "Antiverse Parasite",    boss = "Anti-Man",      status = "planned",
	  summary = "A parasite from the antiverse invades to weaken Unity. Anti-Man dies by Mercy." },
	{ id = 20, title = "Fall of Mercy",         boss = "Mercy",         status = "planned",
	  summary = "Demons overtake Mercy; True Gold X and Mercy kill each other, leaving only Leon." },
	{ id = 21, title = "Nemesis & the Future",  boss = "Nemesis",       status = "planned",
	  summary = "Oryiox gathers heroes across time against Nemesis's control of Daniel Storm (Seasons 21–30)." },
}

function CampaignRegistry.get(id)
	for _, s in ipairs(CampaignRegistry.Seasons) do
		if s.id == id then return s end
	end
	return nil
end

function CampaignRegistry.getActive()
	return CampaignRegistry.get(CampaignRegistry.ActiveSeason)
end

-- seasons whose map is actually built and runnable
function CampaignRegistry.built()
	local out = {}
	for _, s in ipairs(CampaignRegistry.Seasons) do
		if s.status == "built" then out[#out + 1] = s end
	end
	return out
end

return CampaignRegistry
