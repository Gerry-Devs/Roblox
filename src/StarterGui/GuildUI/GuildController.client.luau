local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--------------------------------------------------------------------
-- Guild Hall window (talk to the Guild Master at the Guild stall).
--   Not in a guild: BROWSE / CREATE / INVITES
--   In a guild:     MEMBERS / INVITE / SETTINGS (owner)
-- Emblems: pick a preset (Config.Guild.presets) or paste an image id.
--------------------------------------------------------------------
local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local guildRemote = remotes:WaitForChild("GuildAction")
local guildEvent = remotes:WaitForChild("GuildEvent")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local notify = bridge:WaitForChild("Notify")
local closeAllBridge = bridge:WaitForChild("CloseAll")
local confirmBridge = bridge:WaitForChild("ConfirmPurchase")
local G = Config.Guild

local gui = script.Parent
local OUTLINE = Color3.fromRGB(12, 14, 32)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy
local PURPLE, PURPLE_DARK = Color3.fromRGB(140, 80, 235), Color3.fromRGB(62, 32, 120)
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(60, 205, 95)
local RED = Color3.fromRGB(230, 65, 65)
local BLUE = Color3.fromRGB(60, 130, 235)
local GRAY = Color3.fromRGB(105, 110, 135)
local CARD = Color3.fromRGB(34, 24, 72)
local OPEN_DISTANCE = 22

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r, stroke)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
	if stroke ~= false then
		mk("UIStroke", { Color = OUTLINE, Thickness = stroke or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
	return o
end
local function label(parent, text, size, pos, props)
	local l = mk("TextLabel", { Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
local function small(parent, text, size, pos, props)
	local l = label(parent, text, size, pos, { Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(215, 205, 245) })
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end
local function button(parent, text, size, pos, color)
	local b = mk("TextButton", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = color, Text = text, TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, AutoButtonColor = true }, parent)
	round(b, 10, 3)
	mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return b
end
local function textBox(parent, placeholder, size, pos, multi)
	local t = mk("TextBox", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = Color3.fromRGB(238, 234, 255), Text = "", PlaceholderText = placeholder, TextScaled = not multi, TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = OUTLINE, PlaceholderColor3 = Color3.fromRGB(130, 125, 160), ClearTextOnFocus = false, TextWrapped = multi == true, MultiLine = multi == true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center }, parent)
	round(t, 10, 3)
	mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, t)
	return t
end

-- a guild emblem: image id, or a preset (colour + symbol)
local function emblem(parent, size, pos, icon, imageId)
	local preset = Config.GuildPreset(icon)
	local f = mk("Frame", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = Color3.fromRGB(preset.color[1], preset.color[2], preset.color[3]) }, parent)
	round(f, 12, 3)
	mk("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 190)), Rotation = 90 }, f)
	if imageId and imageId ~= "" then
		mk("ImageLabel", { Size = UDim2.fromScale(0.9, 0.9), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Image = imageId, ScaleType = Enum.ScaleType.Fit }, f)
	else
		mk("TextLabel", { Size = UDim2.fromScale(0.8, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Text = preset.symbol, TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = WHITE, TextStrokeTransparency = 1 }, f)
	end
	return f
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local main = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(720, 500), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), BackgroundColor3 = PURPLE, Visible = false }, gui)
round(main, 20, 6)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(170, 120, 255), PURPLE_DARK), Rotation = 90 }, main)
local mainScale = mk("UIScale", {}, main)
local titleBar = mk("Frame", { Size = UDim2.fromOffset(300, 56), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = GOLD, ZIndex = 5 }, main)
round(titleBar, 16, 5)
label(titleBar, "GUILD HALL", UDim2.new(1, -30, 0.64, 0), UDim2.new(0, 15, 0.18, 0), { ZIndex = 6 })
local closeBtn = button(main, "X", UDim2.fromOffset(54, 54), UDim2.new(1, -6, 0, 6), RED)
closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
closeBtn.ZIndex = 10
local message = label(main, "", UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 1, 6), { TextColor3 = Color3.fromRGB(160, 255, 170) })

