local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local remotes = monsterFolder:WaitForChild("Remotes")
local profileRemote = remotes:WaitForChild("GetProfile")
local buyDiceRemote = remotes:WaitForChild("BuyDice")
local equipDiceRemote = remotes:WaitForChild("EquipDice")
local profileUpdated = remotes:WaitForChild("ProfileUpdated")
local closeAllBridge = monsterFolder:WaitForChild("ClientBridge"):WaitForChild("CloseAll")

--------------------------------------------------------------------
-- Dice Shop, opened by talking to Scripter at the Dice Shop stall.
-- Dice list / prices / luck live in Config.Dice. Put your own dice
-- pictures in Main.List.Dice_<key>.Icon.Image (or Config.Dice imageId).
--------------------------------------------------------------------

local gui = script.Parent
local main = gui:WaitForChild("Main")
local mainScale = main:WaitForChild("UIScale")
local list = main:WaitForChild("List")
local closeButton = main:WaitForChild("CloseButton")
local message = main:WaitForChild("Message")

local GREEN = Color3.fromRGB(60, 205, 95)
local BLUE = Color3.fromRGB(60, 160, 255)
local GRAY = Color3.fromRGB(110, 120, 145)
local GOLD = Color3.fromRGB(255, 205, 93)
local RED = Color3.fromRGB(255, 110, 110)
local OPEN_DISTANCE = 22

local profile = profileRemote:InvokeServer()
local openedAt
local busy = false
local flashToken

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

local function refresh()
	local owned = (profile and profile.ownedDice) or { common = true }
	local equipped = (profile and profile.equippedDice) or "common"
	for _, dice in ipairs(Config.Dice) do
		local row = list:FindFirstChild("Dice_" .. dice.key)
		if row then
			row.Luck.Text = dice.luck > 0 and ("+" .. dice.luck .. "% Luck") or "No bonus"
			local btn = row.ActionButton
			local icon = row:FindFirstChild("Icon")
			if icon then
				if icon.Image == "" and dice.imageId ~= "" then
					icon.Image = dice.imageId
				end
				icon.Visible = icon.Image ~= ""
				row.Die.Visible = icon.Image == ""
			end
			if equipped == dice.key then
				btn.BackgroundColor3 = GRAY
				btn.Label.Text = "EQUIPPED"
			elseif owned[dice.key] then
				btn.BackgroundColor3 = BLUE
				btn.Label.Text = "EQUIP"
			else
				btn.BackgroundColor3 = GREEN
				btn.Label.Text = "BUY  $" .. Config.FormatNumber(dice.cost)
				btn.Label.TextColor3 = (profile and profile.cash or 0) >= dice.cost and Color3.new(1, 1, 1) or RED
			end
			if owned[dice.key] then
				btn.Label.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end
end

for _, dice in ipairs(Config.Dice) do
	local row = list:FindFirstChild("Dice_" .. dice.key)
	if row then
		local btn = row.ActionButton
		local s = btn:FindFirstChildOfClass("UIScale")
		if s then
			btn.MouseEnter:Connect(function()
				TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1 }):Play()
			end)
		end
		btn.Activated:Connect(function()
			if busy then
				return
			end
			local owned = (profile and profile.ownedDice) or {}
			if profile and profile.equippedDice == dice.key then
				return
			end
			busy = true
			local remote = owned[dice.key] and equipDiceRemote or buyDiceRemote
			local ok, response = pcall(function()
				return remote:InvokeServer(dice.key)
			end)
			if ok and response then
				if response.profile then
					profile = response.profile
				end
				flash(response.message or "Done.", response.success and GOLD or RED)
			end
			refresh()
			busy = false
		end)
	end
end

local function close()
	main.Visible = false
	openedAt = nil
end

local function open(anchorPart)
	closeAllBridge:Fire("dice")
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 0 then
		mainScale.Scale = math.clamp(math.min(camera.ViewportSize.Y / 620, camera.ViewportSize.X / 720), 0.55, 1) * ((game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled) and 0.88 or 1)
	end
	openedAt = anchorPart
	main.Visible = true
	refresh()
	local target = mainScale.Scale
	mainScale.Scale = target * 0.85
	TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = target }):Play()
end

closeButton.Activated:Connect(close)
if closeButton.Icon.Image ~= "" then
	closeButton.Label.Visible = false
end
closeAllBridge.Event:Connect(function(except)
	if except ~= "dice" then
		close()
	end
end)

profileUpdated.OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	if main.Visible and not busy then
		refresh()
	end
end)

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

-- hook Scripter's prompt (it moves from the counter onto the NPC)
local hooked = {}
local function hookPrompt(prompt)
	if hooked[prompt] or not prompt:IsA("ProximityPrompt") or prompt.Name ~= "DicePrompt" then
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
	local stall = workspace:WaitForChild("MonsterRNGWorld"):WaitForChild("Hub"):WaitForChild("DiceStall", 30)
	if not stall then
		warn("Dice stall not found")
		return
	end
	for _, d in ipairs(stall:GetDescendants()) do
		hookPrompt(d)
	end
	stall.DescendantAdded:Connect(hookPrompt)
end)

main.Visible = false
