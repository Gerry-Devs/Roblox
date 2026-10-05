local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

--------------------------------------------------------------------
-- Fusion window: opens from the Fusion Machine in the Desert (no button
-- on the screen). Your backpack pets are grouped by monster + grade;
-- a group with 3+ can be fused into the next grade with 1 Fusion
-- Ticket. It uses the 3 best of the group (size / finish / kg), never
-- favorites. Tap FUSE, then CONFIRM.
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local remotes = folder:WaitForChild("Remotes")
local fuseRemote = remotes:WaitForChild("Fuse")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local bridge = folder:WaitForChild("ClientBridge")
local closeAllBridge = bridge:WaitForChild("CloseAll")
local notify = bridge:WaitForChild("Notify")

local OUTLINE = Color3.fromRGB(10, 12, 22)
local WHITE = Color3.new(1, 1, 1)
local PURPLE = Color3.fromRGB(170, 100, 255)
local GREEN = Color3.fromRGB(70, 200, 100)
local GRAY = Color3.fromRGB(80, 86, 104)
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

local gui = mk("ScreenGui", { Name = "FusionGui", ResetOnSpawn = false, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local W, H = 460, 440
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = Color3.fromRGB(40, 36, 58), Visible = false }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, main)
mk("UIStroke", { Color = OUTLINE, Thickness = 5 }, main)
local mainScale = mk("UIScale", {}, main)
local titleFrame = mk("Frame", { Name = "Title", Size = UDim2.fromOffset(260, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = PURPLE, ZIndex = 5 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, titleFrame)
label(titleFrame, "Fusion", UDim2.new(1, -24, 0.64, 0), UDim2.new(0, 12, 0.18, 0), { Name = "Text", ZIndex = 6 })
local closeBtn = mk("TextButton", { Name = "CloseButton", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), BackgroundColor3 = Color3.fromRGB(240, 58, 66), Text = "X", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 10 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, closeBtn)

local ticketText = label(main, "", UDim2.new(1, -110, 0, 28), UDim2.fromOffset(20, 40), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 190, 255) })
label(main, "3 of the same pet + grade + 1 ticket + shards = the next grade (keeps the best size / finish). A, S and SS can FAIL!", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 70), {
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 1,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(200, 200, 225),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local list = mk("ScrollingFrame", { Size = UDim2.new(1, -30, 1, -122), Position = UDim2.fromOffset(15, 108), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, main)
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10) }, list)
local empty = label(main, "No pets to fuse yet.\nYou need 3 of the same pet (same grade) in your backpack.", UDim2.new(1, -60, 0, 60), UDim2.new(0, 30, 0.45, 0), {
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 1,
	TextColor3 = Color3.fromRGB(200, 206, 225),
	Visible = false,
})

local function iconOf(monsterId)
	local bp = playerGui:FindFirstChild("Backpack")
	local icons = bp and bp:FindFirstChild("ItemIcons")
	local v = icons and icons:FindFirstChild(monsterId)
	return v and v.Value or ""
end
local function rankOf(e)
	local f = Config.GetFinishVariant(e.finish or "Normal")
	local s = Config.GetSizeVariant(e.size or "Normal")
	return (f and 1 / math.max(f.weight, 1e-9) or 0) * 1000 + (s and 1 / math.max(s.weight, 1e-9) or 0) + (e.kg or 0) * 1e-6
end

