--------------------------------------------------------------------
-- CombatFx: "CRITICAL!" pops over an enemy when a pet lands a crit.
--------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local function popCrit(model)
	local anchor = model:FindFirstChild("Root") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end
	local size = model:GetExtentsSize()
	local bb = Instance.new("BillboardGui")
	bb.Name = "CritPop"
	-- smaller on phones (a billboard's size is in screen pixels)
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local k = math.clamp(math.min(v.Y / 720, v.X / 1100), 0.45, 1)
	bb.Size = UDim2.fromOffset(220 * k, 70 * k)
	bb.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, size.Y * 0.6 + 2, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "CRITICAL!"
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 214, 60)
	t.Rotation = math.random(-8, 8)
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(150, 30, 10)
	st.Parent = t
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 110, 40))
	grad.Rotation = 90
	grad.Parent = t
	t.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = t
	bb.Adornee = anchor
	bb.Parent = anchor
	TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.25 }):Play()
	task.delay(0.18, function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	task.delay(0.55, function()
		TweenService:Create(t, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		TweenService:Create(bb, TweenInfo.new(0.35), { StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0) }):Play()
	end)
	Debris:AddItem(bb, 1)
end

local hooked = setmetatable({}, { __mode = "k" })
local function hook(model)
	if hooked[model] or not model:IsA("Model") then
		return
	end
	hooked[model] = true
	model:GetAttributeChangedSignal("CritHitAt"):Connect(function()
		local at = model:GetAttribute("CritHitAt")
		local delayBy = math.clamp((at or 0) - workspace:GetServerTimeNow(), 0, 0.4)
		task.delay(delayBy, popCrit, model)
	end)
end
local function watch(folder)
	for _, m in ipairs(folder:GetChildren()) do
		hook(m)
	end
	folder.ChildAdded:Connect(hook)
end
watch(workspace:WaitForChild("Enemies"))
