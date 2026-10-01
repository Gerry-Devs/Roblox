local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
-- the studded look; if the style module is missing or breaks, the
-- backpack still works in its plain look (never blocks opening)
local UIStyle
do
	local mod = monsterFolder:WaitForChild("UIStyle", 5)
	local ok, res = pcall(function()
		return mod and require(mod)
	end)
	if ok and res then
		UIStyle = res
	else
		warn("Backpack: UIStyle module missing, using the plain look")
		local noop = function(f)
			return f
		end
		UIStyle = { OUTLINE = Color3.fromRGB(10, 12, 22), BODY = Color3.fromRGB(40, 44, 58), BODY_DARK = Color3.fromRGB(28, 31, 42), RIM = Color3.fromRGB(185, 192, 210), studs = noop, brick = noop, closeButton = noop, rarityCard = function(card, color)
			card.BackgroundColor3 = color
			return card
		end }
	end
end
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local sellEggRemote = remotes:WaitForChild("SellEgg")
local sellAllEggsRemote = remotes:WaitForChild("SellAllEggs")
local sellMonsterRemote = remotes:WaitForChild("SellMonster")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local toggleFavoriteRemote = remotes:WaitForChild("ToggleFavorite")
local usePotionRemote = remotes:WaitForChild("UsePotion")
local useGearRemote = remotes:WaitForChild("UseGear")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local openBridge = bridge:WaitForChild("OpenBackpack")
local closeBridge = bridge:WaitForChild("CloseBackpack")
local startHoldingBridge = bridge:WaitForChild("StartHolding")

local profile = profileRemote:InvokeServer()

--------------------------------------------------------------------
-- Drives the cartoony Backpack ScreenGui. Everything visual lives in
-- StarterGui.Backpack and can be restyled in Studio:
--   • Any button's icon:   <button>.Icon.Image  (blank = text only)
--   • Title icon:          Main.Title.Icon.Image
--   • Item/egg icons:      ItemIcons.<monsterId> / ItemIcons.Egg_<Rarity>
--                          (StringValue.Value = "rbxassetid://...")
--   • Card look:           Templates.SlotTemplate / Templates.EmptyTemplate
--------------------------------------------------------------------

local gui = script.Parent
local main = gui:WaitForChild("Main")
local mainScale = main:WaitForChild("UIScale")
local grid = main:WaitForChild("Content"):WaitForChild("Grid")
local tabs = main:WaitForChild("Tabs")
local search = main:WaitForChild("Search")
local countText = main:WaitForChild("Count"):WaitForChild("Text")
local closeButton = main:WaitForChild("CloseButton")
-- the Backpack styles its own header: tell CloseButtonFixer right away
-- (if it skins this window too, there are two headers = doubled studs)
closeButton:SetAttribute("KeepPlace", true)
main:SetAttribute("NoSkin", true)
local sortButton = main:WaitForChild("SortButton")
local templates = gui:WaitForChild("Templates")
local slotTemplate = templates:WaitForChild("SlotTemplate")
local emptyTemplate = templates:WaitForChild("EmptyTemplate")
local itemIcons = gui:WaitForChild("ItemIcons")

local BLUE = Color3.fromRGB(60, 160, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(111, 220, 162)

local activeTab = "Egg"
local sortDescending = true
local renderGrid

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------

local function colorFromTable(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- If a button has no icon image, hide the icon and center its label;
-- if it has one, show it and shift the label over.
local function layoutIconButton(button, leftAligned)
	local icon = button:FindFirstChild("Icon")
	local label = button:FindFirstChild("Label")
	if not icon or not label then
		return
	end
	local hasIcon = icon.Image ~= ""
	icon.Visible = hasIcon
	if leftAligned then
		label.Position = UDim2.new(0, hasIcon and 52 or 14, 0.5, 0)
		label.Size = UDim2.new(1, hasIcon and -60 or -24, 0.6, 0)
	elseif hasIcon and label.Text ~= "" then
		local iconWidth = icon.AbsoluteSize.X + 8
		label.Position = UDim2.new(0.5, iconWidth / 2, 0.5, 0)
		label.Size = UDim2.new(1, -16 - iconWidth, label.Size.Y.Scale, 0)
	end
end

local function bounce(button)
	local s = button:FindFirstChildOfClass("UIScale")
	if not s then
		return
	end
	button.MouseEnter:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
	end)
end

local function toast(message, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(420, 28)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -44)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
	label.ZIndex = 20
	label.Parent = main
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, -52) }):Play()
	task.delay(1.8, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.35)
		label:Destroy()
	end)
end

local function getRarity(kind, item)
	if kind == "egg" then
		return Config.GetRarity(item.rarity)
	end
	local monster = Config.GetMonster(item.monsterId)
	return Config.GetRarity(monster and monster.rarity or "Common")
end

local function getDisplayName(kind, item)
	if kind == "egg" then
		return getRarity(kind, item).name .. " Egg"
	end
	local monster = Config.GetMonster(item.monsterId)
	return monster and Config.BuildDisplayName(monster.name, item.size, item.finish) or "Monster"
end

local function getIconImage(kind, item)
	if kind == "egg" and Config.EggIcons and Config.EggIcons[tostring(item.rarity)] then
		return Config.EggIcons[tostring(item.rarity)]
	end
	local key = kind == "egg" and ("Egg_" .. tostring(item.rarity)) or item.monsterId
	local value = itemIcons:FindFirstChild(key)
	return value and value.Value or ""
end

local function darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

--------------------------------------------------------------------
-- Info popup: monster / egg cards only show their picture; tap one to
-- see everything about it (and EQUIP / PLACE it from here)
--------------------------------------------------------------------
local OUTLINE = Color3.fromRGB(10, 15, 35)
local popup = Instance.new("Frame")
popup.Name = "InfoPopup"
popup.Size = UDim2.fromOffset(230, 0)
popup.AutomaticSize = Enum.AutomaticSize.Y
popup.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
popup.BackgroundTransparency = 0.08
popup.Visible = false
popup.ZIndex = 30
popup.Parent = main
Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 12)
local popStroke = Instance.new("UIStroke")
popStroke.Color = Color3.fromRGB(70, 70, 80)
popStroke.Thickness = 2
popStroke.Parent = popup
local popList = Instance.new("UIListLayout")
popList.HorizontalAlignment = Enum.HorizontalAlignment.Center
popList.SortOrder = Enum.SortOrder.LayoutOrder
popList.Padding = UDim.new(0, 6)
popList.Parent = popup
local popPad = Instance.new("UIPadding")
popPad.PaddingTop, popPad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
popPad.PaddingLeft, popPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
popPad.Parent = popup
-- its own scale on top of the window's: the window gets small on phones,
-- the info should stay easy to read
local popScale = Instance.new("UIScale")
popScale.Name = "PopScale"
popScale.Parent = popup
local popupFor
local function closePopup()
	popup.Visible = false
	popupFor = nil
end
local function popLine(order, text, size, color, font, align, italic)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.BackgroundTransparency = 1
	l.RichText = true
	l.Text = text
	l.TextSize = size
	l.Font = font or Enum.Font.GothamBold
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = OUTLINE
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.TextWrapped = true
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.ZIndex = 31
	if italic then
		l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
	end
	l.Parent = popup
	return l
end
local function popDivider(order)
	local d = Instance.new("Frame")
	d.LayoutOrder = order
	d.Size = UDim2.new(1, 0, 0, 2)
	d.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	d.BorderSizePixel = 0
	d.ZIndex = 31
	d.Parent = popup
end
local function showPopup(kind, item, card, rarity, rarityColor, odds)
	if popupFor == item.uid and popup.Visible then
		closePopup()
		return
	end
	for _, c in ipairs(popup:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	popupFor = item.uid
	local o = 0
	local function nxt()
		o += 1
		return o
	end
	popLine(nxt(), getDisplayName(kind, item), 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
	popLine(nxt(), rarity.name, 14, rarityColor:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	popDivider(nxt())
	if kind == "egg" then
		popLine(nxt(), "Egg", 18, Color3.new(1, 1, 1), nil, nil, true)
		popLine(nxt(), "Hatch: " .. Config.FormatDuration(Config.GetEggHatchDuration(item)), 16, Color3.fromRGB(200, 220, 255), nil, nil, true)
	else
		popLine(nxt(), "Level " .. (item.level or 1), 18, Color3.new(1, 1, 1), nil, nil, true)
		if item.finish and item.finish ~= "Normal" then
			popLine(nxt(), item.finish, 17, Color3.fromRGB(255, 215, 110), nil, nil, true)
		end
		if item.size and item.size ~= "Normal" then
			popLine(nxt(), "Size: " .. item.size, 16, Color3.fromRGB(190, 150, 255), nil, nil, true)
		end
		if item.kg then
			popLine(nxt(), Config.FormatKg(item.kg), 15, Color3.fromRGB(200, 200, 210), nil, nil, true)
		end
		popDivider(nxt())
		popLine(nxt(), "\240\159\146\181 $" .. Config.FormatNumber(Config.GetEntryIncome(item)) .. "/s", 18, Color3.fromRGB(150, 255, 150), nil, nil, true)
		-- its skill (works while it's equipped in your pen)
		local sk, v = Config.GetEntrySkill(item)
		if sk then
			popDivider(nxt())
			popLine(nxt(), "\u{2B50} " .. sk.name, 17, Color3.fromRGB(255, 215, 90), Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
			popLine(nxt(), Config.FormatSkill(sk.stat, v), 16, Color3.fromRGB(255, 240, 190), nil, nil, true)
		end
	end
	popDivider(nxt())
	popLine(nxt(), Config.FormatOdds(odds), 18, Color3.new(1, 1, 1), nil, nil, true)
	-- EQUIP / PLACE
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = nxt()
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = GREEN
	btn.Text = kind == "egg" and "PLACE" or "EQUIP"
	btn.Font = Enum.Font.LuckiestGuy
	btn.TextSize = 20
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextStrokeTransparency = 0
	btn.TextStrokeColor3 = OUTLINE
	btn.ZIndex = 32
	btn.Parent = popup
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	btn.Activated:Connect(function()
		closePopup()
		main.Visible = false
		startHoldingBridge:Fire(kind, item.uid, rarityColor)
	end)
	-- place it next to the card, inside the backpack window
	popup.Visible = true
	task.defer(function()
		local scale = mainScale.Scale > 0 and mainScale.Scale or 1
		local camera = workspace.CurrentCamera
		local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local inset = game:GetService("GuiService"):GetGuiInset().Y
		-- size of the popup at scale 1
		local cur = scale * popScale.Scale
		local baseW, baseH = popup.AbsoluteSize.X / cur, popup.AbsoluteSize.Y / cur
		-- phones: close to full size; computers: a bit bigger than the window
		local want = vp.Y < 500 and math.max(0.85, scale * 1.3) or scale * 1.15
		-- never taller than the screen
		local eff = math.min(want, (vp.Y - inset - 16) / math.max(baseH, 1))
		popScale.Scale = math.max(eff / scale, 1)
		eff = scale * popScale.Scale
		local pw, ph = baseW * eff, baseH * eff
		local mainPos, mainSize = main.AbsolutePosition, main.AbsoluteSize
		local cp, cs = card.AbsolutePosition, card.AbsoluteSize
		local x = cp.X + cs.X + 8
		if x + pw > mainPos.X + mainSize.X then
			x = cp.X - pw - 8
		end
		x = math.clamp(x, 8, math.max(8, vp.X - pw - 8))
		-- next to the card, kept on the screen
		local y = math.clamp(cp.Y, 8, math.max(8, vp.Y - inset - ph - 8))
		popup.Position = UDim2.fromOffset((x - mainPos.X) / scale, (y - mainPos.Y) / scale)
	end)
end

--------------------------------------------------------------------
-- Cards
--------------------------------------------------------------------

local function createCard(kind, item, order)
	local toggleFavorite
	local rarity = getRarity(kind, item)
	local rarityColor = colorFromTable(rarity.color)
	local card = slotTemplate:Clone()
	card.Name = "Item_" .. tostring(item.uid)
	card.LayoutOrder = order
	card.Visible = true
	pcall(UIStyle.rarityCard, card, rarityColor)

	card.ItemName.Text = getDisplayName(kind, item)
	-- rarity + odds, then $/s + level (monsters) or hatch time (eggs)
	local odds
	if kind == "egg" then
		local total = 0
		for _, r in ipairs(Config.Rarities) do
			total += r.weight
		end
		odds = math.max(1, math.floor(total / rarity.weight + 0.5))
		local secs = Config.GetEggHatchDuration(item)
		card.Stats.Text = "Hatch: " .. Config.FormatDuration(secs)
	else
		odds = Config.GetOdds(item.monsterId, item.size, item.finish, item.kg)
		card.Stats.Text = Config.FormatKg(item.kg) .. "  " .. "$" .. Config.FormatNumber(Config.GetEntryIncome(item)) .. "/s  \226\128\162  Lv. " .. (item.level or 1)
	end
	card.Rarity.Text = rarity.name:upper() .. "  \226\128\162  " .. Config.FormatOdds(odds)
	card.Rarity.TextColor3 = rarity.tier >= 3 and Color3.new(1, 1, 1) or darker(rarityColor, 0.1):Lerp(Color3.new(1, 1, 1), 0.7)

	local image = getIconImage(kind, item)
	card.Icon.Image = image
	card.Icon.Visible = image ~= ""
	card.Fallback.Visible = image == ""
	card.Fallback.BackgroundColor3 = darker(rarityColor, 0.35)
	-- level in the corner (like the "x15" counts)
	if kind == "monster" then
		local lv = Instance.new("TextLabel")
		lv.Name = "Corner"
		lv.AnchorPoint = Vector2.new(1, 1)
		lv.Position = UDim2.new(1, -6, 1, -4)
		lv.Size = UDim2.new(0.6, 0, 0.2, 0)
		lv.BackgroundTransparency = 1
		lv.Font = Enum.Font.LuckiestGuy
		lv.Text = "Lv" .. (item.level or 1)
		lv.TextScaled = true
		lv.TextXAlignment = Enum.TextXAlignment.Right
		lv.TextColor3 = Color3.new(1, 1, 1)
		lv.TextStrokeTransparency = 0
		lv.TextStrokeColor3 = UIStyle.OUTLINE
		lv.ZIndex = 6
		lv.Parent = card
	end
	card.Fallback.UICorner.CornerRadius = kind == "egg" and UDim.new(1, 0) or UDim.new(0, 14)
	card.Fallback.Letter.Text = kind == "egg" and "EGG" or string.sub(card.ItemName.Text, 1, 1)

	-- picture-only card: no text, no button; the picture fills the card.
	-- Optional card art behind it: ItemIcons.CardBackground (image id)
	card.ItemName.Visible = false
	card.Rarity.Visible = false
	card.Stats.Visible = false
	card.EquipButton.Visible = false
	card.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Icon.Position = UDim2.fromScale(0.5, 0.5)
	card.Icon.Size = UDim2.new(1, -14, 1, -14)
	card.Icon.ScaleType = Enum.ScaleType.Fit
	card.Fallback.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Fallback.Position = UDim2.fromScale(0.5, 0.5)
	card.Fallback.Size = UDim2.new(0.8, 0, 0.8, 0)
	card.Fallback.SizeConstraint = Enum.SizeConstraint.RelativeXX
	local bgValue = itemIcons:FindFirstChild("CardBackground")
	if bgValue and bgValue.Value ~= "" then
		local bg = Instance.new("ImageLabel")
		bg.Name = "CardArt"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundTransparency = 1
		bg.Image = bgValue.Value
		bg.ScaleType = Enum.ScaleType.Crop
		bg.ZIndex = 2
		bg.Parent = card
		Instance.new("UICorner", bg).CornerRadius = card.UICorner.CornerRadius
	end
	local hit = Instance.new("TextButton")
	hit.Name = "Open"
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 5
	hit.Parent = card
	local heldFavorite = false -- a long-press just favorited: that release isn't a tap
	hit.Activated:Connect(function()
		if heldFavorite then
			heldFavorite = false
			return
		end
		showPopup(kind, item, card, rarity, rarityColor, odds)
	end)

	-- Favorites: right-click (PC) or press and hold (mobile, taps never favorite). Favorites
	-- are never sold by the Sell stall's sell-all options.
	local favBadge = card:FindFirstChild("Favorite")
	if favBadge then
		favBadge.Visible = item.favorite == true
		local favIcon = favBadge:FindFirstChild("Icon")
		local favStar = favBadge:FindFirstChild("Star")
		if favIcon and favStar then
			favIcon.Visible = favIcon.Image ~= ""
			favStar.Visible = favIcon.Image == ""
		end
	end

	toggleFavorite = function()
		local response = toggleFavoriteRemote:InvokeServer(item.uid)
		if response and response.success then
			profile = response.profile or profile
			toast(response.favorite and "\226\152\133 Added to favorites" or "Removed from favorites", GOLD)
			renderGrid()
		end
	end

	local pressToken, pressStart
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- right-click only with a real mouse (phones never favorite on taps)
			toggleFavorite()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			heldFavorite = false
			local token = {}
			pressToken = token
			pressStart = input.Position
			task.delay(0.5, function()
				if pressToken == token then
					pressToken = nil
					heldFavorite = true
					toggleFavorite()
				end
			end)
		end
	end)
	hit.InputChanged:Connect(function(input)
		-- scrolling the grid cancels the long-press
		if pressToken and input.UserInputType == Enum.UserInputType.Touch and pressStart
			and (input.Position - pressStart).Magnitude > 12 then
			pressToken = nil
		end
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			pressToken = nil
		end
	end)

	card.Parent = grid
end

local function sortedFiltered(list, kind)
	local needle = search.Text:lower()
	local out = {}
	local tiers = {}
	for _, item in ipairs(list) do
		if needle == "" or string.find(getDisplayName(kind, item):lower(), needle, 1, true) then
			table.insert(out, item)
			tiers[item] = getRarity(kind, item).tier
		end
	end
	table.sort(out, function(a, b)
		if (a.favorite == true) ~= (b.favorite == true) then
			return a.favorite == true
		end
		local ta, tb = tiers[a], tiers[b]
		if sortDescending then
			return ta > tb
		end
		return ta < tb
	end)
	return out
end

local function updateCount()
	local n = #(profile.eggs or {}) + #(profile.monsters or {})
	local cap = Config.GetBackpackCap(profile.upgrades)
	countText.Text = string.format("%d/%d", n, cap)
	countText.TextColor3 = n >= cap and RED or Color3.new(1, 1, 1)
end

-- POTIONS and ITEMS tabs: potions have a USE button; items are shown
-- with their count (Warp Remotes are used from the WARP menu).
local POTION_COLORS = {
	luck = Color3.fromRGB(90, 200, 100),
	health = Color3.fromRGB(235, 80, 100),
	damage = Color3.fromRGB(255, 140, 50),
	cash = Color3.fromRGB(70, 190, 140),
	level = Color3.fromRGB(110, 150, 255),
	revive = Color3.fromRGB(255, 200, 60),
}

local function consumableCard(order, name, image, count, desc, color, buttonText, onUse)
	local card = slotTemplate:Clone()
	card.Name = "Consumable_" .. name
	card.LayoutOrder = order
	card.Visible = true
	pcall(UIStyle.rarityCard, card, color)
	card.Icon.Image = image or ""
	card.Icon.Visible = (image or "") ~= ""
	card.Fallback.Visible = (image or "") == ""
	card.ItemName.Text = name
	card.Rarity.Text = "x" .. count
	card.Rarity.TextColor3 = Color3.new(1, 1, 1)
	local stats = card:FindFirstChild("Stats")
	if stats then
		stats.Text = desc
	end
	local fav = card:FindFirstChild("Favorite")
	if fav then
		fav.Visible = false
	end
	card.EquipButton.Label.Text = buttonText
	if onUse then
		card.EquipButton.Activated:Connect(onUse)
	else
		card.EquipButton.BackgroundColor3 = Color3.fromRGB(110, 120, 145)
	end
	card.Parent = grid
end

-- Revive picker: Revive Potion / Revive Feather ask WHICH defeated
-- monster to bring back
local revivePicker
local function closeRevivePicker()
	if revivePicker then
		revivePicker:Destroy()
		revivePicker = nil
	end
end
local function openRevivePicker(title, onPick)
	closeRevivePicker()
	local list = {}
	for _, src in ipairs({ profile.base or {}, profile.monsters or {} }) do
		for _, e in ipairs(src) do
			if e.defeated and e.monsterId then
				table.insert(list, e)
			end
		end
	end
	if #list == 0 then
		toast("None of your monsters need reviving.", RED)
		return
	end
	local f = Instance.new("Frame")
	f.Name = "RevivePicker"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(360, math.min(90 + #list * 56, 420))
	f.BackgroundColor3 = Color3.fromRGB(24, 26, 44)
	f.ZIndex = 40
	f.Parent = main
	revivePicker = f
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(10, 15, 35) st.Thickness = 4 st.Parent = f
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -60, 0, 40) t.Position = UDim2.fromOffset(14, 8) t.BackgroundTransparency = 1
	t.Text = title t.Font = Enum.Font.LuckiestGuy t.TextScaled = true t.TextColor3 = GOLD
	t.TextStrokeTransparency = 0 t.TextXAlignment = Enum.TextXAlignment.Left t.ZIndex = 41 t.Parent = f
	local x = Instance.new("TextButton")
	x.Size = UDim2.fromOffset(38, 38) x.Position = UDim2.new(1, -46, 0, 8) x.BackgroundColor3 = RED
	x.Text = "X" x.Font = Enum.Font.LuckiestGuy x.TextScaled = true x.TextColor3 = Color3.new(1, 1, 1) x.ZIndex = 41 x.Parent = f
	Instance.new("UICorner", x).CornerRadius = UDim.new(0, 10)
	x.Activated:Connect(closeRevivePicker)
	local sc = Instance.new("ScrollingFrame")
	sc.Size = UDim2.new(1, -20, 1, -64) sc.Position = UDim2.fromOffset(10, 54) sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0 sc.ScrollBarThickness = 6 sc.AutomaticCanvasSize = Enum.AutomaticSize.Y sc.CanvasSize = UDim2.new()
	sc.ZIndex = 41 sc.Parent = f
	local lay = Instance.new("UIListLayout") lay.Padding = UDim.new(0, 6) lay.Parent = sc
	for _, e in ipairs(list) do
		local m = Config.GetMonster(e.monsterId)
		local rarity = Config.GetRarity(m and m.rarity or "Common")
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 50)
		b.BackgroundColor3 = colorFromTable(rarity.color)
		b.Text = "" b.ZIndex = 42 b.Parent = sc
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
		local img = getIconImage("monster", e)
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(42, 42) icon.Position = UDim2.fromOffset(4, 4) icon.BackgroundTransparency = 1
		icon.Image = img icon.ZIndex = 43 icon.Parent = b
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -120, 1, -8) l.Position = UDim2.fromOffset(52, 4) l.BackgroundTransparency = 1
		l.Text = getDisplayName("monster", e) .. "  Lv." .. (e.level or 1)
		l.Font = Enum.Font.LuckiestGuy l.TextScaled = true l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0 l.TextXAlignment = Enum.TextXAlignment.Left l.ZIndex = 43 l.Parent = b
		local go = Instance.new("TextLabel")
		go.Size = UDim2.fromOffset(62, 34) go.Position = UDim2.new(1, -68, 0, 8) go.BackgroundColor3 = GREEN
		go.Text = "REVIVE" go.Font = Enum.Font.LuckiestGuy go.TextScaled = true go.TextColor3 = Color3.new(1, 1, 1)
		go.TextStrokeTransparency = 0 go.ZIndex = 43 go.Parent = b
		Instance.new("UICorner", go).CornerRadius = UDim.new(0, 8)
		b.Activated:Connect(function()
			closeRevivePicker()
			onPick(e.uid)
		end)
	end
end

local function renderConsumables()
	local order = 0
	if activeTab == "Potion" then
		for _, potion in ipairs(Config.Potions) do
			local count = (profile.potions and profile.potions[potion.key]) or 0
			if count > 0 then
				order += 1
				consumableCard(order, potion.name, potion.imageId, count, potion.text, POTION_COLORS[potion.key] or BLUE, "USE", function()
					if potion.key == "revive" then
						openRevivePicker("REVIVE WHICH?", function(uid)
							local ok, r = pcall(function()
								return usePotionRemote:InvokeServer("revive", uid)
							end)
							if ok and r then
								if r.profile then
									profile = r.profile
								end
								toast(r.message or "", r.success and GOLD or RED)
							end
							renderGrid()
						end)
						return
					end
					local ok, r = pcall(function()
						return usePotionRemote:InvokeServer(potion.key)
					end)
					if ok and r then
						if r.profile then
							profile = r.profile
						end
						toast(r.message or "", r.success and GOLD or RED)
					end
					renderGrid()
				end)
			end
		end
	else
		for key, item in pairs(Config.Items) do
			local count = (profile.items and profile.items[key]) or 0
			if count > 0 then
				order += 1
				consumableCard(order, item.name, item.imageId, count, item.text or "", Color3.fromRGB(120, 110, 255), item.button or "OWNED",
					key == "giftCard" and function()
						main.Visible = false
						monsterFolder:WaitForChild("ClientBridge"):WaitForChild("OpenGift"):Fire()
					end or nil)
			end
		end
		-- gears from the Gear Shop (Kurt)
		for _, gear in ipairs(Config.Gears or {}) do
			local count = (profile.gears and profile.gears[gear.key]) or 0
			if count > 0 then
				order += 1
				consumableCard(order, gear.name, gear.imageId, count, gear.text or "", Color3.fromRGB(gear.color[1], gear.color[2], gear.color[3]), "USE", function()
					if gear.key == "reviveFeather" then
						openRevivePicker("REVIVE WHICH?", function(uid)
							local ok, r = pcall(function()
								return useGearRemote:InvokeServer("reviveFeather", uid)
							end)
							if ok and r then
								if r.profile then
									profile = r.profile
								end
								toast(r.message or "", r.success and GOLD or RED)
							end
							renderGrid()
						end)
						return
					end
					local ok, r = pcall(function()
						return useGearRemote:InvokeServer(gear.key)
					end)
					if ok and r then
						if r.profile then
							profile = r.profile
						end
						toast(r.message or "", r.success and GOLD or RED)
					end
					renderGrid()
				end)
			end
		end
	end
	for i = order + 1, math.max(order, 16) do
		local e = emptyTemplate:Clone()
		e.Name = "Empty"
		e.LayoutOrder = i
		e.Visible = true
		e.Parent = grid
	end
end

-- Everything the grid shows. The server sends the whole profile every
-- second (income), so only rebuild the cards when this actually changes.
local lastSignature
local function gridSignature()
	local parts = { activeTab, search.Text, tostring(sortDescending) }
	if activeTab == "Potion" or activeTab == "Item" then
		for _, src in ipairs({ profile.potions, profile.items, profile.gears }) do
			for key, count in pairs(src or {}) do
				table.insert(parts, key .. "=" .. tostring(count))
			end
		end
		table.sort(parts, function(a, b)
			return a < b
		end)
		return table.concat(parts, "|")
	end
	for _, src in ipairs({ profile.eggs or {}, profile.monsters or {} }) do
		for _, item in ipairs(src) do
			table.insert(parts, tostring(item.uid) .. (item.favorite and "*" or "") .. ":" .. tostring(item.level or 0))
		end
	end
	return table.concat(parts, "|")
end

local gridLayout = grid:FindFirstChildOfClass("UIGridLayout")
local function sizeCells()
	if not gridLayout then
		return
	end
	local tall = activeTab == "Potion" or activeTab == "Item"
	-- AbsoluteSize is in screen pixels, but offsets inside the window are
	-- multiplied by its UIScale (phones shrink the window): undo that, or
	-- the rows come out shorter than the cards and they overlap
	local scale = 1
	local a = grid.Parent
	while a do
		local s = a:FindFirstChildOfClass("UIScale")
		if s then
			scale *= s.Scale
		end
		a = a.Parent
	end
	local width = grid.AbsoluteSize.X / math.max(scale, 0.05)
	local w = width > 0 and (width - 30) / 4 - 9 or 120
	gridLayout.CellSize = UDim2.new(0.25, -9, 0, tall and 162 or math.floor(w))
end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCells)

renderGrid = function()
	sizeCells()
	local signature = gridSignature()
	if signature == lastSignature then
		updateCount()
		return
	end
	lastSignature = signature

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	updateCount()

	if activeTab == "Potion" or activeTab == "Item" then
		closePopup()
		renderConsumables()
		return
	end

	local items = {}
	if activeTab == "All" or activeTab == "Egg" then
		for _, egg in ipairs(sortedFiltered(profile.eggs or {}, "egg")) do
			table.insert(items, { "egg", egg })
		end
	end
	if activeTab == "All" or activeTab == "Monster" then
		for _, m in ipairs(sortedFiltered(profile.monsters or {}, "monster")) do
			table.insert(items, { "monster", m })
		end
	end

	for i, entry in ipairs(items) do
		createCard(entry[1], entry[2], i)
	end
	-- keep the info popup open while the list refreshes (income ticks),
	-- close it only if that monster / egg is gone
	if popupFor and not grid:FindFirstChild("Item_" .. tostring(popupFor)) then
		closePopup()
	end
	for i = #items + 1, math.max(#items, 16) do
		local e = emptyTemplate:Clone()
		e.Name = "Empty"
		e.LayoutOrder = i
		e.Visible = true
		e.Parent = grid
	end
end

--------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------

-- tabs: dark studded tiles; the open tab is lighter with a white rim
local function styleTab(b, on)
	pcall(function()
		UIStyle.brick(b, on and Color3.fromRGB(88, 96, 122) or Color3.fromRGB(50, 54, 68), { side = false, studTransparency = 0.65 })
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = on and Color3.fromRGB(240, 244, 255) or UIStyle.OUTLINE
			stroke.Thickness = on and 4 or 3
		end
	end)
end

local tabButtons = {}
for _, b in ipairs(tabs:GetChildren()) do
	if b:IsA("GuiButton") and b.Name:match("^Tab_") then
		local key = b.Name:sub(5)
		tabButtons[key] = b
		layoutIconButton(b, true)
		bounce(b)
		b.Activated:Connect(function()
			activeTab = key
			closePopup()
			for k, other in pairs(tabButtons) do
				styleTab(other, k == activeTab)
			end
			renderGrid()
		end)
	end
end
for k, b in pairs(tabButtons) do
	styleTab(b, k == activeTab)
end

--------------------------------------------------------------------
-- Bottom bar / close / search
--------------------------------------------------------------------

for _, b in ipairs({ closeButton, sortButton }) do
	layoutIconButton(b)
	bounce(b)
end
if closeButton.Icon.Image ~= "" then
	closeButton.Label.Visible = false
end
local titleIcon = main.Title:FindFirstChild("Icon")
if titleIcon then
	titleIcon.Visible = titleIcon.Image ~= ""
end
local countIcon = main.Count:FindFirstChild("Icon")
if countIcon then
	countIcon.Visible = countIcon.Image ~= ""
end

local function close()
	closeRevivePicker()
	closePopup()
	main.Visible = false
end

local function open()
	-- shrink on small screens so the whole window fits
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if viewport and viewport.Y > 0 then
		mainScale.Scale = math.clamp(math.min(viewport.Y / 640, viewport.X / 860), 0.55, 1) * ((game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled) and 0.88 or 1)
	end
	main.Visible = true
	renderGrid()
	mainScale.Scale *= 0.85
	TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = mainScale.Scale / 0.85 }):Play()
end

closeButton.Activated:Connect(close)

sortButton.Activated:Connect(function()
	sortDescending = not sortDescending
	sortButton.Label.Text = sortDescending and "SORT \226\150\188" or "SORT \226\150\178"
	renderGrid()
end)

search:GetPropertyChangedSignal("Text"):Connect(function()
	if main.Visible then
		renderGrid()
	end
end)

openBridge.Event:Connect(open)
closeBridge.Event:Connect(close)

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	if main.Visible then
		renderGrid()
	else
		updateCount()
	end
end)

--------------------------------------------------------------------
-- Cartoony studded look (header bar, dark studded body, rarity cards)
--------------------------------------------------------------------
local restyled, restyleErr = pcall(function()
	local HEADER = 74
	main.BackgroundColor3 = UIStyle.BODY
	local mg = main:FindFirstChildOfClass("UIGradient")
	if mg then
		mg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 205, 215))
	end
	main:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 18)
	main:FindFirstChildOfClass("UIStroke").Color = UIStyle.OUTLINE
	UIStyle.studs(main, 44, 0.8)
	-- light inner rim, like a plastic tray
	local rim = main:FindFirstChild("Rim") or Instance.new("Frame")
	rim.Name = "Rim"
	rim.Size = UDim2.new(1, -10, 1, -10)
	rim.Position = UDim2.fromOffset(5, 5)
	rim.BackgroundTransparency = 1
	rim.ZIndex = 1
	rim.Parent = main
	local rc = rim:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", rim)
	rc.CornerRadius = UDim.new(0, 14)
	local rs = rim:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", rim)
	rs.Color = UIStyle.RIM
	rs.Thickness = 3
	rs.Transparency = 0.35

	-- header bar across the top: blue to cyan, studs, icon + title on the left
	local title = main.Title
	title.AnchorPoint = Vector2.new(0, 0)
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.new(1, 0, 0, HEADER)
	title.BackgroundColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 0 -- (in case it was auto-styled first: that makes it see-through)
	title.ZIndex = 5
	title:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 18)
	local ts = title:FindFirstChildOfClass("UIStroke")
	if ts then
		ts.Enabled = false
	end
	local tg = title:FindFirstChildOfClass("UIGradient")
	tg.Rotation = 0
	tg.Color = ColorSequence.new(Color3.fromRGB(110, 95, 255), Color3.fromRGB(55, 200, 255))
	-- square off the header's bottom corners + a dark line under it
	local fill = title:FindFirstChild("BottomFill") or Instance.new("Frame")
	fill.Name = "BottomFill"
	fill.Size = UDim2.new(1, 0, 0, 20)
	fill.Position = UDim2.new(0, 0, 1, -20)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.ZIndex = 5
	fill.Parent = title
	local fg = fill:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", fill)
	fg.Color = tg.Color
	local line = title:FindFirstChild("Line") or Instance.new("Frame")
	line.Name = "Line"
	line.Size = UDim2.new(1, 0, 0, 5)
	line.Position = UDim2.new(0, 0, 1, 0)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = UIStyle.OUTLINE
	line.ZIndex = 6
	line.Parent = title
	UIStyle.studs(title, 30, 0.15)
	-- only ONE header with ONE stud layer: remove a second header / studs
	-- (if the window was auto-styled before this script marked it)
	local function oneHeader()
		local skin = main:FindFirstChild("SkinHeader")
		if skin then
			skin:Destroy()
		end
		local seen = false
		for _, c in ipairs(title:GetChildren()) do
			if c.Name == "Studs" then
				if seen then
					c:Destroy()
				end
				seen = true
			end
		end
	end
	oneHeader()
	task.delay(2, oneHeader)
	local badge = title:FindFirstChild("GoldBadge")
	if badge then
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 12, 0.5, 0)
		badge.Size = UDim2.fromOffset(60, 60)
	end
	local text = title:FindFirstChild("Text")
	if text then
		text.AnchorPoint = Vector2.new(0, 0.5)
		text.Position = UDim2.new(0, 86, 0.5, 0)
		text.Size = UDim2.new(0.55, 0, 0.6, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = "Backpack"
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0
		text.TextStrokeColor3 = UIStyle.OUTLINE
	end

	-- red studded X square at the right end of the header
	closeButton:SetAttribute("KeepPlace", true) -- CloseButtonFixer leaves it here
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(84, HEADER)
	closeButton.ZIndex = 8
	UIStyle.closeButton(closeButton, true)
	closeButton.Label.Size = UDim2.fromScale(0.6, 0.62)
	closeButton.Label.Position = UDim2.fromScale(0.5, 0.55)

	-- everything below the header moves down to make room for it
	local top = HEADER + 16
	search.Position = UDim2.fromOffset(205, top)
	tabs.Position = UDim2.fromOffset(20, top)
	tabs.Size = UDim2.new(0, 170, 1, -(top + 78))
	local content = main.Content
	content.Position = UDim2.fromOffset(205, top + 52)
	content.Size = UDim2.new(1, -225, 1, -(top + 52 + 76))

	-- search box, grid tray, counter, sort button
	search.BackgroundColor3 = Color3.fromRGB(60, 64, 80)
	search.TextColor3 = Color3.new(1, 1, 1)
	search.PlaceholderColor3 = Color3.fromRGB(170, 176, 196)
	content.BackgroundColor3 = UIStyle.BODY_DARK
	UIStyle.studs(content, 36, 0.8)
	main.Count.BackgroundColor3 = Color3.fromRGB(50, 54, 68)
	UIStyle.studs(main.Count, 30, 0.7)
	UIStyle.studs(sortButton, 30, 0.15)

	-- empty slots: dark sockets
	emptyTemplate.BackgroundColor3 = Color3.fromRGB(36, 39, 52)
	local es = emptyTemplate:FindFirstChildOfClass("UIStroke")
	if es then
		es.Color = Color3.fromRGB(62, 66, 84)
	end
	-- (no studs of their own: the tray's studs show through them)
	emptyTemplate.BackgroundTransparency = math.max(emptyTemplate.BackgroundTransparency, 0.4)
	local oldStuds = emptyTemplate:FindFirstChild("Studs")
	if oldStuds then
		oldStuds:Destroy()
	end
	sizeCells()
end)
if not restyled then
	warn("Backpack restyle failed (the backpack still works): " .. tostring(restyleErr))
end

main.Visible = false
updateCount()
