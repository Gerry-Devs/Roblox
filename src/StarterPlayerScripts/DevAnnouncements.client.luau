local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")

-- Shows Dev messages (sent from the admin panel to every server) as a
-- banner notification at the top of the screen (not in the chat box), and gift notices.
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Remotes")
local devAnnounce = remotes:WaitForChild("DevAnnounce")

local gui = Instance.new("ScreenGui")
gui.Name = "DevAnnouncements"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.Parent = player:WaitForChild("PlayerGui")
local holder = Instance.new("Frame")
holder.Size = UDim2.new(0.9, 0, 0, 400)
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.Position = UDim2.new(0.5, 0, 0, 70)
holder.BackgroundTransparency = 1
holder.Parent = gui
-- keep the banners out of the way of the mini dice roll (HIDE / hidden
-- HUD: the roll plays small at the top-centre): while it's up there the
-- banners sit just below it (PC + mobile)
task.spawn(function()
	local GuiService = game:GetService("GuiService")
	while holder.Parent do
		local y = 70
		local bottomBar = player.PlayerGui:FindFirstChild("BottomBar")
		local stage = bottomBar and bottomBar:FindFirstChild("Stage")
		if stage and stage.AnchorPoint.Y == 0 and stage.Visible and bottomBar.Enabled then
			local inset = bottomBar.IgnoreGuiInset and 0 or GuiService:GetGuiInset().Y
			local reveal = stage:FindFirstChild("Reveal")
			local area = (reveal and reveal.Visible) and reveal or stage
			y = math.max(y, area.AbsolutePosition.Y + area.AbsoluteSize.Y + inset + 6)
		end
		holder.Position = UDim2.new(0.5, 0, 0, y)
		task.wait(0.2)
	end
end)
local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = holder

local OUTLINE = Color3.fromRGB(12, 10, 30)
local function banner(text, dev)
	local frame = Instance.new("Frame")
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.BackgroundTransparency = 1 -- text only, no box behind it
	frame.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = frame
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 19
	label.TextWrapped = true
	label.TextColor3 = dev and Color3.new(1, 1, 1) or Color3.fromRGB(150, 255, 160)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = OUTLINE
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	if dev then
		escaped = escaped:gsub("^%[Dev%]", '<font color="#FFD23C">[Dev]</font>')
	end
	label.Text = escaped
	label.Parent = frame
	local cons = Instance.new("UISizeConstraint")
	cons.MaxSize = Vector2.new(620, 200)
	cons.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(dev and 8 or 4, function()
		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		frame:Destroy()
	end)
end

devAnnounce.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or type(data.text) ~= "string" then
		return
	end
	local dev = data.kind == "dev"
	banner(data.text, dev)
end)
