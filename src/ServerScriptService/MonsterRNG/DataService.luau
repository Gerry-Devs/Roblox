local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("Config"))
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataService = {}
local store

if game.GameId ~= 0 or not RunService:IsStudio() then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("MonsterRNG_PlayerData_v1")
	end)
	if success then
		store = result
	else
		warn("Monster RNG DataStore is unavailable. Using temporary session data.")
	end
else
	warn("Monster RNG is running in an unpublished Studio place. Using temporary session data until the place is published.")
end

local profiles = {}

local function copyPosition(position)
	if type(position) ~= "table" then
		return { x = 0, z = 0 }
	end
	return {
		x = tonumber(position.x) or 0,
		z = tonumber(position.z) or 0,
	}
end

local function copyBase(base)
	-- "base" holds items physically placed in the pen (freeform position,
	-- not a fixed slot grid). Eggs are locked in place until they hatch;
	-- monsters can be unequipped back to the backpack at any time.
	local result = {}
	for index, entry in ipairs(base or {}) do
		if type(entry) == "table" and type(entry.monsterId) == "string" then
			local kind = entry.kind == "egg" and "egg" or "monster"
			local clean = {
				uid = type(entry.uid) == "string" and entry.uid or ("legacy_" .. index),
				kind = kind,
				monsterId = entry.monsterId,
				size = type(entry.size) == "string" and entry.size or "Normal",
				finish = type(entry.finish) == "string" and entry.finish or "Normal",
				grade = type(entry.grade) == "string" and entry.grade or nil,
				kg = type(entry.kg) == "number" and entry.kg or nil,
				level = math.max(1, math.floor(tonumber(entry.level) or 1)),
				xp = math.max(0, math.floor(tonumber(entry.xp) or 0)),
				defeated = entry.defeated == true or nil,
				defeatedAt = tonumber(entry.defeatedAt),
				position = copyPosition(entry.position),
				favorite = entry.favorite == true or nil,
			}
			if kind == "egg" then
				clean.rarity = type(entry.rarity) == "string" and entry.rarity or "Common"
				clean.placedAt = tonumber(entry.placedAt) or os.time()
				clean.readyAt = tonumber(entry.readyAt) or os.time()
				clean.nightHour = tonumber(entry.nightHour) -- night boost already given
			end
			result[index] = clean
		end
	end
	return result
end

local function copyEggs(eggs)
	local result = {}
	for index, entry in ipairs(eggs or {}) do
		if type(entry) == "table" and type(entry.monsterId) == "string" then
			result[index] = {
				uid = type(entry.uid) == "string" and entry.uid or ("egg_legacy_" .. index),
				monsterId = entry.monsterId,
				size = type(entry.size) == "string" and entry.size or "Normal",
				finish = type(entry.finish) == "string" and entry.finish or "Normal",
				grade = type(entry.grade) == "string" and entry.grade or nil,
				kg = type(entry.kg) == "number" and entry.kg or nil,
				rarity = type(entry.rarity) == "string" and entry.rarity or "Common",
				favorite = entry.favorite == true or nil,
			}
		end
	end
	return result
end

local function copyMonsters(monsters)
	-- Hatched monsters that are NOT currently placed in the pen (unequipped).
	local result = {}
	for index, entry in ipairs(monsters or {}) do
		if type(entry) == "table" and type(entry.monsterId) == "string" then
			result[index] = {
				uid = type(entry.uid) == "string" and entry.uid or ("monster_legacy_" .. index),
				monsterId = entry.monsterId,
				size = type(entry.size) == "string" and entry.size or "Normal",
				finish = type(entry.finish) == "string" and entry.finish or "Normal",
				kg = type(entry.kg) == "number" and entry.kg or nil,
				level = math.max(1, math.floor(tonumber(entry.level) or 1)),
				xp = math.max(0, math.floor(tonumber(entry.xp) or 0)),
				defeated = entry.defeated == true or nil,
				defeatedAt = tonumber(entry.defeatedAt),
				favorite = entry.favorite == true or nil,
			}
		end
	end
	return result
end

local function copyUpgrades(upgrades)
	local result = {}
	if type(upgrades) ~= "table" then
		return result
	end
	for nodeId, purchased in pairs(upgrades) do
		if type(nodeId) == "string" and purchased == true then
			result[nodeId] = true
		end
	end
	return result
end

