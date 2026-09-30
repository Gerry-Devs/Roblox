local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--------------------------------------------------------------------
-- Loading screen: shows the moment a player joins and stays until the
-- map, their pen, their data, the monsters and the pictures are loaded.
-- Cartoony + studded like the rest of the game: glowing rays behind the
-- logo, floating rarity eggs, a glossy progress bar with an egg riding
-- on it, and tips. A SKIP button shows after a few seconds.
--------------------------------------------------------------------
ReplicatedFirst:RemoveDefaultLoadingScreen()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- (ReplicatedStorage may not be loaded yet, so the ids live here)
local STUDS_IMAGE = "rbxassetid://139993005514116"
local DICE_IMAGE = "rbxassetid://88531005888419"

local OUTLINE = Color3.fromRGB(12, 14, 32)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local GOLD = Color3.fromRGB(255, 205, 60)
-- egg pictures (same ids as Config.EggIcons; Config isn't loaded yet here)
local EGG_IMAGES = {
	"rbxassetid://89065974622258", -- common
	"rbxassetid://127482163109698", -- uncommon
	"rbxassetid://110319386910427", -- rare
	"rbxassetid://128903214440900", -- epic
	"rbxassetid://104500738290331", -- legendary
	"rbxassetid://128239034591198", -- mythic
	"rbxassetid://129812693239921", -- secret
	"rbxassetid://92395625284904", -- celestial
	"rbxassetid://76982835466807", -- divine
	"rbxassetid://96209352033929", -- supreme
}
local LEGENDARY_EGG = EGG_IMAGES[5]
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(EGG_IMAGES)
	end)
end)
local TIPS = {
	"3 WILDs in a row spin the egg wheel!",
	"Upgrades are forever - they stay after you rebirth.",
	"Rift Shards drop from enemies. Spend them on upgrades and gear!",
	"Better dice = rarer eggs.",
	"Finish all 5 daily quests 7 days in a row for a huge bonus.",
	"Got a code? Redeem it at the bottom of the Shop!",
	"Critical hits deal extra damage - upgrade Crit Chance!",
	"Tap an enemy to send your pets to attack it.",
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	return mk("UICorner", { CornerRadius = r or UDim.new(1, 0) }, o)
end
local function stroke(o, t, c)
	return mk("UIStroke", { Color = c or OUTLINE, Thickness = t or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local gui = mk("ScreenGui", { Name = "LoadingScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)

--------------------------------------------------------------------
-- background: deep purple -> blue, slowly turning, with faint studs
--------------------------------------------------------------------
local bg = mk("Frame", { Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 1 }, gui)
local bgGrad = mk("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 60, 230)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(55, 40, 150)), ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 90)) }), Rotation = 90 }, bg)
mk("ImageLabel", { Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = STUDS_IMAGE, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(64, 64), ImageTransparency = 0.86, ZIndex = 2 }, bg)
-- dark edges so the middle glows
local vignette = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 3 }, bg)
mk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.35) }) }, vignette)

