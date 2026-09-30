-- MonsterModel: cartoony, studded models for every monster (pets + enemies).
-- Each moving part group (body, head, legs, wings, tail...) hangs on a
-- Motor6D named "J_<group>" from the invisible root, so a client script
-- (MonsterAnimator) can animate it: idle / walk / run / jump / fall /
-- fight / dead. Designs are in unit sizes, scaled by "s".
local MonsterModel = {}

local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local R = math.rad
local NEON = Enum.Material.Neon
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.fromRGB(20, 20, 30)
local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local BUILDERS = {}

-- Moss Slime (cute): mint see-through jelly in 6 soft layers, darker core
-- with bubbles, olive moss cap, sprout + tiny flower. Eyes: big round glossy.
BUILDERS.slime = function(b)
	local jelly, jellyLight = C(118, 222, 170), C(160, 238, 196)
	local core, moss, mossDark, pink = C(60, 170, 120), C(112, 138, 56), C(84, 104, 40), C(244, 150, 180)
	b.group("body", V(0, 0, 0))
	b.round("body", V(0.52, 0.38, 0.5), V(0, 0.5, 0.02), core, "Body", nil, 0.15)
	for _, p in ipairs({ { -0.2, 0.3, -0.1 }, { 0.25, 0.62, 0.1 }, { 0.05, 0.78, -0.2 } }) do
		b.add("body", V(0.08, 0.08, 0.08), V(p[1], p[2], p[3]), C(235, 255, 235), nil, nil, nil, 0.35, true)
	end
	local layers = { { 1.0, 0.2, 0.1 }, { 1.22, 0.22, 0.3 }, { 1.26, 0.22, 0.52 }, { 1.1, 0.2, 0.73 }, { 0.84, 0.18, 0.91 }, { 0.52, 0.12, 1.05 } }
	for i, L in ipairs(layers) do
		local g = "sl" .. i
		b.group(g, V(0, L[3], 0), "body")
		b.round(g, V(L[1], L[2], L[1]), V(0, L[3], 0), i % 2 == 0 and jelly or jellyLight, nil, nil, 0.12)
	end
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("sl3", V(sd * 0.2, 0.6, -0.645), 0.17, "round", nil, sd)
		b.add("sl3", V(0.12, 0.05, 0.03), V(sd * 0.36, 0.5, -0.63), pink, nil, nil, nil, 0.25, true)
	end
	b.add("sl3", V(0.14, 0.03, 0.03), V(0, 0.46, -0.645), C(22, 40, 26), nil, nil, nil, nil, true)
	b.add("sl6", V(0.56, 0.08, 0.56), V(0, 1.13, 0), moss)
	for i, cc in ipairs({ { 0.3, 0.14, 0.12 }, { 1.4, 0.1, 0.1 }, { 2.3, 0.16, 0.11 }, { 3.3, 0.1, 0.09 }, { 4.2, 0.13, 0.12 }, { 5.2, 0.09, 0.1 } }) do
		b.add("sl5", V(cc[2], 0.07, cc[3]), V(math.sin(cc[1]) * 0.34, 1.02 - (i % 2) * 0.03, math.cos(cc[1]) * 0.34), i % 2 == 0 and moss or mossDark)
	end
	b.group("sprout", V(-0.08, 1.17, 0.04), "sl6")
	b.add("sprout", V(0.04, 0.2, 0.04), V(-0.08, 1.27, 0.04), C(80, 150, 60))
	for _, sd in ipairs({ -1, 1 }) do
		b.add("sprout", V(0.15, 0.03, 0.08), V(-0.08 + sd * 0.08, 1.37, 0.04), C(110, 200, 80), nil, A(0, 0, R(sd * 25)))
	end
	for i = 0, 3 do
		local ang = i / 4 * math.pi * 2
		b.add("sl6", V(0.06, 0.04, 0.06), V(0.18 + math.cos(ang) * 0.05, 1.2, -0.12 + math.sin(ang) * 0.05), C(250, 150, 200), nil, nil, nil, nil, true)
	end
	b.add("sl6", V(0.05, 0.05, 0.05), V(0.18, 1.21, -0.12), C(255, 220, 90), nil, nil, nil, nil, true)
	return { style = "hop" }
end

-- Cave Bat (cute chibi): big round head on a small body, fluffy collar,
-- broad pink-lined ears, blush, small nose + fangs, two-part wings.
-- Eyes: square glossy.
BUILDERS.bat = function(b)
	local fur, furDark, collar = C(96, 72, 128), C(70, 52, 98), C(196, 172, 214)
	local membrane, bone, pink, eye = C(112, 84, 150), C(140, 116, 168), C(244, 158, 196), C(26, 18, 40)
	b.group("body", V(0, 1.15, 0))
	b.round("body", V(0.42, 0.4, 0.4), V(0, 1.1, 0.04), fur, "Body")
	b.add("body", V(0.26, 0.24, 0.05), V(0, 1.07, -0.16), collar)
	for i = 0, 5 do
		local ang = i / 6 * math.pi * 2
		b.add("body", V(0.13, 0.1, 0.13), V(math.sin(ang) * 0.2, 1.29, math.cos(ang) * 0.2 + 0.02), collar)
	end
	for _, sd in ipairs({ -1, 1 }) do
		b.add("body", V(0.07, 0.1, 0.07), V(sd * 0.1, 0.88, 0.06), furDark)
		b.add("body", V(0.09, 0.035, 0.11), V(sd * 0.1, 0.82, 0.04), bone)
	end
	b.add("body", V(0.26, 0.04, 0.16), V(0, 0.98, 0.25), membrane, nil, A(R(-25), 0, 0), nil, 0.05)
	b.group("head", V(0, 1.32, -0.02), "body")
	b.round("head", V(0.6, 0.5, 0.52), V(0, 1.55, -0.06), fur)
	b.add("head", V(0.42, 0.08, 0.38), V(0, 1.81, -0.06), furDark)
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("head", V(sd * 0.14, 1.58, -0.335), 0.15, "square", eye, sd)
		b.add("head", V(0.1, 0.05, 0.03), V(sd * 0.21, 1.47, -0.325), pink, nil, nil, nil, 0.25, true)
		b.add("head", V(0.03, 0.06, 0.03), V(sd * 0.035, 1.38, -0.335), WHITE, nil, nil, nil, nil, true)
		b.add("head", V(0.02, 0.02, 0.02), V(sd * 0.02, 1.5, -0.368), eye, nil, nil, nil, nil, true)
	end
	b.add("head", V(0.09, 0.055, 0.05), V(0, 1.49, -0.34), C(205, 130, 162), nil, nil, nil, nil, true)
	b.add("head", V(0.12, 0.025, 0.02), V(0, 1.41, -0.335), eye, nil, nil, nil, nil, true)
	b.group("jaw", V(0, 1.4, -0.26), "head")
	b.add("jaw", V(0.16, 0.05, 0.08), V(0, 1.36, -0.3), furDark)
	for _, sd in ipairs({ { "earL", -1 }, { "earR", 1 } }) do
		local g, s = sd[1], sd[2]
		b.group(g, V(s * 0.18, 1.74, -0.06), "head")
		local tilt = A(0, 0, R(-s * 28))
		local function along(d)
			return V(s * (0.2 + d * 0.47), 1.76 + d * 0.88, -0.06)
		end
		b.add(g, V(0.24, 0.12, 0.08), along(0.08), fur, nil, tilt)
		b.add(g, V(0.18, 0.14, 0.08), along(0.2), fur, nil, tilt)
		b.add(g, V(0.1, 0.12, 0.08), along(0.32), furDark, nil, tilt)
		local inner = along(0.17)
		b.add(g, V(0.13, 0.2, 0.03), V(inner.X, inner.Y, -0.105), pink, nil, tilt, nil, nil, true)
	end
	for _, sd in ipairs({ { "wingL", "wingLTip", -1 }, { "wingR", "wingRTip", 1 } }) do
		local g, tg, s = sd[1], sd[2], sd[3]
		b.group(g, V(s * 0.2, 1.22, 0), "body")
		b.add(g, V(0.4, 0.06, 0.07), V(s * 0.4, 1.26, 0), bone)
		b.add(g, V(0.4, 0.05, 0.34), V(s * 0.4, 1.23, 0.15), membrane, nil, nil, nil, 0.05)
		b.add(g, V(0.1, 0.05, 0.1), V(s * 0.46, 1.23, 0.33), membrane, nil, A(0, R(45), 0), nil, 0.05)
		b.group(tg, V(s * 0.6, 1.27, 0), g)
		b.add(tg, V(0.06, 0.09, 0.06), V(s * 0.6, 1.33, -0.04), bone)
		b.add(tg, V(0.46, 0.05, 0.05), V(s * 0.83, 1.27, 0), bone)
		b.add(tg, V(0.42, 0.05, 0.05), V(s * 0.79, 1.26, 0.16), bone, nil, A(0, R(-s * 25), 0))
		b.add(tg, V(0.34, 0.05, 0.05), V(s * 0.72, 1.25, 0.29), bone, nil, A(0, R(-s * 50), 0))
		b.add(tg, V(0.4, 0.05, 0.32), V(s * 0.8, 1.24, 0.16), membrane, nil, nil, nil, 0.05)
		b.add(tg, V(0.22, 0.05, 0.2), V(s * 0.98, 1.24, 0.08), membrane, nil, nil, nil, 0.05)
		b.add(tg, V(0.1, 0.05, 0.1), V(s * 0.76, 1.24, 0.32), membrane, nil, A(0, R(45), 0), nil, 0.05)
	end
	return { style = "fly" }
end

-- Glowcap (cute): cream stem, stubby arms + feet, springy blue-violet cap
-- with glowing spots + glowing gills. Eyes: sleepy half-closed.
BUILDERS.mushroom = function(b)
	local stem, stemDark = C(242, 234, 214), C(214, 202, 176)
	local cap, capDark, glow, pink = C(98, 108, 218), C(66, 72, 170), C(130, 238, 255), C(246, 150, 176)
	b.group("body", V(0, 0.45, 0))
	b.round("body", V(0.58, 0.6, 0.56), V(0, 0.44, 0), stem, "Body")
	b.round("body", V(0.66, 0.14, 0.62), V(0, 0.16, 0), stemDark)
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("body", V(sd * 0.13, 0.5, -0.29), 0.14, "sleepy", nil, sd)
		b.add("body", V(0.1, 0.045, 0.03), V(sd * 0.22, 0.42, -0.285), pink, nil, nil, nil, 0.2, true)
	end
	b.add("body", V(0.08, 0.04, 0.03), V(0, 0.38, -0.295), C(140, 60, 80), nil, nil, nil, nil, true)
	for _, sd in ipairs({ { "armL", -1 }, { "armR", 1 } }) do
		b.group(sd[1], V(sd[2] * 0.28, 0.5, 0), "body")
		b.round(sd[1], V(0.14, 0.15, 0.14), V(sd[2] * 0.36, 0.42, -0.02), stem)
	end
	for _, sd in ipairs({ { "legL", -1 }, { "legR", 1 } }) do
		b.group(sd[1], V(sd[2] * 0.15, 0.14, 0), "body")
		b.round(sd[1], V(0.2, 0.12, 0.26), V(sd[2] * 0.15, 0.06, -0.04), stemDark)
	end
	b.group("cap", V(0, 0.74, 0), "body")
	b.add("cap", V(0.96, 0.06, 0.96), V(0, 0.75, 0), glow, NEON, nil, nil, 0.25, true)
	local tiers = { { 1.34, 0.16, 0.86, cap }, { 1.16, 0.14, 1.0, C(112, 122, 226) }, { 0.86, 0.12, 1.12, C(128, 138, 234) }, { 0.5, 0.08, 1.21, C(146, 156, 240) } }
	b.add("cap", V(1.36, 0.05, 1.36), V(0, 0.775, 0), capDark)
	for _, tr in ipairs(tiers) do
		b.round("cap", V(tr[1], tr[2], tr[1]), V(0, tr[3], 0), tr[4])
	end
	for i = 1, 3 do
		local r = (tiers[i][1] / 2 + tiers[i + 1][1] / 2) / 2
		local top = tiers[i][3] + tiers[i][2] / 2 + 0.02
		local count = ({ 7, 5, 4 })[i]
		for k = 0, count - 1 do
			local ang = k / count * math.pi * 2 + i * 0.6
			local sz = (k % 2 == 0) and 0.11 or 0.08
			b.add("cap", V(sz, 0.04, sz), V(math.sin(ang) * r, top, math.cos(ang) * r), glow, NEON, nil, nil, nil, true)
		end
	end
	b.light(glow, 1, 9)
	b.particles(glow, 2)
	return { style = "walk" }
end

-- Ironclaw Crab (sculpted): a wide faceted dome shell with a ridge + spikes
-- around the rim and raised plate tiles, a pale belly, googly eyes on
-- stalks, big faceted iron claws (upper arm, forearm, fat claw + hinged
-- pincer), 3 jointed tapering legs per side. Eyes: googly.
BUILDERS.crab = function(b)
	local shell, shellLight, shellDark = C(222, 86, 56), C(242, 128, 90), C(170, 56, 36)
	local belly, iron, ironLight, ironDark, pink = C(250, 206, 164), C(184, 192, 206), C(224, 230, 240), C(128, 136, 152), C(255, 160, 170)
	local FLAT = A(0, 0, R(90)) -- blob lying sideways: wide in X
	b.group("body", V(0, 0.46, 0))
	b.blob("body", V(0, 0.5, 0), V(0.5, 1.1, 0.82), shell, FLAT, { name = "Body", layers = 7, shade = 0.18 })
	b.blob("body", V(0, 0.64, 0.02), V(0.3, 0.84, 0.6), shellLight, FLAT, { layers = 5 }) -- raised top
	b.blob("body", V(0, 0.32, 0), V(0.18, 0.94, 0.66), belly, FLAT, { layers = 4 })
	b.tiles("body", V(0, 0.5, 0), V(0.5, 1.1, 0.82), shellDark, FLAT, { -0.6, 0.6 }, 8, V(0.12, 0.1), { tilt = 30, skipFront = true })
	for i = -2, 2 do -- rim spikes
		b.spike("body", V(i * 0.2, 0.62, 0.36 - math.abs(i) * 0.04), V(i * 0.24, 0.7, 0.46 - math.abs(i) * 0.04), 0.07, shellDark)
	end
	for _, sd in ipairs({ -1, 1 }) do
		b.add("body", V(0.12, 0.05, 0.03), V(sd * 0.28, 0.44, -0.41), pink, nil, nil, nil, 0.2, true) -- blush
	end
	b.add("body", V(0.18, 0.04, 0.03), V(0, 0.4, -0.415), shellDark, nil, nil, nil, nil, true) -- smile
	for _, sd in ipairs({ { "eyeL", -1 }, { "eyeR", 1 } }) do
		local g, s = sd[1], sd[2]
		local x = s * 0.17
		b.group(g, V(x, 0.7, -0.26), "body")
		b.tube(g, { V(x, 0.66, -0.26), V(x, 0.78, -0.28), V(x, 0.88, -0.29) }, 0.08, 0.07, shellDark)
		b.blob(g, V(x, 0.98, -0.29), V(0.22, 0.22, 0.2), WHITE, nil, { layers = 4, noTint = true })
		b.cuteEye(g, V(x, 0.98, -0.395), 0.2, "googly", nil, s)
	end
	for _, sd in ipairs({ { "clawL", "pinchL", -1 }, { "clawR", "pinchR", 1 } }) do
		local g, pg, s = sd[1], sd[2], sd[3]
		b.group(g, V(s * 0.46, 0.48, -0.2), "body")
		b.tube(g, { V(s * 0.46, 0.48, -0.2), V(s * 0.62, 0.54, -0.34), V(s * 0.7, 0.58, -0.48) }, 0.16, 0.14, shell) -- arm
		b.blob(g, V(s * 0.74, 0.6, -0.66), V(0.34, 0.42, 0.3), iron, A(R(-80), 0, 0), { layers = 5 }) -- fat claw
		b.add(g, V(0.24, 0.035, 0.26), V(s * 0.74, 0.76, -0.66), ironLight)
		b.tube(g, { V(s * 0.72, 0.66, -0.8), V(s * 0.72, 0.64, -0.94) }, 0.13, 0.06, iron) -- fixed finger
		b.group(pg, V(s * 0.74, 0.52, -0.78), g)
		b.tube(pg, { V(s * 0.74, 0.5, -0.8), V(s * 0.74, 0.5, -0.94) }, 0.11, 0.05, ironDark) -- pincer
	end
	for _, sd in ipairs({ { "L", -1 }, { "R", 1 } }) do
		for i, z in ipairs({ -0.14, 0.08, 0.28 }) do
			local g, s = "leg" .. sd[1] .. i, sd[2]
			b.group(g, V(s * 0.46, 0.44, z), "body")
			b.tube(g, { V(s * 0.46, 0.44, z), V(s * 0.72, 0.56, z), V(s * 0.82, 0.24, z), V(s * 0.86, 0.04, z) }, 0.1, 0.05, i == 2 and shellLight or shell)
		end
	end
	return { style = "walk" }
end

-- Frostfang Wolf (sculpted): a deep-chested faceted body tapering to the
-- hips, a fluffy white mane of tiles, a faceted head with a proper snout +
-- nose, pointed ears, muscular upper legs with thin lower legs and paws,
-- ice crystals on the back, and a thick curved fluffy tail.
-- Eyes: almond, icy blue.
BUILDERS.wolf = function(b)
	-- Frostfang Wolf, from the approved preview model (MonsterRigs.wolf):
	-- faceted studded navy / blue / white armour body, a huge ice-crystal
	-- mane, blocky wolf head with ice fangs, armoured legs with ice claws,
	-- a sweeping tail with an ice fin.
	local F = 1 / 12 -- preview studs -> model units (normal size)
	local L = 0.1
	local function P(x, y, z)
		return V(x, y + L, z) * F
	end
	b.group("body", P(0, 7.8, 0))
	b.group("head", P(0, 9.6, -5.4), "body")
	b.group("jaw", P(0, 9.0, -7.5), "head")
	b.group("earL", P(-1.1, 11.8, -6.1), "head")
	b.group("earR", P(1.1, 11.8, -6.1), "head")
	for _, sd in ipairs({ { "l", -1 }, { "r", 1 } }) do
		local n, s = sd[1], sd[2]
		b.group("f" .. n, P(s * 2.5, 8.0, -3.2), "body")
		b.group("f" .. n .. "Low", P(s * 2.9, 4.2, -4.4), "f" .. n)
		b.group("h" .. n, P(s * 2.4, 7.6, 4.4), "body")
		b.group("h" .. n .. "Low", P(s * 2.8, 4.2, 6.4), "h" .. n)
	end
	b.group("tail", P(0, 7.6, 6.0), "body")
	b.group("tail2", P(0, 9.2, 11.2), "tail")
	b.rig("wolf", F, V(0, L, 0) * F)
	b.particles(C(160, 225, 255), 3)
	b.light(C(120, 210, 255), 0.8, 10)
	return { style = "walk" }
end

-- Stone Golem (sculpted): a huge faceted boulder torso with shoulder
-- boulders, a glowing rune core, moss + a flower, a small head sunk between
-- the shoulders with a rocky brow, long rocky arms with big boulder fists,
-- short thick legs. Eyes: glowing round runes.
BUILDERS.golem = function(b)
	local stone, stoneDark, stoneLight, moss, rune = C(150, 146, 140), C(110, 106, 102), C(182, 178, 170), C(100, 160, 80), C(90, 232, 212)
	b.group("body", V(0, 1.0, 0))
	b.blob("body", V(0, 1.04, 0.02), V(1.0, 0.94, 0.78), stone, nil, { name = "Body", layers = 6, shade = 0.12, bulge = -0.2 })
	b.tiles("body", V(0, 1.04, 0.02), V(1.0, 0.94, 0.78), stoneDark, nil, { -0.3, 0.3 }, 9, V(0.18, 0.14), { tilt = 12, skipFront = true, alt = stoneLight })
	b.blob("body", V(0, 0.92, -0.37), V(0.28, 0.28, 0.1), rune, nil, { name = "GolemCore", layers = 3, material = NEON, noTint = true })
	for _, sd in ipairs({ -1, 1 }) do
		b.blob("body", V(sd * 0.48, 1.36, 0), V(0.42, 0.36, 0.44), stoneLight, nil, { layers = 4 }) -- shoulder boulders
	end
	b.blob("body", V(-0.28, 1.56, 0.06), V(0.32, 0.1, 0.28), moss, nil, { layers = 2 })
	b.tube("body", { V(-0.28, 1.6, 0.06), V(-0.28, 1.74, 0.06) }, 0.04, 0.03, C(80, 150, 60))
	b.add("body", V(0.08, 0.05, 0.08), V(-0.28, 1.76, 0.06), C(255, 150, 200), nil, nil, nil, nil, true)
	b.group("head", V(0, 1.4, -0.22), "body")
	b.blob("head", V(0, 1.44, -0.26), V(0.42, 0.34, 0.36), stone, nil, { layers = 4 })
	b.add("head", V(0.46, 0.08, 0.14), V(0, 1.56, -0.42), stoneDark, nil, A(R(-10), 0, 0)) -- rocky brow
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("head", V(sd * 0.1, 1.46, -0.44), 0.11, "glow", rune, sd)
	end
	b.group("jaw", V(0, 1.32, -0.38), "head")
	b.add("jaw", V(0.16, 0.035, 0.035), V(0, 1.34, -0.44), stoneDark)
	for _, sd in ipairs({ { "armL", -1 }, { "armR", 1 } }) do
		local g, low, s = sd[1], sd[1] .. "Low", sd[2]
		b.group(g, V(s * 0.56, 1.3, 0), "body")
		b.tube(g, { V(s * 0.56, 1.3, 0), V(s * 0.66, 1.08, -0.02), V(s * 0.7, 0.9, -0.04) }, 0.26, 0.22, stone)
		b.group(low, V(s * 0.7, 0.9, -0.04), g)
		b.tube(low, { V(s * 0.7, 0.9, -0.04), V(s * 0.72, 0.72, -0.06) }, 0.22, 0.24, stoneDark)
		b.blob(low, V(s * 0.73, 0.58, -0.07), V(0.38, 0.34, 0.38), stoneLight, nil, { layers = 4 }) -- boulder fist
	end
	for _, sd in ipairs({ { "legL", -1 }, { "legR", 1 } }) do
		local g, low, s = sd[1], sd[1] .. "Low", sd[2]
		b.group(g, V(s * 0.24, 0.66, 0.04), "body")
		b.blob(g, V(s * 0.25, 0.5, 0.03), V(0.3, 0.34, 0.32), stoneDark, nil, { layers = 4 })
		b.group(low, V(s * 0.26, 0.32, 0.02), g)
		b.tube(low, { V(s * 0.26, 0.34, 0.02), V(s * 0.26, 0.14, 0.0) }, 0.24, 0.26, stone)
		b.blob(low, V(s * 0.26, 0.06, -0.05), V(0.32, 0.12, 0.42), stoneLight, nil, { layers = 3 })
	end
	b.particles(C(180, 170, 150), 0)
	b.light(rune, 0.8, 9)
	return { style = "walk" }
end

-- shared: a two-part membrane wing (arm bone + inner membrane on the
-- shoulder joint, 3 finger bones + outer membranes on the wrist joint)
local function batWing(b, g, tg, s, o)
	local shoulder, wrist = o.shoulder, o.wrist
	b.group(g, shoulder, "body")
	b.link(g, shoulder, wrist, o.bone, o.boneColor)
	-- inner membrane (from the body side out to the arm)
	b.add(g, V(math.abs(wrist.X - shoulder.X) + 0.1, 0.04, o.innerDepth), V((shoulder.X + wrist.X) / 2, (shoulder.Y + wrist.Y) / 2 - 0.04, shoulder.Z + o.innerDepth / 2 + 0.05), o.membrane, o.memMat, nil, nil, o.memTrans)
	b.group(tg, wrist, g)
	b.spike(tg, wrist, wrist + V(s * 0.08, 0.16, -0.06), o.bone * 0.7, o.boneColor) -- wrist claw
	for i, f in ipairs(o.fingers) do
		local tip = wrist + V(s * f[1], f[2], f[3])
		b.link(tg, wrist, tip, o.bone * (1 - i * 0.12), o.boneColor)
	end
	-- outer membranes between the fingers
	for _, m in ipairs(o.panels) do
		b.add(tg, V(m[4], 0.04, m[5]), wrist + V(s * m[1], m[2], m[3]), o.membrane, o.memMat, nil, nil, o.memTrans)
	end
	-- glowing veins
	if o.vein then
		for _, f in ipairs(o.fingers) do
			local tip = wrist + V(s * f[1] * 0.9, f[2] * 0.9 - 0.03, f[3] * 0.9 + 0.12)
			b.link(tg, wrist + V(s * 0.1, -0.03, 0.12), tip, 0.03, o.vein, NEON, nil, true)
		end
	end
	-- scalloped back edge
	for _, e in ipairs(o.edge or {}) do
		b.add(tg, V(0.14, 0.04, 0.14), wrist + V(s * e[1], e[2], e[3]), o.membrane, o.memMat, A(0, R(45), 0), nil, o.memTrans)
	end
end
MonsterModel._batWing = batWing

-- Ember Phoenix (the owner's own design): a studded brick phoenix. Angular
-- red body with yellow chest armour plates, a head turned to the side with
-- glowing yellow eyes, angry brows, a hooked yellow beak and a big spiky
-- crest; wings raised in a V made of three bands of pointed feather plates
-- (red near the arm, then orange, then yellow); long tail feathers curling
-- down; yellow legs with curled talons; fire sparks + glow.
-- Built in "preview studs" and scaled down by F to a normal monster size.
BUILDERS.phoenix = function(b)
	-- Ember Phoenix, from the approved preview model (MonsterRigs.phoenix):
	-- chunky studded feathers, yellow hexagon chest, spiky crest, big hooked
	-- beak, raised red/orange/yellow wings, curling flame tail, gold talons.
	local F = 1 / 16 -- preview studs -> model units (normal size)
	local function P(x, y, z)
		return V(x, y, z) * F
	end
	b.group("body", P(0, 19.1668, 0.6))
	b.group("head", P(0, 25.166800000000002, -2), "body")
	b.group("jaw", P(0, 26.3668, -3.9), "head")
	b.group("wingL", P(-2.4, 21.7668, 0.4), "body")
	b.group("wingLTip", P(-9.68, 27.5268, 0.96), "wingL")
	b.group("wingR", P(2.4, 21.7668, 0.4), "body")
	b.group("wingRTip", P(9.68, 27.5268, 0.96), "wingR")
	b.group("tail", P(0, 15.866800000000001, 2.9), "body")
	b.group("tail2", P(0, 11.166799999999999, 6.6), "tail")
	b.group("legL", P(-1.3, 17.1668, -0.4), "body")
	b.group("legR", P(1.3, 17.1668, -0.4), "body")
	b.rig("phoenix", F)
	b.particles(C(255, 200, 60), 6)
	b.light(C(255, 150, 50), 1.2, 12)
	return { style = "fly" }
end

-- Storm Leviathan (snake): a long sea snake. The head and neck rear up like
-- a cobra, the rest of the body lies on the ground in 12 linked segments
-- that taper to a fin tail. Faceted rounded segments, belly plates, a back
-- stripe of scale tiles + small fins, a wide snake head with a snout, a
-- crest, whiskers and a forked tongue. Eyes: big fish eyes.
BUILDERS.leviathan = function(b)
	-- Storm Leviathan (god serpent): 1000+ piece rig (MonsterRigs.leviathan),
	-- a long chain of joints so the whole body can wave like a real snake.
	local F = 1 / 16 -- rig studs -> model units
	local function P(x, y, z)
		return V(x, y, z) * F
	end
	local SP = {
		P(0, 21, -13), P(0, 18.5, -10.5), P(0, 15, -8.5), P(0, 11, -7.5), P(0, 7, -6), P(0, 4, -3),
		P(2.5, 3.4, 1.5), P(4, 3.2, 6), P(2, 3.0, 10.5), P(-2.5, 2.8, 14), P(-4, 2.6, 18.5), P(-2, 2.4, 22.5),
		P(2, 2.2, 26), P(3.5, 2.0, 29.5), P(1.5, 1.8, 32.5),
	}
	b.group("body", SP[6])
	-- neck: body -> n1 .. n4 -> head -> jaw
	b.group("n1", SP[5], "body")
	b.group("n2", SP[4], "n1")
	b.group("n3", SP[3], "n2")
	b.group("n4", SP[2], "n3")
	b.group("head", SP[1], "n4")
	local H = Vector3.new(0, 21, -13)
	local hcf = CFrame.lookAt(H, H + Vector3.new(0, -0.2, -1))
	b.group("jaw", (hcf * CFrame.new(0, -1.17, -1.04)).Position * F, "head")
	-- tail: body -> t1 .. t9
	for k = 1, 9 do
		b.group("t" .. k, SP[6 + k], k == 1 and "body" or ("t" .. (k - 1)))
	end
	b.group("orbit", P(0, 9, 10), "body")
	b.rig("leviathan", F)
	b.light(C(90, 200, 255), 1.2, 12)
	b.particles(C(150, 230, 255), 4)
	return { style = "serpent" }
end

-- Void Dragon (sculpted, long): a long faceted body lying level, a deep
-- chest, belly plates, scale tiles + glowing spines along the back, a long
-- forward-reaching neck, a slim skull with a long snout, brow ridges, curved
-- swept-back horns, a lower jaw with teeth, membrane wings, front arms and
-- muscular hind legs with clawed feet, and a very long tapering tail with a
-- spade. Eyes: purple cat slits.
BUILDERS["void-dragon"] = function(b)
	-- built from the approved preview model (MonsterRigs["void-dragon"]):
	-- black studded body, glowing crystal chest + spikes, thick studded
	-- wing fingers with pixel-mosaic membranes, crystal claws, curling
	-- tail with a crystal blade. Each piece's "G" attribute = its joint.
	local F = 1 / 14 -- preview studs -> model units (normal size)
	local LIFT = 12 -- it flies: the whole dragon hovers this high (preview studs)
	local function P(x, y, z)
		return V(x, y + LIFT, z) * F
	end
	b.group("body", P(0, 7.5, 0.5))
	b.group("neck", P(0, 8.9, -3.4), "body")
	b.group("head", P(0, 13.9, -5.6), "neck")
	b.group("jaw", P(0, 13.97, -5.98), "head")
	for _, sd in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local n, s = sd[1], sd[2]
		b.group("wing" .. n, P(s * 2.5, 9.6, -0.8), "body")
		b.group("wing" .. n .. "Tip", P(s * 11.4, 18.2, 1.4), "wing" .. n)
		local f, h = (s < 0 and "fl" or "fr"), (s < 0 and "hl" or "hr")
		b.group(f, P(s * 2.6, 7.4, -2.2), "body")
		b.group(f .. "Low", P(s * 3.0, 4.6, -3.2), f)
		b.group(h, P(s * 2.4, 6.8, 4.0), "body")
		b.group(h .. "Low", P(s * 3.1, 4.2, 2.8), h)
	end
	b.group("tail", P(0, 6.6, 5.2), "body")
	b.group("tail2", P(-1.5, 4.8, 10.6), "tail")
	b.group("tail3", P(-6.6, 2.9, 11.6), "tail2")
	b.rig("void-dragon", F, V(0, LIFT, 0) * F)
	b.particles(C(190, 90, 255), 3)
	b.light(C(170, 70, 255), 1, 10)
	return { style = "fly" }
end

-- Shadow Wraith (from the approved preview model, MonsterRigs.wraith):
-- a see-through shadow in a studded robe with a pointed hood, glowing
-- eyes, chains, torn flowing hem with violet shadow flames, bony clawed
-- hands and a big reaper scythe in the right hand.
BUILDERS.wraith = function(b)
	local F = 1 / 14 -- preview studs -> model units (normal size)
	local function P(x, y, z)
		return V(x, y, z) * F
	end
	b.group("body", P(0, 12.4, 0.1))
	b.group("cape", P(0, 10.9, 0.2), "body")
	b.group("head", P(0, 17.6, 0.3), "body")
	b.group("armL", P(-3.4, 16.18, 0), "body")
	b.group("armLLow", P(-4.3, 13.58, -2.3), "armL")
	b.group("armR", P(3.4, 16.18, 0), "body")
	b.group("armRLow", P(4.8, 14.18, -1.3), "armR")
	b.group("scythe", P(4.43, 17.18, -2.87), "armRLow")
	b.rig("wraith", F)
	b.light(C(150, 70, 255), 0.8, 9)
	return { style = "float" }
end

-- Star Seraph (sculpted): a graceful angel. A faceted torso in gold armor
-- over a flowing robe that widens to a hem, a head with golden hair, a
-- glowing halo, 4 feathered wings (layered feather plates) and a star wand.
-- Eyes: happy closed "^ ^".
BUILDERS.seraph = function(b)
	local robe, robeShade, gold, skin, wing, star = C(236, 240, 255), C(206, 214, 240), C(255, 210, 90), C(255, 226, 200), C(226, 236, 255), C(255, 245, 170)
	b.group("body", V(0, 1.3, 0))
	b.blob("body", V(0, 1.3, 0), V(0.42, 0.52, 0.34), gold, nil, { name = "Body", layers = 5 }) -- armored chest
	b.blob("body", V(0, 0.9, 0.02), V(0.56, 0.6, 0.5), robe, nil, { layers = 6, bulge = 0.5, shade = 0.08 }) -- robe
	b.tiles("body", V(0, 0.9, 0.02), V(0.56, 0.6, 0.5), robeShade, nil, { -0.6 }, 10, V(0.1, 0.12), { tilt = 5 }) -- hem folds
	b.add("body", V(0.08, 0.08, 0.03), V(0, 1.34, -0.175), C(120, 220, 255), NEON, A(0, 0, R(45)), nil, nil, true) -- gem
	b.group("head", V(0, 1.56, 0), "body")
	b.tube("head", { V(0, 1.54, 0), V(0, 1.62, 0) }, 0.14, 0.14, skin)
	b.blob("head", V(0, 1.78, 0), V(0.38, 0.4, 0.36), skin, nil, { layers = 5 })
	b.blob("head", V(0, 1.9, 0.04), V(0.42, 0.26, 0.4), gold, nil, { layers = 4 }) -- golden hair
	b.tube("head", b.curve(V(0, 1.84, 0.18), V(0, 1.7, 0.26), V(0, 1.5, 0.22), 3), 0.14, 0.06, gold) -- flowing hair
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("head", V(sd * 0.09, 1.8, -0.18), 0.11, "happy", nil, sd)
		b.add("head", V(0.07, 0.035, 0.03), V(sd * 0.14, 1.72, -0.175), C(255, 160, 180), nil, nil, nil, 0.25, true)
	end
	b.group("halo", V(0, 2.16, 0), "head")
	for i = 0, 15 do
		local ang = i / 16 * math.pi * 2
		b.add("halo", V(0.08, 0.04, 0.05), V(math.sin(ang) * 0.2, 2.16, math.cos(ang) * 0.2), gold, NEON, A(0, ang, 0), nil, nil, true)
	end
	-- 4 feathered wings: layered feather plates fanning out and back
	local function featherWing(g, s, shoulder, span, droop, rows)
		for r = 0, rows - 1 do
			for i = 0, 4 do
				local t = i / 4
				local root = shoulder + V(s * span * t * 0.5, -r * 0.06, 0.06 + r * 0.05)
				local tip = shoulder + V(s * span * (0.3 + t * 0.7), droop * t - r * 0.08, 0.2 + t * 0.34 + r * 0.06)
				local dir = tip - root
				b.add(g, V(0.1, 0.03, dir.Magnitude), (root + tip) / 2, (i + r) % 2 == 0 and wing or C(255, 255, 255), NEON, CFrame.lookAt(Vector3.zero, dir.Unit), nil, 0.1, true)
			end
		end
	end
	for _, sd in ipairs({ { "wingL", "wingLTip", -1 }, { "wingR", "wingRTip", 1 } }) do
		local g, tg, s = sd[1], sd[2], sd[3]
		b.group(g, V(s * 0.16, 1.44, 0.14), "body")
		featherWing(g, s, V(s * 0.16, 1.44, 0.14), 0.5, 0.2, 2)
		b.group(tg, V(s * 0.46, 1.6, 0.3), g)
		featherWing(tg, s, V(s * 0.4, 1.58, 0.28), 0.34, 0.1, 1)
	end
	for _, sd in ipairs({ { "wing2L", -1 }, { "wing2R", 1 } }) do
		b.group(sd[1], V(sd[2] * 0.16, 1.12, 0.14), "body")
		featherWing(sd[1], sd[2], V(sd[2] * 0.16, 1.12, 0.14), 0.36, -0.1, 1)
	end
	b.group("armR", V(0.22, 1.42, 0), "body")
	b.tube("armR", { V(0.22, 1.42, 0), V(0.3, 1.26, -0.06), V(0.34, 1.14, -0.12) }, 0.09, 0.08, gold)
	b.tube("armR", { V(0.36, 1.46, -0.14), V(0.36, 0.9, -0.1) }, 0.035, 0.035, gold) -- star wand
	b.spike("armR", V(0.36, 1.46, -0.14), V(0.36, 1.62, -0.16), 0.12, star)
	b.particles(star, 4)
	b.light(star, 1, 10)
	return { style = "fly" }
end

-- Sun Titan (sculpted): a heroic armored giant. A broad faceted chest
-- tapering to the waist, layered shoulder pauldrons with spikes, a sun core,
-- a helmeted head with a crown of rays, muscular armored arms with big
-- gauntlets, armored thighs and boots. Eyes: determined, thick brows.
BUILDERS.titan = function(b)
	local gold, goldDark, bronze, sun, rays, skin = C(245, 196, 70), C(196, 146, 40), C(140, 92, 40), C(255, 244, 170), C(255, 200, 60), C(255, 222, 180)
	b.group("body", V(0, 1.0, 0))
	b.blob("body", V(0, 1.1, 0.02), V(0.9, 0.7, 0.64), gold, nil, { name = "Body", layers = 5, bulge = -0.35, shade = 0.1 }) -- broad chest
	b.blob("body", V(0, 0.72, 0.02), V(0.6, 0.34, 0.5), bronze, nil, { layers = 4 }) -- waist
	b.tiles("body", V(0, 1.1, 0.02), V(0.9, 0.7, 0.64), goldDark, nil, { -0.2, 0.3 }, 10, V(0.14, 0.12), { tilt = 10, skipFront = true })
	b.blob("body", V(0, 1.08, -0.32), V(0.26, 0.26, 0.1), sun, nil, { name = "GolemCore", layers = 3, material = NEON, noTint = true })
	for _, sd in ipairs({ -1, 1 }) do
		b.blob("body", V(sd * 0.5, 1.34, 0), V(0.4, 0.26, 0.44), goldDark, A(0, 0, R(sd * -15)), { layers = 3 }) -- pauldron
		b.blob("body", V(sd * 0.52, 1.26, 0), V(0.34, 0.2, 0.38), gold, A(0, 0, R(sd * -20)), { layers = 3 })
		b.spike("body", V(sd * 0.58, 1.44, 0), V(sd * 0.72, 1.62, 0), 0.1, rays)
	end
	b.group("head", V(0, 1.4, -0.08), "body")
	b.blob("head", V(0, 1.64, -0.12), V(0.44, 0.44, 0.42), skin, nil, { layers = 5 })
	b.blob("head", V(0, 1.8, -0.1), V(0.5, 0.2, 0.48), gold, nil, { layers = 3 }) -- helmet
	for i = 0, 6 do
		local ang = (i - 3) * R(26)
		local base = V(math.sin(ang) * 0.18, 1.88, -0.12 + math.cos(ang) * 0.04)
		b.spike("head", base, base + V(math.sin(ang) * 0.1, 0.24 - math.abs(i - 3) * 0.03, 0), 0.07, rays)
	end
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("head", V(sd * 0.1, 1.66, -0.335), 0.1, "brave", nil, sd)
	end
	b.group("jaw", V(0, 1.5, -0.28), "head")
	b.add("jaw", V(0.12, 0.03, 0.03), V(0, 1.53, -0.335), bronze, nil, nil, nil, nil, true)
	for _, sd in ipairs({ { "armL", -1 }, { "armR", 1 } }) do
		local g, low, s = sd[1], sd[1] .. "Low", sd[2]
		b.group(g, V(s * 0.52, 1.22, 0), "body")
		b.blob(g, V(s * 0.6, 1.06, -0.02), V(0.24, 0.36, 0.26), skin, A(0, 0, R(s * 12)), { layers = 4 }) -- muscular arm
		b.group(low, V(s * 0.66, 0.88, -0.04), g)
		b.tube(low, { V(s * 0.66, 0.88, -0.04), V(s * 0.68, 0.72, -0.06) }, 0.2, 0.24, goldDark)
		b.blob(low, V(s * 0.69, 0.6, -0.07), V(0.3, 0.3, 0.32), gold, nil, { layers = 4 }) -- gauntlet
	end
	for _, sd in ipairs({ { "legL", -1 }, { "legR", 1 } }) do
		local g, low, s = sd[1], sd[1] .. "Low", sd[2]
		b.group(g, V(s * 0.2, 0.6, 0.04), "body")
		b.blob(g, V(s * 0.21, 0.46, 0.03), V(0.26, 0.32, 0.28), goldDark, nil, { layers = 4 })
		b.group(low, V(s * 0.22, 0.3, 0.02), g)
		b.tube(low, { V(s * 0.22, 0.32, 0.02), V(s * 0.22, 0.14, 0.0) }, 0.2, 0.22, bronze)
		b.blob(low, V(s * 0.22, 0.06, -0.05), V(0.26, 0.12, 0.38), gold, nil, { layers = 3 })
	end
	b.particles(rays, 3)
	b.light(sun, 1.2, 12)
	return { style = "walk" }
end

-- Cosmic Emperor (sculpted): a floating cosmic king. A faceted galaxy body
-- that narrows into a wispy floating tail, nebula glows, a regal collar, a
-- long flowing crimson cape, a head with a jeweled crown, clawed hands
-- holding energy, planets orbiting. Eyes: star-shaped pupils.
BUILDERS.emperor = function(b)
	local cosmos, cosmosLight, nebula, nebula2, gold, cape = C(40, 26, 90), C(70, 50, 140), C(210, 110, 255), C(110, 190, 255), C(255, 206, 80), C(190, 30, 60)
	b.group("body", V(0, 1.3, 0))
	b.blob("body", V(0, 1.24, 0), V(0.52, 0.66, 0.44), cosmos, nil, { name = "Body", layers = 6, bulge = -0.3, shade = 0.1 })
	for _, st in ipairs({ { -0.12, 1.2, nebula }, { 0.1, 1.34, nebula2 }, { 0.02, 1.08, nebula } }) do
		b.add("body", V(0.08, 0.08, 0.03), V(st[1], st[2], -0.225), st[3], NEON, nil, nil, 0.15, true)
	end
	b.tube("body", b.curve(V(0, 0.94, 0.02), V(0.06, 0.74, 0.06), V(-0.04, 0.56, 0.14), 4), 0.34, 0.04, cosmosLight) -- wispy tail
	b.blob("body", V(0, 1.54, 0.02), V(0.6, 0.14, 0.5), gold, nil, { layers = 2 }) -- regal collar
	b.group("head", V(0, 1.56, 0), "body")
	b.blob("head", V(0, 1.78, 0), V(0.44, 0.44, 0.42), cosmosLight, nil, { layers = 5 })
	for _, sd in ipairs({ -1, 1 }) do
		b.cuteEye("head", V(sd * 0.1, 1.8, -0.215), 0.13, "star", gold, sd)
	end
	b.blob("head", V(0, 2.0, 0), V(0.38, 0.08, 0.38), gold, nil, { layers = 2 }) -- crown band
	for i = 0, 4 do
		local ang = (i - 2) * R(30)
		local base = V(math.sin(ang) * 0.16, 2.04, -math.cos(ang) * 0.16)
		b.spike("head", base, base + V(0, 0.16, 0), 0.07, gold)
		b.add("head", V(0.05, 0.05, 0.05), base + V(0, 0.02, -0.03), i % 2 == 0 and C(255, 70, 90) or nebula2, NEON, nil, nil, nil, true)
	end
	b.group("cape", V(0, 1.52, 0.2), "body")
	for k = -2, 2 do -- flowing cape in folds
		b.tube("cape", b.curve(V(k * 0.1, 1.52, 0.22), V(k * 0.13, 1.14, 0.3), V(k * 0.16, 0.7, 0.34), 3), 0.14, 0.12, k % 2 == 0 and cape or C(160, 20, 48))
	end
	for _, sd in ipairs({ { "armL", -1 }, { "armR", 1 } }) do
		local g, low, s = sd[1], sd[1] .. "Low", sd[2]
		b.group(g, V(s * 0.28, 1.42, 0), "body")
		b.tube(g, { V(s * 0.28, 1.42, 0), V(s * 0.38, 1.26, -0.06), V(s * 0.4, 1.18, -0.1) }, 0.12, 0.1, cosmosLight)
		b.group(low, V(s * 0.4, 1.18, -0.1), g)
		b.blob(low, V(s * 0.42, 1.1, -0.14), V(0.12, 0.12, 0.12), gold, nil, { layers = 3 })
		b.add(low, V(0.08, 0.08, 0.08), V(s * 0.42, 1.22, -0.16), s == 1 and nebula or nebula2, NEON, nil, nil, nil, true)
	end
	b.group("orbit", V(0, 1.3, 0), "body")
	for i, pl in ipairs({ { 0, 0.12, nebula2 }, { 2.1, 0.09, nebula }, { 4.2, 0.08, gold } }) do
		local p = b.add("orbit", V(pl[2] * 2, pl[2] * 2, pl[2] * 2), V(math.sin(pl[1]) * 0.7, 1.3 + (i - 2) * 0.1, math.cos(pl[1]) * 0.7), pl[3], NEON, nil, nil, nil, true)
		p.Shape = Enum.PartType.Ball
	end
	b.particles(nebula, 4)
	b.light(nebula, 1.1, 12)
	return { style = "float" }
end

--------------------------------------------------------------------
-- build
--------------------------------------------------------------------
-- root: invisible part the game moves; s = size in studs.
-- opts: monsterId, groundOffset (studs from root down to the ground),
--       finish ("Gold"/"Silver"/"Rainbow"), defeated (grey)
--------------------------------------------------------------------
-- Sculpted mesh monsters. Templates live in
-- ReplicatedStorage.MonsterRNG.MonsterMeshes.<monsterId>: a Model whose
-- MeshParts are named by body part ("head", "left wing"...), facing -Z,
-- standing on y = 0, scaled so "1" = a size-1 monster. Each part gets a
-- joint where it meets its parent part, named like the block rigs, so the
-- same animations drive them.
--------------------------------------------------------------------
local MESH_JOINTS = {
	["body"] = { "body" },
	["lower body"] = { "body" },
	["front body"] = { "body" },
	["head"] = { "head", "body" },
	["jaw"] = { "jaw", "head" },
	["left wing"] = { "wingL", "body" },
	["right wing"] = { "wingR", "body" },
	["upper left wing"] = { "wingL", "body" },
	["upper right wing"] = { "wingR", "body" },
	["lower left wing"] = { "wing2L", "body" },
	["lower right wing"] = { "wing2R", "body" },
	["tail"] = { "tail", "body" },
	["left leg"] = { "legL", "body" },
	["right leg"] = { "legR", "body" },
	["left arm"] = { "armL", "body" },
	["right arm"] = { "armR", "body" },
	["left ear"] = { "earL", "head" },
	["right ear"] = { "earR", "head" },
	["front left leg"] = { "fl", "body" },
	["front right leg"] = { "fr", "body" },
	["back left leg"] = { "hl", "body" },
	["back right leg"] = { "hr", "body" },
	["left claw"] = { "clawL", "body" },
	["right claw"] = { "clawR", "body" },
	["left legs"] = { "legL2", "body" },
	["right legs"] = { "legR2", "body" },
	["left eye stalk"] = { "eyeL", "body" },
	["right eye stalk"] = { "eyeR", "body" },
	["cap"] = { "cap", "body" },
	["upper body"] = { "sl4", "body" },
	["crown"] = { "sl6", "sl4" },
	["halo"] = { "halo", "head" },
	["cape"] = { "cape", "body" },
	["orbiting planets"] = { "orbit", "body" },
	["middle body"] = { "seg2", "body" },
	["rear body"] = { "seg4", "seg2" },
	["left fin"] = { "finL", "body" },
	["right fin"] = { "finR", "body" },
}
local MESH_OVERRIDES = {
	leviathan = { ["tail"] = { "seg6", "seg4" } },
}
local MESH_STYLES = {
	bat = "fly", phoenix = "fly", ["void-dragon"] = "fly", seraph = "fly",
	leviathan = "serpent", slime = "hop", wraith = "float", emperor = "float",
}
local AIRBORNE = { fly = 0.55, serpent = 0.5, float = 0.35 } -- how high above the ground (x size)

local function closestPointOnPart(part, point)
	local rel = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	local clamped = Vector3.new(math.clamp(rel.X, -h.X, h.X), math.clamp(rel.Y, -h.Y, h.Y), math.clamp(rel.Z, -h.Z, h.Z))
	return part.CFrame:PointToWorldSpace(clamped)
end

-- living effects for the sculpted monsters: { preset, joint[, color] }
local EFFECTS = {
	phoenix = { { "fire", "body" }, { "fire", "wingL" }, { "fire", "wingR" }, { "fire", "tail" }, { "embers", "body" } },
	["void-dragon"] = { { "mist", "body", Color3.fromRGB(150, 70, 230) }, { "mist", "tail", Color3.fromRGB(150, 70, 230) }, { "motes", "wingL", Color3.fromRGB(200, 120, 255) }, { "motes", "wingR", Color3.fromRGB(200, 120, 255) } },
	leviathan = { { "sparks", "body" }, { "sparks", "seg4" }, { "bubbles", "body", Color3.fromRGB(190, 235, 255) } },
	wolf = { { "mist", "body", Color3.fromRGB(205, 235, 255) }, { "snow", "body" } },
	golem = { { "motes", "body", Color3.fromRGB(90, 232, 212) }, { "motes", "armL", Color3.fromRGB(90, 232, 212) }, { "motes", "armR", Color3.fromRGB(90, 232, 212) } },
	slime = { { "bubbles", "body", Color3.fromRGB(190, 255, 70) } },
	mushroom = { { "spores", "cap" } },
	wraith = { { "shadow", "cape" }, { "shadow", "body" }, { "motes", "head", Color3.fromRGB(200, 160, 255) } },
	seraph = { { "holy", "body" }, { "motes", "wingL", Color3.fromRGB(255, 230, 150) }, { "motes", "wingR", Color3.fromRGB(255, 230, 150) } },
	titan = { { "sunFire", "head" }, { "holy", "body" } },
	emperor = { { "stars", "body" }, { "mist", "cape", Color3.fromRGB(170, 60, 255) }, { "stars", "orbit" } },
}

local function emitter(part, s, color, o)
	local e = Instance.new("ParticleEmitter")
	e.Name = "LifeFX"
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	e.LightEmission = o.light or 0
	e.Rate = o.rate
	e.Lifetime = NumberRange.new(o.life * 0.6, o.life)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size * 0.4 * s), NumberSequenceKeypoint.new(0.4, o.size * s), NumberSequenceKeypoint.new(1, (o.grow and o.size * 1.6 or 0) * s) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.alpha or 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(o.speed * 0.5 * s / 4, o.speed * s / 4)
	e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	e.Acceleration = (o.accel or Vector3.zero) * s / 4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.Parent = part
	return e
end

local PRESETS = {
	fire = function(part, s)
		local f = Instance.new("Fire")
		f.Name = "LifeFX"
		f.Size = math.clamp(s * 0.8, 2, 30)
		f.Heat = 7
		f.Color = Color3.fromRGB(255, 110, 30)
		f.SecondaryColor = Color3.fromRGB(255, 220, 80)
		f.Parent = part
	end,
	sunFire = function(part, s)
		local f = Instance.new("Fire")
		f.Name = "LifeFX"
		f.Size = math.clamp(s * 0.6, 2, 30)
		f.Heat = 8
		f.Color = Color3.fromRGB(255, 200, 60)
		f.SecondaryColor = Color3.fromRGB(255, 250, 200)
		f.Parent = part
	end,
	embers = function(part, s)
		emitter(part, s, Color3.fromRGB(255, 150, 40), { rate = 14, size = 0.08, life = 1.3, speed = 3, light = 1, accel = Vector3.new(0, 6, 0) })
	end,
	mist = function(part, s, c)
		emitter(part, s, c, { rate = 7, size = 0.35, life = 2, speed = 0.5, light = 0.5, alpha = 0.65, grow = true })
	end,
	motes = function(part, s, c)
		emitter(part, s, c, { rate = 6, size = 0.06, life = 1.6, speed = 1, light = 1 })
	end,
	sparks = function(part, s)
		emitter(part, s, Color3.fromRGB(120, 240, 255), { rate = 22, size = 0.05, life = 0.25, speed = 9, light = 1 })
	end,
	bubbles = function(part, s, c)
		emitter(part, s, c, { rate = 5, size = 0.1, life = 2, speed = 1.5, light = 0.3, alpha = 0.4, accel = Vector3.new(0, 2, 0) })
	end,
	snow = function(part, s)
		emitter(part, s, Color3.fromRGB(255, 255, 255), { rate = 8, size = 0.05, life = 2, speed = 0.6, light = 0.5, accel = Vector3.new(0, -3, 0) })
	end,
	spores = function(part, s)
		emitter(part, s, Color3.fromRGB(160, 255, 90), { rate = 6, size = 0.07, life = 2.5, speed = 0.8, light = 1, accel = Vector3.new(0, 1.5, 0) })
	end,
	shadow = function(part, s)
		emitter(part, s, Color3.fromRGB(40, 20, 60), { rate = 10, size = 0.35, life = 1.5, speed = 0.5, alpha = 0.5, grow = true })
	end,
	holy = function(part, s)
		emitter(part, s, Color3.fromRGB(255, 235, 160), { rate = 4, size = 0.3, life = 1.5, speed = 0.4, light = 1, alpha = 0.6, grow = true })
	end,
	stars = function(part, s)
		emitter(part, s, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 150, 255)), { rate = 10, size = 0.07, life = 2, speed = 1, light = 1 })
	end,
}

local function buildFromMesh(root, s, opts, template)
	local id = opts.monsterId
	local style = MESH_STYLES[id] or "walk"
	local model = template:Clone()
	model:ScaleTo(model:GetScale() * s) -- templates are stored at size 1
	local lift = (AIRBORNE[style] or 0) * s
	model:PivotTo(root.CFrame * CFrame.new(0, -(opts.groundOffset or s * 0.5) + lift, 0))

	-- which joint each part belongs to
	local overrides = MESH_OVERRIDES[id] or {}
	local byJoint, parentOf = {}, {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local info = overrides[p.Name] or MESH_JOINTS[p.Name] or { "body" }
			byJoint[info[1]] = byJoint[info[1]] or {}
			table.insert(byJoint[info[1]], p)
			parentOf[info[1]] = info[2]
		end
	end
	local bodyParts = byJoint.body or {}
	local bodyCenter = #bodyParts > 0 and bodyParts[1].Position or root.Position

	local pivots = {}
	local function makeJoint(name)
		if pivots[name] or not byJoint[name] then
			return pivots[name]
		end
		local parentName = parentOf[name]
		if parentName and not pivots[parentName] then
			makeJoint(parentName)
		end
		local parentPivot = parentName and pivots[parentName]
		-- the joint sits where this part meets its parent
		local where
		if name == "body" then
			where = bodyCenter
		elseif name == "orbit" then
			where = bodyCenter
		else
			local parentPart = parentName and byJoint[parentName] and byJoint[parentName][1]
			local target = parentPart and parentPart.Position or bodyCenter
			where = closestPointOnPart(byJoint[name][1], target)
		end
		local pv = Instance.new("Part")
		pv.Name = "Pivot_" .. name
		pv.Size = Vector3.new(0.2, 0.2, 0.2)
		pv.Transparency = 1
		pv.CanCollide = false
		pv.CanQuery = false
		pv.CanTouch = false
		pv.Massless = true
		pv.CFrame = CFrame.new(where) * (root.CFrame - root.CFrame.Position)
		pv.Parent = root
		local motor = Instance.new("Motor6D")
		motor.Name = "J_" .. name
		motor.Part0 = parentPivot or root
		motor.Part1 = pv
		motor.C0 = (parentPivot or root).CFrame:ToObjectSpace(pv.CFrame)
		motor.Parent = root
		pivots[name] = pv
		return pv
	end
	for name in pairs(byJoint) do
		makeJoint(name)
	end
	-- hang every mesh part on its joint
	for name, list in pairs(byJoint) do
		for i, p in ipairs(list) do
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			if name == "body" and i == 1 then
				p.Name = "Body"
			end
			p.Parent = root
			local w = Instance.new("WeldConstraint")
			w.Part0 = pivots[name]
			w.Part1 = p
			w.Parent = p
		end
	end
	model:Destroy()

	-- finish / defeated: a colored glow over the model (keeps the mesh detail)
	local tint
	if opts.defeated then
		tint = Color3.fromRGB(110, 115, 130)
	elseif opts.finish == "Gold" then
		tint = Color3.fromRGB(255, 200, 55)
	elseif opts.finish == "Silver" then
		tint = Color3.fromRGB(215, 225, 240)
	elseif opts.finish == "Rainbow" then
		tint = Color3.fromHSV(math.random(), 0.75, 1)
	end
	if tint then
		local h = Instance.new("Highlight")
		h.Name = "FinishTint"
		h.FillColor = tint
		h.FillTransparency = opts.defeated and 0.25 or 0.55
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = root
	end
	local extra = template:GetAttribute("GlowColor")
	if typeof(extra) == "Color3" then
		local l = Instance.new("PointLight")
		l.Name = "MonsterGlow"
		l.Color = extra
		l.Brightness = 1
		l.Range = 3 * s
		l.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Name = "MonsterSparkles"
		e.Color = ColorSequence.new(extra)
		e.LightEmission = 1
		e.Rate = 3
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = root
	end
	-- living effects (fire, mist, sparks...)
	for _, fx in ipairs(EFFECTS[id] or {}) do
		local preset = PRESETS[fx[1]]
		local list = preset and byJoint[fx[2]] or {}
		for _, part in ipairs(list) do
			preset(part, s, fx[3])
		end
	end
	root:SetAttribute("RigId", id)
	root:SetAttribute("RigScale", s)
	root:SetAttribute("RigStyle", style)
	root:SetAttribute("RigMesh", true)
	return { style = style }
end

local RunServiceMM = game:GetService("RunService")

-- Merged (union) pieces can't be resized while the game runs (they keep
-- their saved size), so ready-sized copies of the Mid / Low pieces are
-- made in Studio for every size a monster is built at (pets: Normal /
-- Huge / Titan, enemies: normal / Big / Huge / Titanic):
--   MonsterRNG.MonsterRigsScaled.<set>.<rig>_<k>
-- A size that isn't there just shows the full-detail pieces.
-- (Re-run MonsterModel.EnsureScaled in Studio if monster sizes change.)
local SCALED_SETS = { "MonsterRigsMid", "MonsterRigsLow" }
local function scaledKey(name, k)
	return name .. "_" .. string.format("%.4f", k)
end
function MonsterModel.EnsureScaled(name, k)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("MonsterRNG")
	if not folder then
		return
	end
	local holder = folder:FindFirstChild("MonsterRigsScaled")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "MonsterRigsScaled"
		holder.Parent = folder
	end
	local key = scaledKey(name, k)
	for _, setName in ipairs(SCALED_SETS) do
		local set = folder:FindFirstChild(setName)
		local rig = set and set:FindFirstChild(name)
		if rig then
			local setHolder = holder:FindFirstChild(setName)
			if not setHolder then
				setHolder = Instance.new("Folder")
				setHolder.Name = setName
				setHolder.Parent = holder
			end
			if not setHolder:FindFirstChild(key) then
				local out = Instance.new("Model")
				out.Name = key
				for _, src in ipairs(rig:GetChildren()) do
					if src:IsA("BasePart") then
						local p = src:Clone()
						p.Size = src.Size * k
						local cf = src.CFrame
						p.CFrame = CFrame.new(cf.Position * k) * (cf - cf.Position)
						for _, l in ipairs(p:GetChildren()) do
							if l:IsA("PointLight") then
								l.Range = math.max(0.5, l.Range * k)
							elseif l:IsA("ParticleEmitter") then
								local kp = {}
								for _, pt in ipairs(l.Size.Keypoints) do
									table.insert(kp, NumberSequenceKeypoint.new(pt.Time, pt.Value * k, pt.Envelope * k))
								end
								l.Size = NumberSequence.new(kp)
								l.Speed = NumberRange.new(l.Speed.Min * k, l.Speed.Max * k)
								l.Acceleration = l.Acceleration * k
							end
						end
						p:SetAttribute("PreScaled", true)
						p.Parent = out
					end
				end
				out.Parent = setHolder
			end
		end
	end
end

-- add (or swap) the rig pieces of a monster built with b.rig.
-- setName: "MonsterRigs" (full detail), "MonsterRigsMid", "MonsterRigsLow"
function MonsterModel.Skin(root, setName)
	local name = root:GetAttribute("RigName")
	if not name then
		return false
	end
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("MonsterRNG")
	setName = setName or "MonsterRigs"
	local k = root:GetAttribute("RigK") or 1
	local rig, preScaled
	if setName == "MonsterMesh" then
		local ok, mod = pcall(require, folder:FindFirstChild("MonsterMesh"))
		rig = ok and mod and mod.Peek(name) or nil
		if not rig then
			return false -- meshes not made yet on this screen
		end
	elseif setName ~= "MonsterRigs" and setName ~= "MonsterMeshRigs" then
		local holder = folder and folder:FindFirstChild("MonsterRigsScaled")
		local setHolder = holder and holder:FindFirstChild(setName)
		rig = setHolder and setHolder:FindFirstChild(scaledKey(name, k))
		preScaled = rig ~= nil
		if not rig and RunServiceMM:IsRunning() then
			return false -- no ready-sized copy: keep what the monster has now
		end
	end
	if not rig then
		local set = folder and (folder:FindFirstChild(setName) or folder:FindFirstChild("MonsterRigs"))
		rig = set and set:FindFirstChild(name)
	end
	if not rig then
		return false
	end
	local pivots = {}
	for _, c in ipairs(root:GetChildren()) do
		if c:GetAttribute("Skin") then
			c:Destroy()
		elseif c.Name:sub(1, 6) == "Pivot_" then
			pivots[c.Name:sub(7)] = c
		end
	end
	local off = root:GetAttribute("RigOff") or Vector3.zero
	local sizeK = preScaled and 1 or k
	local tint, amount = root:GetAttribute("TintColor"), root:GetAttribute("TintAmount")
	local hasBody = false
	for _, src in ipairs(rig:GetChildren()) do
		if src:IsA("BasePart") then
			local g = src:GetAttribute("G")
			local pv = pivots[g] or pivots.body
			if pv then
				local rest = pv:GetAttribute("Rest") or CFrame.identity
				local p = src:Clone()
				p:SetAttribute("G", nil)
				p:SetAttribute("Skin", true)
				p:SetAttribute("PreScaled", nil)
				if sizeK ~= 1 then
					p.Size = src.Size * sizeK
				end
				local cf = src.CFrame
				local pieceRest = CFrame.new(cf.Position * sizeK + off) * (cf - cf.Position)
				local rel = rest:Inverse() * pieceRest -- piece relative to its joint
				p.CFrame = pv.CFrame * rel
				if tint and amount and p.Transparency < 0.9 then
					if p:GetAttribute("VertexColored") then
						-- mesh with its own colours: the part colour tints them
						p.Color = Color3.new(1, 1, 1):Lerp(tint, amount)
					elseif p:IsA("UnionOperation") then
						p.UsePartColor = true
						p.Color = (p:GetAttribute("AvgColor") or p.Color):Lerp(tint, amount)
					else
						p.Color = p.Color:Lerp(tint, amount)
					end
				end
				p.CastShadow = false
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Massless = true
				p.Name = (g == "body" and not hasBody) and "Body" or "Piece"
				hasBody = hasBody or g == "body"
				if sizeK ~= 1 then
					for _, l in ipairs(p:GetChildren()) do
						if l:IsA("PointLight") then
							l.Range = math.max(0.5, l.Range * sizeK)
						elseif l:IsA("ParticleEmitter") then
							local kp = {}
							for _, pt in ipairs(l.Size.Keypoints) do
								table.insert(kp, NumberSequenceKeypoint.new(pt.Time, pt.Value * sizeK, pt.Envelope * sizeK))
							end
							l.Size = NumberSequence.new(kp)
							l.Speed = NumberRange.new(l.Speed.Min * sizeK, l.Speed.Max * sizeK)
							l.Acceleration = l.Acceleration * sizeK
						end
					end
				end
				p.Parent = root
				-- fixed offset from the joint (doesn't depend on where the joint is right now)
				local w = Instance.new("Weld")
				w.Part0 = pv
				w.Part1 = p
				w.C0 = rel
				w.Parent = p
			end
		end
	end
	root:SetAttribute("SkinSet", setName or "MonsterRigs")
	root:SetAttribute("SkinVersion", (root:GetAttribute("SkinVersion") or 0) + 1)
	return true
end

function MonsterModel.Build(root, s, opts)
	opts = opts or {}
	s = s * (MonsterModel.SizeScale or 1.6) -- all monsters a little bigger
	local meshes = game:GetService("ReplicatedStorage"):FindFirstChild("MonsterRNG") and game:GetService("ReplicatedStorage").MonsterRNG:FindFirstChild("MonsterMeshes")
	local template = meshes and opts.monsterId and meshes:FindFirstChild(opts.monsterId)
	if template then
		return buildFromMesh(root, s, opts, template)
	end
	local builder = BUILDERS[opts.monsterId] or BUILDERS.slime
	local gOff = opts.groundOffset or s * 0.5
	local tint, amount
	if opts.defeated then
		tint, amount = C(95, 100, 115), 0.75
	elseif opts.finish == "Gold" then
		tint, amount = C(255, 200, 55), 0.55
	elseif opts.finish == "Silver" then
		tint, amount = C(215, 225, 240), 0.55
	elseif opts.finish == "Rainbow" then
		tint, amount = Color3.fromHSV(math.random(), 0.75, 1), 0.45
	end
	local base = root.CFrame
	local lift = V(0, gOff, 0)
	local pivots = {}
	local b = {}
	b.root = root

	function b.group(name, pos, parentGroup)
		local pv = Instance.new("Part")
		pv.Name = "Pivot_" .. name
		pv.Size = V(0.2, 0.2, 0.2)
		pv.Transparency = 1
		pv.CanCollide = false
		pv.CanQuery = false
		pv.CanTouch = false
		pv.Massless = true
		local offset = CF(pos * s - lift)
		pv.CFrame = base * offset
		pv:SetAttribute("Rest", offset) -- rest pose relative to the root (used to add rig pieces later)
		pv.Parent = root
		local motor = Instance.new("Motor6D")
		motor.Name = "J_" .. name
		local parentPivot = parentGroup and pivots[parentGroup]
		motor.Part0 = parentPivot or root
		motor.Part1 = pv
		-- relative to its parent joint, so it follows the parent's movement
		motor.C0 = parentPivot and parentPivot.CFrame:ToObjectSpace(pv.CFrame) or offset
		motor.Parent = root
		pivots[name] = pv
	end

	function b.add(group, size, pos, color, material, rot, name, transparency, noTint)
		if tint and not noTint then
			color = color:Lerp(tint, amount)
		end
		local p = Instance.new("Part")
		p.Name = name or "Piece"
		p.Size = size * s
		p.CFrame = base * CF(pos * s - lift) * (rot or CFrame.identity)
		p.Color = color
		p.Material = material or Enum.Material.Plastic
		p.Transparency = transparency or 0
		for _, f in ipairs(STUD_FACES) do
			p[f] = Enum.SurfaceType.Studs
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = root
		local w = Instance.new("WeldConstraint")
		w.Part0 = pivots[group]
		w.Part1 = p
		w.Parent = p
		return p
	end

	-- a part running exactly from p1 to p2 (limbs always connect)
	function b.link(group, p1, p2, thick, color, material, name, noTint)
		local dir = p2 - p1
		local up = math.abs(dir.Unit.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
		local rot = CFrame.lookAt(Vector3.zero, dir.Unit, up)
		if b.soft and thick >= 0.07 then
			return b.ellipsoid(group, V(thick, thick, dir.Magnitude + thick * 1.1), (p1 + p2) / 2, color, rot, name, material, nil, noTint)
		end
		local part = b.add(group, V(thick, thick, dir.Magnitude + thick * 0.5), (p1 + p2) / 2, color, material, rot, name, nil, noTint)
		-- rounded limbs: a second box turned 45 degrees around the same axis
		-- gives an 8-sided (smooth, faceted) cross-section instead of a square
		if thick >= 0.07 then
			b.add(group, V(thick * 0.94, thick * 0.94, dir.Magnitude + thick * 0.4), (p1 + p2) / 2, color, material, rot * CFrame.Angles(0, 0, math.rad(45)), nil, nil, noTint)
		end
		return part
	end

	-- a tapered spike from base toward tip (2 pieces)
	function b.spike(group, base, tip, thick, color)
		local mid = base:Lerp(tip, 0.55)
		b.link(group, base, mid, thick, color)
		b.link(group, mid, tip, thick * 0.55, color)
	end

	-- smooth ellipsoid piece: a part shaped by a sphere mesh (any proportions)
	function b.ellipsoid(group, size, pos, color, rot, name, material, transparency, noTint)
		local p = b.add(group, size, pos, color, material, rot, name, transparency, noTint)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end

	-- SCULPT HELPERS (low-poly, faceted, studded - like the crane / goose refs)

	-- an egg/ellipsoid made of stacked 8-sided slabs along its local Y axis.
	-- size = full width (X), length (Y), depth (Z). rot turns the whole blob.
	-- opts.layers (default 6), opts.shade (0..1 darker toward the ends),
	-- opts.name (name of the first part), opts.bulge (>0 = wider bottom)
	function b.blob(group, center, size, color, rot, opts)
		opts = opts or {}
		rot = rot or CFrame.identity
		if b.soft and not opts.hard then
			-- smooth: one ellipsoid + a slightly smaller shaded core for depth
			local p = b.ellipsoid(group, V(size.X, size.Y, size.Z), center, color, rot, opts.name, opts.material, opts.transparency, opts.noTint)
			return p
		end
		local n = opts.layers or 6
		local first
		for i = 1, n do
			local t = -1 + (2 * i - 1) / n -- -1 (bottom) .. 1 (top)
			local r = math.sqrt(math.max(0.08, 1 - t * t * 0.92))
			if opts.bulge then
				r *= 1 + opts.bulge * (-t) * 0.5
			end
			local h = size.Y / n * 1.12
			local off = rot:VectorToWorldSpace(V(0, t * size.Y / 2 * (1 - 1 / n * 0.5), 0))
			local c = color
			if opts.shade then
				c = color:Lerp(Color3.new(0, 0, 0), math.abs(t) * opts.shade)
			end
			local p = b.add(group, V(size.X * r, h, size.Z * r), center + off, c, opts.material, rot, (i == 1) and opts.name or nil, opts.transparency, opts.noTint)
			first = first or p
			local d = (size.X + size.Z) / 2 * r * 0.8
			b.add(group, V(math.min(d, size.X * r), h * 0.97, math.min(d, size.Z * r)), center + off, c, opts.material, rot * A(0, R(45), 0), nil, opts.transparency, opts.noTint)
			if opts.smooth then -- 16 sides: two more slabs turned 22.5 / 67.5 degrees
				local d2 = (size.X + size.Z) / 2 * r * 0.9
				b.add(group, V(math.min(d2, size.X * r * 0.96), h * 0.95, math.min(d2, size.Z * r * 0.96)), center + off, c, opts.material, rot * A(0, R(22.5), 0), nil, opts.transparency, opts.noTint)
				b.add(group, V(math.min(d2, size.X * r * 0.96), h * 0.95, math.min(d2, size.Z * r * 0.96)), center + off, c, opts.material, rot * A(0, R(67.5), 0), nil, opts.transparency, opts.noTint)
			end
		end
		return first
	end

	-- a smooth tapered tube through points (neck, tail, legs): overlapping
	-- 8-sided links, thickness from thicks[1] to thicks[#] along the way
	function b.tube(group, points, thickA, thickB, color, material)
		local n = #points - 1
		for i = 1, n do
			local th = thickA + (thickB - thickA) * ((i - 0.5) / n)
			b.link(group, points[i], points[i + 1], th, color, material)
			if i < n then
				b.round(group, V(th * 1.02, th * 1.02, th * 1.02), points[i + 1], color, nil, material) -- rounded joint
			end
		end
	end

	-- a smooth curve (quadratic bezier) sampled into points, for b.tube
	function b.curve(p0, p1, p2, steps)
		local pts = {}
		for i = 0, steps do
			local t = i / steps
			pts[#pts + 1] = p0:Lerp(p1, t):Lerp(p1:Lerp(p2, t), t)
		end
		return pts
	end

	-- raised feather / scale tiles on the surface of a blob (like the goose)
	-- rows = latitudes (-1..1), cols = how many around; side = 1 right only,
	-- -1 left only, 0 all round. front = skip the front (-Z) if true.
	function b.tiles(group, center, size, color, rot, rows, cols, tileSize, opts)
		opts = opts or {}
		rot = rot or CFrame.identity
		for _, lat in ipairs(rows) do
			for k = 0, cols - 1 do
				local lon = (k + (opts.offset or 0.5)) / cols * math.pi * 2
				local nx, ny, nz = math.cos(lat) * math.sin(lon), math.sin(lat), math.cos(lat) * math.cos(lon)
				local keep = true
				if opts.side and opts.side ~= 0 and nx * opts.side < 0.15 then
					keep = false
				end
				if opts.skipFront and nz < -0.55 then
					keep = false
				end
				if keep then
					local nLocal = V(nx, ny, nz)
					local surf = V(nx * size.X / 2, ny * size.Y / 2, nz * size.Z / 2) * 0.97
					local pos = center + rot:VectorToWorldSpace(surf)
					local nWorld = rot:VectorToWorldSpace(V(nx / size.X, ny / size.Y, nz / size.Z)).Unit
					local up = math.abs(nWorld.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
					local cf = CFrame.lookAt(Vector3.zero, nWorld, up) * A(R(opts.tilt or 18), 0, 0)
					local c = opts.alt and ((k % 2 == 0) and color or opts.alt) or color
					b.add(group, V(tileSize.X, tileSize.Y, 0.035), pos, c, nil, cf)
				end
			end
		end
	end

	-- cartoon eye facing -Z at pos (center of the eye's front). size = width.
	-- styles: round, square, sleepy, googly, almond, glow, lash, fish, slit,
	-- dot, happy, brave, star
	function b.cuteEye(group, pos, size, style, color, side)
		side = side or 1
		local S, W, BK = Enum.Material.SmoothPlastic, WHITE, C(22, 18, 30)
		local function e(sz, off, c, mat, rot, t)
			return b.add(group, sz, pos + off, c, mat or S, rot, "EyeOpen", t, true)
		end
		if style == "round" or style == "lash" or style == "brave" then
			e(V(size, size * 1.15, 0.05), V(0, 0, 0), color or BK)
			e(V(size * 0.36, size * 0.36, 0.04), V(-side * size * 0.2, size * 0.25, -0.03), W)
			e(V(size * 0.18, size * 0.18, 0.04), V(side * size * 0.18, -size * 0.22, -0.03), W)
			if style == "lash" then
				e(V(size * 0.5, size * 0.1, 0.04), V(side * size * 0.45, size * 0.55, -0.01), BK, nil, A(0, 0, R(side * -30)))
			elseif style == "brave" then
				e(V(size * 1.3, size * 0.22, 0.06), V(0, size * 0.78, -0.01), C(60, 40, 20), nil, A(0, 0, R(side * -14)))
			end
		elseif style == "square" then
			e(V(size, size * 1.1, 0.05), V(0, 0, 0), color or BK)
			e(V(size * 0.36, size * 0.36, 0.04), V(-side * size * 0.2, size * 0.25, -0.03), W)
			e(V(size * 0.2, size * 0.2, 0.04), V(side * size * 0.2, -size * 0.25, -0.03), W)
		elseif style == "sleepy" then
			e(V(size, size * 0.6, 0.05), V(0, -size * 0.1, 0), color or BK)
			e(V(size * 1.15, size * 0.22, 0.06), V(0, size * 0.22, -0.01), C(160, 140, 110))
			e(V(size * 0.24, size * 0.18, 0.04), V(-side * size * 0.18, -size * 0.08, -0.03), W)
		elseif style == "googly" then
			e(V(size, size, 0.06), V(0, 0, 0), W)
			e(V(size * 0.42, size * 0.42, 0.05), V(side * size * 0.12, -size * 0.1, -0.03), BK)
			e(V(size * 0.14, size * 0.14, 0.04), V(side * size * 0.06, size * 0.0, -0.05), W)
		elseif style == "almond" or style == "slit" then
			e(V(size * 1.1, size * 0.62, 0.05), V(0, 0, 0), W, nil, A(0, 0, R(side * 10)))
			e(V(size * 0.56, size * 0.56, 0.05), V(0, 0, -0.02), color or C(120, 200, 255))
			e(style == "slit" and V(size * 0.12, size * 0.5, 0.04) or V(size * 0.26, size * 0.28, 0.04), V(0, 0, -0.04), BK)
			e(V(size * 0.14, size * 0.14, 0.04), V(-side * size * 0.14, size * 0.12, -0.05), W)
		elseif style == "glow" then
			e(V(size, size, 0.05), V(0, 0, 0), color or C(90, 232, 212), NEON)
			e(V(size * 0.3, size * 0.3, 0.04), V(-side * size * 0.16, size * 0.18, -0.03), W, NEON)
		elseif style == "dot" then
			e(V(size * 0.5, size * 0.5, 0.05), V(0, 0, 0), color or C(200, 160, 255), NEON)
		elseif style == "happy" then
			e(V(size * 0.6, size * 0.16, 0.05), V(-size * 0.2, 0, 0), BK, nil, A(0, 0, R(30)))
			e(V(size * 0.6, size * 0.16, 0.05), V(size * 0.2, 0, 0), BK, nil, A(0, 0, R(-30)))
		elseif style == "fish" then
			e(V(size, size, 0.06), V(0, 0, 0), W)
			e(V(size * 0.62, size * 0.62, 0.05), V(0, -size * 0.04, -0.02), color or C(70, 160, 230))
			e(V(size * 0.3, size * 0.3, 0.04), V(0, -size * 0.04, -0.04), BK)
			e(V(size * 0.2, size * 0.2, 0.04), V(-side * size * 0.16, size * 0.16, -0.05), W)
		elseif style == "star" then
			e(V(size, size * 1.1, 0.05), V(0, 0, 0), BK)
			e(V(size * 0.5, size * 0.14, 0.04), V(0, 0, -0.03), color or C(255, 220, 90), NEON)
			e(V(size * 0.14, size * 0.5, 0.04), V(0, 0, -0.03), color or C(255, 220, 90), NEON)
			e(V(size * 0.36, size * 0.1, 0.04), V(0, 0, -0.03), color or C(255, 220, 90), NEON, A(0, 0, R(45)))
			e(V(size * 0.36, size * 0.1, 0.04), V(0, 0, -0.03), color or C(255, 220, 90), NEON, A(0, 0, R(-45)))
		end
	end

	-- rounded block: 3 overlapping blocks bevel every edge
	function b.round(group, size, pos, color, name, material, transparency, noTint)
		if b.soft then
			return b.ellipsoid(group, size * 1.08, pos, color, nil, name, material, transparency, noTint)
		end
		local first = b.add(group, V(size.X, size.Y * 0.78, size.Z * 0.78), pos, color, material, nil, name, transparency, noTint)
		b.add(group, V(size.X * 0.78, size.Y, size.Z * 0.78), pos, color, material, nil, nil, transparency, noTint)
		b.add(group, V(size.X * 0.78, size.Y * 0.78, size.Z), pos, color, material, nil, nil, transparency, noTint)
		return first
	end

	-- big cartoon eyes (white + pupil + shine), or glowing eyes
	function b.eyes(group, y, z, spread, size, glow)
		for _, sd in ipairs({ -1, 1 }) do
			local x = sd * spread
			if glow then
				b.add(group, V(size, size * 0.8, 0.06), V(x, y, z), glow, NEON, nil, nil, nil, true)
			else
				b.add(group, V(size, size * 1.15, 0.06), V(x, y, z), WHITE, nil, nil, nil, nil, true)
				b.add(group, V(size * 0.55, size * 0.62, 0.06), V(x + sd * size * 0.08, y - size * 0.1, z - 0.04), BLACK, nil, nil, nil, nil, true)
				b.add(group, V(size * 0.2, size * 0.2, 0.05), V(x - sd * size * 0.15, y + size * 0.22, z - 0.07), WHITE, nil, nil, nil, nil, true)
			end
		end
	end

	-- pieces from a saved rig model (MonsterRigs[name]); each piece has a
	-- "G" attribute naming its joint group; F = rig studs -> model units.
	-- In the running game the SERVER only makes the skeleton (joints);
	-- every player's screen adds the pieces itself (RigSkinner), in the
	-- quality of that player's Graphics setting.
	function b.rig(name, F, offset)
		offset = offset or Vector3.zero
		root:SetAttribute("RigName", name)
		root:SetAttribute("RigK", F * s)
		root:SetAttribute("RigOff", offset * s - lift)
		if tint then
			root:SetAttribute("TintColor", tint)
			root:SetAttribute("TintAmount", amount)
		end
		if RunServiceMM:IsServer() and RunServiceMM:IsRunning() then
			return
		end
		MonsterModel.Skin(root, "MonsterRigs")
	end

	function b.light(color, brightness, range)
		local l = Instance.new("PointLight")
		l.Name = "MonsterGlow"
		l.Color = color
		l.Brightness = brightness or 1
		l.Range = (range or 8) * s / 4
		l.Parent = root
	end

	function b.particles(color, rate)
		local e = Instance.new("ParticleEmitter")
		e.Name = "MonsterSparkles"
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Rate = rate or 3
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = root
	end

	local flags = builder(b) or {}
	root:SetAttribute("RigId", opts.monsterId or "slime")
	local pivotCount = 0
	for _, c in ipairs(root:GetChildren()) do
		if c.Name:sub(1, 6) == "Pivot_" then
			pivotCount += 1
		end
	end
	root:SetAttribute("PivotCount", pivotCount)
	-- the whole monster streams in/out together (so no joint arrives late)
	local model = root.Parent
	if model and model:IsA("Model") then
		pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		end)
	end
	root:SetAttribute("RigScale", s)
	root:SetAttribute("RigStyle", flags.style or "walk")
	return flags
end

return MonsterModel
