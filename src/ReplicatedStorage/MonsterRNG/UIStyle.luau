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
	UIStyle.studs(card, 22, 0.6)
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
		-- script-built X: its text is on the button itself, under the studs;
		-- draw it with a Label on top instead
		label = mk("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Text = button.Text ~= "" and button.Text or "X",
			Font = button.Font,
			TextScaled = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.62, 0.62),
		}, button)
		button.Text = ""
		local pad = button:FindFirstChildOfClass("UIPadding")
		if pad then
			pad:Destroy()
		end
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

-- studs (and dark panels) for the parts inside a window
local SKIP_NAMES = { Studs = true, Rim = true, SkinHeader = true, Fill = true, Bar = true, Track = true, Line = true, Edge = true, RarityGlow = true, BottomFill = true, SquareLeft = true, SquareBottom = true }
local function isNavy(c)
	-- the old dark-blue panel colors
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	return b > r + 20 and b > g + 10 and r < 90 and g < 90 and b < 170
end
local function studOne(d)
	if not d:IsA("GuiObject") or d:IsA("TextLabel") or d:IsA("TextBox") or d:IsA("ImageLabel") then
		return
	end
	if SKIP_NAMES[d.Name] or d:GetAttribute("NoStuds") or d.BackgroundTransparency > 0.6 then
		return
	end
	if d:IsA("ImageButton") and d.Image ~= "" then
		return -- a picture button: leave the picture alone
	end
	if d.Size.Y.Scale == 0 and d.Size.Y.Offset < 20 then
		return -- thin bars
	end
	if d:IsA("Frame") and isNavy(d.BackgroundColor3) then
		d.BackgroundColor3 = UIStyle.BODY_DARK
	end
	local hasText = d:IsA("TextButton") and d.Text ~= ""
	UIStyle.studs(d, d:IsA("GuiButton") and 26 or 32, (d:IsA("GuiButton") and not hasText) and 0.3 or 0.6)
end
function UIStyle.studInside(window, skip)
	local function skipped(d)
		for s in pairs(skip) do
			if s and (d == s or d:IsDescendantOf(s)) then
				return true
			end
		end
		return false
	end
	for _, d in ipairs(window:GetDescendants()) do
		if not skipped(d) then
			pcall(studOne, d)
		end
	end
	window.DescendantAdded:Connect(function(d)
		task.defer(function()
			if d.Parent and not skipped(d) and d.Name ~= "Studs" then
				pcall(studOne, d)
			end
		end)
	end)
end

