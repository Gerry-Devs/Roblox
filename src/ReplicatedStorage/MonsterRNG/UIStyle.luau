--------------------------------------------------------------------
-- UIStyle: the cartoony studded look shared by the windows.
--   UIStyle.studs(frame, tile, transparency)  tiled studs on a frame
--   UIStyle.brick(frame, color, opts)         color + gradient + thick
--                                             outline + dark "brick side"
--   UIStyle.rarityCard(card, color)           dark card, rarity border
-- The stud image comes from Config.UIStudsImage; until it's set the
-- studs are simply left out.
--------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

local UIStyle = {}

UIStyle.OUTLINE = Color3.fromRGB(10, 12, 22)
UIStyle.BODY = Color3.fromRGB(40, 44, 58)
UIStyle.BODY_DARK = Color3.fromRGB(28, 31, 42)
UIStyle.RIM = Color3.fromRGB(185, 192, 210)

local function mk(className, props, parent)
	local o = Instance.new(className)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
UIStyle.mk = mk

local function child(parent, className, name)
	local c = parent:FindFirstChild(name)
	if not c then
		c = Instance.new(className)
		c.Name = name
		c.Parent = parent
	end
	return c
end

-- tiled studs on top of a frame's background (under its content)
function UIStyle.studs(frame, tile, transparency, color)
	local image = Config.UIStudsImage or ""
	local old = frame:FindFirstChild("Studs")
	if image == "" then
		if old then
			old:Destroy()
		end
		return nil
	end
	local studs = old or mk("ImageLabel", { Name = "Studs" }, frame)
	studs.Size = UDim2.fromScale(1, 1)
	studs.BackgroundTransparency = 1
	studs.Image = image
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(tile or 40, tile or 40)
	studs.ImageTransparency = transparency or 0.2
	studs.ImageColor3 = color or Color3.new(1, 1, 1)
	studs.ZIndex = frame.ZIndex
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		child(studs, "UICorner", "UICorner").CornerRadius = corner.CornerRadius
	end
	return studs
end

-- a rounded plastic brick: color with a soft top highlight, thick dark
-- outline and a darker "side" peeking out under it (3D look)
function UIStyle.brick(frame, color, opts)
	opts = opts or {}
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0
	child(frame, "UICorner", "UICorner").CornerRadius = UDim.new(0, opts.radius or 12)
	local stroke = frame:FindFirstChildOfClass("UIStroke") or mk("UIStroke", {}, frame)
	stroke.Color = opts.outline or UIStyle.OUTLINE
	stroke.Thickness = opts.thickness or 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local grad = frame:FindFirstChildOfClass("UIGradient") or mk("UIGradient", {}, frame)
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 210, 220))
	grad.Transparency = NumberSequence.new(0)
	if opts.side ~= false and frame.Parent and frame:IsA("GuiObject") then
		-- the brick's side: a darker copy of the shape, a few px lower
		local side = frame.Parent:FindFirstChild(frame.Name .. "_Side")
		if not side then
			side = mk("Frame", { Name = frame.Name .. "_Side", BorderSizePixel = 0 }, frame.Parent)
			mk("UICorner", {}, side)
		end
		local depth = opts.depth or 5
		side.AnchorPoint = frame.AnchorPoint
		side.Size = frame.Size
		side.Position = frame.Position + UDim2.fromOffset(0, depth)
		side.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45)
		side.ZIndex = math.max(1, frame.ZIndex - 1)
		side.Visible = frame.Visible
		side.LayoutOrder = frame.LayoutOrder
		side.UICorner.CornerRadius = UDim.new(0, opts.radius or 12)
		frame:GetPropertyChangedSignal("Visible"):Connect(function()
			side.Visible = frame.Visible
		end)
	end
	if opts.studs ~= false then
		UIStyle.studs(frame, opts.tile or 34, opts.studTransparency or 0.15)
	end
	return frame
end

