local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------
-- BiomeLoader: on LOW / MID graphics a biome only shows when you are
-- in it or close to it (the one you're in + the edge of the next one).
-- Far biomes are hidden on this screen, so there is much less to draw.
-- HIGH graphics shows everything, like before.
-- (Biomes also stream in/out: every new copy and every part that
-- arrives later is handled too.)
--------------------------------------------------------------------
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))


local shown = setmetatable({}, { __mode = "k" }) -- biome model -> true / false
local hooked = setmetatable({}, { __mode = "k" })

local function graphics()
	return player:GetAttribute("Graphics") or "High"
end

local function applyTo(d, visible, low)
	if d:IsA("BasePart") then
		local hideAnyway = low and d:FindFirstAncestor("Props") ~= nil -- low tiers also hide small decorations
		d.LocalTransparencyModifier = (visible and not hideAnyway) and 0 or 1
	elseif d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Light") or d:IsA("Beam") then
		if visible then
			if d:GetAttribute("LoaderOff") then
				d:SetAttribute("LoaderOff", nil)
				d.Enabled = true
			end
		elseif d.Enabled then
			d:SetAttribute("LoaderOff", true)
			d.Enabled = false
		end
	elseif d:IsA("Decal") or d:IsA("Texture") then
		d.LocalTransparencyModifier = visible and 0 or 1
	end
end

local function hook(model)
	if hooked[model] then
		return
	end
	hooked[model] = true
	-- parts that stream in later follow the biome's current state
	model.DescendantAdded:Connect(function(d)
		local v = shown[model]
		if v ~= nil then
			applyTo(d, v, not Config.GraphicsTier(graphics()).props)
		end
	end)
end

local function setVisible(model, visible)
	hook(model)
	if shown[model] == visible then
		return
	end
	shown[model] = visible
	local low = not Config.GraphicsTier(graphics()).props
	local count = 0
	for _, d in ipairs(model:GetDescendants()) do
		if shown[model] ~= visible then
			return -- changed again while we were working: the newer call wins
		end
		applyTo(d, visible, low)
		count += 1
		if count % 1500 == 0 then
			task.wait() -- spread big biomes over a few frames
		end
	end
end

local function update()
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	if not world then
		return
	end
	local cam = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local z = (root and root.Position.Z) or (cam and cam.CFrame.Position.Z) or 0
	local NEAR = Config.GraphicsTier(graphics()).biomeNear
	local all = NEAR == nil or player:GetAttribute("InPvp")
	NEAR = NEAR or 0
	for _, b in ipairs(Config.Biomes) do
		local model = world:FindFirstChild("Biome_" .. b.key)
		if model then
			local z0, z1 = b.center.Y - b.size.Y / 2 - NEAR, b.center.Y + b.size.Y / 2 + NEAR
			local near = z >= z0 and z <= z1
			task.spawn(setVisible, model, all or near)
		end
	end
end

player:GetAttributeChangedSignal("Graphics"):Connect(function()
	-- quality changed: redo every biome
	for m in pairs(shown) do
		shown[m] = nil
	end
	update()
end)

while true do
	local ok, err = pcall(update)
	if not ok then
		warn("[BiomeLoader] " .. tostring(err))
	end
	task.wait(0.5)
end
