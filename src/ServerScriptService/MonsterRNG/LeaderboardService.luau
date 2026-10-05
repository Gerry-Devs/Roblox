local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

--------------------------------------------------------------------
-- Global leaderboards (every server): CASH/S and REBIRTHS. Two studded
-- boards beside the Gear Shop show the top 50 (scroll them). Scores are saved every
-- 2 minutes; the boards refresh every 2 minutes.
--------------------------------------------------------------------
local LeaderboardService = {}
local TOP = 50 -- (the boards scroll)

local BOARDS = {
	{ key = "cash", store = "LB_CashPerSec_v1", title = "TOP CASH / S", color = Color3.fromRGB(110, 230, 120), offset = Vector3.new(-20, 1, 30), prefix = "$", suffix = "/s" },
	{ key = "rebirths", store = "LB_Rebirths_v1", title = "TOP REBIRTHS", color = Color3.fromRGB(255, 205, 60), offset = Vector3.new(20, 1, 30), prefix = "", suffix = "" },
}

local deps
local names = {} -- userId -> name
local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.Name
		return p.Name
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or ("Player " .. userId)
	return names[userId]
end

local function part(parent, name, size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.Transparency = transparency or 0
	for _, f in ipairs({ "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }) do
		p[f] = Enum.SurfaceType.Studs
	end
	p.Parent = parent
	return p
end

-- the board: two wooden posts, a studded frame and the screen. The
-- screen's picture (title + a scrolling list) is drawn on each player's
-- screen by LeaderboardClient from the "Data" value (JSON).
local function buildBoard(hub, def)
	local model = Instance.new("Model")
	model.Name = "Leaderboard_" .. def.key
	model:SetAttribute("Title", def.title)
	model:SetAttribute("Color", def.color)
	local pos = def.offset
	-- facing the middle of the plaza
	local origin = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local WOOD = Color3.fromRGB(150, 100, 58)
	local W, H = 15, 18
	part(model, "Post", Vector3.new(1.4, H + 2, 1.4), origin * CFrame.new(-W / 2 - 0.4, (H + 2) / 2, 0), WOOD)
	part(model, "Post", Vector3.new(1.4, H + 2, 1.4), origin * CFrame.new(W / 2 + 0.4, (H + 2) / 2, 0), WOOD)
	part(model, "Frame", Vector3.new(W + 1.2, H + 1.2, 0.8), origin * CFrame.new(0, H / 2 + 2, 0.3), def.color:Lerp(Color3.new(0, 0, 0), 0.35))
	part(model, "Roof", Vector3.new(W + 3, 1, 3), origin * CFrame.new(0, H + 3, 0), def.color)
	part(model, "Screen", Vector3.new(W, H, 0.4), origin * CFrame.new(0, H / 2 + 2, -0.2), Color3.fromRGB(25, 30, 55))
	local data = Instance.new("StringValue")
	data.Name = "Data"
	data.Value = "[]"
	data.Parent = model
	model.Parent = hub
	return data
end

local function scoreOf(def, profile)
	if def.key == "cash" then
		return math.clamp(math.floor(deps.WorldService.GetProfileIncome(profile)), 0, 9e15)
	end
	return math.floor(profile.rebirths or 0)
end

function LeaderboardService.Start(d)
	deps = d
	local world = workspace:WaitForChild("MonsterRNGWorld", 60)
	local hub = world and world:WaitForChild("Hub", 60)
	if not hub then
		warn("[Leaderboard] no Hub to put the boards in")
		return
	end
	local boards = {}
	for _, def in ipairs(BOARDS) do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, def.store)
		boards[def.key] = { def = def, data = buildBoard(hub, def), store = ok and store or nil }
	end

	local function saveScores()
		for _, p in ipairs(Players:GetPlayers()) do
			local profile = deps.DataService.Get(p)
			if profile then
				for _, b in pairs(boards) do
					if b.store then
						pcall(b.store.SetAsync, b.store, tostring(p.UserId), scoreOf(b.def, profile))
					end
				end
			end
		end
	end
	local function refresh()
		for _, b in pairs(boards) do
			local entries = {}
			local ok = b.store and pcall(function()
				local pages = b.store:GetSortedAsync(false, TOP)
				for _, item in ipairs(pages:GetCurrentPage()) do
					table.insert(entries, { userId = tonumber(item.key), value = item.value })
				end
			end)
			if not ok then
				-- no DataStore (e.g. Studio without API access): this server's players
				entries = {}
				for _, p in ipairs(Players:GetPlayers()) do
					local profile = deps.DataService.Get(p)
					if profile then
						table.insert(entries, { userId = p.UserId, value = scoreOf(b.def, profile) })
					end
				end
				table.sort(entries, function(x, y)
					return x.value > y.value
				end)
			end
			local list = {}
			for i = 1, math.min(TOP, #entries) do
				local e = entries[i]
				list[i] = { n = nameOf(e.userId), v = b.def.prefix .. Config.FormatNumber(e.value) .. b.def.suffix }
			end
			b.data.Value = HttpService:JSONEncode(list)
		end
	end

	task.spawn(function()
		task.wait(10)
		while true do
			pcall(saveScores)
			pcall(refresh)
			task.wait(120)
		end
	end)
end

return LeaderboardService
