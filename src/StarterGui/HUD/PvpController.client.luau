local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- PvP window (HUD > PVP button) + the battle screen.
--   CHALLENGES: post your team, or FIGHT someone's posted team
--   LEADERBOARD: this month's season, top 100, reward tiers
-- Credits only show here (not in the cash HUD).
--------------------------------------------------------------------
local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local pvpRemote = remotes:WaitForChild("PvpAction")
local pvpEvent = remotes:WaitForChild("PvpEvent")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local notify = bridge:WaitForChild("Notify")
local closeAllBridge = bridge:WaitForChild("CloseAll")

local gui = script.Parent
local panel = gui:WaitForChild("Panels"):WaitForChild("PvpPanel")
local body = panel:WaitForChild("Body")

local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(60, 205, 95)
local RED = Color3.fromRGB(230, 65, 65)
local BLUE = Color3.fromRGB(60, 130, 235)
local GRAY = Color3.fromRGB(110, 118, 140)
local DARK = Color3.fromRGB(22, 32, 70)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
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
	local b = mk("TextButton", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = color, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, AutoButtonColor = true }, parent)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end
local function box(parent, size, pos, color)
	local f = mk("Frame", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = color or DARK }, parent)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, f)
	return f
end
local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	if sec >= 86400 then
		return string.format("%dd %dh", sec // 86400, (sec % 86400) // 3600)
	elseif sec >= 3600 then
		return string.format("%dh %dm", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%dm %ds", sec // 60, sec % 60)
end
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local function seasonName(key)
	local y, m = (key or ""):match("(%d+)%-(%d+)")
	return m and (MONTHS[tonumber(m)] .. " " .. y .. " SEASON") or "SEASON"
end

--------------------------------------------------------------------
-- top: stats
--------------------------------------------------------------------
local stats = box(body, UDim2.new(1, 0, 0, 54), UDim2.fromOffset(0, 18))
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 18) }, stats)
local creditsLabel = label(stats, "CREDITS 0", UDim2.new(0.24, 0, 0.62, 0), nil, { TextColor3 = GOLD })
local pointsLabel = label(stats, "POINTS 0", UDim2.new(0.22, 0, 0.62, 0), nil, { TextColor3 = Color3.fromRGB(140, 220, 255) })
local wlLabel = label(stats, "W 0 / L 0", UDim2.new(0.18, 0, 0.62, 0))
local seasonLabel = label(stats, "", UDim2.new(0.28, 0, 0.5, 0), nil, { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(200, 210, 240) })

-- tabs
local tabChallenges = button(body, "CHALLENGES", UDim2.fromOffset(200, 40), UDim2.fromOffset(0, 80), GOLD)
local tabBoard = button(body, "LEADERBOARD", UDim2.fromOffset(200, 40), UDim2.fromOffset(210, 80), GRAY)
local refreshBtn = button(body, "REFRESH", UDim2.fromOffset(130, 40), UDim2.new(1, -130, 0, 80), BLUE)

local pageC = mk("Frame", { Size = UDim2.new(1, 0, 1, -130), Position = UDim2.fromOffset(0, 128), BackgroundTransparency = 1 }, body)
local pageB = mk("Frame", { Size = pageC.Size, Position = pageC.Position, BackgroundTransparency = 1, Visible = false }, body)

--------------------------------------------------------------------
-- CHALLENGES page
--------------------------------------------------------------------
local myCard = box(pageC, UDim2.new(1, 0, 0, 62), UDim2.new(), Color3.fromRGB(110, 40, 40))
local myText = label(myCard, "YOUR TEAM", UDim2.new(0.62, 0, 0.5, 0), UDim2.new(0.02, 0, 0.08, 0), { TextXAlignment = Enum.TextXAlignment.Left })
local mySub = label(myCard, "", UDim2.new(0.62, 0, 0.34, 0), UDim2.new(0.02, 0, 0.58, 0), { TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(255, 220, 220) })
local postBtn = button(myCard, "POST CHALLENGE", UDim2.new(0.34, 0, 0, 44), UDim2.new(0.65, 0, 0.5, -22), GREEN)

local postList = mk("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -72), Position = UDim2.fromOffset(0, 72), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, pageC)
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, postList)
mk("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }, postList)
local emptyLabel = label(pageC, "No challenges right now.\nPost yours and wait for someone to fight you!", UDim2.new(0.9, 0, 0, 60), UDim2.new(0.05, 0, 0.45, 0), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(200, 210, 240), Visible = false })

