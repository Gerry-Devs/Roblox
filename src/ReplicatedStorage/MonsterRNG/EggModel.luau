-- EggModel: cartoony, studded eggs with a different design per rarity.
-- The pieces are welded to an invisible "root" part, so anything that moves
-- the root (bobbing, hatch shake, your hands) moves the whole egg.
local EggModel = {}

local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
-- width of each layer from bottom to top (1 = widest): a round egg shape
local LAYERS = { 0.55, 0.78, 0.92, 1.0, 1.0, 0.97, 0.9, 0.78, 0.6, 0.35 }
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local V, CF = Vector3.new, CFrame.new

local function piece(root, name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Transparency = transparency or 0
	for _, f in ipairs(STUD_FACES) do
		p[f] = Enum.SurfaceType.Studs
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = root
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	return p
end

--------------------------------------------------------------------
-- designs (match the egg icons: blocky layers covered in square studs,
-- plus each rarity's own details). ctx.side = a patch on one side of a
-- layer, ctx.part = a free piece placed relative to the egg's center,
-- ctx.studs = the square studs all over
--------------------------------------------------------------------
local DESIGNS = {}
local function C3(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- each egg's own body color (like its icon)
local EGG_COLORS = {
	Common = C3(226, 230, 238),
	Uncommon = C3(60, 215, 140),
	Rare = C3(55, 145, 240),
	Epic = C3(140, 75, 230),
	Legendary = C3(248, 198, 45),
	Mythic = C3(225, 60, 205),
	Secret = C3(48, 42, 112),
	Celestial = C3(28, 45, 150),
	Divine = C3(238, 240, 247),
	Supreme = C3(72, 26, 92),
}

-- Common: white egg, square studs + two bigger blocks
DESIGNS.Common = function(ctx)
	ctx.studs(ctx.base:Lerp(WHITE, 0.4))
	ctx.side(4, 0, -0.3, V(ctx.width * 0.26, ctx.width * 0.24, 0.35), ctx.base:Lerp(WHITE, 0.6))
	ctx.side(6, 0, 0.35, V(ctx.width * 0.2, ctx.width * 0.2, 0.35), ctx.base:Lerp(WHITE, 0.6))
end

-- Uncommon: mint green, lime belt with a square buckle
DESIGNS.Uncommon = function(ctx)
	local lime = C3(130, 225, 30)
	ctx.studs(ctx.base:Lerp(WHITE, 0.25))
	ctx.ring(4, 0.45, lime)
	ctx.side(4, 0, 0, V(ctx.width * 0.2, ctx.width * 0.18, 0.4), lime:Lerp(WHITE, 0.2))
end

-- Rare: blue, a pale band around the middle
DESIGNS.Rare = function(ctx)
	ctx.studs(ctx.base:Lerp(WHITE, 0.3))
	ctx.ring(4, 0.55, C3(210, 230, 255))
end

-- Epic: purple, a gold cross emblem + gold belt
DESIGNS.Epic = function(ctx)
	local gold = C3(255, 205, 40)
	ctx.studs(ctx.base:Lerp(WHITE, 0.25))
	ctx.ring(4, 0.45, gold)
	ctx.side(4, 0, 0, V(ctx.width * 0.18, ctx.width * 0.16, 0.4), gold:Lerp(WHITE, 0.15))
	local w = ctx.width
	ctx.side(7, 0, 0, V(w * 0.3, w * 0.1, 0.35), gold, Enum.Material.Neon)
	ctx.side(7, 0, 0, V(w * 0.1, w * 0.3, 0.36), gold, Enum.Material.Neon)
	ctx.sparkles(C3(220, 170, 255))
end

-- Legendary: gold, 3-prong crown with red tips, teal gem on the belt
DESIGNS.Legendary = function(ctx)
	local gold = ctx.base:Lerp(C3(255, 170, 20), 0.3)
	ctx.studs(ctx.base:Lerp(WHITE, 0.3))
	ctx.ring(4, 0.4, gold)
	ctx.side(4, 0, 0, V(ctx.width * 0.22, ctx.width * 0.22, 0.4), C3(40, 210, 190), Enum.Material.Neon)
	local top = ctx.layerTop(#LAYERS)
	for i, x in ipairs({ -0.28, 0, 0.28 }) do
		local hgt = i == 2 and 1.3 or 1.0
		ctx.part("Crown", V(0.45, hgt, 0.45), CF(x * ctx.width, top + hgt / 2 - 0.2, 0) * CFrame.Angles(0, 0, math.rad(-x * 40)), gold)
		ctx.part("CrownGem", V(0.4, 0.4, 0.4), CF(x * ctx.width * 1.15, top + hgt - 0.05, 0), C3(235, 45, 80))
	end
	ctx.sparkles(C3(255, 220, 120))
end

-- Mythic: magenta, two dark segmented horns, yellow pins
DESIGNS.Mythic = function(ctx)
	local horn = C3(55, 25, 90)
	ctx.studs(ctx.base:Lerp(WHITE, 0.25))
	local base = ctx.layerTop(#LAYERS - 2)
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			ctx.part("Horn", V(0.5 - k * 0.08, 0.55, 0.5 - k * 0.08), CF(s * (ctx.width * 0.25 + k * 0.28), base + 0.3 + k * 0.45, 0) * CFrame.Angles(0, 0, math.rad(-s * 30)), horn:Lerp(BLACK, k * 0.1))
		end
	end
	local yellow = C3(255, 195, 30)
	for _, p in ipairs({ { 5, -0.3 }, { 4, 0.3 } }) do
		ctx.side(p[1], 0, p[2], V(ctx.width * 0.14, ctx.width * 0.1, 0.4), yellow)
		ctx.side(p[1] - 1, 0, p[2], V(ctx.width * 0.04, ctx.width * 0.14, 0.38), yellow)
	end
	ctx.sparkles(C3(255, 90, 200))
end

-- Secret: dark indigo, a glowing violet panel with a black slot
DESIGNS.Secret = function(ctx)
	ctx.studs(ctx.base:Lerp(WHITE, 0.15))
	local w = ctx.width
	ctx.side(6, 0, 0, V(w * 0.28, w * 0.36, 0.34), C3(20, 16, 40))
	ctx.side(6, 0, 0, V(w * 0.22, w * 0.3, 0.38), C3(175, 110, 255), Enum.Material.Neon)
	ctx.side(6, 0, 0, V(w * 0.16, w * 0.05, 0.42), C3(12, 8, 20))
	ctx.sparkles(C3(150, 90, 220))
end

-- Celestial: deep blue, glowing cyan strips + tiles and a glowing ring
DESIGNS.Celestial = function(ctx)
	local cyan = C3(110, 225, 255)
	ctx.studs(ctx.base:Lerp(WHITE, 0.15))
	local w = ctx.width
	for _, st in ipairs({ { 7, 0, -0.1, 0.05, 0.3 }, { 7, 0, 0.25, 0.05, 0.3 }, { 3, 0, 0.1, 0.05, 0.26 }, { 6, 1, 0, 0.05, 0.3 }, { 6, 3, 0, 0.05, 0.3 } }) do
		ctx.side(st[1], st[2], st[3], V(w * st[4], w * st[5], 0.38), cyan, Enum.Material.Neon)
	end
	for _, t in ipairs({ { 8, 0, 0.1 }, { 5, 0, -0.3 }, { 6, 0, 0.35 }, { 3, 2, 0 } }) do
		ctx.side(t[1], t[2], t[3], V(w * 0.1, w * 0.1, 0.38), cyan:Lerp(WHITE, 0.3), Enum.Material.Neon)
	end
	-- glowing ring around the middle with square nodes
	for i = 0, 19 do
		local ang = i / 20 * math.pi * 2
		local r = w * 0.66
		ctx.part("CelestialRing", V(w * 0.2, 0.12, 0.12), CFrame.Angles(math.rad(8), 0, 0) * CF(math.sin(ang) * r, -0.1, math.cos(ang) * r) * CFrame.Angles(0, ang, 0), cyan, Enum.Material.Neon)
		if i % 5 == 0 then
			ctx.part("RingNode", V(0.4, 0.4, 0.4), CFrame.Angles(math.rad(8), 0, 0) * CF(math.sin(ang) * r, -0.1, math.cos(ang) * r), cyan:Lerp(WHITE, 0.3))
		end
	end
	ctx.sparkles(cyan)
end

-- Divine: white, two gold bands + buckle, white-and-gold wings
DESIGNS.Divine = function(ctx)
	local gold = C3(255, 205, 30)
	ctx.studs(ctx.base:Lerp(WHITE, 0.5))
	ctx.ring(3, 0.35, gold)
	ctx.ring(6, 0.35, gold)
	ctx.side(5, 0, 0, V(ctx.width * 0.2, ctx.width * 0.18, 0.4), gold)
	local w = ctx.width
	for _, sd in ipairs({ -1, 1 }) do
		for f = 0, 2 do
			local y = ctx.height * 0.02 + f * ctx.height * 0.1
			local len = w * (0.5 - f * 0.07)
			ctx.part("DivineWing", V(len, ctx.height * 0.08, 0.3), CF(sd * (w * 0.52 + len * 0.35), y, 0.1) * CFrame.Angles(0, 0, math.rad(sd * (30 - f * 12))), f == 1 and gold or C3(245, 246, 250))
		end
	end
	ctx.sparkles(gold)
end

-- Supreme: dark purple, gold crown with red tips, red cubes around the
-- sides, gold bars and glowing tiles
DESIGNS.Supreme = function(ctx)
	local red, gold = C3(235, 45, 80), C3(255, 200, 40)
	ctx.studs(ctx.base:Lerp(WHITE, 0.12))
	local w = ctx.width
	for _, b in ipairs({ { 7, 0, -0.35 }, { 5, 0, 0.35 }, { 4, 0, -0.1 }, { 3, 0, 0.3 }, { 6, 1, 0 }, { 5, 3, 0 } }) do
		ctx.side(b[1], b[2], b[3], V(w * 0.05, w * 0.16, 0.36), gold)
	end
	ctx.side(6, 0, -0.25, V(w * 0.2, w * 0.14, 0.36), C3(150, 90, 255), Enum.Material.Neon)
	ctx.side(4, 0, 0.3, V(w * 0.2, w * 0.14, 0.36), C3(215, 210, 255), Enum.Material.Neon)
	-- red cubes sticking out around it
	for i = 0, 5 do
		local ang = i / 6 * math.pi * 2 + math.pi / 6
		local y = (i % 2 == 0) and ctx.height * 0.12 or -ctx.height * 0.12
		ctx.part("RedCube", V(0.6, 0.6, 0.6), CF(math.sin(ang) * w * 0.56, y, math.cos(ang) * w * 0.56) * CFrame.Angles(0, ang, math.rad(45)), red)
	end
	-- crown
	local top = ctx.layerTop(#LAYERS - 1)
	for i, x in ipairs({ -0.3, 0, 0.3 }) do
		local hgt = i == 2 and 1.2 or 0.9
		ctx.part("Crown", V(0.5, hgt, 0.5), CF(x * w, top + hgt / 2, 0), gold)
		ctx.part("CrownGem", V(0.42, 0.42, 0.42), CF(x * w, top + hgt + 0.1, 0), red)
	end
	ctx.part("CrownBand", V(w * 0.8, 0.35, w * 0.5), CF(0, top + 0.15, 0), gold)
	ctx.sparkles(red)
end

--------------------------------------------------------------------
-- build
--------------------------------------------------------------------
-- root: invisible part at the egg's center; height in studs;
-- color = rarity color; rarityKey picks the design ("Common", "Epic"...)
function EggModel.Build(root, height, color, finishKey, rarityKey)
	local width = height / 1.35
	-- each rarity's own egg color (like the icons), then the finish on top
	color = EGG_COLORS[rarityKey] or color
	if finishKey == "Gold" then
		color = color:Lerp(Color3.fromRGB(255, 200, 55), 0.45)
	elseif finishKey == "Silver" then
		color = color:Lerp(Color3.fromRGB(215, 225, 240), 0.45)
	elseif finishKey == "Rainbow" then
		color = color:Lerp(Color3.fromHSV(math.random(), 0.6, 1), 0.5)
	elseif finishKey == "Diamond" then
		color = color:Lerp(Color3.fromRGB(190, 240, 255), 0.55)
	elseif finishKey == "Galaxy" then
		color = color:Lerp(Color3.fromRGB(90, 40, 170), 0.6)
	end
	local shade = color:Lerp(BLACK, 0.1) -- every other layer, so the blocks stand out
	local cf0 = root.CFrame
	local h = height / #LAYERS

	for i, f in ipairs(LAYERS) do
		local w = width * f
		local c = i % 2 == 0 and shade or color
		piece(root, "EggLayer", V(w, h, w), cf0 * CF(0, -height / 2 + (i - 0.5) * h, 0), c)
	end

	local ctx = { base = color, width = width, height = height }
	function ctx.layerTop(i)
		return -height / 2 + i * h
	end
	function ctx.part(name, size, localCf, c, material, transparency)
		return piece(root, name, size, cf0 * localCf, c, material, transparency)
	end
	-- a patch on one of the 4 sides (0-3) of layer i; lateral -0.5..0.5
	function ctx.side(i, side, lateral, size, c, material, transparency)
		local half = width * LAYERS[i] / 2
		local cf = cf0 * CFrame.Angles(0, side * math.pi / 2, 0) * CF(lateral * half * 1.4, -height / 2 + (i - 0.5) * h, -half - size.Z / 2 + 0.03)
		return piece(root, "EggDecor", size, cf, c, material, transparency)
	end
	-- a flat ring hugging layer i
	function ctx.ring(i, thickness, c)
		local w = width * LAYERS[i] * 1.05
		return piece(root, "EggRing", V(w, h * thickness, w), cf0 * CF(0, -height / 2 + (i - 0.5) * h, 0), c)
	end
	-- square studs all over (like the icons): 3 per side on the wide
	-- layers, 2 on the narrow ones
	function ctx.studs(c)
		-- every other layer only (keeps the part count low for phones)
		for i = 2, #LAYERS - 1, 2 do
			local f = LAYERS[i]
			local lats = f >= 0.85 and { -0.3, 0, 0.3 } or { -0.2, 0.2 }
			local d = width * 0.13
			for side = 0, 3 do
				for _, l in ipairs(lats) do
					ctx.side(i, side, l, V(d, math.min(d, h * 0.7), 0.3), c)
				end
			end
		end
	end
	function ctx.sparkles(c)
		local e = Instance.new("ParticleEmitter")
		e.Name = "EggSparkles"
		e.Color = ColorSequence.new(c)
		e.LightEmission = 1
		e.Rate = 3
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = root
	end

	local design = DESIGNS[rarityKey] or DESIGNS.Common
	design(ctx)

	-- cartoon shine on the front
	ctx.side(7, 0, -0.35, V(width * 0.13, width * 0.24, 0.2), WHITE, Enum.Material.SmoothPlastic, 0.3)
end

return EggModel
