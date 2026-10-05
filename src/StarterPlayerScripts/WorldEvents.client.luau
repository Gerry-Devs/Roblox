local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

--------------------------------------------------------------------
-- Day / night + weather (Config.WorldEventAt, the real clock): a banner
-- at the top with what's on and how long it lasts, a message when it
-- starts, and the look of each one (only on this screen):
--   Night:       dark blue night sky (eggs grow 1.5x faster)
--   Starfall:    evening sky full of shooting stars
--   Golden Hour: golden sunset light, gold sparkles falling
--   Giant Storm: dark sky, heavy rain, lightning flashes
--   Lucky Wind:  green sparkles blowing past
--   Rainbow Sky: a big rainbow over the town
--------------------------------------------------------------------
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local notify = folder:WaitForChild("ClientBridge"):WaitForChild("Notify")

local OUTLINE = Color3.fromRGB(10, 12, 22)
local DAY_TIME = 13

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "WorldEventFX"
cc.Parent = Lighting

local fxFolder = Instance.new("Folder")
fxFolder.Name = "WorldEventFx"
fxFolder.Parent = workspace

local function particlesOn()
	local ok, tier = pcall(Config.GraphicsTier, player:GetAttribute("Graphics"))
	return not ok or not tier or (tier.particles or 1) > 0
end
local function C(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

--------------------------------------------------------------------
-- banner (top middle, under Roblox's top bar)
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "WorldEventsGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")
local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.Size = UDim2.fromOffset(420, 80)
holder.BackgroundTransparency = 1
holder.Parent = gui
local holderScale = Instance.new("UIScale")
holderScale.Parent = holder
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = holder
local function fit()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	holderScale.Scale = math.min(v.Y / 720, v.X / 1100, 1)
	holder.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 6)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local function makePill(order)
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(400, 34)
	pill.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	pill.BackgroundTransparency = 0.15
	pill.Visible = false
	pill.Parent = holder
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = OUTLINE
	st.Parent = pill
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -24, 0.7, 0)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = OUTLINE
	l.Parent = pill
	return pill, l
end
local nightPill, nightText = makePill(1)
local weatherPill, weatherText = makePill(2)
nightText.TextColor3 = Color3.fromRGB(170, 195, 255)

local function mmss(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

--------------------------------------------------------------------
-- looks
--------------------------------------------------------------------
local function tweenLook(clock, tint, brightness, saturation, time)
	local info = TweenInfo.new(time or 3, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { ClockTime = clock }):Play()
	TweenService:Create(cc, info, { TintColor = tint, Brightness = brightness, Saturation = saturation }):Play()
end

-- a big invisible box above the camera that sheds particles (rain, sparkles)
local function skyEmitter(props, size, height)
	local box = Instance.new("Part")
	box.Name = "SkyEmitter"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = size
	box.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = box
	local conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			box.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, height, 0))
		end
	end)
	return function()
		conn:Disconnect()
		box:Destroy()
	end
end

-- one shooting star across the sky
local function shootingStar()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(flat.Z, 0, -flat.X)
	local rng = Random.new()
	local start = cam.CFrame.Position + flat * rng:NextNumber(250, 450) + side * rng:NextNumber(-300, 300) + Vector3.new(0, rng:NextNumber(140, 240), 0)
	local dir = (side * (rng:NextNumber() < 0.5 and -1 or 1) + Vector3.new(0, -0.45, 0)).Unit
	local star = Instance.new("Part")
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.new(2.4, 2.4, 2.4)
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromRGB(240, 235, 255)
	star.CFrame = CFrame.new(start)
	star.Parent = fxFolder
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = star
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = star
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 120, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = star
	local dist = rng:NextNumber(180, 300)
	local t = TweenService:Create(star, TweenInfo.new(rng:NextNumber(0.9, 1.4), Enum.EasingStyle.Linear), { CFrame = CFrame.new(start + dir * dist) })
	t.Completed:Connect(function()
		star:Destroy()
	end)
	t:Play()
end

-- a big rainbow arc over the town
local function buildRainbow()
	local model = Instance.new("Model")
	model.Name = "RainbowArc"
	local colors = {
		Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 230, 70), Color3.fromRGB(90, 220, 100),
		Color3.fromRGB(70, 170, 255), Color3.fromRGB(110, 100, 255), Color3.fromRGB(190, 100, 255),
	}
	local center = Vector3.new(0, -40, 520)
	for b, col in ipairs(colors) do
		local r = 420 - (b - 1) * 9
		local segs = 40
		for i = 0, segs - 1 do
			local a1, a2 = math.pi * i / segs, math.pi * (i + 1) / segs
			local p1 = center + Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local p2 = center + Vector3.new(math.cos(a2) * r, math.sin(a2) * r, 0)
			local seg = Instance.new("Part")
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CastShadow = false
			seg.Material = Enum.Material.Neon
			seg.Color = col
			seg.Transparency = 0.35
			seg.Size = Vector3.new(9, 2, (p2 - p1).Magnitude + 1)
			seg.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
			seg.Parent = model
		end
	end
	model.Parent = fxFolder
	return function()
		model:Destroy()
	end
end

local stops = {} -- things to clean up when the weather ends
local function stopWeatherFx()
	for _, f in ipairs(stops) do
		pcall(f)
	end
	table.clear(stops)
end