--------------------------------------------------------------------
-- LEADERBOARD page
--------------------------------------------------------------------
local tierRow = mk("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 }, pageB)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, tierRow)
for i, tier in ipairs(Config.Pvp.rewardTiers) do
	local c = box(tierRow, UDim2.new(1 / 3, -7, 1, 0), nil, Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3]))
	c.LayoutOrder = i
	label(c, tier.name .. "  (#" .. tier.from .. "-" .. tier.to .. ")", UDim2.new(0.94, 0, 0.5, 0), UDim2.new(0.03, 0, 0.06, 0))
	label(c, "Rewards: " .. tier.rewards, UDim2.new(0.94, 0, 0.34, 0), UDim2.new(0.03, 0, 0.58, 0), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = OUTLINE })
end
local myRankLabel = label(pageB, "", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 62), { TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
local boardList = mk("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -96), Position = UDim2.fromOffset(0, 94), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, pageB)
mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, boardList)
mk("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2) }, boardList)
local boardEmpty = label(pageB, "No fights this season yet - be the first!", UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0.55, 0), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(200, 210, 240), Visible = false })

--------------------------------------------------------------------
-- confirm before a fight: your power vs theirs, FIGHT or DECLINE
--------------------------------------------------------------------
local confirm = mk("TextButton", { Name = "Confirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 50 }, panel)
mk("UICorner", { CornerRadius = UDim.new(0, 16) }, confirm)
local cbox = box(confirm, UDim2.fromOffset(460, 270), UDim2.new(0.5, -230, 0.5, -135), DARK)
cbox.ZIndex = 51
local function z(o)
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 52
		end
	end
end
local cTitle = label(cbox, "FIGHT?", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 10), { TextColor3 = GOLD })
local cYou = label(cbox, "", UDim2.new(0.42, 0, 0, 70), UDim2.new(0.04, 0, 0, 58), { TextColor3 = Color3.fromRGB(255, 150, 150) })
label(cbox, "VS", UDim2.new(0.12, 0, 0, 40), UDim2.new(0.44, 0, 0, 72), { TextColor3 = GOLD })
local cThem = label(cbox, "", UDim2.new(0.42, 0, 0, 70), UDim2.new(0.54, 0, 0, 58), { TextColor3 = Color3.fromRGB(150, 190, 255) })
local cHint = label(cbox, "", UDim2.new(1, -30, 0, 26), UDim2.fromOffset(15, 136), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
local cFight = button(cbox, "FIGHT", UDim2.new(0.44, 0, 0, 52), UDim2.new(0.04, 0, 1, -66), RED)
local cDecline = button(cbox, "DECLINE", UDim2.new(0.44, 0, 0, 52), UDim2.new(0.52, 0, 1, -66), GRAY)
z(cbox)
local pendingFight
local function askFight(post, onYes)
	local mine = (data and data.myPower) or 0
	local theirs = post.power or 0
	cTitle.Text = "FIGHT " .. string.upper(post.display or post.name or "?") .. "?"
	cYou.Text = "YOU\n" .. Config.FormatNumber(mine)
	cThem.Text = string.upper(post.display or post.name or "?") .. "\n" .. Config.FormatNumber(theirs)
	local ratio = mine / math.max(1, theirs)
	if ratio >= 1.25 then
		cHint.Text = "Your team is stronger!"
		cHint.TextColor3 = Color3.fromRGB(150, 255, 170)
	elseif ratio >= 0.85 then
		cHint.Text = "Close fight - it could go either way."
		cHint.TextColor3 = Color3.fromRGB(255, 230, 140)
	else
		cHint.Text = "Their team is stronger - be careful!"
		cHint.TextColor3 = Color3.fromRGB(255, 150, 150)
	end
	pendingFight = onYes
	confirm.Visible = true
end
cFight.Activated:Connect(function()
	confirm.Visible = false
	local f = pendingFight
	pendingFight = nil
	if f then
		f()
	end
end)
local function decline()
	confirm.Visible = false
	pendingFight = nil
end
cDecline.Activated:Connect(decline)
confirm.Activated:Connect(decline)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible then
		decline()
	end
end)

--------------------------------------------------------------------
-- data
--------------------------------------------------------------------
local tab = "c"
local data
local seasonLeftAt = 0
local busy = false

local function flashMessage(text, good)
	local m = panel:FindFirstChild("Message")
	if m then
		m.Text = text
		m.TextColor3 = good and Color3.fromRGB(150, 255, 170) or Color3.fromRGB(255, 150, 150)
		local shown = text
		task.delay(3, function()
			if m.Text == shown then
				m.Text = ""
			end
		end)
	else
		notify:Fire(text, good and GREEN or RED)
	end
end

local function renderStats()
	if not data then
		return
	end
	creditsLabel.Text = "CREDITS " .. Config.FormatNumber(data.credits or 0)
	pointsLabel.Text = "POINTS " .. Config.FormatNumber(data.points or 0)
	wlLabel.Text = "W " .. (data.wins or 0) .. " / L " .. (data.losses or 0)
end

local function renderChallenges()
	for _, c in ipairs(postList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not data then
		return
	end
	myText.Text = "YOUR TEAM  -  POWER " .. Config.FormatNumber(data.myPower or 0)
	if data.myPost then
		mySub.Text = "Your challenge is up! Ends in " .. fmtTime((data.myPost.expires or 0) - os.time())
		postBtn.Text = "CANCEL POST"
		postBtn.BackgroundColor3 = RED
	else
		mySub.Text = (data.myCount or 0) .. " monster" .. ((data.myCount == 1) and "" or "s") .. " from your pen will fight"
		postBtn.Text = "POST CHALLENGE"
		postBtn.BackgroundColor3 = GREEN
	end
	emptyLabel.Visible = #(data.posts or {}) == 0
	for i, p in ipairs(data.posts or {}) do
		local row = box(postList, UDim2.new(1, 0, 0, 58), nil, Color3.fromRGB(30, 50, 105))
		row.LayoutOrder = i
		label(row, p.display or p.name or "?", UDim2.new(0.42, 0, 0.48, 0), UDim2.new(0.02, 0, 0.08, 0), { TextXAlignment = Enum.TextXAlignment.Left })
		label(row, "@" .. (p.name or "") .. "  -  " .. (p.count or 0) .. " monsters", UDim2.new(0.42, 0, 0.32, 0), UDim2.new(0.02, 0, 0.6, 0), { TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(190, 205, 240) })
		local stronger = (p.power or 0) > (data.myPower or 0)
		label(row, "POWER " .. Config.FormatNumber(p.power or 0), UDim2.new(0.25, 0, 0.5, 0), UDim2.new(0.45, 0, 0.25, 0), { TextColor3 = stronger and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(150, 255, 170) })
		local fight = button(row, "FIGHT", UDim2.new(0.24, 0, 0, 42), UDim2.new(0.74, 0, 0.5, -21), RED)
		fight.Activated:Connect(function()
			if busy then
				return
			end
			askFight(p, function()
			busy = true
			fight.Text = "..."
			local ok, r = pcall(function()
				return pvpRemote:InvokeServer("fight", p.userId)
			end)
			busy = false
			if ok and r and r.success then
				closeAllBridge:Fire()
			else
				fight.Text = "FIGHT"
				flashMessage((ok and r and r.message) or "Could not start the fight.", false)
				task.spawn(function()
					local ok2, r2 = pcall(function()
						return pvpRemote:InvokeServer("info")
					end)
					if ok2 and r2 and r2.success then
						data = r2
						renderStats()
						renderChallenges()
					end
				end)
			end
			end)
		end)
	end
end

local function renderBoard(b)
	for _, c in ipairs(boardList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not b then
		return
	end
	myRankLabel.Text = b.myRank and ("YOUR RANK: #" .. b.myRank .. "  -  " .. Config.FormatNumber(b.myPoints or 0) .. " POINTS")
		or ("YOUR POINTS: " .. Config.FormatNumber(b.myPoints or 0) .. "  (not in the top 100 yet)")
	boardEmpty.Visible = #(b.list or {}) == 0
	for _, row in ipairs(b.list or {}) do
		local color = Color3.fromRGB(30, 50, 105)
		for _, tier in ipairs(Config.Pvp.rewardTiers) do
			if row.rank >= tier.from and row.rank <= tier.to and row.rank <= 10 then
				color = Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3]):Lerp(Color3.fromRGB(30, 50, 105), 0.55)
			end
		end
		if row.userId == player.UserId then
			color = Color3.fromRGB(40, 140, 80)
		end
		local r = box(boardList, UDim2.new(1, 0, 0, 38), nil, color)
		r.LayoutOrder = row.rank
		label(r, "#" .. row.rank, UDim2.new(0.12, 0, 0.7, 0), UDim2.new(0.02, 0, 0.15, 0), { TextColor3 = row.rank <= 3 and GOLD or WHITE })
		label(r, row.name or "?", UDim2.new(0.55, 0, 0.62, 0), UDim2.new(0.15, 0, 0.19, 0), { TextXAlignment = Enum.TextXAlignment.Left })
		label(r, Config.FormatNumber(row.points) .. " PTS", UDim2.new(0.26, 0, 0.62, 0), UDim2.new(0.72, 0, 0.19, 0), { TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(140, 220, 255) })
	end
end

local function refresh()
	local ok, r = pcall(function()
		return pvpRemote:InvokeServer("info")
	end)
	if ok and r and r.success then
		data = r
		seasonLeftAt = os.clock() + (r.seasonLeft or 0)
		seasonLabel.Text = seasonName(r.season) .. "\nENDS IN " .. fmtTime(r.seasonLeft)
		renderStats()
		renderChallenges()
	end
	if tab == "b" then
		local ok2, b = pcall(function()
			return pvpRemote:InvokeServer("board")
		end)
		if ok2 and b and b.success then
			renderBoard(b)
		end
	end
end

local function showTab(which)
	tab = which
	pageC.Visible = which == "c"
	pageB.Visible = which == "b"
	tabChallenges.BackgroundColor3 = which == "c" and GOLD or GRAY
	tabBoard.BackgroundColor3 = which == "b" and GOLD or GRAY
	task.spawn(refresh)
end
tabChallenges.Activated:Connect(function()
	showTab("c")
end)
tabBoard.Activated:Connect(function()
	showTab("b")
end)
refreshBtn.Activated:Connect(function()
	task.spawn(refresh)
end)

postBtn.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	local action = (data and data.myPost) and "cancel" or "post"
	local ok, r = pcall(function()
		return pvpRemote:InvokeServer(action)
	end)
	busy = false
	flashMessage((ok and r and r.message) or "Try again.", ok and r and r.success)
	refresh()
end)

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		task.spawn(refresh)
	end
