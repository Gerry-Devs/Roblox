local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

--------------------------------------------------------------------
-- Fusion Machine (in the Desert, near the Forest side). Walk up, press
-- the prompt: the Fusion window opens. 3 of the same monster with the
-- same grade (from the backpack, not the pen) + 1 Fusion Ticket -> 1 of
-- the next grade. It keeps the best size, finish, kg and level of the 3.
--------------------------------------------------------------------
local FusionService = {}
local MACHINE_XZ = Vector2.new(35, -578)
local USE_RANGE = 30

local deps
local machinePos

local function sizeRank(key)
	for i, v in ipairs(Config.SizeVariants) do
		if v.key == key then
			return i
		end
	end
	return 1
end
local function finishRank(key)
	-- rarer finish (smaller weight) = better
	local f = Config.GetFinishVariant(key or "Normal")
	return f and (1 / math.max(f.weight, 1e-9)) or 0
end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	if shape then
		p.Shape = shape
	end
	for _, f in ipairs({ "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }) do
		p[f] = Enum.SurfaceType.Studs
	end
	p.Parent = parent
	return p
end

local function buildMachine()
	local world = workspace:WaitForChild("MonsterRNGWorld", 60)
	if not world then
		return
	end
	-- the ground under the spot
	local y = 1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	local hit = workspace:Raycast(Vector3.new(MACHINE_XZ.X, 300, MACHINE_XZ.Y), Vector3.new(0, -600, 0), params)
	if hit then
		y = hit.Position.Y
	end
	local base = CFrame.new(MACHINE_XZ.X, y, MACHINE_XZ.Y) * CFrame.Angles(0, math.rad(180), 0)
	machinePos = base.Position
	local model = Instance.new("Model")
	model.Name = "FusionMachine"
	local DARK = Color3.fromRGB(60, 52, 80)
	local GOLD = Color3.fromRGB(255, 200, 60)
	local GLOW = Color3.fromRGB(190, 110, 255)
	part(model, "Base", Vector3.new(16, 1.4, 16), base * CFrame.new(0, 0.7, 0), Color3.fromRGB(205, 165, 105))
	part(model, "Step", Vector3.new(11, 1, 11), base * CFrame.new(0, 1.9, 0), DARK)
	-- three pedestals (the 3 pets go in) around the middle
	for i = 0, 2 do
		local a = math.rad(i * 120 + 90)
		local at = base * CFrame.new(math.cos(a) * 4, 3.2, math.sin(a) * 4)
		part(model, "Pedestal", Vector3.new(1.8, 1.6, 1.8), at, GOLD)
		part(model, "PedestalOrb", Vector3.new(1.2, 1.2, 1.2), at * CFrame.new(0, 1.4, 0), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	end
	-- the core: a glowing orb in a ring, between two pillars
	part(model, "Pillar", Vector3.new(1.6, 11, 1.6), base * CFrame.new(-6.5, 7, 0), DARK)
	part(model, "Pillar", Vector3.new(1.6, 11, 1.6), base * CFrame.new(6.5, 7, 0), DARK)
	part(model, "Beam", Vector3.new(14.6, 1.4, 1.8), base * CFrame.new(0, 13, 0), GOLD)
	local core = part(model, "Core", Vector3.new(3.2, 3.2, 3.2), base * CFrame.new(0, 7.5, 0), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	local ring = part(model, "Ring", Vector3.new(0.6, 6, 6), base * CFrame.new(0, 7.5, 0), GOLD, Enum.Material.Plastic, Enum.PartType.Cylinder)
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 18
	light.Brightness = 2
	light.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(GLOW, Color3.fromRGB(255, 220, 255))
	sparks.LightEmission = 1
	sparks.Rate = 8
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Parent = core
	-- sign
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 60)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = core
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "FUSION MACHINE"
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(230, 190, 255)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(20, 10, 40)
	t.Parent = bb
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusionPrompt"
	prompt.ObjectText = "Fusion Machine"
	prompt.ActionText = "Fuse"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	model.Parent = world
	-- the ring turns
	task.spawn(function()
		local a = 0
		while ring.Parent do
			a += 0.06
			ring.CFrame = base * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(a * 0.6, 0, 0)
			task.wait(0.05)
		end
	end)
end

local function fuse(player, uids)
	local profile = deps.DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not machinePos or not hrp or (hrp.Position - machinePos).Magnitude > USE_RANGE then
		return { success = false, message = "Go to the Fusion Machine in the Desert to fuse." }
	end
	if type(uids) ~= "table" or #uids ~= 3 then
		return { success = false, message = "Pick 3 pets." }
	end
	if (profile.items.fusionTicket or 0) < 1 then
		return { success = false, message = "You need a Fusion Ticket (bosses drop them)." }
	end
	-- the 3 pets must be in the backpack, different, same monster + grade
	local picked, indexes = {}, {}
	for _, uid in ipairs(uids) do
		if type(uid) ~= "string" or indexes[uid] then
			return { success = false, message = "Pick 3 different pets." }
		end
		for i, e in ipairs(profile.monsters) do
			if e.uid == uid then
				indexes[uid] = i
				table.insert(picked, e)
			end
		end
		if not indexes[uid] then
			return { success = false, message = "Only pets in your backpack can be fused (not in your pen)." }
		end
	end
	local first = picked[1]
	local grade = first.grade or "E"
	for _, e in ipairs(picked) do
		if e.monsterId ~= first.monsterId or (e.grade or "E") ~= grade then
			return { success = false, message = "The 3 pets must be the same monster with the same grade." }
		end
	end
	local gi = Config.GradeIndex(grade)
	if gi >= #Config.Grades then
		return { success = false, message = "That pet is already the best grade (SSS)!" }
	end
	local nextGrade = Config.Grades[gi + 1].key
	local cost = Config.FusionCosts[nextGrade] or { chance = 1, shards = 0 }
	if (profile.riftShards or 0) < cost.shards then
		return { success = false, message = "You need " .. Config.FormatNumber(cost.shards) .. " Rift Shards to fuse into Grade " .. nextGrade .. "." }
	end
	-- the ticket + shards are used either way
	profile.items.fusionTicket -= 1
	if profile.items.fusionTicket <= 0 then
		profile.items.fusionTicket = nil
	end
	profile.riftShards -= cost.shards
	if math.random() > cost.chance then
		-- failed: the 3 pets stay in the backpack
		deps.sync(player)
		task.spawn(deps.DataService.Save, player)
		return { success = false, failed = true, message = "Fusion FAILED! The ticket and " .. Config.FormatNumber(cost.shards) .. " shards are gone. Your pets are safe in your backpack." }
	end
	-- the result keeps the best of the three
	local bestSize, bestFinish, bestKg, bestLevel = "Normal", "Normal", 0, 1
	for _, e in ipairs(picked) do
		if sizeRank(e.size) > sizeRank(bestSize) then
			bestSize = e.size
		end
		if finishRank(e.finish) > finishRank(bestFinish) then
			bestFinish = e.finish
		end
		bestKg = math.max(bestKg, e.kg or 0)
		bestLevel = math.max(bestLevel, e.level or 1)
	end
	-- remove the 3 (highest index first)
	local idx = {}
	for _, i in pairs(indexes) do
		table.insert(idx, i)
	end
	table.sort(idx, function(a, b)
		return a > b
	end)
	for _, i in ipairs(idx) do
		table.remove(profile.monsters, i)
	end
	profile.owned[first.monsterId] = math.max(1, (profile.owned[first.monsterId] or 3) - 2)
	local result = {
		uid = HttpService:GenerateGUID(false),
		monsterId = first.monsterId,
		size = bestSize,
		finish = bestFinish,
		grade = nextGrade,
		kg = bestKg > 0 and bestKg or nil,
		level = bestLevel,
		xp = 0,
	}
	table.insert(profile.monsters, result)
	deps.DataService.RecordIndex(profile, result)
	deps.sync(player)
	task.spawn(deps.DataService.Save, player)
	local m = Config.GetMonster(result.monsterId)
	return { success = true, message = "Fused! Grade " .. result.grade .. " " .. Config.BuildDisplayName(m and m.name or "Pet", result.size, result.finish) .. "!", result = result }
end

function FusionService.Start(d)
	deps = d
	local remote = d.getRemote("Fuse", "RemoteFunction")
	local busy = {}
	remote.OnServerInvoke = function(player, uids)
		if busy[player] then
			return { success = false, message = "One moment..." }
		end
		busy[player] = true
		local ok, r = pcall(fuse, player, uids)
		busy[player] = nil
		if not ok then
			warn("[Fusion] " .. tostring(r))
			return { success = false, message = "Something went wrong, try again." }
		end
		return r
	end
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
	task.spawn(buildMachine)
end

return FusionService
