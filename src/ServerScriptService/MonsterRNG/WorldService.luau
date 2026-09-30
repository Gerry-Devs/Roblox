local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SELLER_USER_ID = 1165846861 -- the Sell stall NPC wears this player's avatar
local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
local justHatched = {} -- uid -> os.clock() of the moment it popped out

local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

local WorldService = {}
local world
local allPens = {}
local pensByPlayer = {}
local buildAllPens

--------------------------------------------------------------------
-- Layout constants
--------------------------------------------------------------------

local PEN_HALF_X = 35
local PEN_HALF_Z = 28
local PEN_RADIUS = 70 -- how close the owner must be for their pets to roam freely
local WANDER_HALF = Vector3.new(PEN_HALF_X - 5, 0, PEN_HALF_Z - 5)
local FOLLOW_DISTANCE = 8

-- Pen 1 sits behind the Sell stall and Pen 6 behind the Dice Shop, the
-- same 47-stud gap from the plaza as the four front pens have.
local basePositions = {
	Vector3.new(-137, 1, 0),
	Vector3.new(-150, 1, 130),
	Vector3.new(-50, 1, 130),
	Vector3.new(50, 1, 130),
	Vector3.new(150, 1, 130),
	Vector3.new(137, 1, 0),
}

-- Gate side per pen ("-Z" = toward the spawn/plaza for the front row).
-- The side pens open toward the shops in the middle.
local PEN_GATES = { [1] = "+X", [6] = "-X" }

--------------------------------------------------------------------
-- Basic build helpers
--------------------------------------------------------------------

local function makePart(parent, name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material or Enum.Material.Plastic
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function addSign(parent, text, position, color)
	local signPart = makePart(
		parent,
		"Sign",
		Vector3.new(15, 4, 0.5),
		CFrame.new(position),
		Color3.fromRGB(13, 18, 37),
		Enum.Material.Plastic
	)
	signPart.CanCollide = false

	local billboard = Instance.new("SurfaceGui")
	billboard.Face = Enum.NormalId.Front
	billboard.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	billboard.PixelsPerStud = 35
	billboard.Parent = signPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Parent = billboard
end

local function addStudFloor(parent, name, size, cframe, baseColor)
	local floor = makePart(parent, name, size, cframe, baseColor, Enum.Material.Plastic)
	return floor
end

local function addBush(parent, position)
	local bush = makePart(
		parent,
		"Bush",
		Vector3.new(4.5, 3.2, 4.5),
		CFrame.new(position + Vector3.new(0, 1.6, 0)),
		Color3.fromRGB(70, 178, 84),
		Enum.Material.Plastic
	)
	bush.Shape = Enum.PartType.Ball
	bush.CanCollide = false
end

local function addFlower(parent, position, color)
	local stem = makePart(
		parent,
		"Stem",
		Vector3.new(0.3, 1.4, 0.3),
		CFrame.new(position + Vector3.new(0, 0.7, 0)),
		Color3.fromRGB(80, 160, 90),
		Enum.Material.Plastic
	)
	stem.CanCollide = false
	local bloom = makePart(
		parent,
		"Bloom",
		Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(position + Vector3.new(0, 1.5, 0)),
		color,
		Enum.Material.Plastic
	)
	bloom.Shape = Enum.PartType.Ball
	bloom.CanCollide = false
end

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(90, 90, 95)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 105)
	Lighting.Brightness = 2
	Lighting.ClockTime = 13
	Lighting.FogColor = Color3.fromRGB(190, 215, 230)
	Lighting.FogEnd = 1800
	Lighting.FogStart = 650

	local oldBloom = Lighting:FindFirstChild("MonsterRNGBloom")
	if oldBloom then
		oldBloom:Destroy()
	end
	local oldSoftBloom = Lighting:FindFirstChild("MonsterRNGSoftBloom")
	if oldSoftBloom then
		oldSoftBloom:Destroy()
	end
	local oldStars = Lighting:FindFirstChild("MonsterRNGStars")
	if oldStars then
		oldStars:Destroy()
	end

	local colorCorrection = Lighting:FindFirstChild("MonsterRNGColor")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "MonsterRNGColor"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Saturation = 0.02
	colorCorrection.Contrast = 0.06
	colorCorrection.Brightness = -0.03
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
end

--------------------------------------------------------------------
-- Central hub: physical stations you walk up to and press E / tap
--------------------------------------------------------------------

local function buildStall(parent, name, offset, color, objectText, actionText)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local base = makePart(
		model,
		"Base",
		Vector3.new(10, 6, 10),
		CFrame.new(offset + Vector3.new(0, 3, 0)),
		color,
		Enum.Material.Plastic
	)

	local topper = makePart(
		model,
		"Topper",
		Vector3.new(4.5, 4.5, 4.5),
		CFrame.new(offset + Vector3.new(0, 8.5, 0)),
		color,
		Enum.Material.Plastic
	)
	topper.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 0.8
	light.Parent = topper

	addSign(model, name:upper(), offset + Vector3.new(0, 13.5, -5.1), Color3.fromRGB(240, 240, 255))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base

	model.PrimaryPart = base
	return model
end

local function stallPart(model, name, size, cf, color, material)
	local p = makePart(model, name, size, cf, color, material or Enum.Material.Plastic)
	return p
end

-- Cartoony Sell stall: counter, back wall, striped awning, gold SELL sign,
-- coin stacks. Faces the plaza center. The NPC stands on NPCSpot.
local function buildMerchantStall(hub, modelName, offset, labelText, stripeColor, objectText, actionText, promptName)
	local model = Instance.new("Model")
	model.Name = modelName
	model.Parent = hub

	local origin = CFrame.lookAt(offset, offset + Vector3.new(-offset.X, 0, -offset.Z).Unit)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end

	local WOOD = Color3.fromRGB(165, 110, 62)
	local WOOD_LIGHT = Color3.fromRGB(215, 160, 95)
	local WOOD_DARK = Color3.fromRGB(120, 78, 45)
	local GOLD = Color3.fromRGB(255, 200, 60)
	local RED = stripeColor or Color3.fromRGB(230, 60, 60)

	local counter = stallPart(model, "Counter", Vector3.new(12, 2.4, 3), at(0, 1.2, -2), WOOD)
	stallPart(model, "CounterTop", Vector3.new(13, 0.5, 3.6), at(0, 2.65, -2), WOOD_LIGHT)
	stallPart(model, "CounterBand", Vector3.new(12.2, 0.7, 0.2), at(0, 1.5, -3.55), GOLD)
	stallPart(model, "BackWall", Vector3.new(13.4, 11.4, 1), at(0, 5.7, 4.2), WOOD_DARK)
	-- side walls close the gap between the front and back posts
	for _, x in ipairs({ -6.3, 6.3 }) do
		stallPart(model, "SideWall", Vector3.new(0.6, 9.3, 7.4), at(x, 4.65, 0.5), WOOD_DARK)
		-- wedge on top follows the awning's slope so there's no gap under the roof
		local top = Instance.new("WedgePart")
		top.Name = "SideWallTop"
		top.Anchored = true
		top.Size = Vector3.new(0.6, 2.1, 7.4)
		top.CFrame = at(x, 9.3 + 1.05 - 0.05, 0.5)
		top.Color = WOOD_DARK
		top.Material = Enum.Material.Plastic
		top.TopSurface = Enum.SurfaceType.Smooth
		top.BottomSurface = Enum.SurfaceType.Smooth
		top.Parent = model
	end
	for _, x in ipairs({ -6.3, 6.3 }) do
		for _, z in ipairs({ -3.2, 4.2 }) do
			-- back posts are taller: the awning slopes up toward the back
			local h = z > 0 and 11.6 or 10
			stallPart(model, "Post", Vector3.new(0.8, h, 0.8), at(x, h / 2, z), WOOD)
		end
	end
	-- striped awning, tilted down toward the front
	for i = 0, 5 do
		local stripe = stallPart(model, "Awning", Vector3.new(2.25, 0.4, 9),
			at(-5.625 + i * 2.25, 10.4, 0.4) * CFrame.Angles(math.rad(-14), 0, 0),
			(i % 2 == 0) and RED or Color3.new(1, 1, 1))
		stripe.CanCollide = false
	end
	stallPart(model, "AwningTrim", Vector3.new(13.6, 0.8, 0.5), at(0, 9.3, -4.1), RED).CanCollide = false

	-- coin stacks on the counter
	for i, spot in ipairs({ Vector3.new(-4.4, 0, -2.2), Vector3.new(-3.2, 0, -1.6), Vector3.new(4.2, 0, -2) }) do
		for c = 1, 2 + i do
			local coin = stallPart(model, "Coin", Vector3.new(0.3, 1.1, 1.1),
				at(spot.X, 2.9 + (c - 1) * 0.3, spot.Z) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal)
			coin.Shape = Enum.PartType.Cylinder
			coin.CanCollide = false
		end
	end

	local spot = stallPart(model, "NPCSpot", Vector3.new(2, 0.2, 2), at(0, 0.1, 1.6), WOOD, Enum.Material.Plastic)
	spot.Transparency = 1
	spot.CanCollide = false

	-- fallback prompt on the counter (moved onto the NPC once it spawns)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = counter

	model.PrimaryPart = counter
	return model
end

local function buildSellStall(hub, offset)
	return buildMerchantStall(hub, "SellStall", offset, "SELL", Color3.fromRGB(230, 60, 60), "Kaiden", "Sell", "SellPrompt")
end

local function buildDiceStall(hub, offset)
	return buildMerchantStall(hub, "DiceStall", offset, "DICE SHOP", Color3.fromRGB(70, 140, 255), "Scripter", "Shop", "DicePrompt")
end

-- Classic "bacon hair" look for the Dice Shop NPC.
local function baconDescription(withClothes)
	local d = Instance.new("HumanoidDescription")
	d.HairAccessory = "63690008" -- Pal Hair
	if withClothes then
		d.Shirt = 144076358 -- Blue and Black Motorcycle Shirt
		d.Pants = 144076760 -- Dark Green Jeans
	end
	local skin = Color3.fromRGB(234, 184, 146)
	d.HeadColor, d.TorsoColor = skin, skin
	d.LeftArmColor, d.RightArmColor = skin, skin
	d.LeftLegColor, d.RightLegColor = skin, skin
	return d
end

