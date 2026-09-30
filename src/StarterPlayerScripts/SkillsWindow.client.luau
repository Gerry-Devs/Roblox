local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------
-- ACTIVE SKILLS window: the total of every skill your equipped (pen)
-- monsters give, with a bar up to each skill's max, and which monsters
-- give it. Opened by the SKILLS button under WARP (right side).
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
local closeAllBridge = folder:WaitForChild("ClientBridge"):WaitForChild("CloseAll")

local OUTLINE = Color3.fromRGB(10, 12, 22)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60)
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

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local gui = mk("ScreenGui", { Name = "SkillsGui", ResetOnSpawn = false, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local W, H = 460, 470
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = Color3.fromRGB(40, 44, 58), Visible = false }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, main)
mk("UIStroke", { Color = OUTLINE, Thickness = 5 }, main)
mk("UIScale", {}, main)
-- title (the studded header is added by CloseButtonFixer)
local titleFrame = mk("Frame", { Name = "Title", Size = UDim2.fromOffset(260, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = GOLD, ZIndex = 5 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, titleFrame)
label(titleFrame, "Active Skills", UDim2.new(1, -24, 0.64, 0), UDim2.new(0, 12, 0.18, 0), { Name = "Text", ZIndex = 6 })
local closeBtn = mk("TextButton", { Name = "CloseButton", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), BackgroundColor3 = Color3.fromRGB(240, 58, 66), Text = "X", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 10 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, closeBtn)

local hint = label(main, "Skills from the monsters equipped in your pen. The same skill adds up to its max.", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 40), {
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 1,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(200, 206, 225),
})
local list = mk("ScrollingFrame", { Name = "List", Size = UDim2.new(1, -30, 1, -96), Position = UDim2.fromOffset(15, 82), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, main)
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10) }, list)
local empty = label(main, "No skills yet.\nEquip monsters in your pen to get their skills!", UDim2.new(1, -60, 0, 60), UDim2.new(0, 30, 0.45, 0), {
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 1,
	TextColor3 = Color3.fromRGB(200, 206, 225),
	Visible = false,
})

local function fmt(v, unit)
	local n = v >= 10 and string.format("%.0f", v) or string.format("%.1f", v)
	n = n:gsub("%.0$", "")
	return n .. (unit or "")
end

local lastSig
local function render()
	if not profile then
		return
	end
	local totals, raw = Config.GetSkillTotals(profile)
	-- which monsters give each stat
	local sources = {}
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind == "monster" then
			local sk = Config.GetEntrySkill(entry)
			if sk then
				local m = Config.GetMonster(entry.monsterId)
				sources[sk.stat] = sources[sk.stat] or {}
				table.insert(sources[sk.stat], (m and m.name or "?") .. " Lv " .. (entry.level or 1))
			end
		end
	end
	local stats = {}
	for stat in pairs(totals) do
		table.insert(stats, stat)
	end
	table.sort(stats, function(a, b)
		return (Config.SkillStats[a] or {}).name < (Config.SkillStats[b] or {}).name
	end)
	-- only rebuild when something changed (the profile comes every second)
	local sigParts = {}
	for _, stat in ipairs(stats) do
		table.insert(sigParts, stat .. "=" .. string.format("%.2f", totals[stat]) .. "/" .. #(sources[stat] or {}))
	end
	local sig = table.concat(sigParts, ",")
	if sig == lastSig then
		return
	end
	lastSig = sig
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	empty.Visible = #stats == 0
	for i, stat in ipairs(stats) do
		local info = Config.SkillStats[stat] or { name = stat, unit = "", cap = 1 }
		local total, cap = totals[stat], info.cap or 1
		local maxed = (raw[stat] or 0) >= cap - 1e-6
		local row = mk("Frame", { Name = stat, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = Color3.fromRGB(28, 31, 42) }, list)
		mk("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
		mk("UIStroke", { Color = maxed and GOLD or Color3.fromRGB(70, 76, 96), Thickness = maxed and 3 or 2 }, row)
		label(row, info.name, UDim2.new(0.58, -12, 0, 24), UDim2.fromOffset(12, 6), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = maxed and GOLD or WHITE })
		local unit = info.unit == "s" and "s" or info.unit
		local value = (info.unit == "s" and "" or "+") .. fmt(total, unit) .. "  /  " .. fmt(cap, unit)
		label(row, maxed and ("MAX  " .. fmt(cap, unit)) or value, UDim2.new(0.42, -12, 0, 22), UDim2.new(0.58, 0, 0, 7), {
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = maxed and GOLD or Color3.fromRGB(150, 255, 170),
		})
		-- bar up to the max
		local back = mk("Frame", { Size = UDim2.new(1, -24, 0, 10), Position = UDim2.fromOffset(12, 34), BackgroundColor3 = Color3.fromRGB(14, 16, 24) }, row)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, back)
		back:SetAttribute("NoStuds", true)
		local fill = mk("Frame", { Name = "Fill", Size = UDim2.fromScale(math.clamp(total / cap, 0, 1), 1), BackgroundColor3 = maxed and GOLD or Color3.fromRGB(90, 220, 130) }, back)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
		local from = table.concat(sources[stat] or {}, ", ")
		label(row, from, UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 50), {
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(180, 186, 205),
		})
	end
end

local function open()
	closeAllBridge:Fire("skills")
	lastSig = nil
	render()
	main.Visible = true
end
local function close()
	main.Visible = false
end
closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "skills" then
		close()
	end
end)
profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
	if main.Visible then
		render()
	end
end)

--------------------------------------------------------------------
-- SKILLS button: a copy of the WARP button on the right side
--------------------------------------------------------------------
task.spawn(function()
	local pen = playerGui:WaitForChild("PenPanel", 30)
	local dock = pen and pen:WaitForChild("Dock", 10)
	local warp = dock and dock:WaitForChild("WarpButton", 10)
	if not warp then
		return
	end
	local btn = warp:Clone()
	btn.Name = "SkillsButton"
	btn.LayoutOrder = (warp.LayoutOrder or 0) + 1
	for _, d in ipairs(btn:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local badge = btn:FindFirstChild("Badge")
	if badge then
		badge:Destroy()
	end
	local text = btn:FindFirstChild("Label")
	if text and text:IsA("TextLabel") then
		text.Text = "SKILLS"
	end
	-- icon: Config.SkillsIconImage (your picture) or a star
	local icon = btn:FindFirstChild("Icon")
	local fallback = btn:FindFirstChild("Fallback")
	local img = Config.SkillsIconImage or ""
	if icon and icon:IsA("ImageLabel") then
		icon.Image = img
		icon.Visible = img ~= ""
	end
	if fallback and fallback:IsA("TextLabel") then
		fallback.Text = "\u{2B50}"
		fallback.Visible = img == ""
	end
	-- make room for one more button in the dock
	local layout = dock:FindFirstChildOfClass("UIListLayout")
	local pad = layout and layout.Padding.Offset or 8
	dock.Size = dock.Size + UDim2.fromOffset(0, warp.Size.Y.Offset + pad)
	btn.Parent = dock
	if btn:IsA("GuiButton") then
		btn.Activated:Connect(function()
			if main.Visible then
				close()
			else
				open()
			end
		end)
	end
end)
