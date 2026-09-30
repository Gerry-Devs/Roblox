local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local rollRemote = remotes:WaitForChild("Roll")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local openBackpackBridge = bridge:WaitForChild("OpenBackpack")
local openUpgradesBridge = bridge:WaitForChild("OpenUpgrades")
local closeAllBridge = bridge:WaitForChild("CloseAll")
local requestRollBridge = bridge:WaitForChild("RequestRoll")

local profile = profileRemote:InvokeServer()

--------------------------------------------------------------------
-- BottomBar: Backpack / Roll / Upgrade buttons, Auto Roll + Hide Roll
-- toggles, and the roll reveal. Customize in StarterGui.BottomBar:
--   • Button art:        Bar.BackpackButton / RollButton / UpgradeButton .Image
--   • Auto/Hide icons:    RollOptions.AutoButton.Icon / HideButton.Icon
--                        (white images; the text glyph hides once set)
--   • Reveal sunburst:   Reveal.Burst.Image (spins; blank = simple rays)
--   • Egg picture:       Backpack.ItemIcons.Egg_<Rarity> (shared with backpack)
--------------------------------------------------------------------

local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local barScale = bar:WaitForChild("UIScale")
local backpackButton = bar:WaitForChild("BackpackButton")
local rollButton = bar:WaitForChild("RollButton")
local upgradeButton = bar:WaitForChild("UpgradeButton")
local stage = gui:WaitForChild("Stage")
local stageScale = stage:WaitForChild("UIScale")
local rollOptions = stage:WaitForChild("RollOptions")
local autoButton = rollOptions:WaitForChild("AutoButton")
local hideButton = rollOptions:WaitForChild("HideButton")

local reveal = stage:WaitForChild("Reveal")
local revealScale = reveal:WaitForChild("UIScale")
local burst = reveal:WaitForChild("Burst")
local rays = burst:WaitForChild("Rays")
local orb = reveal:WaitForChild("Orb")
local orbScale = orb:WaitForChild("UIScale")
local orbStroke = orb:WaitForChild("UIStroke")
local orbIcon = orb:WaitForChild("Icon")
local orbFallback = orb:WaitForChild("Fallback")
local rarityText = reveal:WaitForChild("RarityText")
local resultText = reveal:WaitForChild("ResultText")
local feed = gui:WaitForChild("Feed")

local OUTLINE = Color3.fromRGB(10, 15, 35)
local BLUE = Color3.fromRGB(60, 160, 255)
local GREEN = Color3.fromRGB(60, 205, 95)
local PURPLE = Color3.fromRGB(150, 90, 255)
local RED = Color3.fromRGB(255, 110, 110)

-- One roll takes Config.GetRollDuration() seconds (4.5s base, shorter
-- with the Roll Speed upgrade). Rolls are never sent faster than that,
-- whether shown, hidden or auto — the server enforces the same limit.
local function getRollDuration()
	return Config.GetRollDuration(profile and profile.upgrades) * Config.PassRollTimeMultiplier(profile)
end

local rolling = false
local pendingRoll = false
local autoRoll = false
local hideRoll = false
local applyStageMode -- set at the bottom of the script
local UIS_MINI = game:GetService("UserInputService")
local MINI_SCALE = (UIS_MINI.TouchEnabled and not UIS_MINI.KeyboardEnabled) and 0.28 or 0.3 -- mini roll size
local lastRollAt = 0
local revealToken

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------

