--------------------------------------------------------------------
-- PvpService: challenge posts (every server), monster-vs-monster
-- battles in the arena, credits, monthly seasons + leaderboard.
--
--  * A player POSTS a challenge: their strongest pen monsters are
--    saved as the team (MemoryStore, so every server sees it).
--  * Another player (any server) presses FIGHT: they are taken to the
--    arena and their team fights the posted team.
--  * Both players get credits + season points (the poster gets theirs
--    right away if online anywhere, or when they next join).
--  * Leaderboard = season points this month (OrderedDataStore).
--------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))
local MonsterModel = require(ReplicatedStorage.MonsterRNG:WaitForChild("MonsterModel"))
local P = Config.Pvp

local PvpService = {}
local deps
local pvpRemote, pvpEvent

local postMap
pcall(function()
	postMap = MemoryStoreService:GetSortedMap("MonsterRNG_PvpPosts")
end)
local resultStore
pcall(function()
	resultStore = DataStoreService:GetDataStore("MonsterRNG_PvpResults")
end)
local RESULT_TOPIC = "MonsterRNG_PvpResult"
-- the poster accepts / declines a fight (they can be in another server)
local REQUEST_TOPIC = "MonsterRNG_PvpRequest"
local RESPONSE_TOPIC = "MonsterRNG_PvpResponse"
local ACCEPT_SECONDS = 15 -- no answer in time (AFK / offline) = the fight starts
local pendingRequests = {} -- request id -> { posterId, answer }

local localPosts = {} -- Studio fallback when MemoryStore isn't available
local inBattle = {} -- player -> true
local readyFlags = {} -- player -> true once their screen has loaded the arena
local lastFight = {} -- player -> os.clock()

--------------------------------------------------------------------
-- profile helpers
--------------------------------------------------------------------
local function pvpOf(profile)
	profile.pvp = profile.pvp or { credits = 0, points = 0, season = "", wins = 0, losses = 0 }
	local season = Config.PvpSeason()
	if profile.pvp.season ~= season then
		-- a new month: season points start from 0 (credits stay)
		profile.pvp.season = season
		profile.pvp.points = 0
	end
	return profile.pvp
end

local boardStore = function()
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("MonsterRNG_PvpSeason_" .. Config.PvpSeason())
	end)
	return ok and store or nil
end

local function pushPoints(userId, points)
	task.spawn(function()
		local store = boardStore()
		if store then
			pcall(function()
				store:SetAsync(tostring(userId), math.max(0, math.floor(points)))
			end)
		end
	end)
end

local function buildTeam(profile)
	local list = {}
	for _, e in ipairs(profile.base or {}) do
		if e.kind == "monster" and Config.GetMonster(e.monsterId) then
			local hp, dmg = Config.GetPetStats(e, { upgrades = profile.upgrades, activeBoosts = {} })
			table.insert(list, { monsterId = e.monsterId, size = e.size, finish = e.finish, level = e.level or 1, hp = hp, dmg = dmg })
		end
	end
	table.sort(list, function(a, b)
		return a.hp + a.dmg * 10 > b.hp + b.dmg * 10
	end)
	while #list > P.maxTeam do
		table.remove(list)
	end
	return list
end

-- credits + points for one side of a fight
local function applyResult(profile, win, defended)
	local pv = pvpOf(profile)
	local credits, points
	if defended then
		credits = win and P.defendWinCredits or P.defendLossCredits
		points = win and P.defendWinPoints or -P.defendLossPoints
	else
		credits = win and P.winCredits or P.lossCredits
		points = win and P.winPoints or -P.lossPoints
	end
	pv.credits += credits
	pv.points = math.max(0, pv.points + points)
	if win then
		pv.wins += 1
	else
		pv.losses += 1
	end
	return credits, points, pv.points
end

--------------------------------------------------------------------
-- challenge posts
--------------------------------------------------------------------
local function setPost(userId, data)
	if postMap then
		local ok = pcall(function()
			postMap:SetAsync(tostring(userId), data, P.postMinutes * 60)
		end)
		if ok then
			return true
		end
	end
	localPosts[tostring(userId)] = { value = data, expires = os.time() + P.postMinutes * 60 }
	return true
end

