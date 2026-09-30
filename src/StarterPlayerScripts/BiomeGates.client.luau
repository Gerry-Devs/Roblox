local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local unlockRemote = remotes:WaitForChild("UnlockBiome")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")

--------------------------------------------------------------------
-- Biome gates: a force-field gate across the entrance of every locked
-- biome, with a lock sign and an Unlock prompt. Built only on this
-- player's screen, so it disappears just for them once unlocked (the
-- server also pushes anyone out of biomes they haven't unlocked).
-- Prices / order: Config.Biomes (cost). Unlock in order, Forest first.
--------------------------------------------------------------------

local GROUND = 1
local OUTLINE = Color3.fromRGB(10, 15, 35)
local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local profile = profileRemote:InvokeServer()
local folder = Instance.new("Folder")
folder.Name = "BiomeGates"
folder.Parent = workspace
local gates = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(parent, name, size, cf, color, material, transparency, studs)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if studs then
		for _, f in ipairs(STUD_FACES) do
			p[f] = Enum.SurfaceType.Studs
		end
	end
	p.Parent = parent
	return p
end

local function label(parent, name, text, y, h, color, maxSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = UDim2.new(1, 0, h, 0)
	l.Position = UDim2.fromScale(0, y)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = OUTLINE
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

local function isUnlocked(key)
	return profile and profile.unlockedBiomes and profile.unlockedBiomes[key] == true
end

local function previousOf(index)
	local prev = Config.Biomes[index - 1]
	if prev and prev.cost then
		return prev
	end
	return nil
end

local function flashNote(gate, text, color)
	gate.note.Text = text
	gate.note.TextColor3 = color
	local token = {}
	gate.noteToken = token
	task.delay(2.5, function()
		if gate.noteToken == token and gate.model.Parent then
			gate.refreshNote()
		end
	end)
end

local busy = false
local refresh

local function tryUnlock(biome)
	if busy then
		return
	end
	busy = true
	local ok, response = pcall(function()
		return unlockRemote:InvokeServer(biome.key)
	end)
	busy = false
	local gate = gates[biome.key]
	if ok and response then
		if response.profile then
			profile = response.profile
		end
		if gate then
			flashNote(gate, response.message or "", response.success and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 110, 110))
		end
		if response.success then
			refresh()
		end
	end
end