local function colorFromTable(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Press/hover animation via UIScale, so repeated clicks can never make
-- the button drift smaller (the old Size-based animation could).
local function bounce(button, hoverScale)
	local s = button:FindFirstChildOfClass("UIScale")
	if not s then
		return
	end
	hoverScale = hoverScale or 1.06
	button.MouseEnter:Connect(function()
		tween(s, 0.1, { Scale = hoverScale })
	end)
	button.MouseLeave:Connect(function()
		tween(s, 0.1, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(s, 0.06, { Scale = 0.9 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(s, 0.14, { Scale = hoverScale }, Enum.EasingStyle.Back)
	end)
end

local function layoutIconButton(button)
	local icon, label = button:FindFirstChild("Icon"), button:FindFirstChild("Label")
	if not icon or not label then
		return
	end
	icon.Visible = icon.Image ~= ""
	if icon.Visible then
		label.Position = UDim2.new(0.5, 18, 0.5, 0)
		label.Size = UDim2.new(1, -52, 0.58, 0)
	end
end

local function feedMessage(text, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(280, 22)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = OUTLINE
	label.LayoutOrder = math.floor(os.clock() * 100)
	label.Parent = feed

	local entries = {}
	for _, c in ipairs(feed:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(entries, c)
		end
	end
	if #entries > 5 then
		table.sort(entries, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		entries[1]:Destroy()
	end

	task.delay(1.6, function()
		if label.Parent then
			tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
			Debris:AddItem(label, 0.4)
		end
	end)
end

local function getEggImage(rarity)
	if Config.EggIcons and Config.EggIcons[rarity.key] then
		return Config.EggIcons[rarity.key]
	end
	local backpack = playerGui:FindFirstChild("Backpack")
	local icons = backpack and backpack:FindFirstChild("ItemIcons")
	local value = icons and icons:FindFirstChild("Egg_" .. rarity.key)
	return value and value.Value or ""
end

local function updatePity()
	-- pity system removed
end

--------------------------------------------------------------------
-- Reveal animation (purely visual — it never blocks clicks)
--------------------------------------------------------------------

rays.Visible = burst.Image == ""

-- While the roll animation is on screen, every other GUI is hidden and
-- only the roll + Auto/Hide show. Auto/Hide fade out at the same moment
-- the roll does, and everything else comes back. With Hide Roll on
-- there's no animation, so Auto/Hide show while a hidden roll is in
-- progress (or auto roll is running) so they can still be turned off.
local optionsShown = false
local revealClosing = false
local hiddenRollUntil = 0

local function setOptionsShown(show)
	if show == optionsShown then
		return
	end
	optionsShown = show
	if show then
		rollOptions.Visible = true
		tween(rollOptions, 0.15, { GroupTransparency = 0 })
	else
		local tw = tween(rollOptions, 0.18, { GroupTransparency = 1 })
		tw.Completed:Connect(function()
			if not optionsShown then
				rollOptions.Visible = false
			end
		end)
	end
end

local HIDE_CORE = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.EmotesMenu,
}
local uiHidden = false
local hiddenGuis = {}
local savedCore = {}

local function setOtherUiHidden(hide)
	if hide == uiHidden then
		return
	end
	uiHidden = hide
	if hide then
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		bar.Visible = false
		feed.Visible = false
		for _, t in ipairs(HIDE_CORE) do
			local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
			if ok then
				savedCore[t] = enabled
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false)
			end
		end
	else
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hiddenGuis = {}
		bar.Visible = true
		feed.Visible = true
		for t, enabled in pairs(savedCore) do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, enabled)
		end
		savedCore = {}
	end
end

RunService.RenderStepped:Connect(function(dt)
	if reveal.Visible then
		burst.Rotation = (burst.Rotation + dt * 60) % 360
	end
	local revealShowing = reveal.Visible and not revealClosing
	-- Auto/Hide appear with the roll animation. In HIDE mode (or with the
	-- HUD hidden) the roll plays small at the top and the rest of the UI
	-- stays visible.
	local mini = hideRoll or player:GetAttribute("HudHidden") == true
	setOptionsShown(revealShowing and not mini) -- AUTO/HIDE only on the big roll
	setOtherUiHidden(revealShowing and not mini)
end)

local function paintOrb(rarity)
	local color = colorFromTable(rarity.color)
	orb.BackgroundColor3 = color
	rarityText.Text = rarity.name:upper()
	rarityText.TextColor3 = color
	burst.ImageColor3 = color
	for _, r in ipairs(rays:GetChildren()) do
		r.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
	end
end

local function confetti(color)
	for _ = 1, 14 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(12, 12)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = orb.Position
		piece.Rotation = math.random(0, 90)
		piece.BackgroundColor3 = math.random() < 0.5 and color or Color3.new(1, 1, 1)
		piece.BorderSizePixel = 0
		piece.ZIndex = 5
		local stroke = Instance.new("UIStroke")
		stroke.Color = OUTLINE
		stroke.Thickness = 2
		stroke.Parent = piece
		piece.Parent = reveal
		local angle = math.random() * math.pi * 2
		local dist = math.random(110, 190)
		tween(piece, 0.6, {
			Position = orb.Position + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist),
			Rotation = piece.Rotation + math.random(-180, 180),
			BackgroundTransparency = 1,
		})
		tween(stroke, 0.6, { Transparency = 1 })
		Debris:AddItem(piece, 0.7)
	end
end

-- Plays the spin → land animation, stretched to fill `duration`.
-- Yields until the result has been shown, then fades out on its own.
local REVEAL_SCALE = 1.3 -- how big the roll animation is
local lastHiddenRarity

--------------------------------------------------------------------
-- WILD + the egg wheel
--------------------------------------------------------------------
local WILD = { name = "WILD", key = "WILD", tier = 0, color = { 255, 205, 40 } }
local WHEEL_OUTLINE = Color3.fromRGB(10, 15, 35)
local WHEEL_SIZE = 440 -- wheel diameter (px)
local STUDS_IMAGE = Config.UIStudsImage or ""
local wheel = {} -- the built wheel's parts

local function wmk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function wcorner(o, r)
	return wmk("UICorner", { CornerRadius = r or UDim.new(1, 0) }, o)
end
local function wstroke(o, t, c)
	return wmk("UIStroke", { Thickness = t or 3, Color = c or WHEEL_OUTLINE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
-- a small egg shape with a shine
local function eggShape(parent, color, size, pos, z)
	local egg = wmk("Frame", { Size = size, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, BackgroundColor3 = color, ZIndex = z }, parent)
	wcorner(egg, UDim.new(0.5, 0))
	wstroke(egg, 3)
	wmk("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45), color:Lerp(Color3.new(0, 0, 0), 0.2)) }, egg)
	local shine = wmk("Frame", { Size = UDim2.fromScale(0.26, 0.26), Position = UDim2.fromScale(0.2, 0.14), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, ZIndex = z + 1 }, egg)
	wcorner(shine)
	return egg
end

-- Builds the wheel once:
--   dark backdrop + turning gold rays, a title that pops, the gold rim
--   with 20 chasing light bulbs, real pie slices (made of thin wedges)
--   in each rarity's color with an egg, name and % chance, a studded hub
--   and a red pointer at the top that flicks on every slice.
local function buildWheel()
	if wheel.gui then
		return
	end
	local gui = wmk("ScreenGui", { Name = "EggWheel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	wheel.gui = gui
	wheel.dim = wmk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 6, 24), BackgroundTransparency = 0.25 }, gui)
	-- soft purple glow in the middle
	local glow = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(1.2, 1.2), BackgroundColor3 = Color3.fromRGB(140, 80, 255), BackgroundTransparency = 0, ZIndex = 1 }, wheel.dim)
	wcorner(glow)
	wmk("UIAspectRatioConstraint", {}, glow)
	wmk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) }, glow)

	local holder = wmk("Frame", { Size = UDim2.fromOffset(WHEEL_SIZE + 80, WHEEL_SIZE + 150), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundTransparency = 1, ZIndex = 2 }, gui)
	wheel.scale = wmk("UIScale", {}, holder)
	local cy = 128 + WHEEL_SIZE / 2 -- wheel center (y)

	-- gold rays turning behind the wheel
	wheel.rays = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((WHEEL_SIZE + 80) / 2, cy), Size = UDim2.fromOffset(WHEEL_SIZE * 2.2, WHEEL_SIZE * 2.2), BackgroundTransparency = 1, ZIndex = 2 }, holder)
	for i = 0, 8 do
		local ray = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.1, 0, 1, 0), Rotation = i * 20, BackgroundColor3 = Color3.fromRGB(255, 220, 120), BorderSizePixel = 0, ZIndex = 2 }, wheel.rays)
		wmk("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(0.7, 0.9), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	end

	-- title: "WILD x3!" + subtitle
	wheel.title = wmk("TextLabel", { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = "WILD x3!", TextColor3 = Color3.new(1, 1, 1), ZIndex = 10 }, holder)
	wmk("UIStroke", { Color = WHEEL_OUTLINE, Thickness = 6 }, wheel.title)
	wheel.titleGrad = wmk("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 140, 30)) }, wheel.title)
	wheel.titleScale = wmk("UIScale", {}, wheel.title)
	wheel.sub = wmk("TextLabel", { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 70), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = "SPIN THE EGG WHEEL!", TextColor3 = Color3.new(1, 1, 1), ZIndex = 10 }, holder)
	wmk("UIStroke", { Color = WHEEL_OUTLINE, Thickness = 4 }, wheel.sub)

	-- rim: thick gold ring with studs + light bulbs
	local rim = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((WHEEL_SIZE + 80) / 2, cy), Size = UDim2.fromOffset(WHEEL_SIZE + 44, WHEEL_SIZE + 44), BackgroundColor3 = Color3.fromRGB(255, 200, 50), ZIndex = 4 }, holder)
	wcorner(rim)
	wstroke(rim, 6)
	wmk("UIGradient", { Rotation = 45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 185, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 120, 20)) }) }, rim)
	if STUDS_IMAGE ~= "" then
		local st = wmk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = STUDS_IMAGE, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(26, 26), ImageTransparency = 0.55, ZIndex = 4 }, rim)
		wcorner(st)
	end
	wheel.bulbs = {}
	local BULBS = 20
	for i = 1, BULBS do
		local a = math.rad((i - 1) * (360 / BULBS))
		local r = (WHEEL_SIZE + 22) / 2
		local b = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r), Size = UDim2.fromOffset(15, 15), BackgroundColor3 = Color3.fromRGB(255, 255, 220), ZIndex = 6 }, rim)
		wcorner(b)
		wstroke(b, 2)
		wheel.bulbs[i] = b
	end

	-- the disc that spins
	local disc = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE), BackgroundColor3 = Color3.fromRGB(22, 24, 44), ZIndex = 5 }, rim)
	wcorner(disc)
	wstroke(disc, 5)
	wheel.disc = disc
	local slices = Config.Wild.wheel
	local seg = 360 / #slices
	local total = 0
	for _, s in ipairs(slices) do
		total += s.weight
	end
	local R = WHEEL_SIZE / 2
	local STEP = 3 -- degrees per wedge
	local wedgeW = math.ceil(2 * R * math.tan(math.rad(STEP / 2))) + 3
	wheel.sliceParts = {}
	for i, slice in ipairs(slices) do
		local rarity = Config.GetRarity(slice.rarity)
		local color = colorFromTable(rarity.color)
		local center = (i - 1) * seg
		local parts = {}
		-- pie slice: thin wedges from the middle out, lighter at the rim
		for a = center - seg / 2 + STEP / 2, center + seg / 2 - STEP / 2 + 0.01, STEP do
			local spoke = wmk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = a, ZIndex = 5 }, disc)
			local wedge = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, wedgeW, 0.5, -2), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 5 }, spoke)
			wmk("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.35)) }, wedge)
			table.insert(parts, wedge)
		end
		-- divider at the slice's edge
		local divSpoke = wmk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = center + seg / 2, ZIndex = 7 }, disc)
		local div = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 5, 0.5, -2), BackgroundColor3 = Color3.fromRGB(255, 235, 170), BorderSizePixel = 0, ZIndex = 7 }, divSpoke)
		wstroke(div, 1.5)
		-- egg + name + chance, facing outward
		local labelSpoke = wmk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = center, ZIndex = 8 }, disc)
		if slice.imageId and slice.imageId ~= "" then
			-- your own picture for this slice
			wmk("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, Image = slice.imageId, ScaleType = Enum.ScaleType.Fit, ZIndex = 9 }, labelSpoke)
		else
			eggShape(labelSpoke, color:Lerp(Color3.new(1, 1, 1), 0.2), UDim2.fromOffset(46, 58), UDim2.new(0.5, 0, 0, 58), 9)
		end
		local name = wmk("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(120, 26), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = rarity.name:upper(), TextColor3 = Color3.new(1, 1, 1), ZIndex = 9 }, labelSpoke)
		wmk("UIStroke", { Color = WHEEL_OUTLINE, Thickness = 3 }, name)
		local pct = math.floor(slice.weight / total * 1000 + 0.5) / 10
		local chance = wmk("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(80, 20), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = tostring(pct) .. "%", TextColor3 = Color3.fromRGB(255, 240, 170), ZIndex = 9 }, labelSpoke)
		wmk("UIStroke", { Color = WHEEL_OUTLINE, Thickness = 2.5 }, chance)
		wheel.sliceParts[i] = { wedges = parts, color = color }
	end
	-- dark inner ring (depth) + studded hub
	local hub = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(104, 104), BackgroundColor3 = Color3.fromRGB(255, 200, 50), ZIndex = 12 }, rim)
	wcorner(hub)
	wstroke(hub, 5)
	wmk("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(220, 130, 20)) }, hub)
	if STUDS_IMAGE ~= "" then
		local st = wmk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = STUDS_IMAGE, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(26, 26), ImageTransparency = 0.5, ZIndex = 12 }, hub)
		wcorner(st)
	end
	wheel.hubText = wmk("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.8, 0.36), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = "WILD", TextColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, hub)
	wmk("UIStroke", { Color = WHEEL_OUTLINE, Thickness = 3 }, wheel.hubText)
	wheel.hubScale = wmk("UIScale", {}, hub)

	-- pointer: red studded pin at the top, pivoting from its top
	local pin = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset((WHEEL_SIZE + 80) / 2, 128 - 30), Size = UDim2.fromOffset(56, 84), BackgroundTransparency = 1, ZIndex = 14 }, holder)
	wheel.pin = pin
	local tip = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(38, 38), Rotation = 45, BackgroundColor3 = Color3.fromRGB(235, 50, 60), ZIndex = 14 }, pin)
	wcorner(tip, UDim.new(0, 6))
	wstroke(tip, 4)
	local head = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = Color3.fromRGB(245, 60, 70), ZIndex = 15 }, pin)
	wcorner(head)
	wstroke(head, 4)
	wmk("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 140, 140), Color3.fromRGB(190, 30, 45)) }, head)
	local dot = wmk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.fromRGB(255, 230, 230), ZIndex = 16 }, head)
	wcorner(dot)
	wstroke(dot, 2)

	-- result banner (under the wheel)
	wheel.result = wmk("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(WHEEL_SIZE + 60, 64), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 20, Visible = false }, holder)
	wmk("UIStroke", { Color = WHEEL_OUTLINE, Thickness = 6 }, wheel.result)
	wheel.resultScale = wmk("UIScale", {}, wheel.result)
	wheel.holder = holder
	wheel.center = Vector2.new((WHEEL_SIZE + 80) / 2, cy)
end

-- confetti burst from the wheel's middle
local function wheelBurst(color)
	for _ = 1, 36 do
		local piece = wmk("Frame", { Size = UDim2.fromOffset(math.random(8, 16), math.random(8, 16)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(wheel.center.X, wheel.center.Y), Rotation = math.random(0, 90), BackgroundColor3 = math.random() < 0.5 and color or (math.random() < 0.5 and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)), BorderSizePixel = 0, ZIndex = 18 }, wheel.holder)
		wstroke(piece, 2)
		local a = math.random() * math.pi * 2
		local d = math.random(180, 380)
		local tw = TweenService:Create(piece, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(wheel.center.X + math.cos(a) * d, wheel.center.Y + math.sin(a) * d), Rotation = piece.Rotation + math.random(-360, 360), BackgroundTransparency = 1 })
		tw:Play()
		Debris:AddItem(piece, 1.2)
	end
