--[[
	WarriorsOfTheWorld  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > WarriorsOfTheWorld

	The original Warriors of the World — the strike team that descends into Null's
	Shadowlands (Season 3), defeats the Void Overlord on Gildonia (Season 5), and
	makes the last stand against Omega (Season 7). They become PLAYABLE heroes the
	moment you start a Season 3 campaign, and stay pickable until the story removes
	them (see `untilSeason` — Valkery is cut down by Null in Season 4).

	This is a STORY unlock, not a shop purchase: it costs no Coins, it's gated to
	the campaign season you're playing. Both the client (which shows the extra
	hero cards for the chosen season) and the server (which validates the pick)
	read this module, so the roster + windows are defined once.

	Every `name` is a real hero with its own CharacterKits moveset and
	CharacterModels look, so you fight Void Overlord, Null and Omega with the
	Warriors' actual kits.

	Availability window is inclusive: a Warrior is pickable when the season you're
	starting is between `fromSeason` and `untilSeason`.
]]

local WarriorsOfTheWorld = {}

WarriorsOfTheWorld.GroupName   = "Warriors of the World"
WarriorsOfTheWorld.UnlockSeason = 3   -- first season they're playable

-- fromSeason/untilSeason are inclusive season ids from the CampaignRegistry.
-- (Frost and Water Woman are also free hero STARTERS, so they're always pickable;
-- listing them here just marks them as canonical Warriors of the World.)
WarriorsOfTheWorld.Members = {
	{ name = "Red Rocket",  fromSeason = 3, untilSeason = 7, blurb = "Leader of the Warriors — flame charges and rocket rushes." },
	{ name = "Dead Dash",   fromSeason = 3, untilSeason = 7, blurb = "The storm speedster — energy blurs and lightning-quick strikes." },
	{ name = "Water Woman", fromSeason = 3, untilSeason = 7, blurb = "Water beam, water spheres, a tide ward, and lashing tentacles." },
	{ name = "Liberty",     fromSeason = 3, untilSeason = 7, blurb = "Storm-caller of liberty — lightning bolts and thunder." },
	{ name = "Jumper",      fromSeason = 3, untilSeason = 7, blurb = "The scout who warned Earth — rifts, blinks, and reach." },
	{ name = "Frost",       fromSeason = 3, untilSeason = 7, blurb = "Ice beam that slows then freezes, ice balls, a shattering ward." },
	-- Valkery falls to Null during the Season 4 hunt, so she's cut from the
	-- roster afterward.
	{ name = "Valkery",     fromSeason = 3, untilSeason = 4, blurb = "Winged warrior — aerial dives and twin blades. Falls to Null." },
}

function WarriorsOfTheWorld.get(name)
	for _, m in ipairs(WarriorsOfTheWorld.Members) do
		if m.name == name then return m end
	end
	return nil
end

function WarriorsOfTheWorld.isWarrior(name)
	return WarriorsOfTheWorld.get(name) ~= nil
end

-- is this Warrior pickable for a given campaign season id?
function WarriorsOfTheWorld.isAvailable(name, seasonId)
	local m = WarriorsOfTheWorld.get(name)
	if not m or type(seasonId) ~= "number" then return false end
	return seasonId >= m.fromSeason and seasonId <= m.untilSeason
end

-- the Warriors playable in a given season, in roster order
function WarriorsOfTheWorld.availableFor(seasonId)
	local out = {}
	if type(seasonId) ~= "number" then return out end
	for _, m in ipairs(WarriorsOfTheWorld.Members) do
		if seasonId >= m.fromSeason and seasonId <= m.untilSeason then
			out[#out + 1] = m
		end
	end
	return out
end

return WarriorsOfTheWorld
