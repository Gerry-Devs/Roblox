--------------------------------------------------------------------
-- MonsterMesh: turns a big monster rig (hundreds of block / wedge
-- pieces) into a few meshes, ON EACH PLAYER'S SCREEN, with the exact
-- same shapes and colours (vertex colours). One mesh per moving joint
-- + material, so every animation still works the same.
--   MonsterMesh.Get(rigName) -> Model of MeshParts (rig scale) or nil
-- If meshes can't be made on this device, nil is returned and the
-- normal pieces are used instead.
--------------------------------------------------------------------
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterMesh = {}
local cache = {} -- rigName -> Model | false
local building = {}

-- the 8 corners of a block and 6 of a wedge, in the part's local space
local function blockFaces(h)
	local x, y, z = h.X, h.Y, h.Z
	local c = {
		Vector3.new(-x, -y, -z), Vector3.new(x, -y, -z), Vector3.new(x, y, -z), Vector3.new(-x, y, -z),
		Vector3.new(-x, -y, z), Vector3.new(x, -y, z), Vector3.new(x, y, z), Vector3.new(-x, y, z),
	}
	-- quads, counter-clockwise seen from outside
	return {
		{ c[1], c[4], c[3], c[2] }, -- -Z
		{ c[5], c[6], c[7], c[8] }, -- +Z
		{ c[1], c[5], c[8], c[4] }, -- -X
		{ c[2], c[3], c[7], c[6] }, -- +X
		{ c[4], c[8], c[7], c[3] }, -- +Y
		{ c[1], c[2], c[6], c[5] }, -- -Y
	}
end
local function wedgeFaces(h)
	local x, y, z = h.X, h.Y, h.Z
	-- Roblox wedge: full bottom and back (+Z), slope from front-bottom to back-top
	local a, b = Vector3.new(-x, -y, -z), Vector3.new(x, -y, -z)
	local c, d = Vector3.new(x, -y, z), Vector3.new(-x, -y, z)
	local e, f = Vector3.new(-x, y, z), Vector3.new(x, y, z)
	return {
		{ a, b, c, d }, -- bottom (-Y) reversed below
		{ d, c, f, e }, -- back (+Z)
		{ a, e, f, b }, -- slope
		{ a, d, e }, -- left (-X)
		{ b, f, c }, -- right (+X)
	}
end

local function addFace(em, verts, color)
	local ids = {}
	for i, v in ipairs(verts) do
		ids[i] = em:AddVertex(v)
	end
	local col = em:AddColor(color, 1)
	local function tri(i1, i2, i3)
		local f = em:AddTriangle(ids[i1], ids[i2], ids[i3])
		em:SetFaceColors(f, { col, col, col })
	end
	tri(1, 2, 3)
	if #verts == 4 then
		tri(1, 3, 4)
	end
end

local function buildRig(rigName)
	local rigs = ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("MonsterRigs")
	local rig = rigs:FindFirstChild(rigName)
	if not rig then
		return false
	end
	local out = Instance.new("Model")
	out.Name = rigName
	local buckets = {}
	for _, p in ipairs(rig:GetChildren()) do
		if p:IsA("BasePart") then
			local simple = #p:GetChildren() == 0 and (p:IsA("WedgePart") or (p:IsA("Part") and p.Shape == Enum.PartType.Block))
			if simple then
				local key = tostring(p:GetAttribute("G")) .. "|" .. p.Material.Name .. "|" .. p.Transparency .. "|" .. p.Reflectance
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], p)
			else
				p:Clone().Parent = out -- lights / special pieces stay as they are
			end
		end
	end
	for _, list in pairs(buckets) do
		-- centre of the bucket
		local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, p in ipairs(list) do
			local h = p.Size / 2
			for _, s in ipairs({ Vector3.new(-1, -1, -1), Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1) }) do
				local w = p.CFrame:PointToWorldSpace(h * s)
				minV = minV:Min(w)
				maxV = maxV:Max(w)
			end
		end
		local center = (minV + maxV) / 2
		local em = AssetService:CreateEditableMesh()
		if not em then
			error("NOBUDGET") -- the device isn't ready yet: try again later
		end
		for _, p in ipairs(list) do
			local faces = p:IsA("WedgePart") and wedgeFaces(p.Size / 2) or blockFaces(p.Size / 2)
			for i, face in ipairs(faces) do
				local verts = {}
				for j, v in ipairs(face) do
					verts[j] = p.CFrame:PointToWorldSpace(v) - center
				end
				if p:IsA("WedgePart") and i == 1 then
					-- bottom face points down
					verts = { verts[1], verts[4], verts[3], verts[2] }
				end
				addFace(em, verts, p.Color)
			end
		end
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
		mp.Name = "Piece"
		mp.CFrame = CFrame.new(center)
		mp.Color = Color3.new(1, 1, 1)
		mp.Material = list[1].Material
		mp.Transparency = list[1].Transparency
		mp.Reflectance = list[1].Reflectance
		mp.CastShadow = false
		mp.Anchored = true
		mp.CanCollide = false
		mp:SetAttribute("G", list[1]:GetAttribute("G"))
		mp:SetAttribute("VertexColored", true)
		mp.Parent = out
	end
	return out
end

-- returns the mesh version of a rig (builds it the first time; yields)
function MonsterMesh.Get(rigName)
	local c = cache[rigName]
	if c ~= nil then
		return c or nil
	end
	if building[rigName] then
		while building[rigName] do
			task.wait(0.1)
		end
		return cache[rigName] or nil
	end
	building[rigName] = true
	local ok, result = pcall(buildRig, rigName)
	building[rigName] = nil
	if not ok then
		if tostring(result):find("NOBUDGET", 1, true) then
			return nil -- not cached: the next call tries again
		end
		warn("[MonsterMesh] " .. rigName .. ": " .. tostring(result))
	end
	cache[rigName] = (ok and result) or false
	return cache[rigName] or nil
end

-- already built? (never yields)
function MonsterMesh.Peek(rigName)
	return cache[rigName] or nil
end

return MonsterMesh