local content = mk("Frame", { Size = UDim2.new(1, -40, 1, -60), Position = UDim2.fromOffset(20, 40), BackgroundTransparency = 1 }, main)

local function flash(text, good)
	message.Text = text or ""
	message.TextColor3 = good and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 150, 150)
	local shown = message.Text
	task.delay(3, function()
		if message.Text == shown then
			message.Text = ""
		end
	end)
end

local state = { data = nil, tab = nil }
local busy = false
local function call(action, arg)
	if busy then
		return nil
	end
	busy = true
	local ok, r = pcall(function()
		return guildRemote:InvokeServer(action, arg)
	end)
	busy = false
	if not ok or type(r) ~= "table" then
		flash("Try again in a moment.", false)
		return nil
	end
	return r
end

local render -- forward

local function clearContent()
	for _, c in ipairs(content:GetChildren()) do
		c:Destroy()
	end
end

local function tabs(list, current)
	local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 }, content)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	for i, t in ipairs(list) do
		local b = button(row, t[2], UDim2.fromOffset(t[3] or 170, 42), nil, current == t[1] and GOLD or GRAY)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			state.tab = t[1]
			render()
		end)
	end
	return row
end

local function scroller(pos, size)
	local s = mk("ScrollingFrame", { Size = size, Position = pos, BackgroundColor3 = CARD, BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, content)
	round(s, 12, false)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 8) }, s)
	return s
end

local function row(parent, order, height)
	local r = mk("Frame", { Size = UDim2.new(1, 0, 0, height or 64), BackgroundColor3 = Color3.fromRGB(55, 40, 110), LayoutOrder = order }, parent)
	round(r, 12, 3)
	return r
end

--------------------------------------------------------------------
-- the emblem picker (create + settings)
--------------------------------------------------------------------
local function emblemPicker(parent, pos, selected, onPick)
	local grid = mk("Frame", { Size = UDim2.new(1, 0, 0, 104), Position = pos, BackgroundTransparency = 1 }, parent)
	mk("UIGridLayout", { CellSize = UDim2.fromOffset(46, 46), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local frames = {}
	local function mark()
		for key, f in pairs(frames) do
			local stroke = f:FindFirstChildOfClass("UIStroke")
			stroke.Color = key == selected and WHITE or OUTLINE
			stroke.Thickness = key == selected and 5 or 3
		end
	end
	for i, p in ipairs(G.presets) do
		local f = emblem(grid, UDim2.fromOffset(46, 46), nil, p.key, "")
		f.LayoutOrder = i
		frames[p.key] = f
		local hit = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, f)
		hit.Activated:Connect(function()
			selected = p.key
			mark()
			onPick(p.key)
		end)
	end
	mark()
	return grid
end

-- name / desc / emblem / image / open form (create + settings)
local function guildForm(y, init, buttonText, onSubmit)
	local form = { name = init.name or "", desc = init.desc or "", icon = init.icon or G.presets[1].key, imageId = init.imageId or "", open = init.open ~= false }
	local left = mk("Frame", { Size = UDim2.new(0.5, -8, 1, -y), Position = UDim2.fromOffset(0, y), BackgroundTransparency = 1 }, content)
	local right = mk("Frame", { Size = UDim2.new(0.5, -8, 1, -y), Position = UDim2.new(0.5, 8, 0, y), BackgroundTransparency = 1 }, content)
	small(left, "NAME (" .. G.nameMin .. "-" .. G.nameMax .. " letters)", UDim2.new(1, 0, 0, 18), UDim2.new(), { TextXAlignment = Enum.TextXAlignment.Left })
	local nameBox = textBox(left, "My Guild", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 20))
	nameBox.Text = form.name
	small(left, "DESCRIPTION", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 68), { TextXAlignment = Enum.TextXAlignment.Left })
	local descBox = textBox(left, "What is your guild about?", UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, 88), true)
	descBox.Text = form.desc
	local openBtn = button(left, "", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 188), GREEN)
	local function openText()
		openBtn.Text = form.open and "ANYONE CAN JOIN" or "INVITE ONLY"
		openBtn.BackgroundColor3 = form.open and GREEN or BLUE
	end
	openText()
	openBtn.Activated:Connect(function()
		form.open = not form.open
		openText()
	end)

	small(right, "EMBLEM", UDim2.new(1, 0, 0, 18), UDim2.new(), { TextXAlignment = Enum.TextXAlignment.Left })
	local preview = emblem(right, UDim2.fromOffset(60, 60), UDim2.new(1, -60, 0, 0), form.icon, form.imageId)
	local function refreshPreview()
		preview:Destroy()
		preview = emblem(right, UDim2.fromOffset(60, 60), UDim2.new(1, -60, 0, 0), form.icon, form.imageId ~= "" and ("rbxassetid://" .. (form.imageId:match("%d+") or "")) or "")
	end
	emblemPicker(right, UDim2.fromOffset(0, 66), form.icon, function(key)
		form.icon = key
		refreshPreview()
	end)
	small(right, "OR AN IMAGE ID (optional)", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 176), { TextXAlignment = Enum.TextXAlignment.Left })
	local imgBox = textBox(right, "e.g. 1234567890", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 196))
	imgBox.Text = (form.imageId or ""):match("%d+") or ""
	imgBox.FocusLost:Connect(function()
		form.imageId = imgBox.Text:match("%d+") or ""
		refreshPreview()
	end)
	local submit = button(right, buttonText, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 1, -54), GOLD)
	submit.Activated:Connect(function()
		form.name = nameBox.Text
		form.desc = descBox.Text
		form.imageId = imgBox.Text:match("%d+") or ""
		onSubmit(form)
	end)
	return form
