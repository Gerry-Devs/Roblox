local Players = game:GetService("Players")

--------------------------------------------------------------------
-- Every window's X (close) button sits in the same place: inside the
-- window's top-right corner, same size, never hanging off the edge
-- (so it doesn't get cut off on phones or float outside the window).
-- Works for windows made in StarterGui and ones built by scripts.
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MARGIN = 12
local fixed = setmetatable({}, { __mode = "k" })

local function isCloseButton(b)
	if not b:IsA("GuiButton") then
		return false
	end
	if b.Name == "CloseButton" then
		return true
	end
	return b:IsA("TextButton") and b.Text == "X"
end

local function fix(b)
	if fixed[b] or not isCloseButton(b) then
		return
	end
	local window = b.Parent
	if not window or not window:IsA("GuiObject") then
		return
	end
	fixed[b] = true
	local w = window.Size.X.Offset
	local size = (w > 0 and w < 420) and 42 or 50 -- small side panels get a smaller X
	b.AnchorPoint = Vector2.new(1, 0)
	b.Size = UDim2.fromOffset(size, size)
	b.Position = UDim2.new(1, -MARGIN, 0, MARGIN)
	b.ZIndex = math.max(b.ZIndex, 20)
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 21)
		end
	end
end

local function scan(root)
	for _, d in ipairs(root:GetDescendants()) do
		fix(d)
	end
end

scan(playerGui)
playerGui.DescendantAdded:Connect(function(d)
	task.defer(function()
		if d.Parent then
			fix(d)
		end
	end)
end)
