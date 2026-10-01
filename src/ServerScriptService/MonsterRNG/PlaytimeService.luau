local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))
local RollService = require(script.Parent:WaitForChild("RollService"))

--------------------------------------------------------------------
-- Play-time milestones (Config.Playtime). Per session: the timer starts
-- at 0 every time you join. Only active time counts: if you don't move
-- or touch anything for afkAfter seconds, the timer pauses until you're
-- back. Claimed rewards are remembered for this session only.
--------------------------------------------------------------------
local PlaytimeService = {}
local P = Config.Playtime
local deps
local state = {} -- player -> { active, claimed, lastActive, lastPos, afk }
local stateEvent

local function publicState(s)
	-- string keys: a table with gaps (1, 3 claimed) doesn't survive a remote
	local claimed = {}
	for i in pairs(s.claimed) do
		claimed[tostring(i)] = true
	end
	return { active = math.floor(s.active), claimed = claimed, afk = s.afk }
end

local function push(player)
	local s = state[player]
	if s and stateEvent then
		stateEvent:FireClient(player, publicState(s))
	end
end

local function grant(player, profile, m)
	local parts = {}
	if m.cashPct then
		local amount = Config.CashPackAmount(profile, m.cashPct)
		profile.cash += amount
		table.insert(parts, "$" .. Config.FormatNumber(amount))
	end
	if m.shards then
		profile.riftShards = (profile.riftShards or 0) + m.shards
		table.insert(parts, m.shards .. " Shards")
	end
	for key, n in pairs(m.potions or {}) do
		profile.potions[key] = (profile.potions[key] or 0) + n
		local potion = Config.GetPotion(key)
		table.insert(parts, n .. "x " .. (potion and potion.name or key))
	end
	if m.egg then
		local egg = RollService.GiveEgg(profile, m.egg)
		table.insert(parts, "a " .. Config.GetRarity(egg.rarity).name .. " Egg")
	end
	return table.concat(parts, " + ")
end

function PlaytimeService.Start(d)
	deps = d
	stateEvent = d.getRemote("PlaytimeState", "RemoteEvent")
	local activeEvent = d.getRemote("PlaytimeActive", "RemoteEvent")
	local claimRemote = d.getRemote("PlaytimeClaim", "RemoteFunction")

	local function setup(player)
		state[player] = { active = 0, claimed = {}, lastActive = os.clock(), afk = false }
	end
	Players.PlayerAdded:Connect(setup)
	for _, p in ipairs(Players:GetPlayers()) do
		setup(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		state[p] = nil
	end)

	-- the client says "I'm here" when the player taps / types / moves
	activeEvent.OnServerEvent:Connect(function(player)
		local s = state[player]
		if s then
			s.lastActive = os.clock()
		end
	end)

	claimRemote.OnServerInvoke = function(player, index)
		local s = state[player]
		local profile = deps.DataService.Get(player)
		if not s or not profile then
			return { success = false, message = "Still loading..." }
		end
		if type(index) == "string" then -- "get"
			return { success = true, state = publicState(s) }
		end
		local m = type(index) == "number" and P.milestones[index]
		if not m then
			return { success = false, message = "" }
		end
		if s.claimed[index] then
			return { success = false, message = "Already claimed!" }
		end
		if s.active < m.minutes * 60 then
			return { success = false, message = "Keep playing to unlock this reward!" }
		end
		s.claimed[index] = true
		local text = grant(player, profile, m)
		deps.updateLeaderstats(player)
		deps.sync(player)
		push(player)
		return { success = true, message = "Play-time reward: " .. text .. "!", state = publicState(s) }
	end

	-- count the seconds you're active (moving your character counts too)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			local now = os.clock()
			for player, s in pairs(state) do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local pos = root.Position
					if s.lastPos and (pos - s.lastPos).Magnitude > 2 then
						s.lastActive = now
					end
					s.lastPos = pos
				end
				local afk = now - s.lastActive > P.afkAfter
				if not afk then
					s.active += 1
				end
				-- tell the client when AFK starts / ends, and every 15 s
				if afk ~= s.afk or tick % 15 == 0 then
					s.afk = afk
					push(player)
				end
			end
		end
	end)
end

return PlaytimeService
