local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local giftInfoRemote = remotes:WaitForChild("GiftInfo")
local giftSendRemote = remotes:WaitForChild("GiftSend")
local giftRespondRemote = remotes:WaitForChild("GiftRespond")
local giftEventRemote = remotes:WaitForChild("GiftEvent")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local notify = bridge:WaitForChild("Notify")
local openGiftBridge = bridge:WaitForChild("OpenGift")
local closeAllBridge = bridge:WaitForChild("CloseAll")

--------------------------------------------------------------------
-- Gifting window (opened from the Gift Card in the backpack) + the
-- accept/decline popup for gifts you receive. Rules: Config.Gifting.
--------------------------------------------------------------------

local gui = script.Parent
local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 93)
local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(60, 205, 95)
local BLUE = Color3.fromRGB(60, 160, 255)
local GRAY = Color3.fromRGB(110, 120, 145)
local PINK = Color3.fromRGB(255, 110, 170)
local NAVY = Color3.fromRGB(22, 42, 92)
local FONT = Enum.Font.LuckiestGuy

local profile = profileRemote:InvokeServer()

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(p, r)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 14) }, p)
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
local function button(parent, text, color, size, pos, anchor)
	local b = mk("TextButton", {
		Size = size, Position = pos or UDim2.new(), AnchorPoint = anchor or Vector2.zero, BackgroundColor3 = color,
		Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0,
		TextStrokeColor3 = OUTLINE, AutoButtonColor = true,
	}, parent)
	corner(b, 10)
	stroke(b, 3)
	mk("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end

local function fitScale(frame, w, h)
	local s = frame:FindFirstChildOfClass("UIScale") or mk("UIScale", {}, frame)
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	s.Scale = math.min(1, (v.Y - 90) / h, (v.X - 30) / w) * ((game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled) and 0.88 or 1)
end

--------------------------------------------------------------------
-- main window
--------------------------------------------------------------------

local W, H = 660, 470
local main = mk("Frame", {
	Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = BLUE, Visible = false,
}, gui)
corner(main, 22)
stroke(main, 6)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 120, 235)), Rotation = 90 }, main)
local title = mk("Frame", { Size = UDim2.fromOffset(300, 58), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 18, 0, 0), BackgroundColor3 = PINK, ZIndex = 5 }, main)
corner(title, 18)
stroke(title, 5)
mk("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 190, 205)), Rotation = 90 }, title)
label(title, "SEND GIFT", UDim2.new(1, -64, 0.64, 0), UDim2.new(0, 48, 0.18, 0), { ZIndex = 6 })
-- round gold badge holding the Gift Card, overlapping the ribbon's left end
local badge = mk("Frame", { Size = UDim2.fromOffset(78, 78), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = PINK:Lerp(Color3.new(0, 0, 0), 0.35), ZIndex = 7 }, title)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
stroke(badge, 5)
mk("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Rotation = 90 }, badge)
mk("ImageLabel", { Size = UDim2.fromScale(0.78, 0.78), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = -12, BackgroundTransparency = 1, Image = Config.Items.giftCard.imageId, ScaleType = Enum.ScaleType.Fit, ZIndex = 8 }, badge)
local closeBtn = button(main, "X", Color3.fromRGB(235, 50, 60), UDim2.fromOffset(50, 50), UDim2.new(1, -8, 0, 8), Vector2.new(0.5, 0.5))
closeBtn.ZIndex = 6

local infoLabel = label(main, "", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 40), { TextColor3 = Color3.fromRGB(255, 235, 150) })

-- players column
label(main, "PLAYERS", UDim2.fromOffset(170, 24), UDim2.fromOffset(20, 68))
local playersWell = mk("Frame", { Size = UDim2.new(0, 170, 1, -170), Position = UDim2.fromOffset(20, 96), BackgroundColor3 = NAVY }, main)
corner(playersWell, 14)
stroke(playersWell, 3)
local playerList = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, playersWell)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, playerList)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8) }, playerList)

-- item picker
local tabs = mk("Frame", { Size = UDim2.new(1, -230, 0, 34), Position = UDim2.fromOffset(205, 66), BackgroundTransparency = 1 }, main)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
local itemsWell = mk("Frame", { Size = UDim2.new(1, -225, 1, -218), Position = UDim2.fromOffset(205, 106), BackgroundColor3 = NAVY }, main)
corner(itemsWell, 14)
stroke(itemsWell, 3)
local itemList = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, itemsWell)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, itemList)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }, itemList)

-- cash + send
label(main, "CASH", UDim2.fromOffset(70, 26), UDim2.new(0, 205, 1, -104))
local cashBox = mk("TextBox", {
	Size = UDim2.new(1, -300, 0, 32), Position = UDim2.new(0, 280, 1, -106), BackgroundColor3 = Color3.fromRGB(235, 245, 255),
	Text = "", PlaceholderText = "0", Font = FONT, TextSize = 22, TextColor3 = OUTLINE, ClearTextOnFocus = false,
}, main)
corner(cashBox, 10)
stroke(cashBox, 3)
local selectedLabel = label(main, "0/5 ITEMS", UDim2.fromOffset(200, 30), UDim2.new(0, 20, 1, -56), { TextXAlignment = Enum.TextXAlignment.Left })
local sendBtn = button(main, "SEND GIFT", GREEN, UDim2.fromOffset(220, 50), UDim2.new(1, -20, 1, -14), Vector2.new(1, 1))

-- double confirmation
local confirm = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 20 }, main)
corner(confirm, 22)
local confirmBox = mk("Frame", { Size = UDim2.fromOffset(420, 200), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = NAVY, ZIndex = 21 }, confirm)
corner(confirmBox, 18)
stroke(confirmBox, 4)
local confirmText = label(confirmBox, "", UDim2.new(1, -30, 0, 100), UDim2.fromOffset(15, 14), { ZIndex = 22, TextWrapped = true })
mk("UITextSizeConstraint", { MaxTextSize = 24 }, confirmText)
local yesBtn = button(confirmBox, "YES", GREEN, UDim2.fromOffset(150, 46), UDim2.new(0.5, -8, 1, -14), Vector2.new(1, 1))
local noBtn = button(confirmBox, "NO", Color3.fromRGB(235, 70, 80), UDim2.fromOffset(150, 46), UDim2.new(0.5, 8, 1, -14), Vector2.new(0, 1))
yesBtn.ZIndex, noBtn.ZIndex = 22, 22

--------------------------------------------------------------------
-- state
--------------------------------------------------------------------

local target -- Player
local info -- from GiftInfo
local tab = "monsters"
local picked = { monsters = {}, eggs = {}, potions = {}, items = {} }

local function pickedCount()
	local n = 0
	for _ in pairs(picked.monsters) do
		n += 1
	end
	for _ in pairs(picked.eggs) do
		n += 1
	end
	for _, kind in ipairs({ "potions", "items" }) do
		for _, c in pairs(picked[kind]) do
			n += c
		end
	end
	return n
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local renderItems

local function refreshInfo()
	selectedLabel.Text = pickedCount() .. "/" .. Config.Gifting.maxItemsPerGift .. " ITEMS"
	if not target then
		infoLabel.Text = "Pick a player to gift  \u{2022}  Gift Cards: " .. ((profile.items and profile.items.giftCard) or 0)
		infoLabel.TextColor3 = Color3.fromRGB(255, 235, 150)
		return
	end
	if info and not info.ok then
		infoLabel.Text = info.reason or "You can't gift this player."
		infoLabel.TextColor3 = RED
	elseif info then
		infoLabel.Text = string.format("To %s  \u{2022}  Cards: %d  \u{2022}  Gifts left today: %d  \u{2022}  Max cash: $%s",
			target.DisplayName, info.cards, info.giftsLeft, Config.FormatNumber(info.maxCash))
		infoLabel.TextColor3 = Color3.fromRGB(255, 235, 150)
	end
end

local function renderPlayers()
	clear(playerList)
	local order = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			order += 1
			local b = button(playerList, p.DisplayName, target == p and GOLD or BLUE, UDim2.new(1, 0, 0, 38))
			b.LayoutOrder = order
			b.Activated:Connect(function()
				target = p
				info = nil
				renderPlayers()
				refreshInfo()
				local ok, r = pcall(function()
					return giftInfoRemote:InvokeServer(p.UserId)
				end)
				if ok and target == p then
					info = r
					refreshInfo()
				end
			end)
		end
	end
	if order == 0 then
		label(playerList, "No other players in this server", UDim2.new(1, 0, 0, 60), nil, { TextWrapped = true, TextColor3 = Color3.fromRGB(200, 215, 240) })
	end
end

local function itemRow(order, name, sub, color, rightText, rightColor, onClick, stepper)
	local row = mk("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Color3.fromRGB(35, 62, 125) }, itemList)
	corner(row, 10)
	label(row, name, UDim2.new(1, -170, 0, 22), UDim2.fromOffset(10, 3), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
	label(row, sub, UDim2.new(1, -170, 0, 16), UDim2.fromOffset(10, 26), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 215, 240) })
	if stepper then
		local minus = button(row, "-", Color3.fromRGB(235, 70, 80), UDim2.fromOffset(36, 34), UDim2.new(1, -118, 0.5, 0), Vector2.new(0, 0.5))
		label(row, rightText, UDim2.fromOffset(40, 28), UDim2.new(1, -80, 0.5, -14))
		local plus = button(row, "+", GREEN, UDim2.fromOffset(36, 34), UDim2.new(1, -40, 0.5, 0), Vector2.new(0, 0.5))
		minus.Activated:Connect(function()
			stepper(-1)
		end)
		plus.Activated:Connect(function()
			stepper(1)
		end)
	else
		local b = button(row, rightText, rightColor, UDim2.fromOffset(100, 34), UDim2.new(1, -6, 0.5, 0), Vector2.new(1, 0.5))
		b.Activated:Connect(onClick)
	end
end

renderItems = function()
	clear(itemList)
	local order = 0
	local full = pickedCount() >= Config.Gifting.maxItemsPerGift
	if tab == "monsters" or tab == "eggs" then
		for _, e in ipairs(profile[tab] or {}) do
			if not e.favorite then
				order += 1
				local name, sub, color
				if tab == "monsters" then
					local m = Config.GetMonster(e.monsterId)
					local r = Config.GetRarity(m and m.rarity or "Common")
					name = Config.BuildDisplayName(m and m.name or "Monster", e.size, e.finish)
					sub = "$" .. Config.FormatNumber(Config.GetEntryIncome(e)) .. "/s  \u{2022}  Lv. " .. (e.level or 1) .. "  \u{2022}  " .. Config.FormatKg(e.kg)
					color = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
				else
					local r = Config.GetRarity(e.rarity)
					name = r.name .. " Egg"
					sub = "Hatch: " .. Config.FormatDuration(Config.GetEggHatchDuration(e))
					color = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
				end
				local isPicked = picked[tab][e.uid]
				itemRow(order, name, sub, color, isPicked and "ADDED" or "ADD", isPicked and GOLD or (full and GRAY or GREEN), function()
					if picked[tab][e.uid] then
						picked[tab][e.uid] = nil
					elseif pickedCount() < Config.Gifting.maxItemsPerGift then
						picked[tab][e.uid] = true
					end
					renderItems()
					refreshInfo()
				end)
			end
		end
	else
		local defs = {}
		if tab == "potions" then
			for _, p in ipairs(Config.Potions) do
				table.insert(defs, { key = p.key, name = p.name, text = p.text })
			end
		else
			for key, it in pairs(Config.Items) do
				if key ~= "giftCard" then
					table.insert(defs, { key = key, name = it.name, text = it.text })
				end
			end
		end
		for _, d in ipairs(defs) do
			local have = (profile[tab] and profile[tab][d.key]) or 0
			if have > 0 then
				order += 1
				local n = picked[tab][d.key] or 0
				itemRow(order, d.name, "You have " .. have, GOLD, tostring(n), nil, nil, function(delta)
					local cur = picked[tab][d.key] or 0
					local nextN = math.clamp(cur + delta, 0, have)
					if delta > 0 and pickedCount() >= Config.Gifting.maxItemsPerGift then
						return
					end
					picked[tab][d.key] = nextN > 0 and nextN or nil
					renderItems()
					refreshInfo()
				end)
			end
		end
	end
	if order == 0 then
		label(itemList, "Nothing to gift here", UDim2.new(1, 0, 0, 40), nil, { TextColor3 = Color3.fromRGB(200, 215, 240) })
	end
end

local tabButtons = {}
for i, t in ipairs({ { "monsters", "PETS" }, { "eggs", "EGGS" }, { "potions", "POTIONS" }, { "items", "ITEMS" } }) do
	local b = button(tabs, t[2], t[1] == tab and GOLD or BLUE, UDim2.fromOffset(98, 32))
	b.LayoutOrder = i
	tabButtons[t[1]] = b
	b.Activated:Connect(function()
		tab = t[1]
		for k, tb in pairs(tabButtons) do
			tb.BackgroundColor3 = k == tab and GOLD or BLUE
		end
		renderItems()
	end)
end

--------------------------------------------------------------------
-- send (double confirmation)
--------------------------------------------------------------------

local function buildPayload()
	local payload = { cash = math.floor(tonumber(cashBox.Text) or 0), monsters = {}, eggs = {}, potions = {}, items = {} }
	for uid in pairs(picked.monsters) do
		table.insert(payload.monsters, uid)
	end
	for uid in pairs(picked.eggs) do
		table.insert(payload.eggs, uid)
	end
	for k, n in pairs(picked.potions) do
		payload.potions[k] = n
	end
	for k, n in pairs(picked.items) do
		payload.items[k] = n
	end
	return payload
end

local confirmStep = 0
local function askConfirm(step)
	confirmStep = step
	confirm.Visible = true
	local cash = math.floor(tonumber(cashBox.Text) or 0)
	if step == 1 then
		confirmText.Text = string.format("Gift %d item(s)%s to %s? This uses 1 Gift Card.", pickedCount(), cash > 0 and (" + $" .. Config.FormatNumber(cash)) or "", target.DisplayName)
	else
		confirmText.Text = "Are you REALLY sure? Gifts can't be undone once " .. target.DisplayName .. " accepts."
	end
end

sendBtn.Activated:Connect(function()
	if not target then
		notify:Fire("Pick a player first.", RED)
		return
	end
	if pickedCount() == 0 and math.floor(tonumber(cashBox.Text) or 0) <= 0 then
		notify:Fire("Pick something to gift first.", RED)
		return
	end
	askConfirm(1)
end)
noBtn.Activated:Connect(function()
	confirm.Visible = false
end)
yesBtn.Activated:Connect(function()
	if confirmStep == 1 then
		askConfirm(2)
		return
	end
	confirm.Visible = false
	local ok, r = pcall(function()
		return giftSendRemote:InvokeServer(target.UserId, buildPayload())
	end)
	if ok and r then
		notify:Fire(r.message or "", r.success and GOLD or RED)
		if r.success then
			picked = { monsters = {}, eggs = {}, potions = {}, items = {} }
			cashBox.Text = ""
			main.Visible = false
		end
	end
end)

local function open()
	closeAllBridge:Fire("gift")
	fitScale(main, W, H)
	target, info = nil, nil
	picked = { monsters = {}, eggs = {}, potions = {}, items = {} }
	cashBox.Text = ""
	confirm.Visible = false
	renderPlayers()
	renderItems()
	refreshInfo()
	main.Visible = true
end

openGiftBridge.Event:Connect(open)
closeBtn.Activated:Connect(function()
	main.Visible = false
end)
closeAllBridge.Event:Connect(function(except)
	if except ~= "gift" then
		main.Visible = false
	end
end)
Players.PlayerAdded:Connect(function()
	if main.Visible then
		renderPlayers()
	end
end)
Players.PlayerRemoving:Connect(function(p)
	if p == target then
		target, info = nil, nil
		refreshInfo()
	end
	if main.Visible then
		task.defer(renderPlayers)
	end
end)
-- The server sends the profile every second (income): only rebuild the
-- list when what it shows changed, so it doesn't lag or jump to the top.
local function listSignature(p)
	local parts = { tab }
	local src = p[tab]
	if tab == "monsters" or tab == "eggs" then
		for _, e in ipairs(src or {}) do
			table.insert(parts, tostring(e.uid) .. (e.favorite and "*" or "") .. ":" .. tostring(e.level or 0))
		end
	else
		for key, count in pairs(src or {}) do
			table.insert(parts, key .. "=" .. tostring(count))
		end
		table.sort(parts, function(a, b)
			return a < b
		end)
	end
	return table.concat(parts, "|")
end

profileUpdated.OnClientEvent:Connect(function(newProfile)
	local changed = listSignature(newProfile) ~= listSignature(profile)
	profile = newProfile
	if main.Visible and not confirm.Visible then
		if changed then
			renderItems()
		end
		refreshInfo()
	end
end)

--------------------------------------------------------------------
-- incoming gift popup (accept / decline)
--------------------------------------------------------------------

local offer = mk("Frame", {
	Name = "Offer", Size = UDim2.fromOffset(400, 250), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90),
	BackgroundColor3 = NAVY, Visible = false, ZIndex = 30,
}, gui)
corner(offer, 18)
stroke(offer, 5)
mk("ImageLabel", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, Image = Config.Items.giftCard.imageId, ZIndex = 31 }, offer)
local offerTitle = label(offer, "", UDim2.new(1, -84, 0, 30), UDim2.fromOffset(72, 10), { ZIndex = 31, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = PINK })
local offerTimer = label(offer, "", UDim2.new(1, -84, 0, 20), UDim2.fromOffset(72, 40), { ZIndex = 31, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 215, 240) })
local offerLines = label(offer, "", UDim2.new(1, -24, 0, 110), UDim2.fromOffset(12, 68), { ZIndex = 31, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
mk("UITextSizeConstraint", { MaxTextSize = 20 }, offerLines)
local acceptBtn = button(offer, "ACCEPT", GREEN, UDim2.fromOffset(170, 46), UDim2.new(0.5, -6, 1, -12), Vector2.new(1, 1))
local declineBtn = button(offer, "DECLINE", Color3.fromRGB(235, 70, 80), UDim2.fromOffset(170, 46), UDim2.new(0.5, 6, 1, -12), Vector2.new(0, 1))
acceptBtn.ZIndex, declineBtn.ZIndex = 31, 31

local currentOffer
local function answer(accept)
	if not currentOffer then
		return
	end
	local id = currentOffer.id
	currentOffer = nil
	offer.Visible = false
	local ok, r = pcall(function()
		return giftRespondRemote:InvokeServer(id, accept)
	end)
	if ok and r then
		notify:Fire(r.message or "", r.success and GOLD or RED)
	end
end
acceptBtn.Activated:Connect(function()
	answer(true)
end)
declineBtn.Activated:Connect(function()
	answer(false)
end)

giftEventRemote.OnClientEvent:Connect(function(data)
	if data.kind == "offer" then
		currentOffer = data
		offerTitle.Text = "GIFT FROM " .. string.upper(data.from)
		offerLines.Text = table.concat(data.summary or {}, "\n")
		fitScale(offer, 400, 250)
		offer.Visible = true
		local ends = os.clock() + (data.seconds or 60)
		task.spawn(function()
			while currentOffer == data do
				local left = math.max(0, math.ceil(ends - os.clock()))
				offerTimer.Text = "Accept within " .. left .. "s"
				if left <= 0 then
					currentOffer = nil
					offer.Visible = false
				end
				task.wait(0.5)
			end
		end)
	elseif data.kind == "info" then
		notify:Fire(data.text, data.good and Color3.fromRGB(120, 255, 140) or RED)
	end
end)
