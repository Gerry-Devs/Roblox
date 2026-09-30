local RunService = game:GetService("RunService")

--------------------------------------------------------------------
-- MonsterAnimator: animates every monster model (your pets, other
-- players' pets, enemies) on this screen. States:
--   idle / walk / run / jump / fall / fight / dead
-- Flyers (bat, phoenix, void dragon) hover and flap, the leviathan swims
-- with a wave, the slime hops, legged monsters swing their legs.
--------------------------------------------------------------------

local A, CF = CFrame.Angles, CFrame.new
local R = math.rad
local WHITE = Color3.new(1, 1, 1)
local MAX_DISTANCE = 160

local rigs = {} -- root part -> state
local smoothMove

local function register(model, root)
	if rigs[root] or not root:GetAttribute("RigId") then
		return
	end
	local motors = {}
	local count = 0
	for _, m in ipairs(root:GetChildren()) do
		if m:IsA("Motor6D") and m.Name:sub(1, 2) == "J_" then
			motors[m.Name:sub(3)] = m
			count += 1
		end
	end
	if count == 0 then
		return -- not loaded yet, try again next scan
	end
	local function collectParts()
	local parts, eyesOpen, eyesClosed = {}, {}, {}
	for _, p in ipairs(root:GetChildren()) do
		if p:IsA("BasePart") and not p.Name:find("Pivot_", 1, true) then
			if p:GetAttribute("VertexColored") then
				-- mesh pieces flash with a Highlight instead (see doFlash)
			elseif p:IsA("UnionOperation") then
				table.insert(parts, { p, p.Color, p.UsePartColor, p:GetAttribute("AvgColor") or p.Color })
			else
				table.insert(parts, { p, p.Color })
			end
			if p.Name == "EyeOpen" then
				table.insert(eyesOpen, p)
			elseif p.Name == "EyeClosed" then
				table.insert(eyesClosed, p)
				p.LocalTransparencyModifier = 1 -- hidden until a blink
			end
		end
	end
	return parts, eyesOpen, eyesClosed
	end
	local parts, eyesOpen, eyesClosed = collectParts()
	local st = {
		model = model,
		root = root,
		motors = motors,
		parts = parts,
		eyesOpen = eyesOpen,
		eyesClosed = eyesClosed,
		s = root:GetAttribute("RigScale") or 4,
		style = root:GetAttribute("RigStyle") or "walk",
		rigId = root:GetAttribute("RigId"),
		mesh = root:GetAttribute("RigMesh") == true,
		phase = math.random() * 10,
		samplePos = root.Position,
		sampleAt = os.clock(),
		vel = Vector3.zero,
		attackAt = 0,
		hitAt = 0,
		flashing = false,
	}
	-- pieces added / swapped on this screen (RigSkinner): pick them up
	root:GetAttributeChangedSignal("SkinVersion"):Connect(function()
		st.parts, st.eyesOpen, st.eyesClosed = collectParts()
		st.flashing = false
	end)
	model:GetAttributeChangedSignal("LungeAt"):Connect(function()
		st.attackAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Attacks"):Connect(function()
		st.attackAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Hits"):Connect(function()
		st.hitAt = os.clock()
	end)
	rigs[root] = st
end

-- find monsters (things stream in later, so keep scanning)
task.spawn(function()
	while true do
		local world = workspace:FindFirstChild("MonsterRNGWorld")
		if world then
			for _, base in ipairs(world:GetChildren()) do
				local pets = base.Name:match("^Base_") and base:FindFirstChild("Pets")
				if pets then
					for _, m in ipairs(pets:GetChildren()) do
						local body = m:GetAttribute("Kind") == "monster" and m:FindFirstChild("MonsterBody")
						if body then
							register(m, body)
						end
					end
				end
			end
		end
		-- PvP arena fighters
		local arenas = workspace:FindFirstChild("PvpArenas")
		if arenas then
			for _, arena in ipairs(arenas:GetChildren()) do
				local fighters = arena:FindFirstChild("Fighters")
				if fighters then
					for _, m in ipairs(fighters:GetChildren()) do
						local body = m:FindFirstChild("MonsterBody")
						if body then
							register(m, body)
						end
					end
				end
			end
		end
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			for _, m in ipairs(enemies:GetChildren()) do
				local root = m:FindFirstChild("Root")
				if root then
					register(m, root)
				end
			end
		end
		task.wait(1)
	end
end)

-- Sculpted (mesh) monsters: their pieces were cut from one model, so if a
-- piece turned on its own the cut edges would open up and the body would
-- look broken. They move as ONE solid body (hover, bob, lean, lunge, fall);
-- only pieces that float apart anyway (halo, orbiting planets) move alone.
local MESH_FREE = { body = 0.8, halo = 1, orbit = 1 }
local function set(st, name, cf)
	local m = st.motors[name]
	if m then
		if st.mesh then
			local amount = MESH_FREE[name]
			m.Transform = amount and CFrame.identity:Lerp(cf, amount) or CFrame.identity
		else
			m.Transform = cf
		end
	end
end

-- smooth blend toward a target pose, so state changes never snap
local function blend(st, name, target, alpha)
	st.cur = st.cur or {}
	local cur = (st.cur[name] or CFrame.identity):Lerp(target, alpha)
	st.cur[name] = cur
	set(st, name, cur)
end

local function doFlash(st, now)
	local hit = now - st.hitAt < 0.12
	if hit ~= st.flashing then
		st.flashing = hit
		-- mesh monsters: a quick white highlight
		local hl = st.model:FindFirstChild("HitFlash")
		if hit and not hl and st.root:GetAttribute("SkinSet") == "MonsterMesh" then
			hl = Instance.new("Highlight")
			hl.Name = "HitFlash"
			hl.FillColor = WHITE
			hl.FillTransparency = 0.45
			hl.OutlineTransparency = 1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = st.model
		end
		if hl then
			hl.Enabled = hit
		end
		for _, pc in ipairs(st.parts) do
			local p = pc[1]
			if p.Parent then
				if pc[3] ~= nil then
					-- merged (union) pieces: flash as one color, then back to their own colors
					p.UsePartColor = hit or pc[3]
					p.Color = hit and pc[4]:Lerp(WHITE, 0.6) or pc[2]
				else
					p.Color = hit and pc[2]:Lerp(WHITE, 0.6) or pc[2]
				end
			end
		end
	end
end

-- blinking (any monster with "EyeOpen" / "EyeClosed" parts); eyes shut when dead
local function doBlink(st, now, dead)
	if #st.eyesClosed == 0 then
		return
	end
	st.nextBlink = st.nextBlink or (now + 1 + math.random() * 3)
	if now > st.nextBlink then
		st.blinkAt = now
		st.nextBlink = now + 2.5 + math.random() * 3
	end
	local closed = dead or (st.blinkAt ~= nil and now - st.blinkAt < 0.13)
	if closed ~= st.eyesShut then
		st.eyesShut = closed
		for _, p in ipairs(st.eyesOpen) do
			p.LocalTransparencyModifier = closed and 1 or 0
		end
		for _, p in ipairs(st.eyesClosed) do
			p.LocalTransparencyModifier = closed and 0 or 1
		end
	end
end

local ANIMS = {}

-- Moss Slime (monster): heavy bubbling breathing + glaring, a slow wet lurch
-- (squash with bulging lobes, heave, slap, jelly wobble), fast surging leaps
-- when running, rears up and crashes down to engulf (acid burst), melts
-- into a sizzling puddle when dead. The jaw grinds, gapes and slams.
ANIMS.slime = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 10, 0, 1)
	local fast = math.clamp(dt * 24, 0, 1)
	local hopFreq = ({ walk = 1.5, run = 2.6 })[state]
	local k = 0 -- layer spacing: negative = squash, positive = stretch
	local y, pitch, yaw = 0, 0, 0
	local jaw = 0

	if state == "dead" then
		k, y, jaw = -0.95, -0.06 * s, R(-20)
	elseif state == "fight" then
		local p = math.clamp((now - st.attackAt) / 0.4, 0, 1)
		if p < 0.45 then
			local r = p / 0.45 -- rear up tall, jaws wide
			k, pitch, y, jaw = 0.7 * r, R(14) * r, 0.1 * s * r, R(-38) * r
		else
			local r = (p - 0.45) / 0.55 -- crash down onto the target
			k = 0.7 - 1.6 * math.sin(r * math.pi * 0.5)
			pitch, y, jaw = R(14) - R(40) * r, 0.1 * s * (1 - r), R(-38) * (1 - r)
		end
		if p > 0.75 and st.burstFor ~= st.attackAt then
			st.burstFor = st.attackAt
			st.landAt = now
			local fx = st.root:FindFirstChild("MonsterSparkles")
			if fx then
				fx:Emit(24)
			end
		end
	elseif state == "jump" then
		k, jaw = 0.55, R(-25)
	elseif state == "fall" then
		k = -0.4
	elseif hopFreq then
		st.hopP = (st.hopP or 0) + dt * hopFreq * math.pi * 2
		local p = st.hopP
		local sinP = math.sin(p)
		local wasAir = st.inAir
		st.inAir = sinP > 0.15
		if wasAir and not st.inAir then
			st.landAt = now -- wet slap: start the wobble
		end
		local height = state == "run" and 0.55 or 0.22
		if sinP > 0 then
			y = sinP * height * s
			k = (state == "run" and 0.5 or 0.32) * math.cos(p) -- stretched on takeoff
		else
			k = -0.6 * math.abs(sinP) -- heavy squash on the ground
		end
		pitch = state == "run" and R(-16) or R(-7)
		jaw = state == "run" and R(-22) or R(-6) * math.max(0, math.cos(p))
	else
		st.hopP = 0
		k = math.sin(t * 1.5) * 0.08 + math.sin(t * 3.7) * 0.015 -- heavy bubbling breaths
		yaw = math.sin(t * 0.35) * R(22) -- glaring around
		jaw = -R(12) * math.max(0, math.sin(t * 0.55)) ^ 2 -- slowly grinding open + shut
	end
	-- jelly wobble after landing / crashing
	if st.landAt then
		local since = now - st.landAt
		k += math.sin(since * 20) * 0.2 * math.exp(-since * 5)
	end

	blend(st, "body", CF(0, y, 0) * A(pitch, yaw, 0), state == "fight" and fast or math.clamp(dt * 16, 0, 1))
	local spacing = 0.12 * s
	for i = 1, 7 do
		blend(st, "sl" .. i, CF(0, (i - 1) * k * spacing / 1.6, 0), math.clamp(dt * 26, 0, 1))
	end
	-- base lobes bulge out when squashed
	local bulge = math.max(0, -k) * 0.2 * s + math.max(0, math.sin(t * 1.5)) * 0.01 * s
	blend(st, "lobeF", CF(0, 0, -bulge), fast)
	blend(st, "lobeB", CF(0, 0, bulge), fast)
	blend(st, "lobeL", CF(-bulge, 0, 0), fast)
	blend(st, "lobeR", CF(bulge, 0, 0), fast)
	blend(st, "jaw", A(jaw, 0, 0), fast)
	-- thorny crown sways, flicks when it moves
	local sway = hopFreq and math.sin((st.hopP or 0) * 1) * R(10) or math.sin(t * 1.3) * R(5)
	blend(st, "sprout", state == "dead" and A(0, 0, R(50)) or A(math.sin(t * 1.1) * R(4), 0, sway), smooth)
end

-- Cave Bat: real wingbeats (tips follow the shoulder and fold on the
-- upstroke), body rises with each downstroke, ear twitches, biting dive.
ANIMS.bat = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 10, 0, 1)
	local quick = math.clamp(dt * 28, 0, 1)
	local freq = ({ idle = 5.5, walk = 7.5, run = 9.5, fight = 11, jump = 10, fall = 2.5, dead = 0 })[state]
	st.flapP = (st.flapP or 0) + dt * freq
	local p = st.flapP

	-- wing angles ("up" is positive)
	local up, tipUp
	if state == "dead" then
		up, tipUp = R(-60), R(-100) -- folded in
	elseif state == "fall" then
		up, tipUp = R(55) + math.sin(p) * R(8), R(25) -- spread up, catching air
	elseif state == "fight" then
		up = R(12) + math.sin(p) * R(50) * (1 - fightK) + R(50) * fightK -- swept back for the dive
		tipUp = R(-10) + math.sin(p - 1.1) * R(35) * (1 - fightK) - R(35) * fightK
	else
		local amp = state == "idle" and R(40) or R(52)
		up = R(12) + math.sin(p) * amp
		tipUp = R(-12) + math.sin(p - 1.1) * R(38) -- lags behind: folds on the upstroke
	end
	blend(st, "wingL", A(0, math.cos(p) * R(6), -up), quick)
	blend(st, "wingR", A(0, -math.cos(p) * R(6), up), quick)
	blend(st, "wingLTip", A(0, 0, -tipUp), quick)
	blend(st, "wingRTip", A(0, 0, tipUp), quick)

	-- body: hover, rise on each downstroke, lean into flight, dive, drop
	local bodyCF
	if state == "dead" then
		bodyCF = CF(0, -0.8 * s, 0) * A(0, 0, R(75))
	elseif state == "fight" then
		bodyCF = CF(0, -0.15 * s * fightK, -0.45 * s * fightK) * A(R(-28) * fightK, 0, 0)
	else
		local lean = math.clamp(speed / 15, 0, 1) * R(-14)
		local hover = math.sin(t * 1.6) * 0.08 * s
		local beat = -math.sin(p) * 0.05 * s
		local pitch = state == "fall" and R(-8) or (math.cos(p) * R(4) + lean)
		bodyCF = CF(0, hover + beat, 0) * A(pitch, 0, 0)
	end
	blend(st, "body", bodyCF, state == "fight" and quick or smooth)

	-- head: steady against the beats, looks around, bites when fighting
	local headCF
	if state == "dead" then
		headCF = A(R(25), 0, R(10))
	elseif state == "fight" then
		headCF = A(R(-15) * fightK, 0, 0)
	else
		headCF = A(-math.cos(p) * R(4) + math.sin(t * 0.9) * R(4), math.sin(t * 0.6) * R(16), math.sin(t * 0.8) * R(6))
	end
	blend(st, "head", headCF, smooth)
	blend(st, "jaw", A(-R(30) * fightK, 0, 0), quick)

	-- ears: flop a little with the beats + a quick twitch now and then
	st.nextTwitch = st.nextTwitch or (now + math.random() * 3)
	if now > st.nextTwitch then
		st.twitchAt, st.twitchSide = now, math.random(1, 2)
		st.nextTwitch = now + 1.5 + math.random() * 3
	end
	local twitching = st.twitchAt and now - st.twitchAt < 0.18
	local flop = state == "dead" and R(-40) or math.sin(p - 0.5) * R(6)
	blend(st, "earL", A(flop + ((twitching and st.twitchSide == 1) and R(-25) or 0), 0, 0), quick)
	blend(st, "earR", A(flop + ((twitching and st.twitchSide == 2) and R(-25) or 0), 0, 0), quick)
end

-- Glowcap: side-to-side waddle, springy cap that lags behind the body,
-- cap-headbutt with a spore burst, parachute cap when falling, topples when dead.
ANIMS.mushroom = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 10, 0, 1)
	local lag = math.clamp(dt * 6, 0, 1) -- the cap follows late (springy)
	local freq = ({ walk = 7, run = 11 })[state]
	local roll, pitch, y = 0, 0, 0
	local step = 0

	if state == "dead" then
		roll, y = R(85), -0.15 * s
	elseif state == "fight" then
		-- lean back, then headbutt forward with the cap
		pitch = fightK < 0.5 and R(18) * fightK * 2 or R(-40) * fightK
	elseif state == "fall" then
		pitch = R(-6)
	elseif state == "jump" then
		y = -0.05 * s
	elseif freq then
		st.walkP = (st.walkP or 0) + dt * freq
		local p = st.walkP
		roll = math.sin(p) * R(state == "run" and 12 or 9) -- waddle
		y = math.abs(math.sin(p)) * 0.06 * s
		pitch = state == "run" and R(-12) or R(-4)
		step = math.sin(p)
	else
		roll = math.sin(t * 1.4) * R(4) -- gentle sway
		y = math.sin(t * 2.2) * 0.015 * s
	end
	blend(st, "body", CF(0, y, 0) * A(pitch, 0, roll), state == "fight" and math.clamp(dt * 25, 0, 1) or smooth)

	-- feet step with the waddle
	blend(st, "legL", A(step * R(30), 0, 0), smooth)
	blend(st, "legR", A(-step * R(30), 0, 0), smooth)

	-- little arms swing (up when falling / fighting)
	local armSwing = freq and step * R(35) or math.sin(t * 1.4) * R(10)
	if state == "fall" then
		blend(st, "armL", A(0, 0, R(-70)), smooth)
		blend(st, "armR", A(0, 0, R(70)), smooth)
	elseif state == "fight" then
		blend(st, "armL", A(R(-60) * fightK, 0, R(-20)), smooth)
		blend(st, "armR", A(R(-60) * fightK, 0, R(20)), smooth)
	else
		blend(st, "armL", A(-armSwing, 0, R(-8)), smooth)
		blend(st, "armR", A(armSwing, 0, R(8)), smooth)
	end

	-- springy cap: lags behind the body's tilt; flares up like a parachute when falling
	local capCF
	if state == "dead" then
		capCF = A(0, 0, R(-15))
	elseif state == "fall" then
		capCF = CF(0, 0.08 * s, 0) * A(R(10), 0, 0)
	elseif state == "fight" then
		capCF = A(R(-20) * fightK, 0, 0)
	else
		capCF = A(-pitch * 0.6 + math.sin(t * 2.6) * R(3), 0, -roll * 0.8) * CF(0, math.sin(t * 2.2 + 1) * 0.01 * s, 0)
	end
	blend(st, "cap", capCF, lag)

	-- spore burst when the headbutt lands
	if state == "fight" and fightK > 0.8 and st.burstFor ~= st.attackAt then
		st.burstFor = st.attackAt
		local spores = st.root:FindFirstChild("MonsterSparkles")
		if spores then
			spores:Emit(14)
		end
	end
end

-- Ironclaw Crab (menacing): claws held up in a guard, mandibles click, eyes
-- scan, heavy sideways scuttle, raises both claws then SLAMS + snaps, flips when dead.
ANIMS.crab = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 10, 0, 1)
	local quick = math.clamp(dt * 25, 0, 1)
	local moving = state == "walk" or state == "run"
	local freq = state == "run" and 14 or 9
	if moving then
		st.legP = (st.legP or 0) + dt * freq
	end
	local p = st.legP or 0

	-- body: turn sideways to scuttle, rear up to fight, flip when dead
	local bodyCF
	if state == "dead" then
		bodyCF = CF(0, 0.35 * s, 0) * A(0, 0, math.pi) -- on its back
	elseif state == "fight" then
		bodyCF = CF(0, 0.12 * s * fightK, -0.3 * s * fightK) * A(R(18) * fightK, 0, 0)
	elseif moving then
		bodyCF = CF(0, math.abs(math.sin(p * 2)) * 0.03 * s, 0) * A(0, R(80), math.sin(p) * R(4))
	elseif state == "jump" then
		bodyCF = CF(0, 0.05 * s, 0)
	else
		bodyCF = CF(0, math.sin(t * 2) * 0.012 * s, 0)
	end
	blend(st, "body", bodyCF, state == "fight" and quick or smooth)

	-- legs: ripple in a wave when walking, twitch when dead, tuck/splay in the air
	for side, sign in pairs({ L = -1, R = 1 }) do
		for i = 1, 3 do
			local cf
			if state == "dead" then
				cf = A(math.sin(t * 14 + i) * R(15), 0, 0)
			elseif state == "jump" then
				cf = A(0, 0, R(sign * -25))
			elseif state == "fall" then
				cf = A(0, 0, R(sign * 20))
			elseif moving then
				local ph = p + i * 2.1 + (sign > 0 and math.pi or 0)
				local lift = math.max(0, math.sin(ph))
				cf = A(math.cos(ph) * R(22), 0, R(sign * -22) * lift)
			else
				-- an occasional shuffle
				local shuffle = math.max(0, math.sin(t * 0.9 + i * 1.3 + sign)) ^ 8
				cf = A(0, 0, R(sign * -14) * shuffle)
			end
			blend(st, "leg" .. side .. i, cf, quick)
		end
	end

	-- claws: raised when moving/fighting; pincers open + close, snap in fights
	local clawUp
	if state == "fight" then
		local k = math.clamp((now - st.attackAt) / 0.4, 0, 1)
		clawUp = k < 0.55 and R(-70) * (k / 0.55) or R(-70) + R(85) * ((k - 0.55) / 0.45) -- raise high, then slam down
	elseif state == "dead" then
		clawUp = R(20)
	else
		clawUp = R(-22) + math.sin(t * 1.3) * R(4) -- held up in a guard
	end
	blend(st, "clawL", A(clawUp, R(-8), 0), smooth)
	blend(st, "clawR", A(clawUp, R(8), 0), smooth)
	local open
	if state == "fight" then
		open = math.abs(math.sin(t * 22)) * R(35)
	elseif state == "dead" then
		open = R(30)
	else
		open = (math.sin(t * 1.6) * 0.5 + 0.5) * R(18)
	end
	blend(st, "pinchL", A(open, 0, 0), quick)
	blend(st, "pinchR", A(open, 0, 0), quick)

	-- eye stalks look around on their own (curious)
	for name, off in pairs({ eyeL = 0, eyeR = 2.4 }) do
		local look
		if state == "dead" then
			look = A(R(30), 0, R(off > 0 and 25 or -25))
		elseif state == "fight" then
			look = A(R(-10), 0, 0)
		else
			look = A(math.sin(t * 0.5 + off) * R(5), math.sin(t * 0.35 + off) * R(18), 0) -- slow scanning
		end
		blend(st, name, look, smooth)
	end

	-- mandibles: click now and then, gape when attacking
	local jaw
	if state == "fight" then
		jaw = A(R(28) * fightK, 0, 0)
	elseif state == "dead" then
		jaw = A(R(20), 0, 0)
	else
		jaw = A(R(12) * math.max(0, math.sin(t * 7)) ^ 4 * math.max(0, math.sin(t * 0.7)), 0, 0)
	end
	blend(st, "jaw", jaw, quick)
end

-- Frostfang Wolf (new model): a heavy ice predator.
-- Idle = breathes slowly (mane crystals rise and fall), sniffs the air,
--   scans left and right, tail sways low; now and then it throws its head
--   back and HOWLS (jaw wide, ears back, frost burst).
-- Walk = a low, stalking prowl: head down and level, shoulders rolling,
--   diagonal legs together, tail held out and swaying.
-- Run = a bounding gallop: the spine flexes (front up, back down), front
--   pair then hind pair, ears pinned, jaw panting, tail streaming.
-- Jump = pounce stretch; fall = legs reach down; dead = collapses on its
--   side, legs stiff, head down. Attack = Frost Bite (ATTACKS.wolf).
local FROST_WALK = { fl = 0, hr = 0.02, fr = 0.5, hl = 0.52 }
local FROST_RUN = { fl = 0, fr = 0.1, hl = 0.5, hr = 0.6 }
ANIMS.wolf = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 7, 0, 1)
	local quick = math.clamp(dt * 16, 0, 1)
	local moving = state == "walk" or state == "run"
	local run = state == "run"
	if moving then
		st.gaitP = (st.gaitP or 0) + dt * (run and 2.3 or 1.25) * math.pi * 2
	end
	local p = st.gaitP or 0

	-- howl now and then while idle
	st.nextHowl = st.nextHowl or (now + 6 + math.random() * 6)
	if state == "idle" and now > st.nextHowl then
		st.howlAt = now
		st.nextHowl = now + 12 + math.random() * 10
	end
	local howl = st.howlAt and math.max(0, math.sin(math.clamp((now - st.howlAt) / 2.6, 0, 1) * math.pi)) or 0
	if state ~= "idle" then
		howl = 0
	end
	local breath = math.sin(t * 1.6)
	local sniff = state == "idle" and math.max(0, math.sin(t * 0.7)) ^ 8 or 0

	local body, head, jaw, earBack, tailUp, tailSway
	local legs = {}
	if state == "dead" then
		body = CF(0, -0.3 * s, 0) * A(R(-4), 0, R(84))
		head, jaw = A(R(-20), R(-10), 0), R(-18)
		earBack, tailUp, tailSway = R(-40), R(-25), R(10)
		for leg in pairs(FROST_WALK) do
			local hind = leg:sub(1, 1) == "h"
			legs[leg] = { A(hind and R(-30) or R(35), 0, 0), A(hind and R(10) or R(-10), 0, 0) }
		end
	elseif state == "jump" then
		body = CF(0, 0.05 * s, 0) * A(R(12), 0, 0)
		head, jaw = A(R(10), 0, 0), R(-20)
		earBack, tailUp, tailSway = R(-50), R(10), 0
		legs.fl, legs.fr = { A(R(55), 0, 0), A(R(-30), 0, 0) }, { A(R(55), 0, 0), A(R(-30), 0, 0) }
		legs.hl, legs.hr = { A(R(-45), 0, 0), A(R(30), 0, 0) }, { A(R(-45), 0, 0), A(R(30), 0, 0) }
	elseif state == "fall" then
		body = A(R(-10), 0, 0)
		head, jaw = A(R(-8), 0, 0), R(-8)
		earBack, tailUp, tailSway = R(-30), R(15), math.sin(t * 3) * R(8)
		legs.fl, legs.fr = { A(R(30), 0, 0), A(R(-8), 0, 0) }, { A(R(30), 0, 0), A(R(-8), 0, 0) }
		legs.hl, legs.hr = { A(R(20), 0, 0), A(R(-5), 0, 0) }, { A(R(20), 0, 0), A(R(-5), 0, 0) }
	elseif moving then
		local phases = run and FROST_RUN or FROST_WALK
		local amp = run and R(40) or R(22)
		for leg, off in pairs(phases) do
			local hind = leg:sub(1, 1) == "h"
			local ph = p + off * math.pi * 2
			local lift = math.max(0, math.cos(ph))
			legs[leg] = { A(math.sin(ph) * amp, 0, 0), A((hind and R(34) or R(-44)) * lift, 0, 0) }
		end
		if run then
			-- gallop: the spine flexes, front and back rise in turn
			body = CF(0, math.abs(math.sin(p)) * 0.07 * s, 0) * A(math.sin(p) * R(8) - R(3), 0, 0)
			head = A(R(-6) - math.sin(p) * R(6), 0, 0)
			jaw = -R(12) - math.max(0, math.sin(p * 2)) * R(6) -- panting
			earBack, tailUp, tailSway = R(-55), R(-6) + math.sin(p) * R(6), math.sin(p * 0.5) * R(10)
		else
			-- stalking prowl: low, shoulders rolling, head level and forward
			body = CF(0, -0.03 * s + math.abs(math.sin(p)) * 0.015 * s, 0) * A(R(2), math.sin(p) * R(3), math.sin(p) * R(4))
			head = A(R(-10) + math.sin(p * 2) * R(2), -math.sin(p) * R(4), 0)
			jaw = 0
			earBack, tailUp, tailSway = R(-10), R(-8), math.sin(p) * R(14)
		end
	else -- idle / fight: stands and breathes, sniffs, scans, howls
		body = CF(0, breath * 0.012 * s, 0) * A(breath * R(1.2) + R(8) * howl, 0, 0)
		head = A(R(4) * sniff + R(40) * howl + math.sin(t * 0.8) * R(3), math.sin(t * 0.4) * R(26) * (1 - howl), math.sin(t * 0.6) * R(4) * (1 - howl))
		jaw = -R(8) * sniff - R(34) * howl - R(3) * math.max(0, breath)
		earBack = R(-40) * howl + math.max(0, math.sin(t * 0.9)) ^ 12 * R(-18)
		tailUp, tailSway = R(-6) + R(10) * howl, math.sin(t * 1.1) * R(12)
		for leg in pairs(FROST_WALK) do
			local hind = leg:sub(1, 1) == "h"
			legs[leg] = { A(hind and R(-6) * howl or R(5) * howl, 0, 0), CFrame.identity }
		end
		if state == "fight" then
			head, jaw = A(R(-12), 0, 0), -R(20) -- snarling
			earBack = R(-50)
		end
	end

	blend(st, "body", body, state == "fight" and quick or smooth)
	blend(st, "head", head, smooth)
	blend(st, "jaw", A(jaw, 0, 0), quick)
	blend(st, "earL", A(earBack, 0, R(-6) * math.abs(earBack) / R(55)), quick)
	blend(st, "earR", A(earBack, 0, R(6) * math.abs(earBack) / R(55)), quick)
	for leg in pairs(FROST_WALK) do
		local Lg = legs[leg] or { CFrame.identity, CFrame.identity }
		blend(st, leg, Lg[1], quick)
		blend(st, leg .. "Low", Lg[2], quick)
	end
	-- tail: sways side to side, the end follows a moment later
	-- tail: a FREE tail. Its model curves up, so at rest it's lowered
	-- (positive X = down) to hang out behind, then it wags widely up/down
	-- and left/right; the end follows a moment later like a whip
	local wt = moving and p or t * (state == "fight" and 3 or 1.4)
	local wagAmp = (state == "dead") and 0 or (run and 0.7 or 1)
	local rest = state == "dead" and R(40) or (run and R(22) or R(32)) -- how far it hangs down
	local upDown = math.sin(wt * 2) * R(24) * wagAmp
	local leftRight = math.sin(wt) * R(34) * wagAmp
	blend(st, "tail", A(rest - tailUp * 0.5 + upDown, tailSway + leftRight, 0), smooth)
	blend(st, "tail2", A(R(18) + math.sin(wt * 2 - 1) * R(26) * wagAmp, tailSway * 1.2 + math.sin(wt - 0.9) * R(40) * wagAmp, 0), math.clamp(dt * 6, 0, 1))
	-- howl: burst of frost
	if howl > 0.9 and st.howlFx ~= st.howlAt then
		st.howlFx = st.howlAt
		local fx = st.root:FindFirstChild("MonsterSparkles")
		if fx then
			fx:Emit(30)
		end
	end
end
-- Stone Golem: heavy breathing + pulsing core, lumbering stomp with body sway
-- and dust on every footfall, double-fist overhead smash with a roar,
-- crumbles forward when dead (core fades).
local GOLEM_RUNE = Color3.fromRGB(90, 232, 212)
ANIMS.golem = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local heavy = math.clamp(dt * 6, 0, 1) -- everything moves with weight
	local firm = math.clamp(dt * 14, 0, 1)
	local moving = state == "walk" or state == "run"
	local run = state == "run"
	if moving then
		local before = st.stepP or 0
		st.stepP = before + dt * (run and 1.5 or 0.95) * math.pi * 2
		-- dust puff on each footfall
		if math.floor(st.stepP / math.pi) ~= math.floor(before / math.pi) then
			local dust = st.root:FindFirstChild("MonsterSparkles")
			if dust then
				dust:Emit(6)
			end
		end
	end
	local p = st.stepP or 0

	-- the core pulses like a heartbeat (fades when dead)
	st.core = st.core or (function()
		for _, pc in ipairs(st.parts) do
			if pc[1].Name == "GolemCore" then
				st.coreBase = pc[2]
				return pc[1]
			end
		end
		return false
	end)()
	if st.core then
		local beat = state == "dead" and 0 or (math.sin(t * (moving and 3 or 1.8)) * 0.5 + 0.5)
		st.core.Color = state == "dead" and Color3.fromRGB(40, 60, 58) or (st.coreBase or GOLEM_RUNE):Lerp(Color3.new(1, 1, 1), beat * 0.45)
	end

	-- the attack: raise both fists overhead, then smash down
	local k = math.clamp((now - st.attackAt) / 0.4, 0, 1)
	local raise = state == "fight" and (k < 0.5 and k / 0.5 or 1 - (k - 0.5) / 0.5) or 0
	local smash = state == "fight" and k >= 0.5 and math.sin((k - 0.5) / 0.5 * math.pi) or 0
	if state == "fight" and k > 0.75 and st.burstFor ~= st.attackAt then
		st.burstFor = st.attackAt
		local dust = st.root:FindFirstChild("MonsterSparkles")
		if dust then
			dust:Emit(18)
		end
	end

	-- body: sway + dip with each heavy step, lean back to raise, forward to smash
	local bodyCF
	if state == "dead" then
		bodyCF = CF(0, -0.55 * s, -0.4 * s) * A(R(-80), 0, 0) -- crumbles forward
	elseif state == "fight" then
		bodyCF = CF(0, -0.08 * s * smash, -0.15 * s * smash) * A(R(10) * raise - R(22) * smash, 0, 0)
	elseif state == "jump" then
		bodyCF = CF(0, -0.12 * s, 0) * A(R(-10), 0, 0)
	elseif moving then
		local dip = -math.abs(math.sin(p)) * 0.05 * s
		bodyCF = CF(0, dip, 0) * A(run and R(-12) or R(-5), math.sin(p) * R(4), math.sin(p) * R(6))
	else
		bodyCF = CF(0, math.sin(t * 1.1) * 0.02 * s, 0) * A(math.sin(t * 1.1) * R(1.5), 0, 0) -- slow heavy breathing
	end
	blend(st, "body", bodyCF, state == "fight" and firm or heavy)

	-- head + jaw (roars during the attack)
	local headCF = state == "dead" and A(R(30), 0, 0)
		or state == "fight" and A(R(-15) * raise + R(10) * smash, 0, 0)
		or A(math.sin(t * 0.4) * R(3), math.sin(t * 0.3) * R(18), 0)
	blend(st, "head", headCF, heavy)
	blend(st, "jaw", A(R(30) * math.max(raise, smash * 0.6), 0, 0), firm)

	-- legs: big heavy steps (knee bends as the foot lifts)
	local amp = run and R(34) or R(22)
	for name, off in pairs({ legL = 0, legR = math.pi }) do
		local up, low
		if state == "dead" then
			up, low = A(R(40), 0, 0), A(R(-30), 0, 0)
		elseif state == "jump" then
			up, low = A(R(30), 0, 0), A(R(-50), 0, 0)
		elseif state == "fight" then
			up, low = A(R(12) * smash, 0, 0), A(R(-18) * smash, 0, 0)
		elseif moving then
			local ph = p + off
			up = A(math.sin(ph) * amp, 0, 0)
			low = A(-R(35) * math.max(0, math.cos(ph)), 0, 0)
		else
			up, low = CFrame.identity, CFrame.identity
		end
		blend(st, name, up, firm)
		blend(st, name .. "Low", low, firm)
	end

	-- arms: swing opposite the legs; overhead raise + smash in the attack
	for name, off in pairs({ armL = math.pi, armR = 0 }) do
		local sign = name == "armL" and -1 or 1
		local up, low
		if state == "dead" then
			up, low = A(R(150), 0, sign * R(10)), A(R(20), 0, 0)
		elseif state == "fight" then
			up = A(R(170) * raise + R(40) * smash, 0, sign * R(-12) * raise)
			low = A(R(30) * raise, 0, 0)
		elseif state == "fall" then
			up, low = A(R(40), 0, sign * R(50)), CFrame.identity
		elseif moving then
			local ph = p + off
			up = A(math.sin(ph) * (run and R(30) or R(18)), 0, 0)
			low = A(R(12) + math.max(0, math.sin(ph)) * R(15), 0, 0)
		else
			up = A(math.sin(t * 1.1) * R(2), 0, sign * math.sin(t * 0.7) * R(2))
			low = A(R(6), 0, 0)
		end
		blend(st, name, up, state == "fight" and firm or heavy)
		blend(st, name .. "Low", low, heavy)
	end
end

-- Winged monsters (Phoenix, Void Dragon, Star Seraph): the bat's wingbeats +
-- a second wing pair, a swaying tail, dangling legs, a spinning halo, spear thrust.
ANIMS.flyer = function(st, state, t, dt, now, fightK, speed)
	ANIMS.bat(st, state, t, dt, now, fightK, speed)
	local smooth = math.clamp(dt * 8, 0, 1)
	local p = st.flapP or 0
	local up2 = state == "dead" and R(-50) or (R(5) + math.sin(p - 0.6) * R(35))
	blend(st, "wing2L", A(0, 0, -up2), math.clamp(dt * 25, 0, 1))
	blend(st, "wing2R", A(0, 0, up2), math.clamp(dt * 25, 0, 1))
	local tailUp = state == "dead" and R(-20) or (state == "fight" and R(-10) or math.sin(t * 1.5) * R(6))
	local sway = state == "dead" and 0 or math.sin(t * 2.2) * R(14)
	blend(st, "tail", A(tailUp, sway, 0), smooth)
	blend(st, "tail2", A(tailUp * 0.8, sway * 1.3, 0), math.clamp(dt * 5, 0, 1))
	local leg = state == "fight" and R(-35) * fightK or (math.sin(t * 1.6) * R(8) + (speed > 2 and R(20) or 0))
	blend(st, "legL", A(leg, 0, 0), smooth)
	blend(st, "legR", A(leg * 0.9, 0, 0), smooth)
	set(st, "halo", CF(0, math.sin(t * 2) * 0.02 * st.s, 0) * A(0, (t * 1.2) % (math.pi * 2), 0))
	blend(st, "armR", A(state == "fight" and R(70) * fightK or math.sin(t * 1.2) * R(5), 0, 0), smooth)
	blend(st, "armL", A(math.sin(t * 1.2 + 1) * R(5), 0, 0), smooth)
end
-- Ember Phoenix (new model): a real bird wingbeat. Each wing is first
-- ROLLED around its arm so the feathers lie flat like a flying bird's
-- (not a flat fan facing you), then beats: a fast, powerful DOWNSTROKE
-- with the wing reaching forward and fully spread, then a slower
-- UPSTROKE where the outer wing folds in at the wrist and sweeps back.
-- The body lifts after each downstroke, the tail fans and steers, the
-- crest ruffles. Idle = hovers upright, beating; walk = glides forward
-- leaning in; run = streamlined dive with fast beats; jump = one huge
-- downstroke; fall = wings held open in a glide; dead = wings crumple,
-- falls onto its side. Attack = Blaze Dive (ATTACKS.phoenix).
local PHX_ARM = Vector3.new(12.4, 11.6, 0.9).Unit
local PHX_HINGE = Vector3.new(0.8, -0.6, 0).Unit
local PHX_FOLD_SIGN = -1
local function phoenixWings(st, raise, roll, sweep, bend, alpha)
	for _, s in ipairs({ -1, 1 }) do
		local n = s < 0 and "L" or "R"
		local arm = Vector3.new(PHX_ARM.X * s, PHX_ARM.Y, PHX_ARM.Z)
		local h = Vector3.new(PHX_HINGE.X * s, PHX_HINGE.Y, PHX_HINGE.Z)
		local T = A(0, 0, s * raise) * A(0, s * sweep, 0) * CFrame.fromAxisAngle(arm, -s * roll)
		-- 2nd joint (wrist): the outer wing folds on a hinge that lies
		-- ACROSS the wing at the wrist, in the wing's own surface, so the
		-- inner and outer feathers stay touching along that line
		local chord = Vector3.new(-arm.Y, arm.X, 0).Unit
		local B = CFrame.fromAxisAngle(chord, PHX_FOLD_SIGN * bend)
		if alpha then
			blend(st, "wing" .. n, T, alpha)
			blend(st, "wing" .. n .. "Tip", B, alpha)
		else
			set(st, "wing" .. n, T)
			set(st, "wing" .. n .. "Tip", B)
		end
	end
end
local function birdBeat(u)
	u = u % 1
	if u < 0.4 then
		return math.cos(u / 0.4 * math.pi) -- downstroke (fast): +1 up -> -1 down
	end
	return -math.cos((u - 0.4) / 0.6 * math.pi) -- upstroke (slower)
end
ANIMS.phoenix = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 6, 0, 1)
	local wingA = math.clamp(dt * 20, 0, 1)
	local rate = ({ idle = 0.7, walk = 0.85, run = 1.15, fight = 1.0, jump = 1.0, fall = 0, dead = 0 })[state] or 0.8
	st.phxU = ((st.phxU or 0) + dt * rate) % 1
	local u = st.phxU
	local beat = birdBeat(u) -- +1 wings high, -1 wings low
	local lag = birdBeat(u - 0.1)
	local down = u < 0.4 -- in the downstroke
	local lift = -birdBeat(u - 0.15)

	local body, head, jaw, tail, tail2, leg
	local raise, roll, sweep, bend
	if state == "dead" then
		body = CF(0, -0.55 * s, 0) * A(R(-15), R(10), R(80))
		head, jaw = A(R(-35), R(20), 0), R(-25)
		raise, roll, sweep, bend = R(-45), R(40), R(-15), R(-30)
		tail, tail2 = A(R(15), R(10), 0), A(R(10), 0, 0)
		leg = A(R(-30), 0, 0)
	elseif state == "jump" then
		body = CF(0, 0.12 * s, 0) * A(R(-10), 0, 0)
		head, jaw = A(R(8), 0, 0), R(-12)
		raise, roll, sweep, bend = R(-60), R(70), R(10), R(-30)
		tail, tail2 = A(R(15), 0, 0), A(R(10), 0, 0)
		leg = A(R(25), 0, 0)
	elseif state == "fall" then
		body = A(R(-10), 0, math.sin(t * 1.4) * R(4))
		head, jaw = A(R(10), 0, 0), 0
		raise, roll, sweep, bend = R(-12), R(80), R(-4), R(-12)
		tail, tail2 = A(R(-10), math.sin(t * 2) * R(8), 0), A(R(-8), math.sin(t * 2 - 1) * R(10), 0)
		leg = A(R(25), 0, 0)
	elseif state == "walk" or state == "run" then
		local run = state == "run"
		local pitch = run and R(-55) or R(-28)
		body = CF(0, lift * 0.06 * s + 0.05 * s, 0) * A(pitch + lift * R(4), 0, math.sin(t * 1.2) * R(run and 5 or 3))
		head = A(-pitch * 0.8 + math.sin(u * math.pi * 2) * R(3), math.sin(t * 0.8) * R(8), 0)
		jaw = run and R(-10) or 0
		-- same stroke as the Void Dragon: wing laid flat, beats up/down
		raise = R(-18) + beat * (run and R(40) or R(34))
		roll = R(78)
		sweep = (run and R(-10) or R(-4)) - beat * R(8)
		-- outer wing always droops, folding down most on the upstroke
		bend = -R(8) - R(24) * (1 - lag) / 2 - (down and 0 or R(22) * math.abs(beat))
		tail = A(R(run and -30 or -18), math.sin(t * 2.5) * R(8), 0)
		tail2 = A(R(run and -18 or -10) + math.sin(u * math.pi * 2 - 1.5) * R(8), math.sin(t * 2.5 - 1) * R(12), 0)
		leg = A(R(run and -70 or -50), 0, 0)
	else -- idle / fight: upright hover
		body = CF(0, lift * 0.08 * s, 0) * A(R(-6) + lift * R(4), math.sin(t * 0.5) * R(8), math.sin(t * 0.7) * R(3))
		if state == "idle" then
			head = A(math.sin(t * 0.9) * R(6), math.sin(t * 0.45) * R(28), math.sin(t * 0.6) * R(6))
		else
			head = A(R(-8), 0, 0)
		end
		jaw = (state == "idle" and -R(22) * math.max(0, math.sin(t * 0.35)) ^ 20) or 0
		raise = R(-16) + beat * R(34)
		roll = R(78) -- laid flat like the dragon, so it never looks like a fan
		sweep = R(-2) - beat * R(8)
		bend = -R(8) - R(24) * (1 - lag) / 2 - (down and 0 or R(22) * math.abs(beat))
		tail = A(math.sin(u * math.pi * 2 - 1) * R(8), math.sin(t * 1.2) * R(10), 0)
		tail2 = A(math.sin(u * math.pi * 2 - 2) * R(12), math.sin(t * 1.2 - 0.8) * R(14), 0)
		leg = A(math.sin(u * math.pi * 2) * R(8), 0, 0)
	end
	blend(st, "body", body, smooth)
	blend(st, "head", head, smooth)
	blend(st, "jaw", A(jaw, 0, 0), math.clamp(dt * 12, 0, 1))
	phoenixWings(st, raise, roll, sweep, bend, wingA)
	blend(st, "tail", tail, smooth)
	blend(st, "tail2", tail2, smooth)
	blend(st, "legL", leg, smooth)
	blend(st, "legR", leg * A(R(6), 0, 0), smooth)
	-- sparks on hard downstrokes
	if (state == "run" or state == "jump" or state == "fight") and u < 0.1 and (st.sparkAt or 0) < now - 0.3 then
		st.sparkAt = now
		local fx = st.root:FindFirstChild("MonsterSparkles")
		if fx then
			fx:Emit(8)
		end
	end
end
local function dragonBeat(u)
	u = u % 1
	if u < 0.38 then
		return math.cos(u / 0.38 * math.pi) -- fast downstroke: +1 (up) -> -1 (down)
	end
	return -math.cos((u - 0.38) / 0.62 * math.pi) -- slow upstroke back to +1
end
local DRAGON_LEGS = { "fl", "fr", "hl", "hr" }
-- Wings are built standing up. In flight each wing is ROLLED around its
-- arm bone so the membrane lies flat, then flapped around the body axis;
-- the outer half (fingers) bends on a hinge along the last finger bone,
-- so the membrane never tears.
local DRAGON_ARM = Vector3.new(8.9, 8.6, 2.2).Unit
local DRAGON_F4 = Vector3.new(-1.2, -12.8, 1.6).Unit
local function dragonWings(st, raise, sweep, roll, bend, alpha)
	for _, s in ipairs({ -1, 1 }) do
		local n = s < 0 and "L" or "R"
		local arm = Vector3.new(DRAGON_ARM.X * s, DRAGON_ARM.Y, DRAGON_ARM.Z)
		local f4 = Vector3.new(DRAGON_F4.X * s, DRAGON_F4.Y, DRAGON_F4.Z)
		local T = A(0, 0, s * raise) * A(0, s * sweep, 0) * CFrame.fromAxisAngle(arm, -s * roll)
		local B = CFrame.fromAxisAngle(f4, s * bend)
		if alpha then
			blend(st, "wing" .. n, T, alpha)
			blend(st, "wing" .. n .. "Tip", B, alpha)
		else
			set(st, "wing" .. n, T)
			set(st, "wing" .. n .. "Tip", B)
		end
	end
end
-- tail curl: 0 = its natural hooked curl, 1 = straight out behind
local function dragonTail(st, pitch, sway, straight, wave, alpha)
	local c = straight
	-- swings left and right (each part a little later than the one before,
	-- like a whip) and curls / straightens
	local now = os.clock() + (st.phase or 0)
	local lr = R(22)
	blend(st, "tail", A(pitch + wave[1], sway + math.sin(now * 1.1) * lr, 0), alpha)
	blend(st, "tail2", A(pitch * 0.5 + wave[2], sway * 1.2 + math.sin(now * 1.1 - 0.8) * lr * 1.2 + R(60) * c, 0), alpha)
	blend(st, "tail3", A(pitch * 0.3 + wave[3], sway * 1.5 + math.sin(now * 1.1 - 1.6) * lr * 1.4 + R(85) * c, 0), alpha)
end
ANIMS["void-dragon"] = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 6, 0, 1)
	local quick = math.clamp(dt * 14, 0, 1)
	local wingA = math.clamp(dt * 16, 0, 1)
	local rate = ({ idle = 0.55, walk = 0.72, run = 0.95, fight = 0.9, jump = 0.9, fall = 0, dead = 0 })[state] or 0.6
	st.beatU = ((st.beatU or 0) + dt * rate) % 1
	local u = st.beatU
	local beat = dragonBeat(u) -- +1 wings up, -1 wings down
	local lagBeat = dragonBeat(u - 0.12) -- the wrist follows a little later
	local lift = -dragonBeat(u - 0.1) -- body rises just after the downstroke

	-- roar now and then while hovering
	st.nextRoar = st.nextRoar or (now + 5 + math.random() * 5)
	if state == "idle" and now > st.nextRoar then
		st.roarAt = now
		st.nextRoar = now + 9 + math.random() * 8
	end
	local roar = st.roarAt and math.max(0, math.sin(math.clamp((now - st.roarAt) / 2.2, 0, 1) * math.pi)) or 0
	if state ~= "idle" then
		roar = 0
	end

	local body, neck, head, jaw
	local wingRaise, wingSweep, tipBend
	local roll, curl = R(75), 0.5
	local tailP, tailAmp = 0, 0
	local frontUp, frontLow, hindUp, hindLow
	local shards = CF(0, math.sin(t * 1.3) * 0.03 * s, 0) * A(0, math.sin(t * 0.4) * R(8), 0)

	if state == "dead" then
		body = CF(0, -1.1 * s, 0) * A(R(-6), 0, R(78)) -- crashes down onto its side
		neck, head, jaw = A(R(-35), R(15), 0), A(R(-20), 0, 0), R(-28)
		wingRaise, wingSweep, tipBend = R(-20), R(-10), R(-20)
		roll, curl = R(45), 0.1 -- wings half folded, tail curled up
		frontUp, frontLow, hindUp, hindLow = R(30), R(-15), R(-25), R(20)
		shards = CF(0, -1.1 * s, 0)
	elseif state == "jump" then
		body = CF(0, 0.08 * s, 0) * A(R(14), 0, 0)
		neck, head, jaw = A(R(10), 0, 0), A(R(-6), 0, 0), R(-10)
		wingRaise, wingSweep, tipBend = R(-50), R(8), R(24) -- one huge downstroke, tips trailing up
		curl = 0.8
		frontUp, frontLow, hindUp, hindLow = R(-30), R(50), R(-55), R(30)
		tailP, tailAmp = t * 3, R(6)
	elseif state == "fall" then
		body = A(R(-6), 0, math.sin(t * 1.4) * R(4))
		neck, head, jaw = A(R(-4), 0, 0), A(R(6), 0, 0), R(-6)
		wingRaise, wingSweep, tipBend = R(-12), R(-4), R(8) -- gliding, wings spread flat
		curl = 0.7
		frontUp, frontLow, hindUp, hindLow = R(12), R(-10), R(-10), R(10)
		tailP, tailAmp = t * 2, R(8)
	elseif state == "walk" or state == "run" then
		local run = state == "run"
		local pitch = run and R(-12) or R(-6)
		body = CF(0, lift * (run and 0.05 or 0.06) * s, 0) * A(pitch + lift * R(3), 0, math.sin(t * 0.9) * R(run and 3 or 5))
		neck = A((run and R(-16) or R(-8)) + math.sin(u * math.pi * 2 - 1.2) * R(4), math.sin(t * 0.7) * R(6), 0)
		head = A(-pitch * 0.8 + (run and R(10) or R(5)), 0, 0) -- keeps looking ahead
		jaw = run and R(-8) or 0
		wingRaise = R(-18) + beat * (run and R(40) or R(34))
		-- downstroke: wing reaches forward, tips trail up; upstroke: wing
		-- sweeps back and the outer half folds down to slip through the air
		wingSweep = (run and R(-10) or R(-4)) - beat * R(8)
		tipBend = (lagBeat - beat) * R(30) - math.max(0, beat - lagBeat) * R(10)
		curl = run and 0.95 or (0.75 + math.sin(t * 0.6) * 0.15) -- tail streams straight
		frontUp, frontLow, hindUp, hindLow = R(-35), R(60), R(-60), R(22) -- tucked in
		tailP, tailAmp = u * math.pi * 2, run and R(8) or R(10)
	else -- idle / fight: hovers in place
		body = CF(0, lift * 0.07 * s, 0) * A(R(4) + lift * R(2) + R(6) * roar, math.sin(t * 0.45) * R(6), math.sin(t * 0.6) * R(3))
		neck = A(math.sin(t * 0.7) * R(5) + R(22) * roar, math.sin(t * 0.33) * R(14) * (1 - roar), 0)
		head = A(math.sin(t * 0.9) * R(3) - R(8) * roar, math.sin(t * 0.5) * R(20) * (1 - roar), math.sin(t * 0.6) * R(4))
		jaw = -R(3) * math.max(0, math.sin(t * 1.4)) - R(36) * roar
		wingRaise = R(-16) + beat * R(34) + R(30) * roar
		wingSweep = R(-2) - beat * R(8) + R(10) * roar
		tipBend = (lagBeat - beat) * R(30) + R(10) * roar
		roll = R(75) - R(35) * roar -- roar: wings thrown up and open
		curl = 0.55 + math.sin(t * 0.5) * 0.45 -- the tail slowly curls up and straightens
		frontUp, frontLow = R(-8) + math.sin(t * 1.1) * R(6), R(-25) -- legs hang down
		hindUp, hindLow = R(-18) + math.sin(t * 1.1 - 1) * R(6), R(28)
		tailP, tailAmp = u * math.pi * 2, R(9)
		if state == "fight" then
			neck, head, jaw = A(R(-10), 0, 0), A(R(6), 0, 0), R(-18)
		end
	end

	blend(st, "body", body, state == "fight" and quick or smooth)
	blend(st, "neck", neck, smooth)
	blend(st, "head", head, smooth)
	blend(st, "jaw", A(jaw, 0, 0), quick)
	blend(st, "shards", shards, smooth)
	-- wings: raise/lower (Z) + sweep (Y); the outer half bends at the wrist
	dragonWings(st, wingRaise, wingSweep, roll, tipBend, wingA)
	for _, leg in ipairs(DRAGON_LEGS) do
		local hind = leg:sub(1, 1) == "h"
		local off = (leg == "fr" or leg == "hr") and R(4) or 0
		blend(st, leg, A((hind and hindUp or frontUp) + off, 0, 0), smooth)
		blend(st, leg .. "Low", A(hind and hindLow or frontLow, 0, 0), smooth)
	end
	-- tail: curls and straightens, with a wave rolling through it in time
	-- with the wings
	if state == "dead" then
		dragonTail(st, R(8), R(12), curl, { 0, 0, 0 }, smooth)
	else
		dragonTail(st, 0, math.sin(t * 0.8) * R(8), curl, {
			math.sin(tailP - 1.0) * tailAmp,
			math.sin(tailP - 2.0) * tailAmp * 1.4,
			math.sin(tailP - 3.0) * tailAmp * 1.8,
		}, math.clamp(dt * 4, 0, 1))
	end
	-- roar: a burst of void crystals
	if roar > 0.9 and st.roarFx ~= st.roarAt then
		st.roarFx = st.roarAt
		local fx = st.root:FindFirstChild("MonsterSparkles")
		if fx then
			fx:Emit(25)
		end
	end
end
ANIMS.seraph = ANIMS.flyer

-- Storm Leviathan: a snake wave down the 6 linked segments, hovering and
-- rolling; the head strikes and the jaw bites when it attacks.
ANIMS.leviathan = function(st, state, t, dt, now, fightK, speed)
	-- snake: an S-wave travels from the neck to the tail (each segment turns
	-- a little relative to the one before), the raised head/neck sways like
	-- a cobra, the forked tongue flicks, it rears back and strikes to attack,
	-- and it rolls onto its side when dead.
	local s = st.s
	local smooth = math.clamp(dt * 8, 0, 1)
	local fast = math.clamp(dt * 20, 0, 1)
	local moving = state == "walk" or state == "run"
	st.waveP = (st.waveP or 0) + dt * (state == "run" and 7 or (moving and 4.5 or 1.6))
	local p = st.waveP
	if not st.segCount then
		local n = 0
		while st.motors["seg" .. (n + 1)] do
			n += 1
		end
		st.segCount = n
	end
	local N = st.segCount
	local amp = state == "run" and R(20) or (moving and R(16) or R(7))

	-- attack: rear back, then strike forward with the jaw open
	local k = state == "fight" and math.clamp((now - st.attackAt) / 0.4, 0, 1) or 0
	local rear = state == "fight" and (k < 0.45 and k / 0.45 or 0) or 0
	local strike = state == "fight" and (k >= 0.45 and math.sin((k - 0.45) / 0.55 * math.pi) or 0) or 0

	local bodyCF
	if state == "dead" then
		bodyCF = CF(0, -0.12 * s, 0) * A(0, 0, R(85))
	else
		bodyCF = CF(0, 0, -0.35 * s * strike)
	end
	blend(st, "body", bodyCF, state == "fight" and fast or smooth)

	-- the traveling S-wave (curvature per joint); stronger toward the tail
	for i = 1, N do
		local cf
		if state == "dead" then
			cf = A(0, R(6), 0)
		else
			local weight = 0.55 + 0.45 * (i / N)
			local yaw = math.cos(p - i * 0.62) * amp * weight
			local pitch = 0
			if i <= 3 then -- the raised neck sways / rears
				pitch = R(-18) * rear + R(12) * strike + math.sin(t * 1.1 + i) * R(3)
			end
			cf = A(pitch, yaw, 0)
		end
		blend(st, "seg" .. i, cf, state == "fight" and fast or smooth)
	end

	-- head: sways like a cobra, keeps looking forward while slithering
	local head
	if state == "dead" then
		head = A(R(20), 0, 0)
	else
		head = CF(0, 0, -0.18 * s * strike) * A(R(-22) * rear + R(18) * strike + math.sin(t * 1.3) * R(3), -math.cos(p) * amp * 0.5 + math.sin(t * 0.7) * R(8), 0)
	end
	blend(st, "head", head, state == "fight" and fast or smooth)
	blend(st, "jaw", A(R(35) * math.max(rear, strike), 0, 0), fast)

	-- forked tongue flicks out now and then
	local flick = (state ~= "dead" and math.sin(t * 2.3) > 0.72) and 1 or 0
	blend(st, "tongue", CF(0, 0, (1 - flick) * 0.16 * s) * A(0, math.sin(t * 40) * R(12) * flick, 0), math.clamp(dt * 30, 0, 1))

	if state == "fight" and strike > 0.8 and st.burstFor ~= st.attackAt then
		st.burstFor = st.attackAt
		local sparks = st.root:FindFirstChild("MonsterSparkles")
		if sparks then
			sparks:Emit(15)
		end
	end
end

-- Floaters (Shadow Wraith, Cosmic Emperor): hover and drift, cloak/cape
-- ripples and streams back when moving, clawed arms reach out and slash,
-- planets orbit.
ANIMS.floater = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 8, 0, 1)
	local moving = state == "walk" or state == "run"
	local bodyCF
	if state == "dead" then
		bodyCF = CF(0, -0.6 * s, 0) * A(R(-70), 0, 0)
	elseif state == "fight" then
		bodyCF = CF(0, 0.1 * s * fightK, -0.4 * s * fightK) * A(R(-15) * fightK, 0, 0)
	else
		bodyCF = CF(0, math.sin(t * 1.5) * 0.1 * s, 0) * A((moving and R(-12) or 0) + math.sin(t * 1.1) * R(2), 0, math.sin(t * 0.8) * R(3))
	end
	blend(st, "body", bodyCF, smooth)
	blend(st, "head", state == "fight" and A(R(-15) * fightK, 0, 0) or A(math.sin(t * 0.7) * R(4), math.sin(t * 0.4) * R(20), 0), smooth)
	blend(st, "cape", A((moving and R(25) or R(6)) + math.sin(t * 3) * R(6), 0, math.sin(t * 2.3) * R(5)), smooth)
	local reach = state == "fight" and R(95) * fightK or (math.sin(t * 1.3) * R(8) + R(15))
	blend(st, "armL", A(reach * 0.9, 0, R(-10)), smooth)
	blend(st, "armR", A(reach, 0, R(10)), smooth)
	blend(st, "armLLow", A(R(20) + math.sin(t * 1.7) * R(8), 0, 0), smooth)
	blend(st, "armRLow", A(R(20) + math.sin(t * 1.7 + 1) * R(8), 0, 0), smooth)
	set(st, "orbit", A(0, (t * 1.4) % (math.pi * 2), R(12)))
end
-- Shadow Wraith: a floating shadow. Idle = hovers and sways, the torn
-- robe billows, the head tilts and watches, the claw hand flexes; walk =
-- glides forward leaning in, robe trailing back; run = drifts fast, scythe
-- held back; jump = rises with arms spread; fall = sinks with the robe
-- flaring up; dead = sinks and topples, the scythe drops. The attack is a
-- reaper scythe swing (ATTACKS.wraith).
ANIMS.wraith = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 5, 0, 1)
	local hover = math.sin(t * 1.3) * 0.08 * s
	local body, cape, head, armL, armLLow, armR, armRLow, scythe
	if state == "dead" then
		body = CF(0, -0.55 * s, 0) * A(R(-20), R(20), R(70))
		cape = A(R(10), 0, 0)
		head = A(R(-30), R(15), 0)
		armL, armLLow = A(R(20), 0, R(-30)), A(R(-10), 0, 0)
		armR, armRLow = A(R(-20), 0, R(40)), A(R(20), 0, 0)
		scythe = A(R(30), 0, R(50))
	elseif state == "jump" then
		body = CF(0, 0.15 * s, 0) * A(R(-6), 0, 0)
		cape = A(R(18), 0, 0)
		head = A(R(-10), 0, 0)
		armL, armLLow = A(0, 0, R(-45)), A(R(-15), 0, 0)
		armR, armRLow = A(0, 0, R(35)), CFrame.identity
		scythe = CFrame.identity
	elseif state == "fall" then
		body = A(R(6), 0, math.sin(t * 2) * R(4))
		cape = A(R(-22), 0, math.sin(t * 3) * R(4))
		head = A(R(12), 0, 0)
		armL, armLLow = A(0, 0, R(-30)), A(R(10), 0, 0)
		armR, armRLow = A(0, 0, R(25)), CFrame.identity
		scythe = CFrame.identity
	elseif state == "walk" or state == "run" then
		local run = state == "run"
		local lean = run and R(-24) or R(-10)
		body = CF(0, hover * 0.6 + (run and 0.1 * s or 0.04 * s), 0) * A(lean, 0, math.sin(t * 2) * R(3))
		cape = A(R(run and 30 or 16) + math.sin(t * (run and 9 or 5)) * R(5), 0, math.sin(t * 3) * R(4))
		head = A(-lean * 0.7, math.sin(t * 0.7) * R(8), 0)
		armL, armLLow = A(R(run and 30 or 12), 0, R(-10)), A(math.sin(t * 3) * R(8), 0, 0)
		armR, armRLow = A(R(run and 25 or 8), 0, R(10)), A(R(run and -10 or 0), 0, 0)
		scythe = A(R(run and 25 or 10), 0, 0)
	else
		body = CF(0, hover, 0) * A(math.sin(t * 0.9) * R(3), math.sin(t * 0.4) * R(8), math.sin(t * 0.7) * R(3))
		cape = A(math.sin(t * 1.6) * R(6) + R(4), 0, math.sin(t * 1.1) * R(5))
		head = A(math.sin(t * 0.8) * R(5), math.sin(t * 0.45) * R(22), math.sin(t * 0.6) * R(8))
		armL = A(math.sin(t * 1.2) * R(6), 0, math.sin(t * 0.9) * R(5))
		armLLow = A(math.sin(t * 2.3) * R(8), 0, 0)
		armR, armRLow = A(math.sin(t * 1.1 + 1) * R(4), 0, 0), CFrame.identity
		scythe = A(0, math.sin(t * 0.7) * R(6), 0)
	end
	blend(st, "body", body, smooth)
	blend(st, "cape", cape, smooth)
	blend(st, "head", head, smooth)
	blend(st, "armL", armL, smooth)
	blend(st, "armLLow", armLLow, smooth)
	blend(st, "armR", armR, smooth)
	blend(st, "armRLow", armRLow, smooth)
	blend(st, "scythe", scythe, smooth)
end
--------------------------------------------------------------------
-- Storm Leviathan (god serpent): the whole body waves like a snake
-- (a wave travels from the neck down to the tail), the head looks
-- around and roars, storm bricks orbit it and lightning crackles over
-- its body. Joints: body, n1..n4 (neck), head, jaw, t1..t9 (tail), orbit.
--------------------------------------------------------------------
local LP = game:GetService("Players").LocalPlayer
local function boltsAllowed()
	return LP:GetAttribute("Graphics") ~= "SuperLow"
end
-- a jagged neon lightning bolt from a to b (this screen only, very short)
local function lightningBolt(a, b, width, color)
	local pts = { a }
	local n = 6
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.5 then
		return
	end
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = side:Cross(dir).Unit
	for i = 1, n - 1 do
		local off = (side * (math.random() - 0.5) + up * (math.random() - 0.5)) * len * 0.22
		table.insert(pts, a + dir * (i / n) + off)
	end
	table.insert(pts, b)
	local holder = workspace.CurrentCamera
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = color or Color3.fromRGB(170, 235, 255)
		seg.Size = Vector3.new(width, width, (p1 - p0).Magnitude + width)
		seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		seg.Parent = holder
		task.delay(0.09 + math.random() * 0.08, function()
			seg:Destroy()
		end)
	end
end

local LEVI_CHAIN = { "head", "n4", "n3", "n2", "n1", "body", "t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8", "t9" }
local LEVI_NECK = { "n1", "n2", "n3", "n4" }
ANIMS.leviathan = function(st, state, t, dt, now, fightK, speed)
	local s = st.s
	local smooth = math.clamp(dt * 6, 0, 1)
	local moving = state == "walk" or state == "run" or state == "jump" or state == "fall"
	local run = state == "run"
	local freq = run and 6 or (moving and 3.6 or 1.5)
	local amp = run and R(22) or (moving and R(17) or R(10))
	-- roar every few seconds while idle
	st.nextRoar = st.nextRoar or (now + 4 + math.random() * 4)
	local roar = 0
	if now >= st.nextRoar then
		local k = (now - st.nextRoar) / 1.6
		if k >= 1 then
			st.nextRoar = now + 6 + math.random() * 6
		else
			roar = math.sin(k * math.pi)
		end
	end
	if state == "dead" then
		blend(st, "body", CF(0, -0.1 * s, 0) * A(0, 0, R(25)), smooth)
		for i, n in ipairs(LEVI_NECK) do
			blend(st, n, A(R(14), R(4) * i, 0), smooth)
		end
		blend(st, "head", A(R(20), 0, R(15)), smooth)
		blend(st, "jaw", A(-R(30), 0, 0), smooth)
		for k = 1, 9 do
			blend(st, "t" .. k, A(0, R(6) * math.sin(k), 0), smooth)
		end
		blend(st, "orbit", CF(0, -0.6 * s, 0), smooth)
		return
	end
	-- body: slow breathing rise + a calm sway (no shaking)
	blend(st, "body", CF(0, math.sin(t * 1.2) * 0.03 * s, 0) * A(math.sin(t * 0.8) * R(2), math.sin(t * 0.5) * R(3), math.sin(t * 0.9) * R(2)), smooth)
	-- TAIL FOLLOWS THE GROUND PATH: every tail joint sits on the spot the
	-- body passed over. Straight path = straight tail, a turn = the tail
	-- trails around the curve. (The model's resting S-bend is cancelled.)
	local root = st.root
	if not st.tailRest then
		local pts = {}
		local b = root:FindFirstChild("Pivot_body")
		pts[0] = b and (b:GetAttribute("Rest") or CFrame.identity).Position
		for k = 1, 9 do
			local p = root:FindFirstChild("Pivot_t" .. k)
			pts[k] = p and (p:GetAttribute("Rest") or CFrame.identity).Position
		end
		local ok = pts[0] ~= nil
		for k = 1, 9 do ok = ok and pts[k] ~= nil end
		if ok then
			local restAng, dist = {}, {}
			dist[1] = math.max(Vector2.new(pts[1].X, pts[1].Z).Magnitude, 0.1)
			for k = 1, 9 do
				local d = (k < 9) and (pts[k + 1] - pts[k]) or (pts[9] - pts[8])
				restAng[k] = math.atan2(d.X, d.Z)
				if k < 9 then
					dist[k + 1] = dist[k] + Vector2.new(d.X, d.Z).Magnitude
				end
			end
			dist[10] = dist[9] + Vector2.new(pts[9].X - pts[8].X, pts[9].Z - pts[8].Z).Magnitude
			st.tailRest = { ang = restAng, dist = dist }
		end
	end
	local tr = st.tailRest
	if tr then
		-- remember where the body has been (only when it really moves)
		st.path = st.path or {}
		local path = st.path
		local here = Vector3.new(root.Position.X, 0, root.Position.Z)
		if #path == 0 or (here - path[#path]).Magnitude > 0.05 * s then
			table.insert(path, here)
			local need = tr.dist[10] + s
			local total = 0
			for i = #path, 2, -1 do
				total += (path[i] - path[i - 1]).Magnitude
				if total > need then
					for _ = 1, i - 2 do table.remove(path, 1) end
					break
				end
			end
		end
		local back = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		back = back.Magnitude > 0.01 and -back.Unit or Vector3.new(0, 0, 1)
		-- point on the path `d` studs behind the body
		local function behind(d)
			local cur = here
			local left = d
			for i = #path, 1, -1 do
				local p = path[i]
				local seg = (p - cur).Magnitude
				if seg >= left and seg > 1e-4 then
					return cur + (p - cur) * (left / seg)
				end
				left -= seg
				cur = p
			end
			-- not enough path yet: continue straight out the back from the oldest point
			local dir = back
			if #path >= 2 then
				local d2 = path[1] - path[2]
				if d2.Magnitude > 1e-3 then dir = d2.Unit end
			end
			return cur + dir * left
		end
		local k2s = s / 16 -- model units -> studs
		local q = {}
		for k = 1, 10 do
			q[k] = behind(tr.dist[k] * k2s)
		end
		local acc = 0
		for k = 1, 9 do
			local dirW = q[k + 1] - q[k]
			local want = 0
			if dirW.Magnitude > 1e-3 then
				local l = root.CFrame:VectorToObjectSpace(dirW)
				want = math.atan2(l.X, l.Z)
			end
			-- lazy drift only while resting, never while moving
			if not moving then
				want += R(4) * math.sin(t * 0.6 - k * 0.5) * (k / 9)
			end
			local total = want - tr.ang[k] -- rotation needed from the resting pose
			local rel = math.clamp(total - acc, R(-35), R(35))
			acc += rel
			blend(st, "t" .. k, A(0, rel, 0), math.clamp(dt * 10, 0, 1))
		end
	end
	-- neck: an S that sways gently, rising up when it roars
	for i, n in ipairs(LEVI_NECK) do
		local yaw = R(moving and 4 or 6) * math.sin(t * 0.6 - i * 0.7)
		local pitch = R(4) * math.sin(t * 1.3 - i * 0.5) - roar * R(9)
		blend(st, n, A(pitch, yaw, math.sin(t * 0.9 - i) * R(3)), smooth)
	end
	-- head: looks around; tips up and opens wide when roaring
	blend(st, "head", A(math.sin(t * 0.9) * R(6) - roar * R(20), math.sin(t * 0.45) * R(18), math.sin(t * 0.7) * R(6)), smooth)
	blend(st, "jaw", A(-(R(3) + (math.sin(t * 1.8) * 0.5 + 0.5) * R(3) + roar * R(38)), 0, 0), smooth)
	-- lightning crackles over the body now and then (more when roaring / running)
	st.nextBolt = st.nextBolt or now
	if now >= st.nextBolt and boltsAllowed() and st.root.Parent then
		st.nextBolt = now + (roar > 0.2 and 0.12 or (run and 0.6 or 1.4)) + math.random() * 1.2
		-- crackles run along the body: from one spine joint to the next one
		local chain = {}
		for _, name in ipairs(LEVI_CHAIN) do
			local m = st.motors[name]
			if m and m.Part1 then
				table.insert(chain, m.Part1)
			end
		end
		if #chain >= 2 then
			local bolts = roar > 0.2 and 2 or 1
			for _ = 1, bolts do
				local i = math.random(1, #chain - 1)
				local a, b = chain[i], chain[i + 1]
				local up = a.CFrame.UpVector * (0.25 * s * (0.6 + math.random() * 0.6))
				local side = a.CFrame.RightVector * ((math.random() - 0.5) * 0.4 * s)
				lightningBolt(a.Position + up + side, b.Position + up - side, 0.05 * s, nil)
			end
		end
		local glow = st.root:FindFirstChild("MonsterGlow")
		if glow then
			glow.Brightness = 3
			task.delay(0.1, function()
				glow.Brightness = 1.2
			end)
		end
	end
end
-- Leviathan attack: Storm Strike - rears up, then lunges down with jaws wide
-- open while lightning bursts from its mouth and the tail whips.
ATTACKS_PENDING = ATTACKS_PENDING or {}
ATTACKS_PENDING.leviathan = function(st, k, s)
	local rear = k < 0.4 and k / 0.4 or 0
	local strike = k >= 0.4 and math.sin(math.clamp((k - 0.4) / 0.6, 0, 1) * math.pi) or 0
	set(st, "body", CF(0, 0.1 * s * rear, -0.25 * s * strike) * A(R(-6) * rear + R(8) * strike, 0, 0))
	for i, n in ipairs(LEVI_NECK) do
		set(st, n, A(R(-12) * rear + R(14) * strike, 0, 0))
	end
	set(st, "head", A(R(-25) * rear + R(10) * strike, 0, 0))
	set(st, "jaw", A(-(R(15) * rear + R(55) * strike), 0, 0))
	for j = 1, 9 do
		set(st, "t" .. j, A(0, R(22) * strike * math.sin(j * 0.9 + k * 6), 0))
	end
	if strike > 0.85 and st.boltFor ~= st.attackAt and boltsAllowed() then
		st.boltFor = st.attackAt
		local head = st.motors.head and st.motors.head.Part1
		if head then
			local look = head.CFrame.LookVector
			for _ = 1, 3 do
				lightningBolt(head.Position + look * 1.5 * s * 0.4, head.Position + look * s * 2.2 + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * s, 0.08 * s, Color3.fromRGB(200, 245, 255))
			end
		end
	end
	if strike > 0.8 and st.atkBurst ~= st.attackAt then
		st.atkBurst = st.attackAt
		local fx = st.root:FindFirstChild("MonsterSparkles")
		if fx then
			fx:Emit(30)
		end
	end
end

ANIMS.emperor = ANIMS.floater

ANIMS.titan = ANIMS.golem

--------------------------------------------------------------------
-- Unique attacks: each monster has its own move (instead of all doing
-- the same forward tackle). k = 0..1 through the attack; these run after
-- the monster's normal animation and take over the joints they use.
--------------------------------------------------------------------
local function attackBurst(st, at, n)
	if st.atkBurst ~= st.attackAt and at then
		st.atkBurst = st.attackAt
		local fx = st.root:FindFirstChild("MonsterSparkles")
		if fx then
			fx:Emit(n or 18)
		end
	end
end
local ATTACKS = {}

if ATTACKS_PENDING then
	for k, f in pairs(ATTACKS_PENDING) do
		ATTACKS[k] = f
	end
end
-- Cave Bat: Screech Dive - swoops down in an arc, wings flared, fangs out
ATTACKS.bat = function(st, k, s)
	local up = math.sin(k * math.pi)
	set(st, "body", CF(0, -0.45 * s * up, -0.2 * s * up) * A(R(40) * up, 0, 0))
	set(st, "wingL", A(0, 0, -R(70) * up))
	set(st, "wingR", A(0, 0, R(70) * up))
	set(st, "jaw", A(R(40) * up, 0, 0))
	set(st, "earL", A(R(-40) * up, 0, 0))
	set(st, "earR", A(R(-40) * up, 0, 0))
end
-- Glowcap: Spore Spin - spins on the spot, cap bouncing, spores burst out
ATTACKS.mushroom = function(st, k, s)
	local up = math.sin(k * math.pi)
	set(st, "body", CF(0, 0.2 * s * up, 0) * A(0, k * math.pi * 2, 0))
	set(st, "cap", CF(0, 0.12 * s * math.abs(math.sin(k * math.pi * 3)), 0) * A(0, -k * math.pi, 0))
	set(st, "armL", A(0, 0, R(-80) * up))
	set(st, "armR", A(0, 0, R(80) * up))
	attackBurst(st, k > 0.5, 24)
end
-- Ironclaw Crab: Claw Crush - raises both claws high, slams them down
ATTACKS.crab = function(st, k, s)
	local raise = k < 0.55 and k / 0.55 or math.max(0, 1 - (k - 0.55) / 0.15)
	local slam = k >= 0.55 and math.sin(math.clamp((k - 0.55) / 0.45, 0, 1) * math.pi) or 0
	set(st, "body", CF(0, -0.08 * s * slam, 0) * A(R(-12) * raise + R(10) * slam, 0, 0))
	set(st, "clawL", A(R(-75) * raise + R(20) * slam, R(15) * raise, 0))
	set(st, "clawR", A(R(-75) * raise + R(20) * slam, -R(15) * raise, 0))
	set(st, "pinchL", A(R(35) * raise, 0, 0))
	set(st, "pinchR", A(R(35) * raise, 0, 0))
	attackBurst(st, slam > 0.6, 14)
end
-- Frostfang Wolf: Frost Bite - crouches low with the hackles (mane)
-- raised, lunges forward, bites and SHAKES its head side to side, then
-- springs back; a burst of frost on the bite.
ATTACKS.wolf = function(st, k, s)
	local crouch = k < 0.3 and math.sin(k / 0.3 * math.pi / 2) or math.max(0, 1 - (k - 0.3) / 0.12)
	local lunge = k >= 0.3 and math.sin(math.clamp((k - 0.3) / 0.7, 0, 1) * math.pi) or 0
	local bite = (k > 0.42 and k < 0.9) and 1 or 0
	local shake = bite * math.sin((k - 0.42) * math.pi * 10) * R(22)
	set(st, "body", CF(0, -0.12 * s * crouch + 0.05 * s * lunge, -0.5 * s * lunge) * A(R(-6) * crouch - R(10) * lunge, shake * 0.3, 0))
	set(st, "head", A(R(-14) * crouch - R(6) * lunge, shake, shake * 0.4))
	set(st, "jaw", A(-R(40) * math.max(crouch, lunge) * (1 - bite * 0.8), 0, 0))
	set(st, "fl", A(R(40) * lunge, 0, 0))
	set(st, "fr", A(R(40) * lunge, 0, 0))
	set(st, "flLow", A(-R(30) * crouch, 0, 0))
	set(st, "frLow", A(-R(30) * crouch, 0, 0))
	set(st, "hl", A(-R(30) * lunge + R(10) * crouch, 0, 0))
	set(st, "hr", A(-R(30) * lunge + R(10) * crouch, 0, 0))
	set(st, "hlLow", A(R(25) * crouch, 0, 0))
	set(st, "hrLow", A(R(25) * crouch, 0, 0))
	set(st, "earL", A(R(-60), 0, 0))
	set(st, "earR", A(R(-60), 0, 0))
	set(st, "tail", A(R(-15) * crouch + R(10) * lunge, -shake * 0.6, 0))
	attackBurst(st, bite == 1, 22)
end
-- Ember Phoenix: Blaze Dive - rears up with the wings thrown high and
-- back, talons forward, then dives at the target: one huge wingbeat
-- forward, beak snapping, talons raking, tail fanning out.
ATTACKS.phoenix = function(st, k, s)
	local rear = k < 0.35 and math.sin(k / 0.35 * math.pi / 2) or math.max(0, 1 - (k - 0.35) / 0.2)
	local dive = k >= 0.35 and math.sin(math.clamp((k - 0.35) / 0.65, 0, 1) * math.pi) or 0
	set(st, "body", CF(0, 0.15 * s * rear - 0.08 * s * dive, 0.12 * s * rear - 0.35 * s * dive) * A(R(22) * rear - R(30) * dive, 0, 0))
	set(st, "head", A(R(-20) * rear + R(15) * dive, 0, 0))
	set(st, "jaw", A(-R(35) * math.max(rear, dive * (k < 0.8 and 1 or 0)), 0, 0))
	phoenixWings(st, R(40) * rear - R(65) * dive, R(70) - R(25) * rear, R(-20) * rear + R(25) * dive, -R(15) * rear - R(25) * dive)
	set(st, "legL", A(R(-60) * dive + R(20) * rear, 0, 0))
	set(st, "legR", A(R(-60) * dive + R(20) * rear, 0, 0))
	set(st, "tail", A(R(20) * rear - R(15) * dive, 0, 0))
	set(st, "tail2", A(R(15) * rear, 0, 0))
	attackBurst(st, dive > 0.6, 30)
end
-- Void Dragon: Void Breath - pulls its neck back and up with the jaw
-- opening and the wings flaring wide, then thrusts the head forward and
-- sweeps a breath of void crystals across the target side to side, tail
-- lashing, then snaps the jaw shut.
ATTACKS["void-dragon"] = function(st, k, s)
	local draw = k < 0.3 and math.sin(k / 0.3 * math.pi / 2) or math.max(0, 1 - (k - 0.3) / 0.15)
	local breath = k >= 0.3 and math.clamp((k - 0.3) / 0.55, 0, 1) or 0
	local on = (k >= 0.3 and k < 0.88) and 1 or 0
	local sweep = math.sin(breath * math.pi * 2) * R(28) * on
	set(st, "body", CF(0, 0.06 * s * draw, 0.12 * s * draw - 0.1 * s * on) * A(R(12) * draw - R(6) * on, sweep * 0.3, 0))
	set(st, "neck", A(R(30) * draw - R(22) * on, sweep * 0.6, 0))
	set(st, "head", A(R(-18) * draw + R(8) * on, sweep * 0.5, 0))
	set(st, "jaw", A(-R(20) * draw - R(48) * on, 0, 0))
	dragonWings(st, R(26) * draw + R(8) * on, R(-10) * draw, R(70) - R(30) * draw, R(-10) * draw)
	set(st, "tail", A(R(8) * draw, -sweep * 0.8, 0))
	set(st, "tail2", A(0, -sweep * 1.1, 0))
	set(st, "tail3", A(0, -sweep * 1.4, 0))
	attackBurst(st, on == 1 and breath > 0.15, 40)
end
-- Star Seraph: Holy Smite - rises, raises the wand, brings it down in light
ATTACKS.seraph = function(st, k, s)
	local up = math.sin(k * math.pi)
	local raise = k < 0.6 and k / 0.6 or 1 - (k - 0.6) / 0.4 * 1.4
	set(st, "body", CF(0, 0.45 * s * up, 0))
	set(st, "armR", A(R(-150) * raise, 0, 0))
	set(st, "halo", A(0, k * math.pi * 6, 0))
	set(st, "wingL", A(0, 0, -R(50) * up))
	set(st, "wingR", A(0, 0, R(50) * up))
	attackBurst(st, k > 0.65, 28)
end
-- Sun Titan: Solar Uppercut - twists and throws a huge uppercut
ATTACKS.titan = function(st, k, s)
	local wind = k < 0.35 and k / 0.35 or 0
	local hit = k >= 0.35 and math.sin(math.clamp((k - 0.35) / 0.65, 0, 1) * math.pi) or 0
	set(st, "body", CF(0, 0.2 * s * hit, 0) * A(R(-8) * hit, R(30) * wind - R(35) * hit, 0))
	set(st, "armR", A(R(40) * wind + R(165) * hit, 0, R(10) * hit))
	set(st, "armRLow", A(R(-40) * hit, 0, 0))
	set(st, "armL", A(R(-30) * hit, 0, 0))
	set(st, "legL", A(R(20) * hit, 0, 0))
	attackBurst(st, hit > 0.8, 20)
end
-- Shadow Wraith: Reaper Swing - raises the scythe high behind it, then
-- sweeps it down and across through the target, twisting into the swing.
ATTACKS.wraith = function(st, k, s)
	local wind = k < 0.35 and math.sin(k / 0.35 * math.pi / 2) or 0
	local sw = k >= 0.35 and math.clamp((k - 0.35) / 0.4, 0, 1) or 0
	sw = 1 - (1 - sw) ^ 3
	local back = k > 0.75 and (k - 0.75) / 0.25 or 0
	local swing = sw * (1 - back)
	local w = wind * (1 - sw)
	set(st, "body", CF(0, 0.08 * s * w, -0.25 * s * swing) * A(R(8) * w - R(16) * swing, R(-35) * w + R(40) * swing, 0))
	set(st, "armR", A(R(-60) * w + R(95) * swing, 0, R(-30) * w + R(40) * swing))
	set(st, "armRLow", A(R(-35) * w + R(25) * swing, 0, 0))
	set(st, "scythe", A(R(-25) * w + R(30) * swing, 0, R(15) * swing))
	set(st, "armL", A(R(-20) * w + R(35) * swing, 0, R(-35) * w))
	set(st, "head", A(R(-12) * swing, R(-20) * w + R(20) * swing, 0))
	set(st, "cape", A(R(20) * swing, 0, R(-14) * swing))
	attackBurst(st, sw > 0.5 and back == 0, 26)
end
-- Cosmic Emperor: Cosmic Nova - rises with arms wide, planets whirl, boom
ATTACKS.emperor = function(st, k, s)
	local up = math.sin(k * math.pi)
	set(st, "body", CF(0, 0.4 * s * up, 0) * A(R(-10) * up, 0, 0))
	set(st, "armL", A(R(60) * up, 0, -R(80) * up))
	set(st, "armR", A(R(60) * up, 0, R(80) * up))
	set(st, "orbit", A(0, k * math.pi * 8, R(12)))
	set(st, "cape", A(R(40) * up, 0, 0))
	attackBurst(st, k > 0.55, 40)
end
-- Stone Golem (double fist smash), Moss Slime (rear up + crash) and Storm
-- Leviathan (coil + strike) keep the attacks in their own animations.

local function animate(st, now, dt)
	local root, s, style = st.root, st.s, st.style

	-- speed from how far the root moved (sampled, since the server moves it)
	local elapsed = now - st.sampleAt
	if elapsed >= 0.15 then
		local v = (root.Position - st.samplePos) / elapsed
		if v.Magnitude > 150 then
			v = Vector3.zero -- teleported
		end
		st.vel = st.vel:Lerp(v, 0.6)
		st.samplePos = root.Position
		st.sampleAt = now
	end
	local speed = Vector2.new(st.vel.X, st.vel.Z).Magnitude
	local vy = st.vel.Y

	local state
	-- only enemies that were killed play the dead pose; defeated pets just
	-- rest in the pen (grey) with their normal animations
	if st.model:GetAttribute("Dead") or st.model:GetAttribute("Dying") then
		state = "dead"
	elseif now - st.attackAt < 0.4 then
		state = "fight"
	elseif vy > 4 then
		state = "jump"
	elseif vy < -4 then
		state = "fall"
	elseif speed > 13 then
		state = "run"
	elseif speed > 1.2 then
		state = "walk"
	else
		state = "idle"
	end

	local t = now + st.phase
	local freq = state == "run" and 13 or (state == "walk" and 8 or 2)
	local swing = state == "run" and R(45) or (state == "walk" and R(28) or 0)
	local flying = style == "fly" or style == "serpent"
	local fightK = state == "fight" and math.sin(math.clamp((now - st.attackAt) / 0.4, 0, 1) * math.pi) or 0

	local custom = ANIMS[st.rigId]
	if custom then
		custom(st, state, t, dt, now, fightK, speed)
		local attack = ATTACKS[st.rigId]
		if attack and state == "fight" then
			attack(st, math.clamp((now - st.attackAt) / 0.4, 0, 1), st.s, t)
		end
		doFlash(st, now)
		doBlink(st, now, state == "dead")
		return
	end

	-- body
	local bodyCF
	if state == "dead" then
		bodyCF = flying and (CF(0, -0.9 * s, 0) * A(0, 0, R(80))) or (CF(0, -0.25 * s, 0) * A(0, 0, R(80)))
	elseif state == "fight" then
		bodyCF = CF(0, 0, -0.35 * s * fightK) * A(R(-15) * fightK, 0, 0)
	elseif state == "jump" then
		bodyCF = A(R(12), 0, 0)
	elseif state == "fall" then
		bodyCF = A(R(-10), 0, 0)
	else
		local bob
		if style == "hop" then
			bob = state == "idle" and math.abs(math.sin(t * 2)) * 0.05 * s or math.abs(math.sin(t * freq * 0.6)) * 0.35 * s
		elseif state == "idle" then
			bob = math.sin(t * 2) * 0.03 * s
		else
			bob = math.abs(math.sin(t * freq)) * 0.06 * s
		end
		bodyCF = CF(0, bob, 0) * A(state == "run" and R(-8) or 0, 0, 0)
	end
	if flying and state ~= "dead" then
		bodyCF = CF(0, math.sin(t * 2) * 0.1 * s, 0) * bodyCF -- hover
	end
	set(st, "body", bodyCF)

	-- head
	if state == "dead" then
		set(st, "head", A(R(20), 0, 0))
	elseif state == "fight" then
		set(st, "head", A(R(-18) * fightK, 0, 0))
	else
		set(st, "head", A(math.sin(t * freq * 0.5) * R(4), math.sin(t * 0.7) * R(12), 0))
	end

	-- legs + arms (opposite phases)
	local sw = (state == "jump" or state == "fall" or state == "dead") and 0 or math.sin(t * freq) * swing
	local tuck = state == "jump" and R(-30) or (state == "fall" and R(20) or 0)
	set(st, "legL", A(sw + tuck, 0, 0))
	set(st, "legR", A(-sw + tuck, 0, 0))
	set(st, "legL1", A(sw + tuck, 0, 0))
	set(st, "legR1", A(-sw + tuck, 0, 0))
	set(st, "legL2", A(-sw - tuck, 0, 0))
	set(st, "legR2", A(sw - tuck, 0, 0))
	if state == "fight" then
		set(st, "armL", A(R(-80) * fightK, 0, 0))
		set(st, "armR", A(R(-80) * fightK, 0, 0))
	elseif state == "fall" then
		set(st, "armL", A(0, 0, R(-40)))
		set(st, "armR", A(0, 0, R(40)))
	else
		set(st, "armL", A(-sw, 0, 0))
		set(st, "armR", A(sw, 0, 0))
	end

	-- claws (crab): snap when fighting
	local pinch = state == "fight" and math.abs(math.sin(t * 20)) * R(25) or math.sin(t * 3) * R(6)
	set(st, "clawL", A(0, pinch, 0))
	set(st, "clawR", A(0, -pinch, 0))

	-- wings (flap faster when moving / fighting; up when falling; folded when dead)
	local flapSpeed = ({ idle = 5, walk = 8, run = 11, fight = 13, jump = 9, fall = 0, dead = 0 })[state]
	local flapAmp = ({ idle = R(25), walk = R(35), run = R(45), fight = R(50), jump = R(40), fall = 0, dead = 0 })[state]
	local flap = math.sin(t * flapSpeed) * flapAmp + (state == "fall" and R(-40) or 0) + (state == "dead" and R(15) or 0)
	set(st, "wingL", A(0, 0, flap))
	set(st, "wingR", A(0, 0, -flap))

	-- tail wag, mushroom cap wobble
	set(st, "tail", A(0, math.sin(t * (state == "run" and 12 or 5)) * R(18), 0))
	set(st, "cap", A(math.sin(t * freq) * R(5), 0, math.sin(t * freq * 0.5) * R(5)))

	-- leviathan segments: snake wave
	local waveAmp = state == "idle" and 0.1 or 0.18
	for i = 1, 4 do
		if state == "dead" then
			set(st, "seg" .. i, CF(0, 0, 0))
		else
			set(st, "seg" .. i, CF(math.sin(t * 3 - i * 0.9) * waveAmp * s, 0, 0))
		end
	end

	doFlash(st, now)
	doBlink(st, now, state == "dead")
end

-- The server moves each monster in small steps (10-20 per second). On
-- screen we glide from where it is toward the newest server position, so
-- walking looks smooth instead of stepping like a robot.
smoothMove = function(st, dt)
	local root = st.root
	if not root.Anchored then
		return
	end
	local cf = root.CFrame
	if st.shownCF == nil or cf ~= st.shownCF then
		-- a new position from the server (not the one we set last frame)
		st.targetCF = cf
		if st.shownCF == nil or (cf.Position - st.shownCF.Position).Magnitude > 25 then
			st.shownCF = cf -- teleported: jump there
		end
	end
	local target = st.targetCF or cf
	local alpha = math.clamp(dt * 14, 0, 1)
	root.CFrame = st.shownCF:Lerp(target, alpha)
	st.shownCF = root.CFrame -- read back (stored rounded), so we can tell our value from the server's
end

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local now = os.clock()
	for root, st in pairs(rigs) do
		if not root.Parent then
			rigs[root] = nil
		elseif (root.Position - camPos).Magnitude < MAX_DISTANCE and not st.model:GetAttribute("LowCulled") then
			smoothMove(st, dt)
			animate(st, now, dt)
		end
	end
end)