end)
-- live "ends in" timers while open
task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible and data then
			seasonLabel.Text = seasonName(data.season) .. "\nENDS IN " .. fmtTime(seasonLeftAt - os.clock())
			if data.myPost then
				mySub.Text = "Your challenge is up! Ends in " .. fmtTime((data.myPost.expires or 0) - os.time())
			end
		end
	end
end)

--------------------------------------------------------------------
-- battle screen (top bars, countdown, result)
--------------------------------------------------------------------
local battleGui = mk("ScreenGui", { Name = "PvpBattle", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = false }, player:WaitForChild("PlayerGui"))
local topBars = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.new(0.8, 0, 0, 70), BackgroundTransparency = 1 }, battleGui)
mk("UISizeConstraint", { MaxSize = Vector2.new(900, 70) }, topBars)
local function teamBar(side)
	local holder = mk("Frame", { Size = UDim2.new(0.44, 0, 1, 0), Position = side == 1 and UDim2.new() or UDim2.new(0.56, 0, 0, 0), BackgroundTransparency = 1 }, topBars)
	local name = label(holder, "", UDim2.new(1, 0, 0.42, 0), nil, { TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, TextColor3 = side == 1 and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(150, 190, 255) })
	local back = mk("Frame", { Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.new(0, 0, 0.52, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 30) }, holder)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, back)
	mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, back)
	local fill = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = side == 1 and RED or BLUE, AnchorPoint = side == 1 and Vector2.new(0, 0) or Vector2.new(1, 0), Position = side == 1 and UDim2.new() or UDim2.fromScale(1, 0) }, back)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
	local hpText = label(back, "", UDim2.new(1, -10, 0.8, 0), UDim2.new(0, 5, 0.1, 0))
	return name, fill, hpText
