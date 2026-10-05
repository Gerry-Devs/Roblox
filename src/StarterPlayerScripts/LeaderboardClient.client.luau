local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- The leaderboard screens (LeaderboardService builds the boards and puts
-- the top 50 in each board's "Data" value). Drawn here, on this player's
-- screen, so they can be scrolled: drag the list (finger or mouse wheel)
-- or tap the big UP / DOWN arrows (easy on phones).
--------------------------------------------------------------------
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local UIStyle = require(folder:WaitForChild("UIStyle"))

local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local ROW_H = 46
local ROW_GAP = 4
local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 210, 225), Color3.fromRGB(215, 140, 80) }

local playerGui = player:WaitForChild("PlayerGui")
local attached = {} -- board model -> SurfaceGui

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function outlined(o, radius, thickness)
	mk("UICorner", { CornerRadius = UDim.new(0, radius) }, o)
	mk("UIStroke", { Color = OUTLINE, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	return o
end
local function text(parent, props)
	local l = mk("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local function attach(model)
	local screen = model:FindFirstChild("Screen")
	local data = model:FindFirstChild("Data")
	if not screen or not data then
		return
	end
	local color = model:GetAttribute("Color") or Color3.fromRGB(110, 230, 120)
	local sg = mk("SurfaceGui", {
		Name = model.Name,
		Adornee = screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		MaxDistance = 160,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	attached[model] = sg

	-- studded board
	local bg = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(28, 34, 62) }, sg)
	UIStyle.studs(bg, 60, 0.7)

	-- title: a studded brick in the board's color
	local title = outlined(mk("Frame", { Size = UDim2.new(1, -20, 0, 72), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = color, ZIndex = 2 }, bg), 14, 4)
	UIStyle.studs(title, 36, 0.35)
	text(title, { Size = UDim2.new(1, -20, 1, -14), Position = UDim2.fromOffset(10, 7), Text = model:GetAttribute("Title") or "TOP", ZIndex = 3 })

	-- the list (scrolls)
	local LIST_TOP, BAR_H = 92, 76
	local list = mk("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -20, 1, -(LIST_TOP + BAR_H + 6)),
		Position = UDim2.fromOffset(10, LIST_TOP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 14,
		ScrollBarImageColor3 = color,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		Active = true,
		ZIndex = 2,
	}, bg)
	mk("UIListLayout", { Padding = UDim.new(0, ROW_GAP), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	mk("UIPadding", { PaddingRight = UDim.new(0, 18) }, list)

	-- big arrows at the bottom (phones: tap instead of dragging)
	local bar = mk("Frame", { Size = UDim2.new(1, -20, 0, BAR_H - 10), Position = UDim2.new(0, 10, 1, -BAR_H), BackgroundTransparency = 1, ZIndex = 2 }, bg)
	local function arrow(label, x, dir)
		local b = outlined(mk("TextButton", { Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0), BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.25), Text = "", AutoButtonColor = true, ZIndex = 3 }, bar), 12, 3)
		UIStyle.studs(b, 36, 0.4)
		text(b, { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), Text = label, ZIndex = 4 })
		b.Activated:Connect(function()
			local maxY = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
			local y = math.clamp(list.CanvasPosition.Y + dir * (ROW_H + ROW_GAP) * 5, 0, maxY)
			TweenService:Create(list, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, y) }):Play()
		end)
	end
	arrow("\u{25B2} UP", 0, -1)
	arrow("DOWN \u{25BC}", 0.5, 1)

	local rows = {}
	local function row(i)
		if rows[i] then
			return rows[i]
		end
		local r = mk("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, ROW_H), BackgroundColor3 = MEDALS[i] or Color3.fromRGB(45, 52, 88), BackgroundTransparency = i <= 3 and 0.15 or 0.3, ZIndex = 3 }, list)
		outlined(r, 8, 2)
		local rank = text(r, { Size = UDim2.new(0.13, -6, 1, -12), Position = UDim2.fromOffset(8, 6), Text = "#" .. i, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
		local name = text(r, { Size = UDim2.new(0.5, -8, 1, -14), Position = UDim2.new(0.13, 4, 0, 7), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
		local value = text(r, { Size = UDim2.new(0.37, -10, 1, -14), Position = UDim2.new(0.63, 0, 0, 7), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
		rows[i] = { frame = r, rank = rank, name = name, value = value }
		return rows[i]
	end

	local function render()
		local ok, entries = pcall(HttpService.JSONDecode, HttpService, data.Value)
		if not ok or type(entries) ~= "table" then
			entries = {}
		end
		-- always at least 10 rows (empty ones show "-")
		local n = math.max(10, #entries)
		for i = 1, n do
			local e = entries[i]
			local r = row(i)
			r.frame.Visible = true
			r.name.Text = e and tostring(e.n) or "-"
			r.value.Text = e and tostring(e.v) or ""
			-- you: green name
			r.name.TextColor3 = (e and e.n == player.Name) and Color3.fromRGB(120, 255, 120) or WHITE
		end
		for i = n + 1, #rows do
			rows[i].frame.Visible = false
		end
	end
	render()
	data.Changed:Connect(render)
end

-- the boards can show up late (or stream in / out): look for them
local function scan()
	for model, sg in pairs(attached) do
		if not model.Parent or not model:FindFirstChild("Screen") then
			sg:Destroy()
			attached[model] = nil
		end
	end
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	local hub = world and world:FindFirstChild("Hub")
	if not hub then
		return
	end
	for _, m in ipairs(hub:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Leaderboard_") and not attached[m] then
			attach(m)
		end
	end
end
while true do
	pcall(scan)
	task.wait(2)
end
