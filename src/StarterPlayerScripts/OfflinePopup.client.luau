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
local function hm(sec)
	sec = math.floor(sec)
	local h, m = sec // 3600, (sec % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", math.max(1, m))
end

remote.OnClientEvent:Connect(function(data)
	local gui = mk("ScreenGui", { Name = "OfflinePopupGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	local dim = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45 }, gui)
	local panel = mk("Frame", { Size = UDim2.fromOffset(420, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = NAVY }, dim)
	round(panel, 20, 4)
	-- fits any screen (phones too)
	local scale = mk("UIScale", {}, panel)
	local function fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min((vp.X - 24) / 420, (vp.Y - 24) / 300), 0.5, 1.4)
	end
	fit()
	local conn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	mk("TextLabel", { Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 14), BackgroundTransparency = 1, Text = "WELCOME BACK!", Font = FONT, TextScaled = true, TextColor3 = GOLD }, panel)
	mk("TextLabel", { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 62), BackgroundTransparency = 1, Text = "Your monsters kept working while you were away:", Font = FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(220, 225, 255) }, panel)
	local amount = mk("TextLabel", { Size = UDim2.new(1, -40, 0, 64), Position = UDim2.fromOffset(20, 106), BackgroundTransparency = 1, Text = "+$0", Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(130, 255, 140) }, panel)
	mk("UIStroke", { Thickness = 3, Color = Color3.fromRGB(10, 40, 15) }, amount)
	local capped = data.away > data.seconds
	local info = string.format("Away %s  •  earned for %s (max %dh)  •  %d%% speed", hm(data.away), hm(data.seconds), data.maxHours, math.floor(data.rate * 100 + 0.5))
	mk("TextLabel", { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 174), BackgroundTransparency = 1, Text = info, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(170, 180, 220) }, panel)
	if capped then
		mk("TextLabel", { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 198), BackgroundTransparency = 1, Text = "Upgrade OFFLINE TIME in the Upgrade tree to earn for longer!", Font = FONT, TextScaled = true, TextColor3 = GOLD }, panel)
	end
	local ok = mk("TextButton", { Size = UDim2.fromOffset(180, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 232), BackgroundColor3 = GREEN, Text = "COLLECT", Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true }, panel)
	round(ok, 14, 3)
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
	scale.Scale *= 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = scale.Scale / 0.6 }):Play()
	ok.Activated:Connect(function()
		conn:Disconnect()
		gui:Destroy()
	end)
end)