end
local nameA, fillA, textA = teamBar(1)
local nameB, fillB, textB = teamBar(2)
label(topBars, "VS", UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.45, 0, 0.1, 0), { TextColor3 = GOLD })
local bigText = label(battleGui, "", UDim2.new(0.6, 0, 0, 110), UDim2.new(0.2, 0, 0.3, 0), { TextColor3 = GOLD })
local subText = label(battleGui, "", UDim2.new(0.6, 0, 0, 44), UDim2.new(0.2, 0, 0.3, 115), { TextColor3 = WHITE })

local battleCam = false
local function setBars(d)
	fillA.Size = UDim2.fromScale(math.clamp((d.aHp or 0) / math.max(1, d.aMax or 1), 0, 1), 1)
	fillB.Size = UDim2.fromScale(math.clamp((d.bHp or 0) / math.max(1, d.bMax or 1), 0, 1), 1)
	textA.Text = Config.FormatNumber(d.aHp or 0) .. " / " .. Config.FormatNumber(d.aMax or 0)
	textB.Text = Config.FormatNumber(d.bHp or 0) .. " / " .. Config.FormatNumber(d.bMax or 0)
end

local function pop(text, color, sub)
	bigText.Text = text
	bigText.TextColor3 = color or GOLD
	subText.Text = sub or ""
	bigText.TextTransparency = 0
	bigText.TextStrokeTransparency = 0
	local s = bigText:FindFirstChildOfClass("UIScale") or mk("UIScale", {}, bigText)
	s.Scale = 1.6
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function startArenaCamera(d)
		-- camera: a view over the whole arena (red team left, blue team right)
		if typeof(d.origin) == "Vector3" then
			battleCam = true
			local cam = workspace.CurrentCamera
			local center = d.origin + Vector3.new(0, 2, 0)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(d.origin + Vector3.new(0, 42, 68), center)
			task.spawn(function()
				local t0 = os.clock()
				while battleCam do
					-- other scripts may reset the camera when windows close: keep ours
					if cam.CameraType ~= Enum.CameraType.Scriptable then
						cam.CameraType = Enum.CameraType.Scriptable
					end
					local ang = math.sin((os.clock() - t0) * 0.15) * 0.35 -- slow sweep
					local p = d.origin + Vector3.new(math.sin(ang) * 68, 42, math.cos(ang) * 68)
					cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(p, center), 0.08)
					task.wait()
				end
				cam.CameraType = Enum.CameraType.Custom
			end)
		end
