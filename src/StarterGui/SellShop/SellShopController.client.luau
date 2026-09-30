local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local sellQuoteRemote = remotes:WaitForChild("SellQuote")
local sellBulkRemote = remotes:WaitForChild("SellBulk")
local sellEggRemote = remotes:WaitForChild("SellEgg")
local sellMonsterRemote = remotes:WaitForChild("SellMonster")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local bridge = monsterFolder:WaitForChild("ClientBridge")
local closeAllBridge = bridge:WaitForChild("CloseAll")

--------------------------------------------------------------------
-- Sell Shop, opened by talking to the Seller NPC at the Sell stall.
-- Every option button has an Icon ImageLabel for your own image:
--   Main.Options.SellEggs / SellMonsters / SellAll / SellHeld .Icon
-- Favorites (★ in the backpack) are never sold by the sell-all options.
--------------------------------------------------------------------

local gui = script.Parent
local main = gui:WaitForChild("Main")
local mainScale = main:WaitForChild("UIScale")
local options = main:WaitForChild("Options")
local closeButton = main:WaitForChild("CloseButton")
local message = main:WaitForChild("Message")
local buttons = {
	eggs = options:WaitForChild("SellEggs"),
	monsters = options:WaitForChild("SellMonsters"),
	all = options:WaitForChild("SellAll"),
	held = options:WaitForChild("SellHeld"),
}

local GOLD = Color3.fromRGB(255, 205, 93)
local RED = Color3.fromRGB(255, 110, 110)
local OPEN_DISTANCE = 22

local quote
local busy = false
local openedAt
local flashToken

local function money(n)
	local s = tostring(math.floor(n or 0))
	local f = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if f:sub(1, 1) == "," then
		f = f:sub(2)
	end
	return "$" .. f
end

