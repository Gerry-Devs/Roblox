local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--------------------------------------------------------------------
-- Inspect: tap (or click) another player to see their rebirths, cash/s,
-- Index, pen and 6 best pets. The window gets the studded look + phone
-- fit automatically (CloseButtonFixer / WindowAnimator).
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local inspectRemote = folder:WaitForChild("Remotes"):WaitForChild("InspectPlayer")
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

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local gui = mk("ScreenGui", { Name = "InspectGui", ResetOnSpawn = false, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local W, H = 460, 400
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = Color3.fromRGB(40, 44, 58), Visible = false }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, main)
mk("UIStroke", { Color = OUTLINE, Thickness = 5 }, main)
local mainScale = mk("UIScale", {}, main)
local titleFrame = mk("Frame", { Name = "Title", Size = UDim2.fromOffset(260, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(90, 170, 255), ZIndex = 5 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, titleFrame)
label(titleFrame, "Player", UDim2.new(1, -24, 0.64, 0), UDim2.new(0, 12, 0.18, 0), { Name = "Text", ZIndex = 6 })
local closeBtn = mk("TextButton", { Name = "CloseButton", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), BackgroundColor3 = Color3.fromRGB(240, 58, 66), Text = "X", TextScaled = true, Font = FONT, TextColor3 = WHITE, ZIndex = 10 }, main)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, closeBtn)

local avatar = mk("ImageLabel", { Size = UDim2.fromOffset(78, 78), Position = UDim2.fromOffset(20, 40), BackgroundColor3 = Color3.fromRGB(28, 31, 42) }, main)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
mk("UIStroke", { Color = OUTLINE, Thickness = 3 }, avatar)
local nameText = label(main, "", UDim2.new(1, -130, 0, 30), UDim2.fromOffset(110, 40), { TextXAlignment = Enum.TextXAlignment.Left })
local statText = label(main, "", UDim2.new(1, -130, 0, 22), UDim2.fromOffset(110, 72), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 255, 150) })
local infoText = label(main, "", UDim2.new(1, -130, 0, 20), UDim2.fromOffset(110, 96), { TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.6, TextColor3 = Color3.fromRGB(205, 210, 230) })
label(main, "BEST PETS", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 128), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
local grid = mk("Frame", { Size = UDim2.new(1, -40, 1, -170), Position = UDim2.fromOffset(20, 156), BackgroundTransparency = 1 }, main)
mk("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0.5, -6), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

local function iconOf(monsterId)
	local bp = playerGui:FindFirstChild("Backpack")
	local icons = bp and bp:FindFirstChild("ItemIcons")
	local v = icons and icons:FindFirstChild(monsterId)
	return v and v.Value or ""
end

local function render(d)
	nameText.Text = (d.displayName or d.name) .. (d.displayName and d.displayName ~= d.name and ("  @" .. d.name) or "")
	statText.Text = "REBIRTH " .. d.rebirths .. "  \u{2022}  $" .. Config.FormatNumber(d.income) .. "/s"
	infoText.Text = "Index " .. d.indexFound .. "/" .. d.indexTotal .. "  \u{2022}  Pen: " .. (d.pen or "Normal") .. (d.sizesDone > 0 and (" +" .. d.sizesDone .. " size") or "") .. "  \u{2022}  " .. Config.FormatNumber(d.rolls) .. " rolls"
	avatar.Image = ""
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, d.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then
			avatar.Image = img
		end
	end)
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if #d.best == 0 then
		label(grid, "No pets yet", UDim2.new(1, 0, 1, 0), nil, { LayoutOrder = 1 })
	end
	for i, e in ipairs(d.best) do
		local m = Config.GetMonster(e.monsterId)
		local r = Config.GetRarity(m and m.rarity or "Common")
		local color = Color3.fromRGB(r.color[1], r.color[2], r.color[3])
		local card = mk("Frame", { LayoutOrder = i, BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45) }, grid)
		mk("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
		mk("UIStroke", { Color = color, Thickness = 3 }, card)
		local img = iconOf(e.monsterId)
		if img ~= "" then
			mk("ImageLabel", { Size = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit }, card)
		else
			label(card, string.sub(m and m.name or "?", 1, 1), UDim2.fromScale(0.4, 0.4), UDim2.fromScale(0.3, 0.08))
		end
		label(card, Config.BuildDisplayName(m and m.name or "?", e.size, e.finish), UDim2.new(1, -8, 0.2, 0), UDim2.new(0, 4, 0.56, 0), { TextColor3 = color:Lerp(WHITE, 0.3) })
		label(card, "Lv " .. e.level .. "  $" .. Config.FormatNumber(e.income) .. "/s", UDim2.new(1, -8, 0.18, 0), UDim2.new(0, 4, 0.78, 0), { Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.6 })
	end
end

local function close()
	main.Visible = false
end
closeBtn.Activated:Connect(close)
closeAllBridge.Event:Connect(function(except)
	if except ~= "inspect" then
		close()
	end
end)

local busy = false
local function inspect(target)
	if busy then
		return
	end
	busy = true
	local ok, d = pcall(function()
		return inspectRemote:InvokeServer(target.UserId)
	end)
	busy = false
	if not ok or type(d) ~= "table" then
		return
	end
	closeAllBridge:Fire("inspect")
	local v = workspace.CurrentCamera.ViewportSize
	mainScale.Scale = math.min(v.Y / 560, v.X / 760, 1)
	render(d)
	main.Visible = true
end

--------------------------------------------------------------------
-- tapping a player (a real tap, not a camera drag)
--------------------------------------------------------------------
local function playerAt(pos)
	local camera = workspace.CurrentCamera
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			table.insert(chars, p.Character)
		end
	end
	if #chars == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = chars
	local ray = camera:ScreenPointToRay(pos.X, pos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not hit then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and not Players:GetPlayerFromCharacter(model) do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model and Players:GetPlayerFromCharacter(model)
end

local pressStart = {}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressStart[input] = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock() }
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local p = pressStart[input]
	pressStart[input] = nil
	if not p or os.clock() - p.t > 0.45 then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if (pos - p.pos).Magnitude > 14 or player:GetAttribute("HeldKind") then
		return -- dragging the camera / placing an egg
	end
	local target = playerAt(pos)
	if target then
		inspect(target)
	end
end)
