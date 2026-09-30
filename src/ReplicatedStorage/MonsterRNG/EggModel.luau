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
-- designs (ctx.side = a patch on one side of a layer, ctx.part = a free
-- piece placed relative to the egg's center)
--------------------------------------------------------------------
local DESIGNS = {}

-- Common: classic spotted egg
DESIGNS.Common = function(ctx)
	local spot = ctx.base:Lerp(WHITE, 0.55)
	for _, s in ipairs({ { 3, 0, -0.25 }, { 6, 0, 0.2 }, { 4, 1, 0.1 }, { 7, 1, -0.2 }, { 3, 2, 0.2 }, { 5, 2, -0.15 }, { 4, 3, -0.2 }, { 7, 3, 0.25 } }) do
		local d = ctx.width * 0.2
		ctx.side(s[1], s[2], s[3], V(d, d, 0.25), spot)
	end
	-- small hairline cracks
	local crack = ctx.base:Lerp(BLACK, 0.45)
	for _, c in ipairs({ { 6, 1, 0.05, 0.3 }, { 7, 1, 0.12, 0.14 }, { 5, 3, -0.05, 0.26 } }) do
		ctx.side(c[1], c[2], c[3], V(ctx.width * c[4], 0.05, 0.22), crack)
	end
end

-- Uncommon: leafy sprout on top + darker spots
DESIGNS.Uncommon = function(ctx)
	local leaf = Color3.fromRGB(90, 205, 80)
	local top = ctx.layerTop(#LAYERS)
	ctx.part("Stem", V(0.35, 1.1, 0.35), CF(0, top + 0.45, 0), Color3.fromRGB(110, 80, 50))
	for _, s in ipairs({ -1, 1 }) do
		ctx.part("Leaf", V(1.3, 0.25, 0.8), CF(s * 0.6, top + 0.95, 0) * CFrame.Angles(0, 0, math.rad(s * 25)), leaf)
	end
	local dot = ctx.base:Lerp(BLACK, 0.25)
	for _, s in ipairs({ { 3, 0, 0.2 }, { 6, 0, -0.2 }, { 4, 1, 0 }, { 3, 2, -0.2 }, { 6, 2, 0.15 }, { 5, 3, 0 } }) do
		local d = ctx.width * 0.18
		ctx.side(s[1], s[2], s[3], V(d, d, 0.25), dot)
	end
	-- a vine ring with little leaves
	ctx.ring(4, 0.3, Color3.fromRGB(60, 140, 60))
	for side = 0, 3 do
		ctx.side(4, side, 0.3, V(ctx.width * 0.16, ctx.width * 0.1, 0.25), leaf)
	end
end

-- Rare: ice crystals on top + a ring of bubbles
DESIGNS.Rare = function(ctx)
	local crystal = Color3.fromRGB(160, 235, 255)
	local top = ctx.layerTop(#LAYERS - 1)
	for _, s in ipairs({ { 0, 0, 1.6, 0 }, { 0.45, 0.25, 1.1, 20 }, { -0.45, -0.2, 1.1, -20 } }) do
		ctx.part("Crystal", V(0.55, s[3], 0.55), CF(s[1], top + s[3] / 2, s[2]) * CFrame.Angles(0, 0, math.rad(s[4])), crystal, Enum.Material.Glass, 0.1)
	end
	local bubble = ctx.base:Lerp(WHITE, 0.6)
	for side = 0, 3 do
		for _, l in ipairs({ -0.25, 0.25 }) do
			local d = ctx.width * 0.14
			ctx.side(5, side, l, V(d, d, 0.25), bubble)
		end
	end
	ctx.ring(9, 0.5, Color3.fromRGB(240, 250, 255)) -- frost cap
end

-- Epic: glowing gold 4-point stars on every side + sparkles
DESIGNS.Epic = function(ctx)
	local gold = Color3.fromRGB(255, 215, 90)
	for side = 0, 3 do
		local w = ctx.width * 0.34
		ctx.side(5, side, 0, V(w, w * 0.28, 0.25), gold, Enum.Material.Neon)
		ctx.side(5, side, 0, V(w * 0.28, w, 0.26), gold, Enum.Material.Neon)
	end
	ctx.ring(3, 0.4, Color3.fromRGB(120, 60, 190)) -- amethyst gem band
	for side = 0, 3 do
		ctx.side(3, side, 0, V(ctx.width * 0.12, ctx.width * 0.12, 0.3), Color3.fromRGB(200, 120, 255), Enum.Material.Neon)
	end
	ctx.sparkles(Color3.fromRGB(230, 170, 255))
end

-- Legendary: gold crown with gems, side gems, gold belt + golden sparkles
DESIGNS.Legendary = function(ctx)
	local gold = Color3.fromRGB(255, 200, 50)
	local crownBase = ctx.layerTop(#LAYERS - 1)
	local r = ctx.width * 0.26
	for i = 0, 7 do
		local ang = i / 8 * math.pi * 2
		local tall = i % 2 == 0
		local h = tall and 1.2 or 0.7
		ctx.part("Crown", V(0.5, h, 0.5), CF(math.cos(ang) * r, crownBase + h / 2, math.sin(ang) * r), gold)
		if tall then
			ctx.part("CrownGem", V(0.38, 0.38, 0.38), CF(math.cos(ang) * r, crownBase + h + 0.19, math.sin(ang) * r), Color3.fromRGB(255, 60, 90), Enum.Material.Neon)
		end
	end
	local gems = { Color3.fromRGB(255, 60, 90), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 255, 140), Color3.fromRGB(200, 120, 255) }
	for side = 0, 3 do
		local d = ctx.width * 0.2
		ctx.side(4, side, 0, V(d, d, 0.3), gems[side + 1], Enum.Material.Neon)
	end
	ctx.ring(6, 0.35, gold)
	ctx.sparkles(Color3.fromRGB(255, 220, 120))
end

-- Mythic: horns, glowing lava spots, scorched bottom + ember sparkles
DESIGNS.Mythic = function(ctx)
	local horn = Color3.fromRGB(40, 25, 30)
	local base = ctx.layerTop(#LAYERS - 2)
	for _, s in ipairs({ -1, 1 }) do
		ctx.part("Horn", V(0.6, 1.4, 0.6), CF(s * ctx.width * 0.22, base + 0.6, 0) * CFrame.Angles(0, 0, math.rad(-s * 25)), horn)
		ctx.part("HornTip", V(0.4, 0.8, 0.4), CF(s * ctx.width * 0.33, base + 1.45, 0) * CFrame.Angles(0, 0, math.rad(-s * 40)), horn)
	end
	local glow = Color3.fromRGB(255, 150, 40)
	for _, s in ipairs({ { 3, 0, -0.2 }, { 5, 0, 0.25 }, { 7, 0, -0.1 }, { 4, 1, 0.1 }, { 6, 2, -0.2 }, { 3, 2, 0.2 }, { 5, 3, 0 } }) do
		local d = ctx.width * 0.16
		ctx.side(s[1], s[2], s[3], V(d, d, 0.25), glow, Enum.Material.Neon)
	end
	-- glowing lava cracks
	for _, c in ipairs({ { 4, 0, -0.1, 0.34 }, { 6, 1, 0.1, 0.3 }, { 3, 2, 0, 0.36 }, { 5, 3, -0.1, 0.28 } }) do
		ctx.side(c[1], c[2], c[3], V(ctx.width * c[4], 0.05, 0.22), glow, Enum.Material.Neon)
	end
	ctx.sparkles(Color3.fromRGB(255, 80, 60))
end

-- Secret: a black shadow egg with one glowing violet eye watching you,
-- glowing violet cracks, a glowing "?" on the back, shadow wisps
DESIGNS.Secret = function(ctx)
	local violet = Color3.fromRGB(190, 120, 255)
	local w = ctx.width
	ctx.side(5, 0, 0, V(w * 0.34, w * 0.22, 0.24), Color3.fromRGB(12, 8, 18)) -- eye socket
	ctx.side(5, 0, 0, V(w * 0.26, w * 0.17, 0.26), violet, Enum.Material.Neon) -- glowing iris
	ctx.side(5, 0, 0, V(w * 0.05, w * 0.15, 0.28), Color3.fromRGB(10, 6, 14)) -- slit pupil
	ctx.side(6, 0, 0, V(w * 0.38, w * 0.06, 0.26), Color3.fromRGB(20, 16, 28)) -- lid
	for _, c in ipairs({ { 3, 1, 0.1, 0.3 }, { 7, 3, -0.1, 0.26 }, { 4, 3, 0.15, 0.2 } }) do
		ctx.side(c[1], c[2], c[3], V(w * c[4], 0.05, 0.22), violet, Enum.Material.Neon)
	end
	-- "?" on the back
	ctx.side(7, 2, 0, V(w * 0.2, w * 0.05, 0.24), violet, Enum.Material.Neon)
	ctx.side(6, 2, -0.12, V(w * 0.05, w * 0.1, 0.24), violet, Enum.Material.Neon)
	ctx.side(5, 2, 0, V(w * 0.05, w * 0.08, 0.24), violet, Enum.Material.Neon)
	ctx.side(3, 2, 0, V(w * 0.05, w * 0.05, 0.24), violet, Enum.Material.Neon)
	ctx.sparkles(Color3.fromRGB(150, 90, 220))
end

-- Celestial: deep navy starry egg, glowing stars + constellation lines, a
-- tilted glowing ring around it, cyan sparkles
DESIGNS.Celestial = function(ctx)
	local star, cyan = Color3.fromRGB(255, 255, 235), Color3.fromRGB(120, 220, 255)
	local w = ctx.width
	for _, st in ipairs({ { 2, 0, -0.2 }, { 3, 1, 0.2 }, { 4, 0, 0.25 }, { 5, 2, -0.1 }, { 6, 1, -0.2 }, { 7, 3, 0.1 }, { 8, 0, 0 }, { 3, 3, -0.2 }, { 6, 3, 0.25 }, { 4, 2, 0.2 } }) do
		ctx.side(st[1], st[2], st[3], V(w * 0.07, w * 0.07, 0.25), star, Enum.Material.Neon)
	end
	for _, ln in ipairs({ { 3, 0, 0, 0.3 }, { 5, 0, 0.1, 0.24 }, { 6, 2, 0, 0.3 } }) do
		ctx.side(ln[1], ln[2], ln[3], V(w * ln[4], 0.03, 0.24), cyan, Enum.Material.Neon)
	end
	-- a tilted glowing ring (like a planet)
	for i = 0, 15 do
		local ang = i / 16 * math.pi * 2
		local r = w * 0.72
		ctx.part("CelestialRing", V(w * 0.2, 0.05, 0.08), CFrame.Angles(math.rad(18), 0, 0) * CF(math.sin(ang) * r, 0, math.cos(ang) * r) * CFrame.Angles(0, ang, 0), cyan, Enum.Material.Neon)
	end
	ctx.sparkles(cyan)
end

-- Divine: white-gold egg with gold wings on its sides, a floating halo,
-- gold bands, golden light
DESIGNS.Divine = function(ctx)
	local gold = Color3.fromRGB(255, 205, 70)
	local w = ctx.width
	ctx.ring(3, 0.3, gold)
	ctx.ring(7, 0.3, gold)
	for _, sd in ipairs({ -1, 1 }) do
		for f = 0, 3 do
			local y = -ctx.height * 0.02 + f * ctx.height * 0.07
			local len = w * (0.55 - f * 0.08)
			ctx.part("DivineWing", V(len, ctx.height * 0.05, 0.12), CF(sd * (w * 0.5 + len * 0.4), y, 0.05) * CFrame.Angles(0, 0, math.rad(sd * (25 - f * 10))), f % 2 == 0 and WHITE or gold)
		end
	end
	for i = 0, 11 do
		local ang = i / 12 * math.pi * 2
		ctx.part("DivineHalo", V(w * 0.14, 0.05, 0.06), CF(math.sin(ang) * w * 0.32, ctx.height / 2 + 0.35, math.cos(ang) * w * 0.32) * CFrame.Angles(0, ang, 0), gold, Enum.Material.Neon)
	end
	ctx.sparkles(gold)
end

-- Supreme: crimson-black cosmic egg with galaxy swirls, glowing red cracks,
-- a jeweled gold crown, orbiting gems and a red aura
DESIGNS.Supreme = function(ctx)
	local red, gold = Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 205, 70)
	local w = ctx.width
	for _, g in ipairs({ { 3, 0, -0.1, Color3.fromRGB(170, 70, 255) }, { 5, 1, 0.15, Color3.fromRGB(80, 160, 255) }, { 6, 3, -0.15, Color3.fromRGB(170, 70, 255) }, { 4, 2, 0.1, Color3.fromRGB(255, 90, 170) } }) do
		ctx.side(g[1], g[2], g[3], V(w * 0.26, w * 0.12, 0.23), g[4], Enum.Material.Neon, 0.2) -- galaxy swirls
	end
	for _, c in ipairs({ { 4, 1, -0.1, 0.3 }, { 6, 0, 0.1, 0.28 }, { 7, 2, 0, 0.3 } }) do
		ctx.side(c[1], c[2], c[3], V(w * c[4], 0.05, 0.22), red, Enum.Material.Neon)
	end
	-- jeweled gold crown
	local top = ctx.layerTop(#LAYERS - 1)
	for i = 0, 7 do
		local ang = i / 8 * math.pi * 2
		local tall = i % 2 == 0
		local h = tall and 0.9 or 0.5
		ctx.part("Crown", V(0.45, h, 0.45), CF(math.cos(ang) * w * 0.26, top + h / 2, math.sin(ang) * w * 0.26), gold)
		if tall then
			ctx.part("CrownGem", V(0.3, 0.3, 0.3), CF(math.cos(ang) * w * 0.26, top + h + 0.15, math.sin(ang) * w * 0.26), red, Enum.Material.Neon)
		end
	end
	-- orbiting gems
	for i = 0, 5 do
		local ang = i / 6 * math.pi * 2
		ctx.part("OrbitGem", V(0.35, 0.35, 0.35), CF(math.sin(ang) * w * 0.8, math.sin(ang * 2) * 0.3, math.cos(ang) * w * 0.8) * CFrame.Angles(ang, ang, 0), i % 2 == 0 and red or gold, Enum.Material.Neon)
	end
	ctx.sparkles(red)
end

--------------------------------------------------------------------
-- build
--------------------------------------------------------------------
-- root: invisible part at the egg's center; height in studs;
-- color = rarity color; rarityKey picks the design ("Common", "Epic"...)
function EggModel.Build(root, height, color, finishKey, rarityKey)
	local width = height / 1.35
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
	local EGG_BASE = {
		Secret = Color3.fromRGB(30, 26, 40),
		Celestial = Color3.fromRGB(26, 36, 86),
		Divine = Color3.fromRGB(250, 244, 226),
		Supreme = Color3.fromRGB(62, 12, 22),
	}
	color = EGG_BASE[rarityKey] or color
	local shade = color:Lerp(BLACK, 0.1) -- every other layer, so the blocks stand out
	local cf0 = root.CFrame
	local h = height / #LAYERS

	for i, f in ipairs(LAYERS) do
		local w = width * f
		local c = i % 2 == 0 and shade or color
		if rarityKey == "Mythic" and i <= 2 then
			c = c:Lerp(BLACK, 0.4) -- scorched bottom
		end
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
