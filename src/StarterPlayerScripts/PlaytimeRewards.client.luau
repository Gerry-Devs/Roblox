local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--------------------------------------------------------------------
-- PLAY TIME rewards (Config.Playtime): a clock button in the top bar
-- (beside Daily Rewards) shows the time to the next reward and a "!"
-- when one is ready. The window lists every milestone with CLAIM.
-- Per session; the timer pauses while you're AFK (server decides).
-- The window gets the studded look + phone fit automatically
-- (CloseButtonFixer / WindowAnimator).
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local remotes = folder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local stateEvent = remotes:WaitForChild("PlaytimeState")
local activeEvent = remotes:WaitForChild("PlaytimeActive")
local claimRemote = remotes:WaitForChild("PlaytimeClaim")
local bridge = folder:WaitForChild("ClientBridge")
local closeAllBridge = bridge:WaitForChild("CloseAll")
local notify = bridge:WaitForChild("Notify")

local P = Config.Playtime
local OUTLINE = Color3.fromRGB(10, 12, 22)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(70, 200, 100)
local GRAY = Color3.fromRGB(80, 86, 104)
local RED = Color3.fromRGB(240, 70, 80)
local FONT = Enum.Font.LuckiestGuy

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

local profile
pcall(function()
	profile = profileRemote:InvokeServer()
end)
profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
end)

-- the server's timer + when we got it (counted on locally between updates)
local state = { active = 0, claimed = {}, afk = false }
local gotAt = os.clock()
local function activeNow()
	return state.active + (state.afk and 0 or (os.clock() - gotAt))
end
local function setState(s)
	if type(s) == "table" then
		state = s
		state.claimed = state.claimed or {}
		gotAt = os.clock()
	end
end
stateEvent.OnClientEvent:Connect(setState)
task.spawn(function()
	local ok, r = pcall(function()
		return claimRemote:InvokeServer("get")
	end)
	if ok and r and r.state then
		setState(r.state)
	end
end)

-- "I'm here": any tap / key / mouse move (at most every 20 s)
local lastPing = 0
local function ping()
	if os.clock() - lastPing > 20 then
		lastPing = os.clock()
		activeEvent:FireServer()
	end
end
UserInputService.InputBegan:Connect(ping)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		ping()
	end
end)

local function clock(sec)
	sec = math.max(0, math.floor(sec))
	local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end
local function milestoneName(m)
	if m.minutes < 60 then
		return m.minutes .. " MIN"
	end
	local h = m.minutes / 60
	return (h == math.floor(h) and tostring(math.floor(h)) or string.format("%.1f", h)) .. " HR"
end
-- "Rare+ Egg + 50 Shards", and the picture to show
local function rewardInfo(m)
	local parts, icon = {}, ""
	if m.egg then
		table.insert(parts, Config.GetRarity(m.egg).name .. "+ Egg")
		icon = (Config.EggIcons and Config.EggIcons[m.egg]) or ""
	end
	if m.cashPct then
		local amount = profile and Config.CashPackAmount(profile, m.cashPct) or 0
		table.insert(parts, amount > 0 and ("$" .. Config.FormatNumber(amount)) or (m.cashPct .. "% Cash"))
		icon = icon ~= "" and icon or Config.CashImage
	end
	if m.shards then
		table.insert(parts, m.shards .. " Shards")
		icon = icon ~= "" and icon or Config.RiftShardImage
	end
	for key, n in pairs(m.potions or {}) do
		local potion = Config.GetPotion(key)
		table.insert(parts, (n > 1 and (n .. "x ") or "") .. (potion and potion.name or key))
		icon = icon ~= "" and icon or (potion and potion.imageId or "")
	end
	return table.concat(parts, " + "), icon
end
local function nextMilestone()
	for i, m in ipairs(P.milestones) do
		if not state.claimed[i] and not state.claimed[tostring(i)] then
			return i, m
		end
	end
	return nil
end
local function isClaimed(i)
	return state.claimed[i] or state.claimed[tostring(i)]