local loopToken
local function startWeatherFx(key)
	stopWeatherFx()
	local token = {}
	loopToken = token
	local fx = particlesOn()
	if key == "starfall" then
		tweenLook(20.5, Color3.fromRGB(225, 210, 255), -0.02, 0.05)
		if fx then
			task.spawn(function()
				while loopToken == token do
					shootingStar()
					task.wait(Random.new():NextNumber(0.25, 0.7))
				end
			end)
		end
	elseif key == "golden" then
		tweenLook(17.6, Color3.fromRGB(255, 226, 170), 0.02, 0.12)
		if fx then
			table.insert(stops, skyEmitter({
				Color = ColorSequence.new(Color3.fromRGB(255, 220, 90)),
				LightEmission = 0.8,
				Rate = 40,
				Lifetime = NumberRange.new(4, 6),
				Speed = NumberRange.new(4, 8),
				EmissionDirection = Enum.NormalId.Bottom,
				Size = NumberSequence.new(0.5),
				RotSpeed = NumberRange.new(-90, 90),
			}, Vector3.new(140, 1, 140), 35))
		end
	elseif key == "storm" then
		tweenLook(DAY_TIME, Color3.fromRGB(185, 195, 215), -0.12, -0.3)
		if fx then
			table.insert(stops, skyEmitter({
				Color = ColorSequence.new(Color3.fromRGB(190, 215, 255)),
				Transparency = NumberSequence.new(0.35),
				Rate = 450,
				Lifetime = NumberRange.new(0.8, 1),
				Speed = NumberRange.new(70, 90),
				EmissionDirection = Enum.NormalId.Bottom,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Size = NumberSequence.new(0.18),
				Squash = NumberSequence.new(3),
			}, Vector3.new(120, 1, 120), 45))
		end
		-- lightning flashes
		task.spawn(function()
			while loopToken == token do
				task.wait(Random.new():NextNumber(4, 9))
				if loopToken ~= token then
					break
				end
				for _ = 1, 2 do
					cc.Brightness = 0.45
					task.wait(0.07)
					cc.Brightness = -0.12
					task.wait(0.09)
				end
			end
		end)
	elseif key == "lucky" then
		tweenLook(DAY_TIME, Color3.fromRGB(230, 255, 232), 0.02, 0.12)
		if fx then
			table.insert(stops, skyEmitter({
				Color = ColorSequence.new(Color3.fromRGB(110, 230, 120), Color3.fromRGB(190, 255, 150)),
				LightEmission = 0.5,
				Rate = 35,
				Lifetime = NumberRange.new(3, 5),
				Speed = NumberRange.new(14, 22),
				EmissionDirection = Enum.NormalId.Right,
				SpreadAngle = Vector2.new(20, 20),
				Acceleration = Vector3.new(0, -2, 0),
				Size = NumberSequence.new(0.7),
				RotSpeed = NumberRange.new(-180, 180),
			}, Vector3.new(120, 30, 120), 8))
		end
	elseif key == "rainbow" then
		tweenLook(DAY_TIME, Color3.fromRGB(255, 245, 252), 0.02, 0.15)
		table.insert(stops, buildRainbow())
	end
end

--------------------------------------------------------------------
-- watch the clock
--------------------------------------------------------------------
local wasNight, weatherKey = nil, nil
while true do
	local now = workspace:GetServerTimeNow()
	local ev = Config.WorldEventAt(now)
	-- night
	if ev.night ~= wasNight then
		if ev.night then
			if wasNight ~= nil then
				notify:Fire("\u{1F319} NIGHT has fallen! Eggs grow 1.5x faster for 3 minutes.", Color3.fromRGB(170, 195, 255))
			end
			if not ev.weather then
				tweenLook(0.5, Color3.fromRGB(190, 205, 255), -0.04, -0.05, 4)
			end
		elseif not ev.weather then
			tweenLook(DAY_TIME, Color3.new(1, 1, 1), 0, 0, 4)
		end
		wasNight = ev.night
	end
	-- (hidden while the Upgrades screen is open: it uses the top middle)
	local up = player.PlayerGui:FindFirstChild("UpgradeTree")
	local dim = up and up:FindFirstChild("Dim")
	holder.Visible = not (dim and dim.Visible)
	nightPill.Visible = ev.night
	if ev.night then
		nightText.Text = "\u{1F319} NIGHT  \u{2022}  EGGS GROW 1.5X FASTER  \u{2022}  " .. mmss(ev.nightEnds - now)
	end
	-- weather
	local key = ev.weather and ev.weather.key or nil
	if key ~= weatherKey then
		if key then
			notify:Fire(ev.weather.name .. " has begun! " .. ev.weather.text .. " for 5 minutes!", C(ev.weather.color))
			startWeatherFx(key)
		else
			loopToken = nil
			stopWeatherFx()
			if ev.night then
				tweenLook(0.5, Color3.fromRGB(190, 205, 255), -0.04, -0.05, 4)
			else
				tweenLook(DAY_TIME, Color3.new(1, 1, 1), 0, 0, 4)
			end
		end
		weatherKey = key
	end
	weatherPill.Visible = key ~= nil
	if key then
		weatherText.Text = ev.weather.name .. "  \u{2022}  " .. ev.weather.text:upper() .. "  \u{2022}  " .. mmss(ev.weatherEnds - now)
		weatherText.TextColor3 = C(ev.weather.color)
	end
	task.wait(0.5)
end
