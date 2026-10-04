--------------------------------------------------------------------
-- LootModel: the 3D loot that drops from enemies (built from parts,
-- like the eggs). Matches the icons:
--   Rift Shard: grey rocks around a glowing blue core, a white star in
--     the middle and a few small rocks floating around it
--   Potions: a round glass flask with colored liquid, a blue rim, a
--     cork, a ribbon around the neck and a tag with the potion's sign
-- LootModel.Build(kind, key) -> Model (anchored, no collisions; the
-- PrimaryPart "Root" is the center: move the model with PivotTo)
--------------------------------------------------------------------
local LootModel = {}

local V, CF = Vector3.new, CFrame.new
local R = math.rad
local C3 = Color3.fromRGB

-- each potion (copied from the potion icons): liquid / ribbon color, the
-- tag's shape, its fill + gold rim colors and the sign printed on it
local POTIONS = {
	cash = { liquid = C3(255, 205, 25), ribbon = C3(255, 215, 40), shape = "hex", tag = C3(25, 130, 55), rim = C3(255, 200, 40), sign = "$", signColor = C3(255, 215, 60) },
	level = { liquid = C3(145, 45, 225), ribbon = C3(160, 70, 235), shape = "hex", tag = C3(95, 45, 170), rim = C3(255, 190, 50), sign = "\u{2B06}", signColor = C3(225, 185, 255) },
	revive = { liquid = C3(85, 205, 30), ribbon = C3(95, 210, 40), shape = "shield", tag = C3(25, 95, 35), rim = C3(255, 190, 50), sign = "\u{1F47C}", signColor = C3(255, 255, 255) },
	health = { liquid = C3(225, 25, 30), ribbon = C3(230, 35, 40), shape = "shield", tag = C3(200, 30, 35), rim = C3(255, 190, 50), sign = "\u{271A}", signColor = C3(255, 225, 230) },
	damage = { liquid = C3(200, 20, 25), ribbon = C3(205, 25, 30), shape = "star", tag = C3(140, 15, 20), rim = C3(215, 40, 45), sign = "\u{2694}", signColor = C3(255, 205, 205) },
	luck = { liquid = C3(75, 200, 25), ribbon = C3(85, 205, 35), shape = "clover", tag = C3(70, 180, 40), rim = C3(255, 185, 40), sign = "\u{1F340}", signColor = C3(255, 255, 255) },
}
LootModel.Potions = POTIONS

