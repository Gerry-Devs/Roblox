local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local fxRemote = monsterFolder:WaitForChild("Remotes"):WaitForChild("CombatFx")

--------------------------------------------------------------------
-- Combat visuals (this player's screen only): enemy animation, health
-- bars, pet health bars, loot / XP popups, "pet defeated" alerts.
--------------------------------------------------------------------

local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy

--------------------------------------------------------------------
-- enemies
--------------------------------------------------------------------

local enemiesFolder = workspace:WaitForChild("Enemies", 30)
local tracked = {}

local tracking = {}
local function track(model)
	if tracked[model] or tracking[model] or not model:IsA("Model") then
		return
	end
	tracking[model] = true
	local function stop()
		tracking[model] = nil
	end
	local root = model:WaitForChild("Root", 5)
	local body = root and (model:FindFirstChild("Body", true) or root)
	if not root or not body then
		stop()
		return
	end
	local st = {
		root = root,
		body = body,
		bodyMotor = root:FindFirstChild("BodyMotor"),
		footL = root:FindFirstChild("FootL"),
		footR = root:FindFirstChild("FootR"),
		s = model:GetAttribute("BodySize") or 4,
		phase = math.random() * math.pi * 2,
		baseColor = body.Color,
		hitAt = 0,
		attackAt = 0,
		parts = {},
		rainbow = model:GetAttribute("Finish") == "Rainbow",
	}
	st.footLC0 = st.footL and st.footL.C0
	st.footRC0 = st.footR and st.footR.C0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			table.insert(st.parts, p)
		end
	end
	-- the health bar can replicate a moment after the model itself, so look
	-- it up again until it's there (otherwise the bar never moves)
	local bar, fill, hpText
	local function findBar()
		if fill and fill.Parent then
			return true
		end
		bar = root:FindFirstChild("EnemyBar")
		local barFrame = bar and bar:FindFirstChild("Bar")
		fill = barFrame and barFrame:FindFirstChild("Fill")
		if not fill then
			return false
		end
		-- HP number on the bar
		hpText = Instance.new("TextLabel")
		hpText.Size = UDim2.fromScale(1, 1.6)
		hpText.AnchorPoint = Vector2.new(0.5, 0.5)
		hpText.Position = UDim2.fromScale(0.5, 0.5)
		hpText.BackgroundTransparency = 1
		hpText.TextScaled = true
		hpText.Font = FONT
		hpText.TextColor3 = WHITE
		hpText.TextStrokeTransparency = 0
		hpText.TextStrokeColor3 = OUTLINE
		hpText.ZIndex = 5
		hpText.Parent = barFrame
		return true
	end
	if not findBar() then
		local bb = root:WaitForChild("EnemyBar", 5)
		local barFrame = bb and bb:WaitForChild("Bar", 5)
		if barFrame then
			barFrame:WaitForChild("Fill", 5)
		end
		findBar()
	end
	local lastHealth = model:GetAttribute("Health") or 0
	local function updateBar()
		local h = model:GetAttribute("Health") or 0
		local m = model:GetAttribute("MaxHealth") or 1
		if findBar() then
			fill.Size = UDim2.fromScale(math.clamp(h / m, 0, 1), 1)
			hpText.Text = Config.FormatNumber(h)
		end
		-- floating damage number when it takes a hit (only if you're close)
		local camera = workspace.CurrentCamera
		if h < lastHealth and camera and (root.Position - camera.CFrame.Position).Magnitude < 110 then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(70, 22)
			bb.StudsOffset = Vector3.new(math.random(-15, 15) / 10, (model:GetAttribute("BodySize") or 4) * 0.5 + 0.5, 0)
			bb.AlwaysOnTop = true
			bb.LightInfluence = 0
			bb.Parent = root
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = "-" .. Config.FormatNumber(lastHealth - h)
			t.TextScaled = true
			t.Font = FONT
			t.TextColor3 = Color3.fromRGB(255, 235, 120)
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = OUTLINE
			t.Parent = bb
			TweenService:Create(bb, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
			TweenService:Create(t, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.75, function()
				bb:Destroy()
			end)
		end
		lastHealth = h
	end
	model:GetAttributeChangedSignal("Health"):Connect(updateBar)
	model:GetAttributeChangedSignal("Hits"):Connect(function()
		st.hitAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Attacks"):Connect(function()
		st.attackAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Dead"):Connect(function()
		st.deadAt = os.clock()
		findBar()
		if bar then
			bar.Enabled = false
		end
	end)
	updateBar()
	tracked[model] = st
	stop()
end

if enemiesFolder then
	-- keep checking: with StreamingEnabled far-away enemies load in later
	task.spawn(function()
		while true do
			task.wait(1)
			for _, m in ipairs(enemiesFolder:GetChildren()) do
				if not tracked[m] then
					task.spawn(track, m)
				end
			end
		end
	end)
	for _, m in ipairs(enemiesFolder:GetChildren()) do
		task.spawn(track, m)
	end
	enemiesFolder.ChildAdded:Connect(function(m)
		task.spawn(track, m)
	end)
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local t = os.clock()
	for model, st in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
		elseif (st.root.Position - camPos).Magnitude < 170 and st.bodyMotor then
			local moving = model:GetAttribute("Moving")
			-- hop while walking, gentle breathing while idle
			local bob = moving and math.abs(math.sin(t * 9 + st.phase)) * st.s * 0.12 or math.sin(t * 2.5 + st.phase) * st.s * 0.04
			-- lunge forward when attacking
			local lunge = 0
			local sinceAttack = t - st.attackAt
			if sinceAttack < 0.3 then
				lunge = math.sin(sinceAttack / 0.3 * math.pi) * st.s * 0.45
			end
			-- recoil when hit
			local sinceHit = t - st.hitAt
			local recoil = sinceHit < 0.15 and math.sin(sinceHit / 0.15 * math.pi) * st.s * 0.12 or 0
			st.bodyMotor.C0 = CFrame.new(0, bob, -lunge + recoil) * CFrame.Angles(math.rad(-lunge * 8 / st.s), 0, 0)
			if st.footL and st.footR then
				local sw = moving and math.sin(t * 9 + st.phase) * st.s * 0.16 or 0
				st.footL.C0 = st.footLC0 * CFrame.new(0, math.max(0, sw) * 0.5, sw)
				st.footR.C0 = st.footRC0 * CFrame.new(0, math.max(0, -sw) * 0.5, -sw)
			end
			if st.rainbow then
				st.baseColor = Color3.fromHSV((t * 0.25 + st.phase) % 1, 0.8, 1)
			end
			st.body.Color = sinceHit < 0.12 and st.baseColor:Lerp(WHITE, 0.65) or st.baseColor
			if st.deadAt then
				local k = math.clamp((t - st.deadAt) / 0.5, 0, 1)
				for _, p in ipairs(st.parts) do
					p.LocalTransparencyModifier = k
				end
				st.bodyMotor.C0 = CFrame.new(0, k * st.s * 0.8, 0)
			end
		end
	end
end)

--------------------------------------------------------------------
-- your pets' health bars (only shown while hurt)
--------------------------------------------------------------------

local function ensurePetBar(model)
	local body = model:FindFirstChild("MonsterBody")
	if not body then
		return nil
	end
	local bb = body:FindFirstChild("PetHealthBar")
	if bb then
		return bb
	end
	bb = Instance.new("BillboardGui")
	bb.Name = "PetHealthBar"
	bb.Size = UDim2.fromOffset(48, 7)
	bb.StudsOffset = Vector3.new(0, body.Size.Y / 2 + 1, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = body
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 2
	stroke.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	return bb
end

task.spawn(function()
	while true do
		local world = workspace:FindFirstChild("MonsterRNGWorld")
		local base = world and world:FindFirstChild("Base_" .. player.UserId)
		local pets = base and base:FindFirstChild("Pets")
		if pets then
			for _, model in ipairs(pets:GetChildren()) do
				local h, m = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
				if h and m and model:GetAttribute("Kind") == "monster" then
					local bb = ensurePetBar(model)
					if bb then
						local hurt = h < m and not model:GetAttribute("Defeated")
						bb.Enabled = hurt
						local k = math.clamp(h / math.max(1, m), 0, 1)
						bb.Frame.Fill.Size = UDim2.fromScale(k, 1)
						bb.Frame.Fill.BackgroundColor3 = k > 0.5 and Color3.fromRGB(90, 220, 110) or (k > 0.25 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(235, 70, 70))
					end
				end
			end
		end
		task.wait(0.2)
	end
end)

--------------------------------------------------------------------
-- Keep health bars and name tags above each monster's real head. Tall
-- models (Phoenix, Void Dragon...) reach far above their center, so a
-- fixed offset put the bar inside their body. Measure the model instead.
--------------------------------------------------------------------

local HEAD_GAP = 0.6
local function headHeight(model, center)
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok then
		return nil
	end
	return cf.Position.Y + size.Y / 2 - center.Position.Y
end

local measuredAt = setmetatable({}, { __mode = "k" }) -- model -> os.clock()
local function placeOverHead(model, center, bars)
	-- measuring big models isn't free: once, then every 5s (poses change)
	local now = os.clock()
	if measuredAt[model] and now - measuredAt[model] < 5 then
		return
	end
	measuredAt[model] = now
	local top = headHeight(model, center)
	if not top then
		return
	end
	for _, info in ipairs(bars) do
		local bb = center:FindFirstChild(info[1])
		if bb and bb:IsA("BillboardGui") then
			bb.StudsOffset = Vector3.new(0, top + HEAD_GAP, 0)
			-- shift up by part of its own height so stacked tags don't overlap
			bb.SizeOffset = Vector2.new(0, info[2])
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position
		local world = workspace:FindFirstChild("MonsterRNGWorld")
		if world and camPos then
			for _, base in ipairs(world:GetChildren()) do
				local pets = base.Name:match("^Base_") and base:FindFirstChild("Pets")
				for _, model in ipairs(pets and pets:GetChildren() or {}) do
					local body = model:FindFirstChild("MonsterBody")
					if body and (body.Position - camPos).Magnitude < 150 then
						-- health bar just over the head, name tag above it
						placeOverHead(model, body, { { "PetHealthBar", 0 }, { "MonsterName", 0.75 } })
					end
				end
			end
		end
		if enemiesFolder and camPos then
			for _, model in ipairs(enemiesFolder:GetChildren()) do
				local root = model:FindFirstChild("Root")
				if root and not model:GetAttribute("Dead") and (root.Position - camPos).Magnitude < 150 then
					placeOverHead(model, root, { { "EnemyBar", 0.5 } })
				end
			end
		end
	end
end)

--------------------------------------------------------------------
-- popups
--------------------------------------------------------------------

local toastGui = Instance.new("ScreenGui")
toastGui.Name = "CombatToasts"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.DisplayOrder = 20
toastGui.Parent = player:WaitForChild("PlayerGui")

-- notifications stack (newest at the bottom, max 3) instead of overlapping
local stack = Instance.new("Frame")
stack.Name = "Stack"
stack.AnchorPoint = Vector2.new(0.5, 0)
stack.Position = UDim2.new(0.5, 0, 0, 64)
stack.Size = UDim2.fromOffset(460, 120)
stack.BackgroundTransparency = 1
stack.Parent = toastGui
local stackScale = Instance.new("UIScale")
stackScale.Parent = stack
local stackLayout = Instance.new("UIListLayout")
stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
stackLayout.Padding = UDim.new(0, 2)
stackLayout.Parent = stack
local function fitStack()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	stackScale.Scale = math.min(v.X / 1100, v.Y / 700, 1)
end
fitStack()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitStack)
end

local toastOrder = 0
local function toast(text, color)
	toastOrder += 1
	local l = Instance.new("TextLabel")
	l.LayoutOrder = toastOrder
	l.Size = UDim2.new(1, 0, 0, 24)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.TextWrapped = true
	l.Font = FONT
	l.TextColor3 = color or WHITE
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = OUTLINE
	l.Parent = stack
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.Parent = l
	-- keep only the 3 newest
	local labels = {}
	for _, c in ipairs(stack:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #labels - 3 do
		labels[i]:Destroy()
	end
	task.delay(3, function()
		if l.Parent then
			TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.45)
			l:Destroy()
		end
	end)
end

-- other scripts send their messages here too, so nothing overlaps
monsterFolder:WaitForChild("ClientBridge"):WaitForChild("Notify").Event:Connect(function(text, color)
	toast(text, color)
end)

-- floating lines above where the enemy died: { text, color, icon }
local function popup(position, lines)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(0, 4, 0)
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 26 * #lines)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = anchor
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bb
	local labels = {}
	for i, line in ipairs(lines) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundTransparency = 1
		row.Parent = bb
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Padding = UDim.new(0, 4)
		rl.Parent = row
		if line[3] then
			local icon = Instance.new("ImageLabel")
			icon.LayoutOrder = 1
			icon.Size = UDim2.fromOffset(22, 22)
			icon.BackgroundTransparency = 1
			icon.Image = line[3]
			icon.Parent = row
			table.insert(labels, icon)
		end
		local l = Instance.new("TextLabel")
		l.LayoutOrder = 2
		l.Size = UDim2.fromOffset(0, 22)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.BackgroundTransparency = 1
		l.Text = line[1]
		l.TextSize = 18
		l.Font = FONT
		l.TextColor3 = line[2]
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = OUTLINE
		l.Parent = row
		table.insert(labels, l)
	end
	TweenService:Create(bb, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	task.delay(1.2, function()
		for _, l in ipairs(labels) do
			if l:IsA("TextLabel") then
				TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			else
				TweenService:Create(l, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
			end
		end
	end)
	task.delay(1.9, function()
		anchor:Destroy()
	end)
end

fxRemote.OnClientEvent:Connect(function(data)
	if data.kind == "kill" then
		local lines = { { "+" .. Config.FormatNumber(data.xp) .. " XP", Color3.fromRGB(140, 220, 255) } }
		for _, d in ipairs(data.drops or {}) do
			if d.kind == "shards" then
				table.insert(lines, { "+" .. d.amount .. " Rift Shards", Color3.fromRGB(190, 140, 255), Config.RiftShardImage })
			elseif d.kind == "potion" then
				local p = Config.GetPotion(d.key)
				table.insert(lines, { (p and p.name or "Potion") .. "!", Color3.fromRGB(255, 205, 93), p and p.imageId })
			elseif d.kind == "item" then
				local it = Config.Items[d.key]
				table.insert(lines, { (it and it.name or "Item") .. "!", Color3.fromRGB(255, 205, 93), it and it.imageId })
			end
		end
		for _, lu in ipairs(data.levelUps or {}) do
			table.insert(lines, { lu.name .. " reached Lv " .. lu.level .. "!", Color3.fromRGB(120, 255, 140) })
		end
		popup(data.position, lines)
	elseif data.kind == "recovered" then
		toast("Your defeated pets have recovered!", Color3.fromRGB(120, 255, 140))
	elseif data.kind == "defeated" then
		toast(data.name .. " was defeated! It recovers in " .. Config.FormatDuration(data.recoverIn or 60) .. ", or use a Revive Potion.", Color3.fromRGB(255, 110, 110))
	end
end)

-- near enemies but every pet is defeated: tell the player why nothing fights
task.spawn(function()
	local lastWarn = 0
	while true do
		task.wait(1)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local world = workspace:FindFirstChild("MonsterRNGWorld")
		local base = world and world:FindFirstChild("Base_" .. player.UserId)
		local pets = base and base:FindFirstChild("Pets")
		if hrp and pets and enemiesFolder and os.clock() - lastWarn > 20 then
			local total, down = 0, 0
			for _, m in ipairs(pets:GetChildren()) do
				if m:GetAttribute("Kind") == "monster" then
					total += 1
					if m:GetAttribute("Defeated") then
						down += 1
					end
				end
			end
			if total == 0 or down == total then
				for _, e in ipairs(enemiesFolder:GetChildren()) do
					local r = e:FindFirstChild("Root")
					if r and (r.Position - hrp.Position).Magnitude < Config.Combat.aggroRange then
						lastWarn = os.clock()
						toast(total == 0 and "Equip monsters in your pen so they can fight!"
							or "All your pets are defeated! They're recovering in your pen.", Color3.fromRGB(255, 170, 90))
						break
					end
				end
			end
		end
	end
end)
