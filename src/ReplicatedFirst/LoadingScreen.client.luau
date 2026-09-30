local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- Loading screen: shows the moment a player joins and stays until the
-- map, their pen, their data, the monsters and the pictures are loaded.
-- A SKIP button shows after a few seconds.
--------------------------------------------------------------------
ReplicatedFirst:RemoveDefaultLoadingScreen()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OUTLINE = Color3.fromRGB(12, 14, 32)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local GOLD = Color3.fromRGB(255, 205, 60)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local gui = mk("ScreenGui", { Name = "LoadingScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local bg = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 20, 90) }, gui)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 60, 220), Color3.fromRGB(20, 12, 50)), Rotation = 90 }, bg)
local center = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 360), BackgroundTransparency = 1 }, bg)
local scale = mk("UIScale", { Scale = 1 }, center)
local function fit()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min((vp.X - 30) / 560, (vp.Y - 30) / 360), 0.45, 1.3)
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

local dice = mk("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(110, 110), BackgroundTransparency = 1, Image = "rbxassetid://88531005888419", ScaleType = Enum.ScaleType.Fit }, center)
local title = mk("TextLabel", { Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Text = "MONSTER RNG", TextScaled = true, Font = FONT, TextColor3 = GOLD, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, center)
mk("UIStroke", { Color = OUTLINE, Thickness = 4 }, title)
local barBack = mk("Frame", { Position = UDim2.fromOffset(40, 210), Size = UDim2.new(1, -80, 0, 30), BackgroundColor3 = Color3.fromRGB(20, 16, 40) }, center)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, barBack)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, barBack)
local barFill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 120) }, barBack)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, barFill)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(140, 255, 160), Color3.fromRGB(40, 170, 90)), Rotation = 90 }, barFill)
local percent = mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "0%", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 3 }, barBack)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, percent)
local status = mk("TextLabel", { Position = UDim2.fromOffset(0, 248), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "Loading...", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 210, 255) }, center)
local skip = mk("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 292), Size = UDim2.fromOffset(170, 50), BackgroundColor3 = Color3.fromRGB(110, 118, 140), Text = "SKIP", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, Visible = false }, center)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, skip)
mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skip)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, skip)

-- spinning / bouncing dice
local alive = true
task.spawn(function()
	local t0 = os.clock()
	while alive do
		local t = os.clock() - t0
		dice.Rotation = math.sin(t * 3) * 12
		dice.Position = UDim2.new(0.5, 0, 0, -math.abs(math.sin(t * 4)) * 14)
		task.wait()
	end
end)

local shown = 0
local function setProgress(p, text)
	shown = math.max(shown, math.clamp(p, 0, 1))
	TweenService:Create(barFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(shown, 1) }):Play()
	percent.Text = math.floor(shown * 100 + 0.5) .. "%"
	if text then
		status.Text = text
	end
end

local finished = false
local function close()
	if finished then
		return
	end
	finished = true
	setProgress(1, "Ready!")
	task.wait(0.2)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		if d:IsA("ImageLabel") then
			TweenService:Create(d, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
		end
		if d:IsA("Frame") or d:IsA("TextButton") then
			TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		if d:IsA("UIStroke") then
			TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
	task.wait(0.45)
	alive = false
	gui:Destroy()
end
skip.Activated:Connect(function()
	task.spawn(close)
end)
task.delay(3, function()
	if not finished then
		skip.Visible = true
	end
end)

-- a step: wait for check() (max `limit` seconds)
local function step(p0, p1, text, limit, check)
	setProgress(p0, text)
	local t0 = os.clock()
	while not finished and not check() and os.clock() - t0 < limit do
		setProgress(p0 + (p1 - p0) * math.min(0.9, (os.clock() - t0) / limit))
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
	step(0.62, 0.78, "Getting the monsters ready...", 20, function()
		return player:GetAttribute("MeshesReady") == true
	end)
	-- pictures in the menus
	if not finished then
		setProgress(0.78, "Loading pictures...")
		local assets = {}
		for _, d in ipairs(playerGui:GetDescendants()) do
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
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
		local t0 = os.clock()
		while preloading and not finished and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
	end
	close()
end)