local function copyOwned(owned)
	local result = {}
	for monsterId, count in pairs(owned or {}) do
		if type(monsterId) == "string" and type(count) == "number" then
			result[monsterId] = math.max(0, math.floor(count))
		end
	end
	return result
end

local function newProfile()
	return {
		owned = {},
		base = {},
		eggs = {},
		monsters = {},
		upgrades = {},
		rolls = 0,
		pity = 0,
		luck = 0,
		cash = 250,
		incomeBoost = 1,
		bossWins = 0,
		pvpWins = 0,
		ownedDice = { common = true },
		equippedDice = "common",
		unlockedBiomes = { home = true },
		riftShards = 0,
		rebirths = 0,
		potions = {},
		items = {},
		enemyKills = {},
		settings = { graphics = "High", sound = true, otherPets = true, ownPets = true, miniDice = true, music = true, particles = true, shadows = true },
		daily = { streak = 0, lastDay = -1 },
		activeBoosts = {},
		giftDaily = { day = -1, count = 0 },
		gears = {},
		gearStock = { slot = -1, items = {} },
		adminPasses = {}, -- gamepass perks given by the admin (not a Roblox purchase)
		tags = {}, -- admin-given tags: admin / tester / beta
		redeemedCodes = {}, -- codes this player already used (Shop > CODES)
		autoSell = nil, -- Auto Sell settings (saved; always starts OFF on join)
		pvp = { credits = 0, points = 0, season = "", wins = 0, losses = 0 }, -- PvP credits + this season's points
		guildId = nil, -- the guild this player is in
		indexStats = {}, -- Index: per monster { maxKg, sizes = {Big = true}, finishes = {Gold = true} }
		guildCredits = 0, -- paid guild creates not used yet (Robux never lost)
		lastOnline = nil, -- when this save was last written (for offline earnings)
		quests = nil, -- daily quests (QuestService)
	}
end

