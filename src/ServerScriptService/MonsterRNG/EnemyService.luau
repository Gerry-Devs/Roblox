-- EnemyService: spawns enemies in every biome, runs the fights between
-- players' following pets and enemies, and hands out XP + loot.
-- Balance lives in Config.Combat / Config.EnemySpawns / Config.EnemySizes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))
local MonsterModel = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("MonsterModel"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local EnemyService = {}

local GROUND_Y = 1
local deps
local folder
local enemies = {}
local enemyById = {} -- EnemyId attribute -> enemy (players pick enemies by this id)
local nextEnemyId = 0
local attackOrders = {} -- player -> { [pet uid] = enemy }: pets only fight enemies they're sent to
local petHealth = {} -- pet uid -> { hp, max, lastHit }
local petNextAttack = {}
local dyingPets = {} -- pet uid -> true while it lies there for 2s before going to the pen
local rng = Random.new()

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function motor(name, p0, p1, c0)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.Parent = p0
	return m
end

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

local function rollFrom(list)
	local r = rng:NextNumber()
	local acc = 0
	for _, v in ipairs(list) do
		acc += v.chance
		if r < acc then
			return v
		end
	end
	return nil
end

local function weightedPick(weights)
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local r = rng:NextNumber() * total
	for key, w in pairs(weights) do
		r -= w
		if r <= 0 then
			return key
		end
	end
	return next(weights)
end

local function biomeBounds(biome)
	return biome.size.X / 2 - 64, biome.size.Y / 2 - 30
end

-- structures in a biome (landmark, props, mountains) enemies must not stand in
local structureParams = {}
local function getStructureParams(biome)
	local p = structureParams[biome.key]
	if p then
		return p
	end
	local list = {}
	local world = Workspace:FindFirstChild("MonsterRNGWorld")
	local model = world and world:FindFirstChild("Biome_" .. biome.key)
	if model then
		for _, n in ipairs({ "Landmark", "Props", "Mountain", "Decor" }) do
			local m = model:FindFirstChild(n)
			if m then
				table.insert(list, m)
			end
		end
	end
	p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = list
	structureParams[biome.key] = p
	return p
end

-- true if there's nothing taller than a puddle at this spot (and around it)
local function isOpenGround(biome, pos, radius)
	local params = getStructureParams(biome)
	for _, off in ipairs({ Vector3.zero, Vector3.new(radius, 0, 0), Vector3.new(-radius, 0, 0), Vector3.new(0, 0, radius), Vector3.new(0, 0, -radius) }) do
		local p = pos + off
		local hit = Workspace:Raycast(Vector3.new(p.X, 250, p.Z), Vector3.new(0, -300, 0), params)
		if hit and hit.Position.Y > GROUND_Y + 1 then
			return false
		end
	end
	return true
end

local function randomPoint(biome, radius)
	local hx, hz = biomeBounds(biome)
	local p
	for _ = 1, 30 do
		p = Vector3.new(biome.center.X + rng:NextNumber(-hx, hx), 0, biome.center.Y + rng:NextNumber(-hz, hz))
		if isOpenGround(biome, p, radius or 4) then
			return p
		end
	end
	return p
end

local function clampToBiome(biome, p)
	local hx, hz = biomeBounds(biome)
	return Vector3.new(math.clamp(p.X, biome.center.X - hx, biome.center.X + hx), 0, math.clamp(p.Z, biome.center.Y - hz, biome.center.Y + hz))
end

--------------------------------------------------------------------
-- enemy model: ball body (like the pets) with angry eyes, brows,
-- feet and horns (level 11+). Animated on each client.
--------------------------------------------------------------------
local function createEnemy(biome, def)
	local monsterId = def.monsters[rng:NextInteger(1, #def.monsters)]
	local monster = Config.GetMonster(monsterId)
	local rarity = Config.GetRarity(monster.rarity)
	local level = rng:NextInteger(def.min, def.max)
	local size = rollFrom(Config.EnemySizes)
	local finish = rollFrom(Config.EnemyFinishes)
	local mult = (size and size.mult or 1) * (finish and finish.mult or 1)
	local baseHp, baseDmg = Config.BaseCombatStats(level)
	local C = Config.Combat
	local levelBoost = 1 + (C.enemyLevelScaling or 0) * (level - 1)
	local maxHp = math.floor(baseHp * rng:NextNumber(C.enemyHealthMin, C.enemyHealthMax) * mult * levelBoost)
	local dmg = math.max(1, math.floor(baseDmg * C.enemyDamage * mult * (1 + (levelBoost - 1) * 0.5) + 0.5))

	local color, material = rgb(rarity.color), Enum.Material.SmoothPlastic
	if finish and finish.key == "Gold" then
		color, material = Color3.fromRGB(255, 190, 55), Enum.Material.Metal
	elseif finish and finish.key == "Silver" then
		color, material = Color3.fromRGB(211, 223, 239), Enum.Material.Metal
	elseif finish and finish.key == "Rainbow" then
		color, material = Color3.fromHSV(rng:NextNumber(), 0.8, 1), Enum.Material.Neon
	end
	local s = 4 * (size and size.scale or 1) * (1 + (rarity.tier - 1) * 0.06)
	local name = (size and (size.key .. " ") or "") .. (finish and (finish.key .. " ") or "") .. monster.name
	local pos = randomPoint(biome, s * 0.5 + 2)
	local y = GROUND_Y + s * 0.68

	local model = Instance.new("Model")
	model.Name = "Enemy"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	root.Parent = model

	-- cartoony studded monster model (animated on each client by MonsterAnimator)
	MonsterModel.Build(root, s, { monsterId = monsterId, groundOffset = s * 0.68, finish = finish and finish.key })

	-- name + health bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "EnemyBar"
	bb.Size = UDim2.fromOffset(80, 22)
	bb.StudsOffset = Vector3.new(0, s * 1.35 + 1, 0) -- above the model's head
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = root
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.fromScale(1, 0.52)
	label.BackgroundTransparency = 1
	label.Text = "Lv " .. level .. " " .. name
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = finish and color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(10, 15, 35)
	label.Parent = bb
	local barBg = Instance.new("Frame")
	barBg.Name = "Bar"
	barBg.Size = UDim2.fromScale(0.9, 0.32)
	barBg.Position = UDim2.fromScale(0.05, 0.6)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(10, 15, 35)
	stroke.Thickness = 2
	stroke.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 70, 70)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	model:SetAttribute("Health", maxHp)
	model:SetAttribute("MaxHealth", maxHp)
	model:SetAttribute("Level", level)
	model:SetAttribute("Finish", finish and finish.key or "Normal")
	model:SetAttribute("BodySize", s)
	model:SetAttribute("Hits", 0)
	model:SetAttribute("Attacks", 0)
	model:SetAttribute("Moving", false)
	nextEnemyId += 1
	model:SetAttribute("EnemyId", nextEnemyId)
	model.PrimaryPart = root
	-- with StreamingEnabled, send the whole enemy at once (never half-loaded)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = folder

	return {
		id = nextEnemyId,
		model = model, root = root, biome = biome, def = def, monsterId = monsterId, name = name,
		level = level, hp = maxHp, maxHp = maxHp, dmg = dmg, mult = mult, size = s, y = y,
		home = pos, wanderTarget = pos, nextWander = 0, nextAttack = 0, lastHitAt = 0,
		speed = size and size.key == "Titanic" and 5 or 7, damageBy = {}, dead = false,
	}
end

local function spawnEnemy(biome, def)
	local e = createEnemy(biome, def)
	enemyById[e.id] = e
	table.insert(enemies, e)
end

--------------------------------------------------------------------
-- movement: wander near home, chase the player it's fighting
--------------------------------------------------------------------
local function petBody(player, uid)
	local pen = player and WorldService.GetPen(player)
	local model = pen and uid and pen.pets:FindFirstChild(uid)
	if model and not model:GetAttribute("Defeated") and not model:GetAttribute("Dying") then
		return model:FindFirstChild("MonsterBody")
	end
	return nil
end

-- the pet this enemy is fighting; if it's gone, the nearest living pet
-- of the same player (only while that player's pets are out following)
local function getTargetPetBody(e)
	local pen = e.engaged and WorldService.GetPen(e.engaged)
	if not pen or pen.state.nearby then
		return nil
	end
	local body = petBody(e.engaged, e.targetPet)
	if body then
		return body
	end
	local best, bestD
	for _, model in ipairs(pen.pets:GetChildren()) do
		if model:GetAttribute("Kind") == "monster" and not model:GetAttribute("Defeated") and not model:GetAttribute("Dying") then
			local b = model:FindFirstChild("MonsterBody")
			if b then
				local d = (b.Position - e.root.Position).Magnitude
				if not bestD or d < bestD then
					best, bestD = b, d
					e.targetPet = model.Name
				end
			end
		end
	end
	return best
end

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- is this player standing in the enemy's own biome? (enemies never leave
-- their biome and forget you as soon as you walk out of it)
local function playerInBiome(player, biome)
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local b = Config.GetBiomeAt(hrp.Position.X, hrp.Position.Z)
	return b ~= nil and b.key == biome.key
end

-- placed gears
local taunts = {} -- { pos, expires }
local healZones = {} -- { player, pos, expires }
local TAUNT_RANGE, HEAL_RANGE = 32, 18

local function activeTaunt(e)
	local now = os.clock()
	for i = #taunts, 1, -1 do
		local t = taunts[i]
		if now > t.expires then
			table.remove(taunts, i)
		elseif flatDistance(t.pos, e.root.Position) < TAUNT_RANGE then
			return t
		end
	end
	return nil
end

local function inHealZone(player, pos)
	local now = os.clock()
	for i = #healZones, 1, -1 do
		local z = healZones[i]
		if now > z.expires then
			table.remove(healZones, i)
		elseif z.player == player and flatDistance(z.pos, pos) < HEAL_RANGE then
			return true
		end
	end
	return false
end

local function gearFolder()
	local f = Workspace:FindFirstChild("GearProps")
	if not f then
		f = Instance.new("Folder")
		f.Name = "GearProps"
		f.Parent = Workspace
	end
	return f
end

local function anchoredPart(parent, name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function EnemyService.AddTaunt(player, position, duration)
	local g = Vector3.new(position.X, GROUND_Y, position.Z)
	local m = Instance.new("Model")
	m.Name = "TauntTotem"
	anchoredPart(m, "Base", Vector3.new(4, 1, 4), CFrame.new(g + Vector3.new(0, 0.5, 0)), Color3.fromRGB(110, 105, 100))
	anchoredPart(m, "Pole", Vector3.new(1.6, 7, 1.6), CFrame.new(g + Vector3.new(0, 4.5, 0)), Color3.fromRGB(120, 80, 45))
	anchoredPart(m, "Head", Vector3.new(3.4, 3.4, 3.4), CFrame.new(g + Vector3.new(0, 9, 0)), Color3.fromRGB(215, 60, 50))
	for _, side in ipairs({ -1, 1 }) do
		anchoredPart(m, "Eye", Vector3.new(0.7, 0.9, 0.3), CFrame.new(g + Vector3.new(side * 0.7, 9.4, -1.75)), Color3.fromRGB(255, 240, 120), Enum.Material.Neon)
		anchoredPart(m, "Horn", Vector3.new(0.6, 1.8, 0.6), CFrame.new(g + Vector3.new(side * 1.2, 11.4, 0)) * CFrame.Angles(0, 0, math.rad(-side * 20)), Color3.fromRGB(240, 230, 210))
	end
	anchoredPart(m, "Banner", Vector3.new(2.8, 3, 0.2), CFrame.new(g + Vector3.new(0, 5.5, -0.9)), Color3.fromRGB(255, 200, 60))
	m.Parent = gearFolder()
	task.delay(duration, function()
		m:Destroy()
	end)
	table.insert(taunts, { pos = g, expires = os.clock() + duration })
end

function EnemyService.AddHealZone(player, position, duration)
	local g = Vector3.new(position.X, GROUND_Y, position.Z)
	local m = Instance.new("Model")
	m.Name = "HealingSpring"
	for i = 0, 7 do
		local a = math.rad(i * 45)
		anchoredPart(m, "Rim", Vector3.new(3, 1.2, 2), CFrame.new(g + Vector3.new(math.sin(a) * 6, 0.6, math.cos(a) * 6)) * CFrame.Angles(0, a, 0), Color3.fromRGB(150, 150, 160))
	end
	local water = anchoredPart(m, "Water", Vector3.new(11, 0.4, 11), CFrame.new(g + Vector3.new(0, 0.5, 0)), Color3.fromRGB(80, 230, 180), Enum.Material.Neon, 0.35)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(150, 255, 210)
	sparkles.Parent = water
	m.Parent = gearFolder()
	task.delay(duration, function()
		m:Destroy()
	end)
	table.insert(healZones, { player = player, pos = g, expires = os.clock() + duration })
end

local function moveEnemyTarget(e)
	local t = activeTaunt(e)
	return t and t.pos
end

local function moveEnemy(e, dt, now)
	local target, stopDist
	local tauntPos = moveEnemyTarget(e)
	if tauntPos then
		target, stopDist = tauntPos, e.size * 0.5 + 2.5
	elseif e.engaged then
		local body = getTargetPetBody(e)
		if body and flatDistance(body.Position, e.root.Position) < 70 and playerInBiome(e.engaged, e.biome) then
			-- chase, but never past the edge of its own biome
			target, stopDist = clampToBiome(e.biome, Vector3.new(body.Position.X, 0, body.Position.Z)), e.size * 0.5 + body.Size.X * 0.5 + 1.5
		else
			e.engaged = nil
			e.targetPet = nil
		end
	end
	if not target then
		-- out of the fight for a while: heal back up
		if now - e.lastHitAt > 8 and e.hp < e.maxHp then
			e.hp = e.maxHp
			e.damageBy = {}
			e.model:SetAttribute("Health", e.maxHp)
		end
		if now > e.nextWander then
			local t = clampToBiome(e.biome, e.home + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25)))
			if isOpenGround(e.biome, t, e.size * 0.5 + 1) then
				e.wanderTarget = t
			end
			e.nextWander = now + rng:NextNumber(3, 7)
		end
		target, stopDist = e.wanderTarget, 1
	end
	local cur = Vector3.new(e.root.Position.X, 0, e.root.Position.Z)
	local d = target - cur
	local moving = false
	if d.Magnitude > stopDist then
		cur += d.Unit * math.min(d.Magnitude - stopDist, e.speed * dt)
		moving = true
	end
	local look = d.Magnitude > 0.1 and d.Unit or e.root.CFrame.LookVector
	e.root.CFrame = CFrame.lookAt(Vector3.new(cur.X, e.y, cur.Z), Vector3.new(cur.X + look.X, e.y, cur.Z + look.Z))
	if e.model:GetAttribute("Moving") ~= moving then
		e.model:SetAttribute("Moving", moving)
	end
end

--------------------------------------------------------------------
-- rewards
--------------------------------------------------------------------
local function rewardPlayer(player, profile, e, rec, xpTotal, pos)
	local now = os.time()
	local xpMult = (Config.IsBoostActive(profile, "level", now) and 2 or 1) * Config.GlobalBoost("exp", now)
	local leveled = {}
	for uid, dmg in pairs(rec.pets) do
		local share = dmg / math.max(1, rec.total)
		for _, entry in ipairs(profile.base) do
			if entry.uid == uid and entry.kind == "monster" then
				entry.xp = (entry.xp or 0) + math.max(1, math.floor(xpTotal * share * xpMult))
				while (entry.level or 1) < Config.Combat.maxLevel and entry.xp >= Config.XpForLevel(entry.level or 1) do
					entry.xp -= Config.XpForLevel(entry.level or 1)
					entry.level = (entry.level or 1) + 1
					table.insert(leveled, { name = Config.GetMonster(entry.monsterId).name, level = entry.level })
					if petHealth[uid] then
						petHealth[uid].hp = math.huge -- full heal on level up
					end
				end
			end
		end
	end

	local drops = {}
	-- special enemies drop more; every unlocked biome adds +10% drop chance
	local bonus = math.sqrt(e.mult) * (1 + Config.GetBiomeBonusCount(profile) * Config.BiomeBonus.drops / 100)
	local C = Config.Combat
	-- upgrades: Drops (+shard chance), Potion Drop (+potion chance), Rift Shards (+amount)
	local shardChanceBonus = 1 + Config.GetUpgradeBonus(profile.upgrades, "drops") / 100
	local potionChanceBonus = 1 + Config.GetUpgradeBonus(profile.upgrades, "potionDrop") / 100
	local shardAmountBonus = 1 + Config.GetUpgradeBonus(profile.upgrades, "crystal") / 100
	bonus = bonus * Config.PassDropMultiplier(profile) -- More Drops / Supporter gamepasses
		if rng:NextNumber() < math.min(1, C.shardChance * bonus * shardChanceBonus) then
		local n = math.floor((1 + math.floor(e.level / 5)) * math.max(1, math.floor(e.mult)) * shardAmountBonus + 0.5)
		-- Shard Surge upgrade: chance to double the drop
		if rng:NextNumber() < Config.GetUpgradeBonus(profile.upgrades, "shardSurge") / 100 then
			n *= 2
		end
		profile.riftShards = (profile.riftShards or 0) + n
		table.insert(drops, { kind = "shards", amount = n })
	end
	if rng:NextNumber() < C.potionChance * bonus * potionChanceBonus then
		local key = weightedPick(C.potionWeights)
		profile.potions[key] = (profile.potions[key] or 0) + 1
		table.insert(drops, { kind = "potion", key = key })
	end
	if rng:NextNumber() < C.warpRemoteChance * bonus then
		profile.items.warpRemote = (profile.items.warpRemote or 0) + 1
		table.insert(drops, { kind = "item", key = "warpRemote" })
	end
	-- Gift Card: very rare, only for Rebirth 3+
	if (profile.rebirths or 0) >= (C.giftCardMinRebirth or 3) and rng:NextNumber() < C.giftCardChance * bonus then
		profile.items.giftCard = (profile.items.giftCard or 0) + 1
		table.insert(drops, { kind = "item", key = "giftCard" })
	end
	profile.enemyKills[e.monsterId] = (profile.enemyKills[e.monsterId] or 0) + 1
	require(script.Parent:WaitForChild("QuestService")).Add(profile, "kills", 1)

	if #leveled > 0 then
		WorldService.UpdateBase(player, profile)
	end
	deps.sync(player)
	deps.fx:FireClient(player, { kind = "kill", position = pos, xp = xpTotal, drops = drops, levelUps = leveled, name = e.name })
end

local function killEnemy(e)
	if e.dead then
		return
	end
	e.dead = true
	enemyById[e.id] = nil
	e.model:SetAttribute("Dead", true)
	local pos = e.root.Position
	local xpTotal = Config.EnemyXp(e.level, e.mult)
	for player, rec in pairs(e.damageBy) do
		local profile = DataService.Get(player)
		if profile and player.Parent then
			rewardPlayer(player, profile, e, rec, xpTotal, pos)
		end
	end
	task.delay(0.7, function()
		e.model:Destroy()
	end)
	task.delay(Config.Combat.respawnTime, function()
		local idx = table.find(enemies, e)
		if idx then
			table.remove(enemies, idx)
		end
		spawnEnemy(e.biome, e.def)
	end)
end

local function damageEnemy(e, player, uid, dmg, now)
	e.hp -= dmg
	e.lastHitAt = now
	local rec = e.damageBy[player] or { total = 0, pets = {} }
	e.damageBy[player] = rec
	rec.total += dmg
	rec.pets[uid] = (rec.pets[uid] or 0) + dmg
	e.model:SetAttribute("Health", math.max(0, math.floor(e.hp)))
	e.model:SetAttribute("Hits", (e.model:GetAttribute("Hits") or 0) + 1)
	if e.hp <= 0 then
		killEnemy(e)
	end
end

--------------------------------------------------------------------
-- combat tick (every 0.2s)
--------------------------------------------------------------------
local function combatTick(now)
	local t = os.time()
	local C = Config.Combat
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(player)
		local pen = WorldService.GetPen(player)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if profile and pen and hrp then
			-- pets only fight enemies the player sent them to (tap an enemy ->
			-- attack menu), and only while they're out following the player
			local orders = attackOrders[player] or {}
			attackOrders[player] = orders
			local here = Config.GetBiomeAt(hrp.Position.X, hrp.Position.Z)

			local pets = {}
			for _, entry in ipairs(profile.base) do
				if entry.kind == "monster" and not entry.defeated and not dyingPets[entry.uid] then
					local maxHp, dmg = Config.GetPetStats(entry, profile, t)
					local st = petHealth[entry.uid]
					if not st then
						st = { hp = maxHp, max = maxHp, lastHit = 0 }
						petHealth[entry.uid] = st
					end
					if st.max ~= maxHp then
						st.hp = math.min(maxHp, st.hp * maxHp / math.max(1, st.max))
						st.max = maxHp
					end
					st.hp = math.min(st.hp, st.max)
					table.insert(pets, { entry = entry, st = st, dmg = dmg })
				end
			end

			-- each pet goes for the enemy it was sent to; the order ends when the
			-- enemy dies, you leave its biome, walk far away or go back to the pen
			local assigned, targets = {}, {}
			local living = {}
			for _, p in ipairs(pets) do
				local uid = p.entry.uid
				living[uid] = true
				local pick = orders[uid]
				if pick and (pick.dead or pen.state.nearby or not here or pick.biome.key ~= here.key
					or flatDistance(pick.root.Position, hrp.Position) > (C.leashRange or 80)) then
					orders[uid] = nil
					pick = nil
				end
				assigned[uid] = pick
				if pick then
					targets[uid] = { Vector3.new(pick.root.Position.X, 0, pick.root.Position.Z), pick.size * 0.5 }
				end
				local model = pen.pets:FindFirstChild(uid)
				local targetId = pick and pick.id or 0
				if model and model:GetAttribute("AttackTarget") ~= targetId then
					model:SetAttribute("AttackTarget", targetId)
				end
			end
			-- defeated / removed pets forget their orders
			for uid in pairs(orders) do
				if not living[uid] then
					orders[uid] = nil
				end
			end
			WorldService.SetPetTargets(player, targets)

			for _, p in ipairs(pets) do
				local best = assigned[p.entry.uid]
				if best and not best.dead then
					local model = pen.pets:FindFirstChild(p.entry.uid)
					local body = model and model:FindFirstChild("MonsterBody")
					-- a pet only hits once it has actually reached its enemy
					if body and now >= (petNextAttack[p.entry.uid] or 0)
						and flatDistance(body.Position, best.root.Position) <= best.size * 0.5 + body.Size.X * 0.5 + 4 then
						petNextAttack[p.entry.uid] = now + C.petAttackInterval * rng:NextNumber(0.9, 1.1)
						p.st.lastHit = now
						model:SetAttribute("LungeAt", now)
						-- the first pet to hit an enemy is the one it fights back
						if not best.engaged then
							best.engaged = player
							best.targetPet = p.entry.uid
						end
						-- the hit lands at the impact of the attack animation, not when it starts
						local target, uid, dmg = best, p.entry.uid, p.dmg
						-- critical hit
						local critChance, critMult = Config.CritStats(profile)
						if rng:NextNumber() < critChance then
							dmg *= critMult
							model:SetAttribute("CritAt", now) -- the pet plays its critical-hit move
							require(script.Parent:WaitForChild("QuestService")).Add(profile, "crits", 1)
							target.model:SetAttribute("CritHitAt", workspace:GetServerTimeNow() + 0.22) -- "CRITICAL!" pops over the enemy
						end
						task.delay(0.22, function()
							if not target.dead then
								damageEnemy(target, player, uid, dmg, now + 0.22)
							end
						end)
					end
				end
			end

			for _, p in ipairs(pets) do
				local springModel = pen.pets:FindFirstChild(p.entry.uid)
				local springBody = springModel and springModel:FindFirstChild("MonsterBody")
				if springBody and inHealZone(player, springBody.Position) then
					p.st.hp = math.min(p.st.max, p.st.hp + p.st.max * 0.15 * 0.2)
				end
				if now - p.st.lastHit > C.regenDelay and p.st.hp < p.st.max then
					p.st.hp = math.min(p.st.max, p.st.hp + p.st.max * C.regenPerSecond * 0.2)
				end
				local model = pen.pets:FindFirstChild(p.entry.uid)
				if model then
					local h = math.floor(p.st.hp)
					if model:GetAttribute("Health") ~= h then
						model:SetAttribute("Health", h)
					end
					if model:GetAttribute("MaxHealth") ~= p.st.max then
						model:SetAttribute("MaxHealth", p.st.max)
					end
				end
			end
		end
	end

	-- enemies hit the pet they're fighting once it's in reach
	for _, e in ipairs(enemies) do
		if not e.dead and e.engaged and not playerInBiome(e.engaged, e.biome) then
			-- you left its biome: it gives up and goes home
			e.engaged = nil
			e.targetPet = nil
		end
		if not e.dead and e.engaged and now >= e.nextAttack then
			local taunt = activeTaunt(e)
			if taunt then
				e.nextAttack = now + C.enemyAttackInterval
				if flatDistance(taunt.pos, e.root.Position) <= e.size * 0.5 + 4 then
					e.model:SetAttribute("Attacks", (e.model:GetAttribute("Attacks") or 0) + 1)
				end
				continue
			end
			local player = e.engaged
			local profile = DataService.Get(player)
			local body = getTargetPetBody(e)
			if profile and body then
				if flatDistance(body.Position, e.root.Position) <= e.size * 0.5 + body.Size.X * 0.5 + 5 then
					e.nextAttack = now + C.enemyAttackInterval
					local victim
					for _, entry in ipairs(profile.base) do
						if entry.uid == e.targetPet then
							victim = entry
						end
					end
					local st = victim and petHealth[victim.uid]
					if st and not victim.defeated then
						st.hp -= e.dmg
						st.lastHit = now
						e.model:SetAttribute("Attacks", (e.model:GetAttribute("Attacks") or 0) + 1)
						if st.hp <= 0 then
							-- defeated: plays its death where it fell for 2s, then goes
							-- back to the pen (grey, still earns cash, recovers over time)
							petHealth[victim.uid] = nil
							e.targetPet = nil
							dyingPets[victim.uid] = true
							local pen = WorldService.GetPen(player)
							local petModel = pen and pen.pets:FindFirstChild(victim.uid)
							if petModel then
								petModel:SetAttribute("Health", 0) -- bar shows empty
								petModel:SetAttribute("Dying", true)
							end
							task.delay(2, function()
								dyingPets[victim.uid] = nil
								victim.defeated = true
								victim.defeatedAt = os.time()
								WorldService.UpdateBase(player, profile)
								deps.sync(player)
							end)
							local monster = Config.GetMonster(victim.monsterId)
							deps.fx:FireClient(player, {
								kind = "defeated",
								name = Config.BuildDisplayName(monster and monster.name or "Pet", victim.size, victim.finish),
								recoverIn = Config.GetReviveTime(victim.level),
							})
						end
					end
				else
					e.nextAttack = now + 0.2
				end
			else
				e.nextAttack = now + 0.5
			end
		end
	end
end

function EnemyService.ResetPet(uid)
	petHealth[uid] = nil
end

function EnemyService.Start(d)
	deps = d
	folder = Workspace:FindFirstChild("Enemies")
	if folder then
		folder:ClearAllChildren()
	else
		folder = Instance.new("Folder")
		folder.Name = "Enemies"
		folder.Parent = Workspace
	end
	for _, biome in ipairs(Config.Biomes) do
		local def = Config.EnemySpawns[biome.key]
		if def then
			for _ = 1, def.count do
				spawnEnemy(biome, def)
			end
		end
	end

	local moveAcc, combatAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		moveAcc += dt
		combatAcc += dt
		local now = os.clock()
		if moveAcc >= 0.1 then
			local step = moveAcc
			moveAcc = 0
			local playerPositions = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r then
					table.insert(playerPositions, r.Position)
				end
			end
			for _, e in ipairs(enemies) do
				if not e.dead then
					-- only move enemies someone could see (saves server work)
					local active = e.engaged ~= nil
					if not active then
						for _, pp in ipairs(playerPositions) do
							if (pp - e.root.Position).Magnitude < 220 then
								active = true
								break
							end
						end
					end
					if active then
						moveEnemy(e, step, now)
					end
				end
			end
		end
		if combatAcc >= 0.2 then
			combatAcc = 0
			combatTick(now)
		end
	end)

	-- defeated pets recover on their own after Config.Combat.reviveTime
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.Get(player)
				if profile then
					local changed = false
					for _, list in ipairs({ profile.base, profile.monsters }) do
						for _, e in ipairs(list) do
							if e.defeated then
								e.defeatedAt = e.defeatedAt or now
								if now - e.defeatedAt >= Config.GetReviveTime(e.level) * (Config.IsBoostActive(profile, "campfire", now) and 0.5 or 1) then
									e.defeated = nil
									e.defeatedAt = nil
									petHealth[e.uid] = nil
									changed = true
								end
							end
						end
					end
					if changed then
						WorldService.UpdateBase(player, profile)
						deps.sync(player)
						deps.fx:FireClient(player, { kind = "recovered" })
					end
				end
			end
		end
	end)

	-- Attack menu: tap an enemy, then send ALL your pets, ONE pet, or call
	-- them back. mode = "all" | "one" (uid) | "stop" (this enemy) | "recall"
	local remotes = ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Remotes")
	local attackRemote = remotes:FindFirstChild("AttackEnemy") or Instance.new("RemoteFunction")
	attackRemote.Name = "AttackEnemy"
	attackRemote.Parent = remotes
	local lastOrderAt = {}
	attackRemote.OnServerInvoke = function(player, enemyId, mode, uid)
		local now = os.clock()
		if now - (lastOrderAt[player] or 0) < 0.15 then
			return { success = false, message = "" }
		end
		lastOrderAt[player] = now
		if type(mode) ~= "string" then
			return { success = false, message = "" }
		end
		local profile = DataService.Get(player)
		local pen = WorldService.GetPen(player)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not profile or not pen or not hrp then
			return { success = false, message = "" }
		end
		local orders = attackOrders[player] or {}
		attackOrders[player] = orders

		if mode == "recall" then
			table.clear(orders)
			return { success = true, message = "Your pets are coming back." }
		end

		local e = type(enemyId) == "number" and enemyById[enemyId] or nil
		if not e or e.dead then
			return { success = false, message = "That enemy is already gone." }
		end
		if mode == "stop" then
			for petUid, target in pairs(orders) do
				if target == e then
					orders[petUid] = nil
				end
			end
			return { success = true, message = "Your pets stopped attacking." }
		end
		if pen.state.nearby then
			return { success = false, message = "Your pets are resting in your pen. Walk away from it so they follow you!" }
		end
		local here = Config.GetBiomeAt(hrp.Position.X, hrp.Position.Z)
		if not here or here.key ~= e.biome.key then
			return { success = false, message = "Walk into that enemy's area first." }
		end
		if flatDistance(e.root.Position, hrp.Position) > (Config.Combat.orderRange or 35) + 8 then -- a little slack for lag
			return { success = false, message = "Get closer to that enemy first." }
		end

		local ready = {}
		for _, entry in ipairs(profile.base) do
			if entry.kind == "monster" and not entry.defeated and not dyingPets[entry.uid] then
				ready[entry.uid] = true
			end
		end
		if next(ready) == nil then
			return { success = false, message = "You have no pets that can fight right now." }
		end

		local sent = 0
		if mode == "all" then
			for petUid in pairs(ready) do
				orders[petUid] = e
				sent += 1
			end
		elseif mode == "one" then
			if type(uid) ~= "string" or not ready[uid] then
				return { success = false, message = "That pet can't fight right now." }
			end
			orders[uid] = e
			sent = 1
		else
			return { success = false, message = "" }
		end
		return { success = true, message = sent == 1 and "1 pet is attacking!" or (sent .. " pets are attacking!") }
	end

	Players.PlayerRemoving:Connect(function(player)
		attackOrders[player] = nil
		lastOrderAt[player] = nil
		for _, e in ipairs(enemies) do
			if e.engaged == player then
				e.engaged = nil
			end
			e.damageBy[player] = nil
		end
	end)
end

return EnemyService
