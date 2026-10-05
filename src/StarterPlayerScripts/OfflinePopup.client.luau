--------------------------------------------------------------------
-- "Welcome back!" popup: shows the cash your pen earned while you
-- were offline (the server already added it).
--------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local remote = folder:WaitForChild("Remotes"):WaitForChild("OfflineEarnings")

local FONT = Enum.Font.FredokaOne
local NAVY, GOLD, GREEN = Color3.fromRGB(30, 34, 70), Color3.fromRGB(255, 205, 60), Color3.fromRGB(70, 200, 100)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r, stroke)
	mk("UICorner", { CornerRadius = UDim.new(0, r) }, o)
	if stroke then
		mk("UIStroke", { Thickness = stroke, Color = Color3.fromRGB(10, 10, 25), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
end
local cashRain -- (below)
local function hm(sec)
	sec = math.floor(sec)
	local h, m = sec // 3600, (sec % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

--------------------------------------------------------------------
-- COLLECT: cash bills burst out of the window, then fly one by one into
-- your cash counter (top left) - ching! ching! ching! - and it pops
--------------------------------------------------------------------
local Debris = game:GetService("Debris")
local function ching(i)
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.coin
	s.Volume = Config.Sounds.coinVolume or 0.4
	s.PlaybackSpeed = 1.5 + math.min(i, 20) * 0.03 -- a bit higher every bill
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 2)
end
-- where the cash counter is (in this gui's coordinates)
local function cashTarget(fallback)
	local hud = player.PlayerGui:FindFirstChild("HUD")
	local cash = hud and hud:FindFirstChild("Left") and hud.Left:FindFirstChild("Cash")
	if not cash or not cash.Visible then
		return fallback, nil
	end
	local inset = hud.IgnoreGuiInset and 0 or game:GetService("GuiService"):GetGuiInset().Y
	local icon = cash:FindFirstChildWhichIsA("ImageLabel")
	local at = icon or cash
	return at.AbsolutePosition + at.AbsoluteSize / 2 + Vector2.new(0, inset), cash
end
cashRain = function(center, amount)
	local gui = mk("ScreenGui", { Name = "CashRain", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 70 }, player:WaitForChild("PlayerGui"))
	local vp = workspace.CurrentCamera.ViewportSize
	local k = math.min(vp.Y / 720, 1) -- same size on every screen
	local target, cashFrame = cashTarget(Vector2.new(80 * k, vp.Y * 0.45))
	local rng = Random.new()
	local count = 18
	local bills = {}
	for i = 1, count do
		local size = math.floor(rng:NextNumber(48, 64) * k)
		local b = mk("ImageLabel", {
			Size = UDim2.fromOffset(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			BackgroundTransparency = 1,
			Image = Config.CashImage,
			Rotation = rng:NextNumber(-40, 40),
			ZIndex = 5,
		}, gui)
		local sc = mk("UIScale", { Scale = 0.2 }, b)
		-- burst out around the window
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(70, 200) * k
		local spot = center + Vector2.new(math.cos(ang) * r, math.sin(ang) * r * 0.75)
		task.delay((i - 1) * 0.015, function()
			TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(spot.X, spot.Y), Rotation = rng:NextNumber(-25, 25) }):Play()
			TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
		bills[i] = { b = b, sc = sc }
	end
	-- the counter bumps every time a bill lands
	local bump
	if cashFrame then
		bump = cashFrame:FindFirstChild("RainBump") or mk("UIScale", { Name = "RainBump" }, cashFrame)
	end
	task.wait(0.55)
	for i, bill in ipairs(bills) do
		task.delay((i - 1) * 0.07, function()
			local t = TweenService:Create(bill.b, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(target.X, target.Y), Rotation = 0 })
			TweenService:Create(bill.sc, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.45 }):Play()
			t.Completed:Connect(function()
				bill.b:Destroy()
				ching(i)
				if bump then
					bump.Scale = 1.18
					TweenService:Create(bump, TweenInfo.new(0.15), { Scale = 1 }):Play()
				end
			end)
			t:Play()
		end)
	end
	-- "+$1.2M" rises from the counter at the end
	task.wait((count - 1) * 0.07 + 0.5)
	local plus = mk("TextLabel", {
		Size = UDim2.fromOffset(260 * k, 40 * k),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(target.X + 30 * k, target.Y),
		BackgroundTransparency = 1,
		Text = "+$" .. Config.FormatNumber(amount or 0),
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(130, 255, 140),
		ZIndex = 6,
	}, gui)
	local plusStroke = mk("UIStroke", { Thickness = 3, Color = Color3.fromRGB(10, 40, 15) }, plus)
	TweenService:Create(plusStroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	TweenService:Create(plus, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target.X + 30 * k, target.Y - 50 * k), TextTransparency = 1 }):Play()
	Debris:AddItem(gui, 1.4)
end

remote.OnClientEvent:Connect(function(data)
	local gui = mk("ScreenGui", { Name = "OfflinePopupGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	local dim = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45 }, gui)
	local panel = mk("Frame", { Size = UDim2.fromOffset(420, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = NAVY }, dim)
	round(panel, 20, 4)
	-- fits any screen (phones too)
	local scale = mk("UIScale", {}, panel)
	-- fits any screen (phones too): uses the panel's real size (the studded
	-- header makes it taller) and keeps clear of Roblox's top bar
	local fitScale = 1
	local function fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local inset = game:GetService("GuiService"):GetGuiInset().Y
		local w, h = panel.Size.X.Offset, panel.Size.Y.Offset
		fitScale = math.min((vp.X - 40) / w, (vp.Y - inset * 2 - 30) / h, 1)
		scale.Scale = fitScale
	end
	fit()
	panel:GetPropertyChangedSignal("Size"):Connect(fit)
	local conn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	mk("TextLabel", { Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 14), BackgroundTransparency = 1, Text = "WELCOME BACK!", Font = FONT, TextScaled = true, TextColor3 = GOLD }, panel)
	mk("TextLabel", { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 62), BackgroundTransparency = 1, Text = "Your monsters kept working while you were away:", Font = FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(220, 225, 255) }, panel)
	local amount = mk("TextLabel", { Size = UDim2.new(1, -40, 0, 64), Position = UDim2.fromOffset(20, 128), BackgroundTransparency = 1, Text = "+$0", Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(130, 255, 140) }, panel)
	mk("UIStroke", { Thickness = 3, Color = Color3.fromRGB(10, 40, 15) }, amount)
	local capped = data.away > data.seconds
	if capped then
		mk("TextLabel", { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 202), BackgroundTransparency = 1, Text = "Upgrade OFFLINE TIME in the Upgrade tree to earn for longer!", Font = FONT, TextScaled = true, TextColor3 = GOLD }, panel)
	end
	local ok = mk("TextButton", { Size = UDim2.fromOffset(180, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 232), BackgroundColor3 = GREEN, Text = "COLLECT", Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true }, panel)
	round(ok, 14, 3)
	-- the studded window look (header bar with "WELCOME BACK!")
	local styleMod = folder:FindFirstChild("UIStyle")
	if styleMod then
		pcall(function()
			require(styleMod).skinWindow(panel, nil)
		end)
	end
	mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, ok)

	-- count up
	task.spawn(function()
		local t0 = os.clock()
		while amount.Parent do
			local k = math.clamp((os.clock() - t0) / 1.2, 0, 1)
			amount.Text = "+$" .. Config.FormatNumber(math.floor(data.cash * (1 - (1 - k) ^ 3)))
			if k >= 1 then
				break
			end
			task.wait()
		end
	end)
	fit() -- again: the studded header made the panel taller
	scale.Scale = fitScale * 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fitScale }):Play()
	local collected = false
	ok.Activated:Connect(function()
		if collected then
			return
		end
		collected = true
		conn:Disconnect()
		-- the window pops away, then the cash bursts out and flies to you
		local center = panel.AbsolutePosition + panel.AbsoluteSize / 2
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.15, cashRain, center, data.cash)
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end)
end)
