--------------------------------------------------------------------
-- Calendar window: REWARDS (7-day login) | QUESTS (daily quests +
-- 7-day quest streak bonus).
--------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local remote = folder:WaitForChild("Remotes"):WaitForChild("Quests")

local hud = script.Parent
local panel = hud:WaitForChild("Panels"):WaitForChild("DailyPanel")
local body = panel:WaitForChild("Body")
local titleText = panel:WaitForChild("Title"):WaitForChild("Text")

local FONT = Enum.Font.LuckiestGuy
local NAVY = Color3.fromRGB(28, 40, 88)
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(60, 205, 95)
local GRAY = Color3.fromRGB(120, 130, 150)
local OUT = Color3.fromRGB(10, 15, 35)
local TIER = { easy = { "EASY", Color3.fromRGB(70, 200, 100) }, medium = { "MEDIUM", Color3.fromRGB(255, 160, 50) }, hard = { "HARD", Color3.fromRGB(235, 70, 70) } }

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r, stroke)
	mk("UICorner", { CornerRadius = UDim.new(0, r) }, o)
	if stroke then
		mk("UIStroke", { Thickness = stroke, Color = OUT, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
end
local function label(parent, text, size, pos, props)
	local l = mk("TextLabel", { Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Text = text, Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, parent)
	mk("UIStroke", { Thickness = 2, Color = OUT }, l)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
local function rewardText(r)
	local parts = {}
	if r.cash then table.insert(parts, "$" .. Config.FormatNumber(r.cash)) end
	if r.shards then table.insert(parts, r.shards .. " Shards") end
	for k, n in pairs(r.potions or {}) do
		local p = Config.GetPotion(k)
		table.insert(parts, n .. "x " .. (p and p.name or k))
	end
	for k, n in pairs(r.items or {}) do
		local it = Config.Items[k]
		table.insert(parts, n .. "x " .. (it and it.name or k))
	end
	for k, n in pairs(r.gears or {}) do
		local g = Config.GetGear(k)
		table.insert(parts, n .. "x " .. (g and g.name or k))
	end
	return table.concat(parts, ", ")
end

-- tabs
local tabs = mk("Frame", { Name = "Tabs", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, body)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }, tabs)
local function tabButton(text)
	local b = mk("TextButton", { Name = text:sub(1, 1) .. text:sub(2):lower() .. "Tab", Size = UDim2.fromOffset(170, 40), BackgroundColor3 = GRAY, Text = "", AutoButtonColor = true }, tabs)
	round(b, 12, 3)
	label(b, text, UDim2.new(1, -16, 0.7, 0), UDim2.fromScale(0.5, 0.5), { AnchorPoint = Vector2.new(0.5, 0.5) })
	return b
end
local rewardsTab = tabButton("REWARDS")
local questsTab = tabButton("QUESTS")
local questBadge = mk("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -8, 0, -8), BackgroundColor3 = Color3.fromRGB(235, 60, 60), Visible = false, ZIndex = 5 }, questsTab)
round(questBadge, 11, 2)
label(questBadge, "!", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), { ZIndex = 6 })

-- quests page
local page = mk("Frame", { Name = "QuestsPage", Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1, Visible = false }, body)
local streakBox = mk("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = NAVY }, page)
round(streakBox, 12, 3)
label(streakBox, "7-DAY QUEST STREAK", UDim2.new(0.45, 0, 0, 24), UDim2.fromOffset(12, 6), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local dots = mk("Frame", { Size = UDim2.new(0.45, 0, 0, 34), Position = UDim2.fromOffset(12, 36), BackgroundTransparency = 1 }, streakBox)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, dots)
local dotList = {}
for i = 1, 7 do
	local d = mk("Frame", { Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(50, 60, 100) }, dots)
	round(d, 15, 2)
	local t = label(d, tostring(i), UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.15))
	dotList[i] = d
end
label(streakBox, "Finish all 5 quests every day for 7 days in a row:", UDim2.new(0.52, -12, 0, 20), UDim2.new(0.48, 0, 0, 8), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 210, 255) })
label(streakBox, rewardText(Config.DailyQuestWeekBonus), UDim2.new(0.52, -12, 0, 42), UDim2.new(0.48, 0, 0, 30), { TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = GOLD })

local list = mk("Frame", { Size = UDim2.new(1, 0, 1, -118), Position = UDim2.fromOffset(0, 86), BackgroundTransparency = 1 }, page)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local resetLabel = label(page, "", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, -24), { TextColor3 = Color3.fromRGB(200, 210, 255) })