-- light rays turning behind the logo
local rays = mk("Frame", { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(1400, 1400), BackgroundTransparency = 1, ZIndex = 4 }, bg)
mk("UIAspectRatioConstraint", {}, rays)
for i = 0, 11 do
	local ray = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.09, 0, 1, 0), Rotation = i * 15, BackgroundColor3 = Color3.fromRGB(255, 235, 170), BorderSizePixel = 0, ZIndex = 4 }, rays)
	mk("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.93), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(0.65, 0.93), NumberSequenceKeypoint.new(1, 1) }) }, ray)
end

-- floating rarity eggs (and a few dice) drifting up
local floaters = {}
local floatLayer = mk("Frame", { Name = "Floaters", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, bg)
local rng = Random.new()
local function spawnFloater(startAnywhere)
	local isDice = rng:NextNumber() < 0.2
	local size = rng:NextInteger(26, 64)
	local f
	if isDice then
		f = mk("ImageLabel", { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = DICE_IMAGE, ImageTransparency = 0.25, ZIndex = 5 }, floatLayer)
	else
		local image = EGG_IMAGES[rng:NextInteger(1, #EGG_IMAGES)]
		f = mk("ImageLabel", { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, ImageTransparency = 0.1, ZIndex = 5 }, floatLayer)
	end
	local item = {
		obj = f,
		x = rng:NextNumber(0.03, 0.97),
		y = startAnywhere and rng:NextNumber(0, 1.1) or 1.15,
		speed = rng:NextNumber(0.025, 0.06) * (70 / (size + 10)),
		sway = rng:NextNumber(0.005, 0.02),
		phase = rng:NextNumber(0, math.pi * 2),
		spin = rng:NextNumber(-30, 30),
	}
	table.insert(floaters, item)
end
for _ = 1, 22 do
	spawnFloater(true)
end

--------------------------------------------------------------------
-- middle: logo, progress bar, status, tip, skip
--------------------------------------------------------------------
local W, H = 640, 440
local center = mk("Frame", { Name = "Center", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 10 }, gui)
local scale = mk("UIScale", { Scale = 1 }, center)
local fitScale = 1
local function fit()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	fitScale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.4, 1.4)
	scale.Scale = fitScale
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

-- logo: spinning dice + MONSTER (white) / RNG (gold)
local logo = mk("Frame", { Name = "Logo", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(W, 230), BackgroundTransparency = 1, ZIndex = 10 }, center)
local logoScale = mk("UIScale", { Scale = 0 }, logo)
local dice = mk("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(110, 110), BackgroundTransparency = 1, Image = DICE_IMAGE, ScaleType = Enum.ScaleType.Fit, ZIndex = 12 }, logo)
local diceShadow = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(80, 12), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, ZIndex = 11 }, logo)
corner(diceShadow)
local word1 = mk("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(W, 70), BackgroundTransparency = 1, Text = "MONSTER", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 13 }, logo)
mk("UIStroke", { Color = OUTLINE, Thickness = 6 }, word1)
mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 215, 255)) }, word1)
local word2 = mk("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Size = UDim2.fromOffset(W, 62), BackgroundTransparency = 1, Text = "RNG", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 13 }, logo)
mk("UIStroke", { Color = OUTLINE, Thickness = 6 }, word2)
mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 150, 30)) }, word2)
-- a shine that sweeps over RNG
local sweep = mk("UIGradient", { Rotation = 20, Color = ColorSequence.new(WHITE), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }), Offset = Vector2.new(-1, 0) }, nil)
local rngShine = word2:Clone()
rngShine.Name = "Shine"
rngShine.TextColor3 = WHITE
rngShine.ZIndex = 14
for _, c in ipairs(rngShine:GetChildren()) do
	c:Destroy()
end
sweep.Parent = rngShine
rngShine.Parent = logo

-- progress bar: dark studded track, glossy green -> cyan fill, shine
-- running along it, an egg riding at the end
local barY = 262
local barBack = mk("Frame", { Name = "Bar", Position = UDim2.fromOffset(50, barY), Size = UDim2.new(1, -100, 0, 38), BackgroundColor3 = Color3.fromRGB(22, 20, 44), ZIndex = 10 }, center)
corner(barBack)
stroke(barBack, 4)
mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = STUDS_IMAGE, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(30, 30), ImageTransparency = 0.8, ZIndex = 10 }, barBack)
local fill = mk("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, ClipsDescendants = true, ZIndex = 11 }, barBack)
corner(fill)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(90, 235, 120), Color3.fromRGB(60, 210, 255)) }, fill)
local gloss = mk("Frame", { Size = UDim2.new(1, -12, 0.32, 0), Position = UDim2.fromOffset(6, 5), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, ZIndex = 12 }, fill)
corner(gloss)
local runner = mk("Frame", { Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Rotation = 20, BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, ZIndex = 12 }, fill)
mk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, runner)
local percent = mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "0%", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 15 }, barBack)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, percent)
mk("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 5) }, percent)
-- the egg that rides at the end of the fill
local rider = mk("ImageLabel", { Name = "Egg", Size = UDim2.fromOffset(46, 50), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 0, 0, -2), BackgroundTransparency = 1, Image = LEGENDARY_EGG, ScaleType = Enum.ScaleType.Fit, ZIndex = 16 }, barBack)

