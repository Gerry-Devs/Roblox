local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

--------------------------------------------------------------------
-- Loot on the ground: when your pets kill an enemy, its drops (Rift
-- Shards / potions, LootModel) fly out of it in an arc and land around
-- it, then bob and spin. Walk within Config.Loot.pickupRange and they
-- fly into you and go to your backpack (the server checks it:
-- PickupLoot). Only you see your own loot. Gone after lifetime seconds.
--------------------------------------------------------------------
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local LootModel = require(folder:WaitForChild("LootModel"))
local remotes = folder:WaitForChild("Remotes")
local fxRemote = remotes:WaitForChild("CombatFx")
local pickupRemote = remotes:WaitForChild("PickupLoot")

local L = Config.Loot
local FLIGHT_TIME = 0.75
local HOVER = 1.5 -- studs above the ground
local MAX_LOOT = 40 -- on screen at once (oldest goes first)
local OUTLINE = Color3.fromRGB(10, 15, 35)

local lootFolder = Instance.new("Folder")
lootFolder.Name = "MyLoot"
lootFolder.Parent = workspace

local rng = Random.new()
local active = {} -- list of loot entries

-- where the ground is under a point (ignores characters, pets, enemies)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos, fallback)
	local ignore = { lootFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), rayParams)
	return hit and hit.Position.Y or fallback
end

local function lootText(d)
	if d.kind == "shards" then
		return "+" .. (d.amount or 1) .. " Rift Shard" .. ((d.amount or 1) == 1 and "" or "s"), Color3.fromRGB(150, 190, 255), Config.RiftShardImage
	end
	if d.kind == "item" then
		local it = Config.Items[d.key]
		return "+1 " .. (it and it.name or "Item"), Color3.fromRGB(230, 190, 255), it and it.imageId
	end
	local p = Config.GetPotion(d.key)
	return "+1 " .. (p and p.name or "Potion"), Color3.fromRGB(255, 215, 90), p and p.imageId
end

-- "+1 Luck Potion" rising over your head
local function pickupPopup(d)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local text, color, icon = lootText(d)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 30)
	bb.StudsOffset = Vector3.new(0, 2.5 + rng:NextNumber(0, 0.6), 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = head
	local row = Instance.new("Frame")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = bb
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local img
	if icon and icon ~= "" then
		img = Instance.new("ImageLabel")
		img.Size = UDim2.fromOffset(26, 26)
		img.BackgroundTransparency = 1
		img.Image = icon
		img.Parent = row
	end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromOffset(0, 26)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = 20
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = OUTLINE
	l.Parent = row
	TweenService:Create(bb, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	task.delay(0.9, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		if img then
			TweenService:Create(img, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
		end
	end)
	Debris:AddItem(bb, 1.5)
end

local function pickupSound()
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.Volume = 0.35
	s.PlaybackSpeed = rng:NextNumber(1.1, 1.3)
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 2)
end

local function removeEntry(e)
	local i = table.find(active, e)
	if i then
		table.remove(active, i)
	end
	if e.model then
		e.model:Destroy()
	end
end

local function spawnLoot(d, from)
	if #active >= MAX_LOOT then
		removeEntry(active[1])
	end
	local ok, model = pcall(LootModel.Build, d.kind, d.key)
	if not ok or not model then
		return
	end
	-- a bigger shard pile looks a bit bigger
	local size = d.kind == "shards" and math.clamp(0.8 + (d.amount or 1) * 0.04, 0.8, 1.4) or 0.85
	pcall(function()
		model:ScaleTo(size)
	end)
	local ang = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(4, 7.5)
	local land = from + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
	land = Vector3.new(land.X, groundY(land, from.Y - 2) + HOVER * size, land.Z)
	local start = from + Vector3.new(0, 2, 0)
	model:PivotTo(CFrame.new(start))
	model.Parent = lootFolder
	table.insert(active, {
		drop = d,
		model = model,
		start = start,
		land = land,
		born = os.clock(),
		peak = rng:NextNumber(5, 8),
		spin = rng:NextNumber(2.5, 4) * (rng:NextNumber() < 0.5 and -1 or 1),
		phase = rng:NextNumber(0, math.pi * 2),
		state = "flying",
		size = size,
	})
end

fxRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.kind ~= "kill" or typeof(data.position) ~= "Vector3" then
		return
	end
	for i, d in ipairs(data.drops or {}) do
		if type(d.id) == "number" then
			-- a tiny delay between drops so they burst out one after another
			task.delay((i - 1) * 0.08, spawnLoot, d, data.position)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	for i = #active, 1, -1 do
		local e = active[i]
		if not e.model.Parent then
			table.remove(active, i)
			continue
		end
		local age = now - e.born
		if e.state == "flying" then
			-- an arc out of the enemy, spinning, landing on the ground
			local t = math.min(1, age / FLIGHT_TIME)
			local pos = e.start:Lerp(e.land, t) + Vector3.new(0, math.sin(t * math.pi) * e.peak, 0)
			e.model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 6, age * 8, 0))
			if t >= 1 then
				e.state = "ground"
				e.landedAt = now
			end
		elseif e.state == "ground" then
			-- bob + spin, waiting for you
			local bob = math.sin((now + e.phase) * 2.6) * 0.25
			e.model:PivotTo(CFrame.new(e.land + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * e.spin * 0.5 + e.phase, 0))
			if hrp and (hrp.Position - e.land).Magnitude <= L.pickupRange and now - e.landedAt > 0.15 then
				e.state = "collecting"
				e.from = e.model:GetPivot().Position
				e.collectAt = now
			elseif age > L.lifetime then
				removeEntry(e)
			end
		elseif e.state == "collecting" then
			-- flies into you (speeding up, shrinking)
			local t = math.min(1, (now - e.collectAt) / 0.3)
			local target = hrp and hrp.Position or e.from
			local pos = e.from:Lerp(target, t * t) + Vector3.new(0, math.sin(t * math.pi) * 1.5, 0)
			e.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, now * 12, 0))
			pcall(function()
				e.model:ScaleTo(math.max(0.2, e.size * (1 - t * 0.7)))
			end)
			if t >= 1 then
				pickupRemote:FireServer(e.drop.id)
				pickupPopup(e.drop)
				pickupSound()
				removeEntry(e)
			end
		end
	end
end)