local rows = {}
local state
local busy = false
for i = 1, 5 do
	local row = mk("Frame", { Size = UDim2.new(1, 0, 0.2, -5), BackgroundColor3 = NAVY, LayoutOrder = i }, list)
	round(row, 10, 3)
	local tier = mk("Frame", { Size = UDim2.new(0, 84, 0.62, 0), Position = UDim2.new(0, 8, 0.19, 0), BackgroundColor3 = GREEN }, row)
	round(tier, 8, 2)
	local tierText = label(tier, "", UDim2.new(1, -8, 0.8, 0), UDim2.fromScale(0.5, 0.5), { AnchorPoint = Vector2.new(0.5, 0.5) })
	local text = label(row, "", UDim2.new(0.42, -104, 0.45, 0), UDim2.new(0, 100, 0.06, 0), { TextXAlignment = Enum.TextXAlignment.Left })
	local barBg = mk("Frame", { Size = UDim2.new(0.42, -104, 0.3, 0), Position = UDim2.new(0, 100, 0.58, 0), BackgroundColor3 = Color3.fromRGB(15, 20, 45) }, row)
	round(barBg, 6)
	local bar = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN }, barBg)
	round(bar, 6)
	local barText = label(barBg, "", UDim2.new(1, 0, 0.9, 0), UDim2.fromScale(0, 0.05), { ZIndex = 3 })
	local reward = label(row, "", UDim2.new(0.33, -10, 0.7, 0), UDim2.new(0.42, 4, 0.15, 0), { TextWrapped = true, TextColor3 = GOLD })
	local btn = mk("TextButton", { Size = UDim2.new(0.25, -16, 0.72, 0), Position = UDim2.new(0.75, 4, 0.14, 0), BackgroundColor3 = GRAY, Text = "", AutoButtonColor = true }, row)
	round(btn, 10, 3)
	local btnText = label(btn, "", UDim2.new(1, -12, 0.65, 0), UDim2.fromScale(0.5, 0.5), { AnchorPoint = Vector2.new(0.5, 0.5) })
	rows[i] = { row = row, tier = tier, tierText = tierText, text = text, bar = bar, barText = barText, reward = reward, btn = btn, btnText = btnText }
	btn.Activated:Connect(function()
		local q = state and state.list[i]
		if busy or not q or q.claimed or q.progress < q.target then
			return
		end
		busy = true
		local ok, r = pcall(function()
			return remote:InvokeServer("claim", i)
		end)
		busy = false
		if ok and r then
			if r.quests then
				state = r.quests
			end
			local msg = panel:FindFirstChild("Message")
			if msg then
				msg.Text = r.message or ""
				msg.TextColor3 = r.success and GOLD or Color3.fromRGB(255, 120, 120)
				task.delay(3, function()
					if msg.Text == (r.message or "") then
						msg.Text = ""
					end
				end)
			end
			render()
		end
	end)
end

function render()
	if not state then
		return
	end
	local anyReady = false
	for i, r in ipairs(rows) do
		local q = state.list[i]
		r.row.Visible = q ~= nil
		if q then
			local t = TIER[q.tier] or TIER.easy
			r.tier.BackgroundColor3 = t[2]
			-- dark card with a border in the quest's tier color (like the rewards)
			r.row.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
			local rs = r.row:FindFirstChildOfClass("UIStroke")
			if rs then
				rs.Color = q.claimed and Color3.fromRGB(70, 75, 90) or t[2]
				rs.Thickness = 4
			end
			r.tierText.Text = t[1]
			r.text.Text = q.text
			r.bar.Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0, 1), 1)
			r.barText.Text = Config.FormatNumber(q.progress) .. " / " .. Config.FormatNumber(q.target)
			r.reward.Text = rewardText(Config.DailyQuestRewards[q.tier])
			local ready = not q.claimed and q.progress >= q.target
			anyReady = anyReady or ready
			-- claimed: just a green "COMPLETED" text, not a button any more
			r.btn.BackgroundColor3 = ready and GREEN or GRAY
			r.btn.BackgroundTransparency = q.claimed and 1 or 0
			r.btn.AutoButtonColor = not q.claimed
			r.btn.Active = not q.claimed
			local btnStroke = r.btn:FindFirstChildOfClass("UIStroke")
			if btnStroke then
				btnStroke.Enabled = not q.claimed
			end
			r.btnText.Text = q.claimed and "COMPLETED" or (ready and "CLAIM" or "...")
			r.btnText.TextColor3 = q.claimed and GREEN or Color3.new(1, 1, 1)
		end
	end
	-- streak dots (today's dot lights up once all 5 are claimed)
	local streak = state.streak or 0
	for i, d in ipairs(dotList) do
		d.BackgroundColor3 = i <= streak and GOLD or Color3.fromRGB(50, 60, 100)
	end
	questBadge.Visible = anyReady
end

local function refresh()
	local ok, r = pcall(function()
		return remote:InvokeServer("get")
	end)
	if ok and r and r.quests then
		state = r.quests
		render()
	end
end

local function show(which)
	local quests = which == "quests"
	page.Visible = quests
	for _, n in ipairs({ "Days", "ClaimButton", "Timer" }) do
		local o = body:FindFirstChild(n)
		if o then
			o.Visible = not quests
		end
	end
	rewardsTab.BackgroundColor3 = quests and GRAY or GOLD
	questsTab.BackgroundColor3 = quests and GOLD or GRAY
	titleText.Text = quests and "DAILY QUESTS" or "DAILY REWARDS"
	if quests then
		refresh()
	end
end
rewardsTab.Activated:Connect(function()
	show("rewards")
end)
questsTab.Activated:Connect(function()
	show("quests")
end)
show("rewards")

-- keep it fresh while open + reset timer
task.spawn(function()
	local n = 0
	while true do
		task.wait(1)
		n += 1
		if panel.Visible and page.Visible and n % 2 == 0 then
			refresh()
		elseif n % 20 == 0 then
			refresh() -- badge
		end
		if state and state.resetAt then
			local left = math.max(0, math.floor(state.resetAt - workspace:GetServerTimeNow()))
			resetLabel.Text = string.format("NEW QUESTS IN %02d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
		end
	end
end)
refresh()