-- Spawns a shop NPC behind a stall counter. `source` is a UserId (wears
-- that player's avatar) or a function returning a HumanoidDescription.
-- Runtime only.
local function spawnMerchantNpc(stall, source, displayName, promptName)
	if not RunService:IsRunning() then
		return
	end
	local spot = stall:FindFirstChild("NPCSpot")
	if not spot then
		return
	end
	local old = stall:FindFirstChild(displayName)
	if old then
		old:Destroy()
	end
	task.spawn(function()
		local ok, npc
		if type(source) == "number" then
			ok, npc = pcall(function()
				return Players:CreateHumanoidModelFromUserId(source)
			end)
		else
			ok, npc = pcall(function()
				return Players:CreateHumanoidModelFromDescription(source(true), Enum.HumanoidRigType.R15)
			end)
			if not ok then
				ok, npc = pcall(function()
					return Players:CreateHumanoidModelFromDescription(source(false), Enum.HumanoidRigType.R15)
				end)
			end
		end
		if not ok or not npc then
			warn("Monster RNG: couldn't load NPC " .. displayName .. ":", npc)
			return
		end
		npc.Name = displayName
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local root = npc:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then
			npc:Destroy()
			return
		end
		-- normal Roblox name above the head (same size as players' names), no health bar
		humanoid.DisplayName = displayName
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.NameDisplayDistance = 50
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local height = humanoid.RigType == Enum.HumanoidRigType.R6 and 3 or (humanoid.HipHeight + root.Size.Y / 2)
		root.Anchored = true
		npc:PivotTo(spot.CFrame * CFrame.new(0, height, 0))
		npc.Parent = stall

		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15 and "rbxassetid://507766666" or "rbxassetid://180435571"
		pcall(function()
			local track = animator:LoadAnimation(anim)
			track.Looped = true
			track:Play()
		end)

		local prompt = stall:FindFirstChild(promptName, true)
		if prompt then
			prompt.Parent = root
		end

	end)
end

-- Two-tone checker tiles over the grass. Tiles sit just under the
-- plaza / road / pen floors so they never poke through them.
local TILE_SIZE = 8
local TILE_LIGHT = Color3.fromRGB(118, 201, 94)
local TILE_DARK = Color3.fromRGB(96, 178, 76)

local function ensureGroundTiles(world)
	local island = world:FindFirstChild("Island")
	if not island or world:FindFirstChild("GroundTiles") then
		return
	end
	island.Color = TILE_LIGHT
	island.Material = Enum.Material.Plastic
	island.TopSurface = Enum.SurfaceType.Studs
	local tiles = Instance.new("Model")
	tiles.Name = "GroundTiles"
	tiles.Parent = world
	local top = island.Position.Y + island.Size.Y / 2
	local nx = math.floor(island.Size.X / TILE_SIZE)
	local nz = math.floor(island.Size.Z / TILE_SIZE)
	local x0 = island.Position.X - island.Size.X / 2
	local z0 = island.Position.Z - island.Size.Z / 2
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			do
				local tile = Instance.new("Part")
				tile.Name = "Tile"
				tile.Anchored = true
				tile.CanCollide = false
				tile.CanQuery = false
				tile.CanTouch = false
				tile.CastShadow = false
				tile.Material = Enum.Material.Plastic
				tile.Color = (i + j) % 2 == 1 and TILE_DARK or TILE_LIGHT
				tile.TopSurface = Enum.SurfaceType.Studs
				tile.BottomSurface = Enum.SurfaceType.Smooth
				tile.Size = Vector3.new(TILE_SIZE, 0.2, TILE_SIZE)
				tile.Position = Vector3.new(x0 + (i + 0.5) * TILE_SIZE, top - 0.06, z0 + (j + 0.5) * TILE_SIZE)
				tile.Parent = tiles
			end
		end
	end
end

-- Blocky mountain range along the back edge: studded dirt columns with
-- a grass cap, checkered like the floor and taller toward the back.
local function ensureMountain(world)
	if world:FindFirstChild("Mountain") then
		return
	end
	local island = world:FindFirstChild("Island")
	if not island then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Mountain"
	model.Parent = world

	local DIRT = { Color3.fromRGB(135, 90, 52), Color3.fromRGB(118, 78, 45) }
	local GRASS = { Color3.fromRGB(118, 201, 94), Color3.fromRGB(96, 178, 76) }
	local COL = 16
	local GRASS_H = 3
	local BACK_ROWS = { 42, 32, 22, 12 } -- heights from the back edge inward
	local SIDE_COLS = { 40, 28, 14 } -- heights from each side edge inward

	local ground = island.Position.Y + island.Size.Y / 2
	local halfX = island.Size.X / 2
	local frontZ = island.Position.Z - island.Size.Z / 2
	local cols = math.floor(island.Size.X / COL)
	local rows = math.floor(island.Size.Z / COL)

	local function studs(p)
		for _, face in ipairs(STUD_FACES) do
			p[face] = Enum.SurfaceType.Studs
		end
	end

	-- every column takes the HIGHER of the back-range and side-range
	-- heights, so the corners merge into one solid ridge
	for i = 0, cols - 1 do
		local x = -halfX + (i + 0.5) * COL
		local fromSide = math.min(i, cols - 1 - i) + 1 -- 1 = outermost column
		local sideSign = x < 0 and -1 or 1
		for r = 0, rows - 1 do
			local z = frontZ + (r + 0.5) * COL
			local fromBack = rows - r -- 1 = back row
			local h = 0
			if fromBack <= #BACK_ROWS then
				local bump = 10 * math.sin(x / 37) + 7 * math.cos(x / 19 + fromBack * 1.7)
				h = math.max(h, BACK_ROWS[fromBack] + bump * (1.25 - fromBack * 0.2))
			end
			if fromSide <= #SIDE_COLS then
				local bump = 9 * math.sin(z / 29 + sideSign) + 6 * math.cos(z / 17 + fromSide)
				h = math.max(h, SIDE_COLS[fromSide] + bump * (1.2 - fromSide * 0.25))
			end
			if h > 0 then
				h = math.min(44, math.max(8, math.floor(h / 4 + 0.5) * 4)) -- same height as the gate walls
				local checker = ((i + r) % 2) + 1
				local dirt = makePart(model, "Dirt", Vector3.new(COL, h - GRASS_H, COL),
					CFrame.new(x, ground + (h - GRASS_H) / 2, z), DIRT[checker], Enum.Material.Plastic)
				studs(dirt)
				local grass = makePart(model, "Grass", Vector3.new(COL, GRASS_H, COL),
					CFrame.new(x, ground + h - GRASS_H / 2, z), GRASS[checker], Enum.Material.Plastic)
				studs(grass)
			end
		end
	end
end

--------------------------------------------------------------------
-- Map cleanup: no road, no PvP Arena / Dice Altar, round studded plaza.
--------------------------------------------------------------------
local function studsAll(p)
	for _, face in ipairs(STUD_FACES) do
		p[face] = Enum.SurfaceType.Studs
	end
end

local function ensureMapCleanup(world)
	local road = world:FindFirstChild("VerticalRoad")
	if road then
		road:Destroy()
	end
	local hub = world:FindFirstChild("Hub")
	if not hub then
		return
	end
	for _, n in ipairs({ "PvPArena", "DiceAltar" }) do
		local m = hub:FindFirstChild(n)
		if m then
			m:Destroy()
		end
	end
	-- round plaza made of thin studded strips (blocky circle)
	local plaza = hub:FindFirstChild("PlazaFloor")
	if plaza and plaza:IsA("BasePart") then
		local color, y, center = plaza.Color, plaza.Position.Y, plaza.Position
		plaza:Destroy()
		local circle = Instance.new("Model")
		circle.Name = "PlazaFloor"
		circle.Parent = hub
		local RADIUS, STRIP = 50, 2
		for zOff = -RADIUS + STRIP / 2, RADIUS - STRIP / 2, STRIP do
			local width = 2 * math.sqrt(math.max(0, RADIUS * RADIUS - zOff * zOff))
			width = math.floor(width / 2) * 2
			if width > 0 then
				local strip = makePart(circle, "PlazaStrip", Vector3.new(width, 0.6, STRIP),
					CFrame.new(center.X, y, center.Z + zOff), color, Enum.Material.Plastic)
				strip.TopSurface = Enum.SurfaceType.Studs
			end
		end
	end
end

-- Floating "(icon) Shop Name" title above a stall, and studs on its parts.
local function ensureStallTitle(stall, labelText, iconId)
	local oldSign = stall:FindFirstChild("Sign")
	if oldSign then
		oldSign:Destroy()
	end
	for _, p in ipairs(stall:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Coin" and p.Name ~= "NPCSpot" then
			studsAll(p)
		end
	end
	local anchor = stall:FindFirstChild("TitleAnchor")
	if not anchor then
		local counter = stall:FindFirstChild("Counter")
		if not counter then
			return
		end
		anchor = Instance.new("Part")
		anchor.Name = "TitleAnchor"
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CFrame = counter.CFrame * CFrame.new(0, 12, 1)
		anchor.Parent = stall

		local gui = Instance.new("BillboardGui")
		gui.Name = "StallTitle"
		gui.Size = UDim2.fromOffset(190, 42)
		gui.LightInfluence = 0
		gui.MaxDistance = 50
		gui.Parent = anchor

		local row = Instance.new("Frame")
		row.Name = "Row"
		row.Size = UDim2.fromScale(1, 1)
		row.BackgroundTransparency = 1
		row.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 8)
		layout.Parent = row

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.LayoutOrder = 1
		icon.Size = UDim2.fromOffset(38, 38)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = row

		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.LayoutOrder = 2
		label.Size = UDim2.fromOffset(0, 38)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy
		label.TextSize = 28
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
		label.Parent = row
	end
	local row = anchor.StallTitle.Row
	row.Title.Text = labelText
	row.Icon.Image = iconId or ""
	row.Icon.Visible = (iconId or "") ~= ""
end

--------------------------------------------------------------------
-- Biomes (see Config.Biomes): studded checker ground + blocky props.
--------------------------------------------------------------------
local BIOME_TILE = 8 -- same as the lobby floor

local function block(parent, name, size, cf, color, material, transparency)
	local p = makePart(parent, name, size, cf, color, material or Enum.Material.Plastic, transparency)
	studsAll(p)
	return p
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local BIOME_PROPS = {}

BIOME_PROPS.forest = function(model, rng, spot)
	local leaves = { Color3.fromRGB(60, 150, 60), Color3.fromRGB(45, 125, 50), Color3.fromRGB(85, 170, 70) }
	for _ = 1, 30 do
		local p = spot()
		local h = rng:NextInteger(8, 13)
		block(model, "Trunk", Vector3.new(2, h, 2), CFrame.new(p + Vector3.new(0, h / 2, 0)), Color3.fromRGB(110, 72, 40))
		local g = leaves[rng:NextInteger(1, 3)]
		block(model, "Leaves", Vector3.new(10, 6, 10), CFrame.new(p + Vector3.new(0, h + 2, 0)), g)
		block(model, "Leaves", Vector3.new(6, 4, 6), CFrame.new(p + Vector3.new(0, h + 7, 0)), g)
	end
	for _ = 1, 20 do
		block(model, "Bush", Vector3.new(4, 3, 4), CFrame.new(spot() + Vector3.new(0, 1.5, 0)), leaves[rng:NextInteger(1, 3)])
	end
	for _ = 1, 12 do
		local p = spot()
		block(model, "MushroomStem", Vector3.new(1, 2, 1), CFrame.new(p + Vector3.new(0, 1, 0)), Color3.fromRGB(240, 235, 220))
		block(model, "MushroomCap", Vector3.new(4, 1.5, 4), CFrame.new(p + Vector3.new(0, 2.75, 0)), Color3.fromRGB(220, 60, 60))
	end
end

BIOME_PROPS.desert = function(model, rng, spot)
	local green = Color3.fromRGB(70, 150, 70)
	for _ = 1, 24 do
		local p = spot()
		local h = rng:NextInteger(7, 11)
		block(model, "Cactus", Vector3.new(2, h, 2), CFrame.new(p + Vector3.new(0, h / 2, 0)), green)
		local side = rng:NextInteger(0, 1) == 0 and -1 or 1
		block(model, "CactusArm", Vector3.new(2, 2, 2), CFrame.new(p + Vector3.new(side * 2, h * 0.5, 0)), green)
		block(model, "CactusArm", Vector3.new(2, 3, 2), CFrame.new(p + Vector3.new(side * 2, h * 0.5 + 2.5, 0)), green)
	end
	for _ = 1, 16 do
		local p = spot()
		block(model, "Sandstone", Vector3.new(rng:NextInteger(5, 8), rng:NextInteger(3, 5), rng:NextInteger(4, 7)), CFrame.new(p + Vector3.new(0, 2, 0)), Color3.fromRGB(205, 160, 100))
	end
	for _ = 1, 8 do
		local p = spot()
		for i, s in ipairs({ Vector3.new(28, 2, 20), Vector3.new(18, 2, 13), Vector3.new(9, 2, 6) }) do
			block(model, "Dune", s, CFrame.new(p + Vector3.new(0, i * 2 - 1, 0)), Color3.fromRGB(230, 198, 132))
		end
	end
end

BIOME_PROPS.volcanic = function(model, rng, spot, biome, ground)
	local rock = Color3.fromRGB(45, 40, 48)
	local lava = Color3.fromRGB(255, 110, 30)
	-- volcano near the back of the biome
	local vx, vz = biome.center.X, biome.center.Y - biome.size.Y / 2 + 90
	local y = ground
	for _, s in ipairs({ 84, 64, 46, 30 }) do
		block(model, "Volcano", Vector3.new(s, 10, s), CFrame.new(vx, y + 5, vz), rock)
		y += 10
	end
	block(model, "Crater", Vector3.new(18, 1, 18), CFrame.new(vx, y + 0.1, vz), lava, Enum.Material.Neon)
	for _ = 1, 14 do
		local p = spot()
		block(model, "LavaPool", Vector3.new(rng:NextInteger(10, 20), 0.3, rng:NextInteger(8, 16)), CFrame.new(p + Vector3.new(0, 0.2, 0)), lava, Enum.Material.Neon)
	end
	for _ = 1, 22 do
		local p = spot()
		local h = rng:NextInteger(8, 14)
		block(model, "Obsidian", Vector3.new(3, h, 3), CFrame.new(p + Vector3.new(0, h / 2, 0)), Color3.fromRGB(28, 22, 40))
		block(model, "ObsidianTip", Vector3.new(1.5, 3, 1.5), CFrame.new(p + Vector3.new(0, h + 1.5, 0)), Color3.fromRGB(60, 30, 90))
	end
end

BIOME_PROPS.tundra = function(model, rng, spot)
	local pine = Color3.fromRGB(40, 100, 70)
	local snow = Color3.fromRGB(245, 250, 255)
	for _ = 1, 26 do
		local p = spot()
		block(model, "PineTrunk", Vector3.new(2, 4, 2), CFrame.new(p + Vector3.new(0, 2, 0)), Color3.fromRGB(100, 70, 45))
		local y = 4
		for _, s in ipairs({ 10, 7, 4 }) do
			block(model, "Pine", Vector3.new(s, 3, s), CFrame.new(p + Vector3.new(0, y + 1.5, 0)), pine)
			block(model, "Snow", Vector3.new(s - 1, 0.6, s - 1), CFrame.new(p + Vector3.new(0, y + 3.3, 0)), snow)
			y += 3.6
		end
	end
	for _ = 1, 14 do
		local p = spot()
		local h = rng:NextInteger(8, 13)
		block(model, "IceSpike", Vector3.new(3, h, 3), CFrame.new(p + Vector3.new(0, h / 2, 0)), Color3.fromRGB(150, 220, 255), Enum.Material.Ice, 0.15)
		block(model, "IceTip", Vector3.new(1.5, 4, 1.5), CFrame.new(p + Vector3.new(0, h + 2, 0)), Color3.fromRGB(190, 240, 255), Enum.Material.Ice, 0.15)
	end
	for _ = 1, 6 do
		local p = spot()
		block(model, "Snowman", Vector3.new(5, 5, 5), CFrame.new(p + Vector3.new(0, 2.5, 0)), snow)
		block(model, "Snowman", Vector3.new(4, 4, 4), CFrame.new(p + Vector3.new(0, 7, 0)), snow)
		block(model, "Snowman", Vector3.new(3, 3, 3), CFrame.new(p + Vector3.new(0, 10.5, 0)), snow)
		block(model, "Nose", Vector3.new(0.6, 0.6, 1.6), CFrame.new(p + Vector3.new(0, 10.5, -2)), Color3.fromRGB(255, 140, 40))
	end
end

BIOME_PROPS.candy = function(model, rng, spot)
	local colors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 120, 255), Color3.fromRGB(110, 230, 160) }
	for _ = 1, 16 do
		local p = spot()
		block(model, "LollipopStick", Vector3.new(1, 8, 1), CFrame.new(p + Vector3.new(0, 4, 0)), Color3.new(1, 1, 1))
		block(model, "Lollipop", Vector3.new(7, 7, 1.5), CFrame.new(p + Vector3.new(0, 11, 0)), colors[rng:NextInteger(1, #colors)])
	end
	for _ = 1, 14 do
		local p = spot()
		for i = 0, 4 do
			block(model, "CandyCane", Vector3.new(1.5, 2, 1.5), CFrame.new(p + Vector3.new(0, i * 2 + 1, 0)), i % 2 == 0 and Color3.fromRGB(230, 40, 60) or Color3.new(1, 1, 1))
		end
		block(model, "CandyCane", Vector3.new(4, 1.5, 1.5), CFrame.new(p + Vector3.new(1.25, 10.75, 0)), Color3.fromRGB(230, 40, 60))
	end
	for _ = 1, 22 do
		local p = spot()
		local c = colors[rng:NextInteger(1, #colors)]
		block(model, "Gumdrop", Vector3.new(4, 3, 4), CFrame.new(p + Vector3.new(0, 1.5, 0)), c)
		block(model, "Gumdrop", Vector3.new(2.5, 1.5, 2.5), CFrame.new(p + Vector3.new(0, 3.75, 0)), c)
	end
	for _ = 1, 8 do
		block(model, "Chocolate", Vector3.new(12, 2, 7), CFrame.new(spot() + Vector3.new(0, 1, 0)), Color3.fromRGB(95, 55, 35))
	end
end

BIOME_PROPS.atlantis = function(model, rng, spot)
	local stone = Color3.fromRGB(205, 205, 195)
	for _ = 1, 16 do
		local p = spot()
		local h = rng:NextInteger(0, 2) == 0 and rng:NextInteger(4, 7) or rng:NextInteger(12, 16)
		block(model, "RuinBase", Vector3.new(5, 1, 5), CFrame.new(p + Vector3.new(0, 0.5, 0)), stone)
		block(model, "Column", Vector3.new(3, h, 3), CFrame.new(p + Vector3.new(0, 1 + h / 2, 0)), stone)
		if h > 10 then
			block(model, "ColumnTop", Vector3.new(5, 1, 5), CFrame.new(p + Vector3.new(0, 1.5 + h, 0)), stone)
		end
	end
	local corals = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 80), Color3.fromRGB(180, 120, 255), Color3.fromRGB(255, 110, 200) }
	for _ = 1, 22 do
		local p = spot()
		local c = corals[rng:NextInteger(1, #corals)]
		for _ = 1, rng:NextInteger(2, 4) do
			local h = rng:NextInteger(2, 6)
			block(model, "Coral", Vector3.new(2, h, 2), CFrame.new(p + Vector3.new(rng:NextInteger(-2, 2), h / 2, rng:NextInteger(-2, 2))), c)
		end
	end
	for _ = 1, 26 do
		local p = spot()
		local h = rng:NextInteger(6, 12)
		block(model, "Seaweed", Vector3.new(1, h, 1), CFrame.new(p + Vector3.new(0, h / 2, 0)), Color3.fromRGB(40, 140, 80))
	end
end

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local V, CF = Vector3.new, CFrame.new
local NEON = Enum.Material.Neon

-- 8-sided shape: a square block plus the same block turned 45 degrees
local function oct(m, name, w, h, cf, color, material)
	block(m, name, V(w, h, w), cf, color, material)
	block(m, name, V(w, h, w), cf * CFrame.Angles(0, math.rad(45), 0), color, material)
end

-- tiered, pointed roof; returns the height of the tip
local function spireRoof(m, x, y, z, w, roof, tip)
	local s = w + 2
	while s >= 1.6 do
		oct(m, "Roof", s, 3, CF(x, y + 1.5, z), roof)
		y += 3
		s *= 0.74
	end
	block(m, "Tip", V(1, 7, 1), CF(x, y + 3.5, z), tip, NEON)
	return y + 7
end

-- round (8-sided) tower with trim bands, crown, windows and a spire roof
local function roundTower(m, x, z, g, w, h, P)
	oct(m, "Tower", w, h, CF(x, g + h / 2, z), P.stone)
	for _, f in ipairs({ 0.3, 0.62 }) do
		oct(m, "Trim", w + 1, 1.2, CF(x, g + h * f, z), P.trim)
	end
	oct(m, "Crown", w + 2.5, 3, CF(x, g + h + 1.5, z), P.trim)
	for i = 0, 3 do
		local ang = math.rad(90 * i)
		local d = w / 2 + 0.25
		for _, f in ipairs({ 0.45, 0.8 }) do
			block(m, "Window", V(2, 4, 0.4), CF(x + math.sin(ang) * d, g + h * f, z + math.cos(ang) * d) * CFrame.Angles(0, ang, 0), P.window, NEON)
		end
	end
	return spireRoof(m, x, g + h + 3, z, w, P.roof, P.tip)
end

-- Grand castle: 2-tier foundation, front staircase, curtain walls with
-- battlements and a portcullis gate, 4 corner towers, 2 gate towers, and
-- a 3-tier keep with turrets and a tall central spire. Front faces +Z.
local function grandCastle(m, cx, cz, g, P)
	local hw, hd, WH = 48, 43, 24
	block(m, "Foundation", V(112, 3, 102), CF(cx, g + 1.5, cz), P.trim)
	block(m, "Foundation", V(104, 3, 94), CF(cx, g + 4.5, cz), P.stone)
	local base = g + 6
	for i = 0, 5 do
		block(m, "Stair", V(28, i + 1, 2.5), CF(cx, g + (i + 1) / 2, cz + 51 + (6 - i) * 2.5 - 1.25), P.trim)
	end

	-- curtain walls
	local walls = {
		{ V(hw * 2, WH, 4), V(0, 0, -hd) },
		{ V(4, WH, hd * 2), V(-hw, 0, 0) },
		{ V(4, WH, hd * 2), V(hw, 0, 0) },
		{ V(hw - 9, WH, 4), V(-(9 + (hw - 9) / 2), 0, hd) },
		{ V(hw - 9, WH, 4), V(9 + (hw - 9) / 2, 0, hd) },
	}
	for _, w in ipairs(walls) do
		block(m, "Wall", w[1], CF(cx + w[2].X, base + WH / 2, cz + w[2].Z), P.stone)
		block(m, "WallTrim", w[1] + V(1, -WH + 1.5, 1), CF(cx + w[2].X, base + WH * 0.55, cz + w[2].Z), P.trim)
	end
	block(m, "GateLintel", V(18, 6, 4), CF(cx, base + WH - 3, cz + hd), P.stone)
	block(m, "GateArch", V(18, 2, 5), CF(cx, base + WH - 6.5, cz + hd), P.trim)
	for gx = -7.5, 7.5, 2.5 do
		block(m, "Portcullis", V(0.8, WH - 7, 0.8), CF(cx + gx, base + (WH - 7) / 2, cz + hd), P.dark)
	end
	for gy = 4, WH - 8, 4 do
		block(m, "Portcullis", V(16, 0.8, 0.8), CF(cx, base + gy, cz + hd), P.dark)
	end
	-- battlements
	for x = -hw + 2, hw - 2, 4 do
		for _, zz in ipairs({ -hd, hd }) do
			if zz == -hd or math.abs(x) > 10 then
				block(m, "Merlon", V(2, 3, 4.5), CF(cx + x, base + WH + 1.5, cz + zz), P.merlon or P.trim)
			end
		end
	end
	for z = -hd + 2, hd - 2, 4 do
		for _, xx in ipairs({ -hw, hw }) do
			block(m, "Merlon", V(4.5, 3, 2), CF(cx + xx, base + WH + 1.5, cz + z), P.merlon or P.trim)
		end
	end

	-- towers
	for _, c in ipairs({ { -hw, -hd }, { hw, -hd }, { -hw, hd }, { hw, hd } }) do
		roundTower(m, cx + c[1], cz + c[2], base, 16, 40, P)
	end
	for _, gx in ipairs({ -13, 13 }) do
		roundTower(m, cx + gx, cz + hd, base, 10, 32, P)
	end

	-- keep (3 tiers)
	local kz = cz - 8
	local tiers = { { 48, 30, 40 }, { 36, 18, 30 }, { 24, 16, 20 } }
	local y = base
	for i, t in ipairs(tiers) do
		block(m, "Keep", V(t[1], t[2], t[3]), CF(cx, y + t[2] / 2, kz), P.stone)
		block(m, "KeepTrim", V(t[1] + 2, 2, t[3] + 2), CF(cx, y + t[2] + 1, kz), P.trim)
		local count = math.floor(t[1] / 8)
		for wi = 1, count do
			local wx = -t[1] / 2 + (wi - 0.5) * (t[1] / count)
			block(m, "Window", V(2.5, 5, 0.4), CF(cx + wx, y + t[2] * 0.55, kz + t[3] / 2 + 0.2), P.window, NEON)
		end
		if i == 1 then
			block(m, "KeepDoor", V(9, 13, 0.6), CF(cx, y + 6.5, kz + t[3] / 2 + 0.3), P.dark)
			block(m, "KeepDoorArch", V(12, 2, 1), CF(cx, y + 14, kz + t[3] / 2 + 0.5), P.trim)
			for _, c in ipairs({ { -20, -16 }, { 20, -16 }, { -20, 16 }, { 20, 16 } }) do
				roundTower(m, cx + c[1], kz + c[2], y + t[2] + 2, 6, 12, P)
			end
		end
		y += t[2] + 2
	end
	local top = spireRoof(m, cx, y, kz, 18, P.roof, P.tip)
	if P.extra then
		P.extra(m, cx, cz, g, base, kz, top)
	end
end

local BIOME_LANDMARKS = {}

-- Atlantis: sunken royal castle with a colonnade and a glowing orb
BIOME_LANDMARKS.atlantis = function(m, x, z, g)
	grandCastle(m, x, z, g, {
		stone = C(196, 212, 218), trim = C(232, 242, 246), roof = C(38, 158, 170), tip = C(255, 205, 90),
		window = C(120, 230, 255), dark = C(30, 50, 70),
		extra = function(mm, cx, cz, gg, base, kz, top)
			-- greek colonnade in front of the stairs
			for _, cxo in ipairs({ -26, -18, 18, 26 }) do
				for _, czo in ipairs({ 62, 72 }) do
					block(mm, "ColumnBase", V(4, 1, 4), CF(cx + cxo, gg + 0.5, cz + czo), C(232, 242, 246))
					block(mm, "Column", V(2.5, 16, 2.5), CF(cx + cxo, gg + 9, cz + czo), C(210, 225, 230))
					block(mm, "Capital", V(4, 1.5, 4), CF(cx + cxo, gg + 17.75, cz + czo), C(232, 242, 246))
				end
			end
			for _, side in ipairs({ -1, 1 }) do
				block(mm, "Entablature", V(14, 2, 14), CF(cx + side * 22, gg + 19.5, cz + 67), C(232, 242, 246))
			end
			local orb = makePart(mm, "Orb", V(8, 8, 8), CF(cx, top + 5, kz), C(120, 230, 255), NEON)
			orb.Shape = Enum.PartType.Ball
		end,
	})
end

-- Tundra: fortress gate carved into a giant ice-crystal mountain, a Viking
-- longhouse, and a mammoth skeleton frozen in a block of ice
BIOME_LANDMARKS.tundra = function(m, x, z, g)
	local ice, ice2, snow, deep = C(170, 220, 245), C(140, 200, 235), C(245, 250, 255), C(40, 80, 130)
	local wood, woodDark, stone, bone = C(120, 82, 50), C(90, 60, 36), C(120, 125, 135), C(235, 228, 205)
	local ICE = Enum.Material.Ice
	local rng = Random.new(501)

	local mx, mz = x + 45, z - 25
	local y = g
	for i, t in ipairs({ { 76, 10 }, { 62, 10 }, { 50, 10 }, { 38, 10 }, { 26, 10 } }) do
		oct(m, "IceMountain", t[1], t[2], CF(mx, y + t[2] / 2, mz), i % 2 == 0 and ice2 or ice, ICE)
		oct(m, "Snowcap", t[1] - 6, 1, CF(mx, y + t[2] + 0.5, mz), snow)
		y += t[2]
	end
	for i = 1, 9 do
		local a = math.rad(i * 40)
		local r = i == 1 and 0 or rng:NextInteger(8, 22)
		local h = i == 1 and 46 or rng:NextInteger(18, 32)
		local w = i == 1 and 8 or rng:NextInteger(4, 6)
		local base = i == 1 and (y - 2) or (g + 30)
		local cx, cz = mx + math.sin(a) * r, mz + math.cos(a) * r
		local tilt = CFrame.Angles(math.rad(rng:NextInteger(-14, 14)), 0, math.rad(rng:NextInteger(-14, 14)))
		block(m, "Crystal", V(w, h, w), CF(cx, base + h / 2, cz) * tilt, C(160, 230, 255), Enum.Material.Glass, 0.25)
		block(m, "CrystalCore", V(w * 0.35, h * 0.8, w * 0.35), CF(cx, base + h / 2, cz) * tilt, C(120, 220, 255), NEON)
	end
	local fz = mz + 38
	block(m, "GateFrame", V(26, 26, 6), CF(mx, g + 13, fz), stone)
	block(m, "Gateway", V(14, 18, 1), CF(mx, g + 9, fz + 3.1), deep)
	for _, px in ipairs({ -10, 10 }) do
		block(m, "IcePillar", V(4, 30, 4), CF(mx + px, g + 15, fz + 4), ice2, ICE)
		block(m, "IcePillarTop", V(6, 3, 6), CF(mx + px, g + 31.5, fz + 4), snow)
	end
	block(m, "GateLintel", V(28, 4, 8), CF(mx, g + 28, fz + 1), stone)
	for i = 0, 3 do
		block(m, "GateStep", V(20 - i * 2, i + 1, 3), CF(mx, g + (i + 1) / 2, fz + 12 - i * 2.5), stone)
	end

	local lx, lz = x - 55, z + 30
	block(m, "LonghouseBase", V(24, 2, 46), CF(lx, g + 1, lz), stone)
	block(m, "LonghouseWalls", V(20, 10, 42), CF(lx, g + 7, lz), wood)
	for i, s in ipairs({ 24, 19, 14, 9, 4 }) do
		block(m, "LonghouseRoof", V(s, 2.5, 46), CF(lx, g + 12 + i * 2.5 - 1.25, lz), i % 2 == 0 and woodDark or wood)
		block(m, "RoofSnow", V(s - 1, 0.6, 45), CF(lx, g + 12 + i * 2.5 + 0.3, lz), snow)
	end
	for _, dz in ipairs({ -24, 24 }) do
		block(m, "DragonNeck", V(2, 8, 2), CF(lx, g + 25, lz + dz) * CFrame.Angles(math.rad(dz > 0 and 20 or -20), 0, 0), woodDark)
		block(m, "DragonHead", V(3, 3, 5), CF(lx, g + 29, lz + dz + (dz > 0 and 2 or -2)), woodDark)
	end
	block(m, "LonghouseDoor", V(6, 8, 0.5), CF(lx, g + 6, lz + 21.2), woodDark)
	local shields = { C(200, 40, 40), C(40, 90, 180), C(230, 180, 40) }
	for i = 0, 5 do
		for _, sx in ipairs({ -10.3, 10.3 }) do
			block(m, "Shield", V(0.6, 4, 4), CF(lx + sx, g + 7, lz - 15 + i * 6), shields[i % 3 + 1])
		end
	end

	local kx, kz = x + 55, z + 60
	block(m, "IceBlock", V(36, 20, 18), CF(kx, g + 10, kz), C(170, 225, 250), Enum.Material.Glass, 0.55)
	for i = 0, 7 do
		local bx = kx - 10 + i * 2.8
		block(m, "Spine", V(2.5, 2.5, 2.5), CF(bx, g + 13 + math.sin(i / 7 * math.pi) * 2, kz), bone)
		if i >= 1 and i <= 6 then
			for _, s in ipairs({ -1, 1 }) do
				block(m, "Rib", V(1, 9, 1), CF(bx, g + 9, kz + s * 3) * CFrame.Angles(math.rad(s * 22), 0, 0), bone)
			end
		end
	end
	for _, ox in ipairs({ -8, 8 }) do
		for _, s in ipairs({ -1, 1 }) do
			block(m, "Leg", V(2, 9, 2), CF(kx + ox, g + 4.5, kz + s * 4), bone)
		end
	end
	block(m, "Skull", V(6, 6, 6), CF(kx + 14, g + 13, kz), bone)
	for _, s in ipairs({ -1, 1 }) do
		block(m, "Tusk", V(9, 1.5, 1.5), CF(kx + 19, g + 9, kz + s * 2.5) * CFrame.Angles(0, 0, math.rad(25)), bone)
	end
end

-- Candy Land: giant 5-layer cake tower, a candy factory, and a gumball machine
BIOME_LANDMARKS.candy = function(m, x, z, g)
	local pink, white, choco, cream = C(255, 170, 205), C(255, 250, 245), C(110, 65, 40), C(255, 230, 190)
	local sprinkles = { C(255, 80, 120), C(90, 200, 255), C(255, 220, 70), C(120, 230, 140), C(180, 120, 255) }
	local rng = Random.new(777)

	oct(m, "Plate", 72, 2, CF(x, g + 1, z), white)
	local y = g + 2
	for i, L in ipairs({ { 62, 14, pink }, { 50, 13, choco }, { 38, 12, cream }, { 28, 11, pink }, { 18, 10, white } }) do
		oct(m, "CakeLayer", L[1], L[2], CF(x, y + L[2] / 2, z), L[3])
		local frost = i % 2 == 0 and pink or white
		oct(m, "Frosting", L[1] + 1, 1.5, CF(x, y + L[2] - 0.75, z), frost)
		for d = 0, 11 do
			local a = math.rad(d * 30)
			local r = L[1] / 2 + 0.3
			local dh = rng:NextInteger(2, 4)
			block(m, "Drip", V(2, dh, 0.8), CF(x + math.sin(a) * r, y + L[2] - 1.5 - dh / 2, z + math.cos(a) * r) * CFrame.Angles(0, a, 0), frost)
		end
		for _ = 1, 10 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, L[1] / 2 - 3)
			block(m, "Sprinkle", V(1.4, 0.4, 0.5), CF(x + math.cos(a) * r, y + L[2] + 0.2, z + math.sin(a) * r) * CFrame.Angles(0, a, 0), sprinkles[rng:NextInteger(1, #sprinkles)])
		end
		y += L[2]
	end
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local cx, cz = x + math.sin(a) * 5.5, z + math.cos(a) * 5.5
		block(m, "Candle", V(1.2, 6, 1.2), CF(cx, y + 3, cz), sprinkles[i % #sprinkles + 1])
		block(m, "Flame", V(0.8, 1.4, 0.8), CF(cx, y + 6.8, cz), C(255, 200, 80), NEON)
	end
	local cherry = makePart(m, "Cherry", V(6, 6, 6), CF(x, y + 3, z), C(210, 20, 40), Enum.Material.SmoothPlastic)
	cherry.Shape = Enum.PartType.Ball
	block(m, "CherryStem", V(0.6, 4, 0.6), CF(x + 0.8, y + 7.5, z) * CFrame.Angles(0, 0, math.rad(-20)), C(60, 120, 40))

	local fx, fz = x + 70, z - 10
	block(m, "Factory", V(34, 20, 28), CF(fx, g + 10, fz), C(160, 210, 255))
	block(m, "FactoryRoof", V(36, 2, 30), CF(fx, g + 21, fz), C(255, 120, 180))
	block(m, "FactoryRoof", V(28, 2, 22), CF(fx, g + 23, fz), white)
	block(m, "FactoryDoor", V(8, 10, 0.6), CF(fx, g + 5, fz + 14.2), choco)
	for _, wx in ipairs({ -10, 10 }) do
		block(m, "FactoryWindow", V(6, 6, 0.6), CF(fx + wx, g + 12, fz + 14.2), C(255, 230, 130), NEON)
	end
	for _, cx2 in ipairs({ -9, 9 }) do
		for i = 0, 7 do
			block(m, "Chimney", V(4, 2, 4), CF(fx + cx2, g + 25 + i * 2, fz - 6), i % 2 == 0 and C(230, 40, 60) or white)
		end
		local top = block(m, "ChimneyTop", V(5, 1, 5), CF(fx + cx2, g + 41, fz - 6), C(230, 40, 60))
		local smoke = Instance.new("Smoke")
		smoke.Color = C(255, 200, 230)
		smoke.Opacity = 0.15
		smoke.RiseVelocity = 4
		smoke.Size = 3
		smoke.Parent = top
	end
	block(m, "Conveyor", V(6, 1.5, 24), CF(fx, g + 3, fz + 26), C(80, 80, 95))
	for i = 0, 5 do
		block(m, "Candy", V(2.5, 1.5, 2.5), CF(fx, g + 4.5, fz + 16 + i * 4), sprinkles[i % #sprinkles + 1])
	end

	local gx, gz = x - 10, z + 52
	block(m, "GumballBase", V(10, 12, 10), CF(gx, g + 6, gz), C(220, 40, 50))
	block(m, "GumballTrim", V(11, 1.5, 11), CF(gx, g + 12.75, gz), C(255, 210, 80))
	block(m, "CoinSlot", V(3, 3, 0.4), CF(gx, g + 8, gz + 5.2), C(200, 200, 210))
	block(m, "Chute", V(4, 2, 2), CF(gx, g + 3, gz + 5.5), C(200, 200, 210))
	local globe = makePart(m, "Globe", V(16, 16, 16), CF(gx, g + 21, gz), C(220, 240, 255), Enum.Material.Glass, 0.55)
	globe.Shape = Enum.PartType.Ball
	for _ = 1, 18 do
		local ball = makePart(m, "Gumball", V(3, 3, 3), CF(gx + rng:NextNumber(-4, 4), g + 16 + rng:NextNumber(0, 8), gz + rng:NextNumber(-4, 4)), sprinkles[rng:NextInteger(1, #sprinkles)], Enum.Material.SmoothPlastic)
		ball.Shape = Enum.PartType.Ball
	end
	block(m, "GumballCap", V(5, 3, 5), CF(gx, g + 30, gz), C(220, 40, 50))
end

-- Forest: ancient world tree with buttress roots, spiral stairs and a deck
BIOME_LANDMARKS.forest = function(m, x, z, g)
	local bark, bark2 = C(96, 62, 34), C(78, 50, 28)
	local leaves = { C(52, 132, 52), C(70, 158, 62), C(88, 176, 72) }
	local wood = C(150, 105, 60)
	oct(m, "Trunk", 22, 80, CF(x, g + 40, z), bark)
	oct(m, "Trunk", 16, 24, CF(x, g + 92, z), bark2)
	for i = 0, 5 do
		local a = math.rad(i * 60 + 15)
		block(m, "Root", V(7, 12, 30), CF(x, g + 4, z) * CFrame.Angles(0, a, 0) * CF(0, 0, 16) * CFrame.Angles(math.rad(-22), 0, 0), bark2)
	end
	local branchAngles = { 20, 95, 170, 245, 320 }
	for i, deg in ipairs(branchAngles) do
		local a = math.rad(deg)
		local h = 58 + i * 6
		block(m, "Branch", V(6, 6, 34), CF(x, g + h, z) * CFrame.Angles(0, a, 0) * CF(0, 0, 20) * CFrame.Angles(math.rad(18), 0, 0), bark)
		local ex, ez = x + math.sin(a) * 34, z + math.cos(a) * 34
		oct(m, "Leaves", 26, 12, CF(ex, g + h + 12, ez), leaves[(i % 3) + 1])
	end
	oct(m, "Canopy", 86, 16, CF(x, g + 98, z), leaves[1])
	oct(m, "Canopy", 66, 14, CF(x, g + 112, z), leaves[2])
	oct(m, "Canopy", 42, 12, CF(x, g + 124, z), leaves[3])
	oct(m, "Canopy", 20, 8, CF(x, g + 134, z), leaves[2])
	-- spiral stairs around the trunk up to the deck
	for i = 0, 26 do
		local a = math.rad(i * 18)
		block(m, "StairPlank", V(8, 1, 3.5), CF(x, g + 1 + i * 1.5, z) * CFrame.Angles(0, a, 0) * CF(0, 0, 15.5), wood)
	end
	-- deck around the trunk with railings and a hut
	oct(m, "Deck", 44, 1.5, CF(x, g + 41, z), wood)
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		block(m, "RailPost", V(1, 4, 1), CF(x + math.sin(a) * 21, g + 43.5, z + math.cos(a) * 21), wood)
	end
	block(m, "Hut", V(14, 10, 12), CF(x + 12, g + 47, z + 10), C(170, 120, 70))
	block(m, "HutRoof", V(16, 2, 14), CF(x + 12, g + 53, z + 10), C(160, 50, 45))
	block(m, "HutRoof", V(11, 2, 9), CF(x + 12, g + 55, z + 10), C(160, 50, 45))
	block(m, "HutDoor", V(4, 6, 0.4), CF(x + 12, g + 45, z + 16.2), C(80, 50, 30))
	for _, lx in ipairs({ -14, 14 }) do
		block(m, "Lantern", V(2, 2, 2), CF(x + lx, g + 36, z + 12), C(255, 220, 120), NEON)
	end
end

-- Desert: great pyramid with an avenue of obelisks and two sphinxes
BIOME_LANDMARKS.desert = function(m, x, z, g)
	local c1, c2, gold, dark = C(222, 184, 120), C(205, 166, 104), C(255, 205, 80), C(45, 32, 22)
	local size, y, i = 104, g, 0
	while size >= 8 do
		block(m, "Pyramid", V(size, 4, size), CF(x, y + 2, z), i % 2 == 0 and c1 or c2)
		y += 4
		size -= 8
		i += 1
	end
	block(m, "Capstone", V(6, 5, 6), CF(x, y + 2.5, z), gold, NEON)
	-- entrance portal
	block(m, "Portal", V(20, 18, 10), CF(x, g + 9, z + 55), c2)
	block(m, "Doorway", V(9, 13, 1), CF(x, g + 6.5, z + 60.2), dark)
	block(m, "Lintel", V(22, 3, 11), CF(x, g + 19.5, z + 55), gold)
	-- paved avenue
	block(m, "Avenue", V(18, 0.4, 44), CF(x, g + 0.2, z + 82), c2)
	for _, side in ipairs({ -1, 1 }) do
		for _, oz in ipairs({ 72, 94 }) do
			block(m, "Obelisk", V(4, 26, 4), CF(x + side * 14, g + 13, z + oz), c2)
			block(m, "ObeliskTip", V(2, 3, 2), CF(x + side * 14, g + 27.5, z + oz), gold, NEON)
		end
		-- sphinx
		local sx, sz = x + side * 26, z + 82
		block(m, "SphinxBase", V(10, 3, 18), CF(sx, g + 1.5, sz), c1)
		block(m, "SphinxBody", V(8, 6, 14), CF(sx, g + 6, sz - 1), c2)
		block(m, "SphinxPaw", V(2.5, 2, 6), CF(sx - 2.5, g + 4, sz + 8), c2)
		block(m, "SphinxPaw", V(2.5, 2, 6), CF(sx + 2.5, g + 4, sz + 8), c2)
		block(m, "SphinxHead", V(6, 7, 5), CF(sx, g + 12, sz + 5), c1)
		block(m, "SphinxHeaddress", V(8, 4, 3), CF(sx, g + 13, sz + 3.5), gold)
	end
end

-- Volcanic: obsidian ziggurat with lava moat, stairs, shrine and fire braziers
BIOME_LANDMARKS.volcanic = function(m, x, z, g)
	local obs, basalt, lava, gold = C(28, 22, 38), C(62, 55, 64), C(255, 105, 25), C(255, 190, 60)
	local y = g
	for _, t in ipairs({ { 72, 8 }, { 58, 8 }, { 44, 8 }, { 30, 8 } }) do
		block(m, "Ziggurat", V(t[1], t[2], t[1]), CF(x, y + t[2] / 2, z), obs)
		block(m, "ZigguratTrim", V(t[1] + 1, 1, t[1] + 1), CF(x, y + t[2] - 0.5, z), basalt)
		block(m, "LavaVein", V(t[1] * 0.7, 0.8, 0.4), CF(x, y + t[2] * 0.45, z + t[1] / 2 + 0.2), lava, NEON)
		y += t[2]
	end
	-- stairs up the front
	-- solid steps from the ground up to the shrine (each step reaches the ground)
	for i = 0, 31 do
		block(m, "Stair", V(12, i + 1, 1.2), CF(x, g + (i + 1) / 2, z + 45 - i * 0.95), basalt)
	end
	-- shrine on top
	for i = 0, 7 do
		local a = math.rad(i * 45)
		block(m, "ShrinePillar", V(3, 14, 3), CF(x + math.sin(a) * 11, y + 7, z + math.cos(a) * 11), obs)
	end
	block(m, "ShrineRoof", V(30, 3, 30), CF(x, y + 15.5, z), basalt)
	block(m, "ShrineRoof", V(20, 3, 20), CF(x, y + 18.5, z), obs)
	block(m, "ShrineRoof", V(10, 3, 10), CF(x, y + 21.5, z), basalt)
	local altar = block(m, "LavaAltar", V(6, 3, 6), CF(x, y + 1.5, z), lava, NEON)
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 12
	fire.Color = C(255, 120, 30)
	fire.SecondaryColor = C(255, 220, 90)
	fire.Parent = altar
	-- lava moat around the base, with a bridge at the front
	for _, s in ipairs({ { V(90, 0.4, 5), V(0, 0, -44) }, { V(5, 0.4, 88), V(-44, 0, 0) }, { V(5, 0.4, 88), V(44, 0, 0) },
		{ V(38, 0.4, 5), V(-26, 0, 44) }, { V(38, 0.4, 5), V(26, 0, 44) } }) do
		block(m, "LavaMoat", s[1], CF(x + s[2].X, g + 0.2, z + s[2].Z), lava, NEON)
	end
	-- fire braziers at the corners
	for _, c in ipairs({ { -44, -44 }, { 44, -44 }, { -44, 44 }, { 44, 44 } }) do
		block(m, "Brazier", V(4, 10, 4), CF(x + c[1], g + 5, z + c[2]), basalt)
		local bowl = block(m, "BrazierBowl", V(6, 2, 6), CF(x + c[1], g + 11, z + c[2]), gold)
		local f = Instance.new("Fire")
		f.Size = 7
		f.Heat = 9
		f.Parent = bowl
	end
end

-- where each landmark stands (offset from the biome center) + clear radius
local LANDMARK_SPOTS = {
	forest = { -85, -45, 62 },
	desert = { 90, -30, 80 },
	volcanic = { -95, 75, 62 },
	tundra = { 30, -40, 115 },
	candy = { -55, 0, 110 },
	atlantis = { 0, -70, 90 },
}

--------------------------------------------------------------------
-- Biome details. Each biome gets "Decor" (ground details: pets walk
-- around them, enemies never spawn inside) and "Ambient" (particles and
-- floating lights: not obstacles). Middle lane + gate areas stay open.
--------------------------------------------------------------------

-- flat ground features (paths, water): top sits just above the floor tiles
local function flat(m, name, size, cf, color, material, transparency)
	local p = makePart(m, name, V(size.X, 0.3, size.Z), cf, color, material or Enum.Material.Plastic, transparency)
	p.TopSurface = Enum.SurfaceType.Studs
	p.CanCollide = false
	return p
end

local function strip(m, name, a, b, width, y, color, material, transparency)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(V(mid.X, y, mid.Z), V(b.X, y, b.Z))
	return flat(m, name, V(width, 0, len + width * 0.6), cf, color, material, transparency)
end

local function polyline(m, name, pts, width, y, color, material, transparency)
	for i = 1, #pts - 1 do
		strip(m, name, pts[i], pts[i + 1], width, y, color, material, transparency)
	end
end

-- soft particle cloud filling a box (fireflies, embers, snow, bubbles...)
local function emitter(parent, pos, boxSize, o)
	local p = makePart(parent, "Emitter", boxSize, CF(pos), C(255, 255, 255), Enum.Material.Plastic, 1)
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = o.colorSeq or ColorSequence.new(o.color)
	e.LightEmission = o.light and 1 or 0.2
	e.Rate = o.rate
	e.Lifetime = NumberRange.new(o.life * 0.7, o.life)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, o.size),
		NumberSequenceKeypoint.new(0.8, o.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Speed = NumberRange.new(o.speed * 0.5, o.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = o.accel or Vector3.zero
	e.Transparency = NumberSequence.new(o.transparency or 0.1)
	e.Parent = p
	return p
end

local function palm(m, base, rng)
	local lean = rng:NextNumber(-0.25, 0.25)
	for i = 0, 5 do
		block(m, "PalmTrunk", V(1.8, 3, 1.8), base * CF(lean * i * i * 0.4, 1.5 + i * 3, 0), C(150, 110, 70))
	end
	local top = base * CF(lean * 25 * 0.4, 18.5, 0)
	for i = 0, 5 do
		block(m, "PalmLeaf", V(2.4, 0.6, 9), top * CFrame.Angles(0, i / 6 * math.pi * 2, 0) * CF(0, 0, -4) * CFrame.Angles(math.rad(-20), 0, 0), C(80, 170, 70))
	end
end

local function wavy(P, zBase, amp, freq)
	local pts = {}
	for i = 0, 12 do
		table.insert(pts, P(-180 + i * 30, zBase + math.sin(i * freq) * amp))
	end
	return pts
end

local function keepLine(keep, biome, pts, r)
	for _, p in ipairs(pts) do
		table.insert(keep, { p.X - biome.center.X, p.Z - biome.center.Y, r })
	end
end

local BIOME_DETAILS = {}

-- Forest: winding path to the giant tree, stream + bridge, mossy logs,
-- stone circles, mushroom rings, fireflies
BIOME_DETAILS.forest = function(d, amb, rng, biome, g, keep, pick, P, clear, at)
	local dirt, wood, moss, stone = C(150, 110, 70), C(120, 80, 45), C(80, 150, 70), C(140, 140, 150)
	local path = { P(0, 185), P(12, 140), P(-10, 95), P(-35, 50), P(-55, 10), P(-70, -15) }
	polyline(d, "Path", path, 10, g + 0.1, dirt)
	keepLine(keep, biome, path, 9)
	local stream = wavy(P, 70, 14, 0.9)
	polyline(d, "Stream", stream, 12, g + 0.12, C(70, 150, 220), Enum.Material.Glass, 0.15)
	keepLine(keep, biome, stream, 10)
	local bz = 70 + math.sin(((-30 + 180) / 30) * 0.9) * 14
	block(d, "Bridge", V(14, 0.6, 20), at(-28, g + 0.4, bz), wood)
	for _, o in ipairs({ { -7, -10 }, { 7, -10 }, { -7, 10 }, { 7, 10 } }) do
		block(d, "BridgePost", V(1, 2.5, 1), at(-28 + o[1], g + 1.25, bz + o[2]), wood)
	end
	for _ = 1, 8 do
		local x, z = pick(9)
		if x then
			local cf = at(x, g + 1.5, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			block(d, "Log", V(3, 3, 14), cf, wood)
			block(d, "Moss", V(3.2, 0.6, 10), cf * CF(0, 1.7, 0), moss)
			clear(P(x, z), 9)
		end
	end
	for _ = 1, 3 do
		local x, z = pick(9)
		if x then
			for i = 0, 7 do
				local ang = i / 8 * math.pi * 2
				local h = rng:NextInteger(2, 4)
				block(d, "Stone", V(2.2, h, 2.2), at(x + math.cos(ang) * 6, g + h / 2, z + math.sin(ang) * 6), stone)
			end
			clear(P(x, z), 9)
		end
	end
	for _ = 1, 3 do
		local x, z = pick(7)
		if x then
			for i = 0, 7 do
				local ang = i / 8 * math.pi * 2
				local px, pz = x + math.cos(ang) * 5, z + math.sin(ang) * 5
				block(d, "MushroomStem", V(0.8, 1.6, 0.8), at(px, g + 0.8, pz), C(240, 235, 220))
				block(d, "MushroomCap", V(2.4, 1, 2.4), at(px, g + 2.1, pz), C(220, 60, 60))
			end
			clear(P(x, z), 7)
		end
	end
	for _, s in ipairs({ { -85, -45, 44 }, { 60, 20, 26 }, { -120, 115, 26 }, { 120, -120, 26 } }) do
		emitter(amb, P(s[1], s[2]) + V(0, g + 10, 0), V(s[3], 12, s[3]), { color = C(255, 240, 120), rate = 6, size = 0.35, life = 5, speed = 0.6, light = true })
	end
end

-- Desert: oasis with palms, rock arch, mesas, giant bones, ruins, blowing sand
BIOME_DETAILS.desert = function(d, amb, rng, biome, g, keep, pick, P, clear, at)
	local sand2, stone, bone = C(205, 160, 100), C(195, 150, 95), C(240, 232, 210)
	local ox, oz = -110, 75
	clear(P(ox, oz), 34)
	table.insert(keep, { ox, oz, 34 })
	oct(d, "OasisGrass", 46, 0.3, at(ox, g + 0.1, oz), C(110, 190, 90))
	oct(d, "OasisWater", 32, 0.3, at(ox, g + 0.15, oz), C(70, 170, 220), Enum.Material.Glass)
	for i = 0, 4 do
		local ang = i / 5 * math.pi * 2 + 0.3
		palm(d, at(ox + math.cos(ang) * 20, g, oz + math.sin(ang) * 20), rng)
	end
	local ax, az = 135, 120
	clear(P(ax, az), 26)
	table.insert(keep, { ax, az, 26 })
	for _, s in ipairs({ -1, 1 }) do
		block(d, "ArchPillar", V(8, 22, 8), at(ax + s * 11, g + 11, az), sand2)
		block(d, "ArchBase", V(10, 4, 10), at(ax + s * 11, g + 2, az), stone)
	end
	block(d, "ArchTop", V(32, 7, 9), at(ax, g + 24.5, az), sand2)
	block(d, "ArchTop", V(24, 3, 8), at(ax, g + 29.5, az), stone)
	for _ = 1, 4 do
		local x, z = pick(14)
		if x then
			block(d, "Mesa", V(22, 8, 18), at(x, g + 4, z), sand2)
			block(d, "Mesa", V(15, 6, 12), at(x, g + 11, z), stone)
			block(d, "Mesa", V(8, 4, 7), at(x, g + 16, z), sand2)
			clear(P(x, z), 14)
		end
	end
	local bx, bz = -45, -125
	clear(P(bx, bz), 24)
	table.insert(keep, { bx, bz, 24 })
	for i = 0, 9 do
		block(d, "Spine", V(3, 3, 3), at(bx - 14 + i * 3.2, g + 1.5, bz), bone)
	end
	for i = 1, 7 do
		for _, s in ipairs({ -1, 1 }) do
			block(d, "Rib", V(1.4, 10, 1.4), at(bx - 12 + i * 3.2, g + 4, bz + s * 4) * CFrame.Angles(math.rad(s * 28), 0, 0), bone)
		end
	end
	block(d, "Skull", V(7, 6, 7), at(bx + 19, g + 3, bz), bone)
	block(d, "Horn", V(1.5, 1.5, 8), at(bx + 22, g + 6, bz - 4) * CFrame.Angles(math.rad(-30), 0, 0), bone)
	for _ = 1, 7 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(88, 105)
		local x, z = 90 + math.cos(ang) * r, -30 + math.sin(ang) * r
		if math.abs(x) < 175 and math.abs(z) < 170 then
			local h = rng:NextInteger(4, 12)
			block(d, "RuinPillar", V(3.5, h, 3.5), at(x, g + h / 2, z), sand2)
			if h < 8 then
				block(d, "FallenPillar", V(3.5, 3.5, 9), at(x + 5, g + 1.75, z + 3) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), sand2)
			end
			clear(P(x, z), 7)
		end
	end
	emitter(amb, P(0, 0) + V(0, g + 3, 0), V(320, 4, 320), { color = C(235, 205, 150), rate = 10, size = 0.5, life = 4, speed = 6, transparency = 0.5 })
end

-- Volcanic: lava river + stone bridges, smoking vents, burnt trees,
-- magma rocks with glowing cracks, floating embers
BIOME_DETAILS.volcanic = function(d, amb, rng, biome, g, keep, pick, P, clear, at)
	local basalt, crust, lava, char = C(45, 40, 48), C(30, 26, 34), C(255, 100, 20), C(25, 20, 22)
	table.insert(keep, { 0, -110, 50 }) -- the volcano
	local river = wavy(P, -30, 12, 0.8)
	polyline(d, "LavaCrust", river, 18, g + 0.08, crust)
	polyline(d, "LavaRiver", river, 11, g + 0.14, lava, NEON)
	keepLine(keep, biome, river, 11)
	for _, bx in ipairs({ -45, 75 }) do
		local bz = -30 + math.sin(((bx + 180) / 30) * 0.8) * 12
		block(d, "StoneBridge", V(14, 0.7, 26), at(bx, g + 0.45, bz), basalt)
		for _, o in ipairs({ { -7, -13 }, { 7, -13 }, { -7, 13 }, { 7, 13 } }) do
			block(d, "BridgePost", V(1.5, 2.5, 1.5), at(bx + o[1], g + 1.25, bz + o[2]), basalt)
		end
	end
	for _ = 1, 8 do
		local x, z = pick(5)
		if x then
			for i = 0, 5 do
				local ang = i / 6 * math.pi * 2
				block(d, "VentRock", V(2, 1.5, 2), at(x + math.cos(ang) * 2.5, g + 0.75, z + math.sin(ang) * 2.5), basalt)
			end
			local hole = block(d, "Vent", V(2.6, 0.4, 2.6), at(x, g + 0.3, z), C(255, 120, 40), NEON)
			local sm = Instance.new("Smoke")
			sm.Color = C(90, 85, 90)
			sm.Opacity = 0.18
			sm.RiseVelocity = 7
			sm.Size = 4
			sm.Parent = hole
			clear(P(x, z), 5)
		end
	end
	for _ = 1, 10 do
		local x, z = pick(4)
		if x then
			local h = rng:NextInteger(8, 13)
			block(d, "BurntTrunk", V(1.6, h, 1.6), at(x, g + h / 2, z), char)
			block(d, "BurntBranch", V(5, 1, 1), at(x + 2, g + h * 0.7, z) * CFrame.Angles(0, 0, math.rad(25)), char)
			block(d, "BurntBranch", V(1, 1, 4), at(x, g + h * 0.55, z - 1.8) * CFrame.Angles(math.rad(-25), 0, 0), char)
			clear(P(x, z), 4)
		end
	end
	for _ = 1, 10 do
		local x, z = pick(6)
		if x then
			local s = rng:NextInteger(5, 9)
			local cf = at(x, g + s * 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
			block(d, "MagmaRock", V(s, s * 0.8, s), cf, basalt)
			block(d, "MagmaCrack", V(s * 0.9, 0.3, 0.4), cf * CF(0, s * 0.4 + 0.05, 0), lava, NEON)
			block(d, "MagmaCrack", V(0.4, 0.3, s * 0.7), cf * CF(s * 0.1, s * 0.4 + 0.05, 0), lava, NEON)
			clear(P(x, z), 6)
		end
	end
	for _, s in ipairs({ { 0, -30 }, { -100, 80 }, { 100, 100 }, { 0, -110 } }) do
		emitter(amb, P(s[1], s[2]) + V(0, g + 3, 0), V(120, 2, 90), { color = C(255, 140, 40), rate = 12, size = 0.3, life = 4, speed = 3, light = true, accel = V(0, 2, 0) })
	end
end

-- Tundra: frozen lake with cracks, snow drifts, frozen trees with icicles,
-- abandoned camp, snowfall
BIOME_DETAILS.tundra = function(d, amb, rng, biome, g, keep, pick, P, clear, at)
	local snow, ice, wood = C(245, 250, 255), C(170, 220, 245), C(110, 75, 45)
	local lx, lz = -120, 110
	clear(P(lx, lz), 38)
	table.insert(keep, { lx, lz, 38 })
	oct(d, "LakeShore", 64, 0.3, at(lx, g + 0.1, lz), C(225, 235, 245))
	oct(d, "FrozenLake", 54, 0.3, at(lx, g + 0.15, lz), C(160, 215, 245), Enum.Material.Ice)
	for _ = 1, 9 do
		block(d, "IceCrack", V(0.4, 0.1, rng:NextInteger(6, 14)), at(lx + rng:NextNumber(-18, 18), g + 0.32, lz + rng:NextNumber(-18, 18)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C(240, 250, 255))
	end
	for _ = 1, 10 do
		local x, z = pick(9)
		if x then
			block(d, "Drift", V(16, 2, 9), at(x, g + 1, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), snow)
			block(d, "Drift", V(10, 2, 6), at(x, g + 3, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), snow)
			clear(P(x, z), 9)
		end
	end
	for _ = 1, 10 do
		local x, z = pick(6)
		if x then
			block(d, "FrozenTrunk", V(2, 5, 2), at(x, g + 2.5, z), wood)
			local y = g + 5
			for _, s in ipairs({ 11, 8, 5 }) do
				block(d, "FrozenLeaves", V(s, 3, s), at(x, y + 1.5, z), C(120, 170, 190))
				block(d, "SnowCap", V(s - 1, 0.6, s - 1), at(x, y + 3.3, z), snow)
				for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
					block(d, "Icicle", V(0.5, 1.8, 0.5), at(x + o[1] * (s / 2 - 0.5), y - 0.6, z + o[2] * (s / 2 - 0.5)), ice, Enum.Material.Ice, 0.2)
				end
				y += 3.6
			end
			clear(P(x, z), 6)
		end
	end
	-- abandoned camp: A-frame tent, campfire ring, log seats, crates
	local cx, cz = -130, -125
	clear(P(cx, cz), 22)
	table.insert(keep, { cx, cz, 22 })
	local canvas = C(150, 115, 80)
	block(d, "Tent", V(9, 0.6, 10), at(cx - 2.9, g + 3.6, cz) * CFrame.Angles(0, 0, math.rad(50)), canvas)
	block(d, "Tent", V(9, 0.6, 10), at(cx + 2.9, g + 3.6, cz) * CFrame.Angles(0, 0, math.rad(-50)), canvas)
	for i = 0, 7 do
		local ang = i / 8 * math.pi * 2
		block(d, "FireStone", V(1.4, 1, 1.4), at(cx + 12 + math.cos(ang) * 3, g + 0.5, cz + math.sin(ang) * 3), C(120, 125, 135))
	end
	block(d, "FireLog", V(4, 0.8, 0.8), at(cx + 12, g + 0.5, cz) * CFrame.Angles(0, math.rad(45), 0), wood)
	block(d, "FireLog", V(4, 0.8, 0.8), at(cx + 12, g + 0.5, cz) * CFrame.Angles(0, math.rad(-45), 0), wood)
	for _, o in ipairs({ { 12, 7 }, { 12, -7 } }) do
		block(d, "LogSeat", V(6, 1.6, 1.6), at(cx + o[1], g + 0.8, cz + o[2]), wood)
	end
	block(d, "Crate", V(3, 3, 3), at(cx - 8, g + 1.5, cz + 7), C(150, 110, 70))
	block(d, "Crate", V(2.4, 2.4, 2.4), at(cx - 8, g + 4.2, cz + 7), C(135, 100, 62))
	for _, z in ipairs({ 80, -80 }) do
		emitter(amb, P(0, z) + V(0, g + 45, 0), V(360, 1, 170), { color = snow, rate = 40, size = 0.4, life = 10, speed = 1, accel = V(0, -3, 0), transparency = 0.1 })
	end
end

-- Candy Land: chocolate river + cookie bridges, candy-cane posts along it,
-- giant ice cream cones, donuts, cupcake houses, floating sprinkles
BIOME_DETAILS.candy = function(d, amb, rng, biome, g, keep, pick, P, clear, at)
	local choco, cookie, white, red = C(95, 55, 35), C(215, 165, 100), C(255, 250, 245), C(230, 40, 60)
	local pastel = { C(255, 170, 210), C(170, 220, 255), C(255, 235, 150), C(180, 240, 190), C(210, 180, 255) }
	local river = wavy(P, 115, 10, 0.9)
	polyline(d, "ChocolateBank", river, 18, g + 0.08, C(130, 80, 50))
	polyline(d, "ChocolateRiver", river, 12, g + 0.14, choco, Enum.Material.SmoothPlastic)
	keepLine(keep, biome, river, 12)
	for i, p in ipairs(river) do
		if i % 2 == 0 then
			for _, s in ipairs({ -1, 1 }) do
				for k = 0, 2 do
					block(d, "CanePost", V(1, 1.4, 1), CF(p.X, g + 0.7 + k * 1.4, p.Z + s * 11), k % 2 == 0 and red or white)
				end
			end
		end
	end
	for _, bx in ipairs({ -60, 70 }) do
		local bz = 115 + math.sin(((bx + 180) / 30) * 0.9) * 10
		oct(d, "CookieBridge", 18, 0.8, at(bx, g + 0.5, bz), cookie)
		for _ = 1, 6 do
			block(d, "ChocoChip", V(1.2, 0.4, 1.2), at(bx + rng:NextNumber(-6, 6), g + 1, bz + rng:NextNumber(-6, 6)), choco)
		end
	end
	for _ = 1, 5 do
		local x, z = pick(6)
		if x then
			local y = g
			for _, w in ipairs({ 1.5, 2.5, 3.5, 4.5, 5.5 }) do
				block(d, "Cone", V(w, 2.2, w), at(x, y + 1.1, z), cookie)
				y += 2.2
			end
			local s1 = makePart(d, "Scoop", V(7, 7, 7), at(x, y + 2.5, z), pastel[rng:NextInteger(1, 5)], Enum.Material.SmoothPlastic)
			s1.Shape = Enum.PartType.Ball
			local s2 = makePart(d, "Scoop", V(5.5, 5.5, 5.5), at(x, y + 7, z), pastel[rng:NextInteger(1, 5)], Enum.Material.SmoothPlastic)
			s2.Shape = Enum.PartType.Ball
			local ch = makePart(d, "Cherry", V(1.8, 1.8, 1.8), at(x, y + 10.3, z), red, Enum.Material.SmoothPlastic)
			ch.Shape = Enum.PartType.Ball
			clear(P(x, z), 6)
		end
	end
	for _ = 1, 6 do
		local x, z = pick(5)
		if x then
			local c = pastel[rng:NextInteger(1, 5)]
			local rot = CFrame.Angles(0, rng:NextNumber(0, 3), 0)
			for i = 0, 9 do
				local ang = i / 10 * math.pi * 2
				block(d, "Donut", V(2.6, 2.6, 2.6), at(x, g + 4, z) * rot * CF(math.cos(ang) * 3.4, math.sin(ang) * 3.4, 0), i < 5 and c or cookie)
			end
			clear(P(x, z), 5)
		end
	end
	for _ = 1, 3 do
		local x, z = pick(10)
		if x then
			for i = 0, 7 do
				local ang = i / 8 * math.pi * 2
				block(d, "Wrapper", V(3, 8, 3), at(x + math.cos(ang) * 5, g + 4, z + math.sin(ang) * 5), i % 2 == 0 and C(255, 120, 170) or white)
			end
			oct(d, "CakeCore", 10, 8, at(x, g + 4, z), C(200, 140, 90))
			oct(d, "Frosting", 13, 3, at(x, g + 9.5, z), pastel[rng:NextInteger(1, 5)])
			oct(d, "Frosting", 9, 3, at(x, g + 12.5, z), pastel[rng:NextInteger(1, 5)])
			oct(d, "Frosting", 5, 2, at(x, g + 15, z), white)
			local ch = makePart(d, "Cherry", V(2.4, 2.4, 2.4), at(x, g + 17, z), red, Enum.Material.SmoothPlastic)
			ch.Shape = Enum.PartType.Ball
			block(d, "Door", V(3, 4.5, 0.5), at(x, g + 2.25, z + 6.3), choco)
			block(d, "Window", V(2, 2, 0.5), at(x + 3, g + 5.5, z + 5.6), C(255, 230, 120), NEON)
			clear(P(x, z), 10)
		end
	end
	local sprinkleColors = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C(255, 90, 140)),
		ColorSequenceKeypoint.new(0.33, C(120, 200, 255)),
		ColorSequenceKeypoint.new(0.66, C(255, 220, 90)),
		ColorSequenceKeypoint.new(1, C(120, 230, 150)),
	})
	for _, s in ipairs({ { 0, 60 }, { -100, -100 }, { 100, -60 } }) do
		emitter(amb, P(s[1], s[2]) + V(0, g + 8, 0), V(130, 10, 110), { colorSeq = sprinkleColors, rate = 8, size = 0.4, life = 6, speed = 0.8, light = true })
	end
end

-- Atlantis: shipwreck, kelp forest, giant shells, treasure pile, broken
-- statues, glowing jellyfish (floating) and rising bubbles
BIOME_DETAILS.atlantis = function(d, amb, rng, biome, g, keep, pick, P, clear, at)
	local wood, wood2, stone, gold = C(90, 65, 45), C(70, 50, 35), C(185, 200, 205), C(255, 205, 80)
	local sx, sz = -125, 95
	clear(P(sx, sz), 30)
	table.insert(keep, { sx, sz, 30 })
	local ship = at(sx, g, sz) * CFrame.Angles(0, math.rad(30), math.rad(12))
	block(d, "Hull", V(32, 5, 11), ship * CF(0, 1.5, 0), wood)
	block(d, "Hull", V(34, 5, 1.5), ship * CF(0, 5, 5.5), wood2)
	block(d, "Hull", V(34, 5, 1.5), ship * CF(0, 5, -5.5), wood2)
	block(d, "Deck", V(30, 1, 10), ship * CF(0, 6, 0), wood)
	for i = 0, 3 do
		block(d, "Bow", V(4 - i * 0.5, 5, 11 - i * 2.5), ship * CF(17 + i * 2, 4, 0), wood2)
	end
	block(d, "Stern", V(8, 4, 11), ship * CF(-13, 9, 0), wood2)
	block(d, "BrokenMast", V(1.6, 18, 1.6), ship * CF(-2, 15, 0) * CFrame.Angles(0, 0, math.rad(-20)), wood2)
	block(d, "TornSail", V(0.3, 9, 8), ship * CF(-5, 17, 0) * CFrame.Angles(0, 0, math.rad(-20)), C(215, 205, 180))
	local kx, kz = 120, 115
	clear(P(kx, kz), 34)
	table.insert(keep, { kx, kz, 34 })
	for _ = 1, 18 do
		local x, z = kx + rng:NextNumber(-28, 28), kz + rng:NextNumber(-22, 22)
		local y = g
		for i = 1, rng:NextInteger(3, 5) do
			block(d, "Kelp", V(1.2, 4, 1.2), at(x + math.sin(i) * 0.8, y + 2, z), i % 2 == 0 and C(40, 140, 80) or C(60, 170, 90))
			y += 4
		end
	end
	for _ = 1, 4 do
		local x, z = pick(7)
		if x then
			local rot = at(x, g, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
			for i = 0, 4 do
				block(d, "Shell", V(2.2, 7, 1), rot * CF((i - 2) * 1.6, 3, 0) * CFrame.Angles(0, 0, math.rad((i - 2) * -14)), i % 2 == 0 and C(255, 190, 200) or C(255, 230, 215))
			end
			local pearl = makePart(d, "Pearl", V(2, 2, 2), rot * CF(0, 1.2, 1.5), C(245, 245, 255), NEON)
			pearl.Shape = Enum.PartType.Ball
			clear(P(x, z), 7)
		end
	end
	local tx, tz = -150, -60
	clear(P(tx, tz), 16)
	table.insert(keep, { tx, tz, 16 })
	for _ = 1, 14 do
		block(d, "Coins", V(rng:NextInteger(2, 4), 1, rng:NextInteger(2, 4)), at(tx + rng:NextNumber(-6, 6), g + 0.5 + rng:NextInteger(0, 2), tz + rng:NextNumber(-6, 6)), gold)
	end
	block(d, "Chest", V(6, 4, 4), at(tx, g + 2, tz + 2), wood2)
	block(d, "ChestLid", V(6.2, 1, 4.2), at(tx, g + 4.5, tz + 2), gold)
	block(d, "ChestGlow", V(5, 0.4, 3), at(tx, g + 4.1, tz + 2), gold, NEON)
	local gems = { C(255, 80, 120), C(80, 200, 255), C(120, 255, 140) }
	for _ = 1, 5 do
		block(d, "Gem", V(1, 1, 1), at(tx + rng:NextNumber(-5, 5), g + 2.3, tz + rng:NextNumber(-5, 5)), gems[rng:NextInteger(1, 3)], NEON)
	end
	for _ = 1, 3 do
		local x, z = pick(6)
		if x then
			block(d, "Pedestal", V(6, 3, 6), at(x, g + 1.5, z), stone)
			block(d, "StatueBody", V(3.5, 7, 2.5), at(x, g + 6.5, z), stone)
			block(d, "StatueHead", V(2.5, 2.5, 2.5), at(x + 4, g + 1.25, z + 2) * CFrame.Angles(0.4, 0.3, 0.5), stone)
			block(d, "Trident", V(0.6, 12, 0.6), at(x - 2.5, g + 6, z) * CFrame.Angles(0, 0, math.rad(8)), gold)
			clear(P(x, z), 6)
		end
	end
	local jellyColors = { C(255, 120, 220), C(120, 220, 255), C(200, 150, 255) }
	for _ = 1, 8 do
		local x, z = rng:NextNumber(-170, 170), rng:NextNumber(-160, 160)
		local y = g + rng:NextNumber(12, 22)
		local c = jellyColors[rng:NextInteger(1, 3)]
		oct(amb, "JellyDome", 5, 2.5, at(x, y, z), c, NEON)
		for i = 0, 3 do
			block(amb, "Tentacle", V(0.4, 5, 0.4), at(x + (i - 1.5) * 1.1, y - 3.5, z), c, NEON, 0.3)
		end
		local core = makePart(amb, "JellyCore", V(1, 1, 1), at(x, y, z), c, NEON, 1)
		local light = Instance.new("PointLight")
		light.Color = c
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = core
	end
	for _, s in ipairs({ { -120, 90 }, { 120, 115 }, { 0, -140 }, { 60, 40 } }) do
		emitter(amb, P(s[1], s[2]) + V(0, g + 1, 0), V(40, 1, 40), { color = C(210, 240, 255), rate = 8, size = 0.5, life = 6, speed = 3, accel = V(0, 1, 0), transparency = 0.35 })
	end
end

local function ensureBiomeDetails(world, ground)
	for index, biome in ipairs(Config.Biomes) do
		local model = world:FindFirstChild("Biome_" .. biome.key)
		local build = BIOME_DETAILS[biome.key]
		if model and build and not model:FindFirstChild("Decor") then
			local decor = Instance.new("Model")
			decor.Name = "Decor"
			decor.Parent = model
			local ambient = Instance.new("Model")
			ambient.Name = "Ambient"
			ambient.Parent = model
			local rng = Random.new(2000 + index)
			local keep = {}
			local spot = LANDMARK_SPOTS[biome.key]
			if spot then
				table.insert(keep, { spot[1], spot[2], spot[3] })
			end
			for z = -160, 160, 40 do
				table.insert(keep, { 0, z, 16 }) -- keep the middle open for walking + fights
			end
			local function P(rx, rz)
				return V(biome.center.X + rx, 0, biome.center.Y + rz)
			end
			local function at(rx, y, rz)
				return CF(biome.center.X + rx, y, biome.center.Y + rz)
			end
			local function clear(pos, r)
				local props = model:FindFirstChild("Props")
				if props then
					for _, p in ipairs(props:GetChildren()) do
						if p:IsA("BasePart") and Vector2.new(p.Position.X - pos.X, p.Position.Z - pos.Z).Magnitude < r then
							p:Destroy()
						end
					end
				end
			end
			local function pick(r)
				for _ = 1, 50 do
					local x = rng:NextNumber(-178 + r, 178 - r)
					local z = rng:NextNumber(-170 + r, 170 - r)
					local ok = true
					for _, k in ipairs(keep) do
						if Vector2.new(x - k[1], z - k[2]).Magnitude < r + k[3] then
							ok = false
							break
						end
					end
					if ok then
						table.insert(keep, { x, z, r })
						return x, z
					end
				end
				return nil
			end
			build(decor, ambient, rng, biome, ground, keep, pick, P, clear, at)
			for _, p in ipairs(ambient:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
				end
			end
		end
	end
end

local function ensureLandmarks(world, ground)
	for _, biome in ipairs(Config.Biomes) do
		local model = world:FindFirstChild("Biome_" .. biome.key)
		local build = BIOME_LANDMARKS[biome.key]
		local spot = LANDMARK_SPOTS[biome.key]
		if model and build and spot and not model:FindFirstChild("Landmark") then
			local lm = Instance.new("Model")
			lm.Name = "Landmark"
			lm.Parent = model
			local lx, lz = biome.center.X + spot[1], biome.center.Y + spot[2]
			build(lm, lx, lz, ground)
			-- remove small props that would be inside the landmark
			local props = model:FindFirstChild("Props")
			if props then
				for _, p in ipairs(props:GetChildren()) do
					if p:IsA("BasePart") and Vector2.new(p.Position.X - lx, p.Position.Z - lz).Magnitude < spot[3] then
						p:Destroy()
					end
				end
			end
		end
	end
end

local function ensureBiomes(world)
	local island = world:FindFirstChild("Island")
	local ground = island and (island.Position.Y + island.Size.Y / 2) or 1
	for index, biome in ipairs(Config.Biomes) do
		if biome.tiles and not world:FindFirstChild("Biome_" .. biome.key) then
			local model = Instance.new("Model")
			model.Name = "Biome_" .. biome.key
			model.Parent = world
			local cx, cz = biome.center.X, biome.center.Y
			local hx, hz = biome.size.X / 2, biome.size.Y / 2

			local base = makePart(model, "Ground", Vector3.new(biome.size.X, 4, biome.size.Y),
				CFrame.new(cx, ground - 2, cz), rgb(biome.tiles[1]), Enum.Material.Plastic)
			base.TopSurface = Enum.SurfaceType.Studs

			-- studded checker tiles, all flush
			local tiles = Instance.new("Model")
			tiles.Name = "Tiles"
			tiles.Parent = model
			for i = 0, math.floor(biome.size.X / BIOME_TILE) - 1 do
				for j = 0, math.floor(biome.size.Y / BIOME_TILE) - 1 do
					local t = Instance.new("Part")
					t.Name = "Tile"
					t.Anchored = true
					t.CanCollide = false
					t.CanQuery = false
					t.CanTouch = false
					t.CastShadow = false
					t.Material = Enum.Material.Plastic
					t.Color = rgb(biome.tiles[((i + j) % 2) + 1])
					t.TopSurface = Enum.SurfaceType.Studs
					t.BottomSurface = Enum.SurfaceType.Smooth
					t.Size = Vector3.new(BIOME_TILE, 0.2, BIOME_TILE)
					t.Position = Vector3.new(cx - hx + (i + 0.5) * BIOME_TILE, ground - 0.06, cz - hz + (j + 0.5) * BIOME_TILE)
					t.Parent = tiles
				end
			end

			local props = Instance.new("Model")
			props.Name = "Props"
			props.Parent = model
			local rng = Random.new(1000 + index)
			local function spot()
				return Vector3.new(
					math.floor(cx + rng:NextNumber(-hx + 60, hx - 60)), -- keep clear of the side mountains
					ground,
					math.floor(cz + rng:NextNumber(-hz + 16, hz - 16))
				)
			end
			local builder = BIOME_PROPS[biome.key]
			if builder then
				builder(props, rng, spot, biome, ground)
			end

			-- side mountains like the lobby's: 3 blocks deep on both edges,
			-- tallest at the edge, colored to match the biome
			local COL, CAP_H = 16, 3
			local SIDE = { 40, 28, 14 }
			local colors = biome.mountain or { dirt = { { 135, 90, 52 }, { 118, 78, 45 } }, cap = { { 118, 201, 94 }, { 96, 178, 76 } } }
			local mountain = Instance.new("Model")
			mountain.Name = "Mountain"
			mountain.Parent = model
			for _, side in ipairs({ -1, 1 }) do
				for k, baseH in ipairs(SIDE) do
					local x = cx + side * (hx - (k - 0.5) * COL)
					for r = 0, math.floor(biome.size.Y / COL) - 1 do
						local z = cz - hz + (r + 0.5) * COL
						-- uses world z, so the ridge continues smoothly from biome to biome
						local bump = 9 * math.sin(z / 29 + side) + 6 * math.cos(z / 17 + k)
						local h = math.min(44, math.max(8, math.floor((baseH + bump * (1.2 - k * 0.25)) / 4 + 0.5) * 4))
						local c = ((r + k) % 2) + 1
						block(mountain, "Dirt", Vector3.new(COL, h - CAP_H, COL), CFrame.new(x, ground + (h - CAP_H) / 2, z), rgb(colors.dirt[c]))
						block(mountain, "Cap", Vector3.new(COL, CAP_H, COL), CFrame.new(x, ground + h - CAP_H / 2, z), rgb(colors.cap[c]))
					end
				end
			end
		end
	end

	ensureLandmarks(world, ground)
	ensureBiomeDetails(world, ground)

	-- invisible walls around the whole world so nobody falls off. Parts can
	-- be at most 2048 long, so the long sides are built in pieces (one per
	-- biome) - before, the ends of the map had no wall. Tall, with a lid, so
	-- jumping off the mountain tops can't get anyone out.
	local oldBounds = world:FindFirstChild("WorldBounds")
	if oldBounds then
		oldBounds:Destroy()
	end
	do
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, b in ipairs(Config.Biomes) do
			minX = math.min(minX, b.center.X - b.size.X / 2)
			maxX = math.max(maxX, b.center.X + b.size.X / 2)
			minZ = math.min(minZ, b.center.Y - b.size.Y / 2)
			maxZ = math.max(maxZ, b.center.Y + b.size.Y / 2)
		end
		local bounds = Instance.new("Model")
		bounds.Name = "WorldBounds"
		bounds.Parent = world
		local H = 600
		local w = maxX - minX
		local cxw = (minX + maxX) / 2
		local specs = {
			{ Vector3.new(w + 4, H, 2), Vector3.new(cxw, H / 2 - 20, minZ - 1) },
			{ Vector3.new(w + 4, H, 2), Vector3.new(cxw, H / 2 - 20, maxZ + 1) },
		}
		for _, b in ipairs(Config.Biomes) do
			local z0, z1 = b.center.Y - b.size.Y / 2, b.center.Y + b.size.Y / 2
			table.insert(specs, { Vector3.new(2, H, z1 - z0 + 2), Vector3.new(minX - 1, H / 2 - 20, (z0 + z1) / 2) })
			table.insert(specs, { Vector3.new(2, H, z1 - z0 + 2), Vector3.new(maxX + 1, H / 2 - 20, (z0 + z1) / 2) })
			table.insert(specs, { Vector3.new(w + 4, 2, b.size.Y + 2), Vector3.new(cxw, H - 20, b.center.Y) }) -- lid
		end
		for _, spec in ipairs(specs) do
			local wall = makePart(bounds, "Bound", spec[1], CFrame.new(spec[2]), Color3.new(1, 1, 1), Enum.Material.Plastic, 1)
			wall.CanCollide = true
			wall.CanQuery = false
			wall.CanTouch = false
		end
	end
end

local function ensureSellStall(world)
		ensureGroundTiles(world)
	local hub = world:FindFirstChild("Hub")
	if not hub then
		return
	end
	for _, oldName in ipairs({ "UpgradeSell", "DiceShop" }) do
		local oldStall = hub:FindFirstChild(oldName)
		if oldStall then
			oldStall:Destroy()
		end
	end
	local sellStall = hub:FindFirstChild("SellStall") or buildSellStall(hub, Vector3.new(-25, 1, 0))
	spawnMerchantNpc(sellStall, SELLER_USER_ID, "Kaiden", "SellPrompt")
	local diceStall = hub:FindFirstChild("DiceStall") or buildDiceStall(hub, Vector3.new(25, 1, 0))
	spawnMerchantNpc(diceStall, baconDescription, "Scripter", "DicePrompt")
	ensureStallTitle(sellStall, "Sell Shop", Config.StallIcons and Config.StallIcons.SellStall)
	ensureStallTitle(diceStall, "Dice Shop", Config.StallIcons and Config.StallIcons.DiceStall)
	-- Gear Shop: Kurt, on the north side of the plaza facing the middle
	local gearStall = hub:FindFirstChild("GearStall")
		or buildMerchantStall(hub, "GearStall", Vector3.new(0, 1, 27), "GEAR SHOP", Color3.fromRGB(80, 200, 110), "Kurt", "Shop", "GearPrompt")
	spawnMerchantNpc(gearStall, 64331866, "Kurt", "GearPrompt")
	ensureStallTitle(gearStall, "Gear Shop", Config.StallIcons and Config.StallIcons.GearStall)
	-- Guild Hall: the Guild Master, on the south side of the plaza facing the middle
	local guildStall = hub:FindFirstChild("GuildStall")
		or buildMerchantStall(hub, "GuildStall", Vector3.new(0, 1, -27), "GUILDS", Color3.fromRGB(150, 80, 230), "Guild Master", "Guilds", "GuildPrompt")
	spawnMerchantNpc(guildStall, 156, "Guild Master", "GuildPrompt")
	ensureStallTitle(guildStall, "Guild Hall", Config.StallIcons and Config.StallIcons.GuildStall)
end

local function buildHub(parent)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = parent

	addStudFloor(
		hub,
		"PlazaFloor",
		Vector3.new(110, 0.6, 110),
		CFrame.new(0, 0.75, 0),
		Color3.fromRGB(150, 100, 58)
	)

	buildStall(hub, "DiceAltar", Vector3.new(0, 1, -25), Color3.fromRGB(114, 91, 255), "Dice Altar", "Roll")
	buildSellStall(hub, Vector3.new(-25, 1, 0))
	buildDiceStall(hub, Vector3.new(25, 1, 0))
	buildStall(hub, "PvPArena", Vector3.new(0, 1, 25), Color3.fromRGB(255, 90, 90), "PvP Arena", "Open")

	return hub
end

--------------------------------------------------------------------
-- Map
--------------------------------------------------------------------

function WorldService.BuildMap()
	if Workspace:FindFirstChild("MonsterRNGWorld") then
		-- The map is saved into the place (built once in Edit mode) so it's
		-- visible and editable in Studio. Island/road/hub/decor are reused
		-- as-is; pens carry live per-server state (owner, sign refs, pet
		-- loops), so any saved copies are rebuilt fresh in the same spots.
		world = Workspace.MonsterRNGWorld
		setupLighting()
		for _, child in ipairs(world:GetChildren()) do
			if child:IsA("Model") and (child.Name:match("^Pen_%d+$") or child.Name:match("^Base_%d+$")) then
				child:Destroy()
			end
		end
		buildAllPens()
		ensureMapCleanup(world)
		ensureSellStall(world)
		ensureMountain(world)
		ensureBiomes(world)
		ensureGroundTiles(world)
		return world
	end

	setupLighting()

	world = Instance.new("Folder")
	world.Name = "MonsterRNGWorld"
	world.Parent = Workspace

	makePart(
		world,
		"Island",
		Vector3.new(480, 4, 400),
		CFrame.new(0, -1, 60),
		Color3.fromRGB(89, 189, 92),
		Enum.Material.Plastic
	)
	makePart(
		world,
		"VerticalRoad",
		Vector3.new(24, 0.25, 290),
		CFrame.new(0, 1.125, 5),
		Color3.fromRGB(214, 214, 222),
		Enum.Material.Plastic
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MonsterRNGSpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 1, -64)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = world

	buildHub(world)

	-- Cheerful bushes and flowers instead of glowing floating crystals
	local bushSpots = {
		Vector3.new(-200, 1, -100),
		Vector3.new(200, 1, -100),
		Vector3.new(-205, 1, 70),
		Vector3.new(205, 1, 70),
		Vector3.new(-70, 1, -125),
		Vector3.new(70, 1, -125),
	}
	for _, spot in ipairs(bushSpots) do
		addBush(world, spot)
	end

	local flowerColors = {
		Color3.fromRGB(255, 105, 140),
		Color3.fromRGB(255, 210, 80),
		Color3.fromRGB(140, 190, 255),
	}
	for i = 1, 28 do
		local side = (i % 2 == 0) and 1 or -1
		local x = side * math.random(20, 60)
		local z = math.random(-130, 90)
		addFlower(world, Vector3.new(x, 1, z), flowerColors[math.random(1, #flowerColors)])
	end

	buildAllPens()
	ensureMapCleanup(world)
	ensureSellStall(world)
	ensureMountain(world)
	ensureBiomes(world)
		ensureGroundTiles(world)

	return world
end

--------------------------------------------------------------------
-- Player pens: open, fenced, side by side
--------------------------------------------------------------------

local function buildFence(model, position, gateSide)
	local postHeight = 5
	local WOOD = Color3.fromRGB(133, 94, 58)
	local GATE_HALF = 7 -- half-width of the front opening
	local SPACING = 7 -- distance between posts

	local function studs(part)
		for _, face in ipairs(STUD_FACES) do
			part[face] = Enum.SurfaceType.Studs
		end
	end

	local function post(x, z)
		local p = makePart(model, "FencePost", Vector3.new(1.2, postHeight, 1.2),
			CFrame.new(position + Vector3.new(x, postHeight / 2, z)), WOOD, Enum.Material.Plastic)
		studs(p)
	end

	-- a straight fence run: posts every SPACING studs and two solid rails
	local function run(x1, z1, x2, z2)
		local a, b = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
		local d = b - a
		local length = d.Magnitude
		local count = math.max(1, math.ceil(length / SPACING))
		for i = 0, count do
			local p = a:Lerp(b, i / count)
			post(p.X, p.Z)
		end
		local mid = (a + b) / 2
		local rot = math.atan2(-d.Z, d.X)
		for _, h in ipairs({ 1.6, postHeight - 1.4 }) do
			local rail = makePart(model, "FenceRail", Vector3.new(length, 1, 0.6),
				CFrame.new(position + mid + Vector3.new(0, h, 0)) * CFrame.Angles(0, rot, 0), WOOD, Enum.Material.Plastic)
			rail.CanCollide = true
			studs(rail)
		end
	end

	local X, Z = PEN_HALF_X, PEN_HALF_Z
	local edges = {
		["-Z"] = { -X, -Z, X, -Z },
		["+Z"] = { -X, Z, X, Z },
		["-X"] = { -X, -Z, -X, Z },
		["+X"] = { X, -Z, X, Z },
	}
	for side, e in pairs(edges) do
		if side == (gateSide or "-Z") then
			-- this side has the opening in the middle
			local a, b = Vector3.new(e[1], 0, e[2]), Vector3.new(e[3], 0, e[4])
			local mid, dir = (a + b) / 2, (b - a).Unit
			local g1, g2 = mid - dir * GATE_HALF, mid + dir * GATE_HALF
			run(a.X, a.Z, g1.X, g1.Z)
			run(g2.X, g2.Z, b.X, b.Z)
		else
			run(e[1], e[2], e[3], e[4])
		end
	end
end

local function createOwnerSign(model, position)
	-- invisible anchor high above the middle of the pen
	local pole = makePart(
		model,
		"SignPole",
		Vector3.new(1, 1, 1),
		CFrame.new(position + Vector3.new(0, 30, 0)),
		Color3.fromRGB(133, 94, 58),
		Enum.Material.Plastic,
		1
	)
	pole.CanCollide = false
	pole.CanQuery = false
	pole.CanTouch = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OwnerDisplay"
	-- sized in studs, so it gets smaller with distance like a real sign
	billboard.Size = UDim2.new(8, 0, 9.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 500
	billboard.Parent = pole

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "Avatar"
	avatarImage.Size = UDim2.fromScale(0.72, 0.62)
	avatarImage.Position = UDim2.fromScale(0.5, 0)
	avatarImage.AnchorPoint = Vector2.new(0.5, 0)
	avatarImage.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
	avatarImage.BorderSizePixel = 0
	avatarImage.Image = ""
	avatarImage.Parent = frame
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = avatarImage
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatarImage
	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Thickness = 3
	avatarStroke.Color = Color3.fromRGB(10, 15, 35)
	avatarStroke.Parent = avatarImage

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.28)
	nameLabel.Position = UDim2.fromScale(0, 0.7)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.LuckiestGuy
	nameLabel.Text = "OPEN"
	nameLabel.Parent = frame

	return { avatarImage = avatarImage, nameLabel = nameLabel }
end

local function createPenSpawn(model, position, gateSide)
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "PenSpawn"
	spawnPart.Size = Vector3.new(6, 1, 6)
	spawnPart.Anchored = true
	spawnPart.CanCollide = false
	spawnPart.Neutral = true
	spawnPart.Transparency = 1
	local inside = ({
		["-Z"] = Vector3.new(0, 1, -PEN_HALF_Z + 6),
		["+Z"] = Vector3.new(0, 1, PEN_HALF_Z - 6),
		["-X"] = Vector3.new(-PEN_HALF_X + 6, 1, 0),
		["+X"] = Vector3.new(PEN_HALF_X - 6, 1, 0),
	})[gateSide or "-Z"]
	spawnPart.CFrame = CFrame.new(position + inside)
	spawnPart.Parent = model
	return spawnPart
end

--------------------------------------------------------------------
-- Pet display + AI (roam inside the pen, follow the owner outside it)
--------------------------------------------------------------------

-- eggs rest on the floor; now and then they give a small wiggle
local function animateEggBob(model, body, homePosition, bodySize)
	task.spawn(function()
		local half = bodySize * 1.35 / 2
		local base = homePosition - Vector3.new(0, half, 0)
		local nextWiggle = os.clock() + math.random() * 5
		body.CFrame = CFrame.new(homePosition)
		while model.Parent and body.Parent do
			if os.clock() >= nextWiggle then
				local start = os.clock()
				while model.Parent and body.Parent and os.clock() - start < 0.7 do
					local k = (os.clock() - start) / 0.7
					local tilt = math.sin(k * math.pi * 4) * math.rad(7) * (1 - k)
					body.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, half, 0)
					task.wait(0.03)
				end
				body.CFrame = CFrame.new(homePosition)
				nextWiggle = os.clock() + 4 + math.random() * 5
			end
			task.wait(0.1)
		end
	end)
end

-- Shake that builds up over Config.HatchShakeTime, then the server
-- swaps the egg for the monster (see WorldService.MarkHatched).
-- hatching: rocks harder and faster on its base, rattles, and cracks
local function animateEggShake(model, body, homePosition, baseSize, glow, startedAt)
	local sounds = Config.Sounds or {}
	local rattle
	if sounds.hatchRattle then
		rattle = Instance.new("Sound")
		rattle.SoundId = sounds.hatchRattle
		rattle.Looped = true
		rattle.Volume = 1
		rattle.RollOffMinDistance = 40 -- loud enough from the normal camera distance
		rattle.RollOffMaxDistance = 140
		rattle.Parent = body
		rattle:Play()
	end
	local cracksAt = { 0.35, 0.6, 0.8, 0.95 }
	local nextCrack = 1
	task.spawn(function()
		local half = baseSize.Y / 2
		local base = homePosition - Vector3.new(0, half, 0)
		while model.Parent and body.Parent do
			local t = math.clamp((os.clock() - startedAt) / Config.HatchShakeTime, 0, 1)
			local speed = 14 + t * 30
			local wobble = math.sin(os.clock() * speed)
			local tilt = math.rad(5 + t * t * 20)
			local hop = t > 0.7 and math.abs(math.sin(os.clock() * speed * 0.5)) * baseSize.Y * 0.06 * (t - 0.7) / 0.3 or 0
			body.Size = baseSize * (1 + t ^ 3 * 0.12)
			body.CFrame = CFrame.new(base + Vector3.new(0, hop, 0)) * CFrame.Angles(0, 0, wobble * tilt) * CFrame.new(0, half, 0)
			if glow then
				glow.Brightness = 1.5 + t * 4
			end
			-- cracking sounds as it gets close
			if sounds.eggCrack and cracksAt[nextCrack] and t >= cracksAt[nextCrack] then
				nextCrack += 1
				local crack = Instance.new("Sound")
				crack.SoundId = sounds.eggCrack[math.random(1, #sounds.eggCrack)]
				crack.Volume = 1
				crack.RollOffMinDistance = 40
				crack.RollOffMaxDistance = 140
				crack.PlaybackSpeed = 0.9 + math.random() * 0.25
				crack.Parent = body
				crack:Play()
				game:GetService("Debris"):AddItem(crack, 3)
			end
			task.wait(0.03)
		end
	end)
end

local function createEggDisplay(parent, entry, index, slotPosition)
	local rarity = Config.GetRarity(entry.rarity)
	local bodyColor = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
	local bodySize = 3.4

	-- sit on the pen floor (not floating)
	do
		local ignore = { parent }
		for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
			if plr.Character then
				table.insert(ignore, plr.Character)
			end
		end
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(slotPosition + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rp)
		if hit then
			slotPosition = Vector3.new(slotPosition.X, hit.Position.Y + bodySize * 1.35 / 2, slotPosition.Z)
		end
	end

	local model = Instance.new("Model")
	model.Name = entry.uid
	model.Parent = parent
	model:SetAttribute("Kind", "egg")

	local body = makePart(
		model,
		"MonsterBody",
		Vector3.new(bodySize, bodySize * 1.35, bodySize),
		CFrame.new(slotPosition),
		bodyColor,
		Enum.Material.Neon
	)
	body.Shape = Enum.PartType.Ball
	body.CanCollide = false
	-- the ball is now an invisible center; the blocky egg is welded to it
	body.Transparency = 1
	body.Material = Enum.Material.SmoothPlastic
	require(game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("EggModel")).Build(body, bodySize * 1.35, bodyColor, entry.finish, entry.rarity)
	-- with StreamingEnabled, send the whole egg at once
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local glow = Instance.new("PointLight")
	glow.Color = bodyColor
	glow.Range = 8 + rarity.tier * 1.5
	glow.Brightness = 0.5 + rarity.tier * 0.15 -- soft, so the egg keeps its color
	glow.Parent = body

	local ready = os.time() >= entry.readyAt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ObjectText = rarity.name .. " Egg"
	prompt.ActionText = "Hatch"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	-- off for everyone: the owner's client turns it on once the egg is ready,
	-- so nobody sees "Incubating..." and other players never see your prompt
	prompt.Enabled = false
	prompt.Parent = body
	model:SetAttribute("ReadyAt", entry.readyAt)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MonsterName"
	billboard.Size = UDim2.fromOffset(170, 46)
	billboard.StudsOffset = Vector3.new(0, bodySize + 1, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 25
	billboard.Enabled = false -- egg info now lives in the Eggs panel (middle-right)
	billboard.Parent = body

	local nameFrame = Instance.new("Frame")
	nameFrame.Size = UDim2.fromScale(1, 1)
	nameFrame.BackgroundColor3 = Color3.fromRGB(10, 13, 26)
	nameFrame.BackgroundTransparency = 0.35
	nameFrame.BorderSizePixel = 0
	nameFrame.Parent = billboard
	Instance.new("UICorner", nameFrame).CornerRadius = UDim.new(0, 10)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = bodyColor
	ringStroke.Thickness = 1.5
	ringStroke.Parent = nameFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = entry.hatching and (rarity.name .. " Egg\nHatching!")
		or ready and (rarity.name .. " Egg\nReady! Press E")
		or (rarity.name .. " Egg\nIncubating...")
	label.TextColor3 = bodyColor
	label.TextStrokeTransparency = 0.35
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Parent = nameFrame

	if not ready and not entry.hatching then
		task.spawn(function()
			while model.Parent and os.time() < entry.readyAt do
				task.wait(0.5)
			end
			if model.Parent then
				prompt.ActionText = "Hatch"
				label.Text = rarity.name .. " Egg\nReady! Press E"
			end
		end)
	end

	model.PrimaryPart = body
	if entry.hatching then
		prompt.Enabled = false
		animateEggShake(model, body, slotPosition, body.Size, glow, entry.hatchStartedAt or os.clock())
	else
		animateEggBob(model, body, slotPosition, bodySize)
	end
end

-- Obstacles pets walk around (not pens/fences, so they can leave the pen).
local obstacleParams
local obstacleRefreshedAt = -math.huge
local function getObstacleParams()
	if obstacleParams and os.clock() - obstacleRefreshedAt < 30 then
		return obstacleParams
	end
	local list = {}
	local w = workspace:FindFirstChild("MonsterRNGWorld")
	if w then
		for _, c in ipairs(w:GetChildren()) do
			if c.Name:match("^Biome_") then
				for _, n in ipairs({ "Landmark", "Props", "Mountain", "Decor" }) do
					local m = c:FindFirstChild(n)
					if m then
						table.insert(list, m)
					end
				end
			elseif c.Name == "Mountain" then
				table.insert(list, c)
			elseif c.Name == "Hub" then
				for _, n in ipairs({ "SellStall", "DiceStall", "GearStall", "GuildStall" }) do
					local m = c:FindFirstChild(n)
					if m then
						table.insert(list, m)
					end
				end
			end
		end
	end
	obstacleParams = RaycastParams.new()
	obstacleParams.FilterType = Enum.RaycastFilterType.Include
	obstacleParams.FilterDescendantsInstances = list
	obstacleRefreshedAt = os.clock()
	return obstacleParams
end

-- if something is in the way, try turning 40/80/120 degrees either side
local AVOID_ANGLES = { 0, 40, -40, 80, -80, 120, -120 }
local function avoidObstacles(current, step, radius)
	local len = step.Magnitude
	if len < 0.01 then
		return step
	end
	local params = getObstacleParams()
	local dir = step.Unit
	for _, deg in ipairs(AVOID_ANGLES) do
		local d = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(dir)
		if not workspace:Raycast(current, d * (len + radius), params) then
			return d * len
		end
	end
	return Vector3.zero -- boxed in: wait a moment
end

-- turn smoothly toward a flat direction, at most maxTurn radians per call
local function turnToward(cf, look, maxTurn)
	local flat = Vector3.new(look.X, 0, look.Z)
	local cur = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flat.Magnitude < 0.01 or cur.Magnitude < 0.01 then
		return cf - cf.Position, 0
	end
	flat, cur = flat.Unit, cur.Unit
	local curYaw = math.atan2(-cur.X, -cur.Z)
	local wantYaw = math.atan2(-flat.X, -flat.Z)
	local diff = (wantYaw - curYaw + math.pi) % (math.pi * 2) - math.pi
	local turn = math.clamp(diff, -maxTurn, maxTurn)
	return CFrame.Angles(0, curYaw + turn, 0), math.abs(diff - turn)
end

local function animatePetBody(model, body, homePosition, bodySize, penState)
	task.spawn(function()
		local phase = math.random() * math.pi * 2
		local wanderTarget = homePosition
		local nextWanderAt = 0

		while model.Parent and body.Parent do
			if model:GetAttribute("Dying") then
				task.wait(0.1)
				continue -- lying where it fell
			end
			local now = os.clock()
			-- Unequip only while it's in the pen, not while following you
			local unequipPrompt = body:FindFirstChild("Prompt")
			if unequipPrompt then
				unequipPrompt.Enabled = penState.nearby == true
			end

			if penState.nearby then
				if now >= nextWanderAt then
					-- wander anywhere INSIDE the pen fence (never outside it)
					local center = model.Parent and model.Parent:GetAttribute("BasePosition") or homePosition
					local margin = 4 + bodySize * 0.6
					local hx, hz = math.max(1, PEN_HALF_X - margin), math.max(1, PEN_HALF_Z - margin)
					local rx = math.random(-hx * 10, hx * 10) / 10
					local rz = math.random(-hz * 10, hz * 10) / 10
					wanderTarget = Vector3.new(center.X + rx, homePosition.Y, center.Z + rz)
					nextWanderAt = now + math.random(2, 4)
				end

				local current = body.Position
				local direction = wanderTarget - current
				local distance = direction.Magnitude
				local bob = math.sin(now * 3 + phase) * (bodySize * 0.06)

				local rot, left = turnToward(body.CFrame, direction, math.rad(24))
				if distance > 0.6 then
					-- still turning a lot: walk slowly until it faces the way it goes
					local step
					if left > math.rad(50) then
						-- still turning around: curve along the way it faces (no sliding backwards)
						step = rot.LookVector * math.min(distance, 0.2)
					else
						step = direction.Unit * math.min(distance, 0.6)
					end
					body.CFrame = CFrame.new(current + step + Vector3.new(0, bob, 0)) * rot
				else
					body.CFrame = CFrame.new(wanderTarget + Vector3.new(0, bob, 0)) * (body.CFrame - body.CFrame.Position)
				end
			elseif penState.ownerPosition then
				local formationIndex = model:GetAttribute("FormationIndex") or 1
				local row = math.floor((formationIndex - 1) / 3)
				local col = (formationIndex - 1) % 3
				local look = penState.ownerLook or Vector3.new(0, 0, -1)
				local right = Vector3.new(look.Z, 0, -look.X)
				if right.Magnitude > 0.001 then
					right = right.Unit
				end
				local sideOffset = (col - 1) * 4
				local backOffset = FOLLOW_DISTANCE + row * 5

				local targetPos = penState.ownerPosition - look * backOffset + right * sideOffset
				-- fighting: circle the enemy, lunging in on each hit
				local petTarget = penState.petTargets and penState.petTargets[model.Name]
				local target = petTarget and petTarget[1]
				if target then
					local ang = formationIndex * (math.pi * 2 / 6)
					local radius = (petTarget[2] or 3) + bodySize * 0.6 + 2
					targetPos = target + Vector3.new(math.cos(ang) * radius, 0, math.sin(ang) * radius)
				end
				targetPos = Vector3.new(targetPos.X, homePosition.Y, targetPos.Z)
				local current = body.Position
				local direction = targetPos - current
				local distance = direction.Magnitude
				local ownerDist = Vector2.new(current.X - penState.ownerPosition.X, current.Z - penState.ownerPosition.Z).Magnitude
				if not target and ownerDist > 60 then
					-- far behind YOU (you teleported etc.): jump back to you.
					-- Never teleport onto an enemy - pets always walk into a fight
					body.CFrame = CFrame.new(targetPos)
				elseif distance > 0.5 then
					-- the further behind, the faster it moves, so it keeps pace
					-- walking pace (~20 studs/s) toward a fight; faster only to catch up with you
					local maxStep = target and 1.0 or math.max(1.2, distance * 0.35)
					local step = direction.Unit * math.min(distance, maxStep)
					-- walk around landmarks instead of through them
					step = avoidObstacles(current, step, bodySize * 0.5)
					local look = step.Magnitude > 0.01 and step or direction
					if target then
						-- fighting: always keep facing the enemy (even when stepping back)
						local toEnemy = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
						if toEnemy.Magnitude > 0.1 then
							look = toEnemy
						end
					end
					local rot = turnToward(body.CFrame, look, math.rad(20))
					body.CFrame = CFrame.new(current + step) * rot
				elseif target then
					-- in position: turn to face the enemy
					local toEnemy = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
					if toEnemy.Magnitude > 0.1 then
						local rot = turnToward(body.CFrame, toEnemy, math.rad(20))
						body.CFrame = CFrame.new(current) * rot
					end
				end
			end

			task.wait(penState.nearby and 0.1 or 0.05) -- smoother while following
		end
	end)
end

local function createMonsterDisplay(parent, entry, index, slotPosition, penState)
	local monster = Config.GetMonster(entry.monsterId)
	if not monster then
		return
	end

	local rarity = Config.GetRarity(monster.rarity)
	local sizeVariant = Config.GetSizeVariant(entry.size)
	local model = Instance.new("Model")
	model.Name = entry.uid
	model.Parent = parent
	model:SetAttribute("FormationIndex", index)
	model:SetAttribute("Kind", "monster")

	local bodySize = 4 * sizeVariant.scale
	local bodyColor = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
	if entry.defeated then
		bodyColor = Color3.fromRGB(95, 100, 115) -- defeated: grey, rests in the pen
	elseif entry.finish == "Gold" then
		bodyColor = Color3.fromRGB(255, 190, 55)
	elseif entry.finish == "Silver" then
		bodyColor = Color3.fromRGB(211, 223, 239)
	elseif entry.finish == "Rainbow" then
		bodyColor = Color3.fromHSV((index * 0.17) % 1, 0.8, 1)
	end

	local body = makePart(
		model,
		"MonsterBody",
		Vector3.new(bodySize, bodySize, bodySize),
		CFrame.new(slotPosition),
		bodyColor,
		entry.finish == "Normal" and Enum.Material.SmoothPlastic or Enum.Material.Neon
	)
	body.Shape = Enum.PartType.Ball
	body.CanCollide = false
	-- the ball is now an invisible center; the cartoony studded monster
	-- model hangs on it (animated on each player's screen)
	body.Transparency = 1
	body.Material = Enum.Material.SmoothPlastic
	require(game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("MonsterModel")).Build(body, bodySize, {
		monsterId = entry.monsterId,
		groundOffset = bodySize * 0.5,
		finish = entry.finish,
		defeated = entry.defeated,
	})

	local glow = Instance.new("PointLight")
	glow.Color = bodyColor
	glow.Range = 8 + rarity.tier * 1.5
	glow.Brightness = 0.4 + rarity.tier * 0.15
	glow.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ObjectText = monster.name
	prompt.ActionText = "Unequip"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body

	-- info over the monster's head (4 lines):
	--   Name              (white)
	--   Rarity            (rarity color, Common = white)
	--   $cash/s  -  odds  (yellow)
	--   kg  -  Lv         (green)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MonsterName"
	billboard.Size = UDim2.fromOffset(170, 78)
	billboard.MaxDistance = 28 -- only shows when the monster is near you
	billboard.StudsOffset = Vector3.new(0, bodySize * 1.45 + 0.5, 0) -- above the model's head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = body

	local nameFrame = Instance.new("Frame")
	nameFrame.Size = UDim2.fromScale(1, 1)
	nameFrame.BackgroundTransparency = 1
	nameFrame.Parent = billboard
	local lines = Instance.new("UIListLayout")
	lines.SortOrder = Enum.SortOrder.LayoutOrder
	lines.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lines.VerticalAlignment = Enum.VerticalAlignment.Bottom
	lines.Parent = nameFrame

	local DOT = "  \226\128\162  "
	local odds = Config.FormatOdds(Config.GetOdds(entry.monsterId, entry.size, entry.finish, entry.kg))
	local infoLines = {
		{ Config.BuildDisplayName(monster.name, entry.size, entry.finish), Color3.fromRGB(245, 245, 245), 0.28 },
		-- rarity in its own color (Common is plain white)
		{ rarity.name, rarity.key == "Common" and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3]), 0.24 },
		{ "$" .. Config.FormatNumber(WorldService.GetEntryIncome(entry)) .. "/s" .. DOT .. odds, Color3.fromRGB(255, 222, 60), 0.24 },
		{ Config.FormatKg(entry.kg) .. DOT .. "Lv. " .. (entry.level or 1), Color3.fromRGB(95, 225, 85), 0.24 },
	}
	for i, info in ipairs(infoLines) do
		local line = Instance.new("TextLabel")
		line.Name = "Line" .. i
		line.LayoutOrder = i
		line.Size = UDim2.fromScale(1, info[3])
		line.BackgroundTransparency = 1
		line.Text = info[1]
		line.TextColor3 = entry.defeated and info[2]:Lerp(Color3.fromRGB(120, 125, 140), 0.6) or info[2]
		line.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
		line.TextStrokeTransparency = 0
		line.Font = Enum.Font.GothamBlack
		line.TextScaled = true
		line.Parent = nameFrame
	end

	model.PrimaryPart = body
	model:SetAttribute("Defeated", entry.defeated == true)
	-- defeated pets stay in the pen (they still earn cash) until revived
	local petState = entry.defeated and setmetatable({ nearby = true }, { __index = penState }) or penState
	animatePetBody(model, body, slotPosition, bodySize, petState)

	-- unequipping is done from the Monsters panel now, not in the pen
	local unequipPrompt = body:FindFirstChild("Prompt")
	if unequipPrompt then
		unequipPrompt:Destroy()
	end

	local hatchedAt = justHatched[entry.uid]
	if hatchedAt and os.clock() - hatchedAt < 1 then
		justHatched[entry.uid] = nil
		WorldService.PlayPopIn(body, billboard, entry)
	end
end

local function createSlotDisplay(parent, entry, index, penState)
	local basePosition = parent:GetAttribute("BasePosition")
	local offsetX = (entry.position and entry.position.x) or 0
	local offsetZ = (entry.position and entry.position.z) or 0
	local slotPosition = basePosition + Vector3.new(offsetX, 1.5, offsetZ)

	if entry.kind == "egg" then
		createEggDisplay(parent, entry, index, slotPosition + Vector3.new(0, 2, 0))
	else
		createMonsterDisplay(parent, entry, index, slotPosition, penState)
	end
end

local function startPenLoop(pen)
	-- Skip the owner-tracking loop when the map is being built in Edit
	-- mode (no players, and it would otherwise keep running in Studio).
	if not RunService:IsRunning() then
		return
	end
	task.spawn(function()
		while pen.model.Parent do
			local owner = pen.owner
			if owner then
				local character = owner.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					pen.state.nearby = owner:GetAttribute("InPvp") == true or (hrp.Position - pen.position).Magnitude <= PEN_RADIUS
					pen.state.ownerPosition = hrp.Position
					pen.state.ownerLook = hrp.CFrame.LookVector
				else
					pen.state.nearby = false
				end
			else
				pen.state.nearby = false
			end
			task.wait(0.05)
		end
	end)
end

function buildAllPens()
	for index, position in ipairs(basePositions) do
		local model = Instance.new("Model")
		model.Name = "Pen_" .. index
		model:SetAttribute("BasePosition", position)
		model.Parent = world

		addStudFloor(
			model,
			"PenFloor",
			Vector3.new(PEN_HALF_X * 2, 1, PEN_HALF_Z * 2),
			CFrame.new(position.X, position.Y - 0.45, position.Z),
			Color3.fromRGB(150, 100, 58)
		)
		buildFence(model, position, PEN_GATES[index])
		local display = createOwnerSign(model, position)
		local spawnPart = createPenSpawn(model, position, PEN_GATES[index])

		local pets = Instance.new("Folder")
		pets.Name = "Pets"
		pets.Parent = model
		pets:SetAttribute("BasePosition", position)

		local pen = {
			index = index,
			model = model,
			position = position,
			pets = pets,
			state = { nearby = false, ownerPosition = nil, ownerLook = nil },
			display = display,
			spawnPart = spawnPart,
			owner = nil,
		}
		table.insert(allPens, pen)
		startPenLoop(pen)
	end
end

function WorldService.CreateBase(player, profile)
	if not world then
		WorldService.BuildMap()
	end

	local pen
	for _, candidate in ipairs(allPens) do
		if not candidate.owner then
			pen = candidate
			break
		end
	end

	if not pen then
		warn("Monster RNG: no vacant pen available for " .. player.Name)
		return
	end

	pen.owner = player
	pen.model.Name = "Base_" .. player.UserId
	pen.display.nameLabel.Text = player.Name
	pen.display.avatarImage.Image = ""

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		if ok and pen.owner == player then
			pen.display.avatarImage.Image = content
		end
	end)

	player.RespawnLocation = pen.spawnPart

	pensByPlayer[player] = pen
	WorldService.UpdateBase(player, profile)
end

-- What a pet model shows; if this doesn't change, the model is kept.
local function entrySignature(entry)
	return table.concat({
		entry.kind or "",
		tostring(entry.hatching == true),
		tostring(entry.level or 1),
		entry.size or "",
		entry.finish or "",
		tostring(entry.readyAt or 0),
		tostring(entry.kg or 0),
		tostring(entry.defeated == true),
		tostring(entry.position and entry.position.x),
		tostring(entry.position and entry.position.z),
	}, "|")
end

-- Only rebuilds the pets that actually changed, so hatching / placing
-- one thing no longer makes every other pet blink.
function WorldService.UpdateBase(player, profile)
	local pen = pensByPlayer[player]
	if not pen then
		return
	end
	local wanted = {}
	for index, entry in ipairs(profile.base or {}) do
		wanted[entry.uid] = { entry = entry, index = index, sig = entrySignature(entry) }
	end
	for _, child in ipairs(pen.pets:GetChildren()) do
		local w = wanted[child.Name]
		if w and child:GetAttribute("Sig") == w.sig then
			w.keep = true
		else
			child:Destroy()
		end
	end
	for uid, w in pairs(wanted) do
		if not w.keep then
			createSlotDisplay(pen.pets, w.entry, w.index, pen.state)
			local model = pen.pets:FindFirstChild(uid)
			if model then
				model:SetAttribute("Sig", w.sig)
				model:SetAttribute("Hatching", w.entry.hatching == true)
			end
		end
	end
end

local function hatchInfoBillboard(parent, entry, offsetY)
	local monster = Config.GetMonster(entry.monsterId)
	local rarity = Config.GetRarity(monster and monster.rarity or "Common")
	local color = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])

	local gui = Instance.new("BillboardGui")
	gui.Name = "HatchInfo"
	gui.Size = UDim2.fromOffset(190, 88)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = parent

	local lines = {
		{ Config.BuildDisplayName(monster and monster.name or "Monster", entry.size, entry.finish), color, 0.38 },
		{ "$" .. WorldService.GetEntryIncome(entry) .. "/s", Color3.fromRGB(255, 205, 93), 0.3 },
		{ Config.FormatOdds(Config.GetOdds(entry.monsterId, entry.size, entry.finish, entry.kg)) .. "  \226\128\162  " .. Config.FormatKg(entry.kg), Color3.new(1, 1, 1), 0.28 },
	}
	local y = 0
	local labels = {}
	for _, line in ipairs(lines) do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, line[3])
		l.Position = UDim2.fromScale(0, y)
		l.BackgroundTransparency = 1
		l.Text = line[1]
		l.TextColor3 = line[2]
		l.TextScaled = true
		l.Font = Enum.Font.LuckiestGuy
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
		l.Parent = gui
		table.insert(labels, l)
		y += line[3]
	end
	return gui, labels
end

local function burstAt(position, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	p.Parent = world
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.LightEmission = 0.6
	emitter.Enabled = false
	emitter.Parent = p
	emitter:Emit(40)
	Debris:AddItem(p, 1.5)
end

-- Monster pops out of the egg: grows from tiny with a bounce, then shows
-- its name / cash per second / odds for Config.HatchInfoTime seconds.
function WorldService.PlayPopIn(body, overhead, entry)
	local fullSize = body.Size
	body.Size = fullSize * 0.1
	TweenService:Create(body, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = fullSize }):Play()
	if overhead then
		overhead.Enabled = false
	end
	local info, labels = hatchInfoBillboard(body, entry, fullSize.Y / 2 + 4)
	task.delay(Config.HatchInfoTime, function()
		for _, l in ipairs(labels) do
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.wait(0.3)
		info:Destroy()
		if overhead and overhead.Parent then
			overhead.Enabled = true
		end
	end)
end

-- Called by the server the moment an egg finishes shaking.
local function playRevealAt(position)
	local id = Config.Sounds and Config.Sounds.hatchReveal
	if not id then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = position
	holder.Parent = workspace
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 1
	s.RollOffMinDistance = 40
	s.RollOffMaxDistance = 140
	s.Parent = holder
	s:Play()
	game:GetService("Debris"):AddItem(holder, 5)
end

function WorldService.MarkHatched(player, entry, toBackpack, position)
	pcall(function()
		local DS = require(script.Parent:WaitForChild("DataService"))
		require(script.Parent:WaitForChild("QuestService")).Add(DS.Get(player), "hatches", 1)
	end)
	local pen = pensByPlayer[player]
	if not pen then
		return
	end
	local pos = pen.position + Vector3.new(position and position.x or 0, 1.5, position and position.z or 0)
	local monster = Config.GetMonster(entry.monsterId)
	local rarity = Config.GetRarity(monster and monster.rarity or "Common")
	local color = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
	burstAt(pos + Vector3.new(0, 2, 0), color)
	playRevealAt(pos + Vector3.new(0, 2, 0)) -- the monster pops out

	if not toBackpack then
		justHatched[entry.uid] = os.clock()
		return
	end

	-- pen is full: show it popping out, then it flies to the backpack
	local size = 4 * Config.GetSizeVariant(entry.size).scale
	local temp = Instance.new("Part")
	temp.Name = "HatchPreview"
	temp.Shape = Enum.PartType.Ball
	temp.Size = Vector3.new(size, size, size)
	temp.Color = color
	temp.Material = Enum.Material.SmoothPlastic
	temp.Anchored = true
	temp.CanCollide = false
	temp.CFrame = CFrame.new(pos)
	temp.Parent = pen.model
	temp.Transparency = 1
	require(game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("MonsterModel")).Build(temp, size, { monsterId = entry.monsterId, groundOffset = size * 0.5, finish = entry.finish })
	WorldService.PlayPopIn(temp, nil, entry)
	local note = Instance.new("BillboardGui")
	note.Size = UDim2.fromOffset(220, 30)
	note.StudsOffset = Vector3.new(0, -size / 2 - 1, 0)
	note.AlwaysOnTop = true
	note.Parent = temp
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "Pen full \226\128\148 sent to backpack"
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Parent = note
	task.delay(Config.HatchInfoTime + 0.2, function()
		if temp.Parent then
			TweenService:Create(temp, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
			Debris:AddItem(temp, 0.4)
		end
	end)
end

-- Combat: point this player's following pets at an enemy (nil = stop)
-- Combat: each pet gets its own enemy { position, radius } (nil = none)
function WorldService.SetPetTargets(player, targets)
	local pen = pensByPlayer[player]
	if pen then
		pen.state.petTargets = targets
	end
end

function WorldService.SetCombatTarget(player, position, radius)
	local pen = pensByPlayer[player]
	if pen then
		pen.state.combatTarget = position
		pen.state.combatRadius = radius
	end
end

function WorldService.GetPen(player)
	return pensByPlayer[player]
end

function WorldService.IsValidPlacement(x, z)
	local margin = Config.PenPlacementMargin
	return math.abs(x) <= (PEN_HALF_X - margin) and math.abs(z) <= (PEN_HALF_Z - margin)
end

function WorldService.RemoveBase(player)
	local pen = pensByPlayer[player]
	if pen then
		for _, child in ipairs(pen.pets:GetChildren()) do
			child:Destroy()
		end
		pen.model.Name = "Pen_" .. pen.index
		pen.display.nameLabel.Text = "OPEN"
		pen.display.avatarImage.Image = ""
		pen.owner = nil
		pensByPlayer[player] = nil
	end
end

function WorldService.GetEntryIncome(entry)
	do
		return Config.GetEntryIncome(entry) -- shared formula (includes kg)
	end
	local monster = Config.GetMonster(entry.monsterId)
	if not monster then
		return 0
	end
	local rarity = Config.GetRarity(monster.rarity)
	local size = Config.GetSizeVariant(entry.size)
	local finish = Config.GetFinishVariant(entry.finish)
	local levelMultiplier = math.max(1, entry.level or 1) ^ 1.25
	return math.max(1, math.floor((rarity.tier * 5 + monster.power * 0.25) * size.incomeMultiplier * finish.incomeMultiplier * levelMultiplier))
end

function WorldService.GetProfileIncome(profile)
	local income = 0
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind ~= "egg" then
			income += WorldService.GetEntryIncome(entry)
		end
	end
	local cashBonus = 1 + Config.GetUpgradeBonus(profile.upgrades, "cash") / 100
	local rebirthBonus = 1 + (profile.rebirths or 0) * Config.Rebirth.cashBonus / 100
	if Config.IsBoostActive(profile, "cash") then
		rebirthBonus *= 2 -- Cash Potion
	end
	return math.floor(income * (profile.incomeBoost or 1) * cashBonus * rebirthBonus * Config.PassCashMultiplier(profile) * Config.GlobalBoost("income"))
end

function WorldService.GetEntryPower(entry)
	local monster = Config.GetMonster(entry.monsterId)
	if not monster then
		return 0
	end
	local size = Config.GetSizeVariant(entry.size)
	local finish = Config.GetFinishVariant(entry.finish)
	return math.floor(monster.power * size.powerMultiplier * finish.powerMultiplier * math.max(1, entry.level or 1))
end

function WorldService.GetProfilePower(profile)
	local power = 0
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind ~= "egg" then
			power += WorldService.GetEntryPower(entry)
		end
	end
	return power
end

return WorldService