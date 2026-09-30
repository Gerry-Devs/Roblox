local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- WindowAnimator: every window (anything with an X / CloseButton in it)
-- slides up and pops in when it opens, and shrinks down and away when
-- it closes. Works for windows made in StarterGui and ones built by
-- scripts, without changing them: it watches each window's Visible.
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OPEN_TIME = 0.25
local CLOSE_TIME = 0.13
local SLIDE = 36 -- pixels

local watched = setmetatable({}, { __mode = "k" })

local function isCloseButton(b)
	if not b:IsA("GuiButton") then
		return false
	end
	return b.Name == "CloseButton" or (b:IsA("TextButton") and b.Text == "X")
end

local function watch(window)
	if watched[window] or not window:IsA("GuiObject") then
		return
	end
	local w = { basePos = window.Position, busy = false, token = 0 }
	watched[window] = w

	-- windows that don't pop in by themselves get their own scale
	local scale = window:FindFirstChildOfClass("UIScale")
	local ownScale = false
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "WindowAnimScale"
		scale.Parent = window
		ownScale = true
	end

	local function open()
		w.token += 1
		w.basePos = window.Position
		window.Position = w.basePos + UDim2.fromOffset(0, SLIDE)
		TweenService:Create(window, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = w.basePos }):Play()
		if ownScale then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end

	local function close()
		-- the window was just hidden: show it a moment longer to animate out
		w.token += 1
		local token = w.token
		local fromScale = scale.Scale
		w.busy = true
		window.Visible = true
		w.busy = false
		TweenService:Create(window, TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = w.basePos + UDim2.fromOffset(0, SLIDE),
		}):Play()
		TweenService:Create(scale, TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = fromScale * 0.8 }):Play()
		task.delay(CLOSE_TIME, function()
			if w.token ~= token then
				return -- opened again meanwhile
			end
			w.busy = true
			window.Visible = false
			w.busy = false
			window.Position = w.basePos
			scale.Scale = fromScale
		end)
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if w.busy or not window.Parent then
			return
		end
		if window.Visible then
			if w.token > 0 and window.Position ~= w.basePos then
				-- reopened while closing: put it back first
				window.Position = w.basePos
			end
			open()
		else
			close()
		end
	end)
end

local function check(d)
	if isCloseButton(d) and d.Parent and d.Parent:IsA("GuiObject") then
		watch(d.Parent)
	end
end

for _, d in ipairs(playerGui:GetDescendants()) do
	check(d)
end
playerGui.DescendantAdded:Connect(function(d)
	task.defer(function()
		if d.Parent then
			check(d)
		end
	end)
end)
