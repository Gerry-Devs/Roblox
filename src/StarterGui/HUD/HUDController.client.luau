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
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local claimDailyRemote = remotes:WaitForChild("ClaimDaily")
local saveSettingsRemote = remotes:WaitForChild("SaveSettings")
local closeAllBridge = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("CloseAll")

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
	return math.clamp(math.min(v.Y / 720, v.X / 1100), 0.55, 1) * (isTouch and 1.05 or 1)
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
	return math.floor(total * (profile.incomeBoost or 1) * cashUpgrade * rebirth * potion * Config.PassCashMultiplier(profile) * Config.GlobalBoost("income", workspace:GetServerTimeNow()))
end

local function updateCurrencies()
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

local function getMonsterIcon(monsterId)
	local bp = playerGui:FindFirstChild("Backpack")
	local icons = bp and bp:FindFirstChild("ItemIcons")
	local v = icons and icons:FindFirstChild(monsterId)
	return v and v.Value or ""
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

	local list = table.clone(Config.Monsters)
	table.sort(list, function(a, b)
		local ta, tb = Config.GetRarity(a.rarity).tier, Config.GetRarity(b.rarity).tier
		if ta ~= tb then
			return ta < tb
		end
		return a.name < b.name
	end)
	local found = 0
	for i, monster in ipairs(list) do
		local count
		if indexTab == "pets" then
			count = profile and profile.owned and profile.owned[monster.id]
		else
			count = profile and profile.enemyKills and profile.enemyKills[monster.id]
		end
		local discovered = count ~= nil
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
		card.ItemName.Text = discovered and monster.name or "???"
		if discovered then
			card.Info.Text = indexTab == "pets" and (rarity.name:upper()) or ("Defeated " .. Config.FormatNumber(count))
		else
			card.Info.Text = rarity.name:upper()
		end
		card.Parent = grid
	end
	indexBody.Counter.Text = found .. "/" .. #list .. " found"
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
	rb.Current.Text = string.format("Now: +%d%% cash  \u{2022}  +%d%% luck", n * R.cashBonus, n * R.luckBonus)
	rb.Next.Text = string.format("After: +%d%% cash  \u{2022}  +%d%% luck", (n + 1) * R.cashBonus, (n + 1) * R.luckBonus)
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

local function styleToggle(rowName, on)
	local t = sb[rowName].Options.Toggle
	t.BackgroundColor3 = on and GREEN or Color3.fromRGB(235, 70, 80)
	t.Label.Text = on and "ON" or "OFF"
end

refreshers.SettingsPanel = function()
	for _, q in ipairs(Config.Graphics.order) do
		local b = sb.Graphics.Options:FindFirstChild(q)
		if b then
			b.BackgroundColor3 = settings.graphics == q and GOLD or BLUE
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

refreshers.DailyPanel = function()
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
		card.BackgroundColor3 = isToday and Color3.fromRGB(60, 120, 60) or NAVY
		card.Ring.Color = isToday and GOLD or Color3.fromRGB(10, 15, 35)
		card.Ring.Thickness = isToday and 4 or 3
		card.Status.Text = claimed and "CLAIMED" or (isToday and "READY!" or "")
		card.Status.TextColor3 = claimed and Color3.fromRGB(140, 255, 150) or GOLD
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

local tip = Instance.new("Frame")
tip.Name = "BoostTip"
tip.AnchorPoint = Vector2.new(1, 1)
tip.Size = UDim2.fromOffset(220, 56)
tip.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
tip.BackgroundTransparency = 0.08
tip.Visible = false
tip.Parent = gui
Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 12)
local tipStroke = Instance.new("UIStroke")
tipStroke.Color = Color3.fromRGB(10, 15, 35)
tipStroke.Thickness = 3
tipStroke.Parent = tip
local tipTitle = Instance.new("TextLabel")
tipTitle.Size = UDim2.new(1, -16, 0, 24)
tipTitle.Position = UDim2.fromOffset(8, 4)
tipTitle.BackgroundTransparency = 1
tipTitle.Font = Enum.Font.LuckiestGuy
tipTitle.TextSize = 18
tipTitle.TextColor3 = GOLD
tipTitle.TextXAlignment = Enum.TextXAlignment.Left
tipTitle.Parent = tip
local tipDesc = tipTitle:Clone()
tipDesc.Position = UDim2.fromOffset(8, 28)
tipDesc.TextSize = 14
tipDesc.TextColor3 = Color3.new(1, 1, 1)
tipDesc.Size = UDim2.new(1, -16, 0, 20)
tipDesc.TextScaled = true
tipDesc.Parent = tip

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
	tipDesc.Text = potion.text
	tip.Position = UDim2.new(1, trayRight(), 1, trayBottom() - 68 * trayScale.Scale)
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
					return { key = id, name = item:GetAttribute("Tip") or k.name, text = item:GetAttribute("TipText") or k.text }
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
