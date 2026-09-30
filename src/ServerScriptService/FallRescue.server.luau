-- Fall rescue: if a player gets off the map (jumped off a mountain,
-- slipped past a wall, fell under the ground) they are put back at the
-- FRONT of the area they were in (e.g. off the forest mountains -> the
-- entrance of the forest). Works together with the invisible world walls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

local VOID_Y = -25 -- the ground is at about y = 1
local MARGIN = 6 -- how far past the edge counts as "off the map"

local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, b in ipairs(Config.Biomes) do
	minX = math.min(minX, b.center.X - b.size.X / 2)
	maxX = math.max(maxX, b.center.X + b.size.X / 2)
	minZ = math.min(minZ, b.center.Y - b.size.Y / 2)
	maxZ = math.max(maxZ, b.center.Y + b.size.Y / 2)
end

local function biomeAt(z)
	z = math.clamp(z, minZ + 1, maxZ - 1)
	for _, b in ipairs(Config.Biomes) do
		if math.abs(z - b.center.Y) <= b.size.Y / 2 then
			return b
		end
	end
	return Config.Biomes[1]
end

local function safeSpot(b, character)
	if b.key == "home" then
		local spawn = workspace:FindFirstChild("MonsterRNGWorld") and workspace.MonsterRNGWorld:FindFirstChild("MonsterRNGSpawn")
		if spawn then
			return spawn.Position + Vector3.new(0, 4, 0)
		end
	end
	-- the front (entrance) of the area: the side that faces the hub
	local x, z = b.center.X, b.center.Y + b.size.Y / 2 - 25
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { character }
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	local bounds = world and world:FindFirstChild("WorldBounds")
	if bounds then
		table.insert(ignore, bounds)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
	return Vector3.new(x, (hit and hit.Position.Y or 1) + 4, z)
end

local function offMap(p)
	return p.Y < VOID_Y or p.X < minX - MARGIN or p.X > maxX + MARGIN or p.Z < minZ - MARGIN or p.Z > maxZ + MARGIN
end

while true do
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and not player:GetAttribute("InPvp") and offMap(root.Position) then
			local target = safeSpot(biomeAt(root.Position.Z), character)
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(CFrame.new(target)) -- facing into the area
		end
	end
	task.wait(0.25)
end
