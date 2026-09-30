local Players = game:GetService("Players")

--------------------------------------------------------------------
-- Every window gets the studded Backpack look (UIStyle.skinWindow): a
-- header bar with the title on the left and the red X at its right end.
-- Without the style module, the X falls back to this: centered on
-- the window's top border at the top-right corner, half outside the
-- window, so it never covers anything inside it. Windows that clip their
-- children get it just inside the corner instead (it would be cut off).
-- Works for windows made in StarterGui and ones built by scripts.
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MARGIN = 12

-- the red studded X look (UIStyle); if the module isn't there, X buttons
-- just keep their own look
local UIStyle
do
	local mod = game:GetService("ReplicatedStorage"):WaitForChild("MonsterRNG"):WaitForChild("UIStyle", 5)
	local ok, res = pcall(function()
		return mod and require(mod)
	end)
	UIStyle = ok and res or nil
end
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
	if fixed[b] or not isCloseButton(b) or b:GetAttribute("KeepPlace") then
		return -- KeepPlace: the window placed its own X (e.g. in a header bar)
	end
	local window = b.Parent
	if not window or not window:IsA("GuiObject") then
		return
	end
	fixed[b] = true
	-- the Backpack look for every window: header bar + red X at its end
	if UIStyle and UIStyle.skinWindow and not window:GetAttribute("NoSkin") then
		local ok, err = pcall(UIStyle.skinWindow, window, b)
		if ok then
			return
		end
		warn("Window skin failed for " .. window:GetFullName() .. ": " .. tostring(err))
	end
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
	-- LuckiestGuy draws its letters above the middle of their box, so a
	-- "centered" X looks too high in the button: nudge it down to the middle
	local label = b:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.57)
	elseif b:IsA("TextButton") and b.Text == "X" then
		local pad = b:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.16, 0)
		pad.PaddingBottom = UDim.new(0.04, 0)
		pad.Parent = b
	end
	b.ZIndex = math.max(b.ZIndex, 20)
	if UIStyle and UIStyle.closeButton then
		pcall(UIStyle.closeButton, b, false)
	end
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
