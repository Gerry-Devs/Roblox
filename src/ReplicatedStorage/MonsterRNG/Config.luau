local Config = {}

Config.GameName = "Monster RNG"
Config.BaseSlots = 6
Config.BackpackCap = 100
Config.PenEggCap = 5
Config.PenMonsterCap = 3
Config.PenPlacementMargin = 5 -- studs of buffer kept clear inside the fence line
Config.StartingCash = 250
Config.BossPower = 325
Config.BossReward = 750

-- Gamepass ID gating the "Sell All Eggs" backpack button. Leave at 0 to
-- keep the feature free for everyone (no Marketplace calls happen at
-- all); set it to a real gamepass ID from the Creator Dashboard once
-- you want to monetize it and both client and server will start
-- checking/prompting for ownership automatically.
Config.SellAllGamepassId = 0

-- How long one roll takes (animation + cooldown), in seconds. The Roll
-- Speed upgrade shortens it by its total % (see UpgradeStatInfo.rollSpeed).
-- Applies to hidden rolls and auto roll too, and the server enforces it.
Config.BaseRollDuration = 4.5

-- Hidden pity: every PityEvery-th roll gets PityLuckMultiplier x luck
-- (nothing is shown to the player).
Config.PityEvery = 25
Config.PityLuckMultiplier = 2
Config.MinRollDuration = 1.2

function Config.GetRollDuration(upgrades)
	local bonus = Config.GetUpgradeBonus and Config.GetUpgradeBonus(upgrades, "rollSpeed") or 0
	return math.max(Config.MinRollDuration, Config.BaseRollDuration * (1 - bonus / 100))
end
Config.PityThresholds = {
	rare = 40,
	epic = 80,
	legendary = 150,
}

Config.SizeVariants = {
	{
		key = "Normal",
		name = "Normal",
		weight = 93,
		incomeMultiplier = 1,
		powerMultiplier = 1,
		scale = 1,
	},
	{
		key = "Huge",
		name = "Huge",
		weight = 6,
		incomeMultiplier = 5,
		powerMultiplier = 3,
		scale = 1.45,
	},
	{
		key = "Titan",
		name = "Titan",
		weight = 1,
		incomeMultiplier = 20,
		powerMultiplier = 8,
		scale = 2.1,
	},
}

Config.FinishVariants = {
	{
		key = "Normal",
		name = "Normal",
		weight = 90,
		incomeMultiplier = 1,
		powerMultiplier = 1,
	},
	{
		key = "Gold",
		name = "Gold",
		weight = 7,
		incomeMultiplier = 2.5,
		powerMultiplier = 1.5,
	},
	{
		key = "Silver",
		name = "Silver",
		weight = 2,
		incomeMultiplier = 4,
		powerMultiplier = 2,
	},
	{
		key = "Rainbow",
		name = "Rainbow",
		weight = 1,
		incomeMultiplier = 10,
		powerMultiplier = 4,
	},
}

Config.ShopItems = {
	luckPotion = {
		name = "Luck Potion",
		cost = 250,
		description = "+1 permanent luck",
	},
	incomeBoost = {
		name = "Base Booster",
		cost = 1000,
		description = "+25% base income",
	},
}

Config.Rarities = {
	{
		name = "Common",
		key = "Common",
		weight = 60,
		tier = 1,
		color = { 155, 166, 180 },
	},
	{
		name = "Uncommon",
		key = "Uncommon",
		weight = 25,
		tier = 2,
		color = { 91, 205, 143 },
	},
	{
		name = "Rare",
		key = "Rare",
		weight = 10,
		tier = 3,
		color = { 75, 160, 255 },
	},
	{
		name = "Epic",
		key = "Epic",
		weight = 4,
		tier = 4,
		color = { 176, 102, 255 },
	},
	{
		name = "Legendary",
		key = "Legendary",
		weight = 0.9,
		tier = 5,
		color = { 255, 180, 67 },
	},
	{
		name = "Mythic",
		key = "Mythic",
		weight = 0.1,
		tier = 6,
		color = { 255, 82, 139 },
	},
	-- the 4 "wheel" rarities: tiny chance in normal rolls, much better
	-- from the WILD wheel (see Config.Wild)
	{
		name = "Secret",
		key = "Secret",
		weight = 0.01, -- ~1 in 10,000
		tier = 7,
		color = { 160, 150, 190 },
	},
	{
		name = "Celestial",
		key = "Celestial",
		weight = 0.002, -- ~1 in 50,000
		tier = 8,
		color = { 120, 215, 255 },
	},
	{
		name = "Divine",
		key = "Divine",
		weight = 0.0004, -- ~1 in 250,000
		tier = 9,
		color = { 255, 228, 130 },
	},
	{
		name = "Supreme",
		key = "Supreme",
		weight = 0.0001, -- ~1 in 1,000,000
		tier = 10,
		color = { 255, 70, 70 },
	},
}

Config.Monsters = {
	{
		id = "slime",
		name = "Moss Slime",
		rarity = "Common",
		power = 5,
		description = "A tiny explorer with a big appetite.",
	},
	{
		id = "bat",
		name = "Cave Bat",
		rarity = "Common",
		power = 8,
		description = "It knows every dark corner of the island.",
	},
	{
		id = "mushroom",
		name = "Glowcap",
		rarity = "Uncommon",
		power = 18,
		description = "Its spores light up the night.",
	},
	{
		id = "crab",
		name = "Ironclaw Crab",
		rarity = "Uncommon",
		power = 23,
		description = "Hard shell, harder attitude.",
	},
	{
		id = "wolf",
		name = "Frostfang Wolf",
		rarity = "Rare",
		power = 42,
		description = "A fast hunter from the frozen peaks.",
	},
	{
		id = "golem",
		name = "Runestone Golem",
		rarity = "Rare",
		power = 51,
		description = "Ancient runes pulse beneath its stone skin.",
	},
	{
		id = "phoenix",
		name = "Ember Phoenix",
		rarity = "Epic",
		power = 88,
		description = "A blazing bird that refuses to stay defeated.",
	},
	{
		id = "leviathan",
		name = "Storm Leviathan",
		rarity = "Legendary",
		power = 150,
		description = "The sea itself moves when it wakes.",
	},
	{
		id = "void-dragon",
		name = "Void Dragon",
		rarity = "Mythic",
		power = 300,
		description = "A monster from the space between worlds.",
	},
	{
		id = "wraith",
		name = "Shadow Wraith",
		rarity = "Secret",
		power = 700,
		description = "Nobody has seen its face and lived to tell.",
	},
	{
		id = "seraph",
		name = "Star Seraph",
		rarity = "Celestial",
		power = 1600,
		description = "Born from a falling star, it burns with holy light.",
	},
	{
		id = "titan",
		name = "Sun Titan",
		rarity = "Divine",
		power = 3800,
		description = "A giant of living gold with the sun in its chest.",
	},
	{
		id = "emperor",
		name = "Cosmic Emperor",
		rarity = "Supreme",
		power = 9000,
		description = "It wears the galaxy as a crown.",
	},
}

--------------------------------------------------------------------
-- WILD rolls: each roll can land on WILD, which rolls again. Getting 3
-- WILDs in a row (chances multiplied together) spins the egg wheel.
-- 0.15 x 0.3 x 0.15 = 0.00675 -> about 1 in 150 rolls gets 3 WILDs.
--------------------------------------------------------------------
Config.Wild = {
	chances = { 0.004, 0.3, 0.15 }, -- 1st WILD ~1 in 250 rolls, then 2nd, then 3rd
	wheel = { -- the egg wheel after 3 WILDs (weights = % chance)
		{ rarity = "Mythic", weight = 50 },
		{ rarity = "Secret", weight = 25 },
		{ rarity = "Celestial", weight = 15 },
		{ rarity = "Divine", weight = 7 },
		{ rarity = "Supreme", weight = 3 },
	},
}

