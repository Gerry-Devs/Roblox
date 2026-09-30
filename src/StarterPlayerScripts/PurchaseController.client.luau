local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- Purchase confirmation window (every gamepass + developer product).
-- Other scripts fire ClientBridge.ConfirmPurchase with:
--   { kind = "pass" | "product", id = number, title = string,
--     desc = string, image = "rbxassetid://..", note = string? }
-- The player sees the item's info and must press BUY before the
-- Roblox purchase prompt opens.
--------------------------------------------------------------------

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local clientBridge = monsterFolder:WaitForChild("ClientBridge")
local confirmBridge = clientBridge:WaitForChild("ConfirmPurchase")
local notifyBridge = clientBridge:WaitForChild("Notify")
local remotes = monsterFolder:WaitForChild("Remotes")

local OUTLINE = Color3.fromRGB(10, 15, 35)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.LuckiestGuy

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local gui = mk("ScreenGui", { Name = "PurchaseConfirm", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false }, player:WaitForChild("PlayerGui"))
local shade = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false }, gui)
-- fixed design size; a UIScale shrinks it to fit any screen (phones too)
local W, H = 380, 440
local win = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(30, 54, 118) }, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, win)
mk("UIStroke", { Color = OUTLINE, Thickness = 4 }, win)
mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 120, 230), Color3.fromRGB(30, 54, 130)), Rotation = 90 }, win)
local scale = mk("UIScale", { Scale = 1 }, win)

local title = mk("TextLabel", { Size = UDim2.new(1, -60, 0, 34), Position = UDim2.fromOffset(16, 12), BackgroundTransparency = 1, Text = "", TextScaled = true, Font = FONT, TextColor3 = Color3.fromRGB(255, 225, 120), TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, TextXAlignment = Enum.TextXAlignment.Left }, win)
local close = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = Color3.fromRGB(235, 70, 70), Text = "X", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, win)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, close)
mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)

local iconBg = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1 }, win)
local icon = mk("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit }, iconBg)
local iconText = mk("TextLabel", { Size = UDim2.fromScale(0.7, 0.5), Position = UDim2.fromScale(0.15, 0.25), BackgroundTransparency = 1, Text = "", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, iconBg)

local desc = mk("TextLabel", { Position = UDim2.new(0, 16, 0, 180), Size = UDim2.new(1, -32, 0, 118), BackgroundTransparency = 1, Text = "", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(225, 235, 255), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top }, win)
mk("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, desc)
-- big amount (cash packs): shown instead of the description
local bigText = mk("TextLabel", { Position = UDim2.new(0, 16, 0, 196), Size = UDim2.new(1, -32, 0, 70), BackgroundTransparency = 1, Text = "", TextScaled = true, Font = FONT, TextColor3 = Color3.fromRGB(120, 255, 150), TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE, Visible = false }, win)
local note = mk("TextLabel", { Position = UDim2.new(0, 16, 0, 304), Size = UDim2.new(1, -32, 0, 26), BackgroundTransparency = 1, Text = "", TextScaled = true, Font = FONT, TextColor3 = Color3.fromRGB(120, 255, 150), TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, win)

local buy = mk("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -40, 0, 62), BackgroundColor3 = Color3.fromRGB(60, 205, 95), Text = "BUY", TextScaled = true, Font = FONT, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = OUTLINE }, win)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, buy)
mk("UIStroke", { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, buy)
mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, buy)

local current
local priceCache = {}

local function hide()
	current = nil
	gui.Enabled = false
end
close.Activated:Connect(hide)
shade.Activated:Connect(hide)

local function priceOf(kind, id)
	local key = kind .. id
	if priceCache[key] then
		return priceCache[key]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
	end)
	if ok and info and info.PriceInRobux then
		priceCache[key] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

local function show(req)
	if type(req) ~= "table" or type(req.id) ~= "number" then
		return
	end
	current = req
	title.Text = string.upper(req.title or "Purchase")
	desc.Text = req.desc or ""
	desc.Visible = req.bigText == nil
	bigText.Text = req.bigText or ""
	bigText.Visible = req.bigText ~= nil
	note.Text = req.note or ""
	local img = req.image
	icon.Image = (img and img ~= "") and img or ""
	iconText.Text = (img and img ~= "") and "" or (req.fallback or string.upper(string.sub(req.title or "?", 1, 2)))
	buy.Text = "BUY"
	gui.Enabled = true
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.clamp(math.min((vp.Y - 60) / H, (vp.X - 40) / W), 0.4, 1.15)
	scale.Scale = fit * 0.85
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = fit }):Play()
	task.spawn(function()
		local p = priceOf(req.kind, req.id)
		if current == req and p then
			buy.Text = "BUY  \u{E002} " .. p
		end
	end)
end
confirmBridge.Event:Connect(show)

buy.Activated:Connect(function()
	local req = current
	if not req then
		return
	end
	hide()
	if req.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, req.id)
	else
		MarketplaceService:PromptProductPurchase(player, req.id)
	end
end)

-- the server says a developer product was delivered
local notice = remotes:WaitForChild("PurchaseNotice", 30)
if notice then
	notice.OnClientEvent:Connect(function(data)
		if type(data) == "table" and data.text then
			notifyBridge:Fire(data.text, Color3.fromRGB(120, 255, 150))
		end
	end)
end
