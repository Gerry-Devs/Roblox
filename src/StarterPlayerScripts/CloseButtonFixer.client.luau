local Players = game:GetService("Players")

--------------------------------------------------------------------
-- Every window's X (close) button sits in the same place: centered on
-- the window's top border at the top-right corner, half outside the
-- window, so it never covers anything inside it. Windows that clip their
-- children get it just inside the corner instead (it would be cut off).
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
	b.Size = UDim2.fromOffset(size, size)
	if window.ClipsDescendants then
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -MARGIN, 0, MARGIN)
	else
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(1, -(size / 2 + MARGIN), 0, 0)
	end
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