end
local function readyCount()
	local n, t = 0, activeNow()
	for i, m in ipairs(P.milestones) do
		if not isClaimed(i) and t >= m.minutes * 60 then
			n += 1
		end
	end
	return n
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local gui = mk("ScreenGui", { Name = "PlaytimeGui", ResetOnSpawn = false, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local W, H = 400, 420
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = Color3.fromRGB(40, 44, 58), Visible = false }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, main)
mk("UIStroke", { Color = OUTLINE, Thickness = 5 }, main)
local mainScale = mk("UIScale", {}, main)
local titleFrame = mk("Frame", { Name = "Title", Size = UDim2.fromOffset(260, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = GOLD, ZIndex = 5 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, titleFrame)
label(titleFrame, "Play Time", UDim2.new(1, -24, 0.64, 0), UDim2.new(0, 12, 0.18, 0), { Name = "Text", ZIndex = 6 })
local closeBtn = mk("TextButton", { Name = "CloseButton", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), BackgroundColor3 = RED, Text = "X", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 10 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, closeBtn)

local timeText = label(main, "", UDim2.new(1, -110, 0, 30), UDim2.fromOffset(20, 40), { TextXAlignment = Enum.TextXAlignment.Left })
label(main, "Rewards start over when you rejoin. AFK pauses the timer.", UDim2.new(1, -40, 0, 18), UDim2.fromOffset(20, 72), {
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 1,
	TextColor3 = Color3.fromRGB(200, 206, 225),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local list = mk("ScrollingFrame", { Name = "List", Size = UDim2.new(1, -30, 1, -112), Position = UDim2.fromOffset(15, 98), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, main)
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10) }, list)

local rows = {}
local claiming = false
for i, m in ipairs(P.milestones) do
	local row = mk("Frame", { Name = "M" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = Color3.fromRGB(28, 31, 42) }, list)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
	local st = mk("UIStroke", { Color = Color3.fromRGB(70, 76, 96), Thickness = 2 }, row)
	local text, icon = rewardInfo(m)
	local pic = mk("ImageLabel", { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, Image = icon, ScaleType = Enum.ScaleType.Fit }, row)
	label(row, milestoneName(m), UDim2.new(1, -176, 0, 26), UDim2.fromOffset(66, 6), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
	local reward = label(row, text, UDim2.new(1, -176, 0, 28), UDim2.fromOffset(66, 32), {
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.6,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local btn = mk("TextButton", { Size = UDim2.fromOffset(98, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = GRAY, Text = "", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, AutoButtonColor = true }, row)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, btn)
	mk("UIStroke", { Color = OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
	mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, btn)
	btn.Activated:Connect(function()
		if claiming or isClaimed(i) or activeNow() < m.minutes * 60 then
			return
		end
		claiming = true
		local ok, r = pcall(function()
			return claimRemote:InvokeServer(i)
		end)
		claiming = false
		if ok and r then
			if r.state then
				setState(r.state)
			end
			if r.message and r.message ~= "" then
				notify:Fire(r.message, r.success and GOLD or RED)
			end
		end
	end)
	rows[i] = { frame = row, stroke = st, btn = btn, reward = reward, pic = pic }
end

local function refreshRows()
	local t = activeNow()
	for i, m in ipairs(P.milestones) do
		local r = rows[i]
		local need = m.minutes * 60
		if isClaimed(i) then
			r.btn.Text = "\u{2713}"
			r.btn.BackgroundColor3 = Color3.fromRGB(45, 120, 65)
			r.stroke.Color = Color3.fromRGB(70, 76, 96)
			r.frame.BackgroundTransparency = 0.35
		elseif t >= need then
			r.btn.Text = "CLAIM"
			r.btn.BackgroundColor3 = GREEN
			r.stroke.Color = GOLD
			r.frame.BackgroundTransparency = 0
		else
			r.btn.Text = clock(need - t)
			r.btn.BackgroundColor3 = GRAY
			r.stroke.Color = Color3.fromRGB(70, 76, 96)
			r.frame.BackgroundTransparency = 0
		end
		if m.cashPct then -- the cash amount follows your rebirth
			r.reward.Text = (rewardInfo(m))
		end
	end
	timeText.Text = state.afk and "PAUSED (AFK)" or ("PLAYED: " .. clock(t))
	timeText.TextColor3 = state.afk and Color3.fromRGB(255, 140, 140) or WHITE
end

local function fit()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	mainScale.Scale = math.clamp(math.min(vp.Y / 560, vp.X / 760), 0.55, 1)
end
local function open()
	closeAllBridge:Fire("playtime")
	fit()
	refreshRows()
	main.Visible = true
end
local function close()
	main.Visible = false
end
closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "playtime" then
		close()
	end
end)

--------------------------------------------------------------------
-- top bar button (a copy of the Settings button, like ADMIN)
--------------------------------------------------------------------
local openBtn, btnTime, badge
task.spawn(function()
	local topRow = playerGui:WaitForChild("TopBar"):WaitForChild("Top")
	local template = topRow:WaitForChild("SettingsButton")
	openBtn = template:Clone()
	openBtn.Name = "PlaytimeButton"
	for _, c in ipairs(openBtn:GetDescendants()) do
		if c:IsA("LuaSourceContainer") then
			c:Destroy()
		end
	end
	-- right after Daily Rewards
	local daily = topRow:FindFirstChild("DailyButton")
	if daily then
		for _, c in ipairs(topRow:GetChildren()) do
			if c:IsA("GuiObject") and c ~= daily and c.LayoutOrder > daily.LayoutOrder then
				c.LayoutOrder += 1
			end
		end
		openBtn.LayoutOrder = daily.LayoutOrder + 1
	end
	local icon = openBtn:FindFirstChild("Icon")
	if icon then
		icon.Visible = false
	end
	label(openBtn, "\u{23F0}", UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.19, 0.08), { Name = "Clock", TextStrokeTransparency = 1, ZIndex = openBtn.ZIndex + 1 })
	btnTime = label(openBtn, "", UDim2.fromScale(1.1, 0.34), UDim2.fromScale(-0.05, 0.7), { Name = "Time", ZIndex = openBtn.ZIndex + 2 })
	badge = mk("Frame", { Name = "Badge", Size = UDim2.fromScale(0.36, 0.36), Position = UDim2.fromScale(0.68, -0.06), BackgroundColor3 = RED, Visible = false, ZIndex = openBtn.ZIndex + 3 }, openBtn)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	mk("UIStroke", { Color = OUTLINE, Thickness = 2 }, badge)
	label(badge, "!", UDim2.fromScale(1, 1), nil, { ZIndex = openBtn.ZIndex + 4 })
	openBtn.Parent = topRow
	topRow.Size = UDim2.new(topRow.Size.X.Scale, topRow.Size.X.Offset + 56, topRow.Size.Y.Scale, topRow.Size.Y.Offset)
	if openBtn:IsA("GuiButton") then
		openBtn.Activated:Connect(function()
			if main.Visible then
				close()
			else
				open()
			end
		end)
	end
end)

-- tick: button time / badge, the open window, and a heads-up when a
-- reward becomes ready
local told = {}
while true do
	task.wait(0.5)
	local ready = readyCount()
	if badge then
		badge.Visible = ready > 0
	end
	if btnTime then
		local i, m = nextMilestone()
		if not i then
			btnTime.Text = "DONE"
		elseif ready > 0 then
			btnTime.Text = "CLAIM"
		else
			btnTime.Text = state.afk and "AFK" or clock(m.minutes * 60 - activeNow())
		end
	end
	if main.Visible then
		refreshRows()
	end
	local t = activeNow()
	for i, m in ipairs(P.milestones) do
		if not told[i] and not isClaimed(i) and t >= m.minutes * 60 then
			told[i] = true
			notify:Fire("Play-time reward ready! Tap the \u{23F0} button to claim it.", GOLD)
		end
	end
end