local function sanitize(data)
	local profile = newProfile()
	if type(data) ~= "table" then
		return profile
	end

	profile.owned = copyOwned(data.owned)
	-- Index records (sizes / finishes collected, biggest kg)
	if type(data.indexStats) == "table" then
		for id, st in pairs(data.indexStats) do
			if type(id) == "string" and type(st) == "table" then
				local rec = { maxKg = tonumber(st.maxKg) or 0, sizes = {}, finishes = {}, grades = {} }
				for k, v in pairs(type(st.grades) == "table" and st.grades or {}) do
					if type(k) == "string" and v == true then
						rec.grades[k] = true
					end
				end
				for k, v in pairs(type(st.sizes) == "table" and st.sizes or {}) do
					if type(k) == "string" and v == true then
						rec.sizes[k] = true
					end
				end
				for k, v in pairs(type(st.finishes) == "table" and st.finishes or {}) do
					if type(k) == "string" and v == true then
						rec.finishes[k] = true
					end
				end
				profile.indexStats[id] = rec
			end
		end
	end
	profile.base = copyBase(data.base)
	profile.eggs = copyEggs(data.eggs)
	profile.monsters = copyMonsters(data.monsters)
	profile.upgrades = copyUpgrades(data.upgrades)
	-- items from before kg existed get their base weight
	for _, list in ipairs({ profile.eggs, profile.monsters, profile.base }) do
		for _, item in pairs(list) do
			if type(item) == "table" and item.monsterId and not item.kg then
				item.kg = math.floor(Config.GetBaseKg(item.monsterId, item.size) * 10 + 0.5) / 10
			end
		end
	end
	if type(data.rolls) == "number" then
		profile.rolls = math.max(0, math.floor(data.rolls))
	end
	if type(data.pity) == "number" then
		profile.pity = math.max(0, math.floor(data.pity))
	end
	if type(data.luck) == "number" then
		profile.luck = math.clamp(data.luck, 0, 10)
	end
	if type(data.cash) == "number" then
		profile.cash = math.max(0, math.floor(data.cash))
	end
	if type(data.incomeBoost) == "number" then
		profile.incomeBoost = math.clamp(data.incomeBoost, 1, 5)
	end
	if type(data.bossWins) == "number" then
		profile.bossWins = math.max(0, math.floor(data.bossWins))
	end
	if type(data.pvpWins) == "number" then
		profile.pvpWins = math.max(0, math.floor(data.pvpWins))
	end
	if type(data.ownedDice) == "table" then
		for key, owned in pairs(data.ownedDice) do
			if type(key) == "string" and owned == true then
				profile.ownedDice[key] = true
			end
		end
	end
	if type(data.equippedDice) == "string" and profile.ownedDice[data.equippedDice] then
		profile.equippedDice = data.equippedDice
	end
	if type(data.riftShards) == "number" then
		profile.riftShards = math.max(0, math.floor(data.riftShards))
	end
	if type(data.rebirths) == "number" then
		profile.rebirths = math.max(0, math.floor(data.rebirths))
	end
	for _, field in ipairs({ "potions", "items", "enemyKills", "activeBoosts", "gears" }) do
		if type(data[field]) == "table" then
			for k, v in pairs(data[field]) do
				if type(k) == "string" and type(v) == "number" and v > 0 then
					profile[field][k] = math.floor(v)
				end
			end
		end
	end
	if type(data.settings) == "table" then
		local s = data.settings
		if type(s.graphics) == "string" and Config.Graphics.tiers[s.graphics] then
			profile.settings.graphics = s.graphics
		end
		for _, k in ipairs({ "sound", "otherPets", "ownPets", "miniDice", "music", "particles", "shadows" }) do
			if type(s[k]) == "boolean" then
				profile.settings[k] = s[k]
			end
		end
		if type(s.combat) == "string" and Config.CombatModes.names[s.combat] then
			profile.settings.combat = s.combat
		end
	end
	profile.quests = require(script.Parent:WaitForChild("QuestService")).Sanitize(data.quests)
	if type(data.lastOnline) == "number" then
		profile.lastOnline = math.floor(data.lastOnline)
	end
	if type(data.daily) == "table" and type(data.daily.streak) == "number" and type(data.daily.lastDay) == "number" then
		profile.daily = { streak = math.clamp(math.floor(data.daily.streak), 0, 7), lastDay = math.floor(data.daily.lastDay) }
	end
	if type(data.giftDaily) == "table" and type(data.giftDaily.day) == "number" and type(data.giftDaily.count) == "number" then
		profile.giftDaily = { day = math.floor(data.giftDaily.day), count = math.max(0, math.floor(data.giftDaily.count)) }
	end
	if type(data.gearStock) == "table" and type(data.gearStock.slot) == "number" and type(data.gearStock.items) == "table" then
		local items = {}
		for k, v in pairs(data.gearStock.items) do
			if type(k) == "string" and type(v) == "number" and v > 0 then
				items[k] = math.floor(v)
			end
		end
		profile.gearStock = { slot = math.floor(data.gearStock.slot), items = items }
	end
	for _, field in ipairs({ "adminPasses", "tags", "redeemedCodes" }) do
		if type(data[field]) == "table" then
			for k, v in pairs(data[field]) do
				if type(k) == "string" and v == true then
					profile[field][k] = true
				end
			end
		end
	end
	if type(data.autoSell) == "table" then
		local a = data.autoSell
		local rar = {}
		if type(a.rarities) == "table" then
			for k, v in pairs(a.rarities) do
				if type(k) == "string" and v == true then
					rar[k] = true
				end
			end
		end
		profile.autoSell = {
			enabled = false, -- the configuration is kept, but it's OFF until the player turns it on again
			eggs = a.eggs ~= false,
			monsters = a.monsters ~= false,
			mode = type(a.mode) == "string" and a.mode or "all",
			rarities = rar,
			minCash = tonumber(a.minCash) or 0,
		}
	end
	if type(data.settings) == "table" and type(data.settings.chatTag) == "string" then
		profile.settings.chatTag = data.settings.chatTag
	end
	-- PvP
	if type(data.pvp) == "table" then
		local p = data.pvp
		profile.pvp = {
			credits = math.max(0, math.floor(tonumber(p.credits) or 0)),
			points = math.max(0, math.floor(tonumber(p.points) or 0)),
			season = type(p.season) == "string" and p.season or "",
			wins = math.max(0, math.floor(tonumber(p.wins) or 0)),
			losses = math.max(0, math.floor(tonumber(p.losses) or 0)),
		}
	end
	if type(data.guildId) == "string" then
		profile.guildId = data.guildId
	end
	profile.guildCredits = math.clamp(math.floor(tonumber(data.guildCredits) or 0), 0, 5)
	-- developer product receipts already granted (so a purchase is never given twice)
	if type(data.receipts) == "table" then
		local keep, n = {}, 0
		for k, v in pairs(data.receipts) do
			if type(k) == "string" and v then
				n += 1
				if n <= 200 then
					keep[k] = true
				end
			end
		end
		profile.receipts = keep
	end
	if type(data.unlockedBiomes) == "table" then
		for key, v in pairs(data.unlockedBiomes) do
			if type(key) == "string" and v == true then
				profile.unlockedBiomes[key] = true
			end
		end
	end
	-- monsters you already have count for the Index records
	for _, list in ipairs({ profile.monsters or {}, profile.base or {} }) do
		for _, e in ipairs(list) do
			if e.kind ~= "egg" and e.monsterId then
				DataService.RecordIndex(profile, e)
			end
		end
	end
	return profile
