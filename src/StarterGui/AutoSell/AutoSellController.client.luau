local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- Auto Sell settings window (gamepass). Opened from the AUTO SELL
-- button in the backpack. Every change saves right away.
--------------------------------------------------------------------

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local infoRemote = remotes:WaitForChild("AutoSellInfo")
local saveRemote = remotes:WaitForChild("AutoSellSave")
local soldRemote = remotes:WaitForChild("AutoSold")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local notify = bridge:WaitForChild("Notify")
local closeAllBridge = bridge:WaitForChild("CloseAll")

local gui = script.Parent
local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local GREEN, RED, GRAY, BLUE = Color3.fromRGB(60, 205, 95), Color3.fromRGB(235, 70, 80), Color3.fromRGB(96, 104, 128), Color3.fromRGB(40, 150, 255)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function styled(o, radius, stroke)
	mk("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, o)
	mk("UIStroke", { Color = OUTLINE, Thickness = stroke or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	return o
end
local function label(parent, text, size, pos, props)
	local l = mk("TextLabel", { Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
local function button(parent, text, size, pos, color)
	local b = mk("TextButton", { Size = size, Position = pos, BackgroundColor3 = color, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, AutoButtonColor = true }, parent)
	styled(b, 10, 3)
	mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local W, H = 560, 470
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(40, 120, 235), Visible = false }, gui)
styled(main, 22, 6)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 110, 225)), Rotation = 90 }, main)
local mainScale = mk("UIScale", {}, main)
local title = mk("Frame", { Size = UDim2.fromOffset(300, 58), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(60, 205, 95), ZIndex = 5 }, main)
styled(title, 18, 5)
label(title, "AUTO SELL", UDim2.new(1, -30, 0.64, 0), UDim2.new(0, 15, 0.18, 0), { ZIndex = 6 })
local closeBtn = button(main, "X", UDim2.fromOffset(54, 54), UDim2.new(1, -6, 0, 6), RED)
closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
closeBtn.ZIndex = 10

local body = mk("Frame", { Size = UDim2.new(1, -40, 1, -70), Position = UDim2.fromOffset(20, 50), BackgroundColor3 = Color3.fromRGB(22, 42, 92) }, main)
styled(body, 16, 4)

-- ON / OFF
local onBtn = button(body, "AUTO SELL: OFF", UDim2.new(1, -24, 0, 50), UDim2.fromOffset(12, 12), GRAY)
-- eggs / monsters
local eggsBtn = button(body, "SELL EGGS", UDim2.new(0.5, -18, 0, 40), UDim2.fromOffset(12, 72), GREEN)
local monstersBtn = button(body, "SELL MONSTERS", UDim2.new(0.5, -18, 0, 40), UDim2.new(0.5, 6, 0, 72), GREEN)
-- mode tabs
label(body, "WHAT TO SELL", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 122), { TextColor3 = Color3.fromRGB(255, 220, 110), TextXAlignment = Enum.TextXAlignment.Left })
local modeBtns = {
	all = button(body, "SELL ALL", UDim2.new(1 / 3, -14, 0, 38), UDim2.fromOffset(12, 150), BLUE),
	rarity = button(body, "BY RARITY", UDim2.new(1 / 3, -14, 0, 38), UDim2.new(1 / 3, 6, 0, 150), BLUE),
	cash = button(body, "BY CASH/S", UDim2.new(1 / 3, -14, 0, 38), UDim2.new(2 / 3, 0, 0, 150), BLUE),
}
-- rarity checkboxes
local rarityArea = mk("Frame", { Size = UDim2.new(1, -24, 0, 150), Position = UDim2.fromOffset(12, 198), BackgroundTransparency = 1 }, body)
mk("UIGridLayout", { CellSize = UDim2.new(0.2, -6, 0, 44), CellPadding = UDim2.fromOffset(6, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rarityArea)
local rarityBtns = {}
for i, r in ipairs(Config.Rarities) do
	local c = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
	local b = button(rarityArea, r.name:upper(), UDim2.new(), UDim2.new(), GRAY)
	b.LayoutOrder = i
	b:SetAttribute("Color", c)
	rarityBtns[r.key] = b
end
-- cash/s box
local cashArea = mk("Frame", { Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 198), BackgroundTransparency = 1, Visible = false }, body)
label(cashArea, "SELL IF IT EARNS LESS THAN:", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 0), { TextXAlignment = Enum.TextXAlignment.Left })
local cashBox = mk("TextBox", { Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = Color3.fromRGB(235, 244, 255), Text = "", PlaceholderText = "e.g. 500", TextScaled = true, Font = FONT, TextColor3 = OUTLINE, ClearTextOnFocus = false }, cashArea)
styled(cashBox, 10, 3)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10) }, cashBox)
label(cashArea, "cash per second (favorites are never sold)", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 88), { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 215, 240), TextStrokeTransparency = 1 })
local allNote = label(body, "Sells every egg and monster that comes into your backpack.\nFavorites are never sold.", UDim2.new(1, -24, 0, 60), UDim2.fromOffset(12, 210), { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 215, 240), TextStrokeTransparency = 1 })