local status = mk("TextLabel", { Position = UDim2.fromOffset(0, barY + 48), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "Loading...", TextScaled = true, Font = FONT, TextColor3 = Color3.fromRGB(235, 230, 255), ZIndex = 10 }, center)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, status)

-- tip box
local tipBox = mk("Frame", { Name = "Tip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, barY + 88), Size = UDim2.new(1, -60, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 18, 44), BackgroundTransparency = 0.25, ZIndex = 10 }, center)
corner(tipBox, UDim.new(0, 12))
stroke(tipBox, 3, Color3.fromRGB(120, 100, 255)).Transparency = 0.2
local tipText = mk("TextLabel", { Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), BackgroundTransparency = 1, RichText = true, Text = "", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 222, 255), ZIndex = 11 }, tipBox)

-- SKIP: top-right corner (away from the tip), shrinks with the screen
local skip = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(130, 46), BackgroundColor3 = Color3.fromRGB(88, 96, 122), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20 }, gui)
corner(skip, UDim.new(0, 14))
stroke(skip, 4)
mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 196, 210)) }, skip)
mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = STUDS_IMAGE, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(28, 28), ImageTransparency = 0.6, ZIndex = 20 }, skip)
corner(skip:FindFirstChildOfClass("ImageLabel"), UDim.new(0, 14))
local skipLabel = mk("TextLabel", { Size = UDim2.new(1, -20, 0.55, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), BackgroundTransparency = 1, Text = "SKIP  \u{25B6}", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 21 }, skip)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, skipLabel)
local skipScale = mk("UIScale", {}, skip)

--------------------------------------------------------------------
-- animation (one Heartbeat loop for everything)
--------------------------------------------------------------------
local shown = 0 -- progress 0..1 (what the bar shows)
local target = 0
local alive = true
local t0 = os.clock()
local MIN_TIME = 7 -- seconds the loading screen shows at least
local finished = false
local conn
conn = RunService.Heartbeat:Connect(function(dt)
	if not alive then
		conn:Disconnect()
		return
	end
	local t = os.clock() - t0
	-- background
	bgGrad.Rotation = 90 + math.sin(t * 0.25) * 25
	rays.Rotation = t * 8
	-- floaters
	for i = #floaters, 1, -1 do
		local f = floaters[i]
		f.y -= f.speed * dt
		if f.y < -0.15 then
			f.obj:Destroy()
			table.remove(floaters, i)
			spawnFloater(false)
		else
			f.obj.Position = UDim2.fromScale(f.x + math.sin(t * 0.8 + f.phase) * f.sway, f.y)
			f.obj.Rotation = math.sin(t + f.phase) * f.spin
		end
	end
	-- logo: dice hops and wobbles, words breathe
	local hop = math.abs(math.sin(t * 3.2))
	dice.Position = UDim2.new(0.5, 0, 0, 58 - hop * 22)
	dice.Rotation = math.sin(t * 3.2) * 14
	diceShadow.Size = UDim2.fromOffset(80 - hop * 30, 12 - hop * 4)
	diceShadow.BackgroundTransparency = 0.6 + hop * 0.25
	word1.Rotation = math.sin(t * 1.6) * 2
	word2.Rotation = -math.sin(t * 1.6) * 2.5
	rngShine.Rotation = word2.Rotation
	local s = 1 + math.sin(t * 3.2) * 0.03
	word2.Size = UDim2.fromOffset(W * s, 62 * s)
	rngShine.Size = word2.Size
	-- shine sweep over RNG every 2.5 s
	local k = (t % 2.5) / 1.1
	sweep.Offset = Vector2.new(-1 + math.min(k, 1) * 2, 0)
	-- bar: eases toward the target, shine runs along it, egg bobs
	-- the bar never runs ahead of the minimum time, so it fills smoothly
	local goal = finished and target or math.min(target, t / MIN_TIME)
	shown += (goal - shown) * math.min(1, dt * 2.5)
	fill.Size = UDim2.fromScale(shown, 1)
	runner.Position = UDim2.fromScale((t * 0.9) % 1.4 - 0.2, 0.5)
	rider.Position = UDim2.new(math.clamp(shown, 0.03, 0.97), 0, 0, -2 - math.abs(math.sin(t * 6)) * 6)
	rider.Rotation = math.sin(t * 6) * 10
	percent.Text = math.floor(shown * 100 + 0.5) .. "%"
	-- SKIP pulses a little
	skipScale.Scale = math.min(1, fitScale) * (1 + math.sin(t * 4) * 0.03)
end)

-- logo pops in
TweenService:Create(logoScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

-- tips: a new one every 4 seconds, fading between
task.spawn(function()
	local i = rng:NextInteger(1, #TIPS)
	while alive do
		tipText.Text = '<font color="#FFD23C">TIP:</font> ' .. TIPS[i]
		TweenService:Create(tipText, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.wait(4)
		if not alive then
			break
		end
		TweenService:Create(tipText, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.3)
		i = i % #TIPS + 1
	end
end)

local function setProgress(p, text)
	target = math.max(target, math.clamp(p, 0, 1))
	if text then
		status.Text = text
	end
end

--------------------------------------------------------------------
-- closing: the logo zooms, everything fades, the screen slides away
--------------------------------------------------------------------
local function close()
	if finished then
		return
	end
	finished = true
	setProgress(1, "Ready!")
	status.TextColor3 = Color3.fromRGB(140, 255, 160)
	-- let the bar fill all the way and show "Ready!" for a moment
	task.wait(1.4)
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(logoScale, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 1.4 }):Play()
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		end
		if d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		end
		if d:IsA("GuiObject") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end
		if d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.wait(0.95)
	alive = false
	gui:Destroy()
end
skip.Activated:Connect(function()
	task.spawn(close)
end)
skip.MouseEnter:Connect(function()
	skip.BackgroundColor3 = Color3.fromRGB(110, 120, 150)
end)
skip.MouseLeave:Connect(function()
	skip.BackgroundColor3 = Color3.fromRGB(88, 96, 122)
end)
task.delay(3, function()
	if not finished then
		skip.Visible = true
	end
end)

--------------------------------------------------------------------
-- loading steps
--------------------------------------------------------------------
-- a step: wait for check() (max `limit` seconds)
local function step(p0, p1, text, limit, check)
	setProgress(p0, text)
	local start = os.clock()
	while not finished and not check() and os.clock() - start < limit do
		setProgress(p0 + (p1 - p0) * math.min(0.9, (os.clock() - start) / limit))
		task.wait(0.1)
	end
	setProgress(p1)
end

task.spawn(function()
	step(0.02, 0.15, "Loading the game...", 20, function()
		return game:IsLoaded()
	end)
	step(0.15, 0.35, "Loading the map...", 20, function()
		local world = workspace:FindFirstChild("MonsterRNGWorld")
		return world ~= nil and world:FindFirstChild("Hub") ~= nil and world:FindFirstChild("GroundTiles") ~= nil
	end)
	step(0.35, 0.5, "Loading your monsters and eggs...", 20, function()
		return player:FindFirstChild("leaderstats") ~= nil
	end)
	step(0.5, 0.62, "Building your pen...", 15, function()
		local world = workspace:FindFirstChild("MonsterRNGWorld")
		return player.Character ~= nil and world ~= nil and world:FindFirstChild("Base_" .. player.UserId) ~= nil
	end)
	step(0.62, 0.78, "Waking up the monsters...", 20, function()
		return player:GetAttribute("MeshesReady") == true
	end)
	-- pictures in the menus
	if not finished then
		setProgress(0.78, "Loading pictures...")
		local assets = {}
		for _, d in ipairs(playerGui:GetDescendants()) do
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and not d:IsDescendantOf(gui) then
				table.insert(assets, d)
			end
		end
		local total, done = math.max(1, #assets), 0
		local preloading = true
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(assets, function()
					done += 1
					setProgress(0.78 + 0.2 * (done / total))
				end)
			end)
			preloading = false
		end)
		local start = os.clock()
		while preloading and not finished and os.clock() - start < 20 do
			task.wait(0.1)
		end
	end
	-- stay at least MIN_TIME so the screen can be seen (SKIP still works)
	while not finished and os.clock() - t0 < MIN_TIME do
		task.wait(0.1)
	end
	close()
end)