end

-- spins the wheel so slice `index` ends under the pointer (yields ~7s)
local function spinWheel(index)
	buildWheel()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.min(1, (v.Y - 30) / (WHEEL_SIZE + 150), (v.X - 20) / (WHEEL_SIZE + 80))
	local seg = 360 / #Config.Wild.wheel
	local disc = wheel.disc
	disc.Rotation = 0
	wheel.title.Text = "WILD x3!"
	wheel.titleGrad.Color = ColorSequence.new(Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 140, 30))
	wheel.sub.Text = "SPIN THE EGG WHEEL!"
	wheel.sub.Visible = true
	wheel.result.Visible = false
	wheel.hubText.Text = "WILD"
	for _, s in ipairs(wheel.sliceParts) do
		for _, w in ipairs(s.wedges) do
			w.BackgroundColor3 = s.color
		end
	end
	wheel.scale.Scale = fit * 0.3
	wheel.dim.BackgroundTransparency = 1
	wheel.gui.Enabled = true
	tween(wheel.dim, 0.3, { BackgroundTransparency = 0.25 })
	tween(wheel.scale, 0.45, { Scale = fit }, Enum.EasingStyle.Back)
	wheel.titleScale.Scale = 0
	tween(wheel.titleScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)

	-- one loop animates the rays, bulbs, title and pointer
	local spinning = true
	local landed = false
	local lastSlot
	local pinKick = 0
	local tickSound = script:FindFirstChild("WheelTick")
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not wheel.gui.Enabled then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		wheel.rays.Rotation = t * (spinning and 40 or 15)
		-- bulbs: chase while spinning, all blink when it lands
		for i, b in ipairs(wheel.bulbs) do
			local on
			if landed then
				on = math.floor(t * 6) % 2 == 0
			else
				on = (i + math.floor(t * (spinning and 18 or 5))) % 3 == 0
			end
			b.BackgroundColor3 = on and Color3.fromRGB(255, 255, 220) or Color3.fromRGB(150, 90, 20)
		end
		wheel.title.Rotation = math.sin(t * 3) * 3
		-- pointer flicks on every slice edge it passes
		local slot = math.floor((disc.Rotation + seg / 2) / seg)
		if lastSlot and slot ~= lastSlot then
			pinKick = 1
			if tickSound then
				tickSound:Play()
			end
		end
		lastSlot = slot
		pinKick = math.max(0, pinKick - dt * 7)
		wheel.pin.Rotation = -pinKick * 28
	end)

	task.wait(0.6)
	local target = -((index - 1) * seg) - 360 * 7 + math.random(-math.floor(seg * 0.3), math.floor(seg * 0.3))
	TweenService:Create(disc, TweenInfo.new(5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target }):Play()
	wheel.sub.Text = "SPINNING..."
	task.wait(5.05)
	spinning = false
	landed = true

	-- the win: slice flashes, hub + title show it, confetti
	local rarity = Config.GetRarity(Config.Wild.wheel[index].rarity)
	local color = colorFromTable(rarity.color)
	local win = wheel.sliceParts[index]
	task.spawn(function()
		for k = 1, 6 do
			for _, w in ipairs(win.wedges) do
				w.BackgroundColor3 = (k % 2 == 1) and Color3.new(1, 1, 1) or win.color
			end
			task.wait(0.12)
		end
	end)
	wheel.hubText.Text = "WIN!"
	wheel.hubScale.Scale = 1.3
	tween(wheel.hubScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	wheel.title.Text = rarity.name:upper() .. "!"
	wheel.titleGrad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5), color)
	wheel.titleScale.Scale = 1.5
	tween(wheel.titleScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	wheel.sub.Visible = false
	wheel.result.Text = "YOU GOT A " .. rarity.name:upper() .. " EGG!"
	wheel.result.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
	wheel.result.Visible = true
	wheel.resultScale.Scale = 0
	tween(wheel.resultScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	wheelBurst(color)
	task.wait(0.35)
	wheelBurst(color)
	task.wait(1.8)
	tween(wheel.scale, 0.25, { Scale = fit * 0.2 }, Enum.EasingStyle.Back)
	tween(wheel.dim, 0.25, { BackgroundTransparency = 1 })
	task.wait(0.27)
	wheel.gui.Enabled = false
end

local function spinOrb(final, spinTime, token)
	-- steps start fast and slow down (eased), scaled to spinTime
	local spins = math.floor(12 + spinTime * 5)
	local waits, total = {}, 0
	for i = 1, spins do
		local p = i / spins
		waits[i] = 0.03 + (p ^ 2.4) * 0.16
		total += waits[i]
	end
	for i = 1, spins do
		local step = (i == spins) and final or Config.Rarities[math.random(1, math.min(6, #Config.Rarities))]
		paintOrb(step)
		orb.Rotation = (i % 2 == 0) and 7 or -7
		orbScale.Scale = 1.06
		tween(orbScale, 0.08, { Scale = 1 })
		task.wait(waits[i] / total * spinTime)
		if revealToken ~= token then
			return false
		end
	end
	return true
end

-- 3 WILD slots above the orb: each WILD fills one and stays
local wildRow
local function showWildTokens(count)
	if not wildRow then
		wildRow = Instance.new("Frame")
		wildRow.Name = "WildRow"
		wildRow.Size = UDim2.fromOffset(330, 66)
		wildRow.AnchorPoint = Vector2.new(0.5, 1)
		wildRow.Position = UDim2.new(0.5, 0, 0, -4)
		wildRow.BackgroundTransparency = 1
		wildRow.Parent = reveal
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = wildRow
		for i = 1, 3 do
			local card = Instance.new("Frame")
			card.Name = "W" .. i
			card.LayoutOrder = i
			card.Size = UDim2.fromOffset(98, 60)
			card.BackgroundColor3 = Color3.fromRGB(40, 44, 70)
			card.Parent = wildRow
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(10, 15, 35)
			st.Thickness = 3
			st.Parent = card
			Instance.new("UIScale", card)
			local t = Instance.new("TextLabel")
			t.Name = "Text"
			t.Size = UDim2.new(1, -10, 0.8, 0)
			t.Position = UDim2.new(0, 5, 0.1, 0)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.LuckiestGuy
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(150, 156, 180)
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
			t.Text = "?"
			t.Parent = card
		end
	end
	wildRow.Visible = count > 0
	for i = 1, 3 do
		local card = wildRow["W" .. i]
		local filled = i <= count
		local wasFilled = card:GetAttribute("Filled") == true
		card:SetAttribute("Filled", filled)
		card.BackgroundColor3 = filled and Color3.fromRGB(255, 200, 45) or Color3.fromRGB(40, 44, 70)
		card.Text.Text = filled and "WILD" or "?"
		card.Text.TextColor3 = filled and Color3.new(1, 1, 1) or Color3.fromRGB(150, 156, 180)
		if filled and not wasFilled then
			card.UIScale.Scale = 1.6
			tween(card.UIScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
end

--------------------------------------------------------------------
-- Slot-reel reveal: eggs scroll down through a slot between two light
-- streaks; the middle one is big, the ones above/below small and faded.
-- It slows down and lands with a pop. Each WILD that lands flies to the
-- left and stays there. Double Roll = two reels, same size, same timing.
--------------------------------------------------------------------
local REEL_Y = 130 -- centre of the slot (same as the old orb)
local SLOT = 150 -- distance between eggs on the reel
local reelHolder = Instance.new("Frame")
reelHolder.Name = "Reels"
reelHolder.Size = UDim2.fromScale(1, 1)
reelHolder.BackgroundTransparency = 1
reelHolder.Parent = reveal

local totalWeight = 0
for _, r in ipairs(Config.Rarities) do
	totalWeight += r.weight
end
local function oddsText(r)
	if r.key == "WILD" then
		return "WILD"
	end
	return "1 / " .. Config.FormatNumber(math.max(1, math.floor(totalWeight / r.weight + 0.5)))
end

-- one egg card on the reel
local function makeCard(parent)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(150, 150)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundTransparency = 1
	card.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local egg = Instance.new("Frame")
	egg.Name = "Egg"
	egg.Size = UDim2.fromOffset(88, 108)
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = UDim2.fromScale(0.5, 0.5)
	egg.Parent = card
	Instance.new("UICorner", egg).CornerRadius = UDim.new(0.5, 0)
	local st = Instance.new("UIStroke")
	st.Color = OUTLINE
	st.Thickness = 4
	st.Parent = egg
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170))
	grad.Rotation = 90
	grad.Parent = egg
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(0.22, 0.2)
	shine.Position = UDim2.fromScale(0.2, 0.16)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.25
	shine.Parent = egg
	Instance.new("UICorner", shine).CornerRadius = UDim.new(0.5, 0)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(120, 120)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = card
	local wildText = Instance.new("TextLabel")
	wildText.Name = "Wild"
	wildText.Size = UDim2.fromScale(0.9, 0.4)
	wildText.AnchorPoint = Vector2.new(0.5, 0.5)
	wildText.Position = UDim2.fromScale(0.5, 0.5)
	wildText.BackgroundTransparency = 1
	wildText.Font = Enum.Font.LuckiestGuy
	wildText.TextScaled = true
	wildText.Text = "WILD"
	wildText.TextColor3 = Color3.new(1, 1, 1)
	wildText.TextStrokeTransparency = 0
	wildText.TextStrokeColor3 = OUTLINE
	wildText.Parent = egg
	local odds = Instance.new("TextLabel")
	odds.Name = "Odds"
	odds.Size = UDim2.fromOffset(150, 30)
	odds.AnchorPoint = Vector2.new(0.5, 0.5)
	odds.Position = UDim2.new(0.5, -6, 0.5, -64)
	odds.Rotation = -12
	odds.BackgroundTransparency = 1
	odds.Font = Enum.Font.LuckiestGuy
	odds.TextScaled = true
	odds.TextColor3 = Color3.fromRGB(120, 255, 200)
	odds.TextStrokeTransparency = 0
	odds.TextStrokeColor3 = OUTLINE
	odds.Parent = card
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.fromOffset(150, 28)
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.new(0.5, 0, 0.5, 68)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0
	name.TextStrokeColor3 = OUTLINE
	name.Parent = card
	return { frame = card, scale = scale, egg = egg, icon = icon, wild = wildText, odds = odds, name = name, stroke = st }
end

local function paintCard(c, r)
	if c.shown == r then
		return
	end
	c.shown = r
	local color = colorFromTable(r.color)
	c.egg.BackgroundColor3 = color
	local img = r.key ~= "WILD" and getEggImage(r) or ""
	c.icon.Image = img
	c.icon.Visible = img ~= ""
	c.egg.Visible = img == ""
	c.wild.Visible = r.key == "WILD"
	c.odds.Text = oddsText(r)
	c.name.Text = r.key == "WILD" and "WILD!" or (r.name .. " Egg")
	c.name.TextColor3 = r.key == "WILD" and color or Color3.new(1, 1, 1)
end

local function setCardFade(c, t)
	c.egg.BackgroundTransparency = t
	c.stroke.Transparency = t
	c.icon.ImageTransparency = t
	c.wild.TextTransparency = t
	c.wild.TextStrokeTransparency = t
	c.odds.TextTransparency = t
	c.odds.TextStrokeTransparency = t
	c.name.TextTransparency = t
	c.name.TextStrokeTransparency = t
end

-- a reel column: 4 pooled cards + the two light streaks
local function makeReel(x)
	local col = Instance.new("Frame")
	col.Size = UDim2.fromScale(1, 1)
	col.BackgroundTransparency = 1
	col.Parent = reelHolder
	local glow = burst:Clone()
	glow.Name = "ReelGlow"
	glow.Position = UDim2.new(0.5, x, 0, REEL_Y)
	glow.Size = UDim2.fromOffset(250, 250)
	glow.ImageTransparency = 1
	for _, r in ipairs(glow:GetDescendants()) do
		if r:IsA("GuiObject") then
			r.Visible = false
		end
	end
	glow.Parent = col
	local streaks = {}
	local cards = {}
	for i = 1, 4 do
		local c = makeCard(col)
		c.frame.ZIndex = 3
		cards[i] = c
	end
	for _, side in ipairs({ -1, 1 }) do
		local streak = Instance.new("Frame")
		streak.Size = UDim2.fromOffset(90, 5)
		streak.AnchorPoint = Vector2.new(0.5, 0.5)
		streak.Position = UDim2.new(0.5, x + side * 118, 0, REEL_Y)
		streak.BackgroundColor3 = Color3.new(1, 1, 1)
		streak.BorderSizePixel = 0
		streak.Parent = col
		streaks[side] = streak
		Instance.new("UICorner", streak).CornerRadius = UDim.new(1, 0)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, side < 0 and 1 or 0), NumberSequenceKeypoint.new(1, side < 0 and 0 or 1) })
		g.Parent = streak
	end
	return { col = col, cards = cards, x = x, glow = glow, streaks = streaks }
end

local reels = {}
local function getReel(i, x)
	reels[i] = reels[i] or makeReel(x)
	local r = reels[i]
	if r.x ~= x then
		r.col:Destroy()
		reels[i] = makeReel(x)
		r = reels[i]
	end
	r.col.Visible = true
	return r
end

-- draw a reel at scroll position p (strip[k] sits in the slot when p == k)
local function drawReel(reel, strip, p)
	local base = math.floor(p)
	for i, c in ipairs(reel.cards) do
		local k = base - 1 + (i - 1)
		local r = strip[k]
		local d = k - p -- >0 = above the slot
		if r and math.abs(d) < 1.6 then
			paintCard(c, r)
			c.frame.Visible = true
			c.frame.Position = UDim2.new(0.5, reel.x, 0, REEL_Y - d * SLOT)
			local ad = math.min(1, math.abs(d))
			c.scale.Scale = 1 - ad * 0.45
			setCardFade(c, ad * 0.45 + math.max(0, math.abs(d) - 1) * 0.9)
		else
			c.frame.Visible = false
		end
	end
end

local FILLER_MAX = 6 -- fillers only use the normal rarities
local function buildStrip(final, count)
	local strip = {}
	for k = 1, count - 1 do
		strip[k] = Config.Rarities[math.random(1, math.min(FILLER_MAX, #Config.Rarities))]
	end
	strip[count] = final
	strip[count + 1] = Config.Rarities[math.random(1, 3)]
	return strip
end

-- spin one reel to `final` over `time` (eased: fast, then slows down)
local function spinReel(reel, final, time, token)
	local count = math.floor(10 + time * 7)
	local strip = buildStrip(final, count)
	local t0 = os.clock()
	while true do
		local k = math.clamp((os.clock() - t0) / time, 0, 1)
		local eased = 1 - (1 - k) ^ 3
		drawReel(reel, strip, 1 + eased * (count - 1))
		if k >= 1 or revealToken ~= token then
			break
		end
		RunService.RenderStepped:Wait()
	end
	return revealToken == token
end

local function landPop(reel, r)
	local c
	for _, card in ipairs(reel.cards) do
		if card.frame.Visible and card.scale.Scale > 0.9 then
			c = card
		end
	end
	local color = colorFromTable(r.color)
	reel.glow.ImageColor3 = color
	reel.glow.ImageTransparency = 0.15
	reel.glow.Rotation = 0
	tween(reel.glow, 0.9, { ImageTransparency = 0.55, Rotation = 30 })
	if c then
		c.scale.Scale = 1.35
		tween(c.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	confetti(color)
end

-- WILD cards stack on the left of the reel and stay
local wildStack = Instance.new("Frame")
wildStack.Name = "WildStack"
wildStack.Size = UDim2.fromOffset(110, 300)
wildStack.AnchorPoint = Vector2.new(1, 0.5)
wildStack.BackgroundTransparency = 1
wildStack.Parent = reveal
local wl = Instance.new("UIListLayout")
wl.FillDirection = Enum.FillDirection.Vertical
wl.VerticalAlignment = Enum.VerticalAlignment.Center
wl.HorizontalAlignment = Enum.HorizontalAlignment.Center
wl.Padding = UDim.new(0, 6)
wl.Parent = wildStack
local function clearWilds()
	for _, c in ipairs(wildStack:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end
local function addWildCard(fromX)
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromOffset(92, 58)
	chip.BackgroundColor3 = Color3.fromRGB(255, 200, 45)
	chip.Parent = wildStack
	Instance.new("UICorner", chip).CornerRadius = UDim.new(0.5, 0)
	local st = Instance.new("UIStroke")
	st.Color = OUTLINE
	st.Thickness = 4
	st.Parent = chip
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -10, 0.7, 0)
	t.Position = UDim2.new(0, 5, 0.15, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "WILD"
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = OUTLINE
	t.Parent = chip
	local s = Instance.new("UIScale")
	s.Scale = 1.8
	s.Parent = chip
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function playReveal(rarity, duration, wilds, wheelIndex, second)
	local token = {}
	revealToken = token
	revealClosing = false

	local hold = math.min(1.1, duration * 0.25)
	local spinTime = math.max(0.6, duration - hold - 0.15)

	-- old orb pieces are not used by the reel
	orb.Visible = false
	burst.Visible = false
	rarityText.Visible = false
	resultText.Visible = false
	if wildRow then
		wildRow.Visible = false
	end
	clearWilds()

	-- one reel, or two side by side (Double Roll) - same size, same timing
	local x1 = second and -112 or 0
	local reel1 = getReel(1, x1)
	local reel2
	if second then
		reel2 = getReel(2, 112)
	elseif reels[2] then
		reels[2].col.Visible = false
	end
	-- two reels: only the outer light streaks
	reel1.streaks[1].Visible = not second
	if reel2 then
		reel2.streaks[-1].Visible = false
	end
	wildStack.Position = UDim2.new(0.5, x1 - 100, 0, REEL_Y)
	for _, r in ipairs({ reel1, reel2 }) do
		r.glow.ImageTransparency = 1
		for _, c in ipairs(r.cards) do
			c.frame.Visible = false
		end
	end

	reveal.Visible = true
	revealScale.Scale = REVEAL_SCALE * 0.4
	tween(revealScale, 0.22, { Scale = REVEAL_SCALE }, Enum.EasingStyle.Back)

	-- WILD chain on the first reel: each WILD lands, flies left and stays
	for w = 1, (wilds or 0) do
		if reel2 then
			task.spawn(spinReel, reel2, Config.Rarities[math.random(1, 3)], w == 1 and math.max(0.5, spinTime * 0.6) or 0.7, token)
		end
		if not spinReel(reel1, WILD, w == 1 and math.max(0.5, spinTime * 0.6) or 0.7, token) then
			return
		end
		landPop(reel1, WILD)
		local wildSound = script:FindFirstChild("WildSound")
		if wildSound then
			wildSound:Play()
		end
		task.wait(0.45)
		if revealToken ~= token then
			return
		end
		addWildCard()
		task.wait(0.3)
	end
	if wheelIndex then
		spinWheel(wheelIndex)
		if revealToken ~= token then
			return
		end
		spinTime = 0.6
	elseif (wilds or 0) > 0 then
		spinTime = 0.9
	end

	-- the real result(s)
	local secondDone = true
	if reel2 and second and second.rarity then
		secondDone = false
		task.spawn(function()
			if spinReel(reel2, second.rarity, spinTime, token) then
				landPop(reel2, second.rarity)
			end
			secondDone = true
		end)
	end
	if not spinReel(reel1, rarity, spinTime, token) then
		return
	end
	landPop(reel1, rarity)
	while not secondDone and revealToken == token do
		task.wait()
	end

	task.wait(hold)

	task.delay(0.9, function()
		if revealToken == token then
			revealClosing = true
			tween(revealScale, 0.18, { Scale = REVEAL_SCALE * 0.6 })
			task.wait(0.18)
			if revealToken == token then
				reveal.Visible = false
			end
		end
	end)
end

--------------------------------------------------------------------
-- Rolling
--------------------------------------------------------------------

-- Performs exactly one roll. Returns (success, errorMessage).
local function rollOnce(isRetry)
	if rolling then
		return false, nil
	end
	rolling = true

	local waitFor = getRollDuration() - (os.clock() - lastRollAt)
	if waitFor > 0 then
		rollButton.ImageTransparency = 0.4
		task.wait(waitFor)
		rollButton.ImageTransparency = 0
	end
	lastRollAt = os.clock()

	local ok, response = pcall(function()
		return rollRemote:InvokeServer()
	end)

	if not ok or type(response) ~= "table" then
		rolling = false
		feedMessage("Roll failed \226\128\148 try again", RED)
		return false, "error"
	end

	if not response.success then
		rolling = false
		local msg = response.message or "The roll could not be completed."
		-- a timing rejection is retried once instead of silently dropped
		if not isRetry and msg:find("Slow down") then
			task.wait(0.4)
			return rollOnce(true)
		end
		feedMessage(msg, RED)
		return false, msg
	end

	profile = response.profile or profile
	updatePity()

	local mini = hideRoll or player:GetAttribute("HudHidden") == true
	if mini and player:GetAttribute("MiniRoll") == false then
		-- MINI ROLL off in Settings: just a short line instead of the animation
		if response.wheelIndex then
			spinWheel(response.wheelIndex) -- the wheel always shows, even in mini mode
		end
		feedMessage(((response.wilds or 0) > 0 and ("WILD x" .. response.wilds .. "! ") or "") .. "+1 " .. response.rarity.name .. " Egg" .. (response.second and (" + " .. response.second.rarity.name .. " Egg") or ""), colorFromTable(response.rarity.color))
	else
		playReveal(response.rarity, getRollDuration(), response.wilds, response.wheelIndex, response.second)
	end

	rolling = false
	return true
end

-- Manual rolls: a click during a roll is remembered and runs right
-- after, instead of being ignored.
local function requestRoll()
	if autoRoll then
		return
	end
	if rolling then
		pendingRoll = true
		return
	end
	task.spawn(function()
		repeat
			pendingRoll = false
			rollOnce()
		until not pendingRoll or autoRoll
	end)
end

--------------------------------------------------------------------
-- Auto roll / Hide roll
--------------------------------------------------------------------

local autoThread

local function styleToggles()
	local function style(button, on, onColor)
		button.BackgroundColor3 = on and onColor or Color3.new(0, 0, 0)
		button.BackgroundTransparency = on and 0.15 or 0.35
		button.Ring.Thickness = on and 4 or 0
	end
	style(autoButton, autoRoll, Color3.fromRGB(40, 170, 80))
	style(hideButton, hideRoll, Color3.fromRGB(130, 70, 230))

end

local function setAutoRoll(on)
	autoRoll = on
	pendingRoll = false
	styleToggles()
	if not on or autoThread then
		return
	end
	autoThread = task.spawn(function()
		while autoRoll do
			local ok, msg = rollOnce()
			if not ok then
				if msg and (msg:find("full") or msg:find("loading")) then
					-- backpack full etc. — stop instead of spamming the server
					autoRoll = false
					styleToggles()
					break
				end
				task.wait(msg and 1 or 0.1)
			else
				task.wait()
			end
		end
		autoThread = nil
	end)
end

autoButton.Activated:Connect(function()
	setAutoRoll(not autoRoll)
end)

hideButton.Activated:Connect(function()
	hideRoll = not hideRoll
	styleToggles()
	applyStageMode() -- small at the top (on) or back to the middle (off)
end)

--------------------------------------------------------------------
-- Bar buttons
--------------------------------------------------------------------

local function windowOpen(guiName)
	local g = playerGui:FindFirstChild(guiName)
	local m = g and g:FindFirstChild("Main")
	return m and m.Visible
end

-- ROLL button: in Hide Roll mode it turns Hide off (Auto stays as it
-- is). If a hidden roll is still in progress, it's revealed right away
-- for the time it has left instead of waiting for it to finish.
local function onRollButton()
	if hideRoll then
		hideRoll = false
		styleToggles()
		applyStageMode()
		if autoRoll then
			return -- auto keeps rolling, now with the big animation
		end
	end
	requestRoll()
end

rollButton.Activated:Connect(onRollButton)
requestRollBridge.Event:Connect(onRollButton) -- other scripts can start a roll too
requestRollBridge.Event:Connect(onRollButton)

backpackButton.Activated:Connect(function()
	if windowOpen("Backpack") then
		closeAllBridge:Fire()
	else
		closeAllBridge:Fire("backpack")
		openBackpackBridge:Fire()
	end
end)

upgradeButton.Activated:Connect(function()
	if windowOpen("UpgradeTree") then
		closeAllBridge:Fire()
	else
		closeAllBridge:Fire("upgrades")
		openUpgradesBridge:Fire()
	end
end)

for _, b in ipairs({ backpackButton, rollButton, upgradeButton }) do
	bounce(b, 1.05)
end
for _, b in ipairs({ autoButton, hideButton }) do
	local hasIcon = b.Icon.Image ~= ""
	b.Icon.Visible = hasIcon
	b.Glyph.Visible = not hasIcon
	bounce(b)
end

--------------------------------------------------------------------
-- Screen scaling + live data
--------------------------------------------------------------------

local function updateScale()
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 0 then
		local s = math.clamp(camera.ViewportSize.X / 1000, 0.55, 1)
		local BAR_SCALE = 0.65 -- size of the Backpack / Roll / Upgrade buttons (PC)
		local MOBILE_BAR_SCALE = 0.6 -- size on phones / tablets
		local UIS = game:GetService("UserInputService")
		if UIS.TouchEnabled and not UIS.KeyboardEnabled then
			-- phones: size from the short side of the screen so it stays easy to tap
			local v = camera.ViewportSize
			barScale.Scale = math.clamp(math.min(v.X / 1000, v.Y / 480), 0.6, 1) * MOBILE_BAR_SCALE
		else
			barScale.Scale = s * BAR_SCALE
		end
		-- roll + Auto/Hide fit the screen height too
		local v = camera.ViewportSize
		stageScale.Scale = math.clamp(math.min(v.X / 1000, v.Y / 720), 0.5, 1) * ((hideRoll or player:GetAttribute("HudHidden")) and MINI_SCALE or 1)
		-- phones: AUTO / HIDE sit a little higher
		local rollOptions = stage:FindFirstChild("RollOptions")
		if rollOptions then
			rollOptions:SetAttribute("HomePos", rollOptions:GetAttribute("HomePos") or rollOptions.Position)
			local home = rollOptions:GetAttribute("HomePos")
			if UIS.TouchEnabled and not UIS.KeyboardEnabled then
				rollOptions.Position = home - UDim2.fromOffset(0, 45)
			else
				rollOptions.Position = home
			end
		end
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- the Roll button shows the equipped dice (Common = the default art)
local DEFAULT_ROLL_IMAGE = rollButton.Image
local function updateRollImage()
	local dice = Config.GetDice(profile and profile.equippedDice)
	local img = (dice and dice.imageId ~= "" and dice.imageId) or DEFAULT_ROLL_IMAGE
	if rollButton.Image ~= img then
		rollButton.Image = img
	end
end
updateRollImage()

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	updatePity()
	updateRollImage()
end)

reveal.Visible = false
styleToggles()
updatePity()

-- HIDE button or HUD hidden (eye button): the egg + dice roll plays as a
-- small animation at the top of the screen instead of the middle
local stageHomeAnchor, stageHomePos = stage.AnchorPoint, stage.Position
applyStageMode = function()
	if hideRoll or player:GetAttribute("HudHidden") then
		stage.AnchorPoint = Vector2.new(0.5, 0)
		stage.Position = UDim2.new(0.5, 0, 0, 58) -- just below the top bar
	else
		stage.AnchorPoint = stageHomeAnchor
		stage.Position = stageHomePos
	end
	updateScale()
end
player:GetAttributeChangedSignal("HudHidden"):Connect(applyStageMode)
applyStageMode()