--------------------------------------------------------------------
-- Sounds + music (all from Roblox's licensed libraries; swap any id)
--------------------------------------------------------------------
Config.Sounds = {
	hatchRattle = "rbxassetid://9116420445", -- egg rattling while it hatches
	eggCrack = { "rbxassetid://9113959343", "rbxassetid://9113959071", "rbxassetid://9113958649" },
	hatchReveal = "rbxassetid://9116418035", -- the monster pops out
	wild = "rbxassetid://9125647212", -- WILD roll
	wheelTick = "rbxassetid://9113650981", -- the egg wheel ticking
	music = { -- plays when you enter the biome
		forest = "rbxassetid://82900133335093", -- "Peaceful Breeze" (the birds were only a quiet 10s ambience)
		desert = "rbxassetid://1838819842",
		volcanic = "rbxassetid://1842089558",
		tundra = "rbxassetid://9046912294",
		candy = "rbxassetid://9048060259",
		atlantis = "rbxassetid://91587908006120",
	},
	town = { -- Monster Town: one of these plays now and then
		"rbxassetid://9119383479",
		"rbxassetid://9038472426",
		"rbxassetid://9038464849",
	},
	musicVolume = 0.35,
	townVolume = 0.4,
}

--------------------------------------------------------------------
-- Gamepasses (shown in the Shop). imageId = the icon shown on its card.
-- Perks stack (2x Cash + VIP = 2.4x cash).
--------------------------------------------------------------------
Config.Gamepasses = {
	{ key = "doubleRoll", id = 1999533030, name = "Double Roll", imageId = "rbxassetid://71391623130051", perks = { "Roll 2 eggs at the same time" } },
	{ key = "doubleCash", id = 1998645039, name = "2x Cash", imageId = "rbxassetid://102064029314139", perks = { "Double cash per second" } },
	{ key = "vip", id = 1998465046, name = "VIP", imageId = "rbxassetid://81291811946600", perks = { "VIP name tag + chat tag", "+20% cash", "+10% roll speed", "+15% walk speed", "Double daily rewards", "+20% offline earnings" } },
	{ key = "autoSell", id = 1998668994, name = "Auto Sell", imageId = "rbxassetid://119296484955284", perks = { "Sells eggs + monsters for you", "By rarity or by cash/s" } },
	{ key = "fastRoll", id = 1999971018, name = "Fast Roll", imageId = "rbxassetid://105094275388977", perks = { "Roll 30% faster" } },
	{ key = "moreDrops", id = 1997943032, name = "More Drops", imageId = "rbxassetid://72855230975729", perks = { "+25% enemy drop chance" } },
	{ key = "fastGrowth", id = 1997853055, name = "Fast Growth", imageId = "rbxassetid://101168030555227", perks = { "Eggs hatch 2x faster" } },
	{ key = "plusMonster", id = 1999821057, name = "+1 Monster", imageId = "rbxassetid://115233703785640", perks = { "Equip 1 more monster" } },
	{ key = "supporter", id = 1998483043, name = "Supporter", imageId = "rbxassetid://109467610783421", perks = { "Violet SUPPORTER chat tag", "+10% drop chance" } },
}
-- name / chat tags (a player with both picks one in Settings)
Config.PassTags = {
	dev = { text = "DEV", color = { 255, 70, 70 } },
	admin = { text = "ADMIN", color = { 255, 120, 40 } },
	tester = { text = "TESTER", color = { 70, 220, 140 } },
	beta = { text = "BETA", color = { 90, 180, 255 } },
	vip = { text = "VIP", color = { 255, 205, 60 } },
	supporter = { text = "SUPPORTER", color = { 170, 90, 255 } },
}
Config.TagOrder = { "dev", "admin", "tester", "beta", "vip", "supporter" }
Config.DevUserIds = { [1165846861] = true }
-- tags a player can pick: DEV (the developer), ADMIN / TESTER / BETA
-- (given from the admin panel, saved in profile.tags), VIP / SUPPORTER
-- (from their gamepasses)
function Config.OwnedTags(profile, userId)
	local list = {}
	for _, key in ipairs(Config.TagOrder) do
		local has
		if key == "dev" then
			has = Config.DevUserIds[userId or 0] == true
		elseif key == "vip" or key == "supporter" then
			has = Config.HasPass(profile, key)
		else
			has = profile ~= nil and profile.tags ~= nil and profile.tags[key] == true
		end
		if has then
			table.insert(list, key)
		end
	end
	return list
end
-- bought on Roblox (profile.passes) OR given by the admin (profile.adminPasses)
function Config.HasPass(profile, key)
	return profile ~= nil and ((profile.passes ~= nil and profile.passes[key] == true) or (profile.adminPasses ~= nil and profile.adminPasses[key] == true))
end

--------------------------------------------------------------------
-- Developer products
--------------------------------------------------------------------
Config.Products = {
	hatchAll = { id = 3715373678, name = "Hatch All", text = "Hatch every egg in your pen right now", imageId = "rbxassetid://130974608848145" },
	eggSkipImageId = "rbxassetid://92696344635446",
	-- skip an egg's timer: the smallest one that covers the time left
	eggSkip = {
		{ hours = 1, id = 3715373716 },
		{ hours = 2, id = 3715373757 },
		{ hours = 4, id = 3715373784 },
		{ hours = 8, id = 3715373853 },
		{ hours = 16, id = 3715373921 },
		{ hours = 24, id = 3715373963 },
	},
	-- cash packs: % of the cash needed for your NEXT rebirth (so they grow
	-- every time you rebirth). imageId = shop icon.
	cash = {
		{ key = "pile", id = 3715372817, name = "Pile of Cash", pct = 15, imageId = "rbxassetid://108795853438549" },
		{ key = "stack", id = 3715372907, name = "Stack of Cash", pct = 25, imageId = "rbxassetid://129937593396264" },
		{ key = "bag", id = 3715372954, name = "Bag of Cash", pct = 40, imageId = "rbxassetid://140614516823162" },
		{ key = "bucket", id = 3715373030, name = "Bucket of Cash", pct = 60, imageId = "rbxassetid://111008016370758" },
		{ key = "mountain", id = 3715373095, name = "Mountain of Cash", pct = 100, imageId = "rbxassetid://132031668570337" },
		{ key = "cargo", id = 3715373180, name = "Cargo of Cash", pct = 200, imageId = "rbxassetid://124099272667082" },
	},
}
function Config.EggSkipTier(secondsLeft)
	for _, tier in ipairs(Config.Products.eggSkip) do
		if secondsLeft <= tier.hours * 3600 then
			return tier
		end
	end
	return Config.Products.eggSkip[#Config.Products.eggSkip]
end
function Config.CashPackAmount(profile, pct)
	local cost = Config.GetRebirthCost(profile and profile.rebirths or 0)
	return math.floor(cost * pct / 100)
end
function Config.PassCashMultiplier(p)
	return (Config.HasPass(p, "doubleCash") and 2 or 1) * (Config.HasPass(p, "vip") and 1.2 or 1)
end
function Config.PassRollTimeMultiplier(p) -- lower = faster
	return (Config.HasPass(p, "fastRoll") and 0.7 or 1) * (Config.HasPass(p, "vip") and 0.9 or 1)
end
function Config.PassDropMultiplier(p)
	return (Config.HasPass(p, "moreDrops") and 1.25 or 1) * (Config.HasPass(p, "supporter") and 1.1 or 1)
end
function Config.PassHatchMultiplier(p) -- lower = faster
	return Config.HasPass(p, "fastGrowth") and 0.5 or 1
end
function Config.PassExtraMonsters(p)
	return Config.HasPass(p, "plusMonster") and 1 or 0
end
-- Critical hits: chance (0-1) and damage multiplier with upgrades
function Config.CritStats(profile)
	local C = Config.Combat
	local chance = (C.critChance + Config.GetUpgradeBonus(profile and profile.upgrades, "critChance")) / 100
	local mult = C.critMultiplier + Config.GetUpgradeBonus(profile and profile.upgrades, "critDamage") / 100
	return math.clamp(chance, 0, 1), mult
end

-- Offline earnings: your pen keeps earning while you're away
Config.Offline = { baseHours = 2, rate = 0.5, vipBonus = 0.2, minSeconds = 60 }
function Config.OfflineHours(profile)
	return Config.Offline.baseHours + Config.GetUpgradeBonus(profile and profile.upgrades, "offlineTime")
end
function Config.OfflineRate(profile)
	return Config.Offline.rate + (Config.HasPass(profile, "vip") and Config.Offline.vipBonus or 0)
end
function Config.PassWalkMultiplier(p)
	return Config.HasPass(p, "vip") and 1.15 or 1
end
function Config.PassDailyMultiplier(p)
	return Config.HasPass(p, "vip") and 2 or 1
end

-- Auto Sell gamepass
Config.AutoSellGamepassId = 1998668994

function Config.GetRarity(rarityName)
	for _, rarity in ipairs(Config.Rarities) do
		if rarity.key == rarityName then
			return rarity
		end
	end
	return Config.Rarities[1]
end

function Config.GetMonster(monsterId)
	for _, monster in ipairs(Config.Monsters) do
		if monster.id == monsterId then
			return monster
		end
	end
	return nil
end

function Config.GetSizeVariant(sizeKey)
	for _, variant in ipairs(Config.SizeVariants) do
		if variant.key == sizeKey then
			return variant
		end
	end
	return Config.SizeVariants[1]
end

function Config.GetFinishVariant(finishKey)
	for _, variant in ipairs(Config.FinishVariants) do
		if variant.key == finishKey then
			return variant
		end
	end
	return Config.FinishVariants[1]
end

function Config.GetUpgradeCost(level)
	return math.floor(100 * (level or 1) ^ 1.65)
end

function Config.NextPityThreshold(pity)
	local thresholds = {
		{ value = Config.PityThresholds.rare, label = "Rare" },
		{ value = Config.PityThresholds.epic, label = "Epic" },
		{ value = Config.PityThresholds.legendary, label = "Legendary" },
	}
	for _, entry in ipairs(thresholds) do
		if pity < entry.value then
			return entry
		end
	end
	return thresholds[#thresholds]
end

Config.HatchDurations = {
	Common = 20,
	Uncommon = 45,
	Rare = 90,
	Epic = 180,
	Legendary = 360,
	Mythic = 720,
	Secret = 1440,
	Celestial = 2400,
	Divine = 3000,
	Supreme = 3600,
}

function Config.GetHatchDuration(rarityKey)
	return Config.HatchDurations[rarityKey] or 30
end

--------------------------------------------------------------------
-- Upgrade tree
--
-- Fully data-driven: to add a stat, add it to a branch below and give
-- it a base cost + per-tier value. To retune costs/values, just edit
-- the numbers here — nothing else in the codebase needs to change.
-- Each node has an `imageId` slot (blank by default) for a custom
-- uploaded hex icon; set it to "rbxassetid://..." once you have one.
--------------------------------------------------------------------

Config.UpgradeBranches = {
	{ key = "economy", name = "Economy", icon = "\240\159\146\176", stats = { "cash", "backpackCap", "offlineTime" } },
	{ key = "fortune", name = "Fortune", icon = "\240\159\141\128", stats = { "luck", "drops", "potionDrop", "crystal", "shardSurge" } },
	{ key = "combat", name = "Combat", icon = "\226\154\148\239\184\143", stats = { "health", "damage", "critChance", "critDamage" } },
	{ key = "variants", name = "Variants", icon = "\226\156\168", stats = { "mutation", "size" } },
	{ key = "capacity", name = "Capacity", icon = "\240\159\147\166", stats = { "monsterCap", "eggCap" } },
	{ key = "player", name = "Player", icon = "\240\159\143\131", stats = { "speed", "rollSpeed" } },
}

-- Shared hex-shaped background asset for every upgrade node in the UI.
-- Leave blank to use the built-in rounded-square fallback (still looks
-- clean with zero custom art); set to "rbxassetid://..." once you have
-- a hex frame you like and every node picks it up automatically.
Config.UpgradeHexImage = ""

-- Your own hexagon image for each upgrade (every tier of that upgrade uses
-- it). Leave "" to use the drawn hexagon. To give one single tier its own
-- image instead, set that node's imageId in Config.UpgradeNodes.
Config.UpgradeStatImages = {
	cash = "",
	backpackCap = "",
	offlineTime = "",
	luck = "",
	drops = "",
	potionDrop = "",
	crystal = "",
	shardSurge = "",
	health = "",
	damage = "",
	critChance = "",
	critDamage = "",
	mutation = "",
	size = "",
	monsterCap = "",
	eggCap = "",
	speed = "",
	rollSpeed = "",
}

Config.UpgradeStatInfo = {
	cash = { name = "Cash", unit = "%", live = true },
	backpackCap = { name = "Backpack", unit = "", live = true },
	offlineTime = { name = "Offline Time", unit = "h", live = true }, -- longer offline earnings
	luck = { name = "Luck", unit = "", live = true },
	drops = { name = "Drops", unit = "%", live = true }, -- Rift Shard drop chance
	potionDrop = { name = "Potion Drop", unit = "%", live = true }, -- potion drop chance
	crystal = { name = "Rift Shards", unit = "%", live = true }, -- more shards per drop
	shardSurge = { name = "Shard Surge", unit = "%", live = true }, -- chance a shard drop is doubled
	health = { name = "Health", unit = "%", live = true },
	damage = { name = "Damage", unit = "%", live = true },
	critChance = { name = "Crit Chance", unit = "%", live = true },
	critDamage = { name = "Crit Damage", unit = "%", live = true },
	mutation = { name = "Mutation", unit = "%", live = true },
	size = { name = "Size", unit = "%", live = true },
	monsterCap = { name = "Monster Cap", unit = "", live = true },
	eggCap = { name = "Egg Cap", unit = "", live = true },
	speed = { name = "Speed", unit = "%", live = true },
	rollSpeed = { name = "Roll Speed", unit = "%", live = true },
}

-- Upgrades are permanent (they survive rebirth), so the tree is long:
-- tier 1 is cheap for new players, and each tier costs GROWTH x the one
-- before it (x3 by default -> tier 5 = 81x, tier 10 = ~19,700x the base).
-- The number of tiers of a stat = how many values are in TIER_VALUES.
local BASE_COST = {
	cash = 1000000, -- income: $1M -> $10M -> $100M -> $1B -> $10B ...
	backpackCap = 800,
	offlineTime = 50000, -- $50K -> $500K -> $5M ...
	luck = 1500,
	drops = 500000, -- Rift Shard drop chance: $500K -> $5M -> ...
	potionDrop = 2000,
	crystal = 1000000, -- Rift Shards per drop: $1M -> $10M -> ...
	shardSurge = 2000000, -- chance to double a shard drop: $2M -> $20M -> ...
	health = 1000,
	damage = 1000,
	critChance = 5000,
	critDamage = 5000,
	mutation = 3000,
	size = 3000,
	monsterCap = 100000, -- only 3 tiers (3 -> 6 pets), very expensive
	eggCap = 2000,
	speed = 600,
	rollSpeed = 2500,
}

local GROWTH = {
	monsterCap = 20, -- $100K -> $2M -> $40M
}
local DEFAULT_GROWTH = 10 -- each tier costs 10x the one before

local TIER_VALUES = {
	-- every upgrade is about 1.7x stronger than before (3% -> 5% per level)
	cash = { 8, 8, 8, 8, 15, 15, 15, 25, 25, 35 }, -- +162% income total
	backpackCap = { 40, 40, 40, 40, 40, 40, 40, 40, 40, 40 }, -- +400 slots
	offlineTime = { 1, 1, 1, 1, 1, 1 }, -- +1 hour each: 2h -> 8h
	luck = { 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5 },
	drops = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 }, -- +50% Rift Shard drop chance
	potionDrop = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 }, -- +50% potion drop chance
	crystal = { 15, 15, 15, 15, 15, 15, 15, 15, 15, 15 }, -- +150% shards per drop
	shardSurge = { 6, 6, 6, 6, 6, 6, 6, 6, 6, 6 }, -- up to 60% chance to double a shard drop
	health = { 15, 15, 15, 15, 25, 25, 25, 35, 35, 40 }, -- +265% pet health
	damage = { 15, 15, 15, 15, 25, 25, 25, 35, 35, 40 }, -- +265% pet damage
	critChance = { 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 }, -- +0.5% each: 5% base -> 10% chance to crit
	critDamage = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }, -- +2% each: 1.5x base -> 1.7x crit damage
	mutation = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	size = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	monsterCap = { 1, 1, 1 },
	eggCap = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }, -- 5 -> 25 eggs
	speed = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	rollSpeed = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
}

