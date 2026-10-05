local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

--------------------------------------------------------------------
-- World bosses on this screen: the "a boss appeared" / "defeated"
-- messages, the name of each attack in big letters, and its effect:
--   warn     red circle on the ground (the ULTIMATE hits there in 2 s)
--   slam     a shock ring around the boss
--   beam     a glowing beam to the pet it hits
--   summon   a puff where its helpers appear
--   ultimate a huge flash ring + "CRITICAL!"
--------------------------------------------------------------------
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local remote = folder:WaitForChild("Remotes"):WaitForChild("WorldBoss")
local notify = folder:WaitForChild("ClientBridge"):WaitForChild("Notify")

local OUTLINE = Color3.fromRGB(10, 12, 22)
local fx = Instance.new("Folder")
fx.Name = "BossFx"
fx.Parent = workspace

local function C(t)
	return typeof(t) == "Color3" and t or Color3.fromRGB(t[1], t[2], t[3])
end

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { fx }
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or pos.Y - 6
end

local function disc(pos, radius, color, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0.5
	p.Size = Vector3.new(0.3, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos.X, groundAt(pos) + 0.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = fx
	return p
end

-- big text in the middle of the screen
local gui = Instance.new("ScreenGui")
gui.Name = "BossFxGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9
gui.Parent = player:WaitForChild("PlayerGui")
local function bigText(text, color, time)
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local k = math.min(v.Y / 720, 1)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.3)
	l.Size = UDim2.fromOffset(700 * k, 70 * k)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = OUTLINE
	l.Parent = gui
	local s = Instance.new("UIScale")
	s.Scale = 1.6
	s.Parent = l
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(time or 1.4, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(l, (time or 1.4) + 0.5)
end

remote.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then
		return
	end
	local color = d.color and C(d.color) or Color3.fromRGB(255, 205, 60)
	if d.kind == "spawn" then
		notify:Fire("\u{1F451} WORLD BOSS! The " .. d.boss:upper() .. " appeared in " .. tostring(d.biome) .. "! " .. (d.minutes or 10) .. " minutes to beat it!", color)
		bigText("\u{1F451} " .. d.boss:upper() .. " APPEARED!", color, 2.5)
	elseif d.kind == "defeated" then
		notify:Fire("The " .. d.boss:upper() .. " was defeated! Pick up your loot!", color)
	elseif d.kind == "left" then
		notify:Fire("The " .. d.boss:upper() .. " left... nobody beat it this time.", Color3.fromRGB(200, 200, 210))
	elseif typeof(d.position) == "Vector3" then
		local pos = d.position
		if d.kind == "warn" then
			bigText("\u{26A0} " .. tostring(d.name):upper() .. "!", Color3.fromRGB(255, 80, 80), 1.8)
			local warnDisc = disc(pos, d.radius or 30, Color3.fromRGB(255, 50, 50), 0.6)
			TweenService:Create(warnDisc, TweenInfo.new(d.time or 2, Enum.EasingStyle.Linear), { Transparency = 0.25 }):Play()
			Debris:AddItem(warnDisc, (d.time or 2) + 0.1)
		elseif d.kind == "slam" or d.kind == "ultimate" then
			bigText(tostring(d.name):upper() .. (d.kind == "ultimate" and "  CRITICAL!" or "!"), d.kind == "ultimate" and Color3.fromRGB(255, 90, 60) or color, 1.2)
			local r = d.radius or 20
			local ring = disc(pos, r * 0.3, d.kind == "ultimate" and Color3.fromRGB(255, 120, 60) or color, 0.2)
			local y = ring.CFrame
			TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, r * 2, r * 2), Transparency = 1, CFrame = y }):Play()
			Debris:AddItem(ring, 0.6)
		elseif d.kind == "beam" and typeof(d.target) == "Vector3" then
			bigText(tostring(d.name):upper() .. "!", color, 1)
			local from, to = pos + Vector3.new(0, 6, 0), d.target
			local beam = Instance.new("Part")
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			beam.Material = Enum.Material.Neon
			beam.Color = color
			beam.Transparency = 0.2
			beam.Size = Vector3.new(1.4, 1.4, (to - from).Magnitude)
			beam.CFrame = CFrame.lookAt((from + to) / 2, to)
			beam.Parent = fx
			TweenService:Create(beam, TweenInfo.new(0.45), { Transparency = 1, Size = Vector3.new(0.2, 0.2, beam.Size.Z) }):Play()
			Debris:AddItem(beam, 0.5)
		elseif d.kind == "summon" then
			bigText(tostring(d.name):upper() .. "!", color, 1)
			local puff = Instance.new("Part")
			puff.Anchored = true
			puff.CanCollide = false
			puff.CanQuery = false
			puff.CanTouch = false
			puff.Shape = Enum.PartType.Ball
			puff.Material = Enum.Material.Neon
			puff.Color = color
			puff.Transparency = 0.3
			puff.Size = Vector3.new(4, 4, 4)
			puff.CFrame = CFrame.new(pos)
			puff.Parent = fx
			TweenService:Create(puff, TweenInfo.new(0.6), { Size = Vector3.new(30, 30, 30), Transparency = 1 }):Play()
			Debris:AddItem(puff, 0.7)
		end
	end
end)
