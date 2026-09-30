local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--------------------------------------------------------------------
-- Upgrade Tree: a honeycomb of hexagons. The 6 branches grow out from
-- the center in the 6 hex directions; each stat is a row of tiers.
--   blue hex  = you can buy it      gold hex = owned
--   dark "?"  = locked (buy the tier before it first)
-- PC: hover a hex for its info, click to buy, hold LEFT (or right) mouse
-- and drag to move. Phone: tap a hex for its info + BUY, drag to move.
-- Hexes near the cursor grow a little, squish when clicked, and pop in
-- like a ripple when a page opens.
-- All numbers come from Config (UpgradeBranches / UpgradeNodes).
--------------------------------------------------------------------

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local openBridge = bridge:WaitForChild("OpenUpgrades")
local closeBridge = bridge:WaitForChild("CloseUpgrades")
local closeAllBridge = bridge:WaitForChild("CloseAll")
local notify = bridge:FindFirstChild("Notify")

local gui = script.Parent
local profile = profileRemote:InvokeServer()

local OUTLINE = Color3.fromRGB(12, 16, 34)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local BLUE, BLUE_DARK = Color3.fromRGB(40, 150, 255), Color3.fromRGB(24, 96, 200)
local GOLD, GOLD_DARK = Color3.fromRGB(255, 205, 60), Color3.fromRGB(215, 150, 30)
-- like the example: owned = cyan, can buy = dark slate, locked = dark "?"
local OWNED, OWNED_DARK = Color3.fromRGB(40, 200, 255), Color3.fromRGB(20, 150, 215)
local CANBUY, CANBUY_DARK = Color3.fromRGB(70, 76, 96), Color3.fromRGB(48, 52, 68)
local LOCKED, LOCKED_DARK = Color3.fromRGB(62, 66, 82), Color3.fromRGB(44, 46, 60)
local GREEN, RED, GRAY = Color3.fromRGB(60, 205, 95), Color3.fromRGB(235, 55, 65), Color3.fromRGB(110, 118, 140)

local TILE = 134 -- hex size (px, point to point)
local SPACING = TILE / 2 -- grid radius = hex radius, so the hexes touch (no gaps)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
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

-- a hexagon (pointy top) made of 3 rotated rectangles
local function hexShape(parent, size, color, z)
	local holder = mk("Frame", { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = z }, parent)
	local r = size / 2
	for i = 0, 2 do
		mk("Frame", {
			Name = "Piece",
			Size = UDim2.fromOffset(r, r * math.sqrt(3)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = i * 60,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
	end
	return holder
end
local function paintHex(holder, color)
	for _, p in ipairs(holder:GetChildren()) do
		p.BackgroundColor3 = color
	end
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local dim = mk("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 12, 28), BackgroundTransparency = 0.55, Visible = false, ZIndex = 1 }, gui)

-- the honeycomb area (drag to move)
local view = mk("Frame", { Name = "View", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Active = true }, dim)
dim.Active = true
local canvas = mk("Frame", { Name = "Canvas", Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2 }, view)
local zoom = mk("UIScale", { Scale = 1 }, canvas)

-- top bar: cash + shards
local top = mk("Frame", { Size = UDim2.new(0, 420, 0, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(20, 26, 52), BackgroundTransparency = 0.1, ZIndex = 20 }, dim)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, top)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, top)
local cashText = label(top, "", UDim2.new(0.5, -20, 0.7, 0), UDim2.new(0, 14, 0.15, 0), { TextColor3 = Color3.fromRGB(140, 255, 150), ZIndex = 21, TextXAlignment = Enum.TextXAlignment.Left })
local shardText = label(top, "", UDim2.new(0.5, -20, 0.7, 0), UDim2.new(0.5, 6, 0.15, 0), { TextColor3 = Color3.fromRGB(150, 210, 255), ZIndex = 21, TextXAlignment = Enum.TextXAlignment.Right })
label(dim, "UPGRADES", UDim2.fromOffset(260, 34), UDim2.new(0.5, -130, 0, 66), { ZIndex = 20, TextColor3 = Color3.fromRGB(255, 220, 110) })

-- zoom buttons
local function roundButton(text, pos, color)
	local b = mk("TextButton", { Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(1, 0.5), Position = pos, BackgroundColor3 = color, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 20 }, dim)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end


-- big red CLOSE button
local closeBtn = mk("TextButton", { Size = UDim2.fromOffset(190, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), BackgroundColor3 = RED, Text = "CLOSE", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 20 }, dim)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, closeBtn)
mk("UIStroke", { Color = OUTLINE, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, closeBtn)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, closeBtn)

-- info popup
local info = mk("Frame", { Name = "Info", Size = UDim2.fromOffset(290, 150), BackgroundColor3 = Color3.fromRGB(18, 20, 34), BackgroundTransparency = 0.05, Visible = false, ZIndex = 30 }, dim)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, info)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, info)
local infoTitle = label(info, "", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 8), { ZIndex = 31 })
local infoDesc = label(info, "", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 40), { ZIndex = 31, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(215, 225, 245), TextStrokeTransparency = 1 })
local infoStatus = label(info, "", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 82), { ZIndex = 31 })
local buyBtn = mk("TextButton", { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 106), BackgroundColor3 = GREEN, Text = "BUY", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 31 }, info)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, buyBtn)
mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, buyBtn)
mk("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, buyBtn)

-- small hover tooltip (PC): name, effect, price / status
local tip = mk("Frame", { Name = "Tooltip", Size = UDim2.fromOffset(200, 72), BackgroundColor3 = Color3.fromRGB(18, 20, 34), BackgroundTransparency = 0.05, Visible = false, ZIndex = 40 }, dim)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, tip)
mk("UIStroke", { Color = Color3.fromRGB(230, 235, 250), Thickness = 2 }, tip)
local tipTitle = label(tip, "", UDim2.new(1, -14, 0, 24), UDim2.fromOffset(7, 5), { ZIndex = 41 })
local tipEffect = label(tip, "", UDim2.new(1, -14, 0, 18), UDim2.fromOffset(7, 30), { ZIndex = 41, TextColor3 = Color3.fromRGB(120, 255, 140) })
local tipStatus = label(tip, "", UDim2.new(1, -14, 0, 16), UDim2.fromOffset(7, 51), { ZIndex = 41 })

-- red / green message ("You don't have enough money to buy this upgrade!")
local msg = label(dim, "", UDim2.new(0.8, 0, 0, 34), UDim2.new(0.1, 0, 0.62, 0), { ZIndex = 45, Visible = false })
mk("UITextSizeConstraint", { MaxTextSize = 30 }, msg)
local msgToken
local function flash(text, color)
	local token = {}
	msgToken = token
	msg.Text = text
	msg.TextColor3 = color
	msg.TextTransparency = 0
	msg.TextStrokeTransparency = 0
	msg.Visible = true
	task.delay(1.6, function()
		if msgToken == token then
			TweenService:Create(msg, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local panMoved = false -- the current press turned into a drag: it's not a click
local offset = Vector2.new(0, 0) -- drag position (the hex at 0,0 starts in the middle)
local applyOffset -- set in the move section below

--------------------------------------------------------------------
-- build: category view (6 categories around the center) and a vein view
-- per category (each upgrade grows as a twisting vein; only what you've
-- reached is shown, plus one "?" step ahead)
--------------------------------------------------------------------
local DIRS = { { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 } }
local function hexToPixel(q, r)
	-- flat-top hexagons (matches the hexShape pieces)
	return SPACING * 1.5 * q, SPACING * math.sqrt(3) * (r + q / 2)
end

local tiles = {} -- node id -> tile (only in the vein view)
local selected
local currentBranch -- nil = category view

local function statusOf(node)
	local owned = profile and profile.upgrades and profile.upgrades[node.id]
	if owned then
		return "owned"
	end
	if node.requires and not (profile and profile.upgrades and profile.upgrades[node.requires]) then
		return "locked"
	end
	return "available"
end

local function nodeText(node)
	local statInfo = Config.UpgradeStatInfo[node.statKey] or { name = node.statKey, unit = "" }
	return statInfo.name, string.format("+%s%s %s (Tier %d/%d)", tostring(node.value), statInfo.unit or "", statInfo.name, node.tier, Config.GetUpgradeTierCount(node.statKey))
end

local function showInfo(node)
	selected = node
	local tile = tiles[node.id]
	if not tile then
		return
	end
	local name, desc = nodeText(node)
	local st = statusOf(node)
	infoTitle.Text = st == "locked" and "???" or name:upper()
	infoDesc.Text = st == "locked" and "Buy the tier before it to reveal this upgrade." or desc
	if st == "owned" then
		infoStatus.Text = "OWNED"
		infoStatus.TextColor3 = Color3.fromRGB(140, 255, 150)
		buyBtn.Visible = false
		info.Size = UDim2.fromOffset(290, 112)
	elseif st == "locked" then
		infoStatus.Text = "LOCKED"
		infoStatus.TextColor3 = Color3.fromRGB(170, 176, 196)
		buyBtn.Visible = false
		info.Size = UDim2.fromOffset(290, 112)
	else
		local canPay = (profile and profile.cash or 0) >= node.cost
		infoStatus.Text = Config.FormatNumber(node.cost)
		infoStatus.TextColor3 = canPay and Color3.fromRGB(255, 220, 110) or Color3.fromRGB(255, 120, 120)
		buyBtn.Visible = true
		buyBtn.Text = canPay and "BUY" or ("NEED " .. Config.FormatNumber(node.cost))
		buyBtn.BackgroundColor3 = canPay and GREEN or GRAY
		info.Size = UDim2.fromOffset(290, 150)
	end
	local abs = tile.holder.AbsolutePosition + tile.holder.AbsoluteSize / 2
	local v = workspace.CurrentCamera.ViewportSize
	info.Position = UDim2.fromOffset(math.clamp(abs.X + 60, 10, v.X - 300), math.clamp(abs.Y - 60, 70, v.Y - 170))
	info.Visible = true
end

local allTiles = {} -- every tile on screen (for the honeycomb animation)
local rippleIn = false -- the next page build pops in as a ripple (only when a page opens)
-- one hex tile (outline + fill + inner, optional custom image, labels)
local function makeTile(x, y, fillColor, innerColor, imageId)
	local holder = mk("TextButton", { Size = UDim2.fromOffset(TILE, TILE), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, canvas)
	local outline = hexShape(holder, TILE, Color3.fromRGB(245, 248, 255), 3)
	local fill = hexShape(holder, TILE - 10, fillColor, 4)
	local inner = hexShape(holder, TILE - 30, innerColor, 5)
	local image
	if imageId and imageId ~= "" then
		image = mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = imageId, ScaleType = Enum.ScaleType.Fit, ZIndex = 6 }, holder)
		outline.Visible, fill.Visible, inner.Visible = false, false, false
	elseif (Config.UIHexStudsImage or "") ~= "" then
		-- studs on the hex (same cartoony studs as the windows)
		mk("ImageLabel", { Name = "Studs", Size = UDim2.fromOffset(TILE - 10, TILE - 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Image = Config.UIHexStudsImage, ImageTransparency = 0.5, ZIndex = 5 }, holder)
	end
	local scale = mk("UIScale", { Scale = 0 }, holder)
	local t = { holder = holder, fill = fill, inner = inner, image = image, scale = scale, pop = rippleIn and 0 or 1, mag = 1, press = 1 }
	scale.Scale = t.pop
	-- pops in like a ripple from the middle
	task.delay(math.sqrt(x * x + y * y) * 0.0012, function()
		if t.pop >= 1 then
			return
		end
		local start = os.clock()
		while holder.Parent do
			local k = math.clamp((os.clock() - start) / 0.28, 0, 1)
			local c = 1.7 -- back-out ease: overshoots a little, then settles
			t.pop = 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
			if k >= 1 then
				t.pop = 1
				break
			end
			task.wait()
		end
	end)
	-- squish while pressed
	holder.MouseButton1Down:Connect(function()
		t.press = 0.9
	end)
	holder.MouseButton1Up:Connect(function()
		t.press = 1
	end)
	holder.MouseLeave:Connect(function()
		if t.press < 1 then
			t.press = 1
		end
	end)
	table.insert(allTiles, t)
	return t
end

local GAP = 1.5 -- hexes sit apart, joined by veins
local function veinLine(x1, y1, x2, y2, color)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local line = mk("Frame", {
		Name = "Vein",
		Size = UDim2.fromOffset(len, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, canvas)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, line)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, line)
	return line
end

local function clearCanvas()
	for _, c in ipairs(canvas:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	tiles = {}
	allTiles = {}
	info.Visible = false
	tip.Visible = false
end

local branchCounts = function(branch)
	local owned, total = 0, 0
	for _, node in ipairs(Config.UpgradeNodes) do
		if table.find(branch.stats, node.statKey) then
			total += 1
			if profile and profile.upgrades and profile.upgrades[node.id] then
				owned += 1
			end
		end
	end
	return owned, total
end

local backBtn -- shown in the vein view
local openBranch
local showTip, buyNode
local dragging -- set by the move section below

-- category view: the 6 categories around the center hex
local function buildCategories()
	currentBranch = nil
	clearCanvas()
	if backBtn then
		backBtn.Visible = false
	end
	local c = makeTile(0, 0, Color3.fromRGB(255, 120, 60), Color3.fromRGB(215, 90, 40))
	label(c.holder, "UP\nGRADES", UDim2.fromScale(0.7, 0.42), UDim2.fromScale(0.15, 0.29), { ZIndex = 7 })
	for bi, branch in ipairs(Config.UpgradeBranches) do
		local d = DIRS[((bi - 1) % 6) + 1]
		local x, y = hexToPixel(d[1], d[2])
		x, y = x * GAP, y * GAP
		local owned, total = branchCounts(branch)
		local t = makeTile(x, y, owned > 0 and OWNED or CANBUY, owned > 0 and OWNED_DARK or CANBUY_DARK, branch.imageId)
		label(t.holder, branch.name:upper(), UDim2.fromScale(0.86, 0.2), UDim2.fromScale(0.07, 0.3), { ZIndex = 7 })
		label(t.holder, owned .. "/" .. total, UDim2.fromScale(0.5, 0.16), UDim2.fromScale(0.25, 0.56), { ZIndex = 7, TextColor3 = Color3.fromRGB(255, 240, 200) })
		t.holder.Activated:Connect(function()
			if not panMoved then
				openBranch(bi)
				rippleIn = false
			end
		end)
	end
end

-- vein layout for one category: every upgrade grows outward from the
-- BACK hex in its OWN direction (its own slice of the circle), so the
-- tiers of one upgrade touch each other in a chain while different
-- upgrades split apart and never touch (only their first tiers sit
-- around the BACK hex). No lines, no gaps inside a chain.
local veinCache = {}
local function veinLayout(bi)
	if veinCache[bi] then
		return veinCache[bi]
	end
	local branch = Config.UpgradeBranches[bi]
	local rng = Random.new(1000 + bi * 37)
	local owner = { ["0,0"] = "__center" } -- cell -> which upgrade owns it
	local function key(q, r)
		return q .. "," .. r
	end
	local function angleOf(q, r)
		local x, y = hexToPixel(q, r)
		return math.atan2(y, x)
	end
	local function angDiff(a1, a2)
		local d = (a1 - a2) % (2 * math.pi)
		return d > math.pi and 2 * math.pi - d or d
	end
	local function ring(q, r)
		return math.max(math.abs(q), math.abs(r), math.abs(q + r))
	end
	-- free for `stat`: empty, touches only its own previous tier, never
	-- another upgrade or the BACK hex
	local function freeFor(stat, q, r, prevQ, prevR)
		if owner[key(q, r)] then
			return false
		end
		for _, d in ipairs(DIRS) do
			local nq, nr = q + d[1], r + d[2]
			local o = owner[key(nq, nr)]
			if o and o ~= stat then
				return false
			end
			if o == stat and not (nq == prevQ and nr == prevR) then
				return false
			end
		end
		return true
	end
	local layout = {}
	local k = #branch.stats
	-- spread the directions as far apart as possible
	local dirsFor = ({ { 1 }, { 1, 4 }, { 1, 3, 5 }, { 1, 2, 4, 5 }, { 1, 2, 3, 4, 5 }, { 1, 2, 3, 4, 5, 6 } })[math.min(k, 6)]
	local halfWidth = math.max(math.rad(20), math.rad(360 / math.max(k, 1) / 2 - 22))
	for si, statKey in ipairs(branch.stats) do
		local nodes = {}
		for _, node in ipairs(Config.UpgradeNodes) do
			if node.statKey == statKey then
				table.insert(nodes, node)
			end
		end
		table.sort(nodes, function(x, y)
			return x.tier < y.tier
		end)
		local rayIndex = ((dirsFor[((si - 1) % #dirsFor) + 1] - 1 + (bi % 2)) % 6) + 1
		local ray = DIRS[rayIndex]
		local rayAngle = angleOf(ray[1], ray[2])
		local q, r = ray[1], ray[2] -- the first tier touches the BACK hex
		local pq, pr
		for n, node in ipairs(nodes) do
			if n > 1 then
				-- mostly straight out, sometimes a small bend, but always
				-- inside its own slice and moving away from the middle
				local order = rng:NextNumber() < 0.55 and { 0, 1, -1 } or (rng:NextNumber() < 0.5 and { 1, 0, -1 } or { -1, 0, 1 })
				local placed = false
				for _, t in ipairs(order) do
					local d = DIRS[((rayIndex - 1 + t) % 6) + 1]
					local nq, nr = q + d[1], r + d[2]
					if ring(nq, nr) > ring(q, r) and angDiff(angleOf(nq, nr), rayAngle) <= halfWidth and freeFor(statKey, nq, nr, q, r) then
						pq, pr = q, r
						q, r = nq, nr
						placed = true
						break
					end
				end
				if not placed then
					pq, pr = q, r
					q, r = q + ray[1], r + ray[2]
				end
			end
			owner[key(q, r)] = statKey
			layout[node.id] = { q, r }
		end
	end
	veinCache[bi] = layout
	return layout
end

-- what's visible in a vein: owned, the next buyable, and one "?" after that
local function visibility(node)
	local st = statusOf(node)
	if st ~= "locked" then
		return st
	end
	-- locked: show as "?" only if the tier before it is buyable right now
	for _, other in ipairs(Config.UpgradeNodes) do
		if other.id == node.requires then
			return statusOf(other) == "available" and "locked" or nil
		end
	end
	return nil
end

local function paintTile(node)
	local t = tiles[node.id]
	if not t then
		return
	end
	local st = visibility(node)
	t.holder.Visible = st ~= nil
	if t.vein then
		t.vein.Visible = st ~= nil
		t.vein.BackgroundColor3 = st == "owned" and OWNED or (st == "available" and Color3.fromRGB(70, 150, 255) or LOCKED)
	end
	if not st then
		return
	end
	if t.image then
		t.image.ImageColor3 = st == "owned" and Color3.fromRGB(255, 225, 140) or (st == "available" and WHITE or Color3.fromRGB(85, 88, 104))
	elseif st == "owned" then
		paintHex(t.fill, OWNED)
		paintHex(t.inner, OWNED_DARK)
	elseif st == "available" then
		paintHex(t.fill, CANBUY)
		paintHex(t.inner, CANBUY_DARK)
	else
		paintHex(t.fill, LOCKED)
		paintHex(t.inner, LOCKED_DARK)
	end
	t.question.Visible = st == "locked"
	t.name.Visible = st ~= "locked"
	t.cost.Visible = st == "available"
	local canPay = (profile and profile.cash or 0) >= node.cost
	t.cost.TextColor3 = canPay and Color3.fromRGB(255, 220, 110) or Color3.fromRGB(255, 70, 70)
end

-- hover tooltip next to a hex
showTip = function(node, t)
	local name = nodeText(node)
	local st = statusOf(node)
	tip:SetAttribute("For", node.id)
	if st == "locked" then
		tipTitle.Text = "???"
		tipEffect.Text = "Buy the tier before it"
		tipEffect.TextColor3 = Color3.fromRGB(170, 176, 196)
		tipStatus.Text = "LOCKED"
		tipStatus.TextColor3 = Color3.fromRGB(170, 176, 196)
	else
		local statInfo = Config.UpgradeStatInfo[node.statKey] or { unit = "" }
		tipTitle.Text = name:upper() .. " " .. node.tier
		tipEffect.Text = "+" .. tostring(node.value) .. (statInfo.unit or "") .. " " .. name
		tipEffect.TextColor3 = Color3.fromRGB(120, 255, 140)
		if st == "owned" then
			tipStatus.Text = "OWNED"
			tipStatus.TextColor3 = Color3.fromRGB(120, 220, 255)
		else
			local canPay = (profile and profile.cash or 0) >= node.cost
			tipStatus.Text = "$" .. Config.FormatNumber(node.cost) .. (canPay and "  -  CLICK TO BUY" or "")
			tipStatus.TextColor3 = canPay and Color3.fromRGB(255, 220, 110) or Color3.fromRGB(255, 110, 110)
		end
	end
	local abs = t.holder.AbsolutePosition + t.holder.AbsoluteSize / 2
	local v = workspace.CurrentCamera.ViewportSize
	tip.Position = UDim2.fromOffset(math.clamp(abs.X + t.holder.AbsoluteSize.X * 0.35, 10, v.X - 210), math.clamp(abs.Y - 60, 10, v.Y - 82))
	tip.Visible = true
end

-- vein view for one category
openBranch = function(bi)
	rippleIn = true
	currentBranch = bi
	clearCanvas()
	local branch = Config.UpgradeBranches[bi]
	-- the middle hex is the BACK button
	local root = makeTile(0, 0, RED, Color3.fromRGB(190, 40, 50))
	label(root.holder, "\u{2190}", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.25, 0.2), { ZIndex = 7 })
	label(root.holder, "BACK", UDim2.fromScale(0.7, 0.22), UDim2.fromScale(0.15, 0.5), { ZIndex = 7 })
	root.holder.Activated:Connect(function()
		if not panMoved then
			rippleIn = true
			buildCategories()
			rippleIn = false
		end
	end)
	local layout = veinLayout(bi)
	for _, node in ipairs(Config.UpgradeNodes) do
		local pos = layout[node.id]
		if pos then
			local x, y = hexToPixel(pos[1], pos[2])
			local vein = nil -- tiers of one upgrade touch each other; no lines
			local img = (node.imageId and node.imageId ~= "" and node.imageId) or (Config.UpgradeStatImages and Config.UpgradeStatImages[node.statKey]) or ""
			local t = makeTile(x, y, BLUE, BLUE_DARK, img)
			local statInfo = Config.UpgradeStatInfo[node.statKey] or { name = node.statKey }
			t.name = label(t.holder, statInfo.name .. " " .. node.tier, UDim2.fromScale(0.86, 0.2), UDim2.fromScale(0.07, 0.3), { ZIndex = 7 })
			t.cost = label(t.holder, Config.FormatNumber(node.cost), UDim2.fromScale(0.62, 0.18), UDim2.fromScale(0.19, 0.55), { ZIndex = 7, TextColor3 = Color3.fromRGB(255, 220, 110) })
			t.question = label(t.holder, "?", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.25, 0.25), { ZIndex = 7, TextColor3 = Color3.fromRGB(200, 205, 220) })
			t.vein = vein
			tiles[node.id] = t
			t.holder.Activated:Connect(function(input)
				if panMoved then
					return -- that was a drag, not a click
				end
				local touch = input and input.UserInputType == Enum.UserInputType.Touch
				if not touch and statusOf(node) == "available" then
					selected = node
					buyNode(node) -- PC: click buys right away
				elseif info.Visible and selected == node then
					info.Visible = false -- tap the same upgrade again: close the info
					selected = nil
				else
					showInfo(node)
				end
			end)
			t.holder.MouseEnter:Connect(function()
				if UserInputService.MouseEnabled and not dragging then
					showTip(node, t)
				end
			end)
			t.holder.MouseLeave:Connect(function()
				if tip:GetAttribute("For") == node.id then
					tip.Visible = false
				end
			end)
			paintTile(node)
		end
	end
	offset = Vector2.new(0, 0)
	applyOffset()
end

-- BACK (vein view -> categories)
backBtn = mk("TextButton", { Size = UDim2.fromOffset(150, 52), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18), BackgroundColor3 = BLUE, Text = "BACK", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, ZIndex = 20, Visible = false }, dim)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, backBtn)
mk("UIStroke", { Color = OUTLINE, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, backBtn)
mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, backBtn)
backBtn.Activated:Connect(function()
	rippleIn = true
	buildCategories()
	rippleIn = false
end)

local lastCategorySig
local function refreshAll()
	cashText.Text = Config.FormatNumber((profile and profile.cash) or 0) .. " CASH"
	shardText.Text = Config.FormatNumber((profile and profile.riftShards) or 0) .. " SHARDS"
	if currentBranch then
		for _, node in ipairs(Config.UpgradeNodes) do
			paintTile(node)
		end
		if selected and info.Visible then
			showInfo(selected)
		end
	else
		-- the server sends the profile every second: only rebuild the
		-- category page when an owned count changed
		local sig = {}
		for _, branch in ipairs(Config.UpgradeBranches) do
			table.insert(sig, (branchCounts(branch)))
		end
		sig = table.concat(sig, ",")
		if sig ~= lastCategorySig then
			lastCategorySig = sig
			buildCategories()
		end
	end
end

--------------------------------------------------------------------
-- buying
--------------------------------------------------------------------
local busy = false
buyNode = function(node)
	if busy or not node then
		return
	end
	if (profile and profile.cash or 0) < node.cost then
		flash("You don't have enough money to buy this upgrade!", Color3.fromRGB(255, 70, 70))
		return
	end
	busy = true
	local ok, r = pcall(function()
		return buyUpgradeRemote:InvokeServer(node.id)
	end)
	busy = false
	if ok and r then
		if r.profile then
			profile = r.profile
		end
		if r.success then
			flash((r.message and r.message ~= "") and r.message or "Upgrade bought!", Color3.fromRGB(120, 255, 140))
		else
			flash(r.message or "Can't buy this yet.", Color3.fromRGB(255, 70, 70))
		end
	end
	refreshAll()
	local t = tiles[node.id]
	if t and ok and r and r.success then
		t.press = 1.3 -- a happy bounce (eases back to 1)
	end
	if t and tip.Visible and tip:GetAttribute("For") == node.id then
		showTip(node, t)
	end
end
buyBtn.Activated:Connect(function()
	buyNode(selected)
end)

--------------------------------------------------------------------
-- move + zoom
--------------------------------------------------------------------
applyOffset = function()
	canvas.Position = UDim2.new(0.5, offset.X * zoom.Scale, 0.5, offset.Y * zoom.Scale)
end
local dragStart, offsetStart
local mouseDrag = false
local lastMouse = nil -- right-mouse pan (uses mouse movement, works even when Roblox locks the cursor)
-- PC: hold RIGHT mouse and move to pan (works on top of the hexes too),
-- LEFT click only picks a hex. Phones: drag with a finger.
view.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, offsetStart = true, input.Position, offset
		mouseDrag = false
		panMoved = false
	end
end)
local DRAG_START = 8 -- pixels a press must move before it becomes a drag
local ContextActionService = game:GetService("ContextActionService")
local function mouseInView()
	local m = UserInputService:GetMouseLocation() -- this ScreenGui ignores the top-bar inset
	local p, sz = view.AbsolutePosition, view.AbsoluteSize
	return m.X >= p.X and m.Y >= p.Y and m.X <= p.X + sz.X and m.Y <= p.Y + sz.Y
end
local function onRightMouse(_, state, input)

	if state == Enum.UserInputState.Begin then
		if dim.Visible then
			dragging, dragStart, offsetStart = true, input.Position, offset
			mouseDrag = true
			lastMouse = Vector2.new(input.Position.X, input.Position.Y)
			return Enum.ContextActionResult.Sink -- don't turn the camera while panning
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if dragging then
			dragging = false
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end
local panBound = false
local function updatePanBinding()
	if dim.Visible and not panBound then
		ContextActionService:BindActionAtPriority("UpgradeTreePan", onRightMouse, false, Enum.ContextActionPriority.High.Value + 10, Enum.UserInputType.MouseButton2)
		panBound = true
	elseif not dim.Visible and panBound then
		ContextActionService:UnbindAction("UpgradeTreePan")
		panBound = false
		dragging = false
	end
end
dim:GetPropertyChangedSignal("Visible"):Connect(updatePanBinding)
updatePanBinding()
UserInputService.InputChanged:Connect(function(input)
	if not (dragging and dim.Visible) then
		return
	end
	if mouseDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
		-- mouse held: follow the cursor; if Roblox locked the cursor, use how far it moved
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local move
		if input.Delta.Magnitude > 0 then
			move = Vector2.new(input.Delta.X, input.Delta.Y)
		else
			move = p - (lastMouse or p)
		end
		lastMouse = p
		if not panMoved and (p - Vector2.new(dragStart.X, dragStart.Y)).Magnitude > DRAG_START then
			panMoved = true -- this press is a drag now: move the honeycomb
			move = p - Vector2.new(dragStart.X, dragStart.Y)
			tip.Visible = false
			info.Visible = false
		end
		if panMoved and move.Magnitude > 0 then
			offset = offset + move / zoom.Scale
			applyOffset()
		end
	elseif not mouseDrag and input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		if panMoved or Vector2.new(delta.X, delta.Y).Magnitude > DRAG_START then
			panMoved = true
			offset = offsetStart + Vector2.new(delta.X, delta.Y) / zoom.Scale
			applyOffset()
			info.Visible = false
			tip.Visible = false
		end
	end
end)
UserInputService.InputBegan:Connect(function(input)
	local t = input.UserInputType
	local mouseBtn = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton1
	if mouseBtn and dim.Visible and not dragging and mouseInView() then
		-- hold LEFT (or right) mouse and move to drag the honeycomb
		dragging, dragStart, offsetStart = true, input.Position, offset
		mouseDrag = true
		panMoved = false
		lastMouse = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		dragging = false
		-- the release of a drag must not count as a click (Activated fires right after)
		task.defer(function()
			panMoved = false
		end)
	end
end)

-- honeycomb animation: hexes near the cursor grow a little (a wave that
-- follows the mouse), pressed hexes squish, just-bought ones bounce
game:GetService("RunService").RenderStepped:Connect(function(dt)
	if not dim.Visible then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local hasMouse = UserInputService.MouseEnabled
	local a = math.clamp(dt * 14, 0, 1)
	for _, t in ipairs(allTiles) do
		if t.holder.Parent then
			local target = 1
			if hasMouse and not panMoved then
				local c = t.holder.AbsolutePosition + t.holder.AbsoluteSize / 2
				local d = (Vector2.new(mouse.X, mouse.Y) - c).Magnitude
				target = 1 + 0.12 * math.clamp(1 - d / 170, 0, 1)
			end
			t.mag += (target - t.mag) * a
			if t.press > 1 then
				t.press = math.max(1, t.press - dt * 1.2)
			end
			t.scale.Scale = t.pop * t.mag * t.press
		end
	end
end)

--------------------------------------------------------------------
-- open / close
--------------------------------------------------------------------
local savedZoom
local function lockCamera()
	if savedZoom then
		return
	end
	local cam = workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local dist = head and (cam.CFrame.Position - head.Position).Magnitude or 15
	savedZoom = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
	player.CameraMinZoomDistance = dist
	player.CameraMaxZoomDistance = dist
end
local function unlockCamera()
	if savedZoom then
		player.CameraMinZoomDistance = savedZoom[1]
		player.CameraMaxZoomDistance = savedZoom[2]
		savedZoom = nil
	end
end

local function open()
	closeAllBridge:Fire("upgrades")
	lockCamera()
	local ok, p = pcall(function()
		return profileRemote:InvokeServer()
	end)
	if ok and p then
		profile = p
	end
	local v = workspace.CurrentCamera.ViewportSize
	zoom.Scale = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and 0.72 or 1
	offset = Vector2.new(0, 0)
	dragging = false
	applyOffset()
	info.Visible = false
	currentBranch = nil
	lastCategorySig = nil
	rippleIn = true -- opening the tree: the page pops in as a ripple
	refreshAll()
	rippleIn = false
	dim.Visible = true
end
local function close()
	unlockCamera()
	dim.Visible = false
	info.Visible = false
	dragging = false
end
openBridge.Event:Connect(open)
closeBridge.Event:Connect(close)
closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "upgrades" then
		close()
	end
end)
profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
	if dim.Visible then
		refreshAll()
	end
end)
