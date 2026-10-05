local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

--------------------------------------------------------------------
-- Global leaderboards (every server): CASH/S and REBIRTHS. Two studded
-- boards beside the Gear Shop show the top 20. Scores are saved every
-- 2 minutes; the boards refresh every 2 minutes.
--------------------------------------------------------------------
local LeaderboardService = {}
local TOP = 20
local OUTLINE = Color3.fromRGB(10, 15, 35)

local BOARDS = {
	{ key = "cash", store = "LB_CashPerSec_v1", title = "TOP CASH / S", color = Color3.fromRGB(110, 230, 120), offset = Vector3.new(-18, 1, 30), prefix = "$", suffix = "/s" },
	{ key = "rebirths", store = "LB_Rebirths_v1", title = "TOP REBIRTHS", color = Color3.fromRGB(255, 205, 60), offset = Vector3.new(18, 1, 30), prefix = "", suffix = "" },
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

-- the board: two wooden posts, a studded frame and the screen
local function buildBoard(hub, def)
	local model = Instance.new("Model")
	model.Name = "Leaderboard_" .. def.key
	local pos = def.offset
	-- facing the middle of the plaza
	local origin = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local WOOD = Color3.fromRGB(150, 100, 58)
	local W, H = 13, 15
	part(model, "Post", Vector3.new(1.4, H + 2, 1.4), origin * CFrame.new(-W / 2 - 0.4, (H + 2) / 2, 0), WOOD)
	part(model, "Post", Vector3.new(1.4, H + 2, 1.4), origin * CFrame.new(W / 2 + 0.4, (H + 2) / 2, 0), WOOD)
	part(model, "Frame", Vector3.new(W + 1.2, H + 1.2, 0.8), origin * CFrame.new(0, H / 2 + 2, 0.3), def.color:Lerp(Color3.new(0, 0, 0), 0.35))
	part(model, "Roof", Vector3.new(W + 3, 1, 3), origin * CFrame.new(0, H + 3, 0), def.color)
	local screen = part(model, "Screen", Vector3.new(W, H, 0.4), origin * CFrame.new(0, H / 2 + 2, -0.2), Color3.fromRGB(25, 30, 55))
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Board"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = screen
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 34, 62)
	bg.Parent = sg
	-- studs on the board (same studs as the windows)
	if (Config.UIStudsImage or "") ~= "" then
		local studs = Instance.new("ImageLabel")
		studs.Size = UDim2.fromScale(1, 1)
		studs.BackgroundTransparency = 1
		studs.Image = Config.UIStudsImage
		studs.ScaleType = Enum.ScaleType.Tile
		studs.TileSize = UDim2.fromOffset(60, 60)
		studs.ImageTransparency = 0.75
		studs.Parent = bg
	end
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 64)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundColor3 = def.color
	title.Text = def.title
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = OUTLINE
	title.Parent = bg
	Instance.new("UICorner", title).CornerRadius = UDim.new(0, 14)
	local tst = Instance.new("UIStroke")
	tst.Thickness = 4
	tst.Color = OUTLINE
	tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tst.Parent = title
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.Size = UDim2.new(1, -20, 1, -90)
	rows.Position = UDim2.fromOffset(10, 82)
	rows.BackgroundTransparency = 1
	rows.Parent = bg
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 3)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = rows
	local rowLabels = {}
	for i = 1, TOP do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 1 / TOP, -3)
		row.BackgroundColor3 = i <= 3 and ({ Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 210, 225), Color3.fromRGB(215, 140, 80) })[i] or Color3.fromRGB(45, 52, 88)
		row.BackgroundTransparency = i <= 3 and 0.2 or 0.35
		row.Parent = rows
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local function cell(x, w, align)
			local l = Instance.new("TextLabel")
			l.Position = UDim2.new(x, 8, 0, 0)
			l.Size = UDim2.new(w, -16, 1, 0)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.LuckiestGuy
			l.TextScaled = true
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextStrokeTransparency = 0
			l.TextStrokeColor3 = OUTLINE
			l.TextXAlignment = align
			l.Text = ""
			l.Parent = row
			return l
		end
		rowLabels[i] = { rank = cell(0, 0.12, Enum.TextXAlignment.Left), name = cell(0.1, 0.55, Enum.TextXAlignment.Left), value = cell(0.62, 0.38, Enum.TextXAlignment.Right) }
		rowLabels[i].rank.Text = "#" .. i
	end
	model.Parent = hub
	return rowLabels
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
		boards[def.key] = { def = def, rows = buildBoard(hub, def), store = ok and store or nil }
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
			for i = 1, TOP do
				local e = entries[i]
				local r = b.rows[i]
				r.name.Text = e and nameOf(e.userId) or "-"
				r.value.Text = e and (b.def.prefix .. Config.FormatNumber(e.value) .. b.def.suffix) or ""
			end
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