Config.UpgradeNodes = {}
for _, branch in ipairs(Config.UpgradeBranches) do
	for _, statKey in ipairs(branch.stats) do
		local previousId = nil
		local growth = GROWTH[statKey] or DEFAULT_GROWTH
		for tier, value in ipairs(TIER_VALUES[statKey]) do
			local id = statKey .. tier
			table.insert(Config.UpgradeNodes, {
				id = id,
				statKey = statKey,
				branch = branch.key,
				tier = tier,
				cost = math.floor(BASE_COST[statKey] * growth ^ (tier - 1)),
				value = value,
				requires = previousId,
				imageId = "",
			})
			previousId = id
		end
	end
end

function Config.GetUpgradeTierCount(statKey)
	return #(TIER_VALUES[statKey] or {})
end

function Config.GetUpgradeNode(id)
	for _, node in ipairs(Config.UpgradeNodes) do
		if node.id == id then
			return node
		end
	end
	return nil
end

-- Sum of `value` across every purchased node for a given stat. `upgrades`
-- is the profile's { [nodeId] = true } purchase table.
function Config.GetUpgradeBonus(upgrades, statKey)
	local total = 0
	if type(upgrades) ~= "table" then
		return total
	end
	for _, node in ipairs(Config.UpgradeNodes) do
		if node.statKey == statKey and upgrades[node.id] then
			total += node.value
		end
	end
	return total