end

function DataService.Load(player)
	if not store then
		profiles[player] = newProfile()
		return profiles[player]
	end

	local key = "player_" .. player.UserId
	local success, data = pcall(function()
		return store:GetAsync(key)
	end)

	if success then
		profiles[player] = sanitize(data)
	else
		warn("Monster RNG data failed to load for " .. player.Name)
		profiles[player] = newProfile()
	end

	return profiles[player]
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.Save(player)
	local profile = profiles[player]
	if not profile or not store then
		return false
	end

	local key = "player_" .. player.UserId
	profile.lastOnline = os.time()
	local success, message = pcall(function()
		store:UpdateAsync(key, function()
			return profile
		end)
	end)

	if not success then
		warn("Monster RNG data failed to save for " .. player.Name .. ": " .. tostring(message))
	end
	return success
end

-- edit a player's saved data while they're NOT in this server (admin)
function DataService.UpdateOffline(userId, fn)
	if not store then
		return false, "DataStore not available"
	end
	local ok, err = pcall(function()
		store:UpdateAsync("player_" .. userId, function(old)
			local profile = sanitize(old)
			fn(profile)
			return profile
		end)
	end)
	return ok, err
end
DataService.Sanitize = sanitize

function DataService.Remove(player)
	profiles[player] = nil
end

-- the Index remembers every size / finish of a monster you got and its
-- biggest kg (even after you sell it)
function DataService.RecordIndex(profile, entry)
	if not profile or type(entry) ~= "table" or type(entry.monsterId) ~= "string" then
		return
	end
	profile.indexStats = profile.indexStats or {}
	local rec = profile.indexStats[entry.monsterId] or { maxKg = 0, sizes = {}, finishes = {} }
	profile.indexStats[entry.monsterId] = rec
	rec.grades = rec.grades or {}
	rec.grades[entry.grade or "E"] = true
	rec.sizes[entry.size or "Normal"] = true
	rec.finishes[entry.finish or "Normal"] = true
	rec.maxKg = math.max(rec.maxKg or 0, tonumber(entry.kg) or 0)
end

function DataService.PublicProfile(profile)
	return {
		indexStats = profile.indexStats,
		friendBonus = profile.friendBonus,
		inGroup = profile.inGroup,
		owned = copyOwned(profile.owned),
		base = copyBase(profile.base),
		eggs = copyEggs(profile.eggs),
		monsters = copyMonsters(profile.monsters),
		upgrades = copyUpgrades(profile.upgrades),
		rolls = profile.rolls,
		pity = profile.pity,
		luck = profile.luck,
		cash = profile.cash,
		incomeBoost = profile.incomeBoost,
		ownedDice = table.clone(profile.ownedDice or { common = true }),
		equippedDice = profile.equippedDice or "common",
		unlockedBiomes = table.clone(profile.unlockedBiomes or { home = true }),
		riftShards = profile.riftShards or 0,
		passes = (function()
			local p = table.clone(profile.passes or {})
			for k, v in pairs(profile.adminPasses or {}) do
				if v then
					p[k] = true
				end
			end
			return p
		end)(),
		tags = table.clone(profile.tags or {}),
		rebirths = profile.rebirths or 0,
		potions = table.clone(profile.potions or {}),
		items = table.clone(profile.items or {}),
		enemyKills = table.clone(profile.enemyKills or {}),
		settings = table.clone(profile.settings or {}),
		daily = table.clone(profile.daily or { streak = 0, lastDay = -1 }),
		activeBoosts = table.clone(profile.activeBoosts or {}),
		giftDaily = table.clone(profile.giftDaily or { day = -1, count = 0 }),
		gears = table.clone(profile.gears or {}),
		bossWins = profile.bossWins,
		pvpWins = profile.pvpWins,
		pvp = table.clone(profile.pvp or {}),
		guildId = profile.guildId,
		quests = require(script.Parent:WaitForChild("QuestService")).Public(profile),
	}
end

return DataService