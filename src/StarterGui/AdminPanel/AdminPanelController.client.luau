local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- Admin panel (only for the admin ids below; the server checks too).
-- ADMIN button -> window with two tabs:
--   GIVE: pick a player (or ALL), pick what, amount -> GIVE
--   DEV CHAT: type a message -> shows in every server as
--             [Dev]KaidenBYND : message (a notification, not in chat)
--   EFFECTS: start a server-wide effect in EVERY server:
--            luck / damage / health / income / exp, 1x-8x, for a time
--------------------------------------------------------------------
local ADMIN_IDS = { [1165846861] = true }
-- icon of the admin button (next to Settings / Daily / Hide in the top
-- bar). Put your image id here, e.g. "rbxassetid://1234567890"
local ADMIN_ICON = "rbxassetid://127955947810577"
local player = Players.LocalPlayer
local gui = script.Parent
if not ADMIN_IDS[player.UserId] then
	gui:Destroy()
	return
end

local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local UIStyle
do
	local mod = monsterFolder:WaitForChild("UIStyle", 5)
	local ok, res = pcall(function()
		return mod and require(mod)
	end)
	UIStyle = ok and res or nil
end
local adminRemote = monsterFolder:WaitForChild("Remotes"):WaitForChild("AdminAction")

local OUTLINE = Color3.fromRGB(12, 14, 32)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local PURPLE, PURPLE_DARK = Color3.fromRGB(130, 70, 230), Color3.fromRGB(70, 36, 140)
local GREEN, RED, GRAY, GOLD, BLUE = Color3.fromRGB(60, 205, 95), Color3.fromRGB(235, 60, 70), Color3.fromRGB(96, 104, 128), Color3.fromRGB(255, 200, 60), Color3.fromRGB(50, 150, 255)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r, stroke)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
	if stroke ~= false then
		mk("UIStroke", { Color = OUTLINE, Thickness = stroke or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
	return o
end
local function text(parent, t, size, pos, props)
	local l = mk("TextLabel", { Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Text = t, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
local function button(parent, t, size, pos, color)
	local b = mk("TextButton", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = color, Text = t, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, AutoButtonColor = true }, parent)
	round(b, 10, 3)
	mk("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end

-- the ADMIN button
-- sits in the top bar row beside Settings / Daily / Hide, same style
local topRow = player:WaitForChild("PlayerGui"):WaitForChild("TopBar"):WaitForChild("Top")
local template = topRow:WaitForChild("SettingsButton")
local openBtn = template:Clone()
openBtn.Name = "AdminButton"
openBtn.LayoutOrder = 4
for _, c in ipairs(openBtn:GetChildren()) do
	if c:IsA("LuaSourceContainer") then
		c:Destroy()
	end
end
local icon = openBtn:FindFirstChild("Icon")
if icon then
	icon.Image = ADMIN_ICON
end
if ADMIN_ICON == "" then
	-- no image yet: a small "ADMIN" label
	if icon then
		icon.Visible = false
	end
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Size = UDim2.fromScale(0.9, 0.5)
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.fromScale(0.5, 0.5)
	lbl.BackgroundTransparency = 1
	lbl.Text = "ADMIN"
	lbl.TextScaled = true
	lbl.Font = FONT
	lbl.TextColor3 = RED
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = OUTLINE
	lbl.Parent = openBtn
end
openBtn.Parent = topRow
topRow.Size = UDim2.new(topRow.Size.X.Scale, topRow.Size.X.Offset + 56, topRow.Size.Y.Scale, topRow.Size.Y.Offset)

-- window
-- wider than before: the categories sit in a column on the left (like
-- the Backpack tabs) and the pages keep their old 620px width
local W, H = 845, 560
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = PURPLE, Visible = false }, gui)
round(main, 20, 6)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(160, 110, 255), PURPLE_DARK), Rotation = 90 }, main)
local mainScale = mk("UIScale", {}, main)
local title = mk("Frame", { Name = "Title", Size = UDim2.fromOffset(320, 56), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = RED, ZIndex = 5 }, main)
round(title, 16, 5)
text(title, "Admin Panel", UDim2.new(1, -30, 0.64, 0), UDim2.new(0, 15, 0.18, 0), { ZIndex = 6, Name = "Text" })
local closeBtn = button(main, "X", UDim2.fromOffset(54, 54), UDim2.new(1, -6, 0, 6), RED)
closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
closeBtn.ZIndex = 10

-- categories: a column on the left, like the Backpack tabs
local TAB_W, TAB_H = 170, 52
local tabGive = button(main, "GIVE", UDim2.fromOffset(TAB_W, TAB_H), UDim2.fromOffset(20, 42), GOLD)
local tabChat = button(main, "DEV CHAT", UDim2.fromOffset(TAB_W, TAB_H), UDim2.fromOffset(20, 42 + (TAB_H + 8)), GRAY)
local tabFx = button(main, "EFFECTS", UDim2.fromOffset(TAB_W, TAB_H), UDim2.fromOffset(20, 42 + (TAB_H + 8) * 2), GRAY)
local tabCodes = button(main, "CODES", UDim2.fromOffset(TAB_W, TAB_H), UDim2.fromOffset(20, 42 + (TAB_H + 8) * 3), GRAY)
for _, t in ipairs({ tabGive, tabChat, tabFx, tabCodes }) do
	t.TextXAlignment = Enum.TextXAlignment.Left
	local pad = t:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
	end
end
local BODY_DARK = Color3.fromRGB(28, 31, 42)
local giveBody = mk("Frame", { Size = UDim2.new(1, -(TAB_W + 55), 1, -62), Position = UDim2.fromOffset(TAB_W + 35, 42), BackgroundColor3 = BODY_DARK }, main)
round(giveBody, 14, 3)
local chatBody = mk("Frame", { Size = giveBody.Size, Position = giveBody.Position, BackgroundColor3 = BODY_DARK, Visible = false }, main)
round(chatBody, 14, 3)
local fxBody = mk("Frame", { Size = giveBody.Size, Position = giveBody.Position, BackgroundColor3 = BODY_DARK, Visible = false }, main)
round(fxBody, 14, 3)
local codeBody = mk("Frame", { Size = giveBody.Size, Position = giveBody.Position, BackgroundColor3 = BODY_DARK, Visible = false }, main)
round(codeBody, 14, 3)
local onCodesOpened -- set by the CODES tab below
local function showTab(which)
	giveBody.Visible = which == "give"
	chatBody.Visible = which == "chat"
	fxBody.Visible = which == "fx"
	codeBody.Visible = which == "codes"
	if which == "codes" and onCodesOpened then
		task.spawn(onCodesOpened)
	end
	-- open tab: lighter with a white rim; the others dark (like the Backpack)
	for key, t in pairs({ give = tabGive, chat = tabChat, fx = tabFx, codes = tabCodes }) do
		local on = which == key
		t.BackgroundColor3 = on and Color3.fromRGB(88, 96, 122) or Color3.fromRGB(50, 54, 68)
		local st = t:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = on and Color3.fromRGB(240, 244, 255) or OUTLINE
			st.Thickness = on and 4 or 3
		end
		if UIStyle then
			pcall(UIStyle.studs, t, 34, 0.25)
		end
	end
end
tabFx.Activated:Connect(function()
	showTab("fx")
end)
tabGive.Activated:Connect(function()
	showTab("give")
end)
tabChat.Activated:Connect(function()
	showTab("chat")
end)
tabCodes.Activated:Connect(function()
	showTab("codes")
end)
showTab("give")

--------------------------------------------------------------------
-- GIVE tab
--------------------------------------------------------------------
local state = { target = tostring(player.UserId), kind = "cash", key = nil, size = "Normal", finish = "Normal" }

text(giveBody, "TO", UDim2.fromOffset(40, 26), UDim2.fromOffset(12, 12), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local nameBox = mk("TextBox", { Size = UDim2.fromOffset(170, 38), Position = UDim2.fromOffset(58, 7), BackgroundColor3 = Color3.fromRGB(236, 240, 255), Text = "", PlaceholderText = "username...", TextScaled = true, Font = FONT, TextColor3 = OUTLINE, ClearTextOnFocus = false }, giveBody)
round(nameBox, 10, 3)
mk("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, nameBox)
local targetRow = mk("ScrollingFrame", { Size = UDim2.new(1, -250, 0, 44), Position = UDim2.fromOffset(236, 4), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new() }, giveBody)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, targetRow)

local kindRow = mk("Frame", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 54), BackgroundTransparency = 1 }, giveBody)
mk("UIGridLayout", { CellSize = UDim2.new(1 / 9, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0) }, kindRow)
local KINDS = { { "cash", "CASH" }, { "shards", "SHARDS" }, { "egg", "EGG" }, { "monster", "MONSTER" }, { "potion", "POTION" }, { "item", "ITEM" }, { "gear", "GEAR" }, { "pass", "PASS" }, { "tag", "TAG" } }
local kindBtns = {}

local options = mk("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -242), Position = UDim2.fromOffset(12, 102), BackgroundColor3 = Color3.fromRGB(16, 12, 40), BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, giveBody)
round(options, 10, false)
mk("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 40), CellPadding = UDim2.fromOffset(8, 8) }, options)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, options)
local noOptions = text(giveBody, "", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(30, 170), { TextColor3 = Color3.fromRGB(200, 200, 230) })

-- bottom row: size / finish (eggs + monsters), amount, GIVE
local sizeBtn = button(giveBody, "SIZE: NORMAL", UDim2.fromOffset(150, 38), UDim2.new(0, 12, 1, -104), BLUE)
local finishBtn = button(giveBody, "FINISH: NORMAL", UDim2.fromOffset(170, 38), UDim2.new(0, 170, 1, -104), BLUE)
local amountLabel = text(giveBody, "AMOUNT", UDim2.fromOffset(90, 24), UDim2.new(0, 12, 1, -56), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local removeBtn = button(giveBody, "MODE: GIVE", UDim2.fromOffset(200, 38), UDim2.new(0, 12, 1, -104), BLUE)
removeBtn.Visible = false
local amountBox = mk("TextBox", { Size = UDim2.fromOffset(170, 40), Position = UDim2.new(0, 106, 1, -62), BackgroundColor3 = Color3.fromRGB(236, 240, 255), Text = "1", PlaceholderText = "e.g. 10, 5K, 2M", TextScaled = true, Font = FONT, TextColor3 = OUTLINE, ClearTextOnFocus = false }, giveBody)
round(amountBox, 10, 3)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8) }, amountBox)
local giveBtn = button(giveBody, "GIVE", UDim2.fromOffset(160, 50), UDim2.new(1, -172, 1, -64), GREEN)
-- puts what's picked above into the code you're making (CODES tab)
local addToCodeBtn = button(giveBody, "+ ADD TO CODE", UDim2.fromOffset(150, 50), UDim2.new(1, -330, 1, -64), GOLD)
local status = text(giveBody, "", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 1, -26), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(200, 255, 200) })
status.Position = UDim2.new(0, 12, 1, -134)

local function optionList(kind)
	local list = {}
	if kind == "egg" then
		for _, r in ipairs(Config.Rarities) do
			table.insert(list, { key = r.key, name = r.name .. " Egg", color = Color3.fromRGB(r.color[1], r.color[2], r.color[3]) })
		end
	elseif kind == "monster" then
		for _, m in ipairs(Config.Monsters) do
			local r = Config.GetRarity(m.rarity)
			table.insert(list, { key = m.id, name = m.name, color = Color3.fromRGB(r.color[1], r.color[2], r.color[3]) })
		end
	elseif kind == "potion" then
		for _, p in ipairs(Config.Potions) do
			table.insert(list, { key = p.key, name = p.name, color = Color3.fromRGB(190, 90, 220) })
		end
	elseif kind == "item" then
		for key, it in pairs(Config.Items) do
			table.insert(list, { key = key, name = it.name, color = Color3.fromRGB(70, 160, 255) })
		end
	elseif kind == "pass" then
		for _, g in ipairs(Config.Gamepasses) do
			table.insert(list, { key = g.key, name = g.name, color = Color3.fromRGB(60, 120, 230) })
		end
	elseif kind == "tag" then
		for _, key in ipairs({ "tester", "admin", "beta" }) do
			local t = Config.PassTags[key]
			table.insert(list, { key = key, name = t.text, color = Color3.fromRGB(t.color[1], t.color[2], t.color[3]) })
		end
	elseif kind == "gear" then
		for _, g in ipairs(Config.Gears) do
			table.insert(list, { key = g.key, name = g.name, color = Color3.fromRGB(g.color[1], g.color[2], g.color[3]) })
		end
	end
	return list
end

local optionBtns = {}
local function renderOptions()
	for _, c in ipairs(options:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	optionBtns = {}
	local list = optionList(state.kind)
	noOptions.Text = (#list == 0) and ("Type how much " .. (state.kind == "cash" and "CASH" or "RIFT SHARDS") .. " to give below") or ""
	options.Visible = #list > 0
	if #list > 0 and not state.key then
		state.key = list[1].key
	end
	for i, o in ipairs(list) do
		local b = button(options, o.name:upper(), UDim2.new(), UDim2.new(), o.color)
		b.LayoutOrder = i
		optionBtns[o.key] = b
		b.Activated:Connect(function()
			state.key = o.key
			for k, ob in pairs(optionBtns) do
				ob.UIStroke.Color = (k == state.key) and WHITE or OUTLINE
				ob.UIStroke.Thickness = (k == state.key) and 5 or 3
			end
		end)
		if o.key == state.key then
			b.UIStroke.Color = WHITE
			b.UIStroke.Thickness = 5
		end
	end
	local variants = state.kind == "egg" or state.kind == "monster"
	sizeBtn.Visible = variants
	finishBtn.Visible = variants
	-- gamepasses / tags: no amount, but they can be given OR removed
	local onOff = state.kind == "pass" or state.kind == "tag"
	removeBtn.Visible = onOff
	amountBox.Visible = not onOff
	amountLabel.Visible = not onOff
	if not onOff then
		state.remove = false
	end
	removeBtn.Text = state.remove and "MODE: REMOVE" or "MODE: GIVE"
	removeBtn.BackgroundColor3 = state.remove and RED or BLUE
end

for i, k in ipairs(KINDS) do
	local b = button(kindRow, k[2], UDim2.new(), UDim2.new(), GRAY)
	b.LayoutOrder = i
	kindBtns[k[1]] = b
	b.Activated:Connect(function()
		state.kind = k[1]
		state.key = nil
		for key, kb in pairs(kindBtns) do
			kb.BackgroundColor3 = key == state.kind and GOLD or GRAY
		end
		renderOptions()
	end)
end
kindBtns.cash.BackgroundColor3 = GOLD

local function cycle(list, current)
	for i, v in ipairs(list) do
		if v.key == current then
			return list[(i % #list) + 1].key
		end
	end
	return list[1].key
end
sizeBtn.Activated:Connect(function()
	state.size = cycle(Config.SizeVariants, state.size)
	sizeBtn.Text = "SIZE: " .. state.size:upper()
end)
finishBtn.Activated:Connect(function()
	state.finish = cycle(Config.FinishVariants, state.finish)
	finishBtn.Text = "FINISH: " .. state.finish:upper()
end)

local targetBtns = {}
local function setTarget(id)
	state.target = id
	for k, tb in pairs(targetBtns) do
		tb.BackgroundColor3 = (k == id) and GOLD or BLUE
	end
	nameBox.UIStroke.Color = targetBtns[id] and OUTLINE or GOLD
end
-- typing a username gives to that ONE player
nameBox.FocusLost:Connect(function()
	local name = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if name ~= "" then
		setTarget(name)
		status.Text = "Giving to: " .. name
		status.TextColor3 = Color3.fromRGB(255, 230, 140)
	end
end)
local function renderTargets()
	for _, c in ipairs(targetRow:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	targetBtns = {}
	local ok, r = pcall(function()
		return adminRemote:InvokeServer("players")
	end)
	local list = { { id = tostring(player.UserId), name = "ME" }, { id = "all", name = "ALL PLAYERS" } }
	if ok and r and r.players then
		for _, p in ipairs(r.players) do
			if p.userId ~= player.UserId then
				table.insert(list, { id = tostring(p.userId), name = p.display })
			end
		end
	end
	for i, t in ipairs(list) do
		local b = button(targetRow, t.name:upper(), UDim2.fromOffset(math.max(90, #t.name * 13 + 30), 38), UDim2.new(), BLUE)
		b.LayoutOrder = i
		targetBtns[t.id] = b
		b.Activated:Connect(function()
			nameBox.Text = ""
			setTarget(t.id)
		end)
	end
	if not targetBtns[state.target] then
		state.target = tostring(player.UserId)
	end
	setTarget(state.target)
end

local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qd = 1e15 }
local function readAmount()
	local t = amountBox.Text:gsub(",", ""):lower()
	local num, suf = t:match("^%s*([%d%.]+)%s*(%a*)%s*$")
	return num and math.floor((tonumber(num) or 0) * (SUFFIX[suf] or 1)) or 0
end

removeBtn.Activated:Connect(function()
	state.remove = not state.remove
	removeBtn.Text = state.remove and "MODE: REMOVE" or "MODE: GIVE"
	removeBtn.BackgroundColor3 = state.remove and RED or BLUE
end)

local notify = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("Notify")
local busy = false
giveBtn.Activated:Connect(function()
	if busy then
		return
	end
	local onOff = state.kind == "pass" or state.kind == "tag"
	local amount = onOff and 1 or readAmount()
	if amount <= 0 then
		status.Text = "Enter an amount."
		status.TextColor3 = Color3.fromRGB(255, 140, 140)
		return
	end
	busy = true
	giveBtn.Text = "GIVING..."
	giveBtn.BackgroundColor3 = GRAY
	status.Text = "Giving..."
	status.TextColor3 = Color3.fromRGB(255, 230, 140)
	local ok, r = pcall(function()
		return adminRemote:InvokeServer("give", { target = state.target, kind = state.kind, key = state.key, amount = amount, size = state.size, finish = state.finish, remove = onOff and state.remove or nil })
	end)
	busy = false
	giveBtn.Text = "GIVE"
	giveBtn.BackgroundColor3 = GREEN
	local good = ok and r and r.success
	local msg = (ok and r and r.message) or "Failed."
	status.Text = msg
	status.TextColor3 = good and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 140, 140)
	-- tell the admin every time (so nothing is given twice by accident)
	notify:Fire((good and "[Admin] " or "[Admin] FAILED: ") .. msg, good and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 120, 120))
	-- clear the amount after every give
	if good then
		amountBox.Text = ""
	end
	-- the status line disappears after 3 seconds
	local shown = msg
	task.delay(3, function()
		if status.Text == shown then
			status.Text = ""
		end
	end)
end)

--------------------------------------------------------------------
-- DEV CHAT tab
--------------------------------------------------------------------
text(chatBody, "MESSAGE TO EVERY SERVER", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 12), { TextColor3 = GOLD })
local preview = text(chatBody, "[Dev]KaidenBYND : ...", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 50), { RichText = true, TextColor3 = WHITE })
local chatBox = mk("TextBox", { Size = UDim2.new(1, -24, 0, 170), Position = UDim2.fromOffset(12, 92), BackgroundColor3 = Color3.fromRGB(236, 240, 255), Text = "", PlaceholderText = "Type your message...", TextWrapped = true, TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = OUTLINE, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ClearTextOnFocus = false, MultiLine = true }, chatBody)
round(chatBox, 10, 3)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chatBox)
local sendBtn = button(chatBody, "SEND", UDim2.fromOffset(180, 54), UDim2.new(0.5, -90, 0, 280), GREEN)
local chatStatus = text(chatBody, "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 346), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
chatBox:GetPropertyChangedSignal("Text"):Connect(function()
	if #chatBox.Text > 200 then
		chatBox.Text = chatBox.Text:sub(1, 200)
	end
	local safe = chatBox.Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	preview.Text = '<font color="#FFD23C">[Dev]</font>KaidenBYND : ' .. (safe ~= "" and safe or "...")
end)
local function send()
	local msg = chatBox.Text
	local ok, r = pcall(function()
		return adminRemote:InvokeServer("chat", msg)
	end)
	chatStatus.Text = (ok and r and r.message) or "Failed."
	chatStatus.TextColor3 = (ok and r and r.success) and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 140, 140)
	if ok and r and r.success then
		chatBox.Text = ""
	end
end
sendBtn.Activated:Connect(send)

--------------------------------------------------------------------
-- EFFECTS tab: server-wide effect in every server
--------------------------------------------------------------------
local fx = { key = "luck", mult = 2 }
local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
text(fxBody, "EFFECT", UDim2.fromOffset(120, 24), UDim2.fromOffset(12, 10), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local fxKindRow = mk("Frame", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 38), BackgroundTransparency = 1 }, fxBody)
mk("UIGridLayout", { CellSize = UDim2.new(1 / #Config.GlobalBoostKinds, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0) }, fxKindRow)
text(fxBody, "MULTIPLIER", UDim2.fromOffset(160, 24), UDim2.fromOffset(12, 88), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local fxMultRow = mk("Frame", { Size = UDim2.new(1, -24, 0, 80), Position = UDim2.fromOffset(12, 116), BackgroundTransparency = 1 }, fxBody)
mk("UIGridLayout", { CellSize = UDim2.new(1 / 8, -6, 0, 37), CellPadding = UDim2.fromOffset(6, 6) }, fxMultRow)
text(fxBody, "TIME", UDim2.fromOffset(80, 24), UDim2.fromOffset(12, 204), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local timeBox = mk("TextBox", { Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(12, 230), BackgroundColor3 = Color3.fromRGB(236, 240, 255), Text = "30m", PlaceholderText = "30m, 2h, 1d", TextScaled = true, Font = FONT, TextColor3 = OUTLINE, ClearTextOnFocus = false }, fxBody)
round(timeBox, 10, 3)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, timeBox)
local presetRow = mk("Frame", { Size = UDim2.new(1, -186, 0, 40), Position = UDim2.fromOffset(174, 230), BackgroundTransparency = 1 }, fxBody)
mk("UIGridLayout", { CellSize = UDim2.new(1 / 6, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0) }, presetRow)
for i, p in ipairs({ "5m", "15m", "30m", "1h", "3h", "1d" }) do
	local b = button(presetRow, p:upper(), UDim2.new(), UDim2.new(), BLUE)
	b.LayoutOrder = i
	b.Activated:Connect(function()
		timeBox.Text = p
	end)
end
local startBtn = button(fxBody, "START", UDim2.fromOffset(180, 46), UDim2.fromOffset(12, 280), GREEN)
local stopBtn = button(fxBody, "STOP THIS EFFECT", UDim2.fromOffset(230, 46), UDim2.fromOffset(204, 280), RED)
local fxStatus = text(fxBody, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 332), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
text(fxBody, "ACTIVE IN EVERY SERVER", UDim2.fromOffset(300, 24), UDim2.fromOffset(12, 358), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local activeLabel = text(fxBody, "none", UDim2.new(1, -24, 0, 56), UDim2.fromOffset(12, 386), { TextScaled = false, TextSize = 18, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })

local fxKindBtns, fxMultBtns = {}, {}
local function paintFx()
	for key, b in pairs(fxKindBtns) do
		b.UIStroke.Color = key == fx.key and WHITE or OUTLINE
		b.UIStroke.Thickness = key == fx.key and 5 or 3
	end
	for m, b in pairs(fxMultBtns) do
		b.BackgroundColor3 = m == fx.mult and GOLD or GRAY
	end
	local k
	for _, kk in ipairs(Config.GlobalBoostKinds) do
		if kk.key == fx.key then
			k = kk
		end
	end
	startBtn.Text = "START " .. fx.mult .. "X"
	stopBtn.Text = "STOP " .. (k and k.name:upper() or "")
end
for i, k in ipairs(Config.GlobalBoostKinds) do
	local b = button(fxKindRow, k.name:upper(), UDim2.new(), UDim2.new(), c3(k.color))
	b.LayoutOrder = i
	fxKindBtns[k.key] = b
	b.Activated:Connect(function()
		fx.key = k.key
		paintFx()
	end)
end
for m = 1, Config.GlobalBoostMax do
	local b = button(fxMultRow, m .. "X", UDim2.new(), UDim2.new(), GRAY)
	b.LayoutOrder = m
	fxMultBtns[m] = b
	b.Activated:Connect(function()
		fx.mult = m
		paintFx()
	end)
end
paintFx()

local UNIT = { s = 1, m = 60, h = 3600, d = 86400 }
local function readTime()
	local total = 0
	local t = timeBox.Text:lower():gsub("%s", "")
	if t:match("^%d+$") then
		return tonumber(t) * 60 -- a plain number = minutes
	end
	for num, unit in t:gmatch("([%d%.]+)(%a)") do
		total += (tonumber(num) or 0) * (UNIT[unit] or 0)
	end
	return math.floor(total)
end
local function sendFx(mult)
	local seconds = readTime()
	if mult > 1 and seconds < 10 then
		fxStatus.Text = "Type a time like 30m, 2h or 1d."
		fxStatus.TextColor3 = Color3.fromRGB(255, 140, 140)
		return
	end
	local ok, r = pcall(function()
		return adminRemote:InvokeServer("effect", { key = fx.key, mult = mult, seconds = seconds })
	end)
	fxStatus.Text = (ok and r and r.message) or "Failed."
	fxStatus.TextColor3 = (ok and r and r.success) and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 140, 140)
end
startBtn.Activated:Connect(function()
	sendFx(fx.mult)
end)
stopBtn.Activated:Connect(function()
	sendFx(1)
end)
task.spawn(function()
	while gui.Parent do
		if fxBody.Visible then
			local now = workspace:GetServerTimeNow()
			local lines = {}
			for _, k in ipairs(Config.GlobalBoostKinds) do
				local m = Config.GlobalBoost(k.key, now)
				if m > 1 then
					local left = math.floor(monsterFolder:GetAttribute("GB_" .. k.key .. "_e") - now)
					table.insert(lines, string.format('<font color="#%s">%dx %s</font>  %d:%02d:%02d', c3(k.color):ToHex(), m, k.name:upper(), left // 3600, (left % 3600) // 60, left % 60))
				end
			end
			activeLabel.Text = #lines > 0 and table.concat(lines, "     ") or "none"
		end
		task.wait(1)
	end
end)

--------------------------------------------------------------------
-- CODES tab: make codes players redeem in the Shop (every server)
--   rewards come from the GIVE tab: pick something + amount, then
--   press + ADD TO CODE
--------------------------------------------------------------------
local draft = {} -- rewards of the code being made
local function rewardName(r)
	local name = r.key or ""
	if r.kind == "cash" then
		return "$" .. Config.FormatNumber(r.amount)
	elseif r.kind == "shards" then
		return Config.FormatNumber(r.amount) .. " Shards"
	elseif r.kind == "egg" then
		name = Config.GetRarity(r.key).name .. " Egg"
	elseif r.kind == "monster" then
		local m = Config.GetMonster(r.key)
		name = m and m.name or r.key
	elseif r.kind == "potion" then
		local p = Config.GetPotion(r.key)
		name = p and p.name or r.key
	elseif r.kind == "item" then
		local it = Config.Items[r.key]
		name = it and it.name or r.key
	elseif r.kind == "gear" then
		local g = Config.GetGear(r.key)
		name = g and g.name or r.key
	end
	local extra = ""
	if r.kind == "egg" or r.kind == "monster" then
		extra = ((r.size and r.size ~= "Normal") and (r.size .. " ") or "") .. ((r.finish and r.finish ~= "Normal") and (r.finish .. " ") or "")
	end
	return Config.FormatNumber(r.amount) .. "x " .. extra .. name
end

local function field(labelText, x, w, placeholder)
	text(codeBody, labelText, UDim2.fromOffset(w, 20), UDim2.fromOffset(x, 8), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
	local box = mk("TextBox", { Size = UDim2.fromOffset(w, 38), Position = UDim2.fromOffset(x, 30), BackgroundColor3 = Color3.fromRGB(236, 240, 255), Text = "", PlaceholderText = placeholder, TextScaled = true, Font = FONT, TextColor3 = OUTLINE, ClearTextOnFocus = false }, codeBody)
	round(box, 10, 3)
	mk("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
	return box
end
local codeBox = field("CODE", 12, 250, "e.g. RELEASE")
local hoursBox = field("EXPIRES IN (HOURS)", 274, 170, "blank = never")
local usesBox = field("MAX USES", 456, 150, "blank = no limit")
codeBox:GetPropertyChangedSignal("Text"):Connect(function()
	local up = codeBox.Text:upper():gsub("[^%w_]", "")
	if up ~= codeBox.Text then
		codeBox.Text = up
	end
end)

text(codeBody, "REWARDS", UDim2.fromOffset(200, 20), UDim2.fromOffset(12, 78), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local draftList = mk("ScrollingFrame", { Size = UDim2.new(1, -24, 0, 118), Position = UDim2.fromOffset(12, 100), BackgroundColor3 = Color3.fromRGB(16, 18, 28), BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, codeBody)
round(draftList, 10, false)
mk("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 34), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, draftList)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }, draftList)
local draftHint = text(codeBody, "Pick rewards in the GIVE tab, then press + ADD TO CODE", UDim2.new(1, -60, 0, 22), UDim2.fromOffset(30, 148), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(170, 176, 200) })

local saveCodeBtn = button(codeBody, "SAVE CODE", UDim2.fromOffset(170, 44), UDim2.fromOffset(12, 226), GREEN)
local clearCodeBtn = button(codeBody, "CLEAR", UDim2.fromOffset(110, 44), UDim2.fromOffset(190, 226), GRAY)
local codeStatus = text(codeBody, "", UDim2.new(1, -324, 0, 40), UDim2.fromOffset(312, 228), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })

text(codeBody, "ACTIVE CODES", UDim2.fromOffset(250, 22), UDim2.fromOffset(12, 280), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local codeList = mk("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -318), Position = UDim2.fromOffset(12, 306), BackgroundColor3 = Color3.fromRGB(16, 18, 28), BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, codeBody)
round(codeList, 10, false)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, codeList)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }, codeList)

local function setCodeStatus(msg, good)
	codeStatus.Text = msg
	codeStatus.TextColor3 = good and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 140, 140)
end

local function renderDraft()
	for _, c in ipairs(draftList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	draftHint.Visible = #draft == 0
	for i, r in ipairs(draft) do
		local row = mk("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(50, 54, 68) }, draftList)
		round(row, 8, 2)
		text(row, rewardName(r), UDim2.new(1, -46, 0.62, 0), UDim2.new(0, 8, 0.19, 0), { TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold })
		-- lowercase "x": a button with the text "X" counts as a window's close button
		local x = button(row, "x", UDim2.fromOffset(28, 28), UDim2.new(1, -31, 0.5, -14), RED)
		x.Activated:Connect(function()
			table.remove(draft, i)
			renderDraft()
		end)
	end
end

local function timeLeft(expires, now)
	if not expires then
		return "never expires"
	end
	local s = expires - now
	if s <= 0 then
		return "EXPIRED"
	elseif s >= 86400 then
		return string.format("%dd %dh left", s // 86400, (s % 86400) // 3600)
	elseif s >= 3600 then
		return string.format("%dh %dm left", s // 3600, (s % 3600) // 60)
	end
	return string.format("%dm left", math.max(1, s // 60))
end

local function renderCodes()
	for _, c in ipairs(codeList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ok, r = pcall(function()
		return adminRemote:InvokeServer("codes_list")
	end)
	if not (ok and r and r.success) then
		text(codeList, "Could not load codes.", UDim2.new(1, 0, 0, 30), UDim2.new(), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
		return
	end
	if #r.codes == 0 then
		text(codeList, "No codes yet.", UDim2.new(1, 0, 0, 30), UDim2.new(), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(170, 176, 200) })
	end
	for i, c in ipairs(r.codes) do
		local row = mk("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.fromRGB(40, 44, 58) }, codeList)
		round(row, 10, 2)
		text(row, c.code, UDim2.new(0.45, 0, 0, 26), UDim2.fromOffset(10, 4), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
		local uses = (c.uses or 0) .. (c.maxUses and ("/" .. c.maxUses) or "") .. " uses  -  " .. timeLeft(c.expires, r.now)
		text(row, uses, UDim2.new(0.5, -10, 0, 20), UDim2.new(0.45, 0, 0, 8), { TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(200, 210, 240) })
		local names = {}
		for _, rw in ipairs(c.rewards or {}) do
			table.insert(names, rewardName(rw))
		end
		text(row, table.concat(names, ", "), UDim2.new(1, -190, 0, 18), UDim2.fromOffset(10, 34), { TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(160, 255, 170) })
		local edit = button(row, "EDIT", UDim2.fromOffset(76, 34), UDim2.new(1, -170, 0.5, -17), BLUE)
		local del = button(row, "DELETE", UDim2.fromOffset(86, 34), UDim2.new(1, -90, 0.5, -17), RED)
		edit.Activated:Connect(function()
			codeBox.Text = c.code
			draft = table.clone(c.rewards or {})
			usesBox.Text = c.maxUses and tostring(c.maxUses) or ""
			hoursBox.Text = c.expires and tostring(math.max(0, math.floor((c.expires - r.now) / 360) / 10)) or ""
			renderDraft()
			setCodeStatus("Editing " .. c.code .. " - change it and press SAVE CODE.", true)
		end)
		local armed = false
		del.Activated:Connect(function()
			if not armed then
				armed = true
				del.Text = "SURE?"
				task.delay(3, function()
					if del.Parent then
						armed = false
						del.Text = "DELETE"
					end
				end)
				return
			end
			local ok2, res = pcall(function()
				return adminRemote:InvokeServer("code_delete", c.code)
			end)
			setCodeStatus((ok2 and res and res.message) or "Failed.", ok2 and res and res.success)
			renderCodes()
		end)
	end
end
onCodesOpened = renderCodes

addToCodeBtn.Activated:Connect(function()
	local kind = state.kind
	if kind == "pass" or kind == "tag" then
		status.Text = "Codes can't give gamepasses or tags."
		status.TextColor3 = Color3.fromRGB(255, 140, 140)
		return
	end
	local amount = readAmount()
	if amount <= 0 then
		status.Text = "Enter an amount."
		status.TextColor3 = Color3.fromRGB(255, 140, 140)
		return
	end
	if #draft >= 12 then
		status.Text = "A code can have up to 12 rewards."
		status.TextColor3 = Color3.fromRGB(255, 140, 140)
		return
	end
	local r = { kind = kind, key = state.key, amount = amount, size = state.size, finish = state.finish }
	table.insert(draft, r)
	renderDraft()
	status.Text = "Added " .. rewardName(r) .. " to the code (" .. #draft .. " rewards). Open CODES to save it."
	status.TextColor3 = Color3.fromRGB(255, 230, 140)
end)

local saving = false
saveCodeBtn.Activated:Connect(function()
	if saving then
		return
	end
	saving = true
	setCodeStatus("Saving...", true)
	local ok, r = pcall(function()
		return adminRemote:InvokeServer("code_save", { code = codeBox.Text, rewards = draft, hours = tonumber(hoursBox.Text), maxUses = tonumber(usesBox.Text) })
	end)
	saving = false
	local good = ok and r and r.success
	setCodeStatus((ok and r and r.message) or "Failed.", good)
	if good then
		draft = {}
		codeBox.Text, hoursBox.Text, usesBox.Text = "", "", ""
		renderDraft()
		renderCodes()
	end
end)
clearCodeBtn.Activated:Connect(function()
	draft = {}
	codeBox.Text, hoursBox.Text, usesBox.Text = "", "", ""
	renderDraft()
	setCodeStatus("", true)
end)
renderDraft()

--------------------------------------------------------------------
-- open / close
--------------------------------------------------------------------
local function open()
	renderTargets()
	renderOptions()
	local v = workspace.CurrentCamera.ViewportSize
	local fit = math.min(1, (v.Y - 90) / H, (v.X - 30) / W)
	mainScale.Scale = fit * 0.85
	main.Visible = true
	TweenService:Create(mainScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = fit }):Play()
end
openBtn.Activated:Connect(function()
	if main.Visible then
		main.Visible = false
	else
		open()
	end
end)
closeBtn.Activated:Connect(function()
	main.Visible = false
end)