local function flash(text, color)
	message.Text = text
	message.TextColor3 = color
	message.TextTransparency = 0
	message.TextStrokeTransparency = 0
	local token = {}
	flashToken = token
	task.delay(2, function()
		if flashToken == token then
			TweenService:Create(message, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function setEnabled(button, enabled)
	button.AutoButtonColor = false
	button.BackgroundTransparency = enabled and 0 or 0.45
	for _, d in ipairs(button:GetDescendants()) do
		if d:IsA("TextLabel") then
			d.TextTransparency = enabled and 0 or 0.45
		elseif d:IsA("ImageLabel") then
			d.ImageTransparency = enabled and 0 or 0.45
		end
	end
end

local function refresh()
	local ok, result = pcall(function()
		return sellQuoteRemote:InvokeServer(player:GetAttribute("HeldUid"))
	end)
	if not ok or not result then
		return
	end
	quote = result

	local function plural(n, word)
		return n .. " " .. word .. (n == 1 and "" or "s")
	end
	buttons.eggs.Value.Text = plural(quote.eggs.count, "egg") .. "  •  " .. money(quote.eggs.value)
	buttons.monsters.Value.Text = plural(quote.monsters.count, "monster") .. "  •  " .. money(quote.monsters.value)
	buttons.all.Value.Text = plural(quote.all.count, "item") .. "  •  " .. money(quote.all.value)
	setEnabled(buttons.eggs, quote.eggs.count > 0)
	setEnabled(buttons.monsters, quote.monsters.count > 0)
	setEnabled(buttons.all, quote.all.count > 0)

	if quote.held then
		buttons.held.Value.Text = quote.held.favorite and ("★ " .. quote.held.name .. " (favorite)")
			or (quote.held.name .. "  •  " .. money(quote.held.value))
		setEnabled(buttons.held, not quote.held.favorite)
	else
		buttons.held.Value.Text = "Hold an item first"
		setEnabled(buttons.held, false)
	end

	for _, b in pairs(buttons) do
		local icon = b:FindFirstChild("Icon")
		if icon then
			icon.Visible = icon.Image ~= ""
		end
	end
end

local function close()
	main.Visible = false
	openedAt = nil
end

local function open(stallPart)
	closeAllBridge:Fire("sell")
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 0 then
		mainScale.Scale = math.clamp(math.min(camera.ViewportSize.Y / 600, camera.ViewportSize.X / 700), 0.55, 1) * ((game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled) and 0.88 or 1)
	end
	openedAt = stallPart
	main.Visible = true
	refresh()
	local target = mainScale.Scale
	mainScale.Scale = target * 0.85
	TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
end

local function doSell(mode)
	if busy or not quote then
		return
	end
	busy = true
	local response
	if mode == "held" then
		local held = quote.held
		local uid = player:GetAttribute("HeldUid")
		if held and uid and not held.favorite then
			response = (held.kind == "egg" and sellEggRemote or sellMonsterRemote):InvokeServer(uid)
		end
	else
		response = sellBulkRemote:InvokeServer(mode)
		if response and response.needsGamepass and Config.SellAllGamepassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, Config.SellAllGamepassId)
		end
	end
	if response then
		flash(response.message or "Sold!", response.success and GOLD or RED)
	end
	refresh()
	busy = false
end

--------------------------------------------------------------------
-- Double confirmation before selling
--------------------------------------------------------------------
local OUTLINE_C = Color3.fromRGB(10, 15, 35)
local confirmDim = Instance.new("Frame")
confirmDim.Name = "Confirm"
confirmDim.Size = UDim2.fromScale(1, 1)
confirmDim.BackgroundColor3 = Color3.new(0, 0, 0)
confirmDim.BackgroundTransparency = 0.35
confirmDim.Visible = false
confirmDim.ZIndex = 20
confirmDim.Parent = main
Instance.new("UICorner", confirmDim).CornerRadius = UDim.new(0, 22)
local confirmBox = Instance.new("Frame")
confirmBox.Size = UDim2.fromOffset(420, 210)
confirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
confirmBox.Position = UDim2.fromScale(0.5, 0.5)
confirmBox.BackgroundColor3 = Color3.fromRGB(22, 42, 92)
confirmBox.ZIndex = 21
confirmBox.Parent = confirmDim
Instance.new("UICorner", confirmBox).CornerRadius = UDim.new(0, 18)
local boxStroke = Instance.new("UIStroke")
boxStroke.Color = OUTLINE_C
boxStroke.Thickness = 4
boxStroke.Parent = confirmBox
local confirmText = Instance.new("TextLabel")
confirmText.Size = UDim2.new(1, -30, 0, 110)
confirmText.Position = UDim2.fromOffset(15, 14)
confirmText.BackgroundTransparency = 1
confirmText.TextScaled = true
confirmText.TextWrapped = true
confirmText.Font = Enum.Font.LuckiestGuy
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.TextStrokeTransparency = 0
confirmText.TextStrokeColor3 = OUTLINE_C
confirmText.ZIndex = 22
confirmText.Parent = confirmBox
local textLimit = Instance.new("UITextSizeConstraint")
textLimit.MaxTextSize = 26
textLimit.Parent = confirmText
local function confirmButton(text, color, xAnchor, xOffset)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(160, 50)
	btn.AnchorPoint = Vector2.new(xAnchor, 1)
	btn.Position = UDim2.new(0.5, xOffset, 1, -14)
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextScaled = true
	btn.Font = Enum.Font.LuckiestGuy
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextStrokeTransparency = 0
	btn.TextStrokeColor3 = OUTLINE_C
	btn.ZIndex = 22
	btn.Parent = confirmBox
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
	local s = Instance.new("UIStroke")
	s.Color = OUTLINE_C
	s.Thickness = 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = btn
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = btn
	return btn
end
local yesButton = confirmButton("YES", Color3.fromRGB(60, 205, 95), 1, -8)
local noButton = confirmButton("NO", Color3.fromRGB(235, 70, 80), 0, 8)

local pendingMode, confirmStep = nil, 0
-- each step ignores YES for a moment, so a double-tap can't pass both steps
local CONFIRM_DELAY = 0.5
local confirmReadyAt = 0
local function placeButtons(swapped)
	-- step 2 swaps YES and NO, so tapping the same spot twice can't confirm
	yesButton.AnchorPoint = Vector2.new(swapped and 0 or 1, 1)
	yesButton.Position = UDim2.new(0.5, swapped and 8 or -8, 1, -14)
	noButton.AnchorPoint = Vector2.new(swapped and 1 or 0, 1)
	noButton.Position = UDim2.new(0.5, swapped and -8 or 8, 1, -14)
end

-- what the chosen button would sell, e.g. "12 eggs for $5.2K" (nil = nothing)
local function sellDescription(mode)
	if not quote then
		return nil
	end
	local function plural(n, word)
		return n .. " " .. word .. (n == 1 and "" or "s")
	end
	if mode == "held" then
		local held = quote.held
		if not held or held.favorite then
			return nil
		end
		return held.name .. " for " .. money(held.value)
	end
	local q = quote[mode]
	if not q or q.count <= 0 then
		return nil
	end
	local word = mode == "eggs" and "egg" or (mode == "monsters" and "monster" or "item")
	return plural(q.count, word) .. " for " .. money(q.value)
end

local function askSell(mode)
	if busy then
		return
	end
	local desc = sellDescription(mode)
	if not desc then
		return
	end
	pendingMode = mode
	confirmStep = 1
	confirmText.Text = "Sell " .. desc .. "?"
	placeButtons(false)
	confirmReadyAt = os.clock() + CONFIRM_DELAY
	confirmDim.Visible = true
end

yesButton.Activated:Connect(function()
	if os.clock() < confirmReadyAt then
		return -- too fast (double-tap)
	end
	if confirmStep ~= 1 then
		return
	end
	confirmDim.Visible = false
	confirmStep = 0
	local mode = pendingMode
	pendingMode = nil
	if mode then
		doSell(mode)
	end
end)
noButton.Activated:Connect(function()
	confirmDim.Visible = false
	confirmStep = 0
	pendingMode = nil
end)
main:GetPropertyChangedSignal("Visible"):Connect(function()
	if not main.Visible then
		confirmDim.Visible = false
		confirmStep = 0
		pendingMode = nil
	end
end)

for mode, b in pairs(buttons) do
	b.Activated:Connect(function()
		askSell(mode)
	end)
	local s = b:FindFirstChildOfClass("UIScale")
	if s then
		b.MouseEnter:Connect(function()
			TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1.04 }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1 }):Play()
		end)
	end
end

closeButton.Activated:Connect(close)
local closeIcon = closeButton:FindFirstChild("Icon")
if closeIcon and closeIcon.Image ~= "" then
	closeButton.Label.Visible = false
end

closeAllBridge.Event:Connect(function(except)
	if except ~= "sell" then
		close()
	end
end)

profileUpdated.OnClientEvent:Connect(function()
	if main.Visible and not busy then
		refresh()
	end
end)

-- close automatically when walking away from the stall
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

--------------------------------------------------------------------
-- Hook up the Seller's prompt (it moves onto the NPC once it spawns)
--------------------------------------------------------------------

local hooked = {}
local function hookPrompt(prompt)
	if hooked[prompt] or not prompt:IsA("ProximityPrompt") or prompt.Name ~= "SellPrompt" then
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
	local world = workspace:WaitForChild("MonsterRNGWorld")
	local stall = world:WaitForChild("Hub"):WaitForChild("SellStall", 30)
	if not stall then
		warn("Sell stall not found")
		return
	end
	for _, d in ipairs(stall:GetDescendants()) do
		hookPrompt(d)
	end
	stall.DescendantAdded:Connect(hookPrompt)
end)

main.Visible = false