-- Turn any window into the Backpack look: a blue-to-cyan studded header
-- bar across the top (title on the left), the red studded X at its right
-- end, and a dark studded body with a light inner rim. Everything that
-- was inside the window moves down to make room for the header.
UIStyle.HEADER = 64
function UIStyle.skinWindow(window, closeBtn)
	if window:GetAttribute("Skinned") then
		return
	end
	window:SetAttribute("Skinned", true)
	local H = UIStyle.HEADER
	local z = window.ZIndex

	-- body
	window.BackgroundColor3 = UIStyle.BODY
	window.BackgroundTransparency = 0
	local grad = window:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 205, 215))
		grad.Rotation = 90
	end
	child(window, "UICorner", "UICorner").CornerRadius = UDim.new(0, 18)
	local stroke = window:FindFirstChildOfClass("UIStroke") or mk("UIStroke", {}, window)
	stroke.Color = UIStyle.OUTLINE
	stroke.Thickness = math.max(stroke.Thickness, 5)

	-- where the old content starts: move it all down under the header
	local oldTitle = window:FindFirstChild("Title")
	if not (oldTitle and oldTitle:IsA("GuiObject")) then
		-- script-built windows: a title "bubble" (a frame with a text in
		-- it) sitting on the top edge of the window
		oldTitle = nil
		for _, c in ipairs(window:GetChildren()) do
			if c:IsA("Frame") and c ~= closeBtn and c.Position.Y.Scale == 0 and c.Position.Y.Offset <= 12
				and c.Size.Y.Offset > 0 and c.Size.Y.Offset <= 90 and c:FindFirstChildWhichIsA("TextLabel") then
				oldTitle = c
				break
			end
		end
	end
	local titleText, titleIcon
	if oldTitle and oldTitle:IsA("GuiObject") then
		titleText = oldTitle:FindFirstChild("Text") or oldTitle:FindFirstChildWhichIsA("TextLabel")
		local badge = oldTitle:FindFirstChild("GoldBadge")
		titleIcon = badge
	else
		-- script-built window: its title is a big text near the top
		local best
		for _, c in ipairs(window:GetChildren()) do
			if c:IsA("TextLabel") and c.Position.Y.Scale == 0 and c.Position.Y.Offset <= 30 and c.Size.Y.Offset >= 22 then
				if not best or c.Position.Y.Offset < best.Position.Y.Offset then
					best = c
				end
			end
		end
		titleText = best
	end
	local shift = H - 34 -- old windows kept ~34px at the top for the title
	for _, c in ipairs(window:GetChildren()) do
		if c:IsA("GuiObject") and c ~= oldTitle and c ~= closeBtn and c ~= titleText and c.Name ~= "Studs" and c.Name ~= "Rim" then
			if c.Position.Y.Scale < 0.5 and c.AnchorPoint.Y < 0.5 then
				c.Position += UDim2.fromOffset(0, shift)
			end
		end
	end
	window.Size += UDim2.fromOffset(0, shift)

	UIStyle.studs(window, 44, 0.65)
	local rim = child(window, "Frame", "Rim")
	rim.Size = UDim2.new(1, -10, 1, -10)
	rim.Position = UDim2.fromOffset(5, 5)
	rim.BackgroundTransparency = 1
	rim.ZIndex = z
	child(rim, "UICorner", "UICorner").CornerRadius = UDim.new(0, 14)
	local rs = child(rim, "UIStroke", "UIStroke")
	rs.Color = UIStyle.RIM
	rs.Thickness = 3
	rs.Transparency = 0.35

	-- header bar
	local header = child(window, "Frame", "SkinHeader")
	header.Size = UDim2.new(1, 0, 0, H)
	header.Position = UDim2.fromOffset(0, 0)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ZIndex = z + 3
	child(header, "UICorner", "UICorner").CornerRadius = UDim.new(0, 18)
	local hg = child(header, "UIGradient", "UIGradient")
	hg.Color = ColorSequence.new(Color3.fromRGB(110, 95, 255), Color3.fromRGB(55, 200, 255))
	local fill = child(header, "Frame", "BottomFill")
	fill.Size = UDim2.new(1, 0, 0, 20)
	fill.Position = UDim2.new(0, 0, 1, -20)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.ZIndex = z + 3
	child(fill, "UIGradient", "UIGradient").Color = hg.Color
	local line = child(header, "Frame", "Line")
	line.Size = UDim2.new(1, 0, 0, 5)
	line.Position = UDim2.new(0, 0, 1, 0)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = UIStyle.OUTLINE
	line.ZIndex = z + 4
	local hs = UIStyle.studs(header, 30, 0)
	if hs then
		hs.ZIndex = z + 4
	end

	-- title: icon + text on the left of the header. The title keeps its
	-- place in the window (scripts look it up there); it's only moved and
	-- restyled so it sits inside the header.
	if oldTitle and oldTitle:IsA("GuiObject") then
		oldTitle.AnchorPoint = Vector2.new(0, 0)
		oldTitle.Position = UDim2.fromOffset(0, 0)
		oldTitle.Size = UDim2.new(1, -(H + 12), 0, H)
		oldTitle.BackgroundTransparency = 1
		oldTitle.ZIndex = z + 5
		for _, c in ipairs(oldTitle:GetChildren()) do
			if c:IsA("UIStroke") or c:IsA("UIGradient") then
				c.Enabled = false
			end
		end
	end
	local x = 18
	if titleIcon then
		titleIcon.AnchorPoint = Vector2.new(0, 0.5)
		titleIcon.Position = UDim2.new(0, 10, 0.5, 0)
		titleIcon.Size = UDim2.fromOffset(H - 12, H - 12)
		titleIcon.Rotation = 0
		titleIcon.ZIndex = z + 6
		for _, d in ipairs(titleIcon:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = z + 7
			end
		end
		x = H + 6
	end
	if titleText then
		titleText.AnchorPoint = Vector2.new(0, 0.5)
		titleText.Position = UDim2.new(0, x, 0.5, 0)
		titleText.Size = UDim2.new(1, -(x + (oldTitle and 10 or H + 22)), 0.58, 0)
		titleText.TextXAlignment = Enum.TextXAlignment.Left
		titleText.TextColor3 = Color3.new(1, 1, 1)
		titleText.TextStrokeTransparency = 0
		titleText.TextStrokeColor3 = UIStyle.OUTLINE
		titleText.BackgroundTransparency = 1
		titleText.ZIndex = z + 7
	end

	-- the parts inside get studs too (and the old navy panels go dark)
	UIStyle.studInside(window, { [closeBtn or false] = true, [header] = true, [rim] = true })

	-- the red X at the header's right end
	if closeBtn then
		closeBtn:SetAttribute("KeepPlace", true)
		closeBtn.AnchorPoint = Vector2.new(1, 0)
		closeBtn.Position = UDim2.fromScale(1, 0)
		closeBtn.Size = UDim2.fromOffset(H + 12, H)
		closeBtn.ZIndex = z + 7
		UIStyle.closeButton(closeBtn, true)
		local label = closeBtn:FindFirstChild("Label")
		if label then
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Size = UDim2.fromScale(0.6, 0.62)
			label.Position = UDim2.fromScale(0.5, 0.55)
		end
		local pad = closeBtn:FindFirstChildOfClass("UIPadding")
		if pad and not label then
			pad.PaddingTop = UDim.new(0.2, 0)
			pad.PaddingBottom = UDim.new(0.08, 0)
		end
		for _, d in ipairs(closeBtn:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = math.max(d.ZIndex, z + 8)
			end
		end
	end
end

return UIStyle
