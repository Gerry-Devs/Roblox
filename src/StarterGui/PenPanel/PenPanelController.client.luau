local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local hatchRemote = remotes:WaitForChild("HatchEgg")
local unequipRemote = remotes:WaitForChild("UnequipMonster")
local usePotionRemote = remotes:WaitForChild("UsePotion")
local warpRemote = remotes:WaitForChild("Warp")
local closeAllBridge = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("CloseAll")
local equipBestRemote = remotes:WaitForChild("EquipBest")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")

--------------------------------------------------------------------
-- Pen panels (middle-right): EGGS shows incubating eggs with a live
-- timer bar and a HATCH button (works on mobile too); PETS shows the
-- monsters in your pen with their info and an UNEQUIP button.
-- Clicking an icon opens its panel and hides that icon; closing the
-- panel brings the icon back.
-- Icons: Dock.EggButton.Icon / Dock.MonsterButton.Icon (Image),
--        Templates.EggRow.Icon / MonsterRow.Icon for the row pictures.
--------------------------------------------------------------------

local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local eggButton = dock:WaitForChild("EggButton")
local monsterButton = dock:WaitForChild("MonsterButton")
local eggPanel = gui:WaitForChild("EggPanel")
local monsterPanel = gui:WaitForChild("MonsterPanel")
local warpButton = dock:WaitForChild("WarpButton")
local warpPanel = gui:WaitForChild("WarpPanel")
local templates = gui:WaitForChild("Templates")
local eggRowTemplate = templates:WaitForChild("EggRow")
local monsterRowTemplate = templates:WaitForChild("MonsterRow")
local warpRowTemplate = templates:WaitForChild("WarpRow")
-- each panel and the dock button that opens it
local panelButtons = { [eggPanel] = eggButton, [monsterPanel] = monsterButton, [warpPanel] = warpButton }

local RED = Color3.fromRGB(255, 110, 110)

local profile = profileRemote:InvokeServer()
local eggRows = {} -- { row, entry }

-- Badges only count NEW eggs placed / monsters equipped (or hatched)
-- since the panel was last opened. Opening the panel clears it.
local seen = { egg = {}, monster = {} }

local function markAllSeen(kind)
	for _, e in ipairs(profile.base or {}) do
		if e.kind == kind then
			seen[kind][e.uid] = true
		end
	end
end

local function updateBadges()
	for kind, button in pairs({ egg = eggButton, monster = monsterButton }) do
		local n = 0
		for _, e in ipairs(profile.base or {}) do
			if e.kind == kind and not seen[kind][e.uid] then
				n += 1
			end
		end
		button.Badge.Visible = n > 0
		button.Badge.Text.Text = tostring(n)
	end
end

-- whatever is already in the pen when you join isn't "new"
markAllSeen("egg")
markAllSeen("monster")
local hatching = {} -- uid -> true while the server is shaking it

local function colorFromTable(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

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

local function iconOrFallback(holder)
	local icon = holder:FindFirstChild("Icon")
	local fallback = holder:FindFirstChild("Fallback") or holder:FindFirstChild("Ball")
	if icon and fallback then
		icon.Visible = icon.Image ~= ""
		fallback.Visible = icon.Image == ""
	end
end

local function popIn(frame)
	local s = frame:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = 0.8 * (frame:GetAttribute("BaseScale") or 1)
		TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = frame:GetAttribute("BaseScale") or 1 }):Play()
	end
end

local function getRarityForEntry(entry)
	if entry.rarity then
		return Config.GetRarity(entry.rarity)
	end
	local monster = Config.GetMonster(entry.monsterId)
	return Config.GetRarity(monster and monster.rarity or "Common")
end

--------------------------------------------------------------------
-- Eggs
--------------------------------------------------------------------

local function clearRows(panel)
	for _, c in ipairs(panel.List:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
end

local lastEggKey, lastMonsterKey
-- identifies the set of eggs / monsters, so panels only redraw when it changes
local function listKey(kind)
	local ids = {}
	for _, e in ipairs(profile.base or {}) do
		if e.kind == kind then
			table.insert(ids, e.uid .. ":" .. tostring(e.level or 1) .. ":" .. tostring(e.defeated == true))
		end
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

-- eggs hatched with E (not the panel) are marked on their model in the pen
local function isHatchingInPen(uid)
	local base = workspace:FindFirstChild("MonsterRNGWorld")
	base = base and base:FindFirstChild("Base_" .. Players.LocalPlayer.UserId)
	local pets = base and base:FindFirstChild("Pets")
	local model = pets and pets:FindFirstChild(uid)
	return model ~= nil and model:GetAttribute("Hatching") == true
end

-- Robux: skip one egg's timer (the smallest product that covers the time left)
local function askEggSkip(uid)
	local ok, info = pcall(function()
		return remotes:WaitForChild("EggSkipTarget"):InvokeServer(uid)
	end)
	if not ok or type(info) ~= "table" or not info.productId then
		return
	end
	local left = math.max(0, math.floor(info.left or 0))
	monsterFolder:WaitForChild("ClientBridge"):WaitForChild("ConfirmPurchase"):Fire({
		kind = "product",
		id = info.productId,
		title = "Hatch Egg Now",
		fallback = "SKIP",
		image = Config.Products.eggSkipImageId,
		desc = "Skip this egg's timer and hatch it right away!\nTime left: " .. math.floor(left / 3600) .. "h " .. math.floor((left % 3600) / 60) .. "m",
		note = info.hours .. " HOUR SKIP",
	})
end

local function renderEggs()
	lastEggKey = listKey("egg")
	clearRows(eggPanel)
	eggRows = {}
	local eggs = {}
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind == "egg" then
			table.insert(eggs, entry)
		end
	end
	table.sort(eggs, function(a, b)
		return (a.readyAt or 0) < (b.readyAt or 0)
	end)
	eggPanel.Empty.Text = "No eggs incubating.\nEquip an egg and place it in your pen!"
	eggPanel.Empty.Size = UDim2.new(1, -40, 0, 60)
	eggPanel.Empty.Visible = #eggs == 0

	for i, entry in ipairs(eggs) do
		local rarity = getRarityForEntry(entry)
		local row = eggRowTemplate:Clone()
		row.Name = "Egg_" .. entry.uid
		row.LayoutOrder = i
		row.Visible = true
		row.ItemName.Text = rarity.name .. " Egg"
		row.ItemName.TextColor3 = colorFromTable(rarity.color)
		row.Ball.BackgroundColor3 = colorFromTable(rarity.color)
		iconOrFallback(row)
		local hatchButton = row.HatchButton
		bounce(hatchButton)
		hatchButton.Activated:Connect(function()
			if hatching[entry.uid] then
				return
			end
			if (entry.readyAt or 0) > serverNow() then
				askEggSkip(entry.uid)
				return
			end
			hatching[entry.uid] = true
			hatchButton.Visible = false
			row.Time.Text = "Hatching..."
			local ok, response = pcall(function()
				return hatchRemote:InvokeServer(entry.uid)
			end)
			if not ok or not response or not response.success then
				hatching[entry.uid] = nil
				row.Time.Text = (ok and response and response.message) or "Could not hatch."
				row.Time.TextColor3 = RED
			end
		end)
		row.Parent = eggPanel.List
		table.insert(eggRows, { row = row, entry = entry, total = Config.GetEggHatchDuration(entry) })
	end
end

local function updateEggTimers()
	local now = serverNow()

	if not eggPanel.Visible then
		return
	end
	for _, r in ipairs(eggRows) do
		-- Fast Growth: the egg really takes half the time, but the timer
		-- shows the normal hatch time counting down 2x faster (so it never
		-- starts half way)
		local realRemaining = (r.entry.readyAt or 0) - now
		local realTotal = (r.entry.placedAt and r.entry.readyAt and r.entry.readyAt > r.entry.placedAt) and (r.entry.readyAt - r.entry.placedAt) or r.total
		local speed = math.max(1, r.total / math.max(1, realTotal))
		local remaining = realRemaining > 0 and math.ceil(realRemaining * speed) or realRemaining
		local progress = math.clamp(1 - realRemaining / math.max(1, realTotal), 0, 1)
		r.row.Track.Fill.Size = UDim2.fromScale(progress, 1)
		if hatching[r.entry.uid] or isHatchingInPen(r.entry.uid) then
			r.row.HatchButton.Visible = false
			r.row.Time.Text = "Hatching..."
			r.row.Time.TextColor3 = Color3.fromRGB(255, 205, 93)
			r.row.Track.Fill.Size = UDim2.fromScale(1, 1)
		elseif remaining <= 0 then
			r.row.Time.Text = "READY!"
			r.row.Time.TextColor3 = Color3.fromRGB(120, 255, 140)
			r.row.HatchButton.Visible = true
			r.row.HatchButton.Label.Text = "HATCH"
		else
			r.row.Time.Text = Config.FormatDuration(remaining) .. " left"
			r.row.Time.TextColor3 = Color3.fromRGB(220, 235, 255)
			r.row.HatchButton.Visible = true
			r.row.HatchButton.Label.Text = "SKIP"
		end
	end
end

--------------------------------------------------------------------
-- Monsters in the pen
--------------------------------------------------------------------

local function renderMonsters()
	lastMonsterKey = listKey("monster")
	clearRows(monsterPanel)
	local list = {}
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind == "monster" then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return Config.GetEntryIncome(a) > Config.GetEntryIncome(b)
	end)
	local cap = Config.GetPenMonsterCap(profile.upgrades)
	monsterPanel.Title.Text.Text = string.format("PETS %d/%d", #list, cap)
	monsterPanel.Empty.Text = "No monsters in your pen."
	monsterPanel.Empty.Visible = #list == 0

	for i, entry in ipairs(list) do
		local monster = Config.GetMonster(entry.monsterId)
		local rarity = getRarityForEntry(entry)
		local row = monsterRowTemplate:Clone()
		row.Name = "Monster_" .. entry.uid
		row.LayoutOrder = i
		row.Visible = true
		row.ItemName.Text = Config.BuildDisplayName(monster and monster.name or "Monster", entry.size, entry.finish)
		row.ItemName.TextColor3 = colorFromTable(rarity.color)
		row.Ball.BackgroundColor3 = colorFromTable(rarity.color)
		row.Line1.Text = "$" .. Config.FormatNumber(Config.GetEntryIncome(entry)) .. "/s  \u{2022}  Lv. " .. (entry.level or 1)
		local hasPotion = ((profile.potions and profile.potions.revive) or 0) > 0
		local hasFeather = ((profile.gears and profile.gears.reviveFeather) or 0) > 0
		local canRevive = entry.defeated and (hasPotion or hasFeather)
		if entry.defeated then
			local backIn = math.max(0, (entry.defeatedAt or os.time()) + Config.GetReviveTime(entry.level) - workspace:GetServerTimeNow())
			row.Line1.Text = "DEFEATED  \u{2022}  back in " .. Config.FormatDuration(backIn)
			row.Line1.TextColor3 = Color3.fromRGB(255, 120, 120)
			row.Ball.BackgroundColor3 = Color3.fromRGB(95, 100, 115)
		end
		row.Line2.Text = Config.FormatOdds(Config.GetOdds(entry.monsterId, entry.size, entry.finish, entry.kg))
			.. "  \u{2022}  " .. Config.FormatKg(entry.kg)
		iconOrFallback(row)
		local unequip = row.UnequipButton
		bounce(unequip)
		if canRevive then
			unequip.Label.Text = "REVIVE"
			unequip.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		end
		unequip.Activated:Connect(function()
			if canRevive then
				local ok, r = pcall(function()
					if hasPotion then
						return usePotionRemote:InvokeServer("revive", entry.uid)
					end
					return remotes:WaitForChild("UseGear"):InvokeServer("reviveFeather")
				end)
				if ok and r and r.profile then
					profile = r.profile
				end
				renderMonsters()
				return
			end
			unequip.Visible = false
			local ok, response = pcall(function()
				return unequipRemote:InvokeServer(entry.uid)
			end)
			if ok and response and response.profile then
				profile = response.profile
			end
			if not ok or not response or not response.success then
				unequip.Visible = true
				row.Line2.Text = (ok and response and response.message) or "Could not unequip."
				row.Line2.TextColor3 = RED
			else
				renderMonsters()
			end
		end)
		row.Parent = monsterPanel.List
	end
end

--------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Warp: pen, shops, and every biome (unlocked ones only). Each warp
-- uses one Warp Remote (dropped by enemies).
--------------------------------------------------------------------

local closePanel

local function renderWarp()
	clearRows(warpPanel)
	local count = (profile.items and profile.items.warpRemote) or 0
	warpPanel.Count.Amount.Text = "x" .. count .. " Warp Remote" .. (count == 1 and "" or "s")
	warpPanel.Empty.Visible = false

	local spots = {
		{ key = "pen", name = "My Pen", sub = "Your monsters + eggs", color = Color3.fromRGB(255, 200, 60) },
		{ key = "shop", name = "Shops", sub = "Sell Shop + Dice Shop", color = Color3.fromRGB(255, 120, 180) },
	}
	for _, b in ipairs(Config.Biomes) do
		if b.cost then
			table.insert(spots, { key = b.key, name = b.name, sub = b.subtitle, color = Color3.fromRGB(b.color[1], b.color[2], b.color[3]), biome = true })
		end
	end

	for i, spot in ipairs(spots) do
		local unlocked = not spot.biome or (profile.unlockedBiomes and profile.unlockedBiomes[spot.key])
		local row = warpRowTemplate:Clone()
		row.Name = "Warp_" .. spot.key
		row.LayoutOrder = i
		row.Visible = true
		row.ItemName.Text = spot.name
		row.ItemName.TextColor3 = spot.color
		row.Ball.BackgroundColor3 = spot.color
		row.Line1.Text = unlocked and spot.sub or "Locked"
		row.Line1.TextColor3 = unlocked and Color3.fromRGB(220, 235, 255) or Color3.fromRGB(255, 130, 130)
		iconOrFallback(row)
		local btn = row.WarpButton
		local canWarp = unlocked and count > 0
		btn.Label.Text = unlocked and "WARP" or "LOCKED"
		btn.BackgroundColor3 = canWarp and Color3.fromRGB(80, 200, 220) or Color3.fromRGB(110, 120, 145)
		bounce(btn)
		btn.Activated:Connect(function()
			if not unlocked then
				return
			end
			if count <= 0 then
				row.Line1.Text = "Buy Warp Remotes at the Gear Shop!"
				row.Line1.TextColor3 = RED
				return
			end
			local ok, r = pcall(function()
				return warpRemote:InvokeServer(spot.key)
			end)
			if ok and r and r.success then
				profile = r.profile or profile
				closePanel(warpPanel)
			else
				row.Line1.Text = (ok and r and r.message) or "Can't warp right now."
				row.Line1.TextColor3 = RED
			end
		end)
		row.Parent = warpPanel.List
	end
end

closePanel = function(panel)
	panel.Visible = false
	local b = panelButtons[panel]
	if b then
		b.Visible = true
	end
end

local function openPanel(panel)
	if panel.Visible then
		closePanel(panel) -- tapping the button again closes it
		return
	end
	closeAllBridge:Fire("pen") -- close the backpack, shops, menus...
	for p in pairs(panelButtons) do
		if p ~= panel and p.Visible then
			closePanel(p)
		end
	end
	if panel == eggPanel then
		markAllSeen("egg")
		renderEggs()
	elseif panel == monsterPanel then
		markAllSeen("monster")
		renderMonsters()
	else
		renderWarp()
	end
	updateBadges()
	panel.Visible = true -- the EGGS / PETS / WARP buttons stay visible
	updateEggTimers()
	popIn(panel)
end

warpButton.Activated:Connect(function()
	openPanel(warpPanel)
end)

-- another window opened: close these panels
closeAllBridge.Event:Connect(function(except)
	if except ~= "pen" then
		for p in pairs(panelButtons) do
			if p.Visible then
				closePanel(p)
			end
		end
	end
end)

-- EQUIP BEST: highest cash/s monsters go into the pen, the rest to the backpack
local equipBestButton = monsterPanel:WaitForChild("EquipBestButton")
local equipBusy = false
bounce(equipBestButton)
equipBestButton.Activated:Connect(function()
	if equipBusy then
		return
	end
	equipBusy = true
	local ok, r = pcall(function()
		return equipBestRemote:InvokeServer()
	end)
	equipBusy = false
	if ok and r then
		if r.profile then
			profile = r.profile
		end
		renderMonsters()
		monsterFolder:WaitForChild("ClientBridge"):WaitForChild("Notify"):Fire(r.message or "", r.success and Color3.fromRGB(255, 205, 93) or RED)
	end
end)

-- HATCH ALL: every READY egg hatches for free; if some are still
-- incubating, offer the Hatch All product (Robux) for the rest
local hatchAllButton = eggPanel:WaitForChild("HatchAllButton")
local hatchAllBusy = false
bounce(hatchAllButton)
hatchAllButton.Activated:Connect(function()
	if hatchAllBusy then
		return
	end
	hatchAllBusy = true
	local ok, r = pcall(function()
		return remotes:WaitForChild("HatchAll"):InvokeServer()
	end)
	hatchAllBusy = false
	if not ok or type(r) ~= "table" then
		return
	end
	local notify = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("Notify")
	if (r.hatched or 0) > 0 then
		notify:Fire("Hatching " .. r.hatched .. " egg" .. (r.hatched == 1 and "" or "s") .. "!", Color3.fromRGB(120, 255, 140))
	end
	if (r.waiting or 0) > 0 then
		monsterFolder:WaitForChild("ClientBridge"):WaitForChild("ConfirmPurchase"):Fire({
			kind = "product",
			id = Config.Products.hatchAll.id,
			title = "Hatch All",
			fallback = "ALL",
			image = Config.Products.hatchAll.imageId,
			desc = r.waiting .. " egg" .. (r.waiting == 1 and " is" or "s are") .. " still incubating.\nHatch every egg in your pen right now!",
			note = "HATCHES " .. r.waiting .. " EGG" .. (r.waiting == 1 and "" or "S"),
		})
	elseif (r.hatched or 0) == 0 then
		notify:Fire("No eggs in your pen.", RED)
	end
end)

eggButton.Activated:Connect(function()
	openPanel(eggPanel)
end)
monsterButton.Activated:Connect(function()
	openPanel(monsterPanel)
end)
for _, p in ipairs({ eggPanel, monsterPanel, warpPanel }) do
	local closeButton = p.CloseButton
	bounce(closeButton)
	if closeButton.Icon.Image ~= "" then
		closeButton.Label.Visible = false
	end
	closeButton.Activated:Connect(function()
		closePanel(p)
	end)
end
for _, b in ipairs({ eggButton, monsterButton, warpButton }) do
	iconOrFallback(b)
	bounce(b)
end

--------------------------------------------------------------------
-- Live data + scaling
--------------------------------------------------------------------

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	-- eggs that finished hatching are no longer eggs in the pen
	local stillEggs = {}
	for _, e in ipairs(profile.base or {}) do
		if e.kind == "egg" then
			stillEggs[e.uid] = true
		end
	end
	for uid in pairs(hatching) do
		if not stillEggs[uid] then
			hatching[uid] = nil
		end
	end
	-- only redraw when eggs / monsters were added or removed (no flicker)
	if eggPanel.Visible and listKey("egg") ~= lastEggKey then
		renderEggs()
	end
	if monsterPanel.Visible and listKey("monster") ~= lastMonsterKey then
		renderMonsters()
	end
	if warpPanel.Visible then
		renderWarp()
	end
	-- an open panel shows everything, so nothing in it counts as new
	if eggPanel.Visible then
		markAllSeen("egg")
	end
	if monsterPanel.Visible then
		markAllSeen("monster")
	end
	updateBadges()
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator >= 0.05 then
		accumulator = 0
		updateEggTimers()
	end
end)

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- phones: never shrink below a comfortable tap size
	local isTouch = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
	local s = math.clamp(camera.ViewportSize.Y / 720, isTouch and 0.62 or 0.6, 1)
	local DOCK_SCALE = 0.72 -- size of the EGGS / PETS buttons
	local PANEL_SCALE = 0.8 -- size of the info panels
	dock:SetAttribute("BaseScale", s * DOCK_SCALE)
	dock.UIScale.Scale = s * DOCK_SCALE
	for _, p in ipairs({ eggPanel, monsterPanel, warpPanel }) do
		p:SetAttribute("BaseScale", s * PANEL_SCALE)
		p.UIScale.Scale = s * PANEL_SCALE
		-- keep the panels just left of the (scaled) dock
		p.Position = UDim2.new(1, -14 - 98 * s * DOCK_SCALE, 0.5, 0)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

eggPanel.Visible = false
monsterPanel.Visible = false
warpPanel.Visible = false
renderMonsters()
updateEggTimers()
updateBadges()