end

--------------------------------------------------------------------
-- pages
--------------------------------------------------------------------
local function pageBrowse(viewOnly, myGuildId)
	local search = textBox(content, "Search a guild name...", UDim2.new(1, -250, 0, 38), UDim2.fromOffset(0, 52))
	local go = button(content, "SEARCH", UDim2.fromOffset(115, 38), UDim2.new(1, -240, 0, 52), BLUE)
	local refresh = button(content, "ALL", UDim2.fromOffset(115, 38), UDim2.new(1, -115, 0, 52), GRAY)
	local list = scroller(UDim2.fromOffset(0, 100), UDim2.new(1, 0, 1, -100))
	local function fill(query)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local r = call("browse", query)
		if not r then
			return
		end
		if #(r.list or {}) == 0 then
			small(list, query and "No guild with that name." or "No guilds yet - create the first one!", UDim2.new(1, 0, 0, 40))
		end
		for i, g in ipairs(r.list or {}) do
			local rw = row(list, i, 70)
			emblem(rw, UDim2.fromOffset(54, 54), UDim2.fromOffset(8, 8), g.icon, g.imageId)
			label(rw, g.name, UDim2.new(0.45, 0, 0, 30), UDim2.fromOffset(72, 6), { TextXAlignment = Enum.TextXAlignment.Left })
			small(rw, (g.desc ~= "" and g.desc or "No description"), UDim2.new(0.45, 0, 0, 26), UDim2.fromOffset(72, 38), { TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			label(rw, g.count .. "/" .. g.maxMembers, UDim2.new(0.14, 0, 0, 30), UDim2.new(0.58, 0, 0, 20), { TextColor3 = GOLD })
			local full = g.count >= g.maxMembers
			if viewOnly then
				-- already in a guild: just look (no join button)
				local mine = g.id == myGuildId
				local tag = label(rw, mine and "YOUR GUILD" or (full and "FULL" or (g.open and "OPEN" or "INVITE ONLY")), UDim2.new(0.25, 0, 0, 44), UDim2.new(0.74, 0, 0.5, -22), { TextColor3 = mine and GOLD or Color3.fromRGB(200, 200, 220) })
				continue
			end
			local join = button(rw, full and "FULL" or (g.open and "JOIN" or "INVITE ONLY"), UDim2.new(0.25, 0, 0, 44), UDim2.new(0.74, 0, 0.5, -22), (g.open and not full) and GREEN or GRAY)
			join.Activated:Connect(function()
				if not g.open or full then
					return
				end
				local res = call("join", g.id)
				if res then
					flash(res.message, res.success)
					if res.success then
						state.tab = nil
						render(true)
					end
				end
			end)
		end
	end
	go.Activated:Connect(function()
		fill(search.Text)
	end)
	search.FocusLost:Connect(function(enter)
		if enter then
			fill(search.Text)
		end
	end)
	refresh.Activated:Connect(function()
		search.Text = ""
		fill(nil)
	end)
	task.spawn(fill, nil)
end

local function pageCreate()
	small(content, (state.data and state.data.createFree) and "Making a guild is FREE right now!" or "Making a guild costs Robux.", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 50), { TextColor3 = Color3.fromRGB(160, 255, 170), TextXAlignment = Enum.TextXAlignment.Left })
	guildForm(78, {}, "CREATE GUILD", function(form)
		local r = call("create", form)
		if r then
			flash(r.message, r.success)
			if r.productId then
				confirmBridge:Fire({ kind = "product", id = r.productId, title = "Create a Guild", desc = "Make your own guild!" })
			end
			if r.success then
				state.tab = nil
				render(true)
			end
		end
	end)
end

local function pageInvites()
	local list = scroller(UDim2.fromOffset(0, 52), UDim2.new(1, 0, 1, -52))
	local invites = (state.data and state.data.invites) or {}
	if #invites == 0 then
		small(list, "No invites yet. A guild owner or officer can invite you by your username.", UDim2.new(1, 0, 0, 44))
	end
	for i, inv in ipairs(invites) do
		local rw = row(list, i, 66)
		emblem(rw, UDim2.fromOffset(50, 50), UDim2.fromOffset(8, 8), inv.icon, inv.imageId)
		label(rw, inv.guildName or "?", UDim2.new(0.45, 0, 0, 30), UDim2.fromOffset(68, 6), { TextXAlignment = Enum.TextXAlignment.Left })
		small(rw, "Invited by " .. (inv.from or "?"), UDim2.new(0.45, 0, 0, 22), UDim2.fromOffset(68, 38), { TextXAlignment = Enum.TextXAlignment.Left })
		local yes = button(rw, "ACCEPT", UDim2.new(0.18, 0, 0, 42), UDim2.new(0.6, 0, 0.5, -21), GREEN)
		local no = button(rw, "DECLINE", UDim2.new(0.18, 0, 0, 42), UDim2.new(0.8, 0, 0.5, -21), RED)
		yes.Activated:Connect(function()
			local r = call("accept", inv.guildId)
			if r then
				flash(r.message, r.success)
				state.tab = nil
				render(true)
			end
		end)
		no.Activated:Connect(function()
			local r = call("decline", inv.guildId)
			if r then
				flash(r.message, r.success)
				render(true)
			end
		end)
	end
end

local function guildHeader(g, role)
	local card = mk("Frame", { Size = UDim2.new(1, 0, 0, 84), Position = UDim2.fromOffset(0, 50), BackgroundColor3 = CARD }, content)
	round(card, 12, 3)
	emblem(card, UDim2.fromOffset(70, 70), UDim2.fromOffset(7, 7), g.icon, g.imageId)
	label(card, g.name, UDim2.new(0.6, 0, 0, 32), UDim2.fromOffset(88, 6), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
	small(card, g.desc ~= "" and g.desc or "No description yet.", UDim2.new(0.6, 0, 0, 38), UDim2.fromOffset(88, 40), { TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })
	label(card, g.count .. "/" .. g.maxMembers, UDim2.new(0.18, 0, 0, 34), UDim2.new(0.8, 0, 0, 8), { TextColor3 = WHITE })
	small(card, "YOU: " .. string.upper(role or "member") .. (g.open and "\nANYONE CAN JOIN" or "\nINVITE ONLY"), UDim2.new(0.2, 0, 0, 34), UDim2.new(0.78, 0, 0, 44))
end

local leaveArmed = false
local function pageMembers(g, role)
	guildHeader(g, role)
	local list = scroller(UDim2.fromOffset(0, 142), UDim2.new(1, 0, 1, -196))
	for i, m in ipairs(g.members) do
		local rw = row(list, i, 50)
		mk("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 12, 0.5, -6), BackgroundColor3 = m.online and GREEN or GRAY }, rw):SetAttribute("dot", true)
		label(rw, m.name or "?", UDim2.new(0.4, 0, 0, 28), UDim2.fromOffset(32, 11), { TextXAlignment = Enum.TextXAlignment.Left })
		local roleColor = m.role == "owner" and GOLD or (m.role == "officer" and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(200, 200, 220))
		label(rw, string.upper(m.role or "member"), UDim2.new(0.16, 0, 0, 24), UDim2.new(0.44, 0, 0, 13), { TextColor3 = roleColor })
		if role == "owner" and m.userId ~= player.UserId then
			local promote = button(rw, m.role == "officer" and "MEMBER" or "OFFICER", UDim2.new(0.17, 0, 0, 36), UDim2.new(0.62, 0, 0.5, -18), BLUE)
			local kick = button(rw, "KICK", UDim2.new(0.17, 0, 0, 36), UDim2.new(0.81, 0, 0.5, -18), RED)
			promote.Activated:Connect(function()
				local r = call(m.role == "officer" and "demote" or "promote", m.userId)
				if r then
					flash(r.message, r.success)
					render(true)
				end
			end)
			kick.Activated:Connect(function()
				if kick.Text ~= "SURE?" then
					kick.Text = "SURE?"
					task.delay(3, function()
						if kick.Parent then
							kick.Text = "KICK"
						end
					end)
					return
				end
				local r = call("kick", m.userId)
				if r then
					flash(r.message, r.success)
					render(true)
				end
			end)
		end
	end
	local leave = button(content, "LEAVE GUILD", UDim2.fromOffset(200, 44), UDim2.new(1, -200, 1, -46), RED)
	leaveArmed = false
	leave.Activated:Connect(function()
		if not leaveArmed then
			leaveArmed = true
			leave.Text = role == "owner" and #g.members > 1 and "SURE? (NEW OWNER)" or "PRESS AGAIN"
			task.delay(3, function()
				leaveArmed = false
				if leave.Parent then
					leave.Text = "LEAVE GUILD"
				end
			end)
			return
		end
		local r = call("leave")
		if r then
			flash(r.message, r.success)
			state.tab = nil
			render(true)
		end
	end)
end

local function pageInvite(g, role)
	guildHeader(g, role)
	if role ~= "owner" and role ~= "officer" then
		small(content, "Only the owner and officers can invite players.", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 160))
		return
	end
	small(content, "Invite any player by their Roblox username (they can be offline or in another server).", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 150), { TextXAlignment = Enum.TextXAlignment.Left })
	local box = textBox(content, "username", UDim2.new(1, -200, 0, 46), UDim2.fromOffset(0, 180))
	local send = button(content, "SEND INVITE", UDim2.fromOffset(190, 46), UDim2.new(1, -190, 0, 180), GREEN)
	send.Activated:Connect(function()
		local r = call("invite", box.Text)
		if r then
			flash(r.message, r.success)
			if r.success then
				box.Text = ""
			end
		end
	end)
end

local function pageSettings(g, role)
	if role ~= "owner" then
		guildHeader(g, role)
		small(content, "Only the owner can change the guild.", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 160))
		return
	end
	local slots = button(content, "+" .. G.slotStep .. " MEMBERS", UDim2.fromOffset(170, 42), UDim2.new(1, -170, 0, 0), BLUE)
	slots.Activated:Connect(function()
		local r = call("slots")
		if r then
			if r.productId then
				confirmBridge:Fire({ kind = "product", id = r.productId, title = "+" .. G.slotStep .. " Guild Members", desc = "Your guild can hold " .. G.slotStep .. " more members (up to " .. G.maxMembers .. ")." })
			else
				flash(r.message, r.success)
			end
		end
	end)
	guildForm(52, { name = g.name, desc = g.desc, icon = g.icon, imageId = g.imageId, open = g.open }, "SAVE", function(form)
		local r = call("edit", form)
		if r then
			flash(r.message, r.success)
			if r.success then
				render(true)
			end
		end
	end)
