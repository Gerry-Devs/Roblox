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
