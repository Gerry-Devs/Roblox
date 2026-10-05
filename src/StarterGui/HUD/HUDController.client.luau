local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
-- the studded card / tab look (nil if the module isn't synced)
local UIStyle
do
	local mod = monsterFolder:WaitForChild("UIStyle", 5)
	local ok, res = pcall(function()
		return mod and require(mod)
	end)
	UIStyle = ok and res or nil
end
local function styled(fnName, ...)
	if UIStyle and UIStyle[fnName] then
		pcall(UIStyle[fnName], ...)
	end
end
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local claimDailyRemote = remotes:WaitForChild("ClaimDaily")
local saveSettingsRemote = remotes:WaitForChild("SaveSettings")
local closeAllBridge = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("CloseAll")
local notifyBridge = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("Notify")

--------------------------------------------------------------------
-- HUD: cash + Rift Shards, the Shop / PvP / Index / Rebirth buttons,
-- the round Settings + Daily Rewards buttons at the top, and their
-- panels. All art is in StarterGui.HUD (swap any Image in Studio).
--------------------------------------------------------------------

local gui = script.Parent
local left = gui:WaitForChild("Left")
local cashAmount = left:WaitForChild("Cash"):WaitForChild("Amount")
local shardAmount = left:WaitForChild("Shards"):WaitForChild("Amount")
local incomeAmount = left:WaitForChild("Income"):WaitForChild("Amount")
local buttons = left:WaitForChild("Buttons")
local top = playerGui:WaitForChild("TopBar"):WaitForChild("Top") -- sits in Roblox's top bar row
local panels = gui:WaitForChild("Panels")
local templates = gui:WaitForChild("Templates")

local GOLD = Color3.fromRGB(255, 205, 93)
local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(60, 205, 95)
local BLUE = Color3.fromRGB(60, 160, 255)
local GRAY = Color3.fromRGB(110, 120, 145)
local NAVY = Color3.fromRGB(22, 42, 92)
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local profile = profileRemote:InvokeServer()
local settings = table.clone((profile and profile.settings) or {})
settings.graphics = settings.graphics or "High"
if settings.sound == nil then settings.sound = true end
if settings.otherPets == nil then settings.otherPets = true end
if settings.ownPets == nil then settings.ownPets = true end
if settings.miniDice == nil then settings.miniDice = true end
if settings.music == nil then settings.music = true end
if settings.particles == nil then settings.particles = true end
if settings.shadows == nil then settings.shadows = true end
settings.combat = settings.combat or Config.CombatModes.default
player:SetAttribute("CombatMode", settings.combat) -- AttackMenu follows this
-- graphics: particles (fire, smoke, sparkles...) and shadows can lag weaker devices
local function isFx(d)
	return d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
end
-- GRAPHICS: Super Low / Low / Mid / High / Super High (Config.Graphics)
-- controls particles, glow (lights + neon), shadows, bloom, decorations
local function gtier()
	return Config.GraphicsTier(settings.graphics)
end
local function fxAllowed()
	return gtier().particles > 0
end
local LightingSvc = game:GetService("Lighting")
local function isMonsterPart(d)
	return d:FindFirstAncestor("Pets") ~= nil or d:FindFirstAncestor("Enemies") ~= nil
end
-- one instance: particles, lights (glow) and neon monster parts
local function applyFxTo(d)
	local t = gtier()
	if d:IsA("ParticleEmitter") then
		local orig = d:GetAttribute("GfxRate")
		if orig == nil then
			orig = d.Rate
			d:SetAttribute("GfxRate", orig)
		end
		d.Rate = orig * t.particles
	elseif d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
		d.Enabled = t.particles >= 0.5
	elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
		-- no glow tiers: nothing glows (monsters, pens, biomes); restore only what we turned off
		if not t.lights then
			if d.Enabled then
				d:SetAttribute("GfxOff", true)
				d.Enabled = false
			end
		elseif d:GetAttribute("GfxOff") then
			d:SetAttribute("GfxOff", nil)
			d.Enabled = true
		end
	elseif d:IsA("BasePart") then
		if not t.neon then
			if d.Material == Enum.Material.Neon and isMonsterPart(d) then
				d:SetAttribute("GfxNeon", true)
				d.Material = Enum.Material.SmoothPlastic
			end
		elseif d:GetAttribute("GfxNeon") then
			d:SetAttribute("GfxNeon", nil)
			d.Material = Enum.Material.Neon
		end
	end
end
local function applyGraphicsFx()
	for _, d in ipairs(workspace:GetDescendants()) do
		applyFxTo(d)
	end
	local t = gtier()
	LightingSvc.GlobalShadows = t.shadows
	-- glowing effect (bloom on neon / bright parts + sun rays)
	for _, e in ipairs(LightingSvc:GetChildren()) do
		if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") then
			e.Enabled = t.bloom
		end
	end
	-- SUPER HIGH: extra polish (softer shadows, a little depth blur far away,
	-- stronger sun rays). Everything goes back to normal on other tiers.
	local dof = LightingSvc:FindFirstChild("DepthOfField")
	if dof and dof:IsA("DepthOfFieldEffect") then
		if dof:GetAttribute("GfxOrig") == nil then
			dof:SetAttribute("GfxOrig", dof.Enabled)
		end
		if t.extra then
			dof.Enabled = true
			dof.FarIntensity = 0.12
			dof.FocusDistance = 60
			dof.InFocusRadius = 120
			dof.NearIntensity = 0
		else
			dof.Enabled = dof:GetAttribute("GfxOrig")
		end
	end
	if LightingSvc:GetAttribute("GfxSoftness") == nil then
		LightingSvc:SetAttribute("GfxSoftness", LightingSvc.ShadowSoftness)
	end
	LightingSvc.ShadowSoftness = t.extra and 0.12 or LightingSvc:GetAttribute("GfxSoftness")
	local rays = LightingSvc:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		if rays:GetAttribute("GfxIntensity") == nil then
			rays:SetAttribute("GfxIntensity", rays.Intensity)
		end
		rays.Intensity = t.extra and math.max(rays:GetAttribute("GfxIntensity"), 0.12) or rays:GetAttribute("GfxIntensity")
	end
end
task.defer(applyGraphicsFx)
player:SetAttribute("MusicOn", settings.music ~= false)
-- the roll script reads this: small roll animation (on) or just a text line (off)
player:SetAttribute("MiniRoll", settings.miniDice ~= false)

--------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------

local function bounce(button)
	local s = button:FindFirstChildOfClass("UIScale")
	if not s then
		return
	end
	button.MouseEnter:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1.07 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
end

local function flash(panel, text, color)
	local msg = panel:FindFirstChild("Message")
	if not msg then
		return
	end
	msg.Text = text
	msg.TextColor3 = color
	msg.TextTransparency = 0
	msg.TextStrokeTransparency = 0
	local token = {}
	panel:SetAttribute("MsgToken", tostring(token))
	task.delay(2.2, function()
		if panel:GetAttribute("MsgToken") == tostring(token) then
			TweenService:Create(msg, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function uiScale()
	local camera = workspace.CurrentCamera
	local v = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.min(v.Y / 720, v.X / 1100, 1) * (isTouch and 1.05 or 1)
end

--------------------------------------------------------------------
-- currencies
--------------------------------------------------------------------

-- cash per second from the monsters in your pen (same formula as the server)
local function incomePerSecond()
	if not profile then
		return 0
	end
	local total = 0
	for _, e in ipairs(profile.base or {}) do
		if e.kind == "monster" then
			total += Config.GetEntryIncome(e)
		end
	end
	local cashUpgrade = 1 + Config.GetUpgradeBonus(profile.upgrades, "cash") / 100
	local rebirth = 1 + (profile.rebirths or 0) * Config.Rebirth.cashBonus / 100
	local potion = Config.IsBoostActive(profile, "cash", workspace:GetServerTimeNow()) and 2 or 1
	return math.floor(total * (profile.incomeBoost or 1) * cashUpgrade * rebirth * potion * Config.PassCashMultiplier(profile) * Config.GlobalBoost("income", workspace:GetServerTimeNow()) * Config.ExtraIncomeMultiplier(profile))
end

-- "+20% FRIEND INCOME" under the income (playing with friends)
local friendLabel
pcall(function()
	local income = left:FindFirstChild("Income")
	friendLabel = Instance.new("TextLabel")
	friendLabel.Name = "FriendBonus"
	friendLabel.Size = UDim2.new(0, 200, 0, 22)
	friendLabel.BackgroundTransparency = 1
	friendLabel.Font = Enum.Font.LuckiestGuy
	friendLabel.TextScaled = true
	friendLabel.TextXAlignment = Enum.TextXAlignment.Left
	friendLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
	friendLabel.TextStrokeTransparency = 0
	friendLabel.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
	friendLabel.Visible = false
	-- right under Income in the list
	if income then
		for _, c in ipairs(left:GetChildren()) do
			if c:IsA("GuiObject") and c ~= income and c.LayoutOrder > income.LayoutOrder then
				c.LayoutOrder += 1
			end
		end
		friendLabel.LayoutOrder = income.LayoutOrder + 1
	end
	friendLabel.Parent = left
end)
local function updateFriendLabel()
	local b = math.min(Config.FriendBonus.max, (profile and profile.friendBonus) or 0)
	if friendLabel then
		friendLabel.Visible = b > 0
		friendLabel.Text = "\u{1F465} +" .. b .. "% FRIEND INCOME"
	end
end

local function updateCurrencies()
	updateFriendLabel()
	incomeAmount.Text = "+" .. Config.FormatNumber(incomePerSecond()) .. "/s"
	cashAmount.Text = Config.FormatNumber(profile and profile.cash or 0)
	shardAmount.Text = Config.FormatNumber(profile and profile.riftShards or 0)
end

--------------------------------------------------------------------
-- panels
--------------------------------------------------------------------

local openPanel
local refreshers = {}
local updateMiniDice -- set further down
local hudHiddenState = false

local function closePanels()
	for _, p in ipairs(panels:GetChildren()) do
		p.Visible = false
	end
	openPanel = nil
end

local function showPanel(name)
	local panel = panels:FindFirstChild(name)
	if not panel then
		return
	end
	if openPanel == panel then
		closePanels()
		return
	end
	closeAllBridge:Fire("hud")
	closePanels()
	openPanel = panel
	if refreshers[name] then
		refreshers[name]()
	end
	panel.Visible = true
	local s = panel.UIScale
	-- shrink to fit the screen (room for the title ribbon + top bar)
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local target = math.min(1, (v.Y - 110) / panel.Size.Y.Offset, (v.X - 40) / panel.Size.X.Offset) * (isTouch and 0.9 or 1)
	s.Scale = target * 0.85
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
end

for _, p in ipairs(panels:GetChildren()) do
	local close = p:FindFirstChild("CloseButton")
	if close then
		bounce(close)
		close.Activated:Connect(closePanels)
	end
end
closeAllBridge.Event:Connect(function(except)
	if except ~= "hud" then
		closePanels()
	end
end)

for buttonName, panelName in pairs({
	ShopButton = "ShopPanel",
	PvpButton = "PvpPanel",
	IndexButton = "IndexPanel",
	RebirthButton = "RebirthPanel",
}) do
	local b = buttons:WaitForChild(buttonName)
	bounce(b)
	b.Activated:Connect(function()
		showPanel(panelName)
	end)
end
for buttonName, panelName in pairs({ SettingsButton = "SettingsPanel", DailyButton = "DailyPanel" }) do
	local b = top:WaitForChild(buttonName)
	bounce(b)
	b.Activated:Connect(function()
		showPanel(panelName)
	end)
end

--------------------------------------------------------------------
-- Index: every monster (pets you've owned / enemies you've defeated)
--------------------------------------------------------------------

local indexPanel = panels:WaitForChild("IndexPanel")
local indexBody = indexPanel.Body
local indexTab = "pets"
local indexRarity = "all" -- rarity filter ("all" or a rarity key)
local indexVariant = "any" -- "any", "Normal", a size or a finish (pets only)
local SIZE_KEYS, FINISH_KEYS = {}, {}
for _, v in ipairs(Config.SizeVariants) do
	SIZE_KEYS[v.key] = true
end
for _, v in ipairs(Config.FinishVariants) do
	FINISH_KEYS[v.key] = true
end

-- left column (like the Backpack): PETS / ENEMIES, then a rarity filter
local SIDE_W = 140
local rarityTabs = {}
local variantTabs = {}
local filterTitle
do
	local ok, err = pcall(function()
		if not indexPanel:GetAttribute("SideFilters") then
			indexPanel:SetAttribute("SideFilters", true)
			indexPanel.Size = UDim2.new(indexPanel.Size.X.Scale, indexPanel.Size.X.Offset + SIDE_W + 10, indexPanel.Size.Y.Scale, indexPanel.Size.Y.Offset)
		end
		local tabs = indexBody.Tabs
		tabs.Position = UDim2.new()
		tabs.Size = UDim2.new(0, SIDE_W, 1, 0)
		local layout = tabs:FindFirstChildOfClass("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		for i, name in ipairs({ "PetsTab", "EnemiesTab" }) do
			local b = tabs[name]
			b.LayoutOrder = i
			b.Size = UDim2.new(1, 0, 0, 40)
			b:SetAttribute("NoStuds", true)
			local lbl = b:FindFirstChild("Label")
			if lbl then
				lbl.ZIndex = b.ZIndex + 2
			end
		end
		local head = Instance.new("TextLabel")
		head.Name = "RarityHeader"
		head.LayoutOrder = 3
		head.Size = UDim2.new(1, 0, 0, 22)
		head.BackgroundTransparency = 1
		head.Text = "RARITY"
		head.Font = Enum.Font.LuckiestGuy
		head.TextScaled = true
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.TextColor3 = GOLD
		head.TextStrokeTransparency = 0
		head.Parent = tabs
		local list = Instance.new("ScrollingFrame")
		list.Name = "RarityList"
		list.LayoutOrder = 4
		list.Size = UDim2.new(1, 0, 1, -(40 * 2 + 22 + 8 * 3))
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = tabs
		local ll = Instance.new("UIListLayout")
		ll.Padding = UDim.new(0, 7)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent = list
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 8)
		pad.Parent = list
		local entries = { { key = "all", name = "All", color = Color3.fromRGB(255, 205, 60) } }
		for _, r in ipairs(Config.Rarities) do
			table.insert(entries, { key = r.key, name = r.name, color = Color3.fromRGB(r.color[1], r.color[2], r.color[3]) })
		end
		for i, e in ipairs(entries) do
			local b = Instance.new("TextButton")
			b.Name = "Rarity_" .. e.key
			b.LayoutOrder = i
			b.Size = UDim2.new(1, 0, 0, 32)
			b.Text = ""
			b.AutoButtonColor = false
			b:SetAttribute("NoStuds", true)
			b.Parent = list
			local lbl = Instance.new("TextLabel")
			lbl.Name = "Label"
			lbl.Size = UDim2.new(1, -30, 0.62, 0)
			lbl.AnchorPoint = Vector2.new(0, 0.5)
			lbl.Position = UDim2.new(0, 22, 0.5, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = e.name:upper()
			lbl.Font = Enum.Font.LuckiestGuy
			lbl.TextScaled = true
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = e.color
			lbl.TextStrokeTransparency = 0
			lbl.ZIndex = b.ZIndex + 2
			lbl.Parent = b
			rarityTabs[e.key] = { button = b, color = e.color }
			bounce(b)
			b.Activated:Connect(function()
				indexRarity = e.key
				refreshers.IndexPanel()
			end)
		end
		-- VARIANT: which pets you got as Normal / each size / each finish
		local vhead = Instance.new("TextLabel")
		vhead.Name = "VariantHeader"
		vhead.LayoutOrder = #entries + 1
		vhead.Size = UDim2.new(1, 0, 0, 22)
		vhead.BackgroundTransparency = 1
		vhead.Text = "VARIANT"
		vhead.Font = Enum.Font.LuckiestGuy
		vhead.TextScaled = true
		vhead.TextXAlignment = Enum.TextXAlignment.Left
		vhead.TextColor3 = GOLD
		vhead.TextStrokeTransparency = 0
		vhead.Parent = list
		local variants = { { key = "any", name = "Any", color = Color3.fromRGB(255, 205, 60) }, { key = "Normal", name = "Normal", color = Color3.fromRGB(220, 225, 235) } }
		local VCOL = {
			Big = Color3.fromRGB(150, 220, 255), Huge = Color3.fromRGB(190, 150, 255), Titan = Color3.fromRGB(255, 170, 60), Gigantic = Color3.fromRGB(255, 90, 90),
			Gold = Color3.fromRGB(255, 205, 60), Silver = Color3.fromRGB(215, 225, 240), Diamond = Color3.fromRGB(150, 230, 255), Rainbow = Color3.fromRGB(255, 130, 220), Galaxy = Color3.fromRGB(170, 110, 255),
		}
		for _, list2 in ipairs({ Config.SizeVariants, Config.FinishVariants }) do
			for _, v in ipairs(list2) do
				if v.key ~= "Normal" then
					table.insert(variants, { key = v.key, name = v.key, color = VCOL[v.key] or Color3.new(1, 1, 1) })
				end
			end
		end
		for i, e in ipairs(variants) do
			local b = Instance.new("TextButton")
			b.Name = "Variant_" .. e.key
			b.LayoutOrder = #entries + 1 + i
			b.Size = UDim2.new(1, 0, 0, 32)
			b.Text = ""
			b.AutoButtonColor = false
			b:SetAttribute("NoStuds", true)
			b.Parent = list
			local lbl = Instance.new("TextLabel")
			lbl.Name = "Label"
			lbl.Size = UDim2.new(1, -30, 0.62, 0)
			lbl.AnchorPoint = Vector2.new(0, 0.5)
			lbl.Position = UDim2.new(0, 22, 0.5, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = e.name:upper()
			lbl.Font = Enum.Font.LuckiestGuy
			lbl.TextScaled = true
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = e.color
			lbl.TextStrokeTransparency = 0
			lbl.ZIndex = b.ZIndex + 2
			lbl.Parent = b
			variantTabs[e.key] = { button = b, color = e.color }
			bounce(b)
			b.Activated:Connect(function()
				indexVariant = e.key
				refreshers.IndexPanel()
			end)
		end
		-- the grid moves right; above it: what you're looking at + the counter
		indexBody.Well.Position = UDim2.fromOffset(SIDE_W + 12, 44)
		indexBody.Well.Size = UDim2.new(1, -(SIDE_W + 12), 1, -44)
		filterTitle = Instance.new("TextLabel")
		filterTitle.Name = "FilterTitle"
		filterTitle.Size = UDim2.new(1, -(SIDE_W + 12 + 370), 0, 30)
		-- the counter also shows the Index reward of the page: wider
		local counter = indexBody:FindFirstChild("Counter")
		if counter then
			counter.Size = UDim2.new(0, 360, counter.Size.Y.Scale, counter.Size.Y.Offset)
		end
		filterTitle.Position = UDim2.fromOffset(SIDE_W + 14, 6)
		filterTitle.BackgroundTransparency = 1
		filterTitle.Font = Enum.Font.LuckiestGuy
		filterTitle.TextScaled = true
		filterTitle.TextXAlignment = Enum.TextXAlignment.Left
		filterTitle.TextColor3 = GOLD
		filterTitle.TextStrokeTransparency = 0
		filterTitle.Parent = indexBody
	end)
	if not ok then
		warn("Index filters failed (the Index still works): " .. tostring(err))
	end
end

local function getMonsterIcon(monsterId)
	local bp = playerGui:FindFirstChild("Backpack")
	local icons = bp and bp:FindFirstChild("ItemIcons")
	local v = icons and icons:FindFirstChild(monsterId)
	return v and v.Value or ""
end

--------------------------------------------------------------------
-- Index info: tap a monster you found to see its odds, your biggest kg
-- and which sizes / finishes you got (with the odds of each)
--------------------------------------------------------------------
local VARIANT_COLORS = {
	Normal = Color3.fromRGB(220, 225, 235),
	Big = Color3.fromRGB(150, 220, 255),
	Huge = Color3.fromRGB(190, 150, 255),
	Titan = Color3.fromRGB(255, 170, 60),
	Gigantic = Color3.fromRGB(255, 90, 90),
	Gold = Color3.fromRGB(255, 205, 60),
	Silver = Color3.fromRGB(215, 225, 240),
	Diamond = Color3.fromRGB(150, 230, 255),
	Rainbow = Color3.fromRGB(255, 130, 220),
	Galaxy = Color3.fromRGB(170, 110, 255),
}
local indexInfo = Instance.new("Frame")
indexInfo.Name = "IndexInfo"
indexInfo.AnchorPoint = Vector2.new(0.5, 0.5)
indexInfo.Position = UDim2.fromScale(0.5, 0.52)
indexInfo.Size = UDim2.fromOffset(560, 0)
indexInfo.AutomaticSize = Enum.AutomaticSize.Y
indexInfo.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
indexInfo.Visible = false
indexInfo.ZIndex = 40
indexInfo.Active = true
indexInfo.Parent = indexPanel
Instance.new("UICorner", indexInfo).CornerRadius = UDim.new(0, 14)
do
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(10, 15, 35)
	st.Thickness = 4
	st.Parent = indexInfo
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 12)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = indexInfo
end
-- the rows (in a list) + the X in the corner (outside the list)
local indexInfoBody = Instance.new("Frame")
indexInfoBody.Name = "Body"
indexInfoBody.Size = UDim2.fromScale(1, 0)
indexInfoBody.AutomaticSize = Enum.AutomaticSize.Y
indexInfoBody.BackgroundTransparency = 1
indexInfoBody.ZIndex = 41
indexInfoBody.Parent = indexInfo
do
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.Parent = indexInfoBody
end
local indexInfoClose = Instance.new("TextButton")
indexInfoClose.Name = "InfoClose"
indexInfoClose.Size = UDim2.fromOffset(30, 30)
indexInfoClose.AnchorPoint = Vector2.new(1, 0)
indexInfoClose.Position = UDim2.new(1, 6, 0, -4)
indexInfoClose.BackgroundColor3 = Color3.fromRGB(235, 70, 80)
indexInfoClose.Text = "X"
indexInfoClose.TextScaled = true
indexInfoClose.Font = Enum.Font.GothamBlack
indexInfoClose.TextColor3 = Color3.new(1, 1, 1)
indexInfoClose.ZIndex = 45
indexInfoClose.Parent = indexInfo
Instance.new("UICorner", indexInfoClose).CornerRadius = UDim.new(0, 8)
local indexInfoFor
local function closeIndexInfo()
	indexInfo.Visible = false
	indexInfoFor = nil
end
indexInfoClose.Activated:Connect(closeIndexInfo)
indexPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not indexPanel.Visible then
		closeIndexInfo()
	end
end)
local function infoText(order, text, size, color, font, align, parent)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.Font = font or Enum.Font.GothamBold
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.ZIndex = 42
	l.Parent = parent or indexInfoBody
	return l
end
-- one size / finish row: name, its odds, got it?
local function infoRow(order, name, chanceText, got, parent, nameColor)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = got and Color3.fromRGB(40, 70, 50) or Color3.fromRGB(38, 40, 52)
	row.ZIndex = 42
	row.Parent = parent or indexInfoBody
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
	local function cell(text, x, w, color, align)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(x, 8, 0, 0)
		l.Size = UDim2.new(w, -16, 1, 0)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextSize = 14
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.5
		l.TextXAlignment = align
		l.ZIndex = 43
		l.Parent = row
	end
	cell(name, 0, 0.42, nameColor or VARIANT_COLORS[name] or Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	cell(chanceText, 0.38, 0.42, Color3.fromRGB(200, 210, 230), Enum.TextXAlignment.Center)
	cell(got and "\u{2713}" or "\u{2014}", 0.78, 0.22, got and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(120, 125, 140), Enum.TextXAlignment.Right)
end
local function variantOdds(list, key)
	local total, w = 0, 0
	for _, v in ipairs(list) do
		total += v.weight
		if v.key == key then
			w = v.weight
		end
	end
	return w > 0 and Config.FormatOdds(total / w) or "-"
end
local function showIndexInfo(monster)
	if indexInfoFor == monster.id and indexInfo.Visible then
		closeIndexInfo()
		return
	end
	indexInfoFor = monster.id
	for _, c in ipairs(indexInfoBody:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local rarity = Config.GetRarity(monster.rarity)
	local color = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
	local rec = (profile and profile.indexStats and profile.indexStats[monster.id]) or { maxKg = 0, sizes = {}, finishes = {} }
	local o = 0
	local function nxt()
		o += 1
		return o
	end
	infoText(nxt(), monster.name, 22, color, Enum.Font.GothamBlack)
	infoText(nxt(), rarity.name:upper() .. "  \u{2022}  " .. Config.FormatOdds(Config.GetOdds(monster.id, "Normal", "Normal")), 15, color:Lerp(Color3.new(1, 1, 1), 0.25))
	local count = (profile and profile.owned and profile.owned[monster.id]) or 0
	infoText(nxt(), "Owned: " .. count .. "     Biggest: " .. ((rec.maxKg or 0) > 0 and Config.FormatKg(rec.maxKg) or "-"), 15, Color3.fromRGB(230, 235, 245))
	-- two columns: sizes + finishes on the left, grades on the right
	local cols = Instance.new("Frame")
	cols.LayoutOrder = nxt()
	cols.Size = UDim2.fromScale(1, 0)
	cols.AutomaticSize = Enum.AutomaticSize.Y
	cols.BackgroundTransparency = 1
	cols.ZIndex = 41
	cols.Parent = indexInfoBody
	local function column(x)
		local c = Instance.new("Frame")
		c.Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0)
		c.Size = UDim2.new(0.5, -6, 0, 0)
		c.AutomaticSize = Enum.AutomaticSize.Y
		c.BackgroundTransparency = 1
		c.ZIndex = 41
		c.Parent = cols
		local l = Instance.new("UIListLayout")
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 3)
		l.Parent = c
		return c
	end
	local leftCol, rightCol = column(0), column(0.5)
	local lo = 0
	local function ln()
		lo += 1
		return lo
	end
	infoText(ln(), "SIZES", 16, GOLD, Enum.Font.GothamBlack, nil, leftCol)
	for _, v in ipairs(Config.SizeVariants) do
		infoRow(ln(), v.key, variantOdds(Config.SizeVariants, v.key), rec.sizes and rec.sizes[v.key], leftCol)
	end
	infoText(ln(), "FINISHES", 16, GOLD, Enum.Font.GothamBlack, nil, leftCol)
	for _, v in ipairs(Config.FinishVariants) do
		infoRow(ln(), v.key, variantOdds(Config.FinishVariants, v.key), rec.finishes and rec.finishes[v.key], leftCol)
	end
	-- grades (rolled when an egg hatches): their odds + the ones you got
	infoText(1, "GRADES", 16, GOLD, Enum.Font.GothamBlack, nil, rightCol)
	for i, g in ipairs(Config.Grades) do
		infoRow(1 + i, "Grade " .. g.key, Config.FormatOdds(1 / Config.GradeChance(g.key)), rec.grades and rec.grades[g.key], rightCol, Config.GradeColor(g.key))
	end
	indexInfo.Visible = true
end

refreshers.IndexPanel = function()
	local grid = indexBody.Well.Grid
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	indexBody.Tabs.PetsTab.BackgroundColor3 = indexTab == "pets" and GOLD or BLUE
	indexBody.Tabs.EnemiesTab.BackgroundColor3 = indexTab == "enemies" and GOLD or BLUE
	styled("sideTab", indexBody.Tabs.PetsTab, indexTab == "pets", Color3.fromRGB(255, 205, 60))
	styled("sideTab", indexBody.Tabs.EnemiesTab, indexTab == "enemies", Color3.fromRGB(235, 70, 70))
	for key, t in pairs(rarityTabs) do
		styled("sideTab", t.button, key == indexRarity, t.color)
	end
	for key, t in pairs(variantTabs) do
		styled("sideTab", t.button, key == indexVariant, t.color)
		t.button.Visible = indexTab == "pets" -- enemies have no variants
	end
	local variantHeader = indexBody.Tabs:FindFirstChild("RarityList") and indexBody.Tabs.RarityList:FindFirstChild("VariantHeader")
	if variantHeader then
		variantHeader.Visible = indexTab == "pets"
	end
	local variant = indexTab == "pets" and indexVariant ~= "any" and indexVariant or nil
	local vSize = variant and (variant == "Normal" or SIZE_KEYS[variant]) and variant or "Normal"
	local vFinish = variant and (variant == "Normal" or (FINISH_KEYS[variant] and not SIZE_KEYS[variant])) and variant or "Normal"

	local list = table.clone(Config.Monsters)
	table.sort(list, function(a, b)
		local ta, tb = Config.GetRarity(a.rarity).tier, Config.GetRarity(b.rarity).tier
		if ta ~= tb then
			return ta < tb
		end
		return a.name < b.name
	end)
	if indexRarity ~= "all" then
		local only = {}
		for _, monster in ipairs(list) do
			if Config.GetRarity(monster.rarity).key == indexRarity then
				table.insert(only, monster)
			end
		end
		list = only
	end
	if filterTitle then
		local r = indexRarity ~= "all" and Config.GetRarity(indexRarity)
		filterTitle.Text = (r and r.name:upper() or "ALL") .. (variant and (" " .. variant:upper()) or "") .. (indexTab == "pets" and " PETS" or " ENEMIES")
		filterTitle.TextColor3 = r and Color3.fromRGB(r.color[1], r.color[2], r.color[3]) or GOLD
	end
	local found = 0
	for i, monster in ipairs(list) do
		local count
		if indexTab == "pets" then
			count = profile and profile.owned and profile.owned[monster.id]
		else
			count = profile and profile.enemyKills and profile.enemyKills[monster.id]
		end
		local discovered = count ~= nil
		local knownMonster = discovered -- you have the monster (maybe not this variant)
		-- a variant filter: found = you got this monster as that size / finish
		if variant and discovered then
			local rec = profile and profile.indexStats and profile.indexStats[monster.id]
			if variant == "Normal" then
				discovered = rec ~= nil and rec.sizes and rec.sizes.Normal == true and rec.finishes and rec.finishes.Normal == true
			elseif SIZE_KEYS[variant] then
				discovered = rec ~= nil and rec.sizes and rec.sizes[variant] == true
			else
				discovered = rec ~= nil and rec.finishes and rec.finishes[variant] == true
			end
			discovered = discovered == true
		end
		if discovered then
			found += 1
		end
		local rarity = Config.GetRarity(monster.rarity)
		local color = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
		local card = templates.IndexCard:Clone()
		card.Name = monster.id
		card.LayoutOrder = i
		card.Visible = true
		card.BackgroundColor3 = discovered and color or Color3.fromRGB(45, 52, 78)
		local icon = discovered and getMonsterIcon(monster.id) or ""
		card.Icon.Image = icon
		card.Icon.Visible = icon ~= ""
		card.Fallback.Visible = icon == ""
		card.Fallback.BackgroundColor3 = discovered and color:Lerp(Color3.new(0, 0, 0), 0.35) or Color3.fromRGB(30, 34, 52)
		card.Fallback.Letter.Text = discovered and string.sub(monster.name, 1, 1) or "?"
		card.ItemName.Text = discovered and (variant and Config.BuildDisplayName(monster.name, vSize, vFinish) or monster.name)
			or (knownMonster and monster.name or "???")
		if discovered then
			-- pets you found: the monster's odds (the card color is its rarity)
			card.Info.Text = indexTab == "pets" and Config.FormatOdds(Config.GetOdds(monster.id, vSize, vFinish)) or ("Defeated " .. Config.FormatNumber(count))
			if indexTab == "pets" then
				-- tap for the full info (sizes / finishes / biggest kg)
				local hit = Instance.new("TextButton")
				hit.Name = "Tap"
				hit.Size = UDim2.fromScale(1, 1)
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.ZIndex = 10
				hit.Parent = card
				hit.Activated:Connect(function()
					showIndexInfo(monster)
				end)
			end
		elseif knownMonster and variant then
			-- you have it, but not as this variant yet: how rare that is
			card.Info.Text = Config.FormatOdds(Config.GetOdds(monster.id, vSize, vFinish))
			card.ItemName.TextTransparency = 0.35
		else
			card.Info.Text = rarity.name:upper()
		end
		styled("rarityCard", card, discovered and color or Color3.fromRGB(70, 75, 90))
		card.Parent = grid
	end
	-- what finishing this page gives (Index rewards)
	local reward = ""
	if indexTab == "pets" then
		if variant and variant ~= "Normal" and #list == #Config.Monsters then
			reward = SIZE_KEYS[variant] and "  \u{2022}  Reward: bigger pen +1 egg slot" or ("  \u{2022}  Reward: " .. variant:upper() .. " PEN")
		elseif not variant and indexRarity ~= "all" then
			local r = Config.IndexRewards.rarity[indexRarity]
			if r then
				reward = "  \u{2022}  Reward: +" .. r.luck .. "% luck +" .. r.cash .. "% cash"
			end
		end
		if reward ~= "" and found >= #list then
			reward ..= " \u{2713}"
		end
	end
	indexBody.Counter.Text = found .. "/" .. #list .. " found" .. reward
end

for tabName, key in pairs({ PetsTab = "pets", EnemiesTab = "enemies" }) do
	local b = indexBody.Tabs[tabName]
	bounce(b)
	b.Activated:Connect(function()
		indexTab = key
		refreshers.IndexPanel()
	end)
end

--------------------------------------------------------------------
-- Rebirth
--------------------------------------------------------------------

local rebirthPanel = panels:WaitForChild("RebirthPanel")
local rb = rebirthPanel.Body
local rebirthBusy = false

refreshers.RebirthPanel = function()
	local n = (profile and profile.rebirths) or 0
	local cashCost, shardCost = Config.GetRebirthCost(n)
	local R = Config.Rebirth
	rb.Count.Text = "REBIRTHS: " .. n
	rb.Current.Text = string.format("Now: +%d%% cash  \u{2022}  +%d%% luck  \u{2022}  +%d%% shards", n * R.cashBonus, n * R.luckBonus, n * R.shardBonus)
	rb.Next.Text = string.format("After: +%d%% cash  \u{2022}  +%d%% luck  \u{2022}  +%d%% shards", (n + 1) * R.cashBonus, (n + 1) * R.luckBonus, (n + 1) * R.shardBonus)
	rb.Cost.CashCost.Text = Config.FormatNumber(cashCost)
	rb.Cost.ShardCost.Text = Config.FormatNumber(shardCost)
	local canCash = (profile and profile.cash or 0) >= cashCost
	local canShards = (profile and profile.riftShards or 0) >= shardCost
	rb.Cost.CashCost.TextColor3 = canCash and Color3.new(1, 1, 1) or RED
	rb.Cost.ShardCost.TextColor3 = canShards and Color3.new(1, 1, 1) or RED
	rb.RebirthButton.BackgroundColor3 = (canCash and canShards) and GREEN or GRAY
end

bounce(rb.RebirthButton)
rb.RebirthButton.Activated:Connect(function()
	if rebirthBusy then
		return
	end
	rebirthBusy = true
	local ok, response = pcall(function()
		return rebirthRemote:InvokeServer()
	end)
	rebirthBusy = false
	if ok and response then
		if response.profile then
			profile = response.profile
		end
		flash(rebirthPanel, response.message or "", response.success and GOLD or RED)
		refreshers.RebirthPanel()
		updateCurrencies()
	end
end)

--------------------------------------------------------------------
-- Settings (saved to your profile)
--------------------------------------------------------------------

local settingsPanel = panels:WaitForChild("SettingsPanel")
local sb = settingsPanel.Body

local function applyGraphics()
	local q = settings.graphics
	player:SetAttribute("Graphics", q) -- RigSkinner / BiomeLoader follow this
	applyGraphicsFx()
	-- (biome decorations are shown / hidden by BiomeLoader)
end

-- things that load in later (streaming) follow the Low setting too
workspace.DescendantAdded:Connect(function(d)
	local t = gtier()
	if t.particles >= 1 and t.lights and t.neon and not d:GetAttribute("GfxOff") then
		return -- nothing to change
	end
	if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Light") or (d:IsA("BasePart") and d.Material == Enum.Material.Neon) then
		task.defer(function()
			if d.Parent then
				applyFxTo(d)
			end
		end)
	end
end)

local function setSoundMuted(s, muted)
	if muted then
		if s:GetAttribute("OrigVolume") == nil then
			s:SetAttribute("OrigVolume", s.Volume)
		end
		s.Volume = 0
	elseif s:GetAttribute("OrigVolume") ~= nil then
		s.Volume = s:GetAttribute("OrigVolume")
		s:SetAttribute("OrigVolume", nil)
	end
end

local function applySound()
	for _, root in ipairs({ workspace, SoundService, playerGui }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Sound") then
				setSoundMuted(d, not settings.sound)
			end
		end
	end
end
for _, root in ipairs({ workspace, SoundService, playerGui }) do
	root.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") and not settings.sound then
			setSoundMuted(d, true)
		end
	end)
end

-- hides / shows pets (yours or other players') on your screen only
local function applyPetVisibility()
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	if not world then
		return
	end
	for _, base in ipairs(world:GetChildren()) do
		local pets = base.Name:match("^Base_") and base:FindFirstChild("Pets")
		if pets then
			local own = base.Name == "Base_" .. player.UserId
			local show = (own and settings.ownPets) or (not own and settings.otherPets)
			for _, d in ipairs(pets:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = show and 0 or 1
				elseif d:IsA("BillboardGui") then
					if not show and d.Enabled then
						d:SetAttribute("HiddenBySettings", true)
						d.Enabled = false
					elseif show and d:GetAttribute("HiddenBySettings") then
						d:SetAttribute("HiddenBySettings", nil)
						d.Enabled = true
					end
				end
			end
		end
	end
end
task.spawn(function()
	while true do
		applyPetVisibility()
		task.wait(1)
	end
end)

-- ON/OFF switches (like the reference): a dark track with a knob that
-- slides right (green ON) or left (red OFF)
local function styleToggle(rowName, on)
	local t = sb[rowName].Options.Toggle
	local knob = t:FindFirstChild("Knob")
	if not knob then
		t.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
		t.AutoButtonColor = false
		local st = t:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = Color3.fromRGB(95, 100, 115)
			st.Thickness = 2
		end
		local g = t:FindFirstChildOfClass("UIGradient")
		if g then
			g.Enabled = false
		end
		knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.new(0.56, 0, 1, 0)
		knob.ZIndex = t.ZIndex + 2
		Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 10)
		local ks = Instance.new("UIStroke")
		ks.Color = Color3.fromRGB(10, 12, 22)
		ks.Thickness = 2.5
		ks.Parent = knob
		local kg = Instance.new("UIGradient")
		kg.Rotation = 90
		kg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 205))
		kg.Parent = knob
		knob.Parent = t
		local lbl = t:FindFirstChild("Label")
		if lbl then
			lbl.Parent = knob
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.Position = UDim2.fromScale(0.5, 0.5)
			lbl.Size = UDim2.fromScale(0.8, 0.62)
			lbl.ZIndex = knob.ZIndex + 1
		end
	end
	knob.BackgroundColor3 = on and GREEN or Color3.fromRGB(235, 70, 80)
	TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Position = on and UDim2.fromScale(0.44, 0) or UDim2.fromScale(0, 0) }):Play()
	local lbl = knob:FindFirstChild("Label")
	if lbl then
		lbl.Text = on and "ON" or "OFF"
	end