local function part(model, name, shape, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
-- a squashed / stretched sphere (Ball parts are always round)
local function oval(model, name, size, cf, color, material, transparency)
	local p = part(model, name, Enum.PartType.Block, size, cf, color, material, transparency)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
-- a cylinder standing up (Roblox cylinders lie along X)
local function disc(model, name, height, diameter, cf, color, material, transparency)
	return part(model, name, Enum.PartType.Cylinder, V(height, diameter, diameter), cf * CFrame.Angles(0, 0, R(90)), color, material, transparency)
end
-- a flat disc facing forward (along the frame's look direction)
local function coin(model, name, thick, diameter, cf, color, material)
	return part(model, name, Enum.PartType.Cylinder, V(thick, diameter, diameter), cf * CFrame.Angles(0, R(90), 0), color, material)
end

local function newModel(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = part(model, "Root", Enum.PartType.Block, V(0.2, 0.2, 0.2), CF(), Color3.new(1, 1, 1), nil, 1)
	model.PrimaryPart = root
	return model, root
end

local function sparkles(root, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate or 4
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.22), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(0.6, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Parent = root
end
local function glow(root, color, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 7
	l.Brightness = 1.6
	l.Parent = root
end

--------------------------------------------------------------------
-- Rift Shard (icon: a ball of light grey cartoon rocks with darker
-- spots, glowing blue between them, a white star at the upper left and
-- small rock chips around it)
--------------------------------------------------------------------
local function buildShard()
	local model, root = newModel("RiftShardLoot")
	part(model, "Core", Enum.PartType.Ball, V(1.7, 1.7, 1.7), CF(), C3(45, 70, 255), Enum.Material.Neon)
	part(model, "CoreGlow", Enum.PartType.Ball, V(2.05, 2.05, 2.05), CF(), C3(90, 175, 255), Enum.Material.Neon, 0.82)
	local rock, rockDark, spot = C3(172, 176, 192), C3(140, 144, 162), C3(112, 116, 134)
	-- big rocks all around (fixed layout: every shard looks the same);
	-- direction (yaw, pitch), size, tilt
	local ROCKS = {
		{ 0, 62, 1.0, 20 }, { 120, 58, 0.92, -15 }, { 240, 60, 0.95, 30 },
		{ 30, 18, 1.05, -25 }, { 100, 22, 0.95, 10 }, { 170, 15, 1.0, 35 }, { 245, 20, 0.98, -20 }, { 315, 15, 1.02, 15 },
		{ 65, -28, 1.0, -30 }, { 140, -22, 0.95, 25 }, { 210, -30, 1.0, -10 }, { 285, -25, 0.98, 40 }, { 355, -28, 0.95, 5 },
		{ 60, -68, 0.9, 25 }, { 200, -65, 0.92, -10 },
	}
	for i, r in ipairs(ROCKS) do
		local dir = CFrame.fromEulerAnglesYXZ(R(-r[2]), R(r[1]), 0).LookVector
		local s = r[3]
		local cf = CFrame.lookAt(dir * 0.88, dir * 3) * CFrame.Angles(0, 0, R(r[4]))
		part(model, "Rock", Enum.PartType.Block, V(s, s * 0.82, s * 0.5), cf, i % 4 == 0 and rockDark or rock, Enum.Material.SmoothPlastic)
		-- the darker spot on the rock
		if i % 2 == 1 then
			oval(model, "Spot", V(s * 0.28, s * 0.22, 0.06), cf * CF(s * 0.12, s * 0.1, -s * 0.25), spot)
		end
	end
	-- small rock chips floating around it
	for i, r in ipairs({ { 25, 1.75, 0.36, 0.7 }, { 150, 1.8, 0.3, -0.6 }, { 205, 1.7, 0.26, 0.9 }, { 300, 1.85, 0.34, -0.75 }, { 95, 1.65, 0.22, -0.95 } }) do
		local ang = R(r[1])
		part(model, "Chip", Enum.PartType.Block, V(r[3], r[3] * 0.8, r[3] * 0.6), CF(math.cos(ang) * r[2], r[4], math.sin(ang) * r[2]) * CFrame.Angles(R(r[1]), R(30 + i * 20), R(15)), rock)
	end
	-- the white star, upper left on the front
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(1.3, 1.3)
	bb.StudsOffset = V(-0.35, 0.3, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Parent = root
	local star = Instance.new("TextLabel")
	star.Size = UDim2.fromScale(1, 1)
	star.BackgroundTransparency = 1
	star.Text = "\u{2726}"
	star.TextScaled = true
	star.TextColor3 = Color3.new(1, 1, 1)
	star.Font = Enum.Font.GothamBlack
	star.Parent = bb
	glow(root, C3(80, 130, 255), 8)
	sparkles(root, C3(150, 200, 255), 5)
	return model
end

--------------------------------------------------------------------
-- Potion (icons: a round squat glass flask almost full of liquid with
-- bubbles and a big shine, a flat glass foot, a thick light blue rim,
-- a tilted brown cork with holes, a ribbon tied around the neck with
-- two tails, and a gold ring holding the potion's tag on the right)
--------------------------------------------------------------------
-- the tag: its shape in gold (rim), the same shape in the tag color on
-- top, and the sign printed on the front. cf faces outward.
local function tagShape(model, name, shape, scale, cf, color)
	local thick = 0.07
	if shape == "hex" then
		for i = 0, 2 do
			part(model, name, Enum.PartType.Block, V(0.36 * scale, 0.62 * scale, thick), cf * CFrame.Angles(0, 0, R(i * 60)), color, Enum.Material.SmoothPlastic)
		end
	elseif shape == "shield" then
		part(model, name, Enum.PartType.Block, V(0.6 * scale, 0.4 * scale, thick), cf * CF(0, 0.1 * scale, 0), color)
		part(model, name, Enum.PartType.Block, V(0.42 * scale, 0.42 * scale, thick), cf * CF(0, -0.08 * scale, 0) * CFrame.Angles(0, 0, R(45)), color)
	elseif shape == "star" then
		for i = 0, 2 do
			part(model, name, Enum.PartType.Block, V(0.48 * scale, 0.48 * scale, thick), cf * CFrame.Angles(0, 0, R(i * 30)), color)
		end
	else -- clover: four round leaves
		for _, o in ipairs({ { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
			coin(model, name, thick, 0.36 * scale, cf * CF(o[1] * 0.14 * scale, o[2] * 0.14 * scale, 0), color)
		end
		coin(model, name, thick, 0.3 * scale, cf, color)
	end
end
local function buildPotion(key)
	local look = POTIONS[key] or POTIONS.luck
	local model, root = newModel("PotionLoot_" .. tostring(key))
	local glass = C3(185, 228, 255)
	local rimBlue = C3(125, 190, 248)
	local white = Color3.new(1, 1, 1)
	-- squat glass body, nearly full of liquid (lighter swirl near the top)
	oval(model, "Glass", V(1.9, 1.72, 1.9), CF(0, -0.15, 0), glass, Enum.Material.Glass, 0.7)
	oval(model, "Liquid", V(1.72, 1.55, 1.72), CF(0, -0.17, 0), look.liquid, Enum.Material.SmoothPlastic, 0.02)
	oval(model, "Swirl", V(1.3, 0.22, 1.3), CF(0, 0.38, 0), look.liquid:Lerp(white, 0.35), Enum.Material.SmoothPlastic, 0.1)
	-- the big shine (upper left) and bubbles
	oval(model, "Shine", V(0.42, 0.62, 0.12), CF(-0.5, 0.2, -0.72) * CFrame.Angles(0, R(35), R(-25)), white, Enum.Material.Neon, 0.1)
	for _, b in ipairs({ { 0.28, -0.5, 0.2 }, { -0.25, -0.62, 0.16 }, { 0.45, -0.05, 0.13 }, { -0.05, -0.2, 0.12 }, { 0.15, -0.8, 0.1 } }) do
		local dir = V(b[1], b[2], -0.8).Unit
		part(model, "Bubble", Enum.PartType.Ball, V(b[3], b[3], b[3]), CF(dir * 0.83 + V(0, -0.15, 0)), look.liquid:Lerp(white, 0.55), Enum.Material.Neon, 0.05)
	end
	-- flat glass foot
	disc(model, "Foot", 0.18, 1.2, CF(0, -1.0, 0), rimBlue, Enum.Material.Glass, 0.2)
	-- short neck, ribbon tied around it, thick rim, tilted cork with holes
	disc(model, "Neck", 0.42, 0.66, CF(0, 0.82, 0), glass, Enum.Material.Glass, 0.4)
	disc(model, "Ribbon", 0.18, 0.76, CF(0, 0.76, 0), look.ribbon)
	disc(model, "Rim", 0.26, 1.0, CF(0, 1.1, 0), rimBlue)
	disc(model, "RimInner", 0.27, 0.66, CF(0, 1.1, 0), C3(90, 150, 220))
	local corkCf = CF(0.05, 1.42, 0) * CFrame.Angles(0, 0, R(-10))
	disc(model, "Cork", 0.56, 0.62, corkCf, C3(190, 110, 50), Enum.Material.SmoothPlastic)
	for _, h in ipairs({ { -0.15, 0.08, -0.29 }, { 0.12, -0.08, -0.29 }, { 0.2, 0.15, -0.22 } }) do
		part(model, "CorkHole", Enum.PartType.Ball, V(0.09, 0.09, 0.09), corkCf * CF(h[1], h[2], h[3]), C3(105, 55, 25))
	end
	-- two ribbon tails hanging down the front
	part(model, "RibbonTail", Enum.PartType.Block, V(0.16, 0.5, 0.05), CF(0.05, 0.47, -0.62) * CFrame.Angles(R(-25), 0, R(-14)), look.ribbon)
	part(model, "RibbonTail", Enum.PartType.Block, V(0.16, 0.44, 0.05), CF(0.25, 0.5, -0.58) * CFrame.Angles(R(-25), 0, R(16)), look.ribbon:Lerp(Color3.new(0, 0, 0), 0.12))
	-- gold ring from the ribbon, holding the tag on the right
	local gold = C3(255, 195, 45)
	coin(model, "Ring", 0.07, 0.24, CF(0.45, 0.72, -0.35) * CFrame.Angles(0, R(-45), 0), gold, Enum.Material.Metal)
	local tagCf = CF(0.78, 0.22, -0.72) * CFrame.Angles(0, R(-40), R(-12))
	tagShape(model, "TagRim", look.shape, 1.25, tagCf, look.rim)
	tagShape(model, "Tag", look.shape, 1.0, tagCf * CF(0, 0, -0.03), look.tag)
	-- the sign (on a see-through plate in front of the tag)
	local plate = part(model, "Sign", Enum.PartType.Block, V(0.48, 0.48, 0.02), tagCf * CF(0, 0, -0.08), white, nil, 1)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 120
	sg.Parent = plate
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.Text = look.sign
	sign.TextScaled = true
	sign.TextColor3 = look.signColor
	sign.Font = Enum.Font.GothamBlack
	sign.Parent = sg
	glow(root, look.liquid, 6)
	sparkles(root, look.liquid:Lerp(white, 0.4), 3)
	return model
end

function LootModel.Build(kind, key)
	if kind == "shards" then
		return buildShard()
	end
	return buildPotion(key)
end

return LootModel