-- gamepass lock
local lock = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 14, 30), BackgroundTransparency = 0.15, Visible = false, ZIndex = 20 }, body)
styled(lock, 16, 0)
label(lock, "AUTO SELL IS A GAMEPASS", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 60), { ZIndex = 21, TextColor3 = Color3.fromRGB(255, 220, 110) })
label(lock, "Buy it once to sell eggs and monsters automatically,\nby rarity or by cash/s.", UDim2.new(1, -40, 0, 50), UDim2.fromOffset(20, 104), { ZIndex = 21, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
local buyPass = button(lock, "BUY AUTO SELL", UDim2.new(0.7, 0, 0, 56), UDim2.new(0.15, 0, 0, 180), GREEN)
buyPass.ZIndex = 21

--------------------------------------------------------------------
-- state
--------------------------------------------------------------------
local settings = { enabled = false, eggs = true, monsters = true, mode = "all", rarities = {}, minCash = 0 }
local gamepassId = 0

local function render()
	onBtn.Text = settings.enabled and "AUTO SELL: ON" or "AUTO SELL: OFF"
	onBtn.BackgroundColor3 = settings.enabled and GREEN or GRAY
	eggsBtn.BackgroundColor3 = settings.eggs and GREEN or GRAY
	eggsBtn.Text = settings.eggs and "SELL EGGS: ON" or "SELL EGGS: OFF"
	monstersBtn.BackgroundColor3 = settings.monsters and GREEN or GRAY
	monstersBtn.Text = settings.monsters and "SELL MONSTERS: ON" or "SELL MONSTERS: OFF"
	for mode, b in pairs(modeBtns) do
		b.BackgroundColor3 = settings.mode == mode and Color3.fromRGB(255, 190, 50) or BLUE
	end
	rarityArea.Visible = settings.mode == "rarity"
	cashArea.Visible = settings.mode == "cash"
	allNote.Visible = settings.mode == "all"
	for key, b in pairs(rarityBtns) do
		b.BackgroundColor3 = settings.rarities[key] and b:GetAttribute("Color") or GRAY
		b.TextTransparency = settings.rarities[key] and 0 or 0.3
	end
	if not cashBox:IsFocused() then
		cashBox.Text = settings.minCash > 0 and Config.FormatNumber(settings.minCash) or ""
	end
end

local function save()
	render()
	local ok, r = pcall(function()
		return saveRemote:InvokeServer(settings)
	end)
	if ok and r and r.needsGamepass then
		lock.Visible = true
	end
end

onBtn.Activated:Connect(function()
	settings.enabled = not settings.enabled
	save()
	notify:Fire(settings.enabled and "Auto Sell is ON" or "Auto Sell is OFF", settings.enabled and GREEN or GRAY)
end)
eggsBtn.Activated:Connect(function()
	settings.eggs = not settings.eggs
	save()
end)
monstersBtn.Activated:Connect(function()
	settings.monsters = not settings.monsters
	save()
end)
for mode, b in pairs(modeBtns) do
	b.Activated:Connect(function()
		settings.mode = mode
		save()
	end)
end
for key, b in pairs(rarityBtns) do
	b.Activated:Connect(function()
		settings.rarities[key] = not settings.rarities[key] or nil
		save()
	end)
end
-- "1.5K" / "2M" style input is understood too
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
cashBox.FocusLost:Connect(function()
	local text = cashBox.Text:gsub(",", ""):gsub("%$", ""):lower()
	local num, suffix = text:match("^%s*([%d%.]+)%s*([kmbt]?)%s*$")
	settings.minCash = num and math.floor((tonumber(num) or 0) * (SUFFIX[suffix] or 1)) or 0
	save()
end)

buyPass.Activated:Connect(function()
	if gamepassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, bought)
	if plr == player and bought and passId == gamepassId then
		lock.Visible = false
		notify:Fire("Auto Sell unlocked!", GREEN)
	end
end)

local function open()
	closeAllBridge:Fire("autosell")
	local ok, info = pcall(function()
		return infoRemote:InvokeServer()
	end)
	if ok and info then
		gamepassId = info.gamepassId or 0
		lock.Visible = not info.owns
		if info.settings then
			settings = info.settings
			settings.rarities = settings.rarities or {}
			settings.minCash = settings.minCash or 0
		end
	end
	render()
	local v = workspace.CurrentCamera.ViewportSize
	local fit = math.min(1, (v.Y - 90) / H, (v.X - 30) / W)
	mainScale.Scale = fit * 0.85
	main.Visible = true
	TweenService:Create(mainScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = fit }):Play()
end
local function close()
	main.Visible = false
end
closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "autosell" then
		close()
	end
end)

-- notification when something was auto-sold
soldRemote.OnClientEvent:Connect(function(count, total)
	notify:Fire(string.format("Auto Sell: sold %d item%s for $%s", count, count == 1 and "" or "s", Config.FormatNumber(total)), GREEN)
end)

-- the AUTO SELL button in the backpack (next to SORT)
task.spawn(function()
	local backpack = player:WaitForChild("PlayerGui"):WaitForChild("Backpack")
	local bpMain = backpack:WaitForChild("Main")
	local b = bpMain:FindFirstChild("AutoSellButton") or button(bpMain, "AUTO SELL", UDim2.fromOffset(180, 52), UDim2.new(1, -392, 1, -64), GREEN)
	b.Name = "AutoSellButton"
	b.Activated:Connect(open)
end)
