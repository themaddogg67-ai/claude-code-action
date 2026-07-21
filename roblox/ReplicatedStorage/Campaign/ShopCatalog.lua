--[[
	ShopCatalog  (ModuleScript)
	WHERE IT GOES: ReplicatedStorage > Campaign > ShopCatalog

	The list of EXTRA characters you can unlock with campaign currency, beyond the
	free starters (Heroes: Looney, Leon, Chasm, Frost, Water Woman / Villains:
	Bulldozer, Reddon, Erik, Toxic). Both the server (CampaignMenu, which owns the
	coin wallet + purchase validation) and the client shop GUI read this, so
	prices and rosters are defined once.

	Every `name` here MUST exist as a key in both ReplicatedStorage.Characters
	.CharacterKits (so it has a real moveset) and .CharacterModels (so it can be
	skinned) — these are all verified bosses/heavies from the campaign. `faction`
	decides which roster tab it shows up under in Character Select once owned.

	Currency ("Coins") is earned alongside XP: a little per enemy defeated and a
	lump per season cleared (see CampaignMenu). Owned characters persist per
	player in the same DataStore record as progress/xp.
]]

local ShopCatalog = {}

ShopCatalog.Currency     = "Coins"
ShopCatalog.CoinsPerKill   = 3
ShopCatalog.CoinsPerSeason = 250

-- ordered so the shop lists cheapest first within each faction
ShopCatalog.Items = {
	-- ── unlockable HEROES ────────────────────────────────────────────────
	{ name = "Champion",   faction = "hero",    price = 400,  blurb = "The people's brawler — raw strength and a roaring crowd." },
	{ name = "Jumper",     faction = "hero",    price = 500,  blurb = "The scout who warned Earth. Speed and reach." },
	{ name = "Titan",      faction = "hero",    price = 750,  blurb = "A living fortress. Slow, unstoppable, hits like a truck." },
	{ name = "Red Rocket", faction = "hero",    price = 900,  blurb = "Leader of the Warriors of the World. Explosive kit." },
	{ name = "Patriot",    faction = "hero",    price = 1100, blurb = "The super-soldier defender. Balanced and relentless." },
	{ name = "Valkery",    faction = "hero",    price = 1300, blurb = "Winged warrior — aerial strikes and blades." },
	{ name = "Mercy",      faction = "hero",    price = 1600, blurb = "Holy power turned demon-slaying fury." },

	-- ── unlockable VILLAINS ──────────────────────────────────────────────
	{ name = "El Primo Libre", faction = "villain", price = 450,  blurb = "The luchador bruiser — grapples and slams." },
	{ name = "Carnage",        faction = "villain", price = 650,  blurb = "Symbiote chaos — claws, tendrils, and dread." },
	{ name = "Golden Knight",  faction = "villain", price = 850,  blurb = "Null's radiant champion. Light made lethal." },
	{ name = "Minus",          faction = "villain", price = 1000, blurb = "The gator general and his army's fury." },
	{ name = "Void Overlord",  faction = "villain", price = 1400, blurb = "Master of the Void invasion. Space-warping power." },
	{ name = "Null",           faction = "villain", price = 1800, blurb = "The master of darkness. Shadow incarnate." },
	{ name = "Manderin",       faction = "villain", price = 2200, blurb = "The dictator of Metro City. Tech-empire might." },
	{ name = "Nemesis",        faction = "villain", price = 2600, blurb = "The controller of time and Daniel Storm." },
	{ name = "The Anonymous",  faction = "villain", price = 3000, blurb = "The mind behind the loops. Reality itself bends." },
	{ name = "Omega",          faction = "villain", price = 4000, blurb = "The planet-destroyer. The ultimate unlock." },
}

function ShopCatalog.get(name)
	for _, item in ipairs(ShopCatalog.Items) do
		if item.name == name then return item end
	end
	return nil
end

function ShopCatalog.priceOf(name)
	local item = ShopCatalog.get(name)
	return item and item.price or nil
end

function ShopCatalog.factionOf(name)
	local item = ShopCatalog.get(name)
	return item and item.faction or nil
end

-- names owned-by-default are NOT in the catalog; this is only the paid extras.
function ShopCatalog.forFaction(faction)
	local out = {}
	for _, item in ipairs(ShopCatalog.Items) do
		if item.faction == faction then out[#out + 1] = item end
	end
	return out
end

return ShopCatalog