local function buildGate(index, biome)
	local model = Instance.new("Model")
	model.Name = "Gate_" .. biome.key
	local cx = biome.center.X
	local z = biome.center.Y + biome.size.Y / 2 -- entrance edge (the side you come from)
	local half = biome.size.X / 2 - 48 -- between the side mountains
	local color = rgb(biome.color)
	local m = biome.mountain
	local pillarColor = m and rgb(m.dirt[1]) or Color3.fromRGB(120, 110, 100)
	local capColor = m and rgb(m.cap[1]) or Color3.fromRGB(200, 200, 200)

	-- one solid, studded wall across the whole biome, tall enough that the
	-- camera can't look over it into the locked biome
	local WALL_H = 44 -- same height as the mountains
	local W = biome.size.X
	local V, CF, G = Vector3.new, CFrame.new, GROUND
	local stone, trim = pillarColor, capColor
	local dark = stone:Lerp(Color3.new(0, 0, 0), 0.35)
	local gold = Color3.fromRGB(255, 200, 60)
	local wood = Color3.fromRGB(110, 70, 40)
	local NEON = Enum.Material.Neon

	-- wall with a darker base, trim on top and battlements
	part(model, "Wall", V(W, WALL_H, 4), CF(cx, G + WALL_H / 2, z), stone, nil, 0, true)
	part(model, "Plinth", V(W, 4, 6), CF(cx, G + 2, z), dark, nil, 0, true)
	part(model, "TopTrim", V(W, 2, 6), CF(cx, G + WALL_H - 1, z), trim, nil, 0, true)
	for x = -W / 2 + 5, W / 2 - 5, 10 do
		part(model, "Merlon", V(5, 4, 6), CF(cx + x, G + WALL_H + 2, z), trim, nil, 0, true)
	end
	-- buttresses along the wall
	for x = -W / 2 + 30, W / 2 - 30, 60 do
		if math.abs(x) > 45 then
			part(model, "Buttress", V(6, WALL_H - 8, 4), CF(cx + x, G + (WALL_H - 8) / 2, z + 4), dark, nil, 0, true)
		end
	end
	-- gatehouse: two towers, arch, big door with iron bands, gold lock
	for _, s in ipairs({ -1, 1 }) do
		part(model, "GateTower", V(14, WALL_H + 10, 12), CF(cx + s * 20, G + (WALL_H + 10) / 2, z + 2), stone, nil, 0, true)
		part(model, "TowerCap", V(16, 3, 14), CF(cx + s * 20, G + WALL_H + 11.5, z + 2), trim, nil, 0, true)
		for _, mx in ipairs({ -5, 0, 5 }) do
			part(model, "Merlon", V(3, 3, 3), CF(cx + s * 20 + mx, G + WALL_H + 14.5, z + 7.5), trim, nil, 0, true)
		end
		part(model, "TowerWindow", V(4, 6, 0.4), CF(cx + s * 20, G + WALL_H - 4, z + 8.2), color, NEON)
		-- banners in the biome color
		part(model, "Banner", V(8, 18, 0.4), CF(cx + s * 75, G + WALL_H - 12, z + 2.3), color)
		part(model, "BannerTrim", V(9, 1.5, 0.6), CF(cx + s * 75, G + WALL_H - 2.5, z + 2.4), gold)
		part(model, "BannerEmblem", V(3.5, 3.5, 0.5), CF(cx + s * 75, G + WALL_H - 11, z + 2.6), gold, NEON)
		-- torches by the door
		part(model, "TorchStick", V(1, 5, 1), CF(cx + s * 11.5, G + 12, z + 3.2), wood)
		local flame = part(model, "TorchFlame", V(1.6, 1.6, 1.6), CF(cx + s * 11.5, G + 15.3, z + 3.2), Color3.fromRGB(255, 150, 40), NEON)
		flame.CanCollide = false
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = flame
	end
	part(model, "Arch", V(26, 4, 7), CF(cx, G + 30, z + 1), trim, nil, 0, true)
	part(model, "Door", V(20, 26, 1), CF(cx, G + 14, z + 2.5), wood)
	for _, dy in ipairs({ 5, 14, 23 }) do
		part(model, "DoorBand", V(20.4, 1, 1.2), CF(cx, G + dy, z + 2.6), dark)
	end
	part(model, "DoorSeam", V(0.5, 26, 1.2), CF(cx, G + 14, z + 2.6), dark)
	part(model, "LockPlate", V(6, 7, 0.6), CF(cx, G + 14, z + 3.1), gold, NEON)

	-- lock sign (only shows when you're near the wall)
	local signAnchor = part(model, "SignAnchor", Vector3.new(1, 1, 1), CFrame.new(cx, GROUND + 36, z + 6), color, nil, 1)
	signAnchor.CanCollide = false
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(440, 140)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.Parent = signAnchor
	label(bb, "Title", "\u{1F512} " .. biome.name, 0, 0.46, color, 48)
	label(bb, "Price", "$" .. Config.FormatNumber(biome.cost), 0.46, 0.3, Color3.fromRGB(255, 205, 93), 36)
	local note = label(bb, "Note", "", 0.76, 0.24, Color3.new(1, 1, 1), 24)

	-- unlock prompts spread along the gate
	for _, x in ipairs({ -half * 0.6, 0, half * 0.6 }) do
		local anchor = part(model, "PromptAnchor", Vector3.new(1, 1, 1), CFrame.new(cx + x, GROUND + 5, z + 4), color, nil, 1)
		anchor.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UnlockPrompt"
		prompt.ActionText = "Unlock"
		prompt.ObjectText = biome.name .. "  $" .. Config.FormatNumber(biome.cost)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function()
			tryUnlock(biome)
		end)
	end

	local gate = { model = model, note = note, index = index }
	gate.refreshNote = function()
		local prev = previousOf(index)
		if prev and not isUnlocked(prev.key) then
			note.Text = "Unlock " .. prev.name .. " first"
			note.TextColor3 = Color3.fromRGB(255, 150, 150)
		else
			note.Text = isTouch and "Tap UNLOCK to open" or "Press E to unlock"
			note.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	gate.refreshNote()
	model.Parent = folder
	gates[biome.key] = gate
end

-- unlocked gate: fade the field out, sink the gate, then remove it
local function openGate(key)
	local gate = gates[key]
	if not gate then
		return
	end
	gates[key] = nil
	for _, p in ipairs(gate.model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			TweenService:Create(p, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				CFrame = p.CFrame - Vector3.new(0, p.Size.Y + 5, 0),
			}):Play()
		elseif p:IsA("BillboardGui") or p:IsA("ProximityPrompt") then
			p.Enabled = false
		end
	end
	task.delay(2.1, function()
		gate.model:Destroy()
	end)
end

refresh = function()
	for index, biome in ipairs(Config.Biomes) do
		if biome.cost then
			if isUnlocked(biome.key) then
				openGate(biome.key)
			elseif not gates[biome.key] then
				buildGate(index, biome)
			else
				gates[biome.key].refreshNote()
			end
		end
	end
end

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	refresh()
end)

refresh()
