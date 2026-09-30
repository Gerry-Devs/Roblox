local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

--------------------------------------------------------------------
-- WindowAnimator: every window (anything with an X / CloseButton in it)
-- slides up when it opens, and slides down + shrinks away when it
-- closes. It never changes how the window itself works:
--   * open: only the window's Position is animated (its own scripts
--     keep control of its size / UIScale)
--   * close: the real window closes right away as usual; a copy of it
--     plays the closing animation and is then removed
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OPEN_TIME = 0.22
local CLOSE_TIME = 0.14
local SLIDE = 36 -- pixels
local GHOST = "WindowAnimGhost"

local watched = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------
-- Fit on screen (phones!): a window may never be bigger than the screen.
-- Its UIScale is capped so the whole window fits, with room for
-- Roblox's top bar. Windows that pick their own scale keep doing so;
-- this only stops them from getting too big.
--------------------------------------------------------------------
local GuiService = game:GetService("GuiService")
local MARGIN = 16
local function maxScaleFor(window)
	local camera = workspace.CurrentCamera
	local parent = window.Parent
	if not camera or not parent or not parent:IsA("GuiBase2d") then
		return math.huge
	end
	local v = camera.ViewportSize
	local inset = GuiService:GetGuiInset().Y
	local ps = parent.AbsoluteSize
	local w = window.Size.X.Scale * ps.X + window.Size.X.Offset
	local h = window.Size.Y.Scale * ps.Y + window.Size.Y.Offset
	if w <= 0 or h <= 0 then
		return math.huge
	end
	-- keep a little extra room for the X / title that sit on the edge
	return math.min((v.X - MARGIN * 2) / w, (v.Y - inset - MARGIN * 2 - 20) / h)
end
local fitting = setmetatable({}, { __mode = "k" })
local function watchFit(window)
	if fitting[window] then
		return
	end
	local scale = window:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "FitScale"
		scale.Parent = window
	end
	fitting[window] = scale
	local busy = false
	local function clamp()
		if busy then
			return
		end
		local cap = maxScaleFor(window)
		if scale.Scale > cap then
			busy = true
			scale.Scale = cap
			busy = false
		end
	end
	local scaleConn = scale:GetPropertyChangedSignal("Scale"):Connect(clamp)
	-- the window's own script adds its UIScale later: use that one instead
	window.ChildAdded:Connect(function(c)
		if c:IsA("UIScale") and c ~= scale and scale.Name == "FitScale" then
			scaleConn:Disconnect()
			scale:Destroy()
			scale = c
			fitting[window] = c
			scaleConn = c:GetPropertyChangedSignal("Scale"):Connect(clamp)
			task.defer(clamp)
		end
	end)
	window:GetPropertyChangedSignal("Size"):Connect(clamp)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			task.defer(clamp)
		end
	end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(clamp)
	end
	clamp()
end

local function isCloseButton(b)
	if not b:IsA("GuiButton") then
		return false
	end
	return b.Name == "CloseButton" or (b:IsA("TextButton") and b.Text == "X")
end

-- copy of the window that animates out (no scripts, not clickable)
local function playClose(window, basePos)
	local ok, ghost = pcall(function()
		return window:Clone()
	end)
	if not ok or not ghost then
		return
	end
	ghost:SetAttribute(GHOST, true)
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("GuiButton") then
			d.Active = false
			d.AutoButtonColor = false
		end
	end
	ghost.Position = basePos
	ghost.Visible = true
	local scale = ghost:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = ghost
	end
	ghost.Parent = window.Parent
	local info = TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(ghost, info, { Position = basePos + UDim2.fromOffset(0, SLIDE) }):Play()
	TweenService:Create(scale, info, { Scale = scale.Scale * 0.8 }):Play()
	Debris:AddItem(ghost, CLOSE_TIME + 0.02)
end

local function watch(window)
	if watched[window] or not window:IsA("GuiObject") or window:GetAttribute(GHOST) then
		return
	end
	local w = { basePos = window.Position, tween = nil }
	watched[window] = w
	watchFit(window)

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Parent then
			return
		end
		if window.Visible then
			-- where the window really sits (not a spot left over from an
			-- unfinished slide)
			if w.tween then
				w.tween:Cancel()
				w.tween = nil
			else
				w.basePos = window.Position
			end
			window.Position = w.basePos + UDim2.fromOffset(0, SLIDE)
			local tw = TweenService:Create(window, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = w.basePos })
			w.tween = tw
			tw.Completed:Connect(function()
				if w.tween == tw then
					w.tween = nil
				end
			end)
			tw:Play()
		else
			if w.tween then
				w.tween:Cancel()
				w.tween = nil
			end
			window.Position = w.basePos
			playClose(window, w.basePos)
		end
	end)
end

local function check(d)
	local window = d.Parent
	if isCloseButton(d) and window and window:IsA("GuiObject") and not window:GetAttribute(GHOST) then
		watch(window)
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