end

-- Capacity limits including upgrades (the upgrade values were bought but
-- previously never applied — everything now goes through these).
function Config.GetBackpackCap(upgrades)
	return Config.BackpackCap + Config.GetUpgradeBonus(upgrades, "backpackCap")
end

function Config.GetPenMonsterCap(upgrades)
	return Config.PenMonsterCap + Config.GetUpgradeBonus(upgrades, "monsterCap")
end

function Config.GetPenEggCap(upgrades)
	return Config.PenEggCap + Config.GetUpgradeBonus(upgrades, "eggCap")
end

-- Hatching: the egg shakes for HatchShakeTime seconds, the monster pops
-- out, and its info floats above it for HatchInfoTime seconds.
Config.HatchShakeTime = 4.5
Config.HatchInfoTime = 2.5

-- Base odds of rolling this exact monster + size + finish (no luck/pity),
-- e.g. Moss Slime ≈ 1 in 3, Huge Rainbow Moss Slime ≈ 1 in 5,000.
--------------------------------------------------------------------
-- Weight (kg). Each monster rolls a random kg; heavier = rarer. The kg
-- only raises the odds once it's heavier than about half of its kind.
--------------------------------------------------------------------
-- kg follows a long-tail curve: most monsters are near their base weight,
-- and heavier ones get rarer and rarer, up to MaxKg. Reaching 100,000 kg
-- is roughly 1 in millions.
Config.KgRarity = 1.4 -- higher = heavy monsters are rarer
Config.MaxKg = 100000

function Config.GetBaseKg(monsterId, sizeKey)
	local monster = Config.GetMonster(monsterId)
	local base = 1 + ((monster and monster.power) or 10) / 10
	local scale = Config.GetSizeVariant(sizeKey).scale or 1
	return base * scale * scale
end

function Config.RollKg(monsterId, sizeKey)
	local u = math.max(1e-12, math.random())
	local factor = u ^ (-1 / Config.KgRarity)
	local kg = Config.GetBaseKg(monsterId, sizeKey) * factor
	return math.min(Config.MaxKg, math.floor(kg * 10 + 0.5) / 10)
end

-- chance to roll at least this heavy = (kg / base) ^ -KgRarity
function Config.GetKgOddsMultiplier(monsterId, sizeKey, kg)
	if type(kg) ~= "number" then
		return 1
	end
	local f = kg / Config.GetBaseKg(monsterId, sizeKey)
	if f <= 1 then
		return 1
	end
	local chanceAtLeast = f ^ (-Config.KgRarity)
	return math.max(1, 0.5 / chanceAtLeast)
end

-- heavier monsters earn more cash/s: x (kg / base kg) ^ 0.5
function Config.GetKgIncomeMultiplier(entry)
	if type(entry.kg) ~= "number" or not entry.monsterId then
		return 1
	end
	local f = entry.kg / Config.GetBaseKg(entry.monsterId, entry.size)
	return math.max(1, f) ^ 0.5
end

function Config.FormatKg(kg)
	if type(kg) ~= "number" then
		return ""
	end
	if kg >= 1000 then
		return Config.FormatNumber(kg) .. " kg"
	end
	return string.format("%.1f kg", kg)
end

function Config.GetOdds(monsterId, sizeKey, finishKey, kg)
	local monster = Config.GetMonster(monsterId)
	if not monster then
		return 0
	end
	local totalRarity = 0
	for _, r in ipairs(Config.Rarities) do
		totalRarity += r.weight
	end
	local sameRarity = 0
	for _, m in ipairs(Config.Monsters) do
		if m.rarity == monster.rarity then
			sameRarity += 1
		end
	end
	local function variantChance(list, key)
		local total, weight = 0, 0
		for _, v in ipairs(list) do
			total += v.weight
			if v.key == key then
				weight = v.weight
			end
		end
		return total > 0 and weight / total or 0
	end
	local rarity = Config.GetRarity(monster.rarity)
	local p = (rarity.weight / totalRarity) / math.max(1, sameRarity)
		* variantChance(Config.SizeVariants, sizeKey or "Normal")
		* variantChance(Config.FinishVariants, finishKey or "Normal")
	p = p / Config.GetKgOddsMultiplier(monsterId, sizeKey, kg)
	if p <= 0 then
		return 0
	end
	return math.max(1, math.floor(1 / p + 0.5))
