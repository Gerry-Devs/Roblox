local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local gearShopRemote = remotes:WaitForChild("GearShop")
local buyGearRemote = remotes:WaitForChild("BuyGear")
local gearRestockRemote = remotes:WaitForChild("GearRestock")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local notify = bridge:WaitForChild("Notify")
local closeAllBridge = bridge:WaitForChild("CloseAll")

--------------------------------------------------------------------
-- Gear Shop (Kurt). Your own stock, restocked every 5 minutes: each
-- gear is rolled with its chance, 1 of each that hits. Paid with Rift
-- Shards; bought gears go to the backpack (ITEMS). Gears: Config.Gears.
--------------------------------------------------------------------

local gui = script.Parent
local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 93)
local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(60, 205, 95)
local GRAY = Color3.fromRGB(110, 120, 145)
local NAVY = Color3.fromRGB(22, 42, 92)
local FONT = Enum.Font.LuckiestGuy
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local profile = profileRemote:InvokeServer()
local shop -- { items = { key = count }, restockAt = unix time }

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(p, r)
	mk("UICorner", { CornerRadius = r or UDim.new(0, 14) }, p)
end
local function stroke(p, t)
	mk("UIStroke", { Color = OUTLINE, Thickness = t or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end
local function label(parent, text, size, pos, props)
	local l = mk("TextLabel", {
		Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Text = text, TextScaled = true,
		Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE,
	}, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------

local W, H = 600, 470
local main = mk("Frame", {
	Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(60, 160, 255), Visible = false,
}, gui)
corner(main, UDim.new(0, 22))
stroke(main, 6)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 120, 235)), Rotation = 90 }, main)
local mainScale = mk("UIScale", {}, main)

-- title ribbon
local title = mk("Frame", { Name = "Title", Size = UDim2.fromOffset(300, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(80, 200, 110), ZIndex = 5 }, main)
corner(title, UDim.new(0, 18))
stroke(title, 5)
mk("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 215, 195)), Rotation = 90 }, title)
label(title, "GEAR SHOP", UDim2.new(1, -30, 0.64, 0), UDim2.new(0, 15, 0.18, 0), { ZIndex = 6 })
local closeBtn = mk("TextButton", {
	Size = UDim2.fromOffset(54, 54), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), BackgroundColor3 = Color3.fromRGB(235, 50, 60),
	Text = "X", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 6,
}, main)
corner(closeBtn, UDim.new(0, 12))
stroke(closeBtn, 3)

-- header: your shards + restock timer
local header = mk("Frame", { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 44), BackgroundTransparency = 1 }, main)
mk("ImageLabel", { Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Image = Config.RiftShardImage, ScaleType = Enum.ScaleType.Fit }, header)
local shardText = label(header, "0", UDim2.fromOffset(160, 28), UDim2.fromOffset(38, 2), { TextXAlignment = Enum.TextXAlignment.Left })
local timerText = label(header, "", UDim2.fromOffset(280, 26), UDim2.new(1, -280, 0, 4), { TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 235, 150) })

local well = mk("Frame", { Size = UDim2.new(1, -40, 1, -100), Position = UDim2.fromOffset(20, 84), BackgroundColor3 = NAVY }, main)
corner(well, UDim.new(0, 16))
stroke(well, 4)
local list = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, well)
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }, list)

--------------------------------------------------------------------
-- rows
--------------------------------------------------------------------

local busy = false
local render

local function buy(gear)
	if busy then
		return
	end
	busy = true
	local ok, r = pcall(function()
		return buyGearRemote:InvokeServer(gear.key)
	end)
	busy = false
	if ok and r then
		shop = r.shop or shop
		profile = r.profile or profile
		notify:Fire(r.message or "", r.success and GOLD or RED)
	end
	render()
end

