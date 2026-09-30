--------------------------------------------------------------------
-- QuestService: daily quests (2 easy, 2 medium, 1 hard per UTC day) and
-- the 7-day "finish them all" streak with its weekly bonus.
--   profile.quests = { day, list = { {id, tier, stat, target, progress, claimed} },
--                      streak, lastAllDay }
--------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

local QuestService = {}
local rng = Random.new()

local function today()
	return math.floor(os.time() / 86400)
end
QuestService.Today = today

function QuestService.Ensure(profile)
	local q = profile.quests
	if type(q) ~= "table" then
		q = { day = -1, list = {}, streak = 0, lastAllDay = -1 }
		profile.quests = q
	end
	local d = today()
	if q.day ~= d then
		q.day = d
		q.list = {}
		local used = {}
		for _, tier in ipairs(Config.DailyQuestOrder) do
			local pool = {}
			for _, def in ipairs(Config.DailyQuests[tier]) do
				if not used[def.id] and not used["stat:" .. tier .. def.stat] then
					table.insert(pool, def)
				end
			end
			if #pool == 0 then
				pool = Config.DailyQuests[tier]
			end
			local def = pool[rng:NextInteger(1, #pool)]
			used[def.id] = true
			used["stat:" .. tier .. def.stat] = true
			table.insert(q.list, { id = def.id, tier = tier, stat = def.stat, target = def.target, progress = 0, claimed = false })
		end
	end
	-- a missed day breaks the streak
	if q.lastAllDay < d - 1 and (q.streak or 0) > 0 then
		q.streak = 0
	end
	return q
end

-- count something the player did (rolls, hatches, kills, crits, sells, upgrades, potions)
function QuestService.Add(profile, stat, amount)
	if not profile then
		return
	end
	local q = QuestService.Ensure(profile)
	for _, e in ipairs(q.list) do
		if e.stat == stat and not e.claimed and e.progress < e.target then
			e.progress = math.min(e.target, e.progress + (amount or 1))
		end
	end
end

local function grant(profile, reward)
	if reward.cash then
		profile.cash += reward.cash
	end
	if reward.shards then
		profile.riftShards = (profile.riftShards or 0) + reward.shards
	end
	for k, n in pairs(reward.potions or {}) do
		profile.potions[k] = (profile.potions[k] or 0) + n
	end
	for k, n in pairs(reward.items or {}) do
		profile.items[k] = (profile.items[k] or 0) + n
	end
	for k, n in pairs(reward.gears or {}) do
		profile.gears[k] = (profile.gears[k] or 0) + n
	end
end
QuestService.Grant = grant

function QuestService.Claim(profile, index)
	local q = QuestService.Ensure(profile)
	local e = type(index) == "number" and q.list[math.floor(index)]
	if not e then
		return { success = false, message = "That quest doesn't exist." }
	end
	if e.claimed then
		return { success = false, message = "Already claimed." }
	end
	if e.progress < e.target then
		return { success = false, message = "Not finished yet!" }
	end
	e.claimed = true
	grant(profile, Config.DailyQuestRewards[e.tier])
	local all = true
	for _, x in ipairs(q.list) do
		if not x.claimed then
			all = false
		end
	end
	local weekBonus = false
	if all and q.lastAllDay ~= q.day then
		q.streak = ((q.lastAllDay == q.day - 1) and (q.streak or 0) or 0) + 1
		q.lastAllDay = q.day
		if q.streak >= 7 then
			grant(profile, Config.DailyQuestWeekBonus)
			q.streak = 0
			weekBonus = true
		end
	end
	local msg = weekBonus and "7-DAY BONUS UNLOCKED! Huge rewards added to your backpack!"
		or (all and ("All quests done! Streak: " .. q.streak .. "/7 days")) or "Quest reward claimed!"
	return { success = true, message = msg, weekBonus = weekBonus }
end

-- what the client sees
function QuestService.Public(profile)
	local q = QuestService.Ensure(profile)
	local list = {}
	for i, e in ipairs(q.list) do
		local def
		for _, d in ipairs(Config.DailyQuests[e.tier]) do
			if d.id == e.id then
				def = d
			end
		end
		list[i] = { id = e.id, tier = e.tier, text = string.format(def and def.text or "%d", e.target), target = e.target, progress = e.progress, claimed = e.claimed }
	end
	return { day = q.day, list = list, streak = q.streak or 0, lastAllDay = q.lastAllDay, resetAt = (q.day + 1) * 86400 }
end

-- saved data -> clean table
function QuestService.Sanitize(data)
	if type(data) ~= "table" or type(data.day) ~= "number" or type(data.list) ~= "table" then
		return nil
	end
	local list = {}
	for _, e in ipairs(data.list) do
		if type(e) == "table" and type(e.id) == "string" and Config.DailyQuests[e.tier] and type(e.target) == "number" then
			table.insert(list, { id = e.id, tier = e.tier, stat = tostring(e.stat), target = math.floor(e.target), progress = math.clamp(math.floor(tonumber(e.progress) or 0), 0, e.target), claimed = e.claimed == true })
		end
	end
	return { day = math.floor(data.day), list = list, streak = math.clamp(math.floor(tonumber(data.streak) or 0), 0, 7), lastAllDay = math.floor(tonumber(data.lastAllDay) or -1) }
end

return QuestService