end

render = function(reload)
	if reload or not state.data then
		local r = call("get")
		if r then
			state.data = r
		end
	end
	clearContent()
	local d = state.data
	if not d then
		return
	end
	if d.guild then
		local canInvite = d.myRole == "owner" or d.myRole == "officer"
		state.tab = (state.tab == "members" or state.tab == "invite" or state.tab == "settings" or state.tab == "all") and state.tab or "members"
		local t = { { "members", "MEMBERS", 150 } }
		if canInvite then
			table.insert(t, { "invite", "INVITE", 150 })
		end
		if d.myRole == "owner" then
			table.insert(t, { "settings", "SETTINGS", 150 })
		end
		table.insert(t, { "all", "ALL GUILDS", 160 })
		tabs(t, state.tab)
		if state.tab == "all" then
			pageBrowse(true, d.guild.id)
		elseif state.tab == "invite" then
			pageInvite(d.guild, d.myRole)
		elseif state.tab == "settings" then
			pageSettings(d.guild, d.myRole)
		else
			pageMembers(d.guild, d.myRole)
		end
	else
		state.tab = (state.tab == "browse" or state.tab == "create" or state.tab == "invites") and state.tab or "browse"
		local n = #(d.invites or {})
		tabs({ { "browse", "GUILDS" }, { "create", "CREATE" }, { "invites", "INVITES" .. (n > 0 and (" (" .. n .. ")") or "") } }, state.tab)
		if state.tab == "create" then
			pageCreate()
		elseif state.tab == "invites" then
			pageInvites()
		else
			pageBrowse()
		end
	end
end

--------------------------------------------------------------------
-- open / close
--------------------------------------------------------------------
local openedAt
local function close()
	main.Visible = false
	openedAt = nil
end
local function open(anchorPart)
	closeAllBridge:Fire("guild")
	local cam = workspace.CurrentCamera
	if cam and cam.ViewportSize.Y > 0 then
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		mainScale.Scale = math.clamp(math.min((cam.ViewportSize.Y - 60) / 560, (cam.ViewportSize.X - 30) / 740), 0.45, 1) * (touch and 0.95 or 1)
	end
	openedAt = anchorPart
	main.Visible = true
	render(true)
	local target = mainScale.Scale
	mainScale.Scale = target * 0.85
	TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
end
closeBtn.Activated:Connect(close)
-- other scripts can open it too (ClientBridge.OpenGuild)
bridge:WaitForChild("OpenGuild").Event:Connect(function()
	open(nil)
end)
closeAllBridge.Event:Connect(function(except)
	if except ~= "guild" then
		close()
	end
end)

guildEvent.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then
		return
	end
	if d.kind == "changed" then
		if main.Visible then
			render(true)
		end
	elseif d.kind == "invite" then
		notify:Fire((d.from or "Someone") .. " invited you to the guild " .. (d.guildName or "") .. "! Visit the Guild Hall.", GOLD)
		if main.Visible then
			render(true)
		end
	end
end)

-- walk away = close
task.spawn(function()
	while true do
		task.wait(0.5)
		if main.Visible and openedAt then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - openedAt.Position).Magnitude > OPEN_DISTANCE then
				close()
			end
		end
	end
end)

-- the Guild Master's prompt (it moves from the counter onto the NPC)
local hooked = {}
local function hookPrompt(prompt)
	if hooked[prompt] or not prompt:IsA("ProximityPrompt") or prompt.Name ~= "GuildPrompt" then
		return
	end
	hooked[prompt] = true
	prompt.Triggered:Connect(function(who)
		if who == player then
			open(prompt.Parent)
		end
	end)
end
task.spawn(function()
	local stall = workspace:WaitForChild("MonsterRNGWorld"):WaitForChild("Hub"):WaitForChild("GuildStall", 60)
	if not stall then
		return
	end
	for _, d in ipairs(stall:GetDescendants()) do
		hookPrompt(d)
	end
	stall.DescendantAdded:Connect(hookPrompt)
end)