render = function()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	shardText.Text = Config.FormatNumber((profile and profile.riftShards) or 0)
	for i, gear in ipairs(Config.Gears) do
		local color = Color3.fromRGB(gear.color[1], gear.color[2], gear.color[3])
		local inStock = shop and shop.items and (shop.items[gear.key] or 0) > 0
		local canAfford = ((profile and profile.riftShards) or 0) >= gear.price
		local row = mk("Frame", { Name = gear.key, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(35, 62, 125) }, list)
		corner(row, UDim.new(0, 12))
		stroke(row, 2)
		-- icon in a colored circle (letter until you add an image)
		local circle = mk("Frame", { Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = color }, row)
		corner(circle, UDim.new(1, 0))
		stroke(circle, 3)
		if gear.imageId and gear.imageId ~= "" then
			mk("ImageLabel", { Size = UDim2.fromScale(0.86, 0.86), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Image = gear.imageId, ScaleType = Enum.ScaleType.Fit }, circle)
		else
			label(circle, string.sub(gear.name, 1, 1), UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.15))
		end
		label(row, gear.name, UDim2.new(1, -260, 0, 26), UDim2.fromOffset(76, 8), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
		label(row, gear.text, UDim2.new(1, -260, 0, 18), UDim2.fromOffset(76, 36), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(210, 225, 245) })
		-- stock
		local stockText, stockColor
		if inStock then
			stockText, stockColor = "IN STOCK x" .. shop.items[gear.key], Color3.fromRGB(140, 255, 150)
		else
			stockText, stockColor = "NOT IN STOCK", Color3.fromRGB(170, 180, 200)
		end
		label(row, stockText, UDim2.fromOffset(170, 18), UDim2.new(1, -176, 0, 8), { TextColor3 = stockColor })
		-- buy button with shard price
		local btn = mk("TextButton", {
			Size = UDim2.fromOffset(150, 38), Position = UDim2.new(1, -160, 0, 30), BackgroundColor3 = (inStock and canAfford) and GREEN or GRAY,
			Text = "", AutoButtonColor = inStock,
		}, row)
		corner(btn, UDim.new(0, 10))
		stroke(btn, 3)
		mk("ImageLabel", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 10, 0.5, -13), BackgroundTransparency = 1, Image = Config.RiftShardImage, ScaleType = Enum.ScaleType.Fit }, btn)
		label(btn, inStock and ("BUY " .. gear.price) or tostring(gear.price), UDim2.new(1, -46, 0.7, 0), UDim2.new(0, 40, 0.15, 0))
		btn.Activated:Connect(function()
			if not inStock then
				notify:Fire(gear.name .. " isn't in stock. Wait for the next restock!", RED)
				return
			end
			buy(gear)
		end)
	end
end

--------------------------------------------------------------------
-- open / close
--------------------------------------------------------------------

local function stallRoot()
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	local hub = world and world:FindFirstChild("Hub")
	local stall = hub and hub:FindFirstChild("GearStall")
	return stall and (stall.PrimaryPart or stall:FindFirstChild("Counter"))
end

local function fit()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	mainScale.Scale = math.min(1, (v.Y - 100) / H, (v.X - 30) / W) * (isTouch and 0.88 or 1)
end

local function open()
	closeAllBridge:Fire("gear")
	fit()
	local ok, state = pcall(function()
		return gearShopRemote:InvokeServer()
	end)
	if ok and state then
		shop = state
	end
	render()
	main.Visible = true
	mainScale.Scale *= 0.85
	TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = mainScale.Scale / 0.85 }):Play()
end

local function close()
	main.Visible = false
end

closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "gear" then
		close()
	end
end)

-- Kurt's prompt opens the shop (the stall may stream in later)
local hooked = {}
local function hookPrompt(prompt)
	if hooked[prompt] or not prompt:IsA("ProximityPrompt") or prompt.Name ~= "GearPrompt" then
		return
	end
	hooked[prompt] = true
	prompt.Triggered:Connect(open)
end
task.spawn(function()
	local world = workspace:WaitForChild("MonsterRNGWorld")
	local hub = world:WaitForChild("Hub")
	local stall = hub:WaitForChild("GearStall")
	for _, d in ipairs(stall:GetDescendants()) do
		hookPrompt(d)
	end
	stall.DescendantAdded:Connect(hookPrompt)
end)

-- restock timer + close when you walk away
task.spawn(function()
	while true do
		if main.Visible then
			if shop and shop.restockAt then
				local left = math.max(0, math.ceil(shop.restockAt - workspace:GetServerTimeNow()))
				timerText.Text = string.format("RESTOCK IN %d:%02d", left // 60, left % 60)
			end
			local root = stallRoot()
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if root and hrp and (root.Position - hrp.Position).Magnitude > 22 then
				close()
			end
		end
		task.wait(0.5)
	end
end)

--------------------------------------------------------------------
-- live data + restock notification
--------------------------------------------------------------------

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	if main.Visible then
		render()
	end
end)

gearRestockRemote.OnClientEvent:Connect(function(data)
	shop = data.shop or shop
	notify:Fire("Gear Shop has been restocked!", Color3.fromRGB(140, 255, 150))
	if main.Visible then
		render()
	end
end)
