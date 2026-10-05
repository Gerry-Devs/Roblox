local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

--------------------------------------------------------------------
-- First-time tutorial (only for new players: no rolls yet and never
-- finished / skipped). A bouncing arrow points at what to press and an
-- info box says what to do; each step finishes by itself when you do
-- it. SKIP ends it at any time; it never shows again after that.
--   1 Roll the dice          -> an egg
--   2 Open the Backpack
--   3 Place the egg in your pen
--   4 Hatch it
--   5 Fight an enemy (pets follow you out of the pen)
--   6 The rest (upgrades, rebirth, index...) -> DONE
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local remotes = folder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local doneRemote = remotes:WaitForChild("TutorialDone")

local profile
pcall(function()
	profile = profileRemote:InvokeServer()
end)
if not profile or profile.tutorialDone or (profile.rolls or 0) > 0 then
	return -- not a new player
end
profileUpdated.OnClientEvent:Connect(function(p)
	profile = p
end)

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

local gui = mk("ScreenGui", { Name = "TutorialGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)

-- info box (upper middle)
local box = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(480, 130), BackgroundColor3 = Color3.fromRGB(28, 34, 62), BackgroundTransparency = 0.05 }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, box)
mk("UIStroke", { Color = OUTLINE, Thickness = 4 }, box)
local boxScale = mk("UIScale", {}, box)
local stepText = mk("TextLabel", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(14, 8), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, box)
local infoText = mk("TextLabel", { Size = UDim2.new(1, -28, 0, 56), Position = UDim2.fromOffset(14, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = WHITE }, box)
local function button(text, color, x)
	local b = mk("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, x, 1, -8), Size = UDim2.fromOffset(110, 30), BackgroundColor3 = color, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, box)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
	mk("UIStroke", { Color = OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
	return b
end
local skipBtn = button("SKIP", Color3.fromRGB(110, 115, 135), -10)
local nextBtn = button("NEXT", Color3.fromRGB(70, 200, 100), -128)

-- the bouncing arrow
local arrow = mk("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, Text = "\u{2B07}", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = GOLD, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, Visible = false }, gui)
local arrowScale = mk("UIScale", {}, arrow)

local function fit()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local k = math.min(v.Y / 720, v.X / 1100, 1) * 1.1
	boxScale.Scale = k
	arrowScale.Scale = k
	box.Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 70 * k)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local function bottomButton(name)
	local bb = playerGui:FindFirstChild("BottomBar")
	local bar = bb and bb:FindFirstChild("Bar")
	return bar and bar:FindFirstChild(name)
end
local function countBase(kind)
	local n = 0
	for _, e in ipairs((profile and profile.base) or {}) do
		if e.kind == kind then
			n += 1
		end
	end
	return n
end
local function kills()
	local n = 0
	for _, v in pairs((profile and profile.enemyKills) or {}) do
		n += v
	end
	return n
end

local STEPS = {
	{
		title = "WELCOME TO MONSTER RNG!",
		text = "Tap the big DICE to roll. Every roll gives you an egg - the luckier the roll, the rarer the egg!",
		target = function()
			return bottomButton("RollButton")
		end,
		done = function()
			return (profile.rolls or 0) > 0
		end,
	},
	{
		title = "STEP 2: YOUR BACKPACK",
		text = "Your eggs go to your Backpack. Open it!",
		target = function()
			return bottomButton("BackpackButton")
		end,
		done = function()
			local bp = playerGui:FindFirstChild("Backpack")
			local main = bp and bp:FindFirstChild("Main")
			return (main and main.Visible) or countBase("egg") > 0
		end,
	},
	{
		title = "STEP 3: PLACE YOUR EGG",
		text = "Tap your egg and press PLACE, then tap inside your pen (your fenced plot) to put it down.",
		done = function()
			return countBase("egg") > 0 or countBase("monster") > 0
		end,
	},
	{
		title = "STEP 4: HATCH IT",
		text = "Eggs need time to grow. When it says READY, walk up to it and press Hatch. Your monster earns cash every second!",
		done = function()
			return countBase("monster") > 0 or #((profile and profile.monsters) or {}) > 0
		end,
		canNext = true,
	},
	{
		title = "STEP 5: FIGHT!",
		text = "Walk out of your pen - your pets follow you. Go to the Forest and tap an enemy to attack. Walk over the loot it drops!",
		done = function()
			return kills() > 0
		end,
		canNext = true,
	},
	{
		title = "YOU'RE READY!",
		text = "UPGRADE for stronger stats, REBIRTH for big bonuses, collect them all in the INDEX, and fuse pets in the Desert. Have fun!",
		done = function()
			return false
		end,
		canNext = true,
		last = true,
	},
}

local stepIndex = 1
local finished = false
local function finish()
	if finished then
		return
	end
	finished = true
	pcall(function()
		doneRemote:FireServer()
	end)
	TweenService:Create(box, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	gui:Destroy()
end
local function showStep()
	local st = STEPS[stepIndex]
	if not st then
		finish()
		return
	end
	stepText.Text = st.title
	infoText.Text = st.text
	nextBtn.Visible = st.canNext == true
	nextBtn.Text = st.last and "DONE" or "NEXT"
	fit()
end
skipBtn.Activated:Connect(finish)
nextBtn.Activated:Connect(function()
	stepIndex += 1
	showStep()
end)
showStep()

-- arrow follows its button; steps finish by themselves
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if finished then
		return
	end
	local st = STEPS[stepIndex]
	local target = st and st.target and st.target()
	if target and target:IsA("GuiObject") and target.Visible and target.AbsoluteSize.X > 0 then
		local sg = target:FindFirstAncestorOfClass("ScreenGui")
		local inset = (sg and not sg.IgnoreGuiInset) and GuiService:GetGuiInset().Y or 0
		local pos = target.AbsolutePosition + Vector2.new(target.AbsoluteSize.X / 2, inset)
		local bob = math.abs(math.sin((os.clock() - t0) * 4)) * 14
		arrow.Position = UDim2.fromOffset(pos.X, pos.Y - 4 - bob)
		arrow.Visible = true
	else
		arrow.Visible = false
	end
end)
task.spawn(function()
	while not finished do
		task.wait(0.3)
		local st = STEPS[stepIndex]
		if st and profile and st.done() then
			stepIndex += 1
			showStep()
		end
	end
end)