local confirmKey, confirmAt
local busy = false
local render
render = function()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local tickets = (profile and profile.items and profile.items.fusionTicket) or 0
	ticketText.Text = "\u{1F3AB} FUSION TICKETS: " .. tickets
	-- group the backpack pets (favorites are never used)
	local groups, order = {}, {}
	for _, e in ipairs((profile and profile.monsters) or {}) do
		if not e.favorite then
			local key = e.monsterId .. "|" .. (e.grade or "E")
			if not groups[key] then
				groups[key] = { monsterId = e.monsterId, grade = e.grade or "E", list = {} }
				table.insert(order, key)
			end
			table.insert(groups[key].list, e)
		end
	end
	local rows = {}
	for _, key in ipairs(order) do
		local g = groups[key]
		if #g.list >= 3 and Config.GradeIndex(g.grade) < #Config.Grades then
			table.insert(rows, g)
		end
	end
	table.sort(rows, function(a, b)
		local ma, mb = Config.GetMonster(a.monsterId), Config.GetMonster(b.monsterId)
		local ta = ma and Config.GetRarity(ma.rarity).tier or 0
		local tb = mb and Config.GetRarity(mb.rarity).tier or 0
		if ta ~= tb then
			return ta > tb
		end
		return Config.GradeIndex(a.grade) > Config.GradeIndex(b.grade)
	end)
	empty.Visible = #rows == 0
	for i, g in ipairs(rows) do
		local m = Config.GetMonster(g.monsterId)
		local r = Config.GetRarity(m and m.rarity or "Common")
		local color = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
		local nextGrade = Config.Grades[Config.GradeIndex(g.grade) + 1].key
		local row = mk("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = Color3.fromRGB(28, 26, 42) }, list)
		mk("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
		mk("UIStroke", { Color = color, Thickness = 2 }, row)
		local img = iconOf(g.monsterId)
		if img ~= "" then
			mk("ImageLabel", { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit }, row)
		end
		label(row, (m and m.name or "?") .. "  x" .. #g.list, UDim2.new(1, -180, 0, 26), UDim2.fromOffset(66, 6), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
		-- "Grade C -> B" in the grade colors
		local gl = label(row, "", UDim2.new(1, -180, 0, 24), UDim2.fromOffset(66, 34), { TextXAlignment = Enum.TextXAlignment.Left, RichText = true })
		local function hex(c)
			return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
		end
		local cost = Config.FusionCosts[nextGrade] or { chance = 1, shards = 0 }
		gl.Text = string.format('<font color="%s">GRADE %s</font>  \u{2192}  <font color="%s">%s</font>  <font color="#BFD2FF">\u{2022} %s shards%s</font>', hex(Config.GradeColor(g.grade)), g.grade, hex(Config.GradeColor(nextGrade)), nextGrade, Config.FormatNumber(cost.shards), cost.chance < 1 and string.format("  \u{2022} %d%%", math.floor(cost.chance * 100 + 0.5)) or "")
		local btn = mk("TextButton", { Size = UDim2.fromOffset(100, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = tickets > 0 and GREEN or GRAY, Text = "FUSE", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, row)
		mk("UICorner", { CornerRadius = UDim.new(0, 10) }, btn)
		mk("UIStroke", { Color = OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
		mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, btn)
		local key = g.monsterId .. "|" .. g.grade
		if confirmKey == key and os.clock() - (confirmAt or 0) < 4 then
			btn.Text = "CONFIRM?"
			btn.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
		end
		btn.Activated:Connect(function()
			if busy then
				return
			end
			if tickets < 1 then
				notify:Fire("You need a Fusion Ticket! World bosses drop them.", Color3.fromRGB(255, 120, 120))
				return
			end
			if confirmKey ~= key or os.clock() - (confirmAt or 0) >= 4 then
				confirmKey, confirmAt = key, os.clock()
				render()
				return
			end
			confirmKey = nil
			-- the 3 best of the group
			table.sort(g.list, function(a, b)
				return rankOf(a) > rankOf(b)
			end)
			local uids = { g.list[1].uid, g.list[2].uid, g.list[3].uid }
			busy = true
			local ok, res = pcall(function()
				return fuseRemote:InvokeServer(uids)
			end)
			busy = false
			if ok and res then
				notify:Fire(res.message or "", res.success and Color3.fromRGB(230, 190, 255) or (res.failed and Color3.fromRGB(255, 160, 60)) or Color3.fromRGB(255, 120, 120))
			end
			pcall(function()
				profile = profileRemote:InvokeServer()
			end)
			render()
		end)
	end
end

local function open()
	closeAllBridge:Fire("fusion")
	local v = workspace.CurrentCamera.ViewportSize
	mainScale.Scale = math.min(v.Y / 560, v.X / 760, 1)
	confirmKey = nil
	render()
	main.Visible = true
end
local function close()
	main.Visible = false
end
closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "fusion" then
		close()
	end
end)
profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FusionPrompt" then
		open()
	end
end)
-- walk away = close
task.spawn(function()
	while true do
		task.wait(0.5)
		if main.Visible then
			local machine = workspace:FindFirstChild("MonsterRNGWorld") and workspace.MonsterRNGWorld:FindFirstChild("FusionMachine")
			local core = machine and machine:FindFirstChild("Core")
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if core and hrp and (hrp.Position - core.Position).Magnitude > 30 then
				close()
			end
		end
	end
end)
