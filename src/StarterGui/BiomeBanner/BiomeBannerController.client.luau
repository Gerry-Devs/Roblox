local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

--------------------------------------------------------------------
-- Shows the biome name when the player walks into a new biome.
-- Names, colors and icons come from Config.Biomes (imageId = icon).
--------------------------------------------------------------------

local gui = script.Parent
local banner = gui:WaitForChild("Banner")
local bannerScale = banner:WaitForChild("UIScale")
local row = banner:WaitForChild("Row")
local icon = row:WaitForChild("Icon")
local subtitle = row:WaitForChild("TextBlock"):WaitForChild("Subtitle")
local title = row.TextBlock:WaitForChild("Title")

local SHOW_TIME = 3
local token

local function baseScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local v = camera.ViewportSize
	return math.clamp(math.min(v.X / 1000, v.Y / 650), 0.55, 1)
end

local function show(biome)
	local t = {}
	token = t
	title.Text = biome.name
	title.TextColor3 = Color3.fromRGB(biome.color[1], biome.color[2], biome.color[3])
	subtitle.Text = string.upper(biome.subtitle or "")
	icon.Image = biome.imageId or ""
	icon.Visible = icon.Image ~= ""

	local s = baseScale()
	banner.Visible = true
	banner.GroupTransparency = 1
	bannerScale.Scale = s * 0.7
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = s }):Play()
	TweenService:Create(banner, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()

	task.delay(SHOW_TIME, function()
		if token ~= t then
			return
		end
		local fade = TweenService:Create(banner, TweenInfo.new(0.5), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == t then
			banner.Visible = false
		end
	end)
end

local currentKey
local firstCheck = true
task.spawn(function()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local biome = Config.GetBiomeAt(root.Position.X, root.Position.Z)
			if biome and biome.key ~= currentKey then
				currentKey = biome.key
				-- don't pop up on join, only when walking into a new biome
				if not firstCheck then
					show(biome)
				end
			end
			firstCheck = false
		end
		task.wait(0.25)
	end
end)
