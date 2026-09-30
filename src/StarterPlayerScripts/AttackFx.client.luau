local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------
-- AttackFx: every monster has its own attack effect and its own
-- critical-hit effect (on top of the body animation MonsterAnimator
-- plays). The server sets LungeAt on a pet each time it attacks and
-- CritAt when that hit is a critical; AttackTarget says which enemy.
--
--   Cave Bat          Bite           / Bat Swarm
--   Moss Slime        Slam           / Big Slam
--   Glowcap Mushroom  Spore          / Spore Burst
--   Ironclaw Crab     Claw           / Double Claw
--   Frostfang Wolf    Bite           / Ice Howl
--   Runestone Golem   Punch          / Rock Fall
--   Ember Phoenix     Fire Feathers  / Fire Tornado
--   Storm Leviathan   Water Blast    / Lightning Storm
--   Void Dragon       Void Breath    / Void Blast
--   Shadow Wraith     Scythe Slash   / Soul Reap
--   Star Seraph       Star Shot      / Star Rain
--   Sun Titan         Solar Punch    / Solar Blast
--   Cosmic Emperor    Cosmic Blast   / Cosmic Explosion
--
-- Everything is made of a few neon parts and particle bursts on THIS
-- screen only, and cleans itself up.
--------------------------------------------------------------------

local MAX_DISTANCE = 170 -- only draw effects near the camera
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local fxFolder = Instance.new("Folder")
fxFolder.Name = "AttackFx"
fxFolder.Parent = workspace

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

--------------------------------------------------------------------
-- building blocks
--------------------------------------------------------------------

local function part(size, cf, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = fxFolder
	return p
end

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- grow (or shrink) and fade out, then remove
local function fade(p, t, sizeTo, delayBy)
	task.delay(delayBy or 0, function()
		if not p.Parent then
			return
		end
		local goal = { Transparency = 1 }
		if sizeTo then
			goal.Size = sizeTo
		end
		tween(p, t, goal)
		Debris:AddItem(p, t + 0.05)
	end)
end

local function ball(pos, size, color, t, grow, transparency)
	local p = part(Vector3.one * size, CFrame.new(pos), color, { Shape = Enum.PartType.Ball, Transparency = transparency or 0.1 })
	fade(p, t or 0.35, Vector3.one * size * (grow or 2.2))
	return p
end

-- flat shockwave on the ground
local function ring(pos, color, radius, t, thickness)
	local p = part(Vector3.new(thickness or 0.3, radius * 0.3, radius * 0.3), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.25,
	})
	fade(p, t or 0.45, Vector3.new(thickness or 0.3, radius * 2, radius * 2))
	return p
end

-- burst of particles (sparks, fire, smoke...)
local function emit(pos, color, n, opts)
	opts = opts or {}
	local life = opts.life or 0.5
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.texture or SPARK
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	e.Size = NumberSequence.new(opts.size or 1, opts.sizeEnd or 0)
	e.Transparency = NumberSequence.new(opts.transparency or 0, 1)
	e.Lifetime = NumberRange.new(life, life * 1.4)
	e.Speed = NumberRange.new((opts.speed or 12) * 0.6, opts.speed or 12)
	e.SpreadAngle = opts.spread or Vector2.new(180, 180)
	e.Acceleration = opts.gravity or Vector3.zero
	e.LightEmission = opts.light or 1
	e.Drag = opts.drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.EmissionDirection = opts.direction or Enum.NormalId.Top
	e.Rate = 0
	e.Parent = a
	e:Emit(n)
	Debris:AddItem(a, life * 1.5 + 0.2)
	return a
end

-- a part that keeps emitting particles while it lives (trails)
local function trail(p, color, texture, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(size or 0.8, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.25, 0.4)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Rate = rate or 40
	e.Parent = p
	return e
end

-- moving pieces (projectiles, orbits) are all stepped here
local movers = {}
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for i = #movers, 1, -1 do
		local m = movers[i]
		local k = math.clamp((now - m.t0) / m.dur, 0, 1)
		if not m.part.Parent then
			table.remove(movers, i)
		else
			local cf = m.step(k, now - m.t0)
			if cf then
				m.part.CFrame = cf
			end
			if k >= 1 then
				table.remove(movers, i)
				if m.onDone then
					task.spawn(m.onDone)
				end
			end
		end
	end
end)

local function move(p, dur, step, onDone)
	table.insert(movers, { part = p, dur = dur, t0 = os.clock(), step = step, onDone = onDone })
end

-- fly a part from A to B (with an optional arc / side wobble / spin);
-- onHit runs at B and the part is removed
local function shoot(p, from, to, dur, opts, onHit)
	opts = opts or {}
	local side = opts.side or Vector3.zero
	local last = from
	p.CFrame = CFrame.new(from)
	move(p, dur, function(k, t)
		local pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * (opts.arc or 0), 0)
			+ side * math.sin(k * math.pi * (opts.wobble or 1)) * (opts.wobbleAmount or 0)
		local dir = pos - last
		last = pos
		local cf = dir.Magnitude > 1e-3 and CFrame.lookAt(pos, pos + dir) or CFrame.new(pos)
		if opts.spin then
			cf *= CFrame.Angles(0, 0, t * opts.spin)
		end
		return cf
	end, function()
		p:Destroy()
		if onHit then
			onHit(to)
		end
	end)
end

-- jagged lightning bolt between two points
local function bolt(from, to, color, width, t)
	local points = { from }
	local segs = 6
	local dir = to - from
	local side = dir:Cross(Vector3.yAxis)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
	local up = side:Cross(dir).Unit
	for i = 1, segs - 1 do
		local j = (math.random() - 0.5) * dir.Magnitude * 0.12
		local jj = (math.random() - 0.5) * dir.Magnitude * 0.12
		table.insert(points, from + dir * (i / segs) + side * j + up * jj)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local p = part(Vector3.new(width, width, len), CFrame.lookAt((a + b) / 2, b), color, { Transparency = 0.05 })
		fade(p, t or 0.25, Vector3.new(width * 0.2, width * 0.2, len), 0.05)
	end
end

-- a sweeping slash arc made of thin blades
local function slash(center, facing, color, radius, tilt, t)
	local n = 7
	local base = CFrame.lookAt(center, center + facing) * CFrame.Angles(0, 0, math.rad(tilt or 0))
	for i = 0, n - 1 do
		task.delay(i * 0.012, function()
			local a = math.rad(-70 + 140 * i / (n - 1))
			local cf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
			local p = part(Vector3.new(0.25, radius * 0.45, radius * 0.35), cf, color, { Transparency = 0.1 })
			fade(p, t or 0.25, Vector3.new(0.05, radius * 0.5, radius * 0.4), 0.04)
		end)
	end
end

-- two little fangs that snap together on the target
local function fangs(pos, facing, size, color)
	local cf = CFrame.lookAt(pos, pos + facing)
	for _, sgn in ipairs({ 1, -1 }) do
		local p = part(Vector3.new(size * 0.35, size * 0.6, size * 0.35), cf * CFrame.new(0, sgn * size * 0.7, 0) * CFrame.Angles(sgn > 0 and math.pi or 0, 0, 0), color, {
			Transparency = 0.05,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = p
		tween(p, 0.1, { CFrame = cf * CFrame.new(0, sgn * size * 0.15, 0) * CFrame.Angles(sgn > 0 and math.pi or 0, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		fade(p, 0.2, nil, 0.12)
	end
end

-- things falling from the sky onto the target (rocks, stars)
local function rain(target, radius, count, spread, make, fallTime, onLand)
	for i = 1, count do
		task.delay((i - 1) * spread, function()
			local off = Vector3.new((math.random() - 0.5) * 2 * radius, 0, (math.random() - 0.5) * 2 * radius)
			local land = target + off
			local p = make()
			shoot(p, land + Vector3.new(off.X * 0.3, 26, off.Z * 0.3), land, fallTime, { spin = 8 }, function()
				onLand(land)
			end)
		end)
	end
end

-- parts circling around a point while rising (tornado, cosmic swirl)
local function swirl(center, count, dur, make, radius, height, speed)
	for i = 1, count do
		local p = make(i)
		local a0 = (i / count) * math.pi * 2
		local h0 = (i % 4) / 4
		move(p, dur, function(k, t)
			local r = radius * (0.5 + 0.5 * math.sin(k * math.pi)) + (h0 * radius * 0.3)
			local a = a0 + t * speed
			local y = height * ((h0 + k) % 1)
			return CFrame.new(center + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(0, -a, 0)
		end, function()
			fade(p, 0.2, p.Size * 0.3)
		end)
	end
end

--------------------------------------------------------------------
-- the moves. c = { from, to, dir, s (enemy size), ground, petSize }
--------------------------------------------------------------------

local FX = {}

-- Cave Bat --------------------------------------------------------
FX.bat = {
	attack = function(c) -- Bite
		fangs(c.to, -c.dir, c.s * 0.35, rgb(245, 245, 255))
		task.delay(0.1, function()
			emit(c.to, rgb(230, 60, 80), 10, { speed = 10, size = 0.6, life = 0.35 })
		end)
	end,
	crit = function(c) -- Bat Swarm
		for i = 1, 9 do
			task.delay(i * 0.035, function()
				local p = part(Vector3.new(1.2, 0.2, 0.7), CFrame.new(c.from), rgb(35, 25, 50), { Material = Enum.Material.SmoothPlastic })
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Wedge
				mesh.Parent = p
				local side = c.dir:Cross(Vector3.yAxis)
				side = side.Magnitude > 0 and side.Unit or Vector3.xAxis
				shoot(p, c.from + Vector3.new(0, math.random() * 2, 0), c.to + Vector3.new((math.random() - 0.5) * c.s, (math.random() - 0.3) * c.s * 0.6, 0), 0.35 + math.random() * 0.15, {
					arc = 2 + math.random() * 3,
					side = side,
					wobble = 3,
					wobbleAmount = (math.random() - 0.5) * 4,
				}, function(at)
					emit(at, rgb(150, 70, 220), 4, { speed = 8, size = 0.5, life = 0.3 })
				end)
			end)
		end
		task.delay(0.45, function()
			ball(c.to, c.s * 0.5, rgb(120, 50, 190), 0.35, 2.4, 0.3)
		end)
	end,
}

-- Moss Slime ------------------------------------------------------
FX.slime = {
	attack = function(c) -- Slam
		task.delay(0.12, function()
			ring(c.ground, rgb(120, 220, 90), c.s * 1.2, 0.35)
			emit(c.ground + Vector3.new(0, 0.5, 0), rgb(110, 210, 80), 12, { speed = 14, size = 0.8, life = 0.4, gravity = Vector3.new(0, -40, 0), light = 0.3 })
		end)
	end,
	crit = function(c) -- Big Slam
		task.delay(0.15, function()
			ring(c.ground, rgb(140, 240, 100), c.s * 2.4, 0.5, 0.5)
			task.delay(0.1, function()
				ring(c.ground, rgb(90, 190, 70), c.s * 1.6, 0.45, 0.4)
			end)
			ball(c.ground, c.s * 0.8, rgb(120, 220, 90), 0.4, 2.5, 0.35)
			emit(c.ground + Vector3.new(0, 0.5, 0), rgb(110, 210, 80), 30, { speed = 24, size = 1.2, life = 0.6, gravity = Vector3.new(0, -50, 0), light = 0.3 })
		end)
	end,
}

-- Glowcap Mushroom ------------------------------------------------
FX.mushroom = {
	attack = function(c) -- Spore
		for i = 1, 3 do
			task.delay(i * 0.05, function()
				local p = part(Vector3.one * 0.7, CFrame.new(c.from), rgb(120, 255, 230), { Shape = Enum.PartType.Ball, Transparency = 0.1 })
				trail(p, rgb(120, 255, 220), SPARK, 25, 0.5)
				shoot(p, c.from + Vector3.new(0, 1.5, 0), c.to + Vector3.new((math.random() - 0.5) * c.s * 0.6, 0, (math.random() - 0.5) * c.s * 0.6), 0.3, { arc = 4 }, function(at)
					emit(at, rgb(120, 255, 220), 6, { speed = 6, size = 0.8, life = 0.5, texture = SMOKE, light = 0.6 })
				end)
			end)
		end
	end,
	crit = function(c) -- Spore Burst
		local p = part(Vector3.one * 1.2, CFrame.new(c.from), rgb(150, 255, 220), { Shape = Enum.PartType.Ball, Transparency = 0.05 })
		trail(p, rgb(150, 255, 220), SPARK, 50, 0.8)
		shoot(p, c.from + Vector3.new(0, 2, 0), c.to, 0.3, { arc = 5 }, function(at)
			ball(at, c.s * 0.7, rgb(120, 255, 210), 0.5, 2.8, 0.45)
			emit(at, rgb(140, 255, 220), 26, { speed = 16, size = 1.6, life = 0.8, texture = SMOKE, light = 0.7 })
			emit(at, rgb(220, 255, 250), 18, { speed = 20, size = 0.6, life = 0.5 })
			ring(c.ground, rgb(120, 255, 210), c.s * 1.8, 0.5)
		end)
	end,
}

-- Ironclaw Crab ---------------------------------------------------
FX.crab = {
	attack = function(c) -- Claw
		task.delay(0.1, function()
			slash(c.to - c.dir * c.s * 0.3, c.dir, rgb(255, 150, 70), c.s * 0.45, 45)
			emit(c.to, rgb(255, 170, 90), 8, { speed = 10, size = 0.5, life = 0.3 })
		end)
	end,
	crit = function(c) -- Double Claw
		task.delay(0.08, function()
			slash(c.to - c.dir * c.s * 0.3, c.dir, rgb(255, 130, 60), c.s * 0.55, 45)
		end)
		task.delay(0.2, function()
			slash(c.to - c.dir * c.s * 0.3, c.dir, rgb(255, 200, 90), c.s * 0.55, -45)
			ball(c.to, c.s * 0.4, rgb(255, 160, 70), 0.3, 2.2, 0.3)
			emit(c.to, rgb(255, 180, 90), 20, { speed = 16, size = 0.7, life = 0.4 })
		end)
	end,
}

-- Frostfang Wolf --------------------------------------------------
FX.wolf = {
	attack = function(c) -- Bite
		fangs(c.to, -c.dir, c.s * 0.4, rgb(210, 240, 255))
		task.delay(0.1, function()
			emit(c.to, rgb(170, 225, 255), 10, { speed = 10, size = 0.6, life = 0.35 })
		end)
	end,
	crit = function(c) -- Ice Howl
		ring(c.from - Vector3.new(0, c.petSize * 0.4, 0), rgb(170, 225, 255), c.petSize * 2.5, 0.45, 0.4)
		emit(c.from + Vector3.new(0, c.petSize * 0.3, 0), rgb(200, 240, 255), 16, { speed = 18, size = 0.8, life = 0.5 })
		task.delay(0.18, function()
			for i = 1, 7 do
				local a = i / 7 * math.pi * 2
				local at = c.ground + Vector3.new(math.cos(a), 0, math.sin(a)) * c.s * (0.3 + math.random() * 0.4)
				local h = c.s * (0.6 + math.random() * 0.6)
				local spike = part(Vector3.new(c.s * 0.25, 0.2, c.s * 0.25), CFrame.new(at) * CFrame.Angles(math.rad(math.random(-20, 20)), a, math.rad(math.random(-20, 20))), rgb(185, 230, 255), {
					Material = Enum.Material.Ice,
					Transparency = 0.15,
				})
				tween(spike, 0.12, { Size = Vector3.new(c.s * 0.25, h, c.s * 0.25), CFrame = spike.CFrame * CFrame.new(0, h / 2, 0) }, Enum.EasingStyle.Back)
				fade(spike, 0.35, nil, 0.35)
			end
			ring(c.ground, rgb(200, 240, 255), c.s * 1.6, 0.4)
			emit(c.to, rgb(230, 250, 255), 20, { speed = 14, size = 0.7, life = 0.6 })
		end)
	end,
}

-- Runestone Golem -------------------------------------------------
FX.golem = {
	attack = function(c) -- Punch
		task.delay(0.12, function()
			ball(c.to - c.dir * c.s * 0.3, c.s * 0.35, rgb(160, 150, 140), 0.25, 2, 0.3)
			emit(c.to, rgb(150, 140, 125), 10, { speed = 12, size = 0.7, life = 0.4, texture = SMOKE, light = 0 })
		end)
	end,
	crit = function(c) -- Rock Fall
		rain(c.to, c.s * 0.5, 5, 0.07, function()
			local r = part(Vector3.one * c.s * (0.3 + math.random() * 0.2), CFrame.new(c.to), rgb(110, 105, 100), { Material = Enum.Material.Slate })
			return r
		end, 0.35, function(at)
			local land = Vector3.new(at.X, c.ground.Y, at.Z)
			ring(land, rgb(140, 130, 115), c.s * 0.8, 0.35)
			emit(land + Vector3.new(0, 0.5, 0), rgb(140, 130, 115), 10, { speed = 12, size = 1.2, life = 0.5, texture = SMOKE, light = 0 })
			-- rune glow
			emit(land + Vector3.new(0, 0.5, 0), rgb(90, 200, 255), 4, { speed = 6, size = 0.5, life = 0.4 })
		end)
	end,
}

-- Ember Phoenix ---------------------------------------------------
local function feather(color)
	local p = part(Vector3.new(0.35, 0.15, 1.6), CFrame.identity, color, { Transparency = 0.05 })
	trail(p, rgb(255, 140, 40), FIRE, 40, 1)
	return p
end
FX.phoenix = {
	attack = function(c) -- Fire Feathers
		for i = 1, 4 do
			task.delay(i * 0.04, function()
				local side = c.dir:Cross(Vector3.yAxis)
				side = side.Magnitude > 0 and side.Unit or Vector3.xAxis
				shoot(feather(i % 2 == 0 and rgb(255, 120, 40) or rgb(255, 210, 70)), c.from + side * (i - 2.5) * 0.8, c.to + side * (i - 2.5) * 0.4, 0.28, { arc = 1.5 }, function(at)
					emit(at, rgb(255, 150, 50), 5, { speed = 8, size = 0.9, life = 0.35, texture = FIRE })
				end)
			end)
		end
	end,
	crit = function(c) -- Fire Tornado
		local center = c.ground
		swirl(center, 16, 1.1, function(i)
			local p = part(Vector3.new(0.5, 0.5, 2), CFrame.new(center), i % 2 == 0 and rgb(255, 110, 30) or rgb(255, 200, 60), { Transparency = 0.1 })
			if i % 3 == 0 then
				trail(p, rgb(255, 130, 40), FIRE, 30, 1.4)
			end
			return p
		end, c.s * 0.9, c.s * 2.6, 9)
		emit(center + Vector3.new(0, c.s, 0), rgb(255, 140, 40), 30, { speed = 10, size = 2, life = 0.8, texture = FIRE, direction = Enum.NormalId.Top, spread = Vector2.new(25, 25) })
		ring(center, rgb(255, 120, 40), c.s * 2, 0.6)
	end,
}

-- Storm Leviathan -------------------------------------------------
FX.leviathan = {
	attack = function(c) -- Water Blast
		local p = part(Vector3.one * 1.3, CFrame.new(c.from), rgb(70, 170, 255), { Shape = Enum.PartType.Ball, Transparency = 0.15, Material = Enum.Material.Glass })
		trail(p, rgb(140, 210, 255), SPARK, 45, 0.7)
		shoot(p, c.from + Vector3.new(0, 1, 0), c.to, 0.25, { arc = 1 }, function(at)
			ring(c.ground, rgb(90, 180, 255), c.s * 1.1, 0.35)
			emit(at, rgb(120, 200, 255), 16, { speed = 14, size = 0.7, life = 0.45, gravity = Vector3.new(0, -40, 0), light = 0.5 })
		end)
	end,
	crit = function(c) -- Lightning Storm
		local sky = c.to + Vector3.new(0, 22, 0)
		local cloud = part(Vector3.new(1.5, c.s * 2.5, c.s * 2.5), CFrame.new(sky) * CFrame.Angles(0, 0, math.rad(90)), rgb(45, 50, 70), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
		})
		fade(cloud, 0.4, nil, 0.8)
		emit(sky, rgb(70, 75, 95), 12, { speed = 4, size = 5, life = 1, texture = SMOKE, light = 0 })
		for i = 1, 4 do
			task.delay(0.08 + i * 0.12, function()
				local hit = c.ground + Vector3.new((math.random() - 0.5) * c.s, 0, (math.random() - 0.5) * c.s)
				bolt(sky + Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3), hit, rgb(200, 230, 255), 0.35)
				ball(hit, 1.2, rgb(210, 235, 255), 0.25, 3, 0.2)
				emit(hit, rgb(170, 210, 255), 8, { speed = 16, size = 0.6, life = 0.3 })
			end)
		end
	end,
}

-- Void Dragon -----------------------------------------------------
FX["void-dragon"] = {
	attack = function(c) -- Void Breath
		for i = 1, 7 do
			task.delay(i * 0.03, function()
				local sz = 0.6 + i * 0.12
				local p = part(Vector3.one * sz, CFrame.new(c.from), i % 2 == 0 and rgb(120, 40, 200) or rgb(30, 10, 50), { Shape = Enum.PartType.Ball, Transparency = 0.1 + i * 0.05 })
				shoot(p, c.from + Vector3.new(0, 1, 0), c.to + Vector3.new((math.random() - 0.5) * c.s * 0.5, (math.random() - 0.5) * c.s * 0.4, 0), 0.25, {}, function(at)
					emit(at, rgb(160, 70, 255), 3, { speed = 6, size = 0.6, life = 0.3 })
				end)
			end)
		end
	end,
	crit = function(c) -- Void Blast
		local core = part(Vector3.one * c.s * 0.3, CFrame.new(c.to), rgb(15, 5, 25), { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Transparency = 0.05 })
		tween(core, 0.3, { Size = Vector3.one * c.s * 1.6 }, Enum.EasingStyle.Back)
		task.delay(0.35, function()
			tween(core, 0.15, { Size = Vector3.one * 0.2, Transparency = 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(core, 0.2)
		end)
		local glow = ball(c.to, c.s * 0.5, rgb(150, 60, 255), 0.5, 3.2, 0.5)
		glow.Parent = fxFolder
		task.delay(0.5, function()
			ring(c.ground, rgb(170, 80, 255), c.s * 2.4, 0.45, 0.5)
			emit(c.to, rgb(170, 90, 255), 30, { speed = 24, size = 0.9, life = 0.5 })
		end)
	end,
}

-- Shadow Wraith ---------------------------------------------------
FX.wraith = {
	attack = function(c) -- Scythe Slash
		task.delay(0.08, function()
			slash(c.to - c.dir * c.s * 0.2, c.dir, rgb(110, 60, 180), c.s * 0.7, 30, 0.3)
			emit(c.to, rgb(120, 70, 190), 8, { speed = 10, size = 0.6, life = 0.35 })
		end)
	end,
	crit = function(c) -- Soul Reap
		task.delay(0.05, function()
			slash(c.to - c.dir * c.s * 0.2, c.dir, rgb(60, 20, 110), c.s * 0.9, 20, 0.35)
			slash(c.to - c.dir * c.s * 0.2, c.dir, rgb(170, 110, 255), c.s * 0.75, -20, 0.35)
		end)
		for i = 1, 6 do
			task.delay(0.15 + i * 0.06, function()
				local wisp = part(Vector3.one * 0.6, CFrame.new(c.to), rgb(170, 255, 240), { Shape = Enum.PartType.Ball, Transparency = 0.2 })
				trail(wisp, rgb(150, 255, 230), SPARK, 35, 0.6)
				shoot(wisp, c.to + Vector3.new((math.random() - 0.5) * c.s, math.random() * c.s * 0.5, (math.random() - 0.5) * c.s), c.from, 0.45, { arc = 3 })
			end)
		end
	end,
}

-- Star Seraph -----------------------------------------------------
local function star(size, color)
	local p = part(Vector3.new(size, size, size * 0.3), CFrame.identity, color, { Transparency = 0.05 })
	local p2 = part(Vector3.new(size, size, size * 0.3), CFrame.identity, color, { Transparency = 0.05 })
	local w = Instance.new("WeldConstraint")
	p2.CFrame = p.CFrame * CFrame.Angles(0, 0, math.rad(45))
	p2.Anchored = false
	w.Part0, w.Part1 = p, p2
	w.Parent = p
	p2.Parent = p
	trail(p, rgb(255, 240, 150), SPARK, 30, 0.7)
	return p
end
FX.seraph = {
	attack = function(c) -- Star Shot
		shoot(star(1.1, rgb(255, 230, 110)), c.from + Vector3.new(0, 2, 0), c.to, 0.28, { spin = 20 }, function(at)
			ball(at, 1.2, rgb(255, 240, 150), 0.25, 2.5, 0.2)
			emit(at, rgb(255, 235, 140), 10, { speed = 12, size = 0.6, life = 0.35 })
		end)
	end,
	crit = function(c) -- Star Rain
		rain(c.to, c.s * 0.8, 9, 0.05, function()
			return star(0.9, math.random() < 0.5 and rgb(255, 230, 110) or rgb(255, 255, 220))
		end, 0.3, function(at)
			local land = Vector3.new(at.X, c.ground.Y + 0.3, at.Z)
			ball(land, 1, rgb(255, 240, 150), 0.25, 2.5, 0.2)
			emit(land, rgb(255, 235, 140), 5, { speed = 10, size = 0.5, life = 0.3 })
		end)
	end,
}

-- Sun Titan -------------------------------------------------------
FX.titan = {
	attack = function(c) -- Solar Punch
		task.delay(0.12, function()
			ball(c.to - c.dir * c.s * 0.3, c.s * 0.4, rgb(255, 200, 60), 0.3, 2.4, 0.15)
			ring(c.to - c.dir * c.s * 0.3, rgb(255, 170, 40), c.s * 0.9, 0.3)
			emit(c.to, rgb(255, 190, 70), 12, { speed = 14, size = 0.8, life = 0.4 })
		end)
	end,
	crit = function(c) -- Solar Blast
		local sky = c.to + Vector3.new(0, 30, 0)
		local beam = part(Vector3.new(30, c.s * 0.6, c.s * 0.6), CFrame.new((sky + c.ground) / 2) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 220, 90), {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.15,
		})
		fade(beam, 0.4, Vector3.new(30, c.s * 0.1, c.s * 0.1), 0.25)
		task.delay(0.15, function()
			local sun = ball(c.to, c.s * 0.8, rgb(255, 200, 50), 0.55, 3, 0.1)
			sun.Parent = fxFolder
			ring(c.ground, rgb(255, 180, 40), c.s * 3, 0.55, 0.5)
			emit(c.to, rgb(255, 210, 90), 30, { speed = 26, size = 1, life = 0.5 })
			emit(c.to, rgb(255, 150, 40), 16, { speed = 12, size = 2, life = 0.6, texture = FIRE })
		end)
	end,
}

-- Cosmic Emperor --------------------------------------------------
local COSMIC = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(120, 90, 255)),
	ColorSequenceKeypoint.new(0.5, rgb(255, 110, 220)),
	ColorSequenceKeypoint.new(1, rgb(90, 220, 255)),
})
FX.emperor = {
	attack = function(c) -- Cosmic Blast
		local p = part(Vector3.one * 1.4, CFrame.new(c.from), rgb(140, 90, 255), { Shape = Enum.PartType.Ball, Transparency = 0.05 })
		trail(p, rgb(200, 150, 255), SPARK, 50, 0.8)
		shoot(p, c.from + Vector3.new(0, 2, 0), c.to, 0.28, { arc = 1.5 }, function(at)
			ball(at, 1.5, rgb(180, 120, 255), 0.3, 2.6, 0.2)
			emit(at, COSMIC, 14, { speed = 14, size = 0.7, life = 0.45 })
		end)
	end,
	crit = function(c) -- Cosmic Explosion
		local core = ball(c.to, c.s * 0.5, rgb(255, 255, 255), 0.25, 1.5, 0)
		core.Parent = fxFolder
		task.delay(0.12, function()
			local colors = { rgb(120, 90, 255), rgb(255, 110, 220), rgb(90, 220, 255) }
			for i, col in ipairs(colors) do
				task.delay(i * 0.07, function()
					ring(c.ground + Vector3.new(0, i * 0.4, 0), col, c.s * (1.6 + i * 0.6), 0.5, 0.4)
				end)
			end
			ball(c.to, c.s * 0.9, rgb(150, 100, 255), 0.6, 3, 0.4)
			emit(c.to, COSMIC, 40, { speed = 28, size = 1, life = 0.7 })
			emit(c.to, rgb(255, 255, 255), 20, { speed = 18, size = 0.4, life = 0.9 })
		end)
	end,
}

--------------------------------------------------------------------
-- hook up every pet
--------------------------------------------------------------------

local enemiesFolder = workspace:WaitForChild("Enemies", 30)
local function findEnemy(id)
	if not enemiesFolder or not id or id == 0 then
		return nil
	end
	for _, e in ipairs(enemiesFolder:GetChildren()) do
		if e:GetAttribute("EnemyId") == id then
			return e
		end
	end
	return nil
end

local function play(model, body, isCrit)
	local camera = workspace.CurrentCamera
	if not camera or (body.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local id = body:GetAttribute("RigId")
	local set = id and FX[id]
	local enemy = findEnemy(model:GetAttribute("AttackTarget"))
	local root = enemy and enemy:FindFirstChild("Root")
	if not set or not root or enemy:GetAttribute("Dead") then
		return
	end
	local s = enemy:GetAttribute("BodySize") or 4
	local petSize = body.Size.Y
	local from = body.Position + Vector3.new(0, petSize * 0.3, 0)
	local to = root.Position
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local ctx = {
		from = from,
		to = to,
		dir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.zAxis,
		s = s,
		ground = Vector3.new(to.X, to.Y - s * 0.6, to.Z),
		petSize = petSize,
	}
	local fn = isCrit and set.crit or set.attack
	local ok, err = pcall(fn, ctx)
	if not ok then
		warn("AttackFx", id, err)
	end
end

local hooked = setmetatable({}, { __mode = "k" })
local function hook(model, body)
	if hooked[model] then
		return
	end
	hooked[model] = true
	local critAt = 0
	model:GetAttributeChangedSignal("CritAt"):Connect(function()
		critAt = os.clock()
	end)
	model:GetAttributeChangedSignal("LungeAt"):Connect(function()
		local at = os.clock()
		-- CritAt is set right after LungeAt on the same hit: give it a frame
		task.delay(0.05, function()
			play(model, body, critAt >= at - 0.01)
		end)
	end)
end

while true do
	local world = workspace:FindFirstChild("MonsterRNGWorld")
	if world then
		for _, base in ipairs(world:GetChildren()) do
			local pets = base.Name:match("^Base_") and base:FindFirstChild("Pets")
			if pets then
				for _, m in ipairs(pets:GetChildren()) do
					local body = m:GetAttribute("Kind") == "monster" and m:FindFirstChild("MonsterBody")
					if body then
						hook(m, body)
					end
				end
			end
		end
	end
	task.wait(1)
end
