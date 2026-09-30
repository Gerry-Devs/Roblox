local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- RigSkinner: the big monsters (wolf, phoenix, void dragon, wraith)
-- arrive from the server as a skeleton only; this adds their pieces on
-- THIS screen, in the quality of the Graphics setting:
--   High = full detail (the original models)
--   Mid  = same look, pieces of the same colour joined together
--   Low  = light version (fewer pieces, simpler colours)
--------------------------------------------------------------------
local player = Players.LocalPlayer
local MonsterModel = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("MonsterModel"))

local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))
local function tier()
	return Config.GraphicsTier(player:GetAttribute("Graphics"))
end
-- Big monsters become a few meshes on this screen (same shapes, colours
-- and animation, far fewer pieces). Built once per monster type.
local MonsterMesh = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("MonsterMesh"))
local meshReady = {}
-- (runtime mesh building is off: it hitched when it swapped in and most
-- devices refuse it. Imported meshes will replace it.)
player:SetAttribute("MeshesReady", true) -- the loading screen waits for this
local function wantedSet(root)
	local name = root and root:GetAttribute("RigName")
	if name and meshReady[name] then
		return "MonsterMesh"
	end
	-- imported Blender meshes (a few pieces instead of ~1500): always use them when this monster has them
	local imported = ReplicatedStorage.MonsterRNG:FindFirstChild("MonsterMeshRigs")
	if name and imported and imported:FindFirstChild(name) then
		return "MonsterMeshRigs"
	end
	return tier().rigs or "MonsterRigs"
end

local tracked = {} -- root -> true

local function ready(root)
	local want = root:GetAttribute("PivotCount") or 1
	local n = 0
	for _, c in ipairs(root:GetChildren()) do
		if c.Name:sub(1, 6) == "Pivot_" then
			n += 1
		end
	end
	return n >= want
end

local function fadeOut(root)
	for _, c in ipairs(root:GetChildren()) do
		if c:GetAttribute("Skin") and c:IsA("BasePart") then
			TweenService:Create(c, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end
end

-- LOW graphics: monsters far from you are not drawn at all
local function setCulled(root, culled)
	local model = root.Parent
	if not model or (model:GetAttribute("LowCulled") == true) == culled then
		return
	end
	model:SetAttribute("LowCulled", culled or nil)
	if culled then
		for _, c in ipairs(root:GetChildren()) do
			if c:GetAttribute("Skin") then
				c:Destroy() -- big monsters: drop their pieces
			end
		end
		root:SetAttribute("SkinSet", nil)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = culled and 1 or 0
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			if culled and d.Enabled then
				d:SetAttribute("CullOff", true)
				d.Enabled = false
			elseif not culled and d:GetAttribute("CullOff") then
				d:SetAttribute("CullOff", nil)
				d.Enabled = true
			end
		elseif d:IsA("BillboardGui") then
			if culled and d.Enabled then
				d:SetAttribute("CullOff", true)
				d.Enabled = false
			elseif not culled and d:GetAttribute("CullOff") then
				d:SetAttribute("CullOff", nil)
				d.Enabled = true
			end
		end
	end
end

local didWork = false
local function skin(root)
	if not root.Parent then
		return
	end
	local cam = workspace.CurrentCamera
	local cullAt = tier().monsterCull
	local culled = false -- monsters always stay loaded (no pop-in / teleport lag)
	setCulled(root, culled)
	if culled or not root:GetAttribute("RigName") or not ready(root) then
		return
	end
	local set = wantedSet(root)
	if root:GetAttribute("SkinSet") ~= set then
		didWork = true
		-- the lighter pieces may not be ready yet: full detail meanwhile
		if not MonsterModel.Skin(root, set) and root:GetAttribute("SkinSet") == nil then
			MonsterModel.Skin(root, "MonsterRigs")
		end
		local model = root.Parent
		if model and model:GetAttribute("FadeOut") then
			fadeOut(root)
		end
	end
	if not tracked[root] then
		tracked[root] = true
		local model = root.Parent
		if model then
			model:GetAttributeChangedSignal("FadeOut"):Connect(function()
				if model:GetAttribute("FadeOut") then
					fadeOut(root)
				end
			end)
		end
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(game) then
				tracked[root] = nil
			end
		end)
	end
end

local function scanFolder(folder, rootName)
	for _, m in ipairs(folder:GetChildren()) do
		local root = m:FindFirstChild(rootName)
		if root and root:GetAttribute("RigId") then
			didWork = false
			local ok, err = pcall(skin, root)
			if not ok then
				warn("[RigSkinner] " .. tostring(err))
			end
			if didWork then
				task.wait() -- one monster per frame: no freeze when many arrive at once
			end
		end
	end
end

local function scanAll()
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	if world then
		for _, base in ipairs(world:GetChildren()) do
			local pets = base:FindFirstChild("Pets")
			if pets then
				scanFolder(pets, "MonsterBody")
			end
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		scanFolder(enemies, "Root")
	end
	local arenas = workspace:FindFirstChild("PvpArenas")
	if arenas then
		for _, arena in ipairs(arenas:GetChildren()) do
			local fighters = arena:FindFirstChild("Fighters")
			if fighters then
				scanFolder(fighters, "MonsterBody")
			end
		end
	end
end

-- graphics changed: swap every monster to the new quality
player:GetAttributeChangedSignal("Graphics"):Connect(function()
	task.spawn(function()
		for root in pairs(tracked) do
			if root.Parent then
				pcall(skin, root)
				task.wait()
			end
		end
	end)
end)

while true do
	local ok, err = pcall(scanAll)
	if not ok then
		warn("[RigSkinner] " .. tostring(err))
	end
	task.wait(0.4)
end