end

-- wait until the arena + every fighter has loaded on this screen
local ContentProvider = game:GetService("ContentProvider")
local function waitArenaLoaded(origin, count)
	local t0 = os.clock()
	local arena
	while os.clock() - t0 < 12 do
		local folder = workspace:FindFirstChild("PvpArenas")
		if folder then
			for _, ar in ipairs(folder:GetChildren()) do
				local o = ar:GetAttribute("Origin")
				if o and (o - origin).Magnitude < 1 then
					arena = ar
				end
			end
		end
		local fighters = arena and arena:FindFirstChild("Fighters")
		if fighters and #fighters:GetChildren() >= count then
			local done = true
			for _, m in ipairs(fighters:GetChildren()) do
				local want = m:GetAttribute("PartCount") or 0
				if #m:GetDescendants() < want * 0.95 then
					done = false
				end
				-- big monsters: their pieces are added on this screen
				local body = m:FindFirstChild("MonsterBody")
				if body and body:GetAttribute("RigName") and not body:GetAttribute("SkinSet") then
					done = false
				end
			end
			if done then
				pcall(function()
					ContentProvider:PreloadAsync({ arena })
				end)
				return true
			end
		end
		task.wait(0.2)
	end
	return false
end

pvpEvent.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then
		return
	end
	if d.kind == "loading" then
		closeAllBridge:Fire()
		battleGui.Enabled = true
		nameA.Text = ""
		nameB.Text = ""
		topBars.Visible = false
		pop("LOADING ARENA...", WHITE, "Getting every monster ready")
		startArenaCamera(d)
		task.spawn(function()
			local shownAt = os.clock()
			waitArenaLoaded(d.origin, d.fighters or 0)
			-- keep the loading screen up a moment so it never just flashes
			local rest = 1.5 - (os.clock() - shownAt)
			if rest > 0 then
				task.wait(rest)
			end
			pcall(function()
				pvpRemote:InvokeServer("ready")
			end)
		end)
	elseif d.kind == "start" then
		closeAllBridge:Fire()
		battleGui.Enabled = true
		topBars.Visible = true
		if not battleCam then
			startArenaCamera(d)
		end
		nameA.Text = d.me or "YOU"
		nameB.Text = d.them or "?"
		setBars(d)
		-- countdown, then the fight starts (the server waits for it too)
		task.spawn(function()
			for i = d.countdown or 3, 1, -1 do
				pop(tostring(i), WHITE, "Get ready!")
				task.wait(1)
			end
			pop("FIGHT!", RED)
			task.wait(0.8)
			bigText.Text = ""
			subText.Text = ""
		end)
	elseif d.kind == "hp" then
		setBars(d)
	elseif d.kind == "end" then
		local sub = "+" .. (d.credits or 0) .. " CREDITS    " .. ((d.points or 0) >= 0 and "+" or "") .. (d.points or 0) .. " POINTS"
		pop(d.win and "VICTORY!" or "DEFEAT", d.win and GOLD or Color3.fromRGB(255, 120, 120), sub)
		task.delay(4.2, function()
			battleGui.Enabled = false
			battleCam = false
			bigText.Text = ""
			subText.Text = ""
		end)
	elseif d.kind == "defended" then
		local text = (d.opponent or "Someone") .. " fought your challenge: " .. (d.win and "YOU WON" or "you lost") .. "!  +" .. (d.credits or 0) .. " credits"
		notify:Fire(text, d.win and GOLD or Color3.fromRGB(255, 160, 160))
	end
end)
