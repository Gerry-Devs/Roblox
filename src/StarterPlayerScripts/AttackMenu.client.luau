local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- Attack menu: pets don't attack on their own any more. Tap (or click)
-- an enemy to open this window, then send ALL your pets, pick ONE pet
-- to send, or call them back.
--------------------------------------------------------------------

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local attackRemote = remotes:WaitForChild("AttackEnemy")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local enemiesFolder = workspace:WaitForChild("Enemies", 30)

local profile = profileRemote:InvokeServer()
profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
end)

local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local BLUE = Color3.fromRGB(60, 160, 255)
local RED = Color3.fromRGB(235, 70, 70)
local GREEN = Color3.fromRGB(80, 200, 110)
local GRAY = Color3.fromRGB(120, 125, 140)
local PANEL = Color3.fromRGB(30, 40, 70)

local function mk(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	mk("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local function stroke(parent, thickness)
	mk("UIStroke", { Color = OUTLINE, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function text(parent, props)
	local l = mk("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = OUTLINE,
		TextScaled = true,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local function button(parent, label, color, props)
	local b = mk("TextButton", {
		BackgroundColor3 = color,
		Text = label,
		Font = FONT,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = OUTLINE,
		TextScaled = true,
		AutoButtonColor = true,
	}, parent)
	for k, v in pairs(props) do
		b[k] = v
	end
	corner(b, 10)
	stroke(b, 2)
	mk("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------

local gui = mk("ScreenGui", { Name = "AttackMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local main = mk("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(360, 420),
	BackgroundColor3 = PANEL,
	Visible = false,
}, gui)
corner(main, 18)
stroke(main, 4)
local mainScale = mk("UIScale", {}, main)

local title = text(main, { Name = "Title", Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -80, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
local closeButton = button(main, "X", RED, { Name = "CloseButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(40, 40) })

local hpBack = mk("Frame", { Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 18), BackgroundColor3 = Color3.fromRGB(20, 20, 30) }, main)
corner(hpBack, 9)
stroke(hpBack, 2)
local hpFill = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED }, hpBack)
corner(hpFill, 9)
local hpText = text(hpBack, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })

local allButton = button(main, "ATTACK ALL", GREEN, { Position = UDim2.fromOffset(16, 80), Size = UDim2.new(0.5, -20, 0, 46) })
local stopButton = button(main, "STOP", GRAY, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 80), Size = UDim2.new(0.5, -20, 0, 46) })

text(main, { Position = UDim2.fromOffset(16, 134), Size = UDim2.new(1, -32, 0, 20), Text = "SEND PET", TextColor3 = Color3.fromRGB(200, 215, 240), TextXAlignment = Enum.TextXAlignment.Left })

local list = mk("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 160),
	Size = UDim2.new(1, -24, 1, -172),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, main)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
mk("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) }, list)

-- small message line under the window (results of your orders)
local message = text(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 90),
	Size = UDim2.new(0.8, 0, 0, 28),
	Text = "",
	Visible = false,
})
mk("UITextSizeConstraint", { MaxTextSize = 24 }, message)

local messageToken
local function say(msg, color)
	if not msg or msg == "" then
		return
	end
	local token = {}
	messageToken = token
	message.Text = msg
	message.TextColor3 = color or WHITE
	message.Visible = true
	task.delay(2.5, function()
		if messageToken == token then
			message.Visible = false
		end
	end)
end

--------------------------------------------------------------------
-- state
--------------------------------------------------------------------

local selected -- the enemy model the window is open for
local highlight = mk("Highlight", { FillTransparency = 1, OutlineColor = Color3.fromRGB(255, 220, 80), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, workspace)

local function myPetsFolder()
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	local base = world and world:FindFirstChild("Base_" .. player.UserId)
	return base and base:FindFirstChild("Pets")
end

local function distanceTo(enemy)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local root = enemy:FindFirstChild("Root")
	if not hrp or not root then
		return math.huge
	end
	return Vector2.new(root.Position.X - hrp.Position.X, root.Position.Z - hrp.Position.Z).Magnitude
end

local function petName(entry)
	local monster = Config.GetMonster(entry.monsterId)
	return "Lv " .. (entry.level or 1) .. " " .. Config.BuildDisplayName(monster and monster.name or "Pet", entry.size, entry.finish)
end

local function order(mode, uid)
	if not selected and mode ~= "recall" then
		return
	end
	local ok, r = pcall(function()
		return attackRemote:InvokeServer(selected and selected:GetAttribute("EnemyId"), mode, uid)
	end)
	if ok and r then
		-- only say something when it didn't work (no "X pets are attacking!")
		if not r.success then
			say(r.message, Color3.fromRGB(255, 170, 90))
		end
		return r.success
	end
	return false
end

local rows = {}
local function refreshList()
	if not selected then
		return
	end
	local pets = myPetsFolder()
	local enemyId = selected:GetAttribute("EnemyId")
	local seen = {}
	local n = 0
	for i, entry in ipairs((profile and profile.base) or {}) do
		if entry.kind == "monster" then
			n += 1
			seen[entry.uid] = true
			local row = rows[entry.uid]
			if not row then
				local frame = mk("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(45, 60, 100) }, list)
				corner(frame, 10)
				local name = text(frame, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -120, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
				local status = text(frame, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -120, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5 })
				local send = button(frame, "SEND", BLUE, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(96, 34) })
				local uid = entry.uid
				send.Activated:Connect(function()
					order("one", uid)
				end)
				row = { frame = frame, name = name, status = status, send = send }
				rows[uid] = row
			end
			row.frame.LayoutOrder = i
			row.name.Text = petName(entry)
			local model = pets and pets:FindFirstChild(entry.uid)
			local target = model and model:GetAttribute("AttackTarget") or 0
			if entry.defeated or (model and (model:GetAttribute("Defeated") or model:GetAttribute("Dying"))) then
				row.status.Text = "DEFEATED - RECOVERING"
				row.status.TextColor3 = Color3.fromRGB(255, 120, 120)
				row.send.Visible = false
			elseif target == enemyId then
				row.status.Text = "ATTACKING THIS ENEMY"
				row.status.TextColor3 = Color3.fromRGB(120, 255, 140)
				row.send.Visible = false
			elseif target ~= 0 then
				row.status.Text = "FIGHTING ANOTHER ENEMY"
				row.status.TextColor3 = Color3.fromRGB(255, 205, 93)
				row.send.Visible = true
			else
				row.status.Text = "READY"
				row.status.TextColor3 = Color3.fromRGB(200, 215, 240)
				row.send.Visible = true
			end
		end
	end
	for uid, row in pairs(rows) do
		if not seen[uid] then
			row.frame:Destroy()
			rows[uid] = nil
		end
	end
	if n == 0 and not list:FindFirstChild("Empty") then
		text(list, { Name = "Empty", Size = UDim2.new(1, 0, 0, 40), Text = "Equip monsters in your pen so they can fight!", TextColor3 = Color3.fromRGB(200, 215, 240), TextWrapped = true })
	elseif n > 0 and list:FindFirstChild("Empty") then
		list.Empty:Destroy()
	end
end

local function refreshEnemy()
	if not selected then
		return
	end
	local hp = selected:GetAttribute("Health") or 0
	local max = math.max(1, selected:GetAttribute("MaxHealth") or 1)
	hpFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
	hpText.Text = Config.FormatNumber(hp) .. " / " .. Config.FormatNumber(max)
end

local function close()
	selected = nil
	highlight.Adornee = nil
	highlight.Enabled = false
	main.Visible = false
end

local function open(enemy)
	selected = enemy
	local nameLabel = enemy:FindFirstChild("NameLabel", true)
	title.Text = nameLabel and nameLabel.Text or "Enemy"
	highlight.Adornee = enemy
	highlight.Enabled = true
	-- shrink on small screens so the whole window fits
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if viewport and viewport.Y > 0 then
		mainScale.Scale = math.clamp(math.min(viewport.Y / 560, viewport.X / 760), 0.55, 1)
	end
	refreshEnemy()
	refreshList()
	if not main.Visible then
		main.Visible = true
		local target = mainScale.Scale
		mainScale.Scale = target * 0.85
		TweenService:Create(mainScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = target }):Play()
	end
end

closeButton.Activated:Connect(close)
allButton.Activated:Connect(function()
	if order("all") then
		close()
	end
end)
stopButton.Activated:Connect(function()
	order("stop")
	refreshList()
end)

-- keep the window live while it's open; close it if the enemy is gone
task.spawn(function()
	while true do
		task.wait(0.25)
		if selected then
			if not selected.Parent or selected:GetAttribute("Dead") or distanceTo(selected) > Config.Combat.orderRange + 15 then
				close()
			else
				refreshEnemy()
				refreshList()
			end
		end
	end
end)

--------------------------------------------------------------------
-- tapping an enemy. Enemy parts ignore raycasts (so pets and the camera
-- never bump into them), so pick the enemy by where it is on screen.
--------------------------------------------------------------------

-- Which enemy is under this screen point? The whole body counts (its
-- bounding box on screen, plus some padding so it's easy to hit on a
-- phone). WorldToScreenPoint matches InputObject.Position (both leave
-- out the top bar), so taps line up with what you see.
local TAP_PADDING = 24
local function enemyAtScreen(pos)
	local camera = workspace.CurrentCamera
	if not camera or not enemiesFolder then
		return nil
	end
	local camPos = camera.CFrame.Position
	local best, bestD
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		local root = enemy:FindFirstChild("Root")
		if root and enemy:IsA("Model") and not enemy:GetAttribute("Dead") then
			local depth = (root.Position - camPos).Magnitude
			if depth < 250 and (not bestD or depth < bestD) then
				local ok, cf, size = pcall(enemy.GetBoundingBox, enemy)
				if ok then
					local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
					local anyInFront = false
					for _, x in ipairs({ -0.5, 0.5 }) do
						for _, y in ipairs({ -0.5, 0.5 }) do
							for _, z in ipairs({ -0.5, 0.5 }) do
								local corner = (cf * CFrame.new(size.X * x, size.Y * y, size.Z * z)).Position
								local sp = camera:WorldToScreenPoint(corner)
								if sp.Z > 0 then
									anyInFront = true
									minX, maxX = math.min(minX, sp.X), math.max(maxX, sp.X)
									minY, maxY = math.min(minY, sp.Y), math.max(maxY, sp.Y)
								end
							end
						end
					end
					if anyInFront and pos.X >= minX - TAP_PADDING and pos.X <= maxX + TAP_PADDING
						and pos.Y >= minY - TAP_PADDING and pos.Y <= maxY + TAP_PADDING then
						best, bestD = enemy, depth -- the one closest to the camera wins
					end
				end
			end
		end
	end
	return best
end

-- only a real tap/click: dragging to turn the camera never opens the menu
local pressStart = {}
local TAP_MOVE, TAP_TIME = 14, 0.45
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressStart[input] = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock() }
	end
end)
UserInputService.InputChanged:Connect(function(input)
	local p = pressStart[input]
	if p and (Vector2.new(input.Position.X, input.Position.Y) - p.pos).Magnitude > TAP_MOVE then
		pressStart[input] = nil
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local p = pressStart[input]
	pressStart[input] = nil
	if not p or os.clock() - p.t > TAP_TIME then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if (pos - p.pos).Magnitude > TAP_MOVE then
		return
	end
	local enemy = enemyAtScreen(pos)
	if not enemy then
		return
	end
	-- you have to walk up to an enemy before you can attack it
	if distanceTo(enemy) > Config.Combat.orderRange then
		say("Get closer to attack that enemy!", Color3.fromRGB(255, 170, 90))
		return
	end
	open(enemy)
end)
