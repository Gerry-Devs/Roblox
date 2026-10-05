-- EnemyService: spawns enemies in every biome, runs the fights between
-- players' following pets and enemies, and hands out XP + loot.
-- Balance lives in Config.Combat / Config.EnemySpawns / Config.EnemySizes.
local addLoot -- (loot on the ground, below)
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
local onBossDown -- (world bosses, below)
local onHitSkills -- (defined below, used in the combat tick)
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
-- opts (world bosses / their helpers): { boss = def, monsterId, level,
-- pos, finish = key }
local function createEnemy(biome, def, opts)
	opts = opts or {}
	local boss = opts.boss
	local monsterId = opts.monsterId or def.monsters[rng:NextInteger(1, #def.monsters)]
	local monster = Config.GetMonster(monsterId)
	local rarity = Config.GetRarity(monster.rarity)
	local level = opts.level or rng:NextInteger(def.min, def.max)
	local size = (not boss) and rollFrom(Config.EnemySizes) or nil
	local finish = (not boss) and rollFrom(Config.EnemyFinishes) or nil
	if boss and opts.finish then
		finish = { key = opts.finish, mult = 1 }
	end
	local mult = (size and size.mult or 1) * (finish and finish.mult or 1)
	local baseHp, baseDmg = Config.BaseCombatStats(level)
	local C = Config.Combat
	local levelBoost = 1 + (C.enemyLevelScaling or 0) * (level - 1)
	local maxHp = math.floor(baseHp * rng:NextNumber(C.enemyHealthMin, C.enemyHealthMax) * mult * levelBoost)
	local dmg = math.max(1, math.floor(baseDmg * C.enemyDamage * mult * (1 + (levelBoost - 1) * 0.5) + 0.5))
	if boss then
		maxHp = math.floor(maxHp * Config.WorldBosses.hpMult)
		dmg = math.floor(dmg * Config.WorldBosses.dmgMult)
	end

	local color, material = rgb(rarity.color), Enum.Material.SmoothPlastic
	if finish and finish.key == "Gold" then
		color, material = Color3.fromRGB(255, 190, 55), Enum.Material.Metal
	elseif finish and finish.key == "Silver" then
		color, material = Color3.fromRGB(211, 223, 239), Enum.Material.Metal
	elseif finish and finish.key == "Rainbow" then
		color, material = Color3.fromHSV(rng:NextNumber(), 0.8, 1), Enum.Material.Neon
	end
	local s = boss and Config.WorldBosses.size or 4 * (size and size.scale or 1) * (1 + (rarity.tier - 1) * 0.06)
	local name = boss and boss.name:upper() or ((size and (size.key .. " ") or "") .. (finish and (finish.key .. " ") or "") .. monster.name)
	local pos = opts.pos or randomPoint(biome, s * 0.5 + 2)
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
	bb.Size = boss and UDim2.fromOffset(240, 46) or UDim2.fromOffset(80, 22)
	bb.StudsOffset = Vector3.new(0, s * 1.35 + 1, 0) -- above the model's head
	bb.MaxDistance = boss and 400 or 90
	bb.LightInfluence = 0
	bb.Parent = root
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.fromScale(1, 0.52)
	label.BackgroundTransparency = 1
	label.Text = boss and ("\u{1F451} " .. name .. "  Lv " .. level) or ("Lv " .. level .. " " .. name)
	if boss then
		label.TextColor3 = rgb(boss.color)
	end
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = boss and rgb(boss.color) or (finish and color or Color3.new(1, 1, 1))
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
	if boss then
		model:SetAttribute("Boss", boss.name)
	end
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
		speed = boss and 6 or (size and size.key == "Titanic" and 5 or 7), damageBy = {}, dead = false,
		boss = boss,
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
		if not e.boss and now - e.lastHitAt > 8 and e.hp < e.maxHp then
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
-- loot on the ground (Rift Shards / potions). Each player has their own
-- loot; it's given when they walk up to it (the client sends PickupLoot)
-- and disappears after Config.Loot.lifetime seconds.
--------------------------------------------------------------------
local lootByPlayer = {} -- player -> { [id] = { kind, key, amount, pos, at } }
local nextLootId = 0
addLoot = function(player, drop, pos)
	nextLootId += 1
	drop.id = nextLootId
	local list = lootByPlayer[player] or {}
	lootByPlayer[player] = list
	list[drop.id] = { kind = drop.kind, key = drop.key, amount = drop.amount, pos = pos, at = os.clock() }
end
local function pickupLoot(player, id)
	local list = lootByPlayer[player]
	local loot = list and type(id) == "number" and list[id]
	if not loot then
		return nil
	end
	local profile = DataService.Get(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not profile or not hrp then
		return nil
	end
	-- the loot lands a few studs from where the enemy died
	if (hrp.Position - loot.pos).Magnitude > (Config.Loot.pickupCheck or 40) then
		return nil
	end
	list[id] = nil
	if loot.kind == "shards" then
		profile.riftShards = (profile.riftShards or 0) + (loot.amount or 1)
	elseif loot.kind == "potion" then
		profile.potions[loot.key] = (profile.potions[loot.key] or 0) + 1
	elseif loot.kind == "item" and type(loot.key) == "string" and Config.Items[loot.key] then
		profile.items[loot.key] = (profile.items[loot.key] or 0) + 1
	end
	return loot
end

--------------------------------------------------------------------
-- rewards
--------------------------------------------------------------------
local function rewardPlayer(player, profile, e, rec, xpTotal, pos)
	local now = os.time()
	local xpMult = (Config.IsBoostActive(profile, "level", now) and 2 or 1) * Config.GlobalBoost("exp", now) * (1 + Config.Skill(profile, "xp") / 100)
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
	bonus *= Config.GlobalBoost("drops", now) -- admin panel: server-wide Drops effect
	local C = Config.Combat
	-- upgrades: Drops (+shard chance), Potion Drop (+potion chance), Rift Shards (+amount)
	-- (+ skills: Fetch, Jade Fortune, Void Rift)
	local shardChanceBonus = 1 + (Config.GetUpgradeBonus(profile.upgrades, "drops") + Config.Skill(profile, "shardChance")) / 100
	local potionChanceBonus = 1 + (Config.GetUpgradeBonus(profile.upgrades, "potionDrop") + Config.Skill(profile, "potionDrop")) / 100
	local shardAmountBonus = 1 + (Config.GetUpgradeBonus(profile.upgrades, "crystal") + Config.Skill(profile, "shardAmount")) / 100
	-- rebirths: +25% Rift Shards each
	shardAmountBonus *= 1 + (profile.rebirths or 0) * (Config.Rebirth.shardBonus or 0) / 100
	-- harder biomes: +20% Rift Shards for each biome after the first
	shardAmountBonus *= 1 + Config.BiomeStep(e.biome and e.biome.key) * (Config.Rebirth.biomeShardBonus or 0) / 100
	bonus = bonus * Config.PassDropMultiplier(profile) -- More Drops / Supporter gamepasses
		if rng:NextNumber() < math.min(1, C.shardChance * bonus * shardChanceBonus) then
		local n = math.floor((1 + math.floor(e.level / 5)) * math.max(1, math.floor(e.mult)) * shardAmountBonus + 0.5)
		-- Shard Surge upgrade: chance to double the drop
		if rng:NextNumber() < Config.GetUpgradeBonus(profile.upgrades, "shardSurge") / 100 then
			n *= 2
		end
		table.insert(drops, { kind = "shards", amount = n })
	end
	if rng:NextNumber() < C.potionChance * bonus * potionChanceBonus then
		local key = weightedPick(C.potionWeights)
		table.insert(drops, { kind = "potion", key = key })
	end
	-- (Warp Remote / Gift Card: bought in the Gear Shop now, not dropped)
	-- world boss: lots of shards, potions, and maybe a Fusion Ticket
	if e.boss then
		local n = math.floor((1 + math.floor(e.level / 5)) * 25 * shardAmountBonus + 0.5)
		table.insert(drops, { kind = "shards", amount = n })
		for _ = 1, 3 do
			table.insert(drops, { kind = "potion", key = weightedPick(C.potionWeights) })
		end
		if rng:NextNumber() < Config.WorldBosses.fusionTicketChance then
			table.insert(drops, { kind = "item", key = "fusionTicket" })
		end
	end
	-- Soul Harvest skill: chance every drop comes twice
	if #drops > 0 and rng:NextNumber() * 100 < Config.Skill(profile, "doubleLoot") then
		for _, dr in ipairs(table.clone(drops)) do
			table.insert(drops, table.clone(dr))
		end
	end
	-- the drops fly out onto the ground; they're only given when the
	-- player walks over to them (PickupLoot)
	for _, dr in ipairs(drops) do
		addLoot(player, dr, pos)
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
	if e.boss or e.minion then
		local idx = table.find(enemies, e)
		if idx then
			table.remove(enemies, idx)
		end
		if e.boss and onBossDown then
			onBossDown(e, true)
		end
		return
	end
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
-- skills that trigger when a pet hits (Double Wave, Burn, Venom Bite,
-- Freeze). Burn / poison tick every second for 3 seconds.
--------------------------------------------------------------------
onHitSkills = function(e, player, profile, uid, dmg)
	local now = os.clock()
	if rng:NextNumber() * 100 < Config.Skill(profile, "doubleHit") then
		task.delay(0.2, function()
			if not e.dead then
				damageEnemy(e, player, uid, dmg, os.clock())
			end
		end)
	end
	local burn = Config.Skill(profile, "burn")
	if burn > 0 then
		e.burn = { dps = dmg * burn / 100, untilAt = now + 3, player = player, uid = uid }
	end
	local venom = Config.Skill(profile, "venom")
	if venom > 0 then
		-- a % of the enemy's max HP per second, but never more than 2 hits' worth
		e.venom = { dps = math.min(e.maxHp * venom / 100, dmg * 2), untilAt = now + 3, player = player, uid = uid }
	end
	if not (e.frozenUntil and now < e.frozenUntil) and rng:NextNumber() * 100 < Config.Skill(profile, "freeze") then
		e.frozenUntil = now + 2
		e.model:SetAttribute("FrozenUntil", workspace:GetServerTimeNow() + 2)
	end
end

local lastDotAt = 0
local function tickDots(now)
	if now - lastDotAt < 1 then
		return
	end
	lastDotAt = now
	for _, e in ipairs(enemies) do
		for _, key in ipairs({ "burn", "venom" }) do
			local d = e[key]
			if d and not e.dead then
				if now > d.untilAt or not d.player.Parent then
					e[key] = nil
				else
					damageEnemy(e, d.player, d.uid, d.dps, now)
				end
			end
		end
	end
end

--------------------------------------------------------------------
-- combat tick (every 0.2s)
--------------------------------------------------------------------
local function combatTick(now)
	tickDots(now)
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
					targets[uid] = { Vector3.new(pick.root.Position.X, 0, pick.root.Position.Z), pick.size * 0.5, Config.RangedPets[p.entry.monsterId] and C.rangedExtra or 0 }
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
					-- ranged pets (phoenix, void dragon) hit from further back
					local ranged = Config.RangedPets[p.entry.monsterId] and C.rangedExtra or 0
					if body and now >= (petNextAttack[p.entry.uid] or 0)
						and flatDistance(body.Position, best.root.Position) <= best.size * 0.5 + body.Size.X * 0.5 + 4 + ranged then
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
								onHitSkills(target, player, profile, uid, dmg)
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
					p.st.hp = math.min(p.st.max, p.st.hp + p.st.max * C.regenPerSecond * (1 + Config.Skill(profile, "regen") / 100) * 0.2)
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
				-- ranged pets stand further back, but the enemy can still hit them
				local reach = e.size * 0.5 + body.Size.X * 0.5 + 5
				if Config.RangedPets[body:GetAttribute("RigId")] then
					reach += C.rangedExtra
				end
				if e.frozenUntil and now < e.frozenUntil then
					e.nextAttack = e.frozenUntil -- frozen (Freeze skill)
				elseif flatDistance(body.Position, e.root.Position) <= reach then
					-- Chill skill: the enemy you fight attacks slower
					e.nextAttack = now + C.enemyAttackInterval * (1 + Config.Skill(profile, "chill") / 100)
					local victim
					for _, entry in ipairs(profile.base) do
						if entry.uid == e.targetPet then
							victim = entry
						end
					end
					local st = victim and petHealth[victim.uid]
					if st and not victim.defeated then
						local hit = e.dmg * (1 - Config.Skill(profile, "armor") / 100) -- Unbreakable skill
						if rng:NextNumber() * 100 < Config.Skill(profile, "block") then
							hit = 0 -- Guardian skill: blocked
						end
						st.hp -= hit
						st.lastHit = now
						-- Thorns skill: part of the hit goes back to the enemy
						local thorns = Config.Skill(profile, "thorns")
						if thorns > 0 and hit > 0 then
							damageEnemy(e, player, victim.uid, e.dmg * thorns / 100, now)
						end
						-- Rebirth Flame skill: chance a pet that would fall gets back up
						if st.hp <= 0 and rng:NextNumber() * 100 < Config.Skill(profile, "revive") then
							st.hp = st.max * 0.5
						end
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

--------------------------------------------------------------------
-- World bosses (Config.WorldBosses): each server rolls its own boss
-- right after night. Specials hit every pet near the boss.
--------------------------------------------------------------------
local bossRemote -- RemoteEvent "WorldBoss" (announcements + attack effects)
local currentBoss

-- a boss special hits one pet (same rules as a normal enemy hit)
local function bossHitPet(e, player, profile, entry, amount, now)
	local st = petHealth[entry.uid]
	if not st or entry.defeated or dyingPets[entry.uid] then
		return
	end
	local hit = amount * (1 - Config.Skill(profile, "armor") / 100)
	if rng:NextNumber() * 100 < Config.Skill(profile, "block") then
		hit = 0
	end
	st.hp -= hit
	st.lastHit = now
	if st.hp <= 0 and rng:NextNumber() * 100 < Config.Skill(profile, "revive") then
		st.hp = st.max * 0.5
	end
	if st.hp <= 0 then
		petHealth[entry.uid] = nil
		dyingPets[entry.uid] = true
		local pen = WorldService.GetPen(player)
		local petModel = pen and pen.pets:FindFirstChild(entry.uid)
		if petModel then
			petModel:SetAttribute("Health", 0)
			petModel:SetAttribute("Dying", true)
		end
		task.delay(2, function()
			dyingPets[entry.uid] = nil
			entry.defeated = true
			entry.defeatedAt = os.time()
			WorldService.UpdateBase(player, profile)
			deps.sync(player)
		end)
		local monster = Config.GetMonster(entry.monsterId)
		deps.fx:FireClient(player, { kind = "defeated", name = Config.BuildDisplayName(monster and monster.name or "Pet", entry.size, entry.finish), recoverIn = Config.GetReviveTime(entry.level) })
	end
end

-- every pet (of any player) within radius of the boss
local function petsNear(e, radius)
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(player)
		local pen = WorldService.GetPen(player)
		if profile and pen and not pen.state.nearby then
			for _, entry in ipairs(profile.base) do
				if entry.kind == "monster" and not entry.defeated then
					local model = pen.pets:FindFirstChild(entry.uid)
					local body = model and model:FindFirstChild("MonsterBody")
					if body and flatDistance(body.Position, e.root.Position) <= radius then
						table.insert(out, { player = player, profile = profile, entry = entry })
					end
				end
			end
		end
	end
	return out
end

-- attack effects for everyone in the boss's biome
local function bossFx(e, data)
	data.position = e.root.Position
	data.boss = e.boss.name
	data.color = e.boss.color
	for _, player in ipairs(Players:GetPlayers()) do
		if playerInBiome(player, e.biome) then
			bossRemote:FireClient(player, data)
		end
	end
end

local function bossSpecials(e, now)
	if e.dead or not e.boss then
		return
	end
	local W = Config.WorldBosses
	-- the ultimate: warned 2 s before, then a big critical hit around it
	if now >= (e.nextUltimate or 0) and e.engaged then
		e.nextUltimate = now + W.ultimateEvery
		e.nextSpecial = now + W.attackEvery
		local radius = e.size * 2.5
		bossFx(e, { kind = "warn", name = e.boss.ultimate, radius = radius, time = 2 })
		task.delay(2, function()
			if e.dead then
				return
			end
			e.model:SetAttribute("Attacks", (e.model:GetAttribute("Attacks") or 0) + 1)
			e.model:SetAttribute("CritAt", workspace:GetServerTimeNow())
			bossFx(e, { kind = "ultimate", name = e.boss.ultimate, radius = radius })
			for _, t in ipairs(petsNear(e, radius)) do
				bossHitPet(e, t.player, t.profile, t.entry, e.dmg * W.ultimateDmg, os.clock())
			end
		end)
		return
	end
	if now < (e.nextSpecial or 0) or not e.engaged then
		return
	end
	e.nextSpecial = now + W.attackEvery
	e.special = ((e.special or 0) % 3) + 1
	e.model:SetAttribute("Attacks", (e.model:GetAttribute("Attacks") or 0) + 1)
	if e.special == 1 then
		-- slam: every pet near it
		local radius = e.size * 1.6
		bossFx(e, { kind = "slam", name = e.boss.slam, radius = radius })
		for _, t in ipairs(petsNear(e, radius)) do
			bossHitPet(e, t.player, t.profile, t.entry, e.dmg * W.slamDmg, now)
		end
	elseif e.special == 2 then
		-- beam: the pet it's fighting, hard
		local player = e.engaged
		local profile = player and DataService.Get(player)
		local victim
		for _, entry in ipairs(profile and profile.base or {}) do
			if entry.uid == e.targetPet then
				victim = entry
			end
		end
		if victim then
			local pen = WorldService.GetPen(player)
			local model = pen and pen.pets:FindFirstChild(victim.uid)
			local body = model and model:FindFirstChild("MonsterBody")
			bossFx(e, { kind = "beam", name = e.boss.beam, target = body and body.Position })
			bossHitPet(e, player, profile, victim, e.dmg * W.beamDmg, now)
		end
	else
		-- summon: up to W.maxHelpers helpers around it (they don't come back when beaten)
		bossFx(e, { kind = "summon", name = e.boss.summon })
		local def = Config.EnemySpawns[e.biome.key]
		local alive = 0
		for _, m in ipairs(enemies) do
			if m.minion and m.bossOf == e and not m.dead then
				alive += 1
			end
		end
		for _ = 1, math.max(0, W.maxHelpers - alive) do
			local a = rng:NextNumber(0, math.pi * 2)
			local at = clampToBiome(e.biome, e.root.Position + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12))
			local m = createEnemy(e.biome, def, { level = def.max, pos = Vector3.new(at.X, 0, at.Z) })
			m.minion = true
			m.bossOf = e
			enemyById[m.id] = m
			table.insert(enemies, m)
		end
	end
end

local function removeBoss(e, beaten)
	if not e or e.removed then
		return
	end
	e.removed = true
	if not e.dead then
		-- it leaves (time's up)
		e.dead = true
		enemyById[e.id] = nil
		e.model:SetAttribute("Dead", true)
		task.delay(0.7, function()
			e.model:Destroy()
		end)
		local idx = table.find(enemies, e)
		if idx then
			table.remove(enemies, idx)
		end
	end
	-- its helpers go too
	for i = #enemies, 1, -1 do
		local m = enemies[i]
		if m.minion and m.bossOf == e then
			m.dead = true
			enemyById[m.id] = nil
			if m.model.Parent then
				m.model:Destroy()
			end
			table.remove(enemies, i)
		end
	end
	if currentBoss == e then
		currentBoss = nil
	end
	if bossRemote then
		bossRemote:FireAllClients({ kind = beaten and "defeated" or "left", boss = e.boss.name, biome = e.biome.name, color = e.boss.color })
	end
end
onBossDown = function(e, beaten)
	removeBoss(e, beaten)
end

-- spawn this server's boss (biomeKey = nil: its own weighted roll)
function EnemyService.SpawnBoss(biomeKey)
	if currentBoss and not currentBoss.dead then
		return currentBoss
	end
	local W = Config.WorldBosses
	if not biomeKey then
		local total = 0
		for _, b in pairs(W.list) do
			total += b.weight
		end
		local pick = rng:NextNumber() * total
		for key, b in pairs(W.list) do
			pick -= b.weight
			biomeKey = key
			if pick <= 0 then
				break
			end
		end
	end
	local bossDef = W.list[biomeKey]
	local def = Config.EnemySpawns[biomeKey]
	local biome
	for _, b in ipairs(Config.Biomes) do
		if b.key == biomeKey then
			biome = b
		end
	end
	if not bossDef or not def or not biome then
		return nil
	end
	local e = createEnemy(biome, def, { boss = bossDef, monsterId = bossDef.rig, level = def.max + W.levelBonus, finish = bossDef.finish, pos = randomPoint(biome, W.size * 0.5 + 4) })
	e.expires = os.clock() + W.lifetime
	e.nextSpecial = os.clock() + W.attackEvery
	e.nextUltimate = os.clock() + W.ultimateEvery
	enemyById[e.id] = e
	table.insert(enemies, e)
	currentBoss = e
	if bossRemote then
		bossRemote:FireAllClients({ kind = "spawn", boss = bossDef.name, biome = biome.name, color = bossDef.color, minutes = math.floor(W.lifetime / 60) })
	end
	return e
end

function EnemyService.ResetPet(uid)
	petHealth[uid] = nil
end

function EnemyService.Start(d)
	deps = d
	do
		local r = ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Remotes")
		bossRemote = r:FindFirstChild("WorldBoss") or Instance.new("RemoteEvent")
		bossRemote.Name = "WorldBoss"
		bossRemote.Parent = r
	end
	-- world boss schedule (this server's own): right after night, every hour
	task.spawn(function()
		local W = Config.WorldBosses
		local lastHour = -1
		if RunService:IsStudio() then
			-- Studio: one right away, to test
			task.delay(20, function()
				EnemyService.SpawnBoss()
			end)
		end
		while true do
			task.wait(2)
			local t = os.time()
			local hour = math.floor(t / 3600)
			if hour ~= lastHour and t - hour * 3600 >= W.spawnAt then
				lastHour = hour
				if not (currentBoss and not currentBoss.dead) then
					pcall(EnemyService.SpawnBoss)
				end
			end
			if currentBoss and not currentBoss.dead and os.clock() > (currentBoss.expires or math.huge) then
				removeBoss(currentBoss, false)
			end
		end
	end)
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
			if currentBoss then
				pcall(bossSpecials, currentBoss, now)
			end
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
								if now - e.defeatedAt >= Config.GetReviveTime(e.level) * (Config.IsBoostActive(profile, "campfire", now) and 0.5 or 1) * (1 - Config.Skill(profile, "undying") / 100) then
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
	local pickupRemote = remotes:FindFirstChild("PickupLoot") or Instance.new("RemoteEvent")
	pickupRemote.Name = "PickupLoot"
	pickupRemote.Parent = remotes
	local pendingSync = {}
	pickupRemote.OnServerEvent:Connect(function(player, id)
		if pickupLoot(player, id) and not pendingSync[player] then
			-- several pickups at once: one profile update
			pendingSync[player] = true
			task.delay(0.25, function()
				pendingSync[player] = nil
				if player.Parent then
					deps.sync(player)
				end
			end)
		end
	end)
	-- old loot nobody picked up is gone
	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.clock()
			for player, list in pairs(lootByPlayer) do
				for id, loot in pairs(list) do
					if now - loot.at > (Config.Loot.lifetime or 90) + 5 then
						list[id] = nil
					end
				end
			end
		end
	end)
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

		-- AUTO combat (Settings): the client picks the nearest enemy and
		-- sends everyone; only for players with enough rebirths
		if mode == "auto" then
			if (profile.rebirths or 0) < Config.CombatModes.autoRebirths then
				return { success = false, message = "Auto attack unlocks at Rebirth " .. Config.CombatModes.autoRebirths .. "." }
			end
			mode = "all"
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
		lootByPlayer[player] = nil
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