end

-- rows: dark cards, the names in a clean bold font (Title Case)
local function titleCase(str)
	return (string.lower(str):gsub("(%a)([%w']*)", function(a, b)
		return string.upper(a) .. b
	end))
end
for _, row in ipairs(sb:GetChildren()) do
	if row:IsA("Frame") then
		row.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
		local st = row:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = Color3.fromRGB(58, 61, 72)
			st.Thickness = 2
		end
		local lbl = row:FindFirstChild("Label")
		if lbl and lbl:IsA("TextLabel") then
			lbl.Text = titleCase(lbl.Text)
			lbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
			lbl.TextColor3 = Color3.new(1, 1, 1)
			lbl.TextStrokeTransparency = 0.5
		end
	end
end

-- COMBAT row: MENU / QUICK / AUTO (made from the Graphics row)
local combatButtons = {}
do
	local ok, err = pcall(function()
		local src = sb:FindFirstChild("Graphics")
		if not src or sb:FindFirstChild("Combat") then
			return
		end
		local row = src:Clone()
		row.Name = "Combat"
		local maxOrder = 0
		for _, c in ipairs(sb:GetChildren()) do
			if c:IsA("GuiObject") then
				maxOrder = math.max(maxOrder, c.LayoutOrder)
			end
		end
		row.LayoutOrder = maxOrder + 1
		for _, d in ipairs(row:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		local lbl = row:FindFirstChild("Label")
		if lbl and lbl:IsA("TextLabel") then
			lbl.Text = "Combat"
		end
		local options = row:FindFirstChild("Options")
		local template
		for _, q in ipairs(Config.Graphics.order) do
			local b = options and options:FindFirstChild(q)
			if b then
				template = template or b:Clone()
				b:Destroy()
			end
		end
		if not template then
			row:Destroy()
			return
		end
		for i, mode in ipairs(Config.CombatModes.order) do
			local b = template:Clone()
			b.Name = mode
			b.LayoutOrder = i
			local name = Config.CombatModes.names[mode]
			if b:IsA("TextButton") and b.Text ~= "" then
				b.Text = name
			end
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("TextLabel") then
					d.Text = name
				end
			end
			b.Parent = options
			combatButtons[mode] = b
		end
		row.Parent = sb
	end)
	if not ok then
		warn("Combat setting row failed: " .. tostring(err))
	end
end

-- the rows scroll inside a window of a normal height (Combat, Tag...
-- were added later; a taller window got tiny on phones). The Body keeps
-- its rows (other scripts use sb.Graphics etc.); it now sits in a
-- ScrollingFrame that takes the Body's old spot.
do
	local ok, err = pcall(function()
		if sb.Parent ~= settingsPanel then
			return
		end
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "BodyScroll"
		scroll.Position = sb.Position
		scroll.Size = sb.Size
		scroll.AnchorPoint = sb.AnchorPoint
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.CanvasSize = UDim2.new()
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ZIndex = sb.ZIndex
		scroll.Parent = settingsPanel
		sb.AnchorPoint = Vector2.new(0, 0)
		sb.Position = UDim2.fromOffset(0, 0)
		sb.Size = UDim2.new(1, -10, 0, 0)
		sb.AutomaticSize = Enum.AutomaticSize.Y
		sb.Parent = scroll
		-- a normal window height (it was 596 for the first 6 rows)
		settingsPanel.Size = UDim2.new(settingsPanel.Size.X.Scale, settingsPanel.Size.X.Offset, 0, 470)
	end)
	if not ok then
		warn("Settings scroll failed (Settings still works): " .. tostring(err))
	end
end

refreshers.SettingsPanel = function()
	local autoLocked = ((profile and profile.rebirths) or 0) < Config.CombatModes.autoRebirths
	for mode, b in pairs(combatButtons) do
		b.BackgroundColor3 = settings.combat == mode and GOLD or Color3.fromRGB(58, 62, 76)
		if mode == "auto" then
			local name = autoLocked and ("\u{1F512} R" .. Config.CombatModes.autoRebirths) or Config.CombatModes.names.auto
			if b:IsA("TextButton") and b.Text ~= "" then
				b.Text = name
			end
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("TextLabel") then
					d.Text = name
				end
			end
		end
	end
	for _, q in ipairs(Config.Graphics.order) do
		local b = sb.Graphics.Options:FindFirstChild(q)
		if b then
			b.BackgroundColor3 = settings.graphics == q and GOLD or Color3.fromRGB(58, 62, 76)
		end
	end
	styleToggle("Sound", settings.sound)
	styleToggle("OtherPets", settings.otherPets)
	styleToggle("OwnPets", settings.ownPets)
	styleToggle("MiniDice", settings.miniDice)
	styleToggle("Music", settings.music)
end

local saveToken
local function saveSettings()
	refreshers.SettingsPanel()
	local token = {}
	saveToken = token
	task.delay(0.6, function()
		if saveToken == token then
			pcall(function()
				saveSettingsRemote:InvokeServer(settings)
			end)
		end
	end)
end

for _, q in ipairs(Config.Graphics.order) do
	local b = sb.Graphics.Options:WaitForChild(q)
	bounce(b)
	b.Activated:Connect(function()
		settings.graphics = q
		applyGraphics()
		saveSettings()
	end)
end
for mode, b in pairs(combatButtons) do
	bounce(b)
	b.Activated:Connect(function()
		if mode == "auto" and ((profile and profile.rebirths) or 0) < Config.CombatModes.autoRebirths then
			notifyBridge:Fire("Auto attack unlocks at Rebirth " .. Config.CombatModes.autoRebirths .. "!", RED)
			return
		end
		settings.combat = mode
		player:SetAttribute("CombatMode", mode)
		saveSettings()
	end)
end
for rowName, key in pairs({ Sound = "sound", OtherPets = "otherPets", OwnPets = "ownPets", MiniDice = "miniDice", Music = "music" }) do
	local b = sb[rowName].Options.Toggle
	bounce(b)
	b.Activated:Connect(function()
		settings[key] = not settings[key]
		if key == "sound" then
			applySound()
		elseif key == "music" then
			player:SetAttribute("MusicOn", settings.music ~= false)
		elseif key == "miniDice" then
			player:SetAttribute("MiniRoll", settings.miniDice ~= false)
		else
			applyPetVisibility()
		end
		saveSettings()
	end)
end

--------------------------------------------------------------------
-- Daily rewards (7-day streak)
--------------------------------------------------------------------

local dailyPanel = panels:WaitForChild("DailyPanel")
local db = dailyPanel.Body
local dailyButton = top:WaitForChild("DailyButton")
local dailyBusy = false

local function utcDay()
	return math.floor(workspace:GetServerTimeNow() / 86400)
end

-- which day you're on and whether it can be claimed right now
local function dailyState()
	local d = (profile and profile.daily) or { streak = 0, lastDay = -1 }
	local today = utcDay()
	if d.lastDay == today then
		return d.streak, false
	end
	if d.lastDay == today - 1 then
		return (d.streak % 7) + 1, true
	end
	return 1, true
end

local function rewardInfo(reward)
	local parts, icon = {}, ""
	if reward.cash then
		table.insert(parts, "$" .. Config.FormatNumber(reward.cash))
		icon = Config.CashImage
	end
	if reward.shards then
		table.insert(parts, reward.shards .. " Shards")
		icon = Config.RiftShardImage
	end
	for key, n in pairs(reward.items or {}) do
		local item = Config.Items[key]
		table.insert(parts, (n > 1 and (n .. "x ") or "") .. (item and item.name or key))
		icon = item and item.imageId or icon
	end
	for key, n in pairs(reward.potions or {}) do
		local potion = Config.GetPotion(key)
		table.insert(parts, (n > 1 and (n .. "x ") or "") .. (potion and potion.name or key))
		icon = potion and potion.imageId or icon
	end
	return table.concat(parts, " + "), icon
end

-- Daily Rewards cards (like the reference): Day 1-3 and 4-6 in two rows,
-- a big tall Day 7 on the right; dark cards with a colored border, claimed
-- days dimmed with a big green check.
local DAY_COLORS = {
	Color3.fromRGB(70, 210, 90), Color3.fromRGB(60, 150, 255), Color3.fromRGB(160, 80, 255),
	Color3.fromRGB(255, 190, 40), Color3.fromRGB(240, 60, 70), Color3.fromRGB(80, 110, 255), Color3.fromRGB(255, 255, 255),
}
local dailyStyled = false
local function styleDailyCards()
	if dailyStyled then
		return
	end
	dailyStyled = true
	local days = db.Days
	local grid = days:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid:Destroy() -- placed by hand below (Day 7 is double height)
	end
	local GAP = 0.014
	local COL = (1 - GAP * 3) / 4
	for d = 1, 7 do
		local card = days["Day" .. d]
		if d < 7 then
			local col, row = (d - 1) % 3, (d - 1) // 3
			card.Position = UDim2.new(col * (COL + GAP), 0, row * 0.5, row == 1 and 5 or 0)
			card.Size = UDim2.new(COL, 0, 0.5, -5)
		else
			card.Position = UDim2.new(3 * (COL + GAP), 0, 0, 0)
			card.Size = UDim2.new(COL, 0, 1, 0)
		end
		card.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
		card.ClipsDescendants = false
		local ring = card:FindFirstChild("Ring")
		if ring then
			ring.Color = DAY_COLORS[d]
			ring.Thickness = 4
			if d == 7 then
				-- rainbow border for the big prize
				local g = ring:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
					ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
				})
				g.Rotation = 45
				g.Parent = ring
			end
		end
		-- "Day N" on top, the picture big in the middle, the reward at the bottom
		card.DayLabel.Text = "Day " .. d
		card.DayLabel.TextColor3 = Color3.new(1, 1, 1)
		card.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Icon.Position = UDim2.fromScale(0.5, 0.5)
		card.Icon.Size = d == 7 and UDim2.fromScale(0.85, 0.5) or UDim2.fromScale(0.55, 0.45)
		card.Icon.SizeConstraint = Enum.SizeConstraint.RelativeXY
		card.Icon.ScaleType = Enum.ScaleType.Fit
		card.Reward.AnchorPoint = Vector2.new(0.5, 1)
		card.Reward.Position = UDim2.new(0.5, 0, 1, -6)
		card.Reward.Size = UDim2.new(1, -12, 0, d == 7 and 40 or 30)
		card.Reward.TextColor3 = Color3.new(1, 1, 1)
		card.Reward.TextStrokeTransparency = 0
		card.Reward.TextScaled = true
		card.Reward.TextWrapped = true
		card.Status.AnchorPoint = Vector2.new(0.5, 0)
		card.Status.Position = UDim2.new(0.5, 0, 0, 30)
		card.Status.Size = UDim2.new(1, -10, 0, 16)
		-- claimed: dark cover + big green check
		local dim = Instance.new("Frame")
		dim.Name = "ClaimedDim"
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = Color3.new(0, 0, 0)
		dim.BackgroundTransparency = 0.45
		dim.ZIndex = 20
		dim.Visible = false
		Instance.new("UICorner", dim).CornerRadius = (card:FindFirstChildOfClass("UICorner") or { CornerRadius = UDim.new(0, 12) }).CornerRadius
		dim.Parent = card
		local check = Instance.new("TextLabel")
		check.Name = "Check"
		check.AnchorPoint = Vector2.new(0.5, 0.5)
		check.Position = UDim2.fromScale(0.5, 0.5)
		check.Size = UDim2.fromScale(0.7, 0.55)
		check.BackgroundTransparency = 1
		check.Text = "\u{2714}"
		check.Font = Enum.Font.GothamBlack
		check.TextScaled = true
		check.TextColor3 = Color3.fromRGB(80, 220, 90)
		check.TextStrokeTransparency = 0
		check.TextStrokeColor3 = Color3.fromRGB(10, 40, 15)
		check.ZIndex = 21
		check.Parent = dim
	end
	-- "Next reward in ..." in green
	db.Timer.TextColor3 = Color3.fromRGB(150, 255, 90)
	db.Timer.Font = Enum.Font.LuckiestGuy
	db.Timer.TextStrokeTransparency = 0
end

refreshers.DailyPanel = function()
	styleDailyCards()
	local day, claimable = dailyState()
	for d = 1, 7 do
		local card = db.Days["Day" .. d]
		local textInfo, icon = rewardInfo(Config.DailyRewards[d])
		-- the reward text stops above the status line (long rewards used to
		-- run under "CLAIMED"); long text shrinks to fit instead
		card.Reward.Size = UDim2.new(1, -10, 1, -(90 + 30))
		card.Reward.TextScaled = true
		card.Reward.TextWrapped = true
		card.Status.Size = UDim2.new(1, -10, 0, 20)
		card.Reward.Text = textInfo
		card.Icon.Image = icon
		local claimed = (d < day) or (d == day and not claimable)
		local isToday = d == day and claimable
		card.BackgroundColor3 = isToday and Color3.fromRGB(34, 44, 30) or Color3.fromRGB(22, 24, 34)
		card.Ring.Color = isToday and GOLD or DAY_COLORS[d]
		card.Ring.Thickness = isToday and 6 or 4
		card.Status.Text = isToday and "READY!" or ""
		card.Status.TextColor3 = GOLD
		card.ClaimedDim.Visible = claimed
	end
	db.ClaimButton.BackgroundColor3 = claimable and GREEN or GRAY
	db.ClaimButton.Label.Text = claimable and "CLAIM" or "CLAIMED"
end

bounce(db.ClaimButton)
db.ClaimButton.Activated:Connect(function()
	local _, claimable = dailyState()
	if dailyBusy or not claimable then
		return
	end
	dailyBusy = true
	local ok, response = pcall(function()
		return claimDailyRemote:InvokeServer()
	end)
	dailyBusy = false
	if ok and response then
		if response.profile then
			profile = response.profile
		end
		flash(dailyPanel, response.message or "", response.success and GOLD or RED)
		refreshers.DailyPanel()
		updateCurrencies()
	end
end)

-- badge + countdown
task.spawn(function()
	while true do
		local _, claimable = dailyState()
		dailyButton.Badge.Visible = claimable
		if dailyPanel.Visible then
			if claimable then
				db.Timer.Text = ""
			else
				local left = 86400 - (workspace:GetServerTimeNow() % 86400)
				db.Timer.Text = "Next reward in " .. Config.FormatDuration(left)
			end
		end
		task.wait(1)
	end
end)

--------------------------------------------------------------------
-- layout: scale for the screen, top buttons next to Roblox's buttons
--------------------------------------------------------------------

local function layout()
	left.UIScale.Scale = uiScale()
end
layout()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

--------------------------------------------------------------------
-- live data
--------------------------------------------------------------------

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	updateCurrencies()
	if openPanel and refreshers[openPanel.Name] and openPanel.Name ~= "SettingsPanel" then
		refreshers[openPanel.Name]()
	end
end)

-- the cash also changes every second from income
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 30)
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Changed:Connect(function(v)
			if profile then
				profile.cash = v
			end
			updateCurrencies()
		end)
	end
end)

-- Active potions: tray in the bottom-right (above the jump button on
-- phones). Hover (or tap on mobile) a potion to see what it does.
local tray = Instance.new("Frame")
tray.Name = "BoostTray"
tray.AnchorPoint = Vector2.new(1, 1)
tray.Size = UDim2.fromOffset(420, 62)
tray.BackgroundTransparency = 1
tray.Parent = gui
local trayScale = Instance.new("UIScale")
trayScale.Parent = tray
local trayLayout = Instance.new("UIListLayout")
trayLayout.FillDirection = Enum.FillDirection.Horizontal
trayLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
trayLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
trayLayout.SortOrder = Enum.SortOrder.LayoutOrder
trayLayout.Padding = UDim.new(0, 8)
trayLayout.Parent = tray

-- info box for active potions / server effects (like the reference):
-- dark box, white rounded border, bold title, a thin line, then the
-- icon + the amount ("x2") in italics
local TIP_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local TIP_ITALIC = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local tip = Instance.new("Frame")
tip.Name = "BoostTip"
tip.AnchorPoint = Vector2.new(1, 1)
tip.Size = UDim2.fromOffset(260, 100)
tip.BackgroundColor3 = Color3.fromRGB(24, 25, 30)
tip.BackgroundTransparency = 0.05
tip.Visible = false
tip.ZIndex = 50
tip.Parent = gui
Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 14)
local tipStroke = Instance.new("UIStroke")
tipStroke.Color = Color3.fromRGB(225, 228, 235)
tipStroke.Thickness = 2.5
tipStroke.Parent = tip
local tipTitle = Instance.new("TextLabel")
tipTitle.Size = UDim2.new(1, -28, 0, 30)
tipTitle.Position = UDim2.fromOffset(14, 10)
tipTitle.BackgroundTransparency = 1
tipTitle.FontFace = TIP_FONT
tipTitle.TextScaled = true
tipTitle.TextColor3 = Color3.new(1, 1, 1)
tipTitle.TextStrokeTransparency = 0.4
tipTitle.TextXAlignment = Enum.TextXAlignment.Left
tipTitle.ZIndex = 51
tipTitle.Parent = tip
local tipLine = Instance.new("Frame")
tipLine.Size = UDim2.new(1, -28, 0, 3)
tipLine.Position = UDim2.fromOffset(14, 48)
tipLine.BorderSizePixel = 0
tipLine.BackgroundColor3 = Color3.fromRGB(200, 204, 214)
tipLine.ZIndex = 51
tipLine.Parent = tip
local lineGrad = Instance.new("UIGradient")
lineGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 0.9) })
lineGrad.Parent = tipLine
-- bottom row: icon + amount, centered
local tipRow = Instance.new("Frame")
tipRow.Size = UDim2.new(1, -20, 0, 30)
tipRow.Position = UDim2.fromOffset(10, 60)
tipRow.BackgroundTransparency = 1
tipRow.ZIndex = 51
tipRow.Parent = tip
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 8)
rowLayout.Parent = tipRow
local tipIcon = Instance.new("ImageLabel")
tipIcon.Size = UDim2.fromOffset(28, 28)
tipIcon.BackgroundTransparency = 1
tipIcon.ScaleType = Enum.ScaleType.Fit
tipIcon.ZIndex = 52
tipIcon.Parent = tipRow
local tipDot = Instance.new("Frame")
tipDot.Size = UDim2.fromOffset(20, 20)
tipDot.ZIndex = 52
tipDot.Parent = tipRow
Instance.new("UICorner", tipDot).CornerRadius = UDim.new(1, 0)
local tipDesc = Instance.new("TextLabel")
tipDesc.AutomaticSize = Enum.AutomaticSize.X
tipDesc.Size = UDim2.fromOffset(0, 26)
tipDesc.BackgroundTransparency = 1
tipDesc.FontFace = TIP_ITALIC
tipDesc.TextSize = 22
tipDesc.TextColor3 = Color3.new(1, 1, 1)
tipDesc.TextStrokeTransparency = 0.4
tipDesc.ZIndex = 52
tipDesc.Parent = tipRow

-- phones/tablets: at the very bottom-right, smaller, just LEFT of
-- Roblox's jump button (found on screen, so it never covers the
-- EGGS / PETS / WARP buttons or the jump button)
local function jumpButton()
	local tg = player.PlayerGui:FindFirstChild("TouchGui")
	local frame = tg and tg:FindFirstChild("TouchControlFrame")
	local jb = frame and frame:FindFirstChild("JumpButton")
	return (jb and jb.Visible and tg.Enabled) and jb or nil
end
local function trayBottom()
	return isTouch and -6 or -12
end
local function trayRight()
	if not isTouch then
		return -16
	end
	local jb = jumpButton()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if jb and v and jb.AbsoluteSize.X > 0 then
		local jumpBottom = jb.AbsolutePosition.Y + jb.AbsoluteSize.Y + game:GetService("GuiService"):GetGuiInset().Y
		if jumpBottom > v.Y - 70 then -- the jump button reaches the bottom: sit left of it
			return -(v.X - jb.AbsolutePosition.X) - 6
		end
	end
	return -8
end
local function placeTray()
	tray.Position = UDim2.new(1, trayRight(), 1, trayBottom())
	trayScale.Scale = isTouch and 0.58 or 1
end
task.spawn(function() -- the jump button can appear / move later
	while tray.Parent do
		placeTray()
		task.wait(1)
	end
end)
placeTray()

local boostItems = {}
local monsterFolderGB = game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG")
-- potions + timed gears (Speed Boots, Campfire) share the tray
local boostDefs = {}
for _, p in ipairs(Config.Potions) do
	table.insert(boostDefs, p)
end
for _, g in ipairs(Config.Gears or {}) do
	if g.boost then
		table.insert(boostDefs, g)
	end
end
local tipKey
local function showTip(potion)
	tipKey = potion.key
	tipTitle.Text = potion.name
	-- "x2" for server effects; the potion's short text otherwise
	tipDesc.Text = potion.amount or potion.text or ""
	tipDesc.TextSize = potion.amount and 24 or 16
	local img = potion.imageId or ""
	tipIcon.Image = img
	tipIcon.Visible = img ~= ""
	tipDot.Visible = img == ""
	local c = potion.color
	tipDot.BackgroundColor3 = typeof(c) == "Color3" and c or (type(c) == "table" and Color3.fromRGB(c[1], c[2], c[3])) or GOLD
	tip.Position = UDim2.new(1, trayRight(), 1, trayBottom() - 72 * trayScale.Scale)
	tip.Visible = true
end
local function hideTip(key)
	if tipKey == key then
		tip.Visible = false
		tipKey = nil
	end
end

task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		-- server-wide effects from the Dev (every server, everyone)
		for i, k in ipairs(Config.GlobalBoostKinds) do
			local id = "GB_" .. k.key
			local mult = Config.GlobalBoost(k.key, now)
			local item = boostItems[id]
			local color = Color3.fromRGB(k.color[1], k.color[2], k.color[3])
			if mult > 1 and not item then
				item = Instance.new("Frame")
				item.Name = "Boost_" .. id
				item.LayoutOrder = 100 + i
				item.Size = UDim2.fromOffset(44, 62)
				item.BackgroundTransparency = 1
				item.Parent = tray
				-- the icon is an image (Config.GlobalBoostKinds imageId); until
				-- an image id is set it shows as a plain coloured tile
				local btn = Instance.new("ImageButton")
				btn.Name = "Button"
				btn.Size = UDim2.fromOffset(44, 44)
				btn.BackgroundColor3 = (k.imageId ~= "" and Color3.new(0, 0, 0)) or color
				btn.BackgroundTransparency = k.imageId ~= "" and 0.35 or 0
				btn.Image = k.imageId or ""
				btn.ScaleType = Enum.ScaleType.Fit
				btn.AutoButtonColor = false
				btn.Parent = item
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
				local st = Instance.new("UIStroke")
				st.Color = Color3.fromRGB(10, 15, 35)
				st.Thickness = 2.5
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Parent = btn
				local timer = Instance.new("TextLabel")
				timer.Name = "Timer"
				timer.Size = UDim2.new(1, 8, 0, 16)
				timer.Position = UDim2.fromOffset(-4, 45)
				timer.BackgroundTransparency = 1
				timer.Font = Enum.Font.LuckiestGuy
				timer.TextSize = 15
				timer.TextColor3 = Color3.new(1, 1, 1)
				timer.TextStrokeTransparency = 0
				timer.Parent = item
				local function info()
					return {
						key = id,
						name = k.name .. " Event",
						amount = "x" .. tostring(Config.GlobalBoost(k.key, workspace:GetServerTimeNow())),
						imageId = k.imageId,
						color = k.color,
					}
				end
				btn.MouseEnter:Connect(function()
					showTip(info())
				end)
				btn.MouseLeave:Connect(function()
					hideTip(id)
				end)
				btn.Activated:Connect(function()
					if tipKey == id then
						hideTip(id)
					else
						showTip(info())
					end
				end)
				boostItems[id] = item
			elseif mult <= 1 and item then
				item:Destroy()
				boostItems[id] = nil
				hideTip(id)
			end
			if mult > 1 and item then
				item:SetAttribute("Tip", "Server " .. k.name .. " x" .. mult)
				item:SetAttribute("TipText", k.text)
				local left2 = math.max(0, math.ceil((monsterFolderGB:GetAttribute(id .. "_e") or now) - now))
				item.Timer.Text = left2 >= 3600 and string.format("%d:%02d:%02d", left2 // 3600, (left2 % 3600) // 60, left2 % 60) or string.format("%d:%02d", left2 // 60, left2 % 60)
			end
		end
		-- night + weather (Config.WorldEventAt): an icon like a potion, with
		-- the time left; hover (PC) or hold / tap (phone) for the info
		local ev = Config.WorldEventAt(now)
		for slot, e in ipairs({
			ev.night and { id = "EV_night", name = "Night", icon = "\u{1F319}", color = { 120, 140, 255 }, text = "Eggs grow 1.5x faster", ends = ev.nightEnds } or { id = "EV_night" },
			ev.weather and { id = "EV_weather", name = ev.weather.name, icon = ({ starfall = "\u{1F320}", golden = "\u{2600}", storm = "\u{26C8}", lucky = "\u{1F340}", rainbow = "\u{1F308}" })[ev.weather.key] or "\u{2728}", color = ev.weather.color, text = ev.weather.text, ends = ev.weatherEnds, wkey = ev.weather.key } or { id = "EV_weather" },
		}) do
			local item = boostItems[e.id]
			if item and e.ends and item:GetAttribute("WKey") ~= e.wkey then
				item:Destroy() -- a different weather: new icon
				boostItems[e.id] = nil
				item = nil
			end
			if e.ends and not item then
				item = Instance.new("Frame")
				item.Name = "Boost_" .. e.id
				item.LayoutOrder = 200 + slot
				item.Size = UDim2.fromOffset(44, 62)
				item.BackgroundTransparency = 1
				item:SetAttribute("WKey", e.wkey)
				item.Parent = tray
				local color = Color3.fromRGB(e.color[1], e.color[2], e.color[3])
				local btn = Instance.new("TextButton")
				btn.Name = "Button"
				btn.Size = UDim2.fromOffset(44, 44)
				btn.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45)
				btn.Text = e.icon
				btn.TextScaled = true
				btn.Font = Enum.Font.GothamBold
				btn.TextColor3 = Color3.new(1, 1, 1)
				btn.AutoButtonColor = false
				btn.Parent = item
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
				local st = Instance.new("UIStroke")
				st.Color = color
				st.Thickness = 2.5
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Parent = btn
				local pad = Instance.new("UIPadding")
				pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
				pad.Parent = btn
				local timer = Instance.new("TextLabel")
				timer.Name = "Timer"
				timer.Size = UDim2.new(1, 8, 0, 16)
				timer.Position = UDim2.fromOffset(-4, 45)
				timer.BackgroundTransparency = 1
				timer.Font = Enum.Font.LuckiestGuy
				timer.TextSize = 15
				timer.TextColor3 = Color3.new(1, 1, 1)
				timer.TextStrokeTransparency = 0
				timer.Parent = item
				local info = { key = e.id, name = e.name, text = e.text, color = e.color }
				btn.MouseEnter:Connect(function()
					showTip(info)
				end)
				btn.MouseLeave:Connect(function()
					hideTip(e.id)
				end)
				-- phones: hold to read, let go to hide (a quick tap toggles)
				btn.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch then
						showTip(info)
					end
				end)
				btn.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch then
						task.delay(1.5, function()
							hideTip(e.id)
						end)
					end
				end)
				boostItems[e.id] = item
			elseif not e.ends and item then
				item:Destroy()
				boostItems[e.id] = nil
				hideTip(e.id)
			end
			if e.ends and item then
				local left2 = math.max(0, math.ceil(e.ends - now))
				item.Timer.Text = string.format("%d:%02d", left2 // 60, left2 % 60)
			end
		end
		for i, potion in ipairs(boostDefs) do
			local ends = profile and profile.activeBoosts and profile.activeBoosts[potion.key]
			local active = ends and ends > now
			local item = boostItems[potion.key]
			if active and not item then
				item = Instance.new("Frame")
				item.Name = "Boost_" .. potion.key
				item.LayoutOrder = i
				item.Size = UDim2.fromOffset(44, 62)
				item.BackgroundTransparency = 1
				item.Parent = tray
				local btn = Instance.new("ImageButton")
				btn.Name = "Button"
				btn.Size = UDim2.fromOffset(44, 44)
				btn.BackgroundColor3 = Color3.new(0, 0, 0)
				btn.BackgroundTransparency = 0.35
				btn.Image = potion.imageId
				btn.ScaleType = Enum.ScaleType.Fit
				btn.AutoButtonColor = false
				btn.Parent = item
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
				local timer = Instance.new("TextLabel")
				timer.Name = "Timer"
				timer.Size = UDim2.new(1, 0, 0, 16)
				timer.Position = UDim2.fromOffset(0, 45)
				timer.BackgroundTransparency = 1
				timer.Font = Enum.Font.LuckiestGuy
				timer.TextSize = 15
				timer.TextColor3 = Color3.new(1, 1, 1)
				timer.TextStrokeTransparency = 0
				timer.Parent = item
				btn.MouseEnter:Connect(function()
					showTip(potion)
				end)
				btn.MouseLeave:Connect(function()
					hideTip(potion.key)
				end)
				btn.Activated:Connect(function()
					if tipKey == potion.key then
						hideTip(potion.key)
					else
						showTip(potion)
					end
				end)
				-- phones: holding shows the info too
				btn.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch then
						showTip(potion)
					end
				end)
				boostItems[potion.key] = item
			elseif not active and item then
				item:Destroy()
				boostItems[potion.key] = nil
				hideTip(potion.key)
			end
			if active and item then
				local left2 = math.ceil(ends - now)
				item.Timer.Text = string.format("%d:%02d", left2 // 60, left2 % 60)
			end
		end
		task.wait(0.5)
	end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeTray)
end

-- Hide HUD: slides the left menu, the EGGS/PETS/WARP dock and the
-- Backpack/Roll/Upgrade bar off the screen (and back). The eye gets a
-- red slash while hidden.
local hideButton = top:WaitForChild("HideButton")

-- while the HUD is hidden, rolls play as a mini animation at the top
updateMiniDice = function()
	player:SetAttribute("HudHidden", hudHiddenState == true)
end

local hudHidden = false
hudHiddenState = false
local slideTargets -- { object, shownPosition, hiddenPosition }
local function getSlideTargets()
	if slideTargets then
		return slideTargets
	end
	slideTargets = {}
	local function add(obj, hiddenPos)
		if obj then
			table.insert(slideTargets, { obj, obj.Position, hiddenPos })
		end
	end
	add(left, UDim2.new(0, -320, left.Position.Y.Scale, left.Position.Y.Offset))
	local pen = playerGui:FindFirstChild("PenPanel")
	local dock = pen and pen:FindFirstChild("Dock")
	if dock then
		add(dock, UDim2.new(1, 160, dock.Position.Y.Scale, dock.Position.Y.Offset))
	end
	local bottom = playerGui:FindFirstChild("BottomBar")
	local bar = bottom and bottom:FindFirstChild("Bar")
	if bar then
		add(bar, UDim2.new(bar.Position.X.Scale, bar.Position.X.Offset, 1, 320))
	end
	return slideTargets
end

local function setHudHidden(hidden)
	hudHidden = hidden
	hudHiddenState = hidden
	updateMiniDice()
	hideButton.Slash.Visible = hidden
	hideButton.Eye.BackgroundTransparency = hidden and 0.4 or 0
	for _, t in ipairs(getSlideTargets()) do
		TweenService:Create(t[1], TweenInfo.new(0.35, Enum.EasingStyle.Back, hidden and Enum.EasingDirection.In or Enum.EasingDirection.Out),
			{ Position = hidden and t[3] or t[2] }):Play()
	end
	tray.Visible = not hidden
	tip.Visible = false
	if hidden then
		closePanels()
	end
end

bounce(hideButton)
hideButton.Activated:Connect(function()
	setHudHidden(not hudHidden)
end)

closePanels()
updateCurrencies()
applyGraphics()
applySound()
applyPetVisibility()
