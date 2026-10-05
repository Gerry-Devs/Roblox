local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

local RollService = {}
local random = Random.new()

local function getTier(rarityName)
	return Config.GetRarity(rarityName).tier
end

-- Luck divides the odds (like most RNG games): starting from the rarest,
-- each rarity is tried with chance (its chance x luck). A rarity whose
-- odds are smaller than your luck can't miss, so everything more common
-- than it never shows up any more (e.g. 2x luck = no more Commons).
-- luckMult is already softened by Config.Luck.soft (see RollService.Roll).
local function chooseRarity(luckMult, minimumTier)
	local list, total = {}, 0
	for _, rarity in ipairs(Config.Rarities) do
		if rarity.tier >= (minimumTier or 1) then
			table.insert(list, rarity)
			total += rarity.weight
		end
	end
	table.sort(list, function(a, b)
		return a.tier > b.tier
	end)
	luckMult = math.max(1, luckMult or 1)
	for _, rarity in ipairs(list) do
		if random:NextNumber() < math.min(1, rarity.weight / total * luckMult) then
			return rarity
		end
	end
	return list[#list] -- the most common one allowed
end

local function chooseMonster(rarityName)
	-- weighted: monster.weight (1 = normal, lower = rarer inside its rarity)
	local matches, total = {}, 0
	for _, monster in ipairs(Config.Monsters) do
		if monster.rarity == rarityName then
			table.insert(matches, monster)
			total += monster.weight or 1
		end
	end
	local pick = random:NextNumber() * total
	for _, monster in ipairs(matches) do
		pick -= monster.weight or 1
		if pick <= 0 then
			return monster
		end
	end
	return matches[#matches]
end

local function chooseVariant(variants, bonusPercent, extra)
	local multiplier = 1 + math.max(0, bonusPercent or 0) / 100
	local totalWeight = 0
	local weighted = {}
	for _, variant in ipairs(variants) do
		local weight = variant.weight
		if variant.key ~= "Normal" then
			weight *= multiplier
		end
		-- weather: e.g. Starfall makes Galaxy 3x more common
		if extra and extra[variant.key] then
			weight *= extra[variant.key]
		end
		totalWeight += weight
		table.insert(weighted, { variant = variant, weight = weight })
	end

	local roll = random:NextNumber(0, totalWeight)
	local runningWeight = 0
	for _, entry in ipairs(weighted) do
		runningWeight += entry.weight
		if roll <= runningWeight then
			return entry.variant
		end
	end

	return variants[1]
end

-- the egg wheel after 3 WILDs: returns the slice number (1-5)
local function chooseWheelSlice()
	local total = 0
	for _, slice in ipairs(Config.Wild.wheel) do
		total += slice.weight
	end
	local roll = random:NextNumber(0, total)
	local running = 0
	for i, slice in ipairs(Config.Wild.wheel) do
		running += slice.weight
		if roll <= running then
			return i
		end
	end
	return #Config.Wild.wheel
end

-- every luck boost as ONE multiplier (before softening):
--   luck points (shop, Luck upgrade, Luck skills): +10% each
--   dice, rebirths, biomes: their +%
--   Luck Potion 2x, server luck event, Blessing / Infinity / Chaos skills
function RollService.GetLuck(profile)
	local points = (profile.luck or 0) + Config.GetUpgradeBonus(profile.upgrades, "luck") + Config.Skill(profile, "luck")
	local m = 1 + points * 0.1
	m *= 1 + Config.GetDice(profile.equippedDice).luck / 100
	m *= 1 + (profile.rebirths or 0) * Config.Rebirth.luckBonus / 100
	m *= 1 + Config.GetBiomeBonusCount(profile) * Config.BiomeBonus.luck / 100
	if Config.IsBoostActive(profile, "luck") then
		m *= 2
	end
	m *= math.max(1, Config.GlobalBoost("luck"))
	m *= math.max(1, Config.SkillLuckMultiplier(profile))
	-- weather: Lucky Wind
	local weather = Config.WorldEventAt(os.time()).weather
	if weather and weather.luck then
		m *= weather.luck
	end
	-- Index rewards (completed rarities) + the group reward
	local indexLuck = Config.IndexBonus(profile)
	m *= 1 + indexLuck / 100
	if profile.inGroup then
		m *= 1 + Config.Group.luck / 100
	end
	return m
end

function RollService.Roll(profile)
	-- (pity system removed)
	-- (+ Luck skills of your equipped monsters)
	local luckMult = RollService.GetLuck(profile)
	-- hidden pity: every 25th roll is a 2x luck roll
	if (profile.rolls + 1) % Config.PityEvery == 0 then
		luckMult *= Config.PityLuckMultiplier
	end
	luckMult = Config.SoftLuck(luckMult)
	-- WILD chain: each WILD rolls again; all 3 in a row spins the egg wheel
	local wilds = 0
	-- Wild Chance upgrade: makes the 1st WILD more likely
	local wildBoost = 1 + (Config.GetUpgradeBonus(profile.upgrades, "wildChance") + Config.Skill(profile, "wild")) / 100
	for i, chance in ipairs(Config.Wild.chances) do
		if i == 1 then
			chance = math.min(1, chance * wildBoost)
		end
		if random:NextNumber() < chance then
			wilds += 1
		else
			break
		end
	end
	local rarity, wheelIndex
	if wilds >= #Config.Wild.chances then
		wheelIndex = chooseWheelSlice()
		rarity = Config.GetRarity(Config.Wild.wheel[wheelIndex].rarity)
	else
		rarity = chooseRarity(luckMult, 1)
	end
	local monster = chooseMonster(rarity.key)
	local monsterTier = getTier(monster.rarity)
	-- (+ Nature's Gift skill: more mutations and bigger sizes)
	local gift = Config.Skill(profile, "mutation")
	local weather = Config.WorldEventAt(os.time()).weather
	local size = chooseVariant(Config.SizeVariants, Config.GetUpgradeBonus(profile.upgrades, "size") + gift, weather and weather.sizes)
	local finish = chooseVariant(Config.FinishVariants, Config.GetUpgradeBonus(profile.upgrades, "mutation") + gift, weather and weather.finishes)

	local egg = {
		uid = HttpService:GenerateGUID(false),
		monsterId = monster.id,
		size = size.key,
		finish = finish.key,
		rarity = rarity.key,
		kg = Config.RollKg(monster.id, size.key),
	}

	profile.rolls += 1

	table.insert(profile.eggs, egg)

	return rarity, egg, wilds, wheelIndex
end

-- a reward egg: a random egg of at least this rarity (normal odds above
-- it, so it's usually that rarity). Size / finish roll like normal.
function RollService.GiveEgg(profile, minRarityKey)
	local rarity = chooseRarity(1, getTier(minRarityKey or "Common"))
	local monster = chooseMonster(rarity.key)
	local size = chooseVariant(Config.SizeVariants, 0)
	local finish = chooseVariant(Config.FinishVariants, 0)
	local egg = {
		uid = HttpService:GenerateGUID(false),
		monsterId = monster.id,
		size = size.key,
		finish = finish.key,
		rarity = rarity.key,
		kg = Config.RollKg(monster.id, size.key),
	}
	table.insert(profile.eggs, egg)
	return egg
end

return RollService