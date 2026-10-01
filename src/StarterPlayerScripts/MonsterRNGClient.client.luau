local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")

local rollRemote = remotes:WaitForChild("Roll")
local profileRemote = remotes:WaitForChild("GetProfile")
local shopRemote = remotes:WaitForChild("BuyShopItem")
local bossRemote = remotes:WaitForChild("BattleBoss")
local pvpRemote = remotes:WaitForChild("ChallengePlayer")
local placeEggRemote = remotes:WaitForChild("PlaceEgg")
local placeMonsterRemote = remotes:WaitForChild("PlaceMonster")
local hatchRemote = remotes:WaitForChild("HatchEgg")
local unequipRemote = remotes:WaitForChild("UnequipMonster")
local sellEggRemote = remotes:WaitForChild("SellEgg")
local sellMonsterRemote = remotes:WaitForChild("SellMonster")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")

-- Cross-script signaling with the Backpack UI (a separate ScreenGui
-- under StarterGui, with its own controller script). Profile changes
-- reach it on their own via the ProfileUpdated remote above (every
-- mutating remote fires that before responding), so this bridge only
-- needs to carry open/close and "start holding this item" requests.
local clientBridge = monsterFolder:WaitForChild("ClientBridge")
local openBackpackBridge = clientBridge:WaitForChild("OpenBackpack")
local closeBackpackBridge = clientBridge:WaitForChild("CloseBackpack")
local startHoldingBridge = clientBridge:WaitForChild("StartHolding")
local openUpgradesBridge = clientBridge:WaitForChild("OpenUpgrades")
local closeUpgradesBridge = clientBridge:WaitForChild("CloseUpgrades")
local requestRollBridge = clientBridge:WaitForChild("RequestRoll")
local closeAllBridge = clientBridge:WaitForChild("CloseAll")

local profile = profileRemote:InvokeServer()
local cards = {}

--------------------------------------------------------------------
-- Palette
--------------------------------------------------------------------

local COLOR = {
	bg = Color3.fromRGB(9, 13, 29),
	bgTop = Color3.fromRGB(17, 27, 59),
	panel = Color3.fromRGB(20, 29, 60),
	panelLight = Color3.fromRGB(27, 38, 78),
	card = Color3.fromRGB(24, 31, 58),
	cardOn = Color3.fromRGB(31, 43, 82),
	purple = Color3.fromRGB(114, 91, 255),
	purpleLight = Color3.fromRGB(139, 118, 255),
	purpleDark = Color3.fromRGB(69, 60, 132),
	gold = Color3.fromRGB(255, 205, 93),
	red = Color3.fromRGB(177, 81, 49),
	teal = Color3.fromRGB(35, 112, 128),
	green = Color3.fromRGB(111, 220, 162),
	textWhite = Color3.fromRGB(239, 243, 255),
	textMuted = Color3.fromRGB(156, 172, 211),
}

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------

local function colorFromTable(color)
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function getRarity(rarityName)
	return Config.GetRarity(rarityName)
end

local function create(className, properties, parent)
	local object = Instance.new(className)
	for property, value in pairs(properties) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function corner(radius, parent)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 12) }, parent)
end

local function stroke(color, thickness, parent)
	return create("UIStroke", { Color = color, Thickness = thickness or 1.5, Transparency = 0.35 }, parent)
end

local function tween(object, time, style, props)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local GLOSS = {
	blueTop = Color3.fromRGB(110, 205, 255),
	blueBottom = Color3.fromRGB(35, 130, 220),
	redTop = Color3.fromRGB(255, 130, 130),
	redBottom = Color3.fromRGB(205, 55, 55),
	greenTop = Color3.fromRGB(130, 225, 155),
	greenBottom = Color3.fromRGB(55, 170, 95),
	goldTop = Color3.fromRGB(255, 215, 120),
	goldBottom = Color3.fromRGB(230, 160, 40),
	outline = Color3.fromRGB(10, 20, 45),
}

local function applyGloss(obj, topColor, bottomColor)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(1, bottomColor),
		}),
		Rotation = 90,
	}, obj)
end

local function outlineText(obj, outlineColor)
	obj.TextStrokeColor3 = outlineColor or GLOSS.outline
	obj.TextStrokeTransparency = 0
end

local closeButtonImages = {}

local function createCloseButton(parent, size, position, zIndex, key)
	local closeButton = create("TextButton", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = zIndex,
	}, parent)
	local icon = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex,
	}, closeButton)
	if key then
		closeButtonImages[key] = icon
	end
	return closeButton
end

local function pressAnim(button)
	button.MouseButton1Down:Connect(function()
		tween(button, 0.08, Enum.EasingStyle.Quad, { Size = button.Size - UDim2.fromOffset(4, 4) })
	end)
	button.MouseButton1Up:Connect(function()
		tween(button, 0.12, Enum.EasingStyle.Back, { Size = button.Size + UDim2.fromOffset(4, 4) })
	end)
end

--------------------------------------------------------------------
-- Root GUI
--------------------------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local gui = create("ScreenGui", {
	Name = "MonsterRNGGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, playerGui)

-- Everything in this UI is laid out in fixed pixel offsets against a
-- desktop-sized reference (~1000px wide). Uniformly shrinking the whole
-- ScreenGui on smaller screens keeps every element in its correct
-- relative position instead of letting things overflow or overlap.
local uiScale = create("UIScale", { Scale = 1 }, gui)

local BASE_UI_WIDTH = 1000
local function updateUIScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewportWidth = camera.ViewportSize.X
	if viewportWidth <= 0 then
		return
	end
	uiScale.Scale = math.clamp(viewportWidth / BASE_UI_WIDTH, 0.55, 1)
end

updateUIScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateUIScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)
	end
end)

--------------------------------------------------------------------
-- Top-left HUD: cash, rolls, pity
--------------------------------------------------------------------

local hud = create("Frame", {
	Name = "HUD",
	Size = UDim2.fromOffset(230, 96),
	Position = UDim2.new(0, 20, 0.3, 0),
	BackgroundTransparency = 1,
}, gui)

local cashPill = create("Frame", {
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
}, hud)
corner(UDim.new(0, 14), cashPill)
stroke(Color3.fromRGB(255, 205, 93), 1.5, cashPill)

local cashBadge = create("TextLabel", {
	Size = UDim2.fromOffset(28, 28),
	Position = UDim2.fromOffset(6, 6),
	BackgroundColor3 = COLOR.gold,
	Text = "$",
	TextColor3 = Color3.fromRGB(60, 44, 6),
	TextSize = 16,
	Font = Enum.Font.LuckiestGuy,
}, cashPill)
corner(UDim.new(1, 0), cashBadge)

local cashLabel = create("TextLabel", {
	Size = UDim2.new(1, -46, 1, 0),
	Position = UDim2.fromOffset(42, 0),
	BackgroundTransparency = 1,
	Text = "$0",
	TextColor3 = COLOR.gold,
	TextSize = 20,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
}, cashPill)

local rollsPill = create("Frame", {
	Size = UDim2.new(1, 0, 0, 28),
	Position = UDim2.fromOffset(0, 46),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
}, hud)
corner(UDim.new(0, 10), rollsPill)

local rollsLabel = create("TextLabel", {
	Size = UDim2.new(1, -16, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	BackgroundTransparency = 1,
	Text = "Rolls: 0",
	TextColor3 = COLOR.textMuted,
	TextSize = 13,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
}, rollsPill)

local pityTrack = create("Frame", {
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.fromOffset(0, 78),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, hud)
corner(UDim.new(0, 8), pityTrack)

local pityFill = create("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = COLOR.purple,
	BorderSizePixel = 0,
}, pityTrack)
corner(UDim.new(0, 8), pityFill)

local pityLabel = create("TextLabel", {
	Size = UDim2.new(1, -10, 1, 0),
	Position = UDim2.fromOffset(6, 0),
	BackgroundTransparency = 1,
	Text = "Pity 0/40",
	TextColor3 = COLOR.textWhite,
	TextSize = 11,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 2,
}, pityTrack)

-- only the cash is shown (rolls/income and the pity bar were removed)
rollsPill.Visible = false
pityTrack.Visible = false

--------------------------------------------------------------------
-- Right side vertical action stack: SHOP / BOSS / PVP
--------------------------------------------------------------------

local sideIconImages = {}

local function createSideIcon(order, name, glyph, color, position)
	local iconButton = create("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(64, 64),
		Position = position,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	}, gui)

	local icon = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
	}, iconButton)
	sideIconImages[name] = icon

	pressAnim(iconButton)
	return iconButton
end

local shopIcon = createSideIcon(1, "SHOP", "$", COLOR.teal, UDim2.new(1, -84, 0, 130))
local bossIcon = createSideIcon(2, "BOSS", "!", COLOR.red, UDim2.new(1, -84, 0, 206))
local pvpIcon = createSideIcon(3, "PVP", "X", Color3.fromRGB(255, 130, 90), UDim2.new(1, -84, 0, 282))
local indexIcon = createSideIcon(4, "INDEX", "i", COLOR.purple, UDim2.new(1, -84, 0, 358))

--------------------------------------------------------------------
-- Index window (monster dex / collection)
--------------------------------------------------------------------

local indexWindow = create("Frame", {
	Size = UDim2.fromScale(0.62, 0.72),
	Position = UDim2.fromScale(0.5, 0.46),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
}, gui)
corner(UDim.new(0, 20), indexWindow)
stroke(COLOR.purple, 2, indexWindow)

create("TextLabel", {
	Size = UDim2.new(1, -90, 0, 35),
	Position = UDim2.fromOffset(24, 18),
	BackgroundTransparency = 1,
	Text = "MONSTER INDEX",
	TextColor3 = COLOR.textWhite,
	TextSize = 22,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, indexWindow)

local collectionHint = create("TextLabel", {
	Size = UDim2.new(1, -100, 0, 22),
	Position = UDim2.fromOffset(24, 52),
	BackgroundTransparency = 1,
	TextColor3 = COLOR.textMuted,
	TextSize = 13,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, indexWindow)

local indexClose = createCloseButton(indexWindow, UDim2.fromOffset(38, 38), UDim2.new(1, -56, 0, 16), 11, "index")

local collection = create("ScrollingFrame", {
	Size = UDim2.new(1, -48, 1, -96),
	Position = UDim2.fromOffset(24, 84),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = COLOR.purple,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 11,
}, indexWindow)

create("UIGridLayout", {
	CellSize = UDim2.new(0.235, -8, 0, 120),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, collection)

--------------------------------------------------------------------
-- Backpack window now lives in StarterGui.Backpack, run by its own
-- BackpackController LocalScript. This script only opens/closes it
-- (via clientBridge below) and fulfills "start holding this item"
-- requests from it, since world placement stays owned here.
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Shop window
--------------------------------------------------------------------

local shopWindow = create("Frame", {
	Size = UDim2.fromScale(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 12,
}, gui)
corner(UDim.new(0, 20), shopWindow)
stroke(COLOR.teal, 2, shopWindow)

create("TextLabel", {
	Size = UDim2.new(1, -90, 0, 35),
	Position = UDim2.fromOffset(24, 18),
	BackgroundTransparency = 1,
	Text = "UPGRADE SHOP",
	TextColor3 = COLOR.textWhite,
	TextSize = 22,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 13,
}, shopWindow)

local shopClose = createCloseButton(shopWindow, UDim2.fromOffset(38, 38), UDim2.new(1, -56, 0, 16), 13, "shop")

create("TextLabel", {
	Size = UDim2.new(1, -48, 0, 30),
	Position = UDim2.fromOffset(24, 58),
	BackgroundTransparency = 1,
	Text = "Spend your base cash on permanent boosts.",
	TextColor3 = COLOR.textMuted,
	TextSize = 13,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 13,
}, shopWindow)

local shopList = create("Frame", {
	Size = UDim2.new(1, -48, 1, -112),
	Position = UDim2.fromOffset(24, 96),
	BackgroundTransparency = 1,
	ZIndex = 13,
}, shopWindow)

--------------------------------------------------------------------
-- PvP window
--------------------------------------------------------------------

local pvpWindow = create("Frame", {
	Size = UDim2.fromScale(0.5, 0.58),
	Position = UDim2.fromScale(0.5, 0.46),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 16,
}, gui)
corner(UDim.new(0, 20), pvpWindow)
stroke(Color3.fromRGB(255, 130, 90), 2, pvpWindow)

create("TextLabel", {
	Size = UDim2.new(1, -90, 0, 35),
	Position = UDim2.fromOffset(24, 18),
	BackgroundTransparency = 1,
	Text = "PVP COLOSSEUM",
	TextColor3 = COLOR.textWhite,
	TextSize = 22,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 17,
}, pvpWindow)

local pvpClose = createCloseButton(pvpWindow, UDim2.fromOffset(38, 38), UDim2.new(1, -56, 0, 16), 17, "pvp")

create("TextLabel", {
	Size = UDim2.new(1, -48, 0, 42),
	Position = UDim2.fromOffset(24, 58),
	BackgroundTransparency = 1,
	Text = "Choose an online player to compare monster power. The winner earns $500.",
	TextColor3 = COLOR.textMuted,
	TextSize = 13,
	Font = Enum.Font.LuckiestGuy,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 17,
}, pvpWindow)

local pvpList = create("ScrollingFrame", {
	Size = UDim2.new(1, -48, 1, -120),
	Position = UDim2.fromOffset(24, 105),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Color3.fromRGB(255, 130, 90),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 17,
}, pvpWindow)

--------------------------------------------------------------------
-- Reveal stage (slot-machine roll animation)
--------------------------------------------------------------------

local revealBackdrop = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 30,
}, gui)

local revealClose = create("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 30,
}, revealBackdrop)

local orbFrame = create("Frame", {
	Size = UDim2.fromOffset(210, 210),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
	ZIndex = 31,
}, revealBackdrop)
corner(UDim.new(1, 0), orbFrame)
local orbStroke = stroke(COLOR.purple, 5, orbFrame)

local orbLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "?",
	TextColor3 = COLOR.textWhite,
	TextSize = 62,
	Font = Enum.Font.LuckiestGuy,
	ZIndex = 32,
}, orbFrame)

local revealRarity = create("TextLabel", {
	Size = UDim2.new(0, 400, 0, 30),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.6),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLOR.gold,
	TextSize = 22,
	Font = Enum.Font.LuckiestGuy,
	ZIndex = 31,
}, revealBackdrop)

local revealName = create("TextLabel", {
	Size = UDim2.new(0, 500, 0, 44),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.655),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLOR.textWhite,
	TextSize = 32,
	Font = Enum.Font.LuckiestGuy,
	TextWrapped = true,
	ZIndex = 31,
}, revealBackdrop)

local revealDesc = create("TextLabel", {
	Size = UDim2.new(0, 460, 0, 40),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.72),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLOR.textMuted,
	TextSize = 14,
	Font = Enum.Font.LuckiestGuy,
	TextWrapped = true,
	ZIndex = 31,
}, revealBackdrop)

local revealHint = create("TextLabel", {
	Size = UDim2.new(0, 400, 0, 24),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.82),
	BackgroundTransparency = 1,
	Text = "Tap to continue",
	TextColor3 = COLOR.textMuted,
	TextSize = 12,
	Font = Enum.Font.LuckiestGuy,
	TextTransparency = 1,
	ZIndex = 31,
}, revealBackdrop)

local function spawnBurst(parent, color, count)
	for _ = 1, count do
		local piece = create("Frame", {
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 33,
		}, parent)
		corner(UDim.new(1, 0), piece)
		local angle = math.random() * math.pi * 2
		local distance = math.random(90, 190)
		local target = UDim2.fromScale(0.5, 0.42) + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance)
		tween(piece, 0.55 + math.random() * 0.35, Enum.EasingStyle.Quad, {
			Position = target,
			BackgroundTransparency = 1,
		})
		Debris:AddItem(piece, 1.2)
	end
end

local revealOpen = false
local revealCanClose = false

local function closeReveal()
	if not revealOpen then
		return
	end
	revealOpen = false
	tween(revealBackdrop, 0.25, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
	tween(revealName, 0.2, Enum.EasingStyle.Quad, { TextTransparency = 1 })
	tween(revealDesc, 0.2, Enum.EasingStyle.Quad, { TextTransparency = 1 })
	tween(revealRarity, 0.2, Enum.EasingStyle.Quad, { TextTransparency = 1 })
	tween(revealHint, 0.2, Enum.EasingStyle.Quad, { TextTransparency = 1 })
	tween(orbFrame, 0.25, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
	tween(orbLabel, 0.2, Enum.EasingStyle.Quad, { TextTransparency = 1 })
	task.delay(0.28, function()
		if not revealOpen then
			revealBackdrop.Visible = false
			orbFrame.BackgroundTransparency = 0
			orbLabel.TextTransparency = 0
		end
	end)
end

revealClose.MouseButton1Click:Connect(function()
	if revealCanClose then
		closeReveal()
	end
end)

local function playRollReveal(monster, rarity, entry, placed)
	revealOpen = true
	revealCanClose = false
	revealBackdrop.Visible = true
	revealBackdrop.BackgroundTransparency = 1
	revealName.Text = ""
	revealDesc.Text = ""
	revealRarity.Text = ""
	revealName.TextTransparency = 1
	revealDesc.TextTransparency = 1
	revealRarity.TextTransparency = 1
	revealHint.TextTransparency = 1
	orbFrame.Size = UDim2.fromOffset(210, 210)
	orbFrame.BackgroundTransparency = 0
	orbLabel.TextTransparency = 0

	tween(revealBackdrop, 0.2, Enum.EasingStyle.Quad, { BackgroundTransparency = 0.45 })

	-- Spin phase: cycle through rarities, slowing down toward the true result
	local spinCount = 10 + rarity.tier * 4
	local sequence = {}
	for i = 1, spinCount do
		sequence[i] = Config.Rarities[math.random(1, #Config.Rarities)]
	end
	sequence[spinCount] = rarity

	for i, step in ipairs(sequence) do
		local stepColor = colorFromTable(step.color)
		orbFrame.BackgroundColor3 = stepColor
		orbStroke.Color = stepColor
		orbLabel.Text = string.sub(step.name, 1, 1)
		orbLabel.TextColor3 = Color3.new(1, 1, 1)
		revealRarity.Text = step.name:upper()
		revealRarity.TextColor3 = stepColor
		revealRarity.TextTransparency = 0

		local progress = i / spinCount
		local waitTime = 0.018 + (progress ^ 3) * 0.16
		task.wait(waitTime)
	end

	-- Landing bounce
	local finalColor = colorFromTable(rarity.color)
	tween(orbFrame, 0.35, Enum.EasingStyle.Back, { Size = UDim2.fromOffset(240, 240) })
	task.delay(0.12, function()
		tween(orbFrame, 0.25, Enum.EasingStyle.Quad, { Size = UDim2.fromOffset(210, 210) })
	end)

	spawnBurst(revealBackdrop, finalColor, 10 + rarity.tier * 3)

	revealName.Text = Config.BuildDisplayName(monster.name, entry.size, entry.finish)
	revealDesc.Text = placed and monster.description or (monster.description .. "  (Cage is full \226\128\148 added to your collection)")
	tween(revealName, 0.3, Enum.EasingStyle.Quad, { TextTransparency = 0 })
	tween(revealDesc, 0.3, Enum.EasingStyle.Quad, { TextTransparency = 0 })

	task.wait(0.4)
	revealCanClose = true
	tween(revealHint, 0.4, Enum.EasingStyle.Quad, { TextTransparency = 0.3 })

	task.delay(3.5, function()
		if revealOpen then
			closeReveal()
		end
	end)
end

--------------------------------------------------------------------
-- Data helpers
--------------------------------------------------------------------

local function calculateEntryIncome(entry)
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

local function calculateProfileIncome()
	local income = 0
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind ~= "egg" then
			income += calculateEntryIncome(entry)
		end
	end
	return math.floor(income * (profile.incomeBoost or 1))
end

local function updateStats()
	cashLabel.Text = "$" .. Config.FormatNumber(profile.cash or 0)
	rollsLabel.Text = string.format("Rolls: %d  \226\128\162  Income: +$%d/s", profile.rolls or 0, calculateProfileIncome())

	local pity = profile.pity or 0
	local nextThreshold = Config.NextPityThreshold(pity)
	local fillScale = math.clamp(pity / nextThreshold.value, 0, 1)
	tween(pityFill, 0.25, Enum.EasingStyle.Quad, { Size = UDim2.new(fillScale, 0, 1, 0) })
	pityLabel.Text = string.format("Pity \226\134\146 %s: %d/%d", nextThreshold.label, pity, nextThreshold.value)

	local ownedCount = 0
	for _, count in pairs(profile.owned or {}) do
		if count > 0 then
			ownedCount += 1
		end
	end
	collectionHint.Text = string.format("%d/%d discovered", ownedCount, #Config.Monsters)
end

--------------------------------------------------------------------
-- Collection cards
--------------------------------------------------------------------

local function refreshCard(monster, card, parts)
	local count = (profile.owned or {})[monster.id] or 0
	local rarity = getRarity(monster.rarity)
	local discovered = count > 0
	card.BackgroundColor3 = discovered and COLOR.cardOn or COLOR.card
	parts.accent.BackgroundColor3 = discovered and colorFromTable(rarity.color) or Color3.fromRGB(60, 66, 92)
	parts.nameLabel.Text = discovered and monster.name or "Undiscovered"
	parts.nameLabel.TextColor3 = discovered and COLOR.textWhite or Color3.fromRGB(113, 124, 158)
	parts.rarityLabel.Text = monster.rarity:upper()
	parts.rarityLabel.TextColor3 = colorFromTable(rarity.color)
	parts.countLabel.Text = discovered and ("x" .. count) or "???"
	parts.icon.Text = discovered and string.sub(monster.name, 1, 1) or "?"
	parts.icon.TextColor3 = discovered and colorFromTable(rarity.color) or Color3.fromRGB(86, 96, 128)
end

local function createMonsterCard(monster, index)
	local card = create("Frame", {
		Name = monster.id,
		LayoutOrder = index,
		BackgroundColor3 = COLOR.card,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, collection)
	corner(UDim.new(0, 12), card)

	local accent = create("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(60, 66, 92),
		BorderSizePixel = 0,
	}, card)

	local icon = create("TextLabel", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(12, 10),
		BackgroundColor3 = Color3.fromRGB(15, 20, 42),
		BorderSizePixel = 0,
		TextSize = 22,
		Font = Enum.Font.LuckiestGuy,
	}, card)
	corner(UDim.new(0, 10), icon)

	local nameLabel = create("TextLabel", {
		Size = UDim2.new(1, -64, 0, 22),
		Position = UDim2.fromOffset(62, 9),
		BackgroundTransparency = 1,
		TextSize = 13,
		Font = Enum.Font.LuckiestGuy,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	local rarityLabel = create("TextLabel", {
		Size = UDim2.new(1, -64, 0, 18),
		Position = UDim2.fromOffset(62, 30),
		BackgroundTransparency = 1,
		TextSize = 10,
		Font = Enum.Font.LuckiestGuy,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local countLabel = create("TextLabel", {
		Size = UDim2.fromOffset(40, 18),
		Position = UDim2.new(1, -50, 0, 10),
		BackgroundTransparency = 1,
		TextColor3 = COLOR.textMuted,
		TextSize = 11,
		Font = Enum.Font.LuckiestGuy,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, card)

	local parts = {
		accent = accent,
		icon = icon,
		nameLabel = nameLabel,
		rarityLabel = rarityLabel,
		countLabel = countLabel,
	}

	table.insert(cards, { monster = monster, card = card, parts = parts })
	refreshCard(monster, card, parts)
end

for index, monster in ipairs(Config.Monsters) do
	createMonsterCard(monster, index)
end

--------------------------------------------------------------------
-- Base / cage rendering
--------------------------------------------------------------------

local notifyBridge = game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("ClientBridge"):WaitForChild("Notify")
local function showToast(message, color)
	notifyBridge:Fire(message, color)
end

--------------------------------------------------------------------
-- Hold & place: equip an egg/monster from the backpack, then walk to
-- your pen and click anywhere inside it to place it there (freeform
-- position, not a fixed slot). Placed monsters can be picked back up
-- with E; placed eggs are locked in until they hatch.
--------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")

local heldItem = nil -- { kind = "egg" | "monster", uid = ... }
local heldVisualPart = nil
local heldWeld = nil

local holdHintFrame = create("Frame", {
	Size = UDim2.fromOffset(380, 48),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	BackgroundColor3 = COLOR.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 25,
}, gui)
corner(UDim.new(0, 12), holdHintFrame)
stroke(COLOR.purple, 1.5, holdHintFrame)

local holdHintLabel = create("TextLabel", {
	Size = UDim2.new(1, -100, 1, 0),
	Position = UDim2.fromOffset(16, 0),
	BackgroundTransparency = 1,
	Text = "Tap inside your pen to place it",
	TextColor3 = COLOR.textWhite,
	TextSize = 13,
	Font = Enum.Font.LuckiestGuy,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	ZIndex = 25,
}, holdHintFrame)

local holdCancelButton = create("TextButton", {
	Size = UDim2.fromOffset(80, 34),
	Position = UDim2.new(1, -87, 0.5, -17),
	BackgroundColor3 = Color3.fromRGB(154, 67, 90),
	BorderSizePixel = 0,
	Text = "CANCEL",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 11,
	Font = Enum.Font.LuckiestGuy,
	AutoButtonColor = false,
	ZIndex = 25,
}, holdHintFrame)
corner(UDim.new(0, 8), holdCancelButton)

local function getCharacterTorso()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local savedShoulderC0 = {}

-- Both arms straight up, hands in a bit, like lifting something over
-- the head. Changes the shoulder joints' C0 (animations still
-- play on top, so walking looks natural).
local function setJointPose(on)
	local character = player.Character
	if not character then
		return
	end
	local joints = {}
	local rightArm, leftArm = character:FindFirstChild("RightUpperArm"), character:FindFirstChild("LeftUpperArm")
	if rightArm and leftArm then
		joints = {
			{ rightArm:FindFirstChild("RightShoulder"), CFrame.fromEulerAnglesYXZ(math.rad(165), 0, math.rad(-12)) },
			{ leftArm:FindFirstChild("LeftShoulder"), CFrame.fromEulerAnglesYXZ(math.rad(165), 0, math.rad(12)) },
		}
	else
		local torso = character:FindFirstChild("Torso")
		if torso then
			joints = {
				{ torso:FindFirstChild("Right Shoulder"), CFrame.Angles(0, 0, math.rad(165)) },
				{ torso:FindFirstChild("Left Shoulder"), CFrame.Angles(0, 0, math.rad(-165)) },
			}
		end
	end
	-- Classic rigs use Motor6D (rotate C0); newer rigs use
	-- AnimationConstraint (rotate its torso-side attachment instead).
	for _, pair in ipairs(joints) do
		local joint, offset = pair[1], pair[2]
		if joint then
			pcall(function()
				local target, prop
				if joint:IsA("Motor6D") then
					target, prop = joint, "C0"
				elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
					target, prop = joint.Attachment0, "CFrame"
				end
				if not target then
					return
				end
				if on then
					savedShoulderC0[target] = savedShoulderC0[target] or target[prop]
					target[prop] = savedShoulderC0[target] * offset
				elseif savedShoulderC0[target] then
					target[prop] = savedShoulderC0[target]
					savedShoulderC0[target] = nil
				end
			end)
		end
	end
end

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local holdAnimIds = {}
local holdTrack

-- Builds the "carrying something in front" pose in code: upper arms
-- raised forward (a bit below shoulder height) and angled in, forearms
-- slightly bent. Only the arms are keyed, so walking still animates legs.
local function getHoldAnimationId(isR15)
	if holdAnimIds[isR15] then
		return holdAnimIds[isR15]
	end
	local kfs = Instance.new("KeyframeSequence")
	kfs.Loop = true
	kfs.Priority = Enum.AnimationPriority.Action
	for _, time in ipairs({ 0, 1 }) do
		local kf = Instance.new("Keyframe")
		kf.Time = time
		kf.Parent = kfs
		local function pose(name, parent, cf, weight)
			local p = Instance.new("Pose")
			p.Name = name
			p.CFrame = cf or CFrame.new()
			p.Weight = weight or 0
			p.Parent = parent
			return p
		end
		local root = pose("HumanoidRootPart", kf)
		if isR15 then
			local lower = pose("LowerTorso", root)
			local upper = pose("UpperTorso", lower)
			local ra = pose("RightUpperArm", upper, CFrame.fromEulerAnglesYXZ(math.rad(65), math.rad(22), 0), 1)
			local la = pose("LeftUpperArm", upper, CFrame.fromEulerAnglesYXZ(math.rad(65), math.rad(-22), 0), 1)
			pose("RightLowerArm", ra, CFrame.Angles(math.rad(18), 0, 0), 1)
			pose("LeftLowerArm", la, CFrame.Angles(math.rad(18), 0, 0), 1)
		else
			local torso = pose("Torso", root)
			pose("Right Arm", torso, CFrame.Angles(0, 0, math.rad(70)), 1)
			pose("Left Arm", torso, CFrame.Angles(0, 0, math.rad(-70)), 1)
		end
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
	end)
	if ok then
		holdAnimIds[isR15] = id
		return id
	end
	return nil
end

-- The carry pose is done by the SERVER (it bends the character's arm
-- joints), so it works in the real game and every player sees it.
-- (The old code-built animation only works inside Roblox Studio.)
local holdPoseRemote = remotes:WaitForChild("HoldPose", 10)
local function setHoldPose(on)
	if holdTrack then
		holdTrack:Stop(0.2)
		holdTrack = nil
	end
	setJointPose(false)
	if holdPoseRemote then
		holdPoseRemote:FireServer(on == true)
	else
		setJointPose(on) -- fallback: this screen only
	end
end

local function clearHeldVisual()
	if heldWeld then
		heldWeld:Destroy()
		heldWeld = nil
	end
	if heldVisualPart then
		heldVisualPart:Destroy()
		heldVisualPart = nil
	end
	-- any leftover held model (never leave one stuck on the character)
	local character = player.Character
	if character then
		for _, c in ipairs(character:GetChildren()) do
			if c.Name == "HeldItem" then
				c:Destroy()
			end
		end
	end
end

local holdToken -- a newer startHolding / stopHolding cancels an older one
local function stopHolding()
	holdToken = nil
	heldItem = nil
	player:SetAttribute("HeldKind", nil)
	player:SetAttribute("HeldUid", nil)
	holdHintFrame.Visible = false
	clearHeldVisual()
	setHoldPose(false)
end


-- the saved entry for this egg / monster (local copy first, the server if needed)
local function findHeldEntry(kind, uid)
	local function find(p)
		for _, e in ipairs((p and (kind == "egg" and p.eggs or p.monsters)) or {}) do
			if e.uid == uid then
				return e
			end
		end
		return nil
	end
	local e = find(profile)
	if not e then
		pcall(function()
			e = find(remotes.GetProfile:InvokeServer())
		end)
	end
	return e
end

local function startHolding(kind, uid, color)
	stopHolding()
	local token = {}
	holdToken = token
	local torso = getCharacterTorso()
	if not torso then
		showToast("Your character isn't ready yet.", Color3.fromRGB(255, 166, 111))
		return
	end

	heldItem = { kind = kind, uid = uid }
	player:SetAttribute("HeldKind", kind)
	player:SetAttribute("HeldUid", uid)

	-- look it up BEFORE building anything: this can wait on the server,
	-- and if it was placed / cancelled meanwhile nothing is left behind
	local entry = findHeldEntry(kind, uid)
	if holdToken ~= token or not torso.Parent then
		return
	end

	local part = Instance.new("Part")
	part.Name = "HeldItem"
	part.Shape = Enum.PartType.Ball
	part.Size = kind == "egg" and Vector3.new(1.7, 1.7, 1.7) or Vector3.new(2, 2, 2)
	part.Color = color
	part.Material = kind == "egg" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Anchored = false
	part.Massless = true
	-- lifted over the head, resting on the raised hands
	part.CFrame = torso.CFrame * CFrame.new(0, kind == "egg" and 3.7 or 3.5, -0.5)
	part.Parent = player.Character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part
	heldVisualPart = part
	heldWeld = weld

	if kind == "monster" then
		-- a small version of the monster's own model
		part.Transparency = 1
		require(game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("MonsterModel")).Build(part, 1.8, { monsterId = entry and entry.monsterId, groundOffset = 0.9, finish = entry and entry.finish })
	end
	if kind == "egg" then
		-- same blocky studded egg as in the pen (small)
		part.Transparency = 1
		require(game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("EggModel")).Build(part, 2.3, color, nil, entry and entry.rarity)
	end
	if holdToken ~= token then
		part:Destroy()
		return
	end

	setHoldPose(true)
	holdHintLabel.Text = kind == "monster" and "Click anywhere to equip it" or "Click inside your pen to place it"
	holdHintFrame.Visible = true
end

holdCancelButton.MouseButton1Click:Connect(stopHolding)
player.CharacterAdded:Connect(stopHolding)

-- Place only on a real TAP/CLICK: finger (or mouse) goes down and comes
-- back up quickly without moving. Dragging to turn the camera never places.
local pressStart = {} -- input object -> { pos, time }
local TAP_MOVE, TAP_TIME = 14, 0.45
local placeAt
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent or not heldItem then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	pressStart[input] = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock() }
end)
UserInputService.InputChanged:Connect(function(input)
	local p = pressStart[input]
	if p and (Vector2.new(input.Position.X, input.Position.Y) - p.pos).Magnitude > TAP_MOVE then
		pressStart[input] = nil -- it's a drag (camera), not a tap
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local p = pressStart[input]
	pressStart[input] = nil
	if not p or not heldItem then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- mouse: InputChanged doesn't track the button, so check where it ended
		local nowPos = Vector2.new(input.Position.X, input.Position.Y)
		if (nowPos - p.pos).Magnitude > TAP_MOVE then
			return
		end
	end
	if os.clock() - p.t > TAP_TIME then
		return -- held down too long: probably looking around
	end
	placeAt(input)
end)
placeAt = function(input)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local unitRay = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character, heldVisualPart }
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, raycastParams)
	if not result then
		if heldItem.kind ~= "monster" then
			return
		end
		result = { Position = Vector3.new(1e5, 0, 1e5) } -- sky: the server picks a spot in the pen
	end

	local myBaseModel = workspace.MonsterRNGWorld:FindFirstChild("Base_" .. player.UserId)
	local penPosition = myBaseModel and myBaseModel:GetAttribute("BasePosition")
	if not penPosition then
		showToast("Your pen could not be found.", Color3.fromRGB(255, 166, 111))
		return
	end

	local offset = result.Position - penPosition
	local kind, uid = heldItem.kind, heldItem.uid

	local response
	if kind == "egg" then
		response = placeEggRemote:InvokeServer(uid, offset.X, offset.Z)
	else
		response = placeMonsterRemote:InvokeServer(uid, offset.X, offset.Z)
	end

	if response.profile then
		profile = response.profile
	end
	showToast(response.message or "Placed.", response.success and COLOR.green or Color3.fromRGB(255, 166, 111))
	updateStats()

	if response.success then
		stopHolding()
	end
end

--------------------------------------------------------------------
-- Shop rendering
--------------------------------------------------------------------

local function renderShop()
	for _, child in ipairs(shopList:GetChildren()) do
		child:Destroy()
	end

	local items = {
		{ key = "luckPotion", item = Config.ShopItems.luckPotion, color = COLOR.purple },
		{ key = "incomeBoost", item = Config.ShopItems.incomeBoost, color = COLOR.teal },
	}

	for index, entry in ipairs(items) do
		local card = create("Frame", {
			Size = UDim2.new(1, 0, 0, 72),
			Position = UDim2.fromOffset(0, (index - 1) * 86),
			BackgroundColor3 = COLOR.cardOn,
			BorderSizePixel = 0,
			ZIndex = 14,
		}, shopList)
		corner(UDim.new(0, 12), card)

		create("TextLabel", {
			Size = UDim2.new(0.56, 0, 0, 25),
			Position = UDim2.fromOffset(14, 9),
			BackgroundTransparency = 1,
			Text = entry.item.name,
			TextColor3 = COLOR.textWhite,
			TextSize = 15,
			Font = Enum.Font.LuckiestGuy,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
		}, card)
		create("TextLabel", {
			Size = UDim2.new(0.56, 0, 0, 22),
			Position = UDim2.fromOffset(14, 35),
			BackgroundTransparency = 1,
			Text = entry.item.description,
			TextColor3 = COLOR.textMuted,
			TextSize = 11,
			Font = Enum.Font.LuckiestGuy,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
		}, card)

		local buyButton = create("TextButton", {
			Size = UDim2.new(0.32, 0, 0, 38),
			Position = UDim2.new(0.66, 0, 0.5, -19),
			BackgroundColor3 = entry.color,
			BorderSizePixel = 0,
			Text = "BUY  $" .. entry.item.cost,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 12,
			Font = Enum.Font.LuckiestGuy,
			AutoButtonColor = false,
			ZIndex = 15,
		}, card)
		corner(UDim.new(0, 9), buyButton)

		buyButton.MouseButton1Click:Connect(function()
			local response = shopRemote:InvokeServer(entry.key)
			if response.profile then
				profile = response.profile
			end
			showToast(response.message or "Shop update.", response.success and COLOR.green or Color3.fromRGB(255, 166, 111))
			updateStats()
			renderShop()
		end)
	end
end

--------------------------------------------------------------------
-- PvP rendering
--------------------------------------------------------------------

local function renderPvP()
	for _, child in ipairs(pvpList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local opponents = {}
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			table.insert(opponents, otherPlayer)
		end
	end

	if #opponents == 0 then
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = "No other players are online yet.",
			TextColor3 = COLOR.textMuted,
			TextSize = 14,
			Font = Enum.Font.LuckiestGuy,
			ZIndex = 18,
		}, pvpList)
		return
	end

	for index, opponent in ipairs(opponents) do
		local card = create("Frame", {
			Size = UDim2.new(1, 0, 0, 62),
			Position = UDim2.fromOffset(0, (index - 1) * 74),
			BackgroundColor3 = COLOR.cardOn,
			BorderSizePixel = 0,
			ZIndex = 18,
		}, pvpList)
		corner(UDim.new(0, 11), card)
		create("TextLabel", {
			Size = UDim2.new(0.58, 0, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			BackgroundTransparency = 1,
			Text = opponent.DisplayName .. "  @" .. opponent.Name,
			TextColor3 = COLOR.textWhite,
			TextSize = 13,
			Font = Enum.Font.LuckiestGuy,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 19,
		}, card)

		local challengeButton = create("TextButton", {
			Size = UDim2.new(0.28, 0, 0, 36),
			Position = UDim2.new(0.69, 0, 0.5, -18),
			BackgroundColor3 = COLOR.red,
			BorderSizePixel = 0,
			Text = "BATTLE",
			TextColor3 = Color3.fromRGB(255, 244, 236),
			TextSize = 11,
			Font = Enum.Font.LuckiestGuy,
			AutoButtonColor = false,
			ZIndex = 19,
		}, card)
		corner(UDim.new(0, 9), challengeButton)

		challengeButton.MouseButton1Click:Connect(function()
			local response = pvpRemote:InvokeServer(opponent.UserId)
			if response.profile then
				profile = response.profile
			end
			showToast(response.message or "PvP battle complete.", response.success and COLOR.gold or Color3.fromRGB(255, 166, 111))
			updateStats()
			pvpWindow.Visible = false
		end)
	end
end

--------------------------------------------------------------------
-- Window toggles
--------------------------------------------------------------------

local function closeAllWindows()
	closeBackpackBridge:Fire()
	indexWindow.Visible = false
	shopWindow.Visible = false
	pvpWindow.Visible = false
	closeUpgradesBridge:Fire()
end

closeAllBridge.Event:Connect(function(except)
	indexWindow.Visible = false
	shopWindow.Visible = false
	pvpWindow.Visible = false
	if except ~= "backpack" then
		closeBackpackBridge:Fire()
	end
	if except ~= "upgrades" then
		closeUpgradesBridge:Fire()
	end
end)



startHoldingBridge.Event:Connect(function(kind, uid, color)
	startHolding(kind, uid, color)
end)



shopIcon.MouseButton1Click:Connect(function()
	closeAllWindows()
	shopWindow.Visible = true
	renderShop()
end)

pvpIcon.MouseButton1Click:Connect(function()
	closeAllWindows()
	pvpWindow.Visible = true
	renderPvP()
end)

indexIcon.MouseButton1Click:Connect(function()
	closeAllWindows()
	indexWindow.Visible = true
end)

indexClose.MouseButton1Click:Connect(function()
	indexWindow.Visible = false
end)
shopClose.MouseButton1Click:Connect(function()
	shopWindow.Visible = false
end)
pvpClose.MouseButton1Click:Connect(function()
	pvpWindow.Visible = false
end)

bossIcon.MouseButton1Click:Connect(function()
	local response = bossRemote:InvokeServer()
	if response.profile then
		profile = response.profile
	end
	showToast(response.message or "Boss battle complete.", response.success and COLOR.gold or Color3.fromRGB(255, 166, 111))
	updateStats()
end)

renderShop()

--------------------------------------------------------------------
-- Hub interaction: walk up to a station and press E (PC) or tap (mobile).
-- Roblox's ProximityPrompt handles both input styles automatically.
--------------------------------------------------------------------

local worldFolder = workspace:WaitForChild("MonsterRNGWorld")
local hub = worldFolder:WaitForChild("Hub")

local function wireStallPrompt(stallName, callback)
	local stall = hub:WaitForChild(stallName)
	local stallBase = stall:WaitForChild("Base")
	local prompt = stallBase:WaitForChild("Prompt")
	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer == player then
			callback()
		end
	end)
end


--------------------------------------------------------------------
-- Egg hatch interaction: walk up to your egg in your pen and press
-- E / tap, same as the hub stations. Eggs are created and destroyed
-- dynamically as your base changes, so we watch for new ones.
--------------------------------------------------------------------

local function wireEggModel(model)
	-- with StreamingEnabled the egg's parts can arrive a moment after the model
	local body = model:WaitForChild("MonsterBody", 10)
	local prompt = body and body:WaitForChild("Prompt", 10)
	local kind = model:GetAttribute("Kind")
	if not prompt or (kind ~= "egg" and kind ~= "monster") then
		return
	end
	if kind == "egg" then
		-- your own eggs always show "Hatch Egg" (E / click on PC, hold on mobile).
		-- Not ready yet -> it offers the egg-skip product for the time left.
		local UIS = game:GetService("UserInputService")
		task.spawn(function()
			while model.Parent and prompt.Parent do
				local readyAt = model:GetAttribute("ReadyAt") or math.huge
				local on = not model:GetAttribute("Hatching")
				if prompt.Enabled ~= on then
					prompt.Enabled = on
				end
				local ready = workspace:GetServerTimeNow() >= readyAt
				local action = ready and "Hatch Egg" or "Hatch Egg Now"
				if prompt.ActionText ~= action then
					prompt.ActionText = action
				end
				prompt.ClickablePrompt = true
				local hold = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and 0.5 or 0
				if prompt.HoldDuration ~= hold then
					prompt.HoldDuration = hold
				end
				task.wait(0.5)
			end
		end)
	end

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end

		local baseUid = model.Name

		if kind == "egg" then
			local readyAt = model:GetAttribute("ReadyAt") or math.huge
			if workspace:GetServerTimeNow() < readyAt then
				-- still incubating: offer the smallest egg skip that covers the time left
				local info = remotes:WaitForChild("EggSkipTarget"):InvokeServer(baseUid)
				if type(info) == "table" and info.productId then
					local left = math.max(0, math.floor(info.left or 0))
					local h, m = math.floor(left / 3600), math.floor((left % 3600) / 60)
					clientBridge:WaitForChild("ConfirmPurchase"):Fire({
						kind = "product",
						id = info.productId,
						title = "Hatch Egg Now",
		fallback = "SKIP",
		image = Config.Products.eggSkipImageId,
						desc = "Skip this egg's timer and hatch it right away!\nTime left: " .. h .. "h " .. m .. "m",
						note = info.hours .. " HOUR SKIP",
					})
					return
				elseif not (type(info) == "table" and info.ready) then
					return
				end
			end
			local response = hatchRemote:InvokeServer(baseUid)
			if response.profile then
				profile = response.profile
			end
			-- no popup: the egg shakes in the pen and the monster pops out of it
			if not response.success then
				showToast(response.message or "Not ready yet.", Color3.fromRGB(255, 166, 111))
			end
		else
			local response = unequipRemote:InvokeServer(baseUid)
			if response.profile then
				profile = response.profile
			end
			showToast(response.message or "Not able to unequip that.", response.success and COLOR.gold or Color3.fromRGB(255, 166, 111))
			if response.success then
				updateStats()
			end
		end
	end)
end

task.spawn(function()
	local myBaseModel = workspace.MonsterRNGWorld:WaitForChild("Base_" .. player.UserId, 15)
	if not myBaseModel then
		return
	end
	local myPets = myBaseModel:WaitForChild("Pets")
	for _, model in ipairs(myPets:GetChildren()) do
		task.spawn(wireEggModel, model)
	end
	myPets.ChildAdded:Connect(wireEggModel)
end)

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	updateStats()
	if heldItem then
		local list = heldItem.kind == "egg" and profile.eggs or profile.monsters
		local stillHave = false
		for _, item in ipairs(list or {}) do
			if item.uid == heldItem.uid then
				stillHave = true
				break
			end
		end
		if not stillHave then
			stopHolding()
		end
	end
	for _, entry in ipairs(cards) do
		refreshCard(entry.monster, entry.card, entry.parts)
	end
end)

updateStats()
-- cash HUD now lives in StarterGui.HUD
hud.Visible = false

-- old code-built side buttons + windows are replaced by StarterGui UI;
-- remove them completely so they can't be tapped on mobile
do
	local oldButtons = { SHOP = true, BOSS = true, PVP = true, INDEX = true }
	local oldTitles = { ["MONSTER INDEX"] = true, ["PVP COLOSSEUM"] = true, ["UPGRADE SHOP"] = true }
	for _, c in ipairs(gui:GetChildren()) do
		if c:IsA("TextButton") and oldButtons[c.Name] then
			c:Destroy()
		elseif c:IsA("Frame") then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("TextLabel") and oldTitles[d.Text] then
					c:Destroy()
					break
				end
			end
		end
	end
end