local function removePost(userId)
	localPosts[tostring(userId)] = nil
	if postMap then
		pcall(function()
			postMap:RemoveAsync(tostring(userId))
		end)
	end
end

local function listPosts()
	local out = {}
	local seen = {}
	if postMap then
		local ok, items = pcall(function()
			return postMap:GetRangeAsync(Enum.SortDirection.Ascending, 100)
		end)
		if ok and items then
			for _, it in ipairs(items) do
				if type(it.value) == "table" and not it.value.taken then
					table.insert(out, it.value)
					seen[it.key] = true
				end
			end
		end
	end
	for key, p in pairs(localPosts) do
		if p.expires < os.time() then
			localPosts[key] = nil
		elseif not seen[key] and not p.value.taken then
			table.insert(out, p.value)
		end
	end
	table.sort(out, function(a, b)
		return (a.posted or 0) > (b.posted or 0)
	end)
	return out
end

-- claim a post so only ONE player can fight it
local function takePost(userId, takerId)
	local key = tostring(userId)
	local post
	if postMap then
		local ok = false
		for _ = 1, 3 do
			ok = pcall(function()
				postMap:UpdateAsync(key, function(old)
				if type(old) ~= "table" or old.taken then
					return nil -- gone or already taken: no change
				end
				old.taken = takerId
				post = old
				return old
			end, 60)
			end)
			if ok then
				break
			end
			task.wait(0.3)
		end
		if ok and post then
			removePost(userId)
			return post
		end
	end
	local lp = localPosts[key]
	if lp and not lp.value.taken and lp.expires > os.time() then
		localPosts[key] = nil
		return lp.value
	end
	return nil
end

local function myPost(userId)
	local key = tostring(userId)
	if postMap then
		local ok, v = pcall(function()
			return postMap:GetAsync(key)
		end)
		if ok and type(v) == "table" and not v.taken then
			return v
		end
	end
	local lp = localPosts[key]
	return lp and lp.expires > os.time() and lp.value or nil
end

--------------------------------------------------------------------
-- results for the poster (other server / offline)
--------------------------------------------------------------------
local function giveDefenderResult(player, r)
	local profile = deps.DataService.Get(player)
	if not profile then
		return false
	end
	local credits, points, total = applyResult(profile, r.win, true)
	pushPoints(player.UserId, total)
	deps.sync(player)
	pvpEvent:FireClient(player, {
		kind = "defended",
		win = r.win,
		opponent = r.opponent,
		credits = credits,
		points = points,
	})
	return true
end

local function claimResults(player)
	if not resultStore then
		return
	end
	local claimed = {}
	local ok = pcall(function()
		resultStore:UpdateAsync("u_" .. player.UserId, function(old)
			claimed = {}
			if type(old) ~= "table" or #old == 0 then
				return nil
			end
			for _, r in ipairs(old) do
				table.insert(claimed, r)
			end
			return {}
		end)
	end)
	if ok then
		for _, r in ipairs(claimed) do
			giveDefenderResult(player, r)
		end
	end
end

local function sendDefenderResult(userId, r)
	local here = Players:GetPlayerByUserId(userId)
	if here and deps.DataService.Get(here) then
		giveDefenderResult(here, r)
		return
	end
	if not resultStore then
		return
	end
	pcall(function()
		resultStore:UpdateAsync("u_" .. userId, function(old)
			old = type(old) == "table" and old or {}
			table.insert(old, r)
			return old
		end)
	end)
	pcall(function()
		MessagingService:PublishAsync(RESULT_TOPIC, { userId = userId })
	end)
end

--------------------------------------------------------------------
-- battle simulation (decided on the server, then played in the arena)
--------------------------------------------------------------------
local function simulate(teamA, teamB)
	local rng = Random.new()
	local units = {}
	for side, team in ipairs({ teamA, teamB }) do
		for i, m in ipairs(team) do
			table.insert(units, { side = side, idx = i, hp = m.hp, max = m.hp, dmg = m.dmg, nextAt = 0.4 + rng:NextNumber() * 0.8 })
		end
	end
	local events = {}
	local t = 0
	local function alive(side)
		local list = {}
		for _, u in ipairs(units) do
			if u.side == side and u.hp > 0 then
				table.insert(list, u)
			end
		end
		return list
	end
	while t < 60 do
		t += 0.1
		for _, u in ipairs(units) do
			if u.hp > 0 and t >= u.nextAt then
				local foes = alive(3 - u.side)
				if #foes == 0 then
					break
				end
				local target = foes[rng:NextInteger(1, #foes)]
				local crit = rng:NextNumber() < 0.1
				local dmg = math.max(1, math.floor(u.dmg * rng:NextNumber(0.85, 1.15) * (crit and 1.6 or 1)))
				target.hp = math.max(0, target.hp - dmg)
				table.insert(events, { t = t, a = { u.side, u.idx }, b = { target.side, target.idx }, dmg = dmg, crit = crit, left = target.hp, max = target.max })
				u.nextAt = t + 1 + rng:NextNumber() * 0.35
			end
		end
		if #alive(1) == 0 or #alive(2) == 0 then
			break
		end
	end
	local function share(side)
		local hp, max = 0, 0
		for _, u in ipairs(units) do
			if u.side == side then
				hp += u.hp
				max += u.max
			end
		end
		return max > 0 and hp / max or 0
	end
	local winner
	if #alive(2) == 0 and #alive(1) > 0 then
		winner = 1
	elseif #alive(1) == 0 and #alive(2) > 0 then
		winner = 2
	else
		winner = share(1) >= share(2) and 1 or 2 -- time up: most health left wins
	end
	return events, winner
end

--------------------------------------------------------------------
-- the arena map (one per fight at the same time, far from the world)
--------------------------------------------------------------------
local arenasFolder
local arenaSlots = {} -- slot -> busy
local ARENA_ORIGIN = Vector3.new(6000, 200, 0)

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function buildArena(slot)
	arenasFolder = arenasFolder or workspace:FindFirstChild("PvpArenas") or Instance.new("Folder")
	arenasFolder.Name = "PvpArenas"
	arenasFolder.Parent = workspace
	local name = "Arena_" .. slot
	local existing = arenasFolder:FindFirstChild(name)
	if existing then
		return existing
	end
	local o = ARENA_ORIGIN + Vector3.new(slot * 500, 0, 0)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Origin", o)
	local STONE, STONE_DARK, SAND = Color3.fromRGB(150, 140, 130), Color3.fromRGB(95, 88, 84), Color3.fromRGB(225, 196, 140)
	local RED, BLUE, GOLD = Color3.fromRGB(215, 60, 60), Color3.fromRGB(60, 120, 230), Color3.fromRGB(255, 200, 60)
	-- the fighting floor: sand circle inside a stone ring
	part(m, "Base", Vector3.new(6, 140, 140), CFrame.new(o + Vector3.new(0, -3, 0)) * CFrame.Angles(0, 0, math.rad(90)), STONE_DARK, Enum.Material.Slate, Enum.PartType.Cylinder)
	part(m, "Floor", Vector3.new(1, 104, 104), CFrame.new(o + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), SAND, Enum.Material.Sand, Enum.PartType.Cylinder)
	part(m, "CenterRing", Vector3.new(1.1, 22, 22), CFrame.new(o + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(205, 175, 120), Enum.Material.Sand, Enum.PartType.Cylinder)
	-- team sides
	part(m, "RedMark", Vector3.new(0.2, 14, 30), CFrame.new(o + Vector3.new(-34, 0.85, 0)), RED, Enum.Material.Neon).Transparency = 0.4
	part(m, "BlueMark", Vector3.new(0.2, 14, 30), CFrame.new(o + Vector3.new(34, 0.85, 0)), BLUE, Enum.Material.Neon).Transparency = 0.4
	for _, sgn in ipairs({ -1, 1 }) do
		part(m, "SideLine", Vector3.new(0.3, 0.2, 60), CFrame.new(o + Vector3.new(sgn * 28, 0.85, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
	-- stone wall + 2 rows of stands all around (24 pieces each, kept light)
	local segs = 24
	for i = 0, segs - 1 do
		local ang = (i / segs) * math.pi * 2
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local up = Vector3.new(0, 3, 0)
		part(m, "Wall", Vector3.new(14.4, 6, 2), CFrame.lookAt(o + dir * 53 + up, o + up), STONE, Enum.Material.Slate)
		for row = 1, 2 do
			local r = 57 + row * 6
			local h = 3 + row * 4
			local hv = Vector3.new(0, h / 2, 0)
			part(m, "Stand", Vector3.new(16 + row * 2.4, h, 6), CFrame.lookAt(o + dir * r + hv, o + hv), row == 1 and STONE_DARK or STONE, Enum.Material.Slate)
		end
		if i % 3 == 0 then
			-- torches: glowing flame + light (no Fire effect: cheaper)
			local torchPos = o + dir * 52 + Vector3.new(0, 7, 0)
			part(m, "TorchPole", Vector3.new(0.6, 3, 0.6), CFrame.new(torchPos - Vector3.new(0, 1, 0)), Color3.fromRGB(90, 60, 35), Enum.Material.Wood)
			local flame = part(m, "Flame", Vector3.new(1.2, 1.6, 1.2), CFrame.new(torchPos + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
			flame.CanCollide = false
			if i % 6 == 0 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 170, 80)
				light.Range = 28
				light.Brightness = 1.4
				light.Parent = flame
			end
		end
		if i % 6 == 1 or i % 6 == 4 then
			-- team banners (red on the left half, blue on the right)
			local bannerColor = dir.X < 0 and RED or BLUE
			local top = o + dir * 70 + Vector3.new(0, 16, 0)
			part(m, "BannerPole", Vector3.new(0.6, 16, 0.6), CFrame.new(top - Vector3.new(0, 4, 0)), Color3.fromRGB(80, 60, 40), Enum.Material.Wood)
			part(m, "Banner", Vector3.new(4, 7, 0.3), CFrame.lookAt(top - Vector3.new(0, 1.5, 0) + dir * -0.6, o + Vector3.new(0, 14.5, 0)), bannerColor, Enum.Material.Fabric).CanCollide = false
		end
	end
	-- where the challenger watches: a balcony behind the red team
	local balcony = o + Vector3.new(-66, 12, 0)
	part(m, "Balcony", Vector3.new(14, 1, 16), CFrame.new(balcony), STONE, Enum.Material.Slate)
	part(m, "BalconyRail", Vector3.new(1, 3, 16), CFrame.new(balcony + Vector3.new(7, 2, 0)), STONE_DARK, Enum.Material.Slate)
	part(m, "BalconyRailL", Vector3.new(14, 3, 1), CFrame.new(balcony + Vector3.new(0, 2, 8)), STONE_DARK, Enum.Material.Slate)
	part(m, "BalconyRailR", Vector3.new(14, 3, 1), CFrame.new(balcony + Vector3.new(0, 2, -8)), STONE_DARK, Enum.Material.Slate)
	local watch = part(m, "WatchSpot", Vector3.new(2, 1, 2), CFrame.lookAt(balcony + Vector3.new(0, 3.5, 0), o + Vector3.new(0, 3.5, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	watch.Transparency = 1
	watch.CanCollide = false
	-- a big invisible dome so nobody falls out
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local wall = part(m, "Bound", Vector3.new(40, 80, 2), CFrame.lookAt(o + dir * 80 + Vector3.new(0, 30, 0), o + Vector3.new(0, 30, 0)), Color3.new(), Enum.Material.SmoothPlastic)
		wall.Transparency = 1
	end
	part(m, "Lid", Vector3.new(170, 2, 170), CFrame.new(o + Vector3.new(0, 70, 0)), Color3.new(), Enum.Material.SmoothPlastic).Transparency = 1
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = false
			d.CanTouch = false
			if d.Transparency >= 1 then
				d.CanQuery = false
			end
		end
	end
	local fighters = Instance.new("Folder")
	fighters.Name = "Fighters"
	fighters.Parent = m
	m.Parent = arenasFolder
	return m
end

local function takeSlot()
	for i = 1, 20 do
		if not arenaSlots[i] then
			arenaSlots[i] = true
			return i
		end
	end
	return nil
end

--------------------------------------------------------------------
-- one fighter model in the arena
--------------------------------------------------------------------
local function spawnFighter(arena, entry, side, idx, pos, lookAt)
	local monster = Config.GetMonster(entry.monsterId)
	local sizeVariant = Config.GetSizeVariant(entry.size)
	local bodySize = 4 * sizeVariant.scale
	local model = Instance.new("Model")
	model.Name = "F" .. side .. "_" .. idx
	model:SetAttribute("Kind", "monster")
	local body = Instance.new("Part")
	body.Name = "MonsterBody"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(bodySize, bodySize, bodySize)
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.lookAt(pos + Vector3.new(0, bodySize * 0.5 + 0.8, 0), lookAt + Vector3.new(0, bodySize * 0.5 + 0.8, 0))
	body.Parent = model
	model.PrimaryPart = body
	model.Parent = arena.Fighters
	pcall(function()
		MonsterModel.Build(body, bodySize, { monsterId = entry.monsterId, groundOffset = bodySize * 0.5, finish = entry.finish })
	end)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = false
			d.CanTouch = false
		end
	end
	model:SetAttribute("PartCount", #model:GetDescendants())
	-- name + health bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bar"
	bb.Size = UDim2.fromOffset(120, 36)
	bb.StudsOffset = Vector3.new(0, bodySize * 1.45 + 0.8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	bb.Parent = body
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = (monster and monster.name or "?") .. "  Lv" .. (entry.level or 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.LuckiestGuy
	nameLabel.TextColor3 = side == 1 and Color3.fromRGB(255, 140, 140) or Color3.fromRGB(140, 190, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Parent = bb
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0.32, 0)
	back.Position = UDim2.new(0, 0, 0.6, 0)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	back.BorderSizePixel = 0
	back.Parent = bb
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = side == 1 and Color3.fromRGB(235, 70, 70) or Color3.fromRGB(70, 140, 240)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	return { model = model, body = body, home = body.CFrame, fill = fill, size = bodySize, attacks = 0, hits = 0 }
end

local function damagePop(body, amount, crit)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 34)
	bb.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = body
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = (crit and "CRIT " or "") .. "-" .. Config.FormatNumber(amount)
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = crit and Color3.fromRGB(255, 210, 60) or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.8), { StudsOffset = bb.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		bb:Destroy()
	end)
end

--------------------------------------------------------------------
-- run a fight: challenger (side 1, red) vs the posted team (side 2, blue)
--------------------------------------------------------------------
local function returnToTown(player)
	local character = player.Character
	local spawn = workspace:FindFirstChild("MonsterRNGWorld") and workspace.MonsterRNGWorld:FindFirstChild("MonsterRNGSpawn")
	if character and spawn then
		character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 4, 0)))
	end
end

local function runBattle(player, profile, post)
	local teamA = buildTeam(profile)
	local teamB = post.team or {}
	local events, winner = simulate(teamA, teamB)
	local slot = takeSlot()
	local arena = slot and buildArena(slot)

	inBattle[player] = true
	player:SetAttribute("InPvp", true)
	local o = arena and arena:GetAttribute("Origin")
	local fighters = { {}, {} }
	if arena then
		arena.Fighters:ClearAllChildren()
		local function place(team, side)
			local n = #team
			for i, entry in ipairs(team) do
				local z = (i - (n + 1) / 2) * 9
				local x = side == 1 and -26 or 26
				local pos = o + Vector3.new(x + (i % 2) * (side == 1 and -5 or 5), 0.5, z)
				fighters[side][i] = spawnFighter(arena, entry, side, i, pos, o + Vector3.new(0, 0.5, z))
			end
		end
		place(teamA, 1)
		place(teamB, 2)
		local watch = arena:FindFirstChild("WatchSpot")
		-- stream the arena to the player before moving them there
		pcall(function()
			player:RequestStreamAroundAsync(o, 10)
		end)
		local character = player.Character
		if character and watch then
			character:PivotTo(watch.CFrame)
		end
	end
	local function teamHp(team, hpTable)
		local hp, max = 0, 0
		for i, m in ipairs(team) do
			hp += hpTable[i]
			max += m.hp
		end
		return hp, max
	end
	local hpA, hpB = {}, {}
	for i, m in ipairs(teamA) do
		hpA[i] = m.hp
	end
	for i, m in ipairs(teamB) do
		hpB[i] = m.hp
	end
	local aHp, aMax = teamHp(teamA, hpA)
	local bHp, bMax = teamHp(teamB, hpB)
	-- wait until the player's game has loaded the arena + every monster
	readyFlags[player] = nil
	pvpEvent:FireClient(player, { kind = "loading", origin = o, fighters = #teamA + #teamB })
	local t0 = os.clock()
	while player.Parent and not readyFlags[player] and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	readyFlags[player] = nil
	pvpEvent:FireClient(player, {
		kind = "start",
		me = player.DisplayName,
		them = post.display or post.name or "?",
		aHp = aHp, aMax = aMax, bHp = bHp, bMax = bMax,
		countdown = 3,
		origin = o,
	})
	task.wait(3.2) -- 3.. 2.. 1.. FIGHT
	local start = os.clock()
	for _, ev in ipairs(events) do
		if not player.Parent then
			break
		end
		local waitFor = ev.t - (os.clock() - start)
		if waitFor > 0 then
			task.wait(waitFor)
		end
		local attacker = fighters[ev.a[1]][ev.a[2]]
		local target = fighters[ev.b[1]][ev.b[2]]
		if attacker and target and attacker.body.Parent and target.body.Parent then
			-- lunge toward the target and back
			local from = attacker.home
			local toward = (target.body.Position - from.Position) * Vector3.new(1, 0, 1)
			local reach = math.max(0, toward.Magnitude - (attacker.size + target.size) * 0.6)
			local dest = toward.Magnitude > 0.1 and (from.Position + toward.Unit * math.min(reach, 14)) or from.Position
			local lookCF = CFrame.lookAt(dest, dest + (toward.Magnitude > 0.1 and toward.Unit or from.LookVector))
			TweenService:Create(attacker.body, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { CFrame = lookCF }):Play()
			attacker.attacks += 1
			attacker.model:SetAttribute("Attacks", attacker.attacks)
			task.delay(0.22, function()
				if target.body.Parent then
					target.hits += 1
					target.model:SetAttribute("Hits", target.hits)
					damagePop(target.body, ev.dmg, ev.crit)
					target.fill.Size = UDim2.fromScale(math.clamp(ev.left / math.max(1, ev.max), 0, 1), 1)
					if ev.left <= 0 then
						target.model:SetAttribute("Dying", true)
						target.fill.Parent.Parent.Enabled = false
						task.delay(1.4, function()
							target.model:SetAttribute("FadeOut", true) -- players' screens fade the rig pieces
							for _, d in ipairs(target.model:GetDescendants()) do
								if d:IsA("BasePart") and d.Transparency < 1 then
									TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
								end
							end
						end)
					end
				end
				if attacker.body.Parent then
					TweenService:Create(attacker.body, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { CFrame = from }):Play()
				end
			end)
		end
		if ev.b[1] == 1 then
			hpA[ev.b[2]] = ev.left
		else
			hpB[ev.b[2]] = ev.left
		end
		aHp = teamHp(teamA, hpA)
		bHp = teamHp(teamB, hpB)
		pvpEvent:FireClient(player, { kind = "hp", aHp = aHp, aMax = aMax, bHp = bHp, bMax = bMax })
	end
	task.wait(1.5)

	-- results
	local win = winner == 1
	local credits, points, total = 0, 0, 0
	local p2 = deps.DataService.Get(player)
	if p2 then
		credits, points, total = applyResult(p2, win, false)
		pushPoints(player.UserId, total)
		deps.sync(player)
		task.spawn(deps.DataService.Save, player)
	end
	pvpEvent:FireClient(player, { kind = "end", win = win, credits = credits, points = points, them = post.display or post.name })
	sendDefenderResult(post.userId, { win = not win, opponent = player.DisplayName, t = os.time() })

	task.wait(4)
	if arena then
		arena.Fighters:ClearAllChildren()
		arenaSlots[slot] = nil
	end
	if player.Parent then
		player:SetAttribute("InPvp", nil)
		returnToTown(player)
	end
	inBattle[player] = nil
end

--------------------------------------------------------------------
-- leaderboard (top 100 of this season), cached for 60s
--------------------------------------------------------------------
local nameCache = {}
local board = { season = "", at = 0, list = {} }
local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and n or ("#" .. userId)
	return nameCache[userId]
end
local function getBoard()
	local season = Config.PvpSeason()
	if board.season == season and os.clock() - board.at < 60 then
		return board.list
	end
	local store = boardStore()
	local list = {}
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 100)
		end)
		if ok and pages then
			for rank, item in ipairs(pages:GetCurrentPage()) do
				local uid = tonumber(item.key)
				if uid and item.value > 0 then
					table.insert(list, { rank = rank, userId = uid, points = item.value })
				end
			end
		end
	end
	-- names (in parallel)
	local pending = #list
	for _, row in ipairs(list) do
		task.spawn(function()
			row.name = getName(row.userId)
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 5 do
		task.wait(0.1)
	end
	board = { season = season, at = os.clock(), list = list }
	return list
end

--------------------------------------------------------------------
-- ask the poster: ACCEPT or DECLINE (popup on their screen, any server)
--------------------------------------------------------------------
local function showRequest(posterId, req)
	local poster = Players:GetPlayerByUserId(posterId)
	if poster then
		pvpEvent:FireClient(poster, req)
		return true
	end
	return false
end

-- yields until the poster answers (true = fight) or the time runs out
local function askPoster(post, challenger, profile)
	local team = buildTeam(profile)
	local id = HttpService:GenerateGUID(false)
	local req = {
		kind = "request",
		id = id,
		from = challenger.DisplayName,
		fromUser = challenger.Name,
		power = Config.TeamPower(team),
		count = #team,
		yourPower = post.power or 0,
		seconds = ACCEPT_SECONDS,
	}
	pendingRequests[id] = { posterId = post.userId }
	if not showRequest(post.userId, req) then
		pcall(function()
			MessagingService:PublishAsync(REQUEST_TOPIC, { posterId = post.userId, req = req })
		end)
	end
	local t0 = os.clock()
	local answer
	while os.clock() - t0 < ACCEPT_SECONDS + 2 do
		answer = pendingRequests[id].answer
		if answer ~= nil or not challenger.Parent then
			break
		end
		task.wait(0.2)
	end
	pendingRequests[id] = nil
	if answer == nil then
		return true, "timeout" -- no answer (away / offline): the challenge was open, so fight
	end
	return answer, answer and "accepted" or "declined"
end

local function answerRequest(posterId, id, accept)
	local pend = type(id) == "string" and pendingRequests[id]
	if pend then
		if pend.posterId == posterId then
			pend.answer = accept
		end
		return
	end
	-- the challenger is in another server
	pcall(function()
		MessagingService:PublishAsync(RESPONSE_TOPIC, { id = id, posterId = posterId, accept = accept })
	end)
end

--------------------------------------------------------------------
-- remote
--------------------------------------------------------------------
local function info(player, profile)
	local pv = pvpOf(profile)
	local posts = {}
	for _, p in ipairs(listPosts()) do
		if p.userId ~= player.UserId then
			table.insert(posts, { userId = p.userId, name = p.name, display = p.display, power = p.power, count = #(p.team or {}), posted = p.posted, level = p.level })
		end
	end
	local mine = myPost(player.UserId)
	local team = buildTeam(profile)
	return {
		success = true,
		credits = pv.credits,
		points = pv.points,
		wins = pv.wins,
		losses = pv.losses,
		season = pv.season,
		seasonLeft = Config.PvpSeasonLeft(),
		myPower = Config.TeamPower(team),
		myCount = #team,
		myPost = mine and { posted = mine.posted, expires = (mine.posted or os.time()) + P.postMinutes * 60 } or nil,
		posts = posts,
	}
end

local function onAction(player, action, arg)
	local profile = deps.DataService.Get(player)
	if not profile then
		return { success = false, message = "Loading..." }
	end
	if action == "ready" then
		if inBattle[player] then
			readyFlags[player] = true
		end
		return { success = true }
	elseif action == "info" then
		return info(player, profile)
	elseif action == "board" then
		local list = getBoard()
		local myRank
		for _, row in ipairs(list) do
			if row.userId == player.UserId then
				myRank = row.rank
			end
		end
		return { success = true, list = list, myRank = myRank, myPoints = pvpOf(profile).points, season = Config.PvpSeason(), seasonLeft = Config.PvpSeasonLeft(), tiers = P.rewardTiers }
	elseif action == "post" then
		local team = buildTeam(profile)
		if #team == 0 then
			return { success = false, message = "Put monsters in your pen first - they are your team!" }
		end
		setPost(player.UserId, {
			userId = player.UserId,
			name = player.Name,
			display = player.DisplayName,
			team = team,
			power = Config.TeamPower(team),
			posted = os.time(),
		})
		return { success = true, message = "Challenge posted! Anyone can fight your team for the next " .. P.postMinutes .. " minutes." }
	elseif action == "respond" and type(arg) == "table" then
		answerRequest(player.UserId, arg.id, arg.accept == true)
		return { success = true }
	elseif action == "cancel" then
		removePost(player.UserId)
		return { success = true, message = "Challenge removed." }
	elseif action == "fight" then
		local target = tonumber(arg)
		if not target or target == player.UserId then
			return { success = false, message = "Pick a challenge." }
		end
		if inBattle[player] then
			return { success = false, message = "You're already fighting!" }
		end
		if lastFight[player] and os.clock() - lastFight[player] < P.cooldown then
			return { success = false, message = "Wait a moment before the next fight." }
		end
		local team = buildTeam(profile)
		if #team == 0 then
			return { success = false, message = "Put monsters in your pen first - they are your team!" }
		end
		local post = takePost(target, player.UserId)
		if not post then
			return { success = false, message = "That challenge was already taken or ended." }
		end
		lastFight[player] = os.clock()
		-- the poster decides (popup on their screen)
		local accepted, why = askPoster(post, player, profile)
		if not player.Parent then
			return { success = false }
		end
		if not accepted then
			post.taken = nil
			setPost(post.userId, post) -- back on the list for others
			return { success = false, message = (post.display or post.name or "They") .. " declined your challenge." }
		end
		if why == "timeout" and inBattle[player] then
			return { success = false, message = "You're already fighting!" }
		end
		task.spawn(function()
			local ok, err = pcall(runBattle, player, profile, post)
			if not ok then
				warn("[PvP] battle error: " .. tostring(err))
				inBattle[player] = nil
				if player.Parent then
					player:SetAttribute("InPvp", nil)
					returnToTown(player)
				end
			end
		end)
		return { success = true, message = "To the arena!" }
	end
	return { success = false, message = "Unknown action." }
end

function PvpService.Start(d)
	deps = d
	pvpRemote = d.getRemote("PvpAction", "RemoteFunction")
	pvpEvent = d.getRemote("PvpEvent", "RemoteEvent")
	pvpRemote.OnServerInvoke = function(player, action, arg)
		local ok, r = pcall(onAction, player, action, arg)
		if not ok then
			warn("[PvP] " .. tostring(r))
			return { success = false, message = "Something went wrong, try again." }
		end
		return r
	end
	-- fight requests / answers between servers
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(REQUEST_TOPIC, function(msg)
				local dta = msg.Data
				if type(dta) == "table" and type(dta.req) == "table" then
					showRequest(tonumber(dta.posterId) or 0, dta.req)
				end
			end)
		end)
		pcall(function()
			MessagingService:SubscribeAsync(RESPONSE_TOPIC, function(msg)
				local dta = msg.Data
				local pend = type(dta) == "table" and pendingRequests[dta.id]
				if pend and pend.posterId == tonumber(dta.posterId) then
					pend.answer = dta.accept == true
				end
			end)
		end)
	end)
	-- the poster's results when their post was fought in another server
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(RESULT_TOPIC, function(msg)
				local dta = msg.Data
				local p = type(dta) == "table" and Players:GetPlayerByUserId(tonumber(dta.userId) or 0)
				if p then
					claimResults(p)
				end
			end)
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		for _ = 1, 40 do
			if deps.DataService.Get(player) or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		task.wait(3)
		claimResults(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyFlags[player] = nil
		inBattle[player] = nil
		lastFight[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in ipairs(Players:GetPlayers()) do
				claimResults(p)
			end
		end
	end)
	-- build the first arena now so the first fight starts fast
	task.defer(buildArena, 1)
end

return PvpService
