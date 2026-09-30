local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

--------------------------------------------------------------------
-- Biome mood: a gentle color tint for each biome, faded in when you
-- walk in (only on your screen). Edit the values below to taste.
--------------------------------------------------------------------

local MOODS = {
	home = { tint = Color3.fromRGB(255, 255, 255), brightness = 0, contrast = 0, saturation = 0 },
	forest = { tint = Color3.fromRGB(238, 255, 238), brightness = 0, contrast = 0.02, saturation = 0.08 },
	desert = { tint = Color3.fromRGB(255, 242, 220), brightness = 0.03, contrast = 0.03, saturation = 0.05 },
	volcanic = { tint = Color3.fromRGB(255, 218, 200), brightness = -0.02, contrast = 0.08, saturation = 0.1 },
	tundra = { tint = Color3.fromRGB(228, 242, 255), brightness = 0.04, contrast = 0, saturation = -0.12 },
	candy = { tint = Color3.fromRGB(255, 232, 246), brightness = 0.02, contrast = 0, saturation = 0.15 },
	atlantis = { tint = Color3.fromRGB(205, 232, 255), brightness = -0.02, contrast = 0.03, saturation = 0.05 },
}

local cc = Lighting:FindFirstChild("BiomeMood")
if not cc then
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BiomeMood"
	cc.Parent = Lighting
end

local current
while true do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local biome = Config.GetBiomeAt(root.Position.X, root.Position.Z)
		local key = biome and biome.key or "home"
		if key ~= current then
			current = key
			local m = MOODS[key] or MOODS.home
			TweenService:Create(cc, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
				TintColor = m.tint,
				Brightness = m.brightness,
				Contrast = m.contrast,
				Saturation = m.saturation,
			}):Play()
		end
	end
	task.wait(0.5)
end
