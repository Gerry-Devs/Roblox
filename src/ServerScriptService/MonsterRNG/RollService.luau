local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

local RollService = {}
local random = Random.new()

local function getTier(rarityName)
	return Config.GetRarity(rarityName).tier
end

local function chooseRarity(luck, minimumTier, diceLuck)
	local totalWeight = 0
	local weightedRarities = {}

	for _, rarity in ipairs(Config.Rarities) do
		if rarity.tier >= (minimumTier or 1) then
			local luckMultiplier = 1 + (math.max(0, luck) * math.max(0, rarity.tier - 1) * 0.04)
			local diceMultiplier = rarity.tier > 1 and (1 + math.max(0, diceLuck or 0) / 100) or 1
			local adjustedWeight = rarity.weight * luckMultiplier * diceMultiplier
			totalWeight += adjustedWeight
			table.insert(weightedRarities, {
				rarity = rarity,
				weight = adjustedWeight,
			})
		end
	end

	local roll = random:NextNumber(0, totalWeight)
	local runningWeight = 0
	for _, entry in ipairs(weightedRarities) do
		runningWeight += entry.weight
		if roll <= runningWeight then
			return entry.rarity
		end
	end

	return weightedRarities[#weightedRarities].rarity
end

local function chooseMonster(rarityName)
	local matches = {}
	for _, monster in ipairs(Config.Monsters) do
		if monster.rarity == rarityName then
			table.insert(matches, monster)
		end
	end
	return matches[random:NextInteger(1, #matches)]
end

local function chooseVariant(variants, bonusPercent)
	local multiplier = 1 + math.max(0, bonusPercent or 0) / 100
	local totalWeight = 0
	local weighted = {}
	for _, variant in ipairs(variants) do
		local weight = variant.weight
		if variant.key ~= "Normal" then
			weight *= multiplier
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

function RollService.Roll(profile)
	-- (pity system removed)
	local effectiveLuck = profile.luck + Config.GetUpgradeBonus(profile.upgrades, "luck")
	local diceLuck = Config.GetDice(profile.equippedDice).luck
	-- rebirths: +10% luck each
	diceLuck = ((1 + diceLuck / 100) * (1 + (profile.rebirths or 0) * Config.Rebirth.luckBonus / 100) - 1) * 100
	-- every unlocked biome: +5% luck
	diceLuck = ((1 + diceLuck / 100) * (1 + Config.GetBiomeBonusCount(profile) * Config.BiomeBonus.luck / 100) - 1) * 100
	-- Luck Potion: 2x luck
	if Config.IsBoostActive(profile, "luck") then
		diceLuck = ((1 + diceLuck / 100) * 2 - 1) * 100
	end
	-- Dev server-wide luck effect (1x-8x)
	local globalLuck = Config.GlobalBoost("luck")
	if globalLuck > 1 then
		diceLuck = ((1 + diceLuck / 100) * globalLuck - 1) * 100
	end
	-- hidden pity: every 25th roll is a 2x luck roll
	if (profile.rolls + 1) % Config.PityEvery == 0 then
		diceLuck = ((1 + diceLuck / 100) * Config.PityLuckMultiplier - 1) * 100
	end
	-- WILD chain: each WILD rolls again; all 3 in a row spins the egg wheel
	local wilds = 0
	-- Wild Chance upgrade: makes the 1st WILD more likely
	local wildBoost = 1 + Config.GetUpgradeBonus(profile.upgrades, "wildChance") / 100
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
		rarity = chooseRarity(effectiveLuck, 1, diceLuck)
	end
	local monster = chooseMonster(rarity.key)
	local monsterTier = getTier(monster.rarity)
	local size = chooseVariant(Config.SizeVariants, Config.GetUpgradeBonus(profile.upgrades, "size"))
	local finish = chooseVariant(Config.FinishVariants, Config.GetUpgradeBonus(profile.upgrades, "mutation"))

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

return RollService