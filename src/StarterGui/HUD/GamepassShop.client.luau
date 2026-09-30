local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

--------------------------------------------------------------------
-- Gamepass Shop (HUD > Shop) + the TAG choice in Settings.
-- Cards come from Config.Gamepasses; put each icon in its imageId.
--------------------------------------------------------------------

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local saveSettingsRemote = remotes:WaitForChild("SaveSettings")

local gui = script.Parent
local panel = gui:WaitForChild("Panels"):WaitForChild("ShopPanel")
local body = panel:WaitForChild("Body")
local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local GREEN, GRAY = Color3.fromRGB(60, 205, 95), Color3.fromRGB(110, 118, 140)

local profile = profileRemote:InvokeServer()

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function label(parent, text, size, pos, props)
	local l = mk("TextLabel", { Size = size, Position = pos, BackgroundTransparency = 1, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

local confirmBridge = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("ConfirmPurchase")
local GOLD = Color3.fromRGB(255, 225, 120)
local TweenService = game:GetService("TweenService")

-- the studded tab look (optional: without it the tabs keep their colors)
local UIStyle
do
	local mod = monsterFolder:WaitForChild("UIStyle", 5)
	local ok, res = pcall(function()
		return mod and require(mod)
	end)
	UIStyle = ok and res or nil
end

-- category buttons in a column on the left, like the Backpack (they only
-- scroll the list, nothing disappears; the one you're looking at lights up)
local SIDE_W = 150
if not panel:GetAttribute("SideFilters") then
	panel:SetAttribute("SideFilters", true)
	panel.Size = UDim2.new(panel.Size.X.Scale, panel.Size.X.Offset + 60, panel.Size.Y.Scale, panel.Size.Y.Offset)
end
local tabs = mk("Frame", { Name = "Categories", Size = UDim2.new(0, SIDE_W, 1, -8), Position = UDim2.fromOffset(0, 8), BackgroundTransparency = 1 }, body)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)

local list = mk("ScrollingFrame", { Name = "PassList", Size = UDim2.new(1, -(SIDE_W + 10), 1, -8), Position = UDim2.fromOffset(SIDE_W + 10, 8), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, list)

local order = 0
local sectionTabs = {}
local function section(titleText, tabColor)
	order += 1
	local header = label(list, titleText, UDim2.new(1, 0, 0, 34), UDim2.new(), { LayoutOrder = order, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
	order += 1
	local grid = mk("Frame", { Name = titleText, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, list)
	mk("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 240), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	-- its category button
	local tab = mk("TextButton", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = tabColor, Text = "", AutoButtonColor = false }, tabs)
	tab:SetAttribute("NoStuds", true)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, tab)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tab)
	label(tab, titleText, UDim2.new(1, -32, 0.5, 0), UDim2.new(0, 22, 0.25, 0), { Name = "Label", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = tabColor:Lerp(WHITE, 0.35), ZIndex = tab.ZIndex + 2 })
	table.insert(sectionTabs, { tab = tab, header = header, color = tabColor })
	tab.Activated:Connect(function()
		local y = header.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 4
		local maxY = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
		TweenService:Create(list, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, math.clamp(y, 0, maxY)) }):Play()
	end)
	return grid
end

local function card(parent, i, key, titleText, infoText, imageId, fallback, colors)
	local c = mk("Frame", { Name = key, LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(30, 54, 118) }, parent)
	mk("UICorner", { CornerRadius = UDim.new(0, 16) }, c)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, c)
	mk("UIGradient", { Color = ColorSequence.new(colors[1], colors[2]), Rotation = 90 }, c)
	-- big image, no circle behind it
	if imageId and imageId ~= "" then
		mk("ImageLabel", { Size = UDim2.fromOffset(118, 118), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), BackgroundTransparency = 1, Image = imageId, ScaleType = Enum.ScaleType.Fit }, c)
	else
		label(c, fallback, UDim2.fromOffset(90, 70), UDim2.new(0.5, -45, 0, 26))
	end
	label(c, string.upper(titleText), UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 122), { TextColor3 = GOLD })
	local info = label(c, infoText, UDim2.new(1, -16, 0, 42), UDim2.fromOffset(8, 148), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(220, 232, 255) })
	local btn = mk("TextButton", { Size = UDim2.new(1, -24, 0, 38), Position = UDim2.new(0, 12, 1, -46), BackgroundColor3 = GREEN, Text = "BUY", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, c)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, btn)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
	mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, btn)
	return c, btn, info
end

local function fetchPrice(kind, id, callback)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			callback(info.PriceInRobux)
		end
	end)
end

-- GAMEPASSES --------------------------------------------------------
local BLUE = { Color3.fromRGB(70, 120, 230), Color3.fromRGB(30, 54, 130) }
local passGrid = section("GAMEPASSES", Color3.fromRGB(60, 120, 235))
local cards = {}
for i, pass in ipairs(Config.Gamepasses) do
	local _, btn = card(passGrid, i, pass.key, pass.name, table.concat(pass.perks, "\n"), pass.imageId, string.upper(pass.name:sub(1, 2)), BLUE)
	cards[pass.key] = { btn = btn, price = nil }
	btn.Activated:Connect(function()
		if not Config.HasPass(profile, pass.key) then
			confirmBridge:Fire({ kind = "pass", id = pass.id, title = pass.name, desc = table.concat(pass.perks, "\n"), image = pass.imageId })
		end
	end)
	fetchPrice("pass", pass.id, function(price)
		cards[pass.key].price = price
		if not Config.HasPass(profile, pass.key) then
			btn.Text = "\u{E002} " .. price
		end
	end)
end

-- CASH (grows with your rebirths) ------------------------------------
local GREENS = { Color3.fromRGB(70, 200, 110), Color3.fromRGB(25, 95, 60) }
local cashGrid = section("CASH", Color3.fromRGB(50, 190, 90))
local cashCards = {}
for i, pack in ipairs(Config.Products.cash) do
	local _, btn, info = card(cashGrid, i, pack.key, pack.name, "", pack.imageId, "$", GREENS)
	cashCards[pack.key] = { info = info, pack = pack }
	btn.Activated:Connect(function()
		confirmBridge:Fire({
			kind = "product",
			id = pack.id,
			title = pack.name,
			image = pack.imageId,
			fallback = "$",
			bigText = "+" .. Config.FormatNumber(Config.CashPackAmount(profile, pack.pct)) .. " CASH",
		})
	end)
	fetchPrice("product", pack.id, function(price)
		btn.Text = "\u{E002} " .. price
	end)
end

local function render()
	for key, c in pairs(cards) do
		local owned = Config.HasPass(profile, key)
		c.btn.BackgroundColor3 = owned and GRAY or GREEN
		c.btn.Text = owned and "OWNED" or (c.price and ("\u{E002} " .. c.price) or "BUY")
	end
	for _, c in pairs(cashCards) do
		c.info.Text = "+" .. Config.FormatNumber(Config.CashPackAmount(profile, c.pack.pct)) .. " Cash"
		c.info.TextColor3 = Color3.fromRGB(150, 255, 170)
		c.info.Font = FONT
		c.info.TextStrokeTransparency = 0
	end
end
render()

--------------------------------------------------------------------
-- Settings: TAG. Tap it to pick from every tag you own (DEV, ADMIN,
-- TESTER, BETA, VIP, SUPPORTER) or NONE.
--------------------------------------------------------------------
task.spawn(function()
	local sBody = gui.Panels:WaitForChild("SettingsPanel"):WaitForChild("Body")
	local template = sBody:WaitForChild("OwnPets")
	local row = mk("Frame", { Name = "TagRow", Size = template.Size, LayoutOrder = 9, BackgroundTransparency = template.BackgroundTransparency, BackgroundColor3 = template.BackgroundColor3, Visible = false, ZIndex = 5 }, sBody)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
	-- same layout as the other settings rows
	local tagLabel = label(row, "TAG", UDim2.new(0.45, 0, 0.6, 0), UDim2.new(0, 16, 0.5, 0), { TextXAlignment = Enum.TextXAlignment.Left })
	tagLabel.AnchorPoint = Vector2.new(0, 0.5)
	local pick = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(150, 42), Position = UDim2.new(1, -10, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 205, 60), Text = "NONE", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 6 }, row)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, pick)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pick)
	mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, pick)

	-- the choice list opens over the settings panel
	local panelFrame = gui.Panels:WaitForChild("SettingsPanel")
	local chooser = mk("Frame", { Name = "TagChooser", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.6, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(25, 40, 90), Visible = false, ZIndex = 50 }, panelFrame)
	mk("UICorner", { CornerRadius = UDim.new(0, 14) }, chooser)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, chooser)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, chooser)
	mk("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chooser)

	local function colorOf(key)
		local info = Config.PassTags[key]
		return info and Color3.fromRGB(info.color[1], info.color[2], info.color[3]) or GRAY
	end
	local function update()
		row.Visible = player:GetAttribute("TagChoices") ~= nil
		local key = player:GetAttribute("Tag")
		local info = key and Config.PassTags[key]
		pick.Text = info and info.text or "NONE"
		pick.BackgroundColor3 = info and colorOf(key) or GRAY
	end
	local function choose(key)
		chooser.Visible = false
		pcall(function()
			saveSettingsRemote:InvokeServer({ chatTag = key })
		end)
		task.wait(0.2)
		update()
	end
	local function openChooser()
		for _, c in ipairs(chooser:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		label(chooser, "CHOOSE TAG", UDim2.new(1, 0, 0, 30), UDim2.new(), { LayoutOrder = 0, ZIndex = 51, TextColor3 = Color3.fromRGB(255, 225, 120) })
		local keys = string.split(player:GetAttribute("TagChoices") or "", ",")
		table.insert(keys, "none")
		for i, key in ipairs(keys) do
			if key ~= "" then
				local info = Config.PassTags[key]
				local b = mk("TextButton", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = colorOf(key), Text = info and info.text or "NONE", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 51 }, chooser)
				mk("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
				mk("UIStroke", { Color = (player:GetAttribute("Tag") or "none") == key and WHITE or OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
				mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
				b.Activated:Connect(function()
					choose(key)
				end)
			end
		end
		chooser.Visible = true
	end
	pick.Activated:Connect(function()
		if chooser.Visible then
			chooser.Visible = false
		else
			openChooser()
		end
	end)
	panelFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panelFrame.Visible then
			chooser.Visible = false
		end
	end)
	player:GetAttributeChangedSignal("Tag"):Connect(update)
	player:GetAttributeChangedSignal("TagChoices"):Connect(update)
	update()
end)

-- CODES (the last section): type a code the dev made, get its rewards --
do
	local redeemRemote = remotes:FindFirstChild("RedeemCode")
	local codeGrid = section("CODES", Color3.fromRGB(235, 90, 200))
	local layout = codeGrid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout:Destroy()
	end
	local box = mk("Frame", { Name = "CodeCard", Size = UDim2.new(1, -4, 0, 150), BackgroundColor3 = Color3.fromRGB(28, 31, 42) }, codeGrid)
	mk("UICorner", { CornerRadius = UDim.new(0, 16) }, box)
	mk("UIStroke", { Color = Color3.fromRGB(235, 90, 200), Thickness = 4 }, box)
	label(box, "REDEEM A CODE", UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 12), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 150, 230) })
	label(box, "Codes are posted in our group and socials. Each code works once!", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 44), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 208, 230) })
	local input = mk("TextBox", { Size = UDim2.new(1, -210, 0, 48), Position = UDim2.fromOffset(16, 72), BackgroundColor3 = Color3.fromRGB(236, 240, 255), Text = "", PlaceholderText = "Enter code...", TextScaled = true, Font = FONT, TextColor3 = OUTLINE, PlaceholderColor3 = Color3.fromRGB(140, 146, 170), ClearTextOnFocus = false }, box)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, input)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, input)
	mk("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, input)
	local redeem = mk("TextButton", { Size = UDim2.fromOffset(170, 48), Position = UDim2.new(1, -186, 0, 72), BackgroundColor3 = GREEN, Text = "REDEEM", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, box)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, redeem)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, redeem)
	mk("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9) }, redeem)
	local result = label(box, "", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 124), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local busy = false
	local function tryRedeem()
		redeemRemote = redeemRemote or remotes:FindFirstChild("RedeemCode")
		if busy or not redeemRemote then
			return
		end
		local code = input.Text:gsub("%s", "")
		if code == "" then
			result.Text = "Type a code first."
			result.TextColor3 = Color3.fromRGB(255, 140, 140)
			return
		end
		busy = true
		redeem.Text = "..."
		local ok, r = pcall(function()
			return redeemRemote:InvokeServer(code)
		end)
		busy = false
		redeem.Text = "REDEEM"
		local good = ok and r and r.success
		result.Text = (ok and r and r.message) or "Something went wrong. Try again."
		result.TextColor3 = good and Color3.fromRGB(140, 255, 150) or Color3.fromRGB(255, 140, 140)
		if good then
			input.Text = ""
		end
	end
	redeem.Activated:Connect(tryRedeem)
	input.FocusLost:Connect(function(enter)
		if enter then
			tryRedeem()
		end
	end)
end

-- light up the category you're looking at
local activeTab
local function updateTabs()
	local current = sectionTabs[1]
	for _, t in ipairs(sectionTabs) do
		if t.header.AbsolutePosition.Y - list.AbsolutePosition.Y <= 60 then
			current = t
		end
	end
	-- scrolled all the way down: the last section (CODES is short)
	local maxY = list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y
	if maxY > 0 and list.CanvasPosition.Y >= maxY - 4 then
		current = sectionTabs[#sectionTabs]
	end
	if current == activeTab then
		return
	end
	activeTab = current
	for _, t in ipairs(sectionTabs) do
		if UIStyle and UIStyle.sideTab then
			pcall(UIStyle.sideTab, t.tab, t == current, t.color)
		else
			t.tab.BackgroundTransparency = t == current and 0 or 0.35
		end
	end
end
list:GetPropertyChangedSignal("CanvasPosition"):Connect(updateTabs)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		task.defer(function()
			activeTab = nil
			updateTabs()
		end)
	end
end)
task.defer(updateTabs)

profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
	render()
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, _, bought)
	if plr == player and bought then
		task.wait(1)
		local ok, p = pcall(function()
			return profileRemote:InvokeServer()
		end)
		if ok and p then
			profile = p
			render()
		end
	end
end)