-- item card: dark inside, thick rarity-colored border, a soft glow of the
-- rarity color from the bottom, and studs
function UIStyle.rarityCard(card, color)
	card.BackgroundColor3 = UIStyle.BODY_DARK
	card.BackgroundTransparency = 0
	child(card, "UICorner", "UICorner").CornerRadius = UDim.new(0, 12)
	local stroke = card:FindFirstChildOfClass("UIStroke") or mk("UIStroke", {}, card)
	stroke.Color = color
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local sg = stroke:FindFirstChildOfClass("UIGradient") or mk("UIGradient", {}, stroke)
	sg.Rotation = 90
	sg.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25))
	local grad = card:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1))
	end
	local glow = child(card, "Frame", "RarityGlow")
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.55
	glow.BorderSizePixel = 0
	glow.ZIndex = card.ZIndex
	child(glow, "UICorner", "UICorner").CornerRadius = UDim.new(0, 12)
	local gg = child(glow, "UIGradient", "UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0.2) })
	UIStyle.studs(card, 22, 0.35)
	return card
end

-- the red studded X (like the reference): red square with studs, a
-- darker red edge on the left and a white X with a thick dark outline.
-- header = true: sits at the right end of a header bar, so only its
-- top-right corner is rounded.
function UIStyle.closeButton(button, header)
	local RED = Color3.fromRGB(240, 58, 66)
	button.BackgroundColor3 = RED
	button.BackgroundTransparency = 0
	button.AutoButtonColor = true
	if button:IsA("ImageButton") then
		button.Image = ""
	end
	local radius = header and 18 or 10
	child(button, "UICorner", "UICorner").CornerRadius = UDim.new(0, radius)
	local grad = button:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 205))
		grad.Rotation = 90
	end
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Enabled = not header
		stroke.Color = UIStyle.OUTLINE
		stroke.Thickness = 3
	end
	local z = button.ZIndex
	if header then
		-- square off every corner but the top-right one
		local left = child(button, "Frame", "SquareLeft")
		left.Size = UDim2.fromScale(0.5, 1)
		left.BorderSizePixel = 0
		left.BackgroundColor3 = RED
		left.ZIndex = z
		local bottom = child(button, "Frame", "SquareBottom")
		bottom.Size = UDim2.fromScale(1, 0.5)
		bottom.Position = UDim2.fromScale(0, 0.5)
		bottom.BorderSizePixel = 0
		bottom.BackgroundColor3 = RED
		bottom.ZIndex = z
		for _, f in ipairs({ left, bottom }) do
			local g = child(f, "UIGradient", "UIGradient")
			g.Rotation = 90
			if f == bottom then
				g.Color = ColorSequence.new(Color3.fromRGB(235, 225, 225), Color3.fromRGB(215, 205, 205))
			else
				g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 205))
			end
		end
		-- darker red edge on the left, where it meets the header
		local edge = child(button, "Frame", "Edge")
		edge.Size = UDim2.new(0, 5, 1, 0)
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = Color3.fromRGB(150, 25, 35)
		edge.ZIndex = z + 1
	end
	local studs = UIStyle.studs(button, header and 22 or 16, 0)
	if studs then
		studs.ZIndex = z + 1
	end
	local label = button:FindFirstChild("Label")
	if not label and button:IsA("TextButton") then
		-- script-built X: the text is on the button itself
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextStrokeTransparency = 0
		button.TextStrokeColor3 = UIStyle.OUTLINE
		return button
	end
	if label then
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 1
		label.ZIndex = z + 2
		local ls = label:FindFirstChildOfClass("UIStroke") or mk("UIStroke", {}, label)
		ls.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		ls.Color = UIStyle.OUTLINE
		ls.Thickness = header and 3.5 or 2.5
		local icon = button:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.Visible = false -- the drawn X replaces any icon
		end
		label.Visible = true
	end
	return button
end

return UIStyle