end

-- Hatch time of a specific egg, based on the cash/s the monster inside
-- will make (which already includes rarity, size, finish and kg):
-- ~6 $/s -> 25s, ~25 $/s -> 2 min, ~60 $/s -> 5.5 min, capped at 1 hour.
Config.HatchTimeBase = 3.5
Config.HatchTimeExponent = 1.1
Config.HatchTimeMin = 15
Config.HatchTimeMax = 3600

function Config.GetEggHatchDuration(egg)
	local income = Config.GetEntryIncome(egg)
	if not income or income <= 0 then
		return Config.GetHatchDuration(egg.rarity)
	end
	return math.floor(math.clamp(Config.HatchTimeBase * income ^ Config.HatchTimeExponent, Config.HatchTimeMin, Config.HatchTimeMax))
end

function Config.FormatDuration(secs)
	secs = math.max(0, math.ceil(secs))
	if secs >= 3600 then
		return string.format("%dh %dm", secs // 3600, (secs % 3600) // 60)
	elseif secs >= 60 then
		return string.format("%dm %ds", secs // 60, secs % 60)
	end
	return secs .. "s"
end

function Config.FormatOdds(n)
	local s
	if n >= 1e6 then
		s = string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		s = string.format("%.1fK", n / 1e3)
	else
		s = tostring(n)
	end
	s = s:gsub("%.0([KM])", "%1")
	return "1 in " .. s
end

--------------------------------------------------------------------
-- Dice (sold at the Dice Shop stall). The equipped dice multiplies the
-- chance of every rarity above Common by (1 + luck%). imageId is a
-- slot for your own dice icon.
--------------------------------------------------------------------
Config.Dice = {
	{ key = "common", name = "Common Dice", luck = 0, cost = 0, color = { 155, 166, 180 }, imageId = "" },
	{ key = "uncommon", name = "Uncommon Dice", luck = 1, cost = 200000, color = { 91, 205, 143 }, imageId = "rbxassetid://123743310892109" },
	{ key = "rare", name = "Rare Dice", luck = 2, cost = 4000000, color = { 75, 160, 255 }, imageId = "rbxassetid://118515790782413" },
	{ key = "epic", name = "Epic Dice", luck = 3, cost = 60000000, color = { 176, 102, 255 }, imageId = "rbxassetid://121811100357188" },
	{ key = "legendary", name = "Legendary Dice", luck = 5, cost = 800000000, color = { 255, 180, 67 }, imageId = "rbxassetid://89543967956550" },
	{ key = "mythic", name = "Mythic Dice", luck = 7, cost = 12000000000, color = { 255, 82, 139 }, imageId = "rbxassetid://121229103557418" },
	{ key = "secret", name = "Secret Dice", luck = 10, cost = 200000000000, color = { 160, 150, 190 }, imageId = "rbxassetid://72694947695527" },
	{ key = "celestial", name = "Celestial Dice", luck = 14, cost = 4000000000000, color = { 120, 215, 255 }, imageId = "rbxassetid://71725518426639" },
	{ key = "divine", name = "Divine Dice", luck = 19, cost = 80000000000000, color = { 255, 228, 130 }, imageId = "rbxassetid://130366771307960" },
	{ key = "supreme", name = "Supreme Dice", luck = 25, cost = 2000000000000000, color = { 255, 90, 60 }, imageId = "rbxassetid://99080298269341" },
}

function Config.FindDice(key)
	for _, d in ipairs(Config.Dice) do
		if d.key == key then
			return d
		end
	end
	return nil
end

function Config.GetDice(key)
	return Config.FindDice(key) or Config.Dice[1]
end

-- 500001 -> "500K", 1250000 -> "1.2M"
function Config.FormatNumber(n)
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	local suffixes = { "K", "M", "B", "T", "Qd", "Qn" }
	local i, v = 0, n
	while v >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	local s
	if v >= 100 then
		s = tostring(math.floor(v))
	else
		s = string.format("%.1f", math.floor(v * 10) / 10):gsub("%.0$", "")
	end
	return s .. suffixes[i]
end

-- Cash per second of one monster (same formula the server uses).
function Config.GetEntryIncome(entry)
	local monster = Config.GetMonster(entry.monsterId)
	if not monster then
		return 0
	end
	local rarity = Config.GetRarity(monster.rarity)
	local size = Config.GetSizeVariant(entry.size)
	local finish = Config.GetFinishVariant(entry.finish)
	local levelMultiplier = math.max(1, entry.level or 1) ^ 1.25
	return math.max(1, math.floor((rarity.tier * 5 + monster.power * 0.25) * size.incomeMultiplier * finish.incomeMultiplier * levelMultiplier * Config.GetKgIncomeMultiplier(entry)))
end

--------------------------------------------------------------------
-- Biomes. Each is the size of the home map (480 x 400 studs), laid out
-- in a 3 x 2 grid in front of it. center = (X, Z). imageId is a slot for
-- an icon shown on the "you entered" banner. tiles = checker colors.
--------------------------------------------------------------------
local BIOME_SIZE = Vector2.new(480, 400)
-- In a straight line going out from the lobby's front edge (z = -140):
-- Forest -> Desert -> Volcanic -> Tundra -> Candy Land -> Atlantis.
-- mountain = colors of the side mountains (dirt/body + cap), 2 shades each.
Config.Biomes = {
	{ key = "home", name = "Home", subtitle = "Monster Town", center = Vector2.new(0, 60), size = BIOME_SIZE, color = { 255, 205, 93 }, imageId = "" },
	{ key = "forest", cost = 25000, name = "Whispering Woods", subtitle = "Forest", center = Vector2.new(0, -340), size = BIOME_SIZE, color = { 120, 220, 110 }, imageId = "",
		tiles = { { 70, 150, 60 }, { 58, 132, 52 } },
		mountain = { dirt = { { 135, 90, 52 }, { 118, 78, 45 } }, cap = { { 70, 150, 60 }, { 58, 132, 52 } } } },
	{ key = "desert", cost = 250000, name = "Scorched Dunes", subtitle = "Desert", center = Vector2.new(0, -740), size = BIOME_SIZE, color = { 255, 200, 110 }, imageId = "",
		tiles = { { 236, 206, 142 }, { 222, 190, 124 } },
		mountain = { dirt = { { 205, 160, 100 }, { 190, 145, 88 } }, cap = { { 236, 206, 142 }, { 222, 190, 124 } } } },
	{ key = "volcanic", cost = 2000000, name = "Obsidian Crags", subtitle = "Volcanic", center = Vector2.new(0, -1140), size = BIOME_SIZE, color = { 255, 110, 50 }, imageId = "",
		tiles = { { 64, 58, 64 }, { 50, 46, 54 } },
		mountain = { dirt = { { 50, 45, 52 }, { 40, 36, 44 } }, cap = { { 95, 82, 88 }, { 78, 68, 74 } } } },
	{ key = "tundra", cost = 15000000, name = "Frostbite Steppes", subtitle = "Tundra", center = Vector2.new(0, -1540), size = BIOME_SIZE, color = { 170, 230, 255 }, imageId = "",
		tiles = { { 240, 246, 255 }, { 222, 234, 246 } },
		mountain = { dirt = { { 120, 125, 140 }, { 105, 110, 125 } }, cap = { { 245, 250, 255 }, { 228, 238, 248 } } } },
	{ key = "candy", cost = 100000000, name = "Confection Kingdom", subtitle = "Candy Land", center = Vector2.new(0, -1940), size = BIOME_SIZE, color = { 255, 140, 200 }, imageId = "",
		tiles = { { 255, 182, 215 }, { 255, 160, 200 } },
		mountain = { dirt = { { 110, 65, 40 }, { 95, 55, 35 } }, cap = { { 255, 170, 210 }, { 255, 150, 195 } } } },
	{ key = "atlantis", cost = 750000000, name = "Sunken Abyss", subtitle = "Atlantis", center = Vector2.new(0, -2340), size = BIOME_SIZE, color = { 90, 200, 255 }, imageId = "",
		tiles = { { 72, 170, 182 }, { 60, 152, 168 } },
		mountain = { dirt = { { 90, 120, 130 }, { 78, 106, 118 } }, cap = { { 72, 170, 182 }, { 60, 152, 168 } } } },
}

function Config.GetBiomeAt(x, z)
	for _, b in ipairs(Config.Biomes) do
		if math.abs(x - b.center.X) <= b.size.X / 2 and math.abs(z - b.center.Y) <= b.size.Y / 2 then
			return b
		end
	end
	return nil
end

-- Icon shown before the shop name floating above each stall
-- ("rbxassetid://..."). Leave blank for text only.
Config.StallIcons = {
	SellStall = "",
	DiceStall = "",
	GearStall = "",
	GuildStall = "",
}

--------------------------------------------------------------------
-- Currencies, potions, items, rebirth and daily rewards
--------------------------------------------------------------------
Config.CashImage = "rbxassetid://83763596751604"
Config.RiftShardImage = "rbxassetid://75633089538163"

-- duration in seconds (0 = instant)
Config.Potions = {
	{ key = "luck", name = "Luck Potion", imageId = "rbxassetid://110066320591030", duration = 120, text = "2x roll luck for 2 min" },
	{ key = "health", name = "Health Potion", imageId = "rbxassetid://78622291412983", duration = 180, text = "+50% pet health for 3 min" },
	{ key = "damage", name = "Damage Potion", imageId = "rbxassetid://73334192671687", duration = 180, text = "+50% pet damage for 3 min" },
	{ key = "cash", name = "Cash Potion", imageId = "rbxassetid://77742735052898", duration = 120, text = "2x cash income for 2 min" },
	{ key = "level", name = "XP Potion", imageId = "rbxassetid://87122184597982", duration = 180, text = "2x pet XP for 3 min" },
	{ key = "revive", name = "Revive Potion", imageId = "rbxassetid://92173666140969", duration = 0, text = "Revives a defeated pet" },
}
function Config.GetPotion(key)
	for _, p in ipairs(Config.Potions) do
		if p.key == key then
			return p
		end
	end
	return nil
end

Config.Items = {
	warpRemote = { name = "Warp Remote", imageId = "rbxassetid://80619965977171", text = "Use one to warp", button = "IN WARP" },
	giftCard = { name = "Gift Card", imageId = "rbxassetid://119686941815919", text = "Gift to players (Rebirth 3+)", button = "GIFT" },
}

-- Rebirth: costs cash + Rift Shards. Resets cash and unlocked biomes
-- (they must be bought again); keeps inventory, pen and upgrades.
Config.Rebirth = {
	baseCash = 2500000,
	baseShards = 100,
	growth = 3,
	cashBonus = 25, -- +% cash income per rebirth
	luckBonus = 10, -- +% luck per rebirth
}
function Config.GetRebirthCost(rebirths)
	local m = Config.Rebirth.growth ^ (rebirths or 0)
	return math.floor(Config.Rebirth.baseCash * m), math.floor(Config.Rebirth.baseShards * m)
end

--------------------------------------------------------------------
-- Daily quests (calendar window): every UTC day you get 2 easy, 2 medium
-- and 1 hard quest from these lists. Finish (claim) all 5 on 7 days in a
-- row for the big weekly bonus. "stat" is what gets counted.
--------------------------------------------------------------------
Config.DailyQuests = {
	easy = {
		{ id = "roll50", stat = "rolls", target = 50, text = "Roll the dice %d times" },
		{ id = "hatch3", stat = "hatches", target = 3, text = "Hatch %d eggs" },
		{ id = "kill15", stat = "kills", target = 15, text = "Defeat %d enemies" },
		{ id = "sell10", stat = "sells", target = 10, text = "Sell %d eggs or monsters" },
		{ id = "crit10", stat = "crits", target = 10, text = "Land %d critical hits" },
	},
	medium = {
		{ id = "roll250", stat = "rolls", target = 250, text = "Roll the dice %d times" },
		{ id = "hatch10", stat = "hatches", target = 10, text = "Hatch %d eggs" },
		{ id = "kill75", stat = "kills", target = 75, text = "Defeat %d enemies" },
		{ id = "crit50", stat = "crits", target = 50, text = "Land %d critical hits" },
		{ id = "upgrade2", stat = "upgrades", target = 2, text = "Buy %d upgrades" },
		{ id = "potion2", stat = "potions", target = 2, text = "Use %d potions" },
	},
	hard = {
		{ id = "roll750", stat = "rolls", target = 750, text = "Roll the dice %d times" },
		{ id = "kill250", stat = "kills", target = 250, text = "Defeat %d enemies" },
		{ id = "hatch25", stat = "hatches", target = 25, text = "Hatch %d eggs" },
		{ id = "crit200", stat = "crits", target = 200, text = "Land %d critical hits" },
	},
}
Config.DailyQuestOrder = { "easy", "easy", "medium", "medium", "hard" }
Config.DailyQuestRewards = {
	easy = { shards = 20 },
	medium = { shards = 50, potions = { luck = 1 } },
	hard = { shards = 150, potions = { luck = 1, cash = 1 } },
}
Config.DailyQuestWeekBonus = {
	shards = 1500,
	potions = { revive = 3, luck = 3, cash = 3, damage = 2, health = 2, level = 2 },
	items = { warpRemote = 5 },
	gears = { reviveFeather = 3 },
}

-- 7-day streak (miss a day and it starts over at day 1)
Config.DailyRewards = {
	{ cash = 5000 },
	{ shards = 25 },
	{ potions = { luck = 1 } },
	{ cash = 50000 },
	{ potions = { cash = 1 }, shards = 50 },
	{ items = { warpRemote = 2 } },
	{ potions = { revive = 1 }, shards = 200, cash = 250000 },
}

--------------------------------------------------------------------
-- Combat. Pets that follow you fight enemies near you automatically.
-- Enemy HP = 110-120% of a same-level pet, enemy damage = 90%.
--------------------------------------------------------------------
Config.Combat = {
	petBaseHealth = 100,
	petHealthPerLevel = 0.15, -- +15% per level
	petBaseDamage = 10,
	petDamagePerLevel = 0.12, -- +12% per level
	enemyHealthMin = 2.2,
	enemyHealthMax = 2.6,
	enemyDamage = 1.1,
	enemyLevelScaling = 0.08, -- extra enemy HP per level (half of it for damage)
	reviveBase = 60, -- defeated pets recover on their own: 60s + 30s per pet level (max 30 min)
	revivePerLevel = 30,
	reviveMax = 1800,
	petAttackInterval = 1.0,
	enemyAttackInterval = 1.2,
	critChance = 5, -- % chance every monster hit is a critical hit
	critMultiplier = 1.5, -- critical hits do this much damage
	aggroRange = 24, -- "tap an enemy to attack" hint shows when you're this close to one
	orderRange = 35, -- you must be this close to an enemy to tap it and send your pets
	leashRange = 80, -- walk further than this from the enemy and your pets come back
	rangedExtra = 6, -- ranged pets (Config.RangedPets) fight this much further back; enemies still reach them
	regenDelay = 5, -- seconds out of combat before pets heal
	regenPerSecond = 0.05, -- 5% of max health per second
	xpBase = 25,
	xpExponent = 1.35,
	maxLevel = 100,
	respawnTime = 10,
	shardChance = 0.35,
	potionChance = 0.04,
	warpRemoteChance = 0, -- Warp Remotes are sold in the Gear Shop now (not dropped)
	giftCardChance = 0.001, -- as rare as a Revive Potion; only drops for Rebirth 3+
	giftCardMinRebirth = 3,
	potionWeights = { luck = 25, health = 20, damage = 20, cash = 20, level = 13, revive = 5 },
}
Config.RarityPower = { 1, 1.2, 1.45, 1.75, 2.1, 2.5 }
Config.PetSizePower = { Normal = 1, Huge = 1.3, Titan = 1.7 }
Config.PetFinishPower = { Normal = 1, Gold = 1.15, Silver = 1.25, Rainbow = 1.5 }

-- special enemies: much tougher, more XP and loot (mult applies to all)
-- pets that attack from a little further away (fire / breath attacks)
Config.RangedPets = { phoenix = true, ["void-dragon"] = true }

Config.EnemySizes = {
	{ key = "Titanic", chance = 0.01, mult = 5, scale = 2.3 },
	{ key = "Huge", chance = 0.05, mult = 2.5, scale = 1.6 },
	{ key = "Big", chance = 0.15, mult = 1.5, scale = 1.25 },
}
Config.EnemyFinishes = {
	{ key = "Rainbow", chance = 0.005, mult = 3 },
	{ key = "Gold", chance = 0.03, mult = 1.8 },
	{ key = "Silver", chance = 0.08, mult = 1.3 },
}
-- per biome: level range, how many at once, which monsters
Config.EnemySpawns = {
	forest = { min = 1, max = 5, count = 18, monsters = { "slime", "bat", "mushroom" } },
	desert = { min = 6, max = 10, count = 18, monsters = { "crab", "bat", "wolf" } },
	volcanic = { min = 11, max = 15, count = 18, monsters = { "golem", "phoenix", "wolf" } },
	tundra = { min = 16, max = 20, count = 18, monsters = { "wolf", "golem", "crab" } },
	candy = { min = 21, max = 25, count = 18, monsters = { "slime", "mushroom", "phoenix" } },
	atlantis = { min = 26, max = 30, count = 18, monsters = { "leviathan", "crab", "void-dragon" } },
}

function Config.GetReviveTime(level)
	local C = Config.Combat
	return math.min(C.reviveMax, C.reviveBase + C.revivePerLevel * math.max(1, level or 1))
end

function Config.XpForLevel(level)
	return math.floor(40 * level ^ 1.6)
end

function Config.EnemyXp(level, mult)
	return math.floor(Config.Combat.xpBase * level ^ Config.Combat.xpExponent * (mult or 1))
end

function Config.IsBoostActive(profile, key, now)
	return profile ~= nil and profile.activeBoosts ~= nil and (profile.activeBoosts[key] or 0) > (now or os.time())
end

-- Server-wide effects the Dev starts from the admin panel (every server,
-- every player): 1x-8x, for a set time. The server keeps them as
-- attributes on ReplicatedStorage.MonsterRNG (GB_<key>_m = multiplier,
-- GB_<key>_e = end time), so the client sees them too.
-- imageId = the icon shown on screen while the effect is on. Put your
-- own image id here, e.g. imageId = "rbxassetid://1234567890"
Config.GlobalBoostKinds = {
	{ key = "luck", name = "Luck", imageId = "", color = { 80, 220, 110 }, text = "Better rolls for everyone" },
	{ key = "damage", name = "Damage", imageId = "", color = { 255, 90, 80 }, text = "Monsters hit harder" },
	{ key = "health", name = "Health", imageId = "", color = { 255, 110, 170 }, text = "Monsters have more health" },
	{ key = "income", name = "Income", imageId = "", color = { 255, 205, 60 }, text = "More cash from your monsters" },
	{ key = "exp", name = "EXP", imageId = "", color = { 110, 170, 255 }, text = "More EXP from enemies" },
	{ key = "speed", name = "Speed", imageId = "", color = { 90, 230, 230 }, text = "Everyone runs faster" },
	{ key = "drops", name = "Drops", imageId = "", color = { 190, 130, 255 }, text = "More drops from enemies" },
}
Config.GlobalSpeedCap = 3 -- walking faster than 3x breaks the map, so the speed effect stops there
Config.GlobalBoostMax = 16
function Config.GlobalBoost(key, now)
	local holder = game:GetService("ReplicatedStorage"):FindFirstChild("MonsterRNG")
	if not holder then
		return 1
	end
	local m, e = holder:GetAttribute("GB_" .. key .. "_m"), holder:GetAttribute("GB_" .. key .. "_e")
	if type(m) == "number" and type(e) == "number" and e > (now or os.time()) then
		return math.clamp(m, 1, Config.GlobalBoostMax)
	end
	return 1
end

-- a same-level baseline (Common, Normal, no upgrades)
function Config.BaseCombatStats(level)
	local C = Config.Combat
	local l = math.max(1, level or 1)
	return C.petBaseHealth * (1 + C.petHealthPerLevel * (l - 1)), C.petBaseDamage * (1 + C.petDamagePerLevel * (l - 1))
end

-- max health + damage of one pet, including upgrades and active potions
function Config.GetPetStats(entry, profile, now)
	local monster = Config.GetMonster(entry.monsterId)
	local tier = monster and Config.GetRarity(monster.rarity).tier or 1
	local power = (Config.RarityPower[tier] or 1) * (Config.PetSizePower[entry.size] or 1) * (Config.PetFinishPower[entry.finish] or 1)
	local hp, dmg = Config.BaseCombatStats(entry.level)
	local upgrades = profile and profile.upgrades
	hp *= power * (1 + Config.GetUpgradeBonus(upgrades, "health") / 100)
	dmg *= power * (1 + Config.GetUpgradeBonus(upgrades, "damage") / 100)
	if Config.IsBoostActive(profile, "health", now) then
		hp *= 1.5
	end
	if Config.IsBoostActive(profile, "damage", now) then
		dmg *= 1.5
	end
	hp *= Config.GlobalBoost("health", now)
	dmg *= Config.GlobalBoost("damage", now)
	return math.floor(hp), math.floor(dmg)
end

-- Gifting (needs a Gift Card). Not a trade: one player gives, the other
-- accepts. Both players need Rebirth 3+ and a 30+ day old account, and
-- must be in the same server.
Config.Gifting = {
	minRebirth = 3,
	minAccountAge = 30, -- days
	giftsPerDay = 3, -- per sender, per UTC day
	maxItemsPerGift = 5, -- pets + eggs + potions + items
	cashShare = 0.5, -- max cash = 50% of the receiver's current rebirth cost
	offerSeconds = 60, -- time the receiver has to accept
}

--------------------------------------------------------------------
-- Gear Shop (Kurt). Every GearRestockSeconds each player gets a new
-- stock: each gear is rolled with its chance; every hit rolls again for
-- one more (same chance), up to GearMaxStock of each.
-- Bought with Rift Shards; goes to the backpack (ITEMS) to use later.
--------------------------------------------------------------------
Config.GearRestockSeconds = 300
Config.GearMaxStock = 5
Config.Gears = {
	{ key = "speedBoots", name = "Speed Boots", imageId = "rbxassetid://117951493575646", price = 20, chance = 0.5, duration = 180, boost = true, color = { 90, 200, 255 }, text = "+40% walk speed for 3 min" },
	{ key = "tauntTotem", name = "Taunt Totem", imageId = "rbxassetid://85760759986031", price = 45, chance = 0.3, duration = 30, color = { 235, 90, 70 }, text = "Enemies attack it instead of your pets (30s)" },
	{ key = "healingSpring", name = "Healing Spring", imageId = "rbxassetid://131193150650112", price = 35, chance = 0.2, duration = 60, color = { 80, 220, 160 }, text = "Your pets near it heal fast (60s)" },
	{ key = "campfire", name = "Campfire", imageId = "rbxassetid://115564759046466", price = 60, chance = 0.05, duration = 300, boost = true, color = { 255, 150, 50 }, text = "Defeated pets recover 2x faster (5 min)" },
	{ key = "warpRemote", name = "Warp Remote", imageId = "rbxassetid://80619965977171", price = 25, chance = 0.4, item = true, color = { 120, 190, 255 }, text = "Warp to any biome you unlocked (WARP menu)" },
	{ key = "reviveFeather", name = "Revive Feather", imageId = "rbxassetid://112794123950752", price = 90, chance = 0.04, color = { 255, 215, 90 }, text = "Instantly revives one defeated pet" },
}
function Config.GetGear(key)
	for _, g in ipairs(Config.Gears) do
		if g.key == key then
			return g
		end
	end
	return nil
end

-- every biome you've unlocked: +5% roll luck and +10% enemy drop chance
Config.BiomeBonus = { luck = 5, drops = 10 }
function Config.GetBiomeBonusCount(profile)
	local n = 0
	for key, on in pairs((profile and profile.unlockedBiomes) or {}) do
		if on and key ~= "home" then
			n += 1
		end
	end
	return n
end

function Config.BuildDisplayName(monsterName, sizeKey, finishKey)
	local parts = {}
	if sizeKey and sizeKey ~= "Normal" then
		table.insert(parts, sizeKey)
	end
	if finishKey and finishKey ~= "Normal" then
		table.insert(parts, finishKey)
	end
	table.insert(parts, monsterName)
	return table.concat(parts, " ")
end

--------------------------------------------------------------------
-- PvP (from the PVP button). Post a challenge, anyone in ANY server can
-- take it; the teams (monsters in your pen) fight in the arena.
-- Credits only show in the PvP window. Seasons are one calendar month.
--------------------------------------------------------------------
Config.Pvp = {
	postMinutes = 30, -- a challenge post stays up this long
	maxTeam = 6, -- strongest monsters in your pen that fight
	winCredits = 25, -- you took a challenge and won
	lossCredits = 5,
	defendWinCredits = 15, -- your post was taken and your team won
	defendLossCredits = 3,
	winPoints = 25, -- season points (leaderboard)
	lossPoints = 10, -- taken away (never below 0)
	defendWinPoints = 15,
	defendLossPoints = 5,
	cooldown = 10, -- seconds between fights
	-- season rewards (none yet): top 1-3, 4-10, 11-100
	rewardTiers = {
		{ from = 1, to = 3, name = "TOP 3", color = { 255, 205, 60 }, rewards = "Coming soon" },
		{ from = 4, to = 10, name = "TOP 10", color = { 200, 210, 230 }, rewards = "Coming soon" },
		{ from = 11, to = 100, name = "TOP 100", color = { 205, 140, 90 }, rewards = "Coming soon" },
	},
}
-- "2026-09" style key of the current season (UTC month)
function Config.PvpSeason(t)
	local d = DateTime.fromUnixTimestamp(t or os.time()):ToUniversalTime()
	return string.format("%d-%02d", d.Year, d.Month)
end
-- seconds until the season ends
function Config.PvpSeasonLeft(t)
	t = t or os.time()
	local d = DateTime.fromUnixTimestamp(t):ToUniversalTime()
	local y, m = d.Year, d.Month + 1
	if m > 12 then
		y, m = y + 1, 1
	end
	return DateTime.fromUniversalTime(y, m, 1, 0, 0, 0).UnixTimestamp - t
end
-- a team's total power (shown on posts)
function Config.TeamPower(team)
	local p = 0
	for _, m in ipairs(team or {}) do
		p += (m.hp or 0) / 10 + (m.dmg or 0)
	end
	return math.floor(p)
end

--------------------------------------------------------------------
-- Guilds (the Guild stall in town)
--------------------------------------------------------------------
Config.Guild = {
	createProductId = 0, -- 0 = creating a guild is FREE for now (put a product id here later)
	baseMembers = 10,
	slotStep = 5, -- +5 members each time the owner buys more slots
	maxMembers = 50,
	slotProductId = 0, -- developer product for +5 members (0 = not for sale yet)
	nameMin = 3,
	nameMax = 20,
	descMax = 120,
	-- preset emblems: a color + a symbol (or put an image id in the guild settings)
	presets = {
		{ key = "star", symbol = "⭐", color = { 255, 200, 60 } },
		{ key = "crown", symbol = "👑", color = { 255, 150, 40 } },
		{ key = "sword", symbol = "⚔️", color = { 200, 60, 60 } },
		{ key = "skull", symbol = "💀", color = { 80, 80, 100 } },
		{ key = "heart", symbol = "❤️", color = { 240, 80, 140 } },
		{ key = "bolt", symbol = "⚡", color = { 90, 170, 255 } },
		{ key = "moon", symbol = "🌙", color = { 120, 90, 220 } },
		{ key = "fire", symbol = "🔥", color = { 255, 120, 40 } },
		{ key = "dragon", symbol = "🐉", color = { 50, 60, 80 } },
		{ key = "diamond", symbol = "💎", color = { 60, 200, 220 } },
		{ key = "clover", symbol = "🍀", color = { 60, 190, 90 } },
		{ key = "shield", symbol = "🛡️", color = { 150, 100, 60 } },
	},
}
function Config.GuildPreset(key)
	for _, p in ipairs(Config.Guild.presets) do
		if p.key == key then
			return p
		end
	end
	return Config.Guild.presets[1]
end

--------------------------------------------------------------------
-- Graphics quality (Settings > GRAPHICS). Everything that draws the
-- world reads these: monsters (RigSkinner), biomes (BiomeLoader) and
-- effects / lighting (HUD).
--   rigs        = which monster pieces (always the full model: MonsterRigs)
--   monsterCull = monsters further than this are not drawn (nil = never)
--   biomeNear   = biomes show only this close to their edge (nil = always)
--------------------------------------------------------------------
Config.Graphics = {
	order = { "SuperLow", "Low", "Mid", "High", "SuperHigh" },
	tiers = {
		SuperLow = { label = "S.LOW", rigs = "MonsterRigs", monsterCull = 60, biomeNear = 60, particles = 0, lights = false, neon = false, shadows = false, bloom = false, props = false },
		Low = { label = "LOW", rigs = "MonsterRigs", monsterCull = 100, biomeNear = 160, particles = 0.3, lights = false, neon = false, shadows = false, bloom = false, props = false },
		Mid = { label = "MID", rigs = "MonsterRigs", monsterCull = 180, biomeNear = 160, particles = 0.65, lights = true, neon = true, shadows = false, bloom = true, props = true },
		High = { label = "HIGH", rigs = "MonsterRigs", particles = 1, lights = true, neon = true, shadows = true, bloom = true, props = true },
		SuperHigh = { label = "S.HIGH", rigs = "MonsterRigs", particles = 1, lights = true, neon = true, shadows = true, bloom = true, props = true, extra = true },
	},
}
function Config.GraphicsTier(name)
	return Config.Graphics.tiers[name or "High"] or Config.Graphics.tiers.High
end

return Config