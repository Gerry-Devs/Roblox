local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local monsterFolder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(monsterFolder:WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("MonsterRNG"):WaitForChild("DataService"))
local RollService = require(script.Parent:WaitForChild("MonsterRNG"):WaitForChild("RollService"))
local WorldService = require(script.Parent:WaitForChild("MonsterRNG"):WaitForChild("WorldService"))
local QuestService = require(script.Parent:WaitForChild("MonsterRNG"):WaitForChild("QuestService"))

local remotes = monsterFolder:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = monsterFolder

local function getRemote(name, className)
	local remote = remotes:FindFirstChild(name) or Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local rollRemote = getRemote("Roll", "RemoteFunction")
local profileRemote = getRemote("GetProfile", "RemoteFunction")
local shopRemote = getRemote("BuyShopItem", "RemoteFunction")
local bossRemote = getRemote("BattleBoss", "RemoteFunction")
local pvpRemote = getRemote("ChallengePlayer", "RemoteFunction")
local placeEggRemote = getRemote("PlaceEgg", "RemoteFunction")
local placeMonsterRemote = getRemote("PlaceMonster", "RemoteFunction")
local hatchRemote = getRemote("HatchEgg", "RemoteFunction")
local unequipRemote = getRemote("UnequipMonster", "RemoteFunction")
local sellEggRemote = getRemote("SellEgg", "RemoteFunction")
local sellAllEggsRemote = getRemote("SellAllEggs", "RemoteFunction")
local sellMonsterRemote = getRemote("SellMonster", "RemoteFunction")
local buyUpgradeRemote = getRemote("BuyUpgrade", "RemoteFunction")
local toggleFavoriteRemote = getRemote("ToggleFavorite", "RemoteFunction")
local buyDiceRemote = getRemote("BuyDice", "RemoteFunction")
local unlockBiomeRemote = getRemote("UnlockBiome", "RemoteFunction")
local rebirthRemote = getRemote("Rebirth", "RemoteFunction")
local claimDailyRemote = getRemote("ClaimDaily", "RemoteFunction")
local saveSettingsRemote = getRemote("SaveSettings", "RemoteFunction")
local usePotionRemote = getRemote("UsePotion", "RemoteFunction")
local EnemyService = require(game.ServerScriptService.MonsterRNG:WaitForChild("EnemyService"))
local combatFxRemote = getRemote("CombatFx", "RemoteEvent")
local warpRemote = getRemote("Warp", "RemoteFunction")
local giftInfoRemote = getRemote("GiftInfo", "RemoteFunction")
local giftSendRemote = getRemote("GiftSend", "RemoteFunction")
local giftRespondRemote = getRemote("GiftRespond", "RemoteFunction")
local giftEventRemote = getRemote("GiftEvent", "RemoteEvent")
local equipBestRemote = getRemote("EquipBest", "RemoteFunction")
local gearShopRemote = getRemote("GearShop", "RemoteFunction")
local buyGearRemote = getRemote("BuyGear", "RemoteFunction")
local useGearRemote = getRemote("UseGear", "RemoteFunction")
local gearRestockRemote = getRemote("GearRestock", "RemoteEvent")
local offlineRemote = getRemote("OfflineEarnings", "RemoteEvent")
local questsRemote = getRemote("Quests", "RemoteFunction")
local equipDiceRemote = getRemote("EquipDice", "RemoteFunction")
local sellBulkRemote = getRemote("SellBulk", "RemoteFunction")
local sellQuoteRemote = getRemote("SellQuote", "RemoteFunction")
local profileUpdated = getRemote("ProfileUpdated", "RemoteEvent")

local BASE_WALK_SPEED = 16
local BASE_JUMP_POWER, BASE_JUMP_HEIGHT = 50, 7.2

-- Royal Tax skill (Hollow King): sell for more
local function sellBoost(profile)
	return 1 + Config.Skill(profile, "sell") / 100
end

local function applyWalkSpeed(player, profile)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local bonus = Config.GetUpgradeBonus(profile.upgrades, "speed")
	local boots = Config.IsBoostActive(profile, "speedBoots") and 1.4 or 1
	local target = BASE_WALK_SPEED * (1 + bonus / 100) * boots
	target = target * Config.PassWalkMultiplier(profile) -- VIP +15%
	-- Dev server-wide speed effect (admin panel), capped so nobody flies off the map
	target = target * math.min(Config.GlobalBoost("speed"), Config.GlobalSpeedCap or 3)
	if humanoid.WalkSpeed ~= target then
		humanoid.WalkSpeed = target
	end
	-- Bouncy skill (Moss Slime): jump higher
	local jump = 1 + Config.Skill(profile, "jump") / 100
	if humanoid.UseJumpPower then
		humanoid.JumpPower = BASE_JUMP_POWER * jump
	else
		humanoid.JumpHeight = BASE_JUMP_HEIGHT * jump
	end
end

-- walk / jump skills change when monsters are equipped or level up
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if profile then
				pcall(applyWalkSpeed, player, profile)
			end
		end
	end
end)

local lastRollAt = {}
local lastBossAt = {}
local lastPvpAt = {}
local ROLL_COOLDOWN = 0.8
local BOSS_COOLDOWN = 4
local PVP_COOLDOWN = 5

local function publicProfile(player)
	local profile = DataService.Get(player)
	return profile and DataService.PublicProfile(profile) or nil
end

local function updateLeaderstats(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local rollsValue = leaderstats:FindFirstChild("Rolls")
	local cashValue = leaderstats:FindFirstChild("Cash")
	if rollsValue then
		rollsValue.Value = profile.rolls
	end
	if cashValue then
		cashValue.Value = profile.cash
	end
end

local function sync(player)
	local profile = publicProfile(player)
	if profile then
		profileUpdated:FireClient(player, profile)
	end
end

local function loadProfile(player)
	local profile = DataService.Get(player)
	local attempts = 0
	while not profile and attempts < 50 do
		task.wait(0.1)
		attempts += 1
		profile = DataService.Get(player)
	end
	return profile or DataService.Load(player)
end

Players.CharacterAutoLoads = false
WorldService.BuildMap()

--------------------------------------------------------------------
-- Gamepasses: owned passes live in profile.passes (checked on join and
-- updated right away when bought). VIP / Supporter give a name tag +
-- chat tag; a player with both picks one in Settings (settings.chatTag).
--------------------------------------------------------------------
local function updatePassTag(player, profile)
	-- tags the player owns (DEV / ADMIN / TESTER / BETA / VIP / SUPPORTER)
	local owned = Config.OwnedTags(profile, player.UserId)
	local chosen = profile.settings and profile.settings.chatTag
	if chosen ~= "none" and not (chosen and table.find(owned, chosen)) then
		chosen = owned[1]
	end
	if chosen == "none" then
		chosen = nil
	end
	player:SetAttribute("Tag", chosen)
	player:SetAttribute("TagChoices", #owned > 0 and table.concat(owned, ",") or nil)
	-- name tag above the head
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		local old = head:FindFirstChild("PassTag")
		if old then
			old:Destroy()
		end
		local info = chosen and Config.PassTags[chosen]
		if info then
			local bb = Instance.new("BillboardGui")
			bb.Name = "PassTag"
			bb.Size = UDim2.fromOffset(140, 26)
			bb.StudsOffset = Vector3.new(0, 2.6, 0)
			bb.MaxDistance = 30 -- hidden when the camera is far away
			bb.AlwaysOnTop = true
			bb.Parent = head
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.LuckiestGuy
			l.TextScaled = true
			l.Text = info.text
			l.TextColor3 = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
			l.TextStrokeTransparency = 0
			l.TextStrokeColor3 = Color3.fromRGB(20, 16, 30)
			l.Parent = bb
		end
	end
end

local function refreshPasses(player, profile)
	profile.passes = profile.passes or {}
	for _, pass in ipairs(Config.Gamepasses) do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ok then
			profile.passes[pass.key] = owns or nil
		end
	end
	updatePassTag(player, profile)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if not bought then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.passes = profile.passes or {}
	for _, pass in ipairs(Config.Gamepasses) do
		if pass.id == passId then
			profile.passes[pass.key] = true
		end
	end
	updatePassTag(player, profile)
	applyWalkSpeed(player, profile)
	WorldService.UpdateBase(player, profile)
	sync(player)
end)

task.spawn(function()
	while true do
		task.wait(2)
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = DataService.Get(p)
			if prof then
				pcall(applyWalkSpeed, p, prof)
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local profile = DataService.Load(player)
	task.spawn(refreshPasses, player, profile)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local rollsValue = Instance.new("IntValue")
	rollsValue.Name = "Rolls"
	rollsValue.Value = profile.rolls
	rollsValue.Parent = leaderstats

	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = profile.cash
	cashValue.Parent = leaderstats

	WorldService.CreateBase(player, profile)
	-- Offline earnings: what the pen made while you were away
	task.spawn(function()
		task.wait(5) -- passes (VIP) and the pen are ready by now
		if not player.Parent or DataService.Get(player) ~= profile then
			return
		end
		local last = profile.lastOnline
		if type(last) ~= "number" then
			return
		end
		local away = os.time() - last
		if away < Config.Offline.minSeconds then
			return
		end
		local maxSeconds = Config.OfflineHours(profile) * 3600
		local seconds = math.min(away, maxSeconds)
		local cash = math.floor(WorldService.GetProfileIncome(profile) * seconds * Config.OfflineRate(profile))
		profile.lastOnline = os.time() -- can't be claimed twice
		if cash <= 0 then
			return
		end
		profile.cash += cash
		sync(player)
		offlineRemote:FireClient(player, { cash = cash, seconds = seconds, away = away, maxHours = Config.OfflineHours(profile), rate = Config.OfflineRate(profile) })
	end)
	player.CharacterAdded:Connect(function(character)
		-- respawn after dying / Reset (characters don't load on their own in this game)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				task.wait(Players.RespawnTime)
				if player.Parent and player.Character == character then
					player:SetAttribute("InPvp", nil)
					player:LoadCharacter()
				end
			end)
		end
		applyWalkSpeed(player, profile)
		character:WaitForChild("Head", 5)
		updatePassTag(player, profile)
	end)
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	DataService.Save(player)
	WorldService.RemoveBase(player)
	DataService.Remove(player)
	lastRollAt[player] = nil
	lastBossAt[player] = nil
	lastPvpAt[player] = nil
end)

profileRemote.OnServerInvoke = function(player)
	local profile = loadProfile(player)
	return DataService.PublicProfile(profile)
end

rollRemote.OnServerInvoke = function(player)
	local now = os.clock()
	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end

	-- One roll per roll-duration (shortened by the Roll Speed upgrade);
	-- a small allowance covers network jitter.
	local cooldown = math.max(ROLL_COOLDOWN, Config.GetRollDuration(profile.upgrades) * Config.PassRollTimeMultiplier(profile) - 0.3)
	if lastRollAt[player] and now - lastRollAt[player] < cooldown then
		return { success = false, message = "Slow down for a moment." }
	end

	local backpackCap = Config.GetBackpackCap(profile.upgrades)
	local backpackCount = #profile.eggs + #profile.monsters
	if backpackCount >= backpackCap then
		return {
			success = false,
			message = string.format("Your backpack is full (%d/%d). Sell or place some items first.", backpackCount, backpackCap),
		}
	end

	lastRollAt[player] = now
	local rarity, egg, wilds, wheelIndex = RollService.Roll(profile)
	local second
	if rarity and Config.HasPass(profile, "doubleRoll") then
		local ok, r2, e2 = pcall(RollService.Roll, profile)
		if ok and r2 and e2 then
			second = { rarity = r2, egg = e2 }
		end
	end
	-- Glitch skill (Glitch Beast): chance the roll gives a 2nd egg
	if rarity and not second and math.random() * 100 < Config.Skill(profile, "glitch") and #profile.eggs + #profile.monsters < backpackCap then
		local ok, r2, e2 = pcall(RollService.Roll, profile)
		if ok and r2 and e2 then
			second = { rarity = r2, egg = e2 }
		end
	end
	if rarity then
		QuestService.Add(profile, "rolls", 1)
	end
	updateLeaderstats(player)
	sync(player)

	return {
		success = true,
		rarity = rarity,
		egg = egg,
		second = second,
		wilds = wilds,
		wheelIndex = wheelIndex,
		profile = DataService.PublicProfile(profile),
	}
end

local function countPlacedByKind(profile, kind)
	local count = 0
	for _, entry in ipairs(profile.base) do
		if entry.kind == kind then
			count += 1
		end
	end
	return count
end

local function findAndRemoveByUid(list, uid)
	for index, entry in ipairs(list) do
		if entry.uid == uid then
			return table.remove(list, index)
		end
	end
	return nil
end

local function findInBase(profile, uid)
	for index, entry in ipairs(profile.base) do
		if entry.uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

placeEggRemote.OnServerInvoke = function(player, eggUid, x, z)
	local profile = DataService.Get(player)
	x = tonumber(x)
	z = tonumber(z)
	if not profile or type(eggUid) ~= "string" or not x or not z then
		return { success = false, message = "That egg could not be placed." }
	end

	if not WorldService.IsValidPlacement(x, z) then
		return { success = false, message = "You can only place items inside your own pen." }
	end

	local eggCap = Config.GetPenEggCap(profile.upgrades)
	if countPlacedByKind(profile, "egg") >= eggCap then
		return {
			success = false,
			message = string.format("Your pen already has %d/%d eggs incubating.", eggCap, eggCap),
		}
	end

	local egg = findAndRemoveByUid(profile.eggs, eggUid)
	if not egg then
		return { success = false, message = "That egg is no longer in your backpack." }
	end

	table.insert(profile.base, {
		uid = egg.uid,
		kind = "egg",
		monsterId = egg.monsterId,
		size = egg.size,
		finish = egg.finish,
		kg = egg.kg,
		rarity = egg.rarity,
		level = 1,
		position = { x = x, z = z },
		placedAt = os.time(),
		readyAt = os.time() + math.floor(Config.GetEggHatchDuration(egg) * Config.PassHatchMultiplier(profile)),
		favorite = egg.favorite,
	})

	WorldService.UpdateBase(player, profile)
	sync(player)

	return {
		success = true,
		message = "Egg placed in your pen.",
		profile = DataService.PublicProfile(profile),
	}
end

placeMonsterRemote.OnServerInvoke = function(player, monsterUid, x, z)
	local profile = DataService.Get(player)
	x = tonumber(x)
	z = tonumber(z)
	if not profile or type(monsterUid) ~= "string" or not x or not z then
		return { success = false, message = "That monster could not be placed." }
	end

	-- monsters can be equipped from anywhere: if the click wasn't inside
	-- the pen, it just gets a free spot in the pen
	if not WorldService.IsValidPlacement(x, z) then
		local found = false
		for _ = 1, 40 do
			local rx, rz = (math.random() - 0.5) * 40, (math.random() - 0.5) * 36
			if WorldService.IsValidPlacement(rx, rz) then
				x, z, found = rx, rz, true
				break
			end
		end
		if not found then
			x, z = 0, 0
		end
	end

	local monsterCap = (Config.GetPenMonsterCap(profile.upgrades) + Config.PassExtraMonsters(profile))
	if countPlacedByKind(profile, "monster") >= monsterCap then
		return {
			success = false,
			message = string.format("Your pen already has %d/%d monsters placed.", monsterCap, monsterCap),
		}
	end

	local monster = findAndRemoveByUid(profile.monsters, monsterUid)
	if not monster then
		return { success = false, message = "That monster is no longer in your backpack." }
	end

	table.insert(profile.base, {
		uid = monster.uid,
		kind = "monster",
		monsterId = monster.monsterId,
		size = monster.size,
		finish = monster.finish,
		kg = monster.kg,
		level = monster.level,
		xp = monster.xp,
		defeated = monster.defeated,
		defeatedAt = monster.defeatedAt,
		position = { x = x, z = z },
		favorite = monster.favorite,
	})

	WorldService.UpdateBase(player, profile)
	sync(player)

	return {
		success = true,
		message = "Monster equipped!",
		profile = DataService.PublicProfile(profile),
	}
end

unequipRemote.OnServerInvoke = function(player, baseUid)
	local profile = DataService.Get(player)
	if not profile or type(baseUid) ~= "string" then
		return { success = false, message = "That could not be unequipped." }
	end

	local entry, index = findInBase(profile, baseUid)
	if not entry or entry.kind ~= "monster" then
		return { success = false, message = "That monster is not in your pen." }
	end

	table.remove(profile.base, index)
	table.insert(profile.monsters, {
		uid = entry.uid,
		monsterId = entry.monsterId,
		size = entry.size,
		finish = entry.finish,
		kg = entry.kg,
		level = entry.level,
		xp = entry.xp,
		defeated = entry.defeated,
		defeatedAt = entry.defeatedAt,
		favorite = entry.favorite,
	})

	WorldService.UpdateBase(player, profile)
	sync(player)

	return {
		success = true,
		message = "Monster sent back to your backpack.",
		profile = DataService.PublicProfile(profile),
	}
end

-- Hatching: the egg shakes for Config.HatchShakeTime seconds (visible to
-- everyone), then the monster pops out of it. It stays in the pen if
-- there's room, otherwise it goes to the backpack.
hatchRemote.OnServerInvoke = function(player, baseUid)
	local profile = DataService.Get(player)
	if not profile or type(baseUid) ~= "string" then
		return { success = false, message = "That egg could not be hatched." }
	end

	local entry = findInBase(profile, baseUid)
	if not entry or entry.kind ~= "egg" then
		return { success = false, message = "There is no egg there." }
	end
	if entry.hatching then
		return { success = false, message = "It's already hatching!" }
	end
	if os.time() < entry.readyAt then
		return { success = false, message = string.format("Still incubating for %ds.", entry.readyAt - os.time()) }
	end

	entry.hatching = true
	entry.hatchStartedAt = os.clock()
	WorldService.UpdateBase(player, profile)

	task.delay(Config.HatchShakeTime, function()
		if DataService.Get(player) ~= profile then
			return
		end
		local egg, index = findInBase(profile, baseUid)
		if not egg then
			return
		end

		local monsterEntry = {
			uid = egg.uid,
			monsterId = egg.monsterId,
			size = egg.size,
			finish = egg.finish,
		kg = egg.kg,
			level = 1,
			favorite = egg.favorite,
		}
		local fitsInPen = countPlacedByKind(profile, "monster") < (Config.GetPenMonsterCap(profile.upgrades) + Config.PassExtraMonsters(profile))
		local position = egg.position

		if fitsInPen then
			monsterEntry.kind = "monster"
			monsterEntry.position = position
			profile.base[index] = monsterEntry
		else
			table.remove(profile.base, index)
			table.insert(profile.monsters, monsterEntry)
		end
		profile.owned[egg.monsterId] = (profile.owned[egg.monsterId] or 0) + 1

		WorldService.MarkHatched(player, monsterEntry, not fitsInPen, position)
		WorldService.UpdateBase(player, profile)
		updateLeaderstats(player)
		sync(player)
	end)

	return { success = true, hatching = true, profile = DataService.PublicProfile(profile) }
end

sellEggRemote.OnServerInvoke = function(player, eggUid)
	local profile = DataService.Get(player)
	if not profile or type(eggUid) ~= "string" then
		return { success = false, message = "That egg could not be sold." }
	end

	for _, e in ipairs(profile.eggs) do
		if e.uid == eggUid and e.favorite then
			return { success = false, message = "That egg is a favorite \226\128\148 unfavorite it to sell." }
		end
	end
	local egg = findAndRemoveByUid(profile.eggs, eggUid)
	if not egg then
		return { success = false, message = "That egg is not in your backpack." }
	end

	local rarity = Config.GetRarity(egg.rarity)
	local saleValue = math.floor(math.max(15, rarity.tier * 20) * sellBoost(profile))
	profile.cash += saleValue
	QuestService.Add(profile, "sells", 1)
	updateLeaderstats(player)
	sync(player)

	return {
		success = true,
		message = "Sold " .. rarity.name .. " Egg for $" .. saleValue .. ".",
		profile = DataService.PublicProfile(profile),
	}
end

sellAllEggsRemote.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end

	if Config.SellAllGamepassId ~= 0 then
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.SellAllGamepassId)
		end)
		if not (ok and result) then
			return { success = false, message = "Sell All requires the gamepass.", needsGamepass = true }
		end
	end

	if #profile.eggs == 0 then
		return { success = false, message = "You have no eggs to sell." }
	end

	local total = 0
	for _, egg in ipairs(profile.eggs) do
		local rarity = Config.GetRarity(egg.rarity)
		total += math.floor(math.max(15, rarity.tier * 20) * sellBoost(profile))
	end
	QuestService.Add(profile, "sells", #profile.eggs)
	profile.eggs = {}
	profile.cash += total
	updateLeaderstats(player)
	sync(player)

	return {
		success = true,
		message = "Sold all eggs for $" .. total .. ".",
		profile = DataService.PublicProfile(profile),
	}
end

sellMonsterRemote.OnServerInvoke = function(player, monsterUid)
	local profile = DataService.Get(player)
	if not profile or type(monsterUid) ~= "string" then
		return { success = false, message = "That monster could not be sold." }
	end

	for _, m in ipairs(profile.monsters) do
		if m.uid == monsterUid and m.favorite then
			return { success = false, message = "That monster is a favorite \226\128\148 unfavorite it to sell." }
		end
	end
	local entry = findAndRemoveByUid(profile.monsters, monsterUid)
	if not entry then
		return { success = false, message = "That monster is not in your backpack." }
	end

	local monster = Config.GetMonster(entry.monsterId)
	local saleValue = math.floor(math.max(25, WorldService.GetEntryIncome(entry) * 10) * sellBoost(profile))
	profile.cash += saleValue
	QuestService.Add(profile, "sells", 1)
	profile.owned[entry.monsterId] = math.max(0, (profile.owned[entry.monsterId] or 1) - 1)
	updateLeaderstats(player)
	sync(player)

	return {
		success = true,
		message = "Sold " .. (monster and monster.name or "monster") .. " for $" .. saleValue .. ".",
		profile = DataService.PublicProfile(profile),
	}
end

local function eggSaleValue(egg)
	return math.max(15, Config.GetRarity(egg.rarity).tier * 20)
end

local function monsterSaleValue(monster)
	return math.max(25, WorldService.GetEntryIncome(monster) * 10)
end

local function quoteList(list, valueFn, boost)
	local count, value = 0, 0
	for _, item in ipairs(list) do
		if not item.favorite then
			count += 1
			value += math.floor(valueFn(item) * (boost or 1))
		end
	end
	return count, value
end

toggleFavoriteRemote.OnServerInvoke = function(player, uid)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" then
		return { success = false }
	end
	for _, list in ipairs({ profile.eggs, profile.monsters }) do
		for _, item in ipairs(list) do
			if item.uid == uid then
				item.favorite = not item.favorite or nil
				sync(player)
				return {
					success = true,
					favorite = item.favorite == true,
					profile = DataService.PublicProfile(profile),
				}
			end
		end
	end
	return { success = false, message = "That item is not in your backpack." }
end

sellQuoteRemote.OnServerInvoke = function(player, heldUid)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local boost = sellBoost(profile)
	local eggCount, eggValue = quoteList(profile.eggs, eggSaleValue, boost)
	local monsterCount, monsterValue = quoteList(profile.monsters, monsterSaleValue, boost)

	-- the item the player is currently holding (equipped from the backpack)
	local held
	if type(heldUid) == "string" then
		for _, e in ipairs(profile.eggs) do
			if e.uid == heldUid then
				held = { kind = "egg", name = Config.GetRarity(e.rarity).name .. " Egg", value = math.floor(eggSaleValue(e) * boost), favorite = e.favorite == true }
			end
		end
		for _, m in ipairs(profile.monsters) do
			if m.uid == heldUid then
				local monster = Config.GetMonster(m.monsterId)
				held = {
					kind = "monster",
					name = Config.BuildDisplayName(monster and monster.name or "Monster", m.size, m.finish),
					value = math.floor(monsterSaleValue(m) * boost),
					favorite = m.favorite == true,
				}
			end
		end
	end

	return {
		eggs = { count = eggCount, value = eggValue },
		monsters = { count = monsterCount, value = monsterValue },
		all = { count = eggCount + monsterCount, value = eggValue + monsterValue },
		held = held,
	}
end

-- mode: "eggs" | "monsters" | "all". Favorites are never sold.
sellBulkRemote.OnServerInvoke = function(player, mode)
	local profile = DataService.Get(player)
	if not profile or (mode ~= "eggs" and mode ~= "monsters" and mode ~= "all") then
		return { success = false, message = "Could not sell." }
	end
	if Config.SellAllGamepassId ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.SellAllGamepassId)
		end)
		if not (ok and owns) then
			return { success = false, message = "Sell All requires the gamepass.", needsGamepass = true }
		end
	end

	local total, sold = 0, 0
	local function sellFrom(list, valueFn, onSold)
		local kept = {}
		for _, item in ipairs(list) do
			if item.favorite then
				table.insert(kept, item)
			else
				total += math.floor(valueFn(item) * sellBoost(profile))
				sold += 1
				if onSold then
					onSold(item)
				end
			end
		end
		return kept
	end

	if mode == "eggs" or mode == "all" then
		profile.eggs = sellFrom(profile.eggs, eggSaleValue)
	end
	if mode == "monsters" or mode == "all" then
		profile.monsters = sellFrom(profile.monsters, monsterSaleValue, function(m)
			profile.owned[m.monsterId] = math.max(0, (profile.owned[m.monsterId] or 1) - 1)
		end)
	end

	if sold == 0 then
		return { success = false, message = "Nothing to sell (favorites are kept)." }
	end
	QuestService.Add(profile, "sells", sold)
	profile.cash += total
	updateLeaderstats(player)
	sync(player)
	return {
		success = true,
		message = string.format("Sold %d item%s for $%d!", sold, sold == 1 and "" or "s", total),
		profile = DataService.PublicProfile(profile),
	}
end

--------------------------------------------------------------------
-- Auto Sell (gamepass): sells new backpack items that match the player's
-- settings every few seconds. Favorites are never sold.
--   settings = { enabled, eggs, monsters, mode = "all"|"rarity"|"cash",
--                rarities = { [key] = true }, minCash = number }
--------------------------------------------------------------------
local autoSellInfoRemote = getRemote("AutoSellInfo", "RemoteFunction")
local autoSellSaveRemote = getRemote("AutoSellSave", "RemoteFunction")
local autoSoldRemote = getRemote("AutoSold", "RemoteEvent")
local autoSellOwned = {} -- player -> { owns, checkedAt }

local function ownsAutoSell(player)
	if Config.HasPass(DataService.Get(player), "autoSell") then
		return true -- bought or given by the admin
	end
	if (Config.AutoSellGamepassId or 0) == 0 then
		return true -- no gamepass set yet: free for testing
	end
	local c = autoSellOwned[player]
	if c and os.clock() - c.checkedAt < 60 then
		return c.owns
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.AutoSellGamepassId)
	end)
	autoSellOwned[player] = { owns = ok and owns or false, checkedAt = os.clock() }
	return ok and owns or false
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if bought and passId == Config.AutoSellGamepassId then
		autoSellOwned[player] = { owns = true, checkedAt = os.clock() }
	end
end)

local function autoSellSettings(profile)
	profile.autoSell = profile.autoSell or { enabled = false, eggs = true, monsters = true, mode = "all", rarities = {}, minCash = 0 }
	return profile.autoSell
end

autoSellInfoRemote.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	return { owns = ownsAutoSell(player), settings = autoSellSettings(profile), gamepassId = Config.AutoSellGamepassId or 0 }
end

autoSellSaveRemote.OnServerInvoke = function(player, incoming)
	local profile = DataService.Get(player)
	if not profile or type(incoming) ~= "table" then
		return { success = false }
	end
	if not ownsAutoSell(player) then
		return { success = false, message = "Auto Sell requires the gamepass.", needsGamepass = true }
	end
	local s = autoSellSettings(profile)
	s.enabled = incoming.enabled == true
	s.eggs = incoming.eggs ~= false
	s.monsters = incoming.monsters ~= false
	s.mode = (incoming.mode == "rarity" or incoming.mode == "cash") and incoming.mode or "all"
	s.rarities = {}
	if type(incoming.rarities) == "table" then
		for _, r in ipairs(Config.Rarities) do
			if incoming.rarities[r.key] == true then
				s.rarities[r.key] = true
			end
		end
	end
	s.minCash = math.clamp(tonumber(incoming.minCash) or 0, 0, 1e15)
	return { success = true, settings = s }
end

local function autoSellMatches(s, item)
	if item.favorite then
		return false
	end
	if s.mode == "rarity" then
		return s.rarities[item.rarity or (Config.GetMonster(item.monsterId) or {}).rarity or ""] == true
	elseif s.mode == "cash" then
		local ok, income = pcall(Config.GetEntryIncome, item)
		return ok and type(income) == "number" and income < (s.minCash or 0)
	end
	return true
end

task.spawn(function()
	while true do
		task.wait(3)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			local s = profile and profile.autoSell
			if s and s.enabled and ownsAutoSell(player) then
				local total, sold = 0, 0
				local heldUid = player:GetAttribute("HeldUid")
				local function sellFrom(list, valueFn, onSold)
					local kept = {}
					for _, item in ipairs(list) do
						if item.uid ~= heldUid and autoSellMatches(s, item) then
							total += math.floor(valueFn(item) * sellBoost(profile))
							sold += 1
							if onSold then
								onSold(item)
							end
						else
							table.insert(kept, item)
						end
					end
					return kept
				end
				if s.eggs then
					profile.eggs = sellFrom(profile.eggs, eggSaleValue)
				end
				if s.monsters then
					profile.monsters = sellFrom(profile.monsters, monsterSaleValue, function(m)
						profile.owned[m.monsterId] = math.max(0, (profile.owned[m.monsterId] or 1) - 1)
					end)
				end
				if sold > 0 then
					profile.cash += total
					updateLeaderstats(player)
					sync(player)
					autoSoldRemote:FireClient(player, sold, total)
					pcall(QuestService.Add, profile, "sells", type(sold) == "number" and sold or 1)
				end
			end
		end
	end
end)

buyDiceRemote.OnServerInvoke = function(player, key)
	local profile = DataService.Get(player)
	local dice = type(key) == "string" and Config.FindDice(key)
	if not profile or not dice then
		return { success = false, message = "That dice doesn't exist." }
	end
	profile.ownedDice = profile.ownedDice or { common = true }
	if profile.ownedDice[key] then
		return { success = false, message = "You already own the " .. dice.name .. "." }
	end
	if profile.cash < dice.cost then
		return { success = false, message = "You need $" .. Config.FormatNumber(dice.cost) .. " for the " .. dice.name .. "." }
	end
	profile.cash -= dice.cost
	profile.ownedDice[key] = true
	profile.equippedDice = key
	updateLeaderstats(player)
	sync(player)
	return { success = true, message = "Bought and equipped the " .. dice.name .. "!", profile = DataService.PublicProfile(profile) }
end

equipDiceRemote.OnServerInvoke = function(player, key)
	local profile = DataService.Get(player)
	local dice = type(key) == "string" and Config.FindDice(key)
	if not profile or not dice then
		return { success = false, message = "That dice doesn't exist." }
	end
	profile.ownedDice = profile.ownedDice or { common = true }
	if not profile.ownedDice[key] then
		return { success = false, message = "You don't own the " .. dice.name .. " yet." }
	end
	profile.equippedDice = key
	sync(player)
	return { success = true, message = "Equipped the " .. dice.name .. ".", profile = DataService.PublicProfile(profile) }
end

-- Rebirth: pay cash + Rift Shards, reset cash + unlocked biomes, gain bonuses.
rebirthRemote.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end
	local cashCost, shardCost = Config.GetRebirthCost(profile.rebirths or 0)
	if profile.cash < cashCost or (profile.riftShards or 0) < shardCost then
		return { success = false, message = string.format("You need $%s and %s Rift Shards.", Config.FormatNumber(cashCost), Config.FormatNumber(shardCost)) }
	end
	profile.riftShards -= shardCost
	profile.rebirths = (profile.rebirths or 0) + 1
	profile.cash = 0
	-- biomes must be bought again; inventory + upgrades are kept
	profile.unlockedBiomes = { home = true }
	updateLeaderstats(player)
	sync(player)
	return { success = true, message = "Rebirth " .. profile.rebirths .. "! Bonuses increased.", profile = DataService.PublicProfile(profile) }
end

-- Daily rewards: one claim per UTC day; missing a day restarts at day 1.
local function utcDay()
	return math.floor(os.time() / 86400)
end

claimDailyRemote.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end
	profile.daily = profile.daily or { streak = 0, lastDay = -1 }
	local today = utcDay()
	if profile.daily.lastDay == today then
		return { success = false, message = "Already claimed today, come back tomorrow!" }
	end
	local streak = (profile.daily.lastDay == today - 1) and (profile.daily.streak % 7) + 1 or 1
	local reward = Config.DailyRewards[streak]
	local mult = Config.PassDailyMultiplier(profile) -- VIP: double daily rewards
	if reward.cash then
		profile.cash += reward.cash * mult
	end
	if reward.shards then
		profile.riftShards = (profile.riftShards or 0) + reward.shards * mult
	end
	for key, n in pairs(reward.potions or {}) do
		profile.potions[key] = (profile.potions[key] or 0) + n * mult
	end
	for key, n in pairs(reward.items or {}) do
		profile.items[key] = (profile.items[key] or 0) + n * mult
	end
	profile.daily = { streak = streak, lastDay = today }
	updateLeaderstats(player)
	sync(player)
	return { success = true, message = "Day " .. streak .. " reward claimed!", profile = DataService.PublicProfile(profile) }
end

-- Daily quests: "get" the list, or "claim" quest number i
questsRemote.OnServerInvoke = function(player, action, index)
	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end
	if action == "claim" then
		local r = QuestService.Claim(profile, index)
		if r.success then
			updateLeaderstats(player)
			sync(player)
		end
		r.quests = QuestService.Public(profile)
		r.profile = DataService.PublicProfile(profile)
		return r
	end
	return { success = true, quests = QuestService.Public(profile) }
end

saveSettingsRemote.OnServerInvoke = function(player, settings)
	local profile = DataService.Get(player)
	if not profile or type(settings) ~= "table" then
		return false
	end
	profile.settings = profile.settings or {}
	if type(settings.graphics) == "string" and Config.Graphics.tiers[settings.graphics] then
		profile.settings.graphics = settings.graphics
	end
	if type(settings.chatTag) == "string" and (settings.chatTag == "none" or table.find(Config.OwnedTags(profile, player.UserId), settings.chatTag)) then
		profile.settings.chatTag = settings.chatTag
		updatePassTag(player, profile)
	end
	for _, k in ipairs({ "sound", "otherPets", "ownPets", "miniDice", "music", "particles", "shadows" }) do
		if type(settings[k]) == "boolean" then
			profile.settings[k] = settings[k]
		end
	end
	return true
end

-- Potions: timed boosts, or Revive on a defeated pet.
usePotionRemote.OnServerInvoke = function(player, key, targetUid)
	local profile = DataService.Get(player)
	local potion = type(key) == "string" and Config.GetPotion(key)
	if not profile or not potion then
		return { success = false, message = "That potion doesn't exist." }
	end
	if (profile.potions[key] or 0) <= 0 then
		return { success = false, message = "You don't have a " .. potion.name .. "." }
	end
	if key == "revive" then
		local target
		for _, list in ipairs({ profile.base, profile.monsters }) do
			for _, e in ipairs(list) do
				if e.defeated and (type(targetUid) ~= "string" or e.uid == targetUid) and not target then
					target = e
				end
			end
		end
		if not target then
			return { success = false, message = "None of your pets need reviving." }
		end
		target.defeated = nil
		target.defeatedAt = nil
		EnemyService.ResetPet(target.uid)
		WorldService.UpdateBase(player, profile)
	else
		profile.activeBoosts = profile.activeBoosts or {}
		local now = os.time()
		profile.activeBoosts[key] = math.max(now, profile.activeBoosts[key] or 0) + potion.duration
	end
	profile.potions[key] -= 1
	if profile.potions[key] <= 0 then
		profile.potions[key] = nil
	end
	sync(player)
	QuestService.Add(profile, "potions", 1)
	return { success = true, message = potion.name .. " used!", profile = DataService.PublicProfile(profile) }
end

-- Warp: uses one Warp Remote. Biomes must be unlocked.
warpRemote.OnServerInvoke = function(player, key)
	local profile = DataService.Get(player)
	if not profile or type(key) ~= "string" then
		return { success = false, message = "Can't warp right now." }
	end
	if (profile.items.warpRemote or 0) <= 0 then
		return { success = false, message = "You need a Warp Remote. Buy one at the Gear Shop!" }
	end
	local character = player.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return { success = false, message = "Your character isn't ready." }
	end
	local target
	if key == "pen" then
		local pen = WorldService.GetPen(player)
		local spawnPart = pen and pen.model and pen.model:FindFirstChild("PenSpawn")
		target = spawnPart and spawnPart.Position + Vector3.new(0, 4, 0)
	elseif key == "shop" then
		target = Vector3.new(0, 5, 12)
	else
		for _, b in ipairs(Config.Biomes) do
			if b.key == key and b.cost then
				if not (profile.unlockedBiomes and profile.unlockedBiomes[key]) then
					return { success = false, message = "Unlock " .. b.name .. " first!" }
				end
				target = Vector3.new(b.center.X, 5, b.center.Y + b.size.Y / 2 - 25)
			end
		end
	end
	if not target then
		return { success = false, message = "You can't warp there." }
	end
	profile.items.warpRemote -= 1
	if profile.items.warpRemote <= 0 then
		profile.items.warpRemote = nil
	end
	pcall(function()
		player:RequestStreamAroundAsync(target, 5)
	end)
	character:PivotTo(CFrame.new(target))
	sync(player)
	return { success = true, message = "Warped!", profile = DataService.PublicProfile(profile) }
end

--------------------------------------------------------------------
-- Gifting. Nothing leaves the sender until the receiver accepts, and
-- everything is checked again at that moment, so gifts can't be duped.
--------------------------------------------------------------------
local G = Config.Gifting
local pendingGifts = {} -- receiver Player -> { id, from, payload, summary }

local function giftDay()
	return math.floor(os.time() / 86400)
end

local function giftBlockReason(player, profile)
	if not profile then
		return player.Name .. "'s data is still loading."
	end
	if (profile.rebirths or 0) < G.minRebirth then
		return player.Name .. " needs Rebirth " .. G.minRebirth .. "+ to use gifts."
	end
	if player.AccountAge < G.minAccountAge then
		return player.Name .. "'s account must be " .. G.minAccountAge .. "+ days old to use gifts."
	end
	return nil
end

local function giftsLeftToday(profile)
	local d = profile.giftDaily or {}
	if d.day ~= giftDay() then
		return G.giftsPerDay
	end
	return math.max(0, G.giftsPerDay - (d.count or 0))
end

local function maxGiftCash(receiverProfile)
	local cashCost = Config.GetRebirthCost(receiverProfile.rebirths or 0)
	return math.floor(cashCost * G.cashShare)
end

local function findByUid(list, uid)
	for i, e in ipairs(list) do
		if e.uid == uid then
			return e, i
		end
	end
	return nil
end

-- validates a gift; returns the cleaned gift or nil + reason
local function checkGift(sender, sp, receiver, rp, payload)
	if type(payload) ~= "table" then
		return nil, "Invalid gift."
	end
	local reason = giftBlockReason(sender, sp) or giftBlockReason(receiver, rp)
	if reason then
		return nil, reason
	end
	if (sp.items.giftCard or 0) < 1 then
		return nil, "You need a Gift Card to send a gift."
	end
	if giftsLeftToday(sp) <= 0 then
		return nil, "You've used all " .. G.giftsPerDay .. " gifts for today."
	end
	local g = { cash = 0, monsters = {}, eggs = {}, potions = {}, items = {}, count = 0 }
	local cash = math.floor(tonumber(payload.cash) or 0)
	if cash < 0 then
		return nil, "Invalid cash amount."
	end
	if cash > 0 then
		local cap = maxGiftCash(rp)
		if cash > cap then
			return nil, "You can gift at most $" .. Config.FormatNumber(cap) .. " cash to " .. receiver.Name .. "."
		end
		if cash > sp.cash then
			return nil, "You don't have that much cash."
		end
		g.cash = cash
	end
	local seen = {}
	for _, kind in ipairs({ "monsters", "eggs" }) do
		for _, uid in ipairs(type(payload[kind]) == "table" and payload[kind] or {}) do
			if type(uid) ~= "string" or seen[uid] then
				return nil, "Invalid gift."
			end
			seen[uid] = true
			local e = findByUid(sp[kind], uid)
			if not e then
				return nil, "Something in the gift isn't in your backpack anymore."
			end
			if e.favorite then
				return nil, "Favorites can't be gifted. Unfavorite it first."
			end
			table.insert(g[kind], uid)
			g.count += 1
		end
	end
	for _, kind in ipairs({ "potions", "items" }) do
		for key, n in pairs(type(payload[kind]) == "table" and payload[kind] or {}) do
			n = math.floor(tonumber(n) or 0)
			local valid = type(key) == "string" and (kind == "potions" and Config.GetPotion(key) or (kind == "items" and Config.Items[key]))
			if not valid or n < 0 then
				return nil, "Invalid gift."
			end
			if kind == "items" and key == "giftCard" then
				return nil, "Gift Cards can't be gifted."
			end
			if n > 0 then
				if n > (sp[kind][key] or 0) then
					return nil, "You don't have enough of that to gift."
				end
				g[kind][key] = n
				g.count += n
			end
		end
	end
	if g.count > G.maxItemsPerGift then
		return nil, "A gift can hold at most " .. G.maxItemsPerGift .. " items."
	end
	if g.count == 0 and g.cash == 0 then
		return nil, "Pick something to gift first."
	end
	local incoming = #g.monsters + #g.eggs
	if incoming > 0 and #rp.eggs + #rp.monsters + incoming > Config.GetBackpackCap(rp.upgrades) then
		return nil, receiver.Name .. "'s backpack is too full."
	end
	return g
end

local function giftSummary(sp, g)
	local lines = {}
	if g.cash > 0 then
		table.insert(lines, "$" .. Config.FormatNumber(g.cash) .. " cash")
	end
	for _, uid in ipairs(g.monsters) do
		local e = findByUid(sp.monsters, uid)
		local m = e and Config.GetMonster(e.monsterId)
		table.insert(lines, m and Config.BuildDisplayName(m.name, e.size, e.finish) or "Monster")
	end
	for _, uid in ipairs(g.eggs) do
		local e = findByUid(sp.eggs, uid)
		table.insert(lines, (e and Config.GetRarity(e.rarity).name or "") .. " Egg")
	end
	for key, n in pairs(g.potions) do
		table.insert(lines, n .. "x " .. Config.GetPotion(key).name)
	end
	for key, n in pairs(g.items) do
		table.insert(lines, n .. "x " .. Config.Items[key].name)
	end
	return lines
end

local function giftNotify(player, text, good)
	if player and player.Parent then
		giftEventRemote:FireClient(player, { kind = "info", text = text, good = good })
	end
end

giftInfoRemote.OnServerInvoke = function(player, targetUserId)
	local sp = DataService.Get(player)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	local rp = target and DataService.Get(target)
	local reason = (sp and giftBlockReason(player, sp)) or (target and target ~= player and giftBlockReason(target, rp)) or nil
	return {
		ok = reason == nil and target ~= nil and target ~= player,
		reason = reason,
		maxCash = rp and maxGiftCash(rp) or 0,
		giftsLeft = sp and giftsLeftToday(sp) or 0,
		cards = sp and (sp.items.giftCard or 0) or 0,
	}
end

giftSendRemote.OnServerInvoke = function(player, targetUserId, payload)
	local sp = DataService.Get(player)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not sp or not target or target == player then
		return { success = false, message = "That player isn't in this server." }
	end
	local rp = DataService.Get(target)
	if pendingGifts[target] then
		return { success = false, message = target.Name .. " already has a gift waiting. Try again soon." }
	end
	local g, err = checkGift(player, sp, target, rp, payload)
	if not g then
		return { success = false, message = err }
	end
	local id = HttpService:GenerateGUID(false)
	local summary = giftSummary(sp, g)
	pendingGifts[target] = { id = id, from = player, payload = payload, summary = summary }
	giftEventRemote:FireClient(target, { kind = "offer", id = id, from = player.DisplayName, summary = summary, seconds = G.offerSeconds })
	task.delay(G.offerSeconds, function()
		local p = pendingGifts[target]
		if p and p.id == id then
			pendingGifts[target] = nil
			giftNotify(player, target.Name .. " didn't answer your gift in time. Nothing was sent.", false)
			giftNotify(target, "The gift from " .. player.Name .. " expired.", false)
		end
	end)
	return { success = true, message = "Gift sent! Waiting for " .. target.DisplayName .. " to accept..." }
end

giftRespondRemote.OnServerInvoke = function(player, giftId, accept)
	local p = pendingGifts[player]
	if not p or p.id ~= giftId then
		return { success = false, message = "That gift is no longer available." }
	end
	pendingGifts[player] = nil
	local sender = p.from
	if not accept then
		giftNotify(sender, player.Name .. " declined your gift. Nothing was sent.", false)
		return { success = true, message = "Gift declined." }
	end
	local sp, rp = sender.Parent and DataService.Get(sender), DataService.Get(player)
	if not sp or not rp then
		return { success = false, message = "The sender left the server. The gift was cancelled." }
	end
	-- check everything again right now, then move it all at once
	local g, err = checkGift(sender, sp, player, rp, p.payload)
	if not g then
		giftNotify(sender, "Your gift to " .. player.Name .. " failed: " .. err, false)
		return { success = false, message = "The gift couldn't be completed: " .. err }
	end
	if g.cash > 0 then
		sp.cash -= g.cash
		rp.cash += g.cash
	end
	for _, kind in ipairs({ "monsters", "eggs" }) do
		for _, uid in ipairs(g[kind]) do
			local e, i = findByUid(sp[kind], uid)
			table.remove(sp[kind], i)
			table.insert(rp[kind], e)
			if kind == "monsters" then
				sp.owned[e.monsterId] = math.max(0, (sp.owned[e.monsterId] or 1) - 1)
				rp.owned[e.monsterId] = (rp.owned[e.monsterId] or 0) + 1
			end
		end
	end
	for _, kind in ipairs({ "potions", "items" }) do
		for key, n in pairs(g[kind]) do
			sp[kind][key] -= n
			if sp[kind][key] <= 0 then
				sp[kind][key] = nil
			end
			rp[kind][key] = (rp[kind][key] or 0) + n
		end
	end
	sp.items.giftCard -= 1
	if sp.items.giftCard <= 0 then
		sp.items.giftCard = nil
	end
	local day = giftDay()
	if (sp.giftDaily or {}).day ~= day then
		sp.giftDaily = { day = day, count = 0 }
	end
	sp.giftDaily.count += 1
	updateLeaderstats(sender)
	updateLeaderstats(player)
	sync(sender)
	sync(player)
	giftNotify(sender, player.Name .. " accepted your gift!", true)
	return { success = true, message = "You received a gift from " .. sender.DisplayName .. "!" }
end

Players.PlayerRemoving:Connect(function(player)
	pendingGifts[player] = nil
	for target, p in pairs(pendingGifts) do
		if p.from == player then
			pendingGifts[target] = nil
			giftNotify(target, "The gift from " .. player.Name .. " was cancelled (they left).", false)
		end
	end
end)

--------------------------------------------------------------------
-- Equip Best: put your highest cash/s monsters in the pen, rest to backpack
--------------------------------------------------------------------
equipBestRemote.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end
	local cap = (Config.GetPenMonsterCap(profile.upgrades) + Config.PassExtraMonsters(profile))
	local all = {}
	for _, e in ipairs(profile.base) do
		if e.kind == "monster" then
			table.insert(all, e)
		end
	end
	for _, e in ipairs(profile.monsters) do
		table.insert(all, e)
	end
	table.sort(all, function(a, b)
		local ia, ib = Config.GetEntryIncome(a), Config.GetEntryIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return (a.level or 1) > (b.level or 1)
	end)
	local best = {}
	for i = 1, math.min(cap, #all) do
		best[all[i].uid] = true
	end
	-- pen monsters that aren't the best go back to the backpack
	local freeSpots = {}
	for i = #profile.base, 1, -1 do
		local e = profile.base[i]
		if e.kind == "monster" and not best[e.uid] then
			table.remove(profile.base, i)
			table.insert(freeSpots, e.position)
			e.kind = nil
			e.position = nil
			table.insert(profile.monsters, e)
		end
	end
	local function spotFree(x, z)
		for _, e in ipairs(profile.base) do
			local p = e.position
			if p and math.abs(p.x - x) < 7 and math.abs(p.z - z) < 7 then
				return false
			end
		end
		return true
	end
	local grid = {}
	for _, z in ipairs({ -14, 0, 14 }) do
		for _, x in ipairs({ -24, -12, 0, 12, 24 }) do
			table.insert(grid, { x = x, z = z })
		end
	end
	local swapped = 0
	for i = #profile.monsters, 1, -1 do
		local e = profile.monsters[i]
		if best[e.uid] then
			local spot
			while #freeSpots > 0 and not spot do
				local s = table.remove(freeSpots)
				if s and spotFree(s.x, s.z) then
					spot = s
				end
			end
			if not spot then
				for _, g in ipairs(grid) do
					if spotFree(g.x, g.z) then
						spot = g
						break
					end
				end
			end
			if spot then
				table.remove(profile.monsters, i)
				e.kind = "monster"
				e.position = { x = spot.x, z = spot.z }
				table.insert(profile.base, e)
				swapped += 1
			end
		end
	end
	WorldService.UpdateBase(player, profile)
	sync(player)
	return {
		success = true,
		message = swapped > 0 and ("Equipped your best pets! (" .. swapped .. " swapped in)") or "Your best pets are already equipped!",
		profile = DataService.PublicProfile(profile),
	}
end

--------------------------------------------------------------------
-- Gear Shop (Kurt): per-player stock that restocks every 5 minutes.
-- The stock is saved, so leaving and rejoining can't reroll it.
--------------------------------------------------------------------
local gearRng = Random.new()

local function gearSlot()
	return math.floor(os.time() / Config.GearRestockSeconds)
end

-- makes sure the player's stock is for the current 5-minute slot
local function ensureGearStock(profile)
	local slot = gearSlot()
	if type(profile.gearStock) ~= "table" or profile.gearStock.slot ~= slot then
		local items = {}
		for _, g in ipairs(Config.Gears) do
			-- each hit rolls again for one more, up to GearMaxStock
			local n = 0
			while n < (Config.GearMaxStock or 5) and gearRng:NextNumber() < g.chance do
				n += 1
			end
			if n > 0 then
				items[g.key] = n
			end
		end
		profile.gearStock = { slot = slot, items = items }
		return true
	end
	return false
end

local function gearShopState(profile)
	return { items = table.clone(profile.gearStock.items), restockAt = (gearSlot() + 1) * Config.GearRestockSeconds }
end

gearShopRemote.OnServerInvoke = function(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	ensureGearStock(profile)
	return gearShopState(profile)
end

buyGearRemote.OnServerInvoke = function(player, key)
	local profile = DataService.Get(player)
	local gear = type(key) == "string" and Config.GetGear(key)
	if not profile or not gear then
		return { success = false, message = "That gear doesn't exist." }
	end
	ensureGearStock(profile)
	if (profile.gearStock.items[key] or 0) <= 0 then
		return { success = false, message = gear.name .. " is sold out. Wait for the next restock!", shop = gearShopState(profile) }
	end
	if (profile.riftShards or 0) < gear.price then
		return { success = false, message = "You need " .. gear.price .. " Rift Shards.", shop = gearShopState(profile) }
	end
	profile.riftShards -= gear.price
	profile.gearStock.items[key] -= 1
	if profile.gearStock.items[key] <= 0 then
		profile.gearStock.items[key] = nil
	end
	if gear.item then
		profile.items[key] = (profile.items[key] or 0) + 1 -- e.g. Warp Remote: used from the WARP menu
	else
		profile.gears[key] = (profile.gears[key] or 0) + 1
	end
	sync(player)
	return { success = true, message = "Bought " .. gear.name .. "! It's in your backpack (ITEMS).", shop = gearShopState(profile), profile = DataService.PublicProfile(profile) }
end

-- a small campfire in your pen while the Campfire boost lasts
local function placeCampfire(player, seconds)
	local pen = WorldService.GetPen(player)
	local spawnPart = pen and pen.model and pen.model:FindFirstChild("PenSpawn")
	if not spawnPart then
		return
	end
	local old = pen.model:FindFirstChild("Campfire")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "Campfire"
	local g = spawnPart.Position - Vector3.new(0, spawnPart.Size.Y / 2 + 0.5, 0)
	local function part(size, cf, color, material)
		local p = Instance.new("Part")
		p.Size, p.CFrame, p.Color = size, cf, color
		p.Material = material or Enum.Material.Wood
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Parent = m
		return p
	end
	part(Vector3.new(5, 0.8, 0.8), CFrame.new(g + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(110, 70, 40))
	part(Vector3.new(5, 0.8, 0.8), CFrame.new(g + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.rad(-45), 0), Color3.fromRGB(95, 60, 35))
	local flame = part(Vector3.new(1.6, 1.6, 1.6), CFrame.new(g + Vector3.new(0, 1.6, 0)), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 8
	fire.Parent = flame
	m.Parent = pen.model
	task.delay(seconds, function()
		if m.Parent then
			m:Destroy()
		end
	end)
end

useGearRemote.OnServerInvoke = function(player, key, targetUid)
	local profile = DataService.Get(player)
	local gear = type(key) == "string" and Config.GetGear(key)
	if not profile or not gear then
		return { success = false, message = "That gear doesn't exist." }
	end
	if (profile.gears[key] or 0) <= 0 then
		return { success = false, message = "You don't have a " .. gear.name .. "." }
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.time()
	profile.activeBoosts = profile.activeBoosts or {}
	if key == "speedBoots" or key == "campfire" then
		profile.activeBoosts[key] = math.max(now, profile.activeBoosts[key] or 0) + gear.duration
		if key == "speedBoots" then
			applyWalkSpeed(player, profile)
		else
			placeCampfire(player, profile.activeBoosts[key] - now)
		end
	elseif key == "tauntTotem" or key == "healingSpring" then
		if not hrp then
			return { success = false, message = "Your character isn't ready." }
		end
		if key == "tauntTotem" then
			EnemyService.AddTaunt(player, hrp.Position + hrp.CFrame.LookVector * 6, gear.duration)
		else
			EnemyService.AddHealZone(player, hrp.Position, gear.duration)
		end
	elseif key == "reviveFeather" then
		local target
		for _, list in ipairs({ profile.base, profile.monsters }) do
			for _, e in ipairs(list) do
				if e.defeated and (type(targetUid) ~= "string" or e.uid == targetUid) and not target then
					target = e
				end
			end
		end
		if not target then
			return { success = false, message = "None of your pets need reviving." }
		end
		target.defeated = nil
		target.defeatedAt = nil
		EnemyService.ResetPet(target.uid)
		WorldService.UpdateBase(player, profile)
	end
	profile.gears[key] -= 1
	if profile.gears[key] <= 0 then
		profile.gears[key] = nil
	end
	sync(player)
	return { success = true, message = gear.name .. " used!", profile = DataService.PublicProfile(profile) }
end

-- restock every 5 minutes (+ tell each player what's in stock),
-- and keep walk speed in sync with Speed Boots
task.spawn(function()
	local lastSlot = gearSlot()
	while true do
		task.wait(1)
		local slot = gearSlot()
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if profile then
				applyWalkSpeed(player, profile)
				if slot ~= lastSlot then
					ensureGearStock(profile)
					local names = {}
					for _, g in ipairs(Config.Gears) do
						if profile.gearStock.items[g.key] then
							table.insert(names, g.name)
						end
					end
					sync(player)
					gearRestockRemote:FireClient(player, { names = names, shop = gearShopState(profile) })
				end
			end
		end
		lastSlot = slot
	end
end)

-- Biome gates: unlock in order (Forest first), paid with cash.
unlockBiomeRemote.OnServerInvoke = function(player, key)
	local profile = DataService.Get(player)
	if not profile or type(key) ~= "string" then
		return { success = false, message = "Could not unlock." }
	end
	profile.unlockedBiomes = profile.unlockedBiomes or { home = true }
	local index
	for i, b in ipairs(Config.Biomes) do
		if b.key == key then
			index = i
		end
	end
	local biome = index and Config.Biomes[index]
	if not biome or not biome.cost then
		return { success = false, message = "That area can't be unlocked." }
	end
	if profile.unlockedBiomes[key] then
		return { success = false, message = "Already unlocked!" }
	end
	local prev = Config.Biomes[index - 1]
	if prev and prev.cost and not profile.unlockedBiomes[prev.key] then
		return { success = false, message = "Unlock " .. prev.name .. " first!" }
	end
	if profile.cash < biome.cost then
		return { success = false, message = "You need $" .. Config.FormatNumber(biome.cost) .. " to unlock " .. biome.name .. "." }
	end
	profile.cash -= biome.cost
	profile.unlockedBiomes[key] = true
	updateLeaderstats(player)
	sync(player)
	return { success = true, message = "Unlocked " .. biome.name .. "!", profile = DataService.PublicProfile(profile) }
end

-- Anyone standing in a biome they haven't unlocked is pushed back out
-- through its gate (the gates themselves are built on each client).
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if profile and root then
				local biome = Config.GetBiomeAt(root.Position.X, root.Position.Z)
				if biome and biome.cost and not (profile.unlockedBiomes and profile.unlockedBiomes[biome.key]) then
					local entryZ = biome.center.Y + biome.size.Y / 2 + 10
					root.CFrame = CFrame.new(biome.center.X, root.Position.Y + 3, entryZ)
				end
			end
		end
	end
end)

buyUpgradeRemote.OnServerInvoke = function(player, nodeId)
	local profile = DataService.Get(player)
	local node = type(nodeId) == "string" and Config.GetUpgradeNode(nodeId)
	if not profile or not node then
		return { success = false, message = "That upgrade does not exist." }
	end

	if profile.upgrades[nodeId] then
		return { success = false, message = "You already own this upgrade." }
	end
	if node.requires and not profile.upgrades[node.requires] then
		return { success = false, message = "Purchase the previous tier first." }
	end
	if Config.UpgradeFunds(profile, node) < node.cost then
		return { success = false, message = "You need " .. Config.UpgradePriceText(node) .. " for this upgrade." }
	end

	if node.currency == "shards" then
		profile.riftShards -= node.cost
	else
		profile.cash -= node.cost
	end
	profile.upgrades[nodeId] = true
	QuestService.Add(profile, "upgrades", 1)
	updateLeaderstats(player)

	if node.statKey == "speed" then
		applyWalkSpeed(player, profile)
	end

	sync(player)

	local statInfo = Config.UpgradeStatInfo[node.statKey]
	return {
		success = true,
		message = string.format("Purchased %s Tier %d.", statInfo and statInfo.name or node.statKey, node.tier),
		profile = DataService.PublicProfile(profile),
	}
end

shopRemote.OnServerInvoke = function(player, itemKey)
	local profile = DataService.Get(player)
	local item = Config.ShopItems[itemKey]
	if not profile or not item then
		return { success = false, message = "That shop item does not exist." }
	end
	if profile.cash < item.cost then
		return { success = false, message = "You need $" .. item.cost .. " to buy that item." }
	end

	profile.cash -= item.cost
	if itemKey == "luckPotion" then
		profile.luck = math.min(10, profile.luck + 1)
	elseif itemKey == "incomeBoost" then
		profile.incomeBoost = math.min(5, profile.incomeBoost + 0.25)
	end

	updateLeaderstats(player)
	sync(player)
	return {
		success = true,
		message = "Purchased " .. item.name .. ".",
		profile = DataService.PublicProfile(profile),
	}
end

bossRemote.OnServerInvoke = function(player)
	local now = os.clock()
	if lastBossAt[player] and now - lastBossAt[player] < BOSS_COOLDOWN then
		return { success = false, message = "The boss is recovering. Try again soon." }
	end

	local profile = DataService.Get(player)
	if not profile then
		return { success = false, message = "Your profile is still loading." }
	end

	lastBossAt[player] = now
	local power = WorldService.GetProfilePower(profile)
	if power < Config.BossPower then
		return {
			success = false,
			message = string.format("Your base power is %d. You need %d to defeat the Boss.", power, Config.BossPower),
			profile = DataService.PublicProfile(profile),
		}
	end

	profile.cash += Config.BossReward
	profile.bossWins += 1
	updateLeaderstats(player)
	sync(player)
	return {
		success = true,
		message = string.format("Boss defeated! You earned $%d.", Config.BossReward),
		profile = DataService.PublicProfile(profile),
	}
end

pvpRemote.OnServerInvoke = function(player, targetUserId)
	local now = os.clock()
	if lastPvpAt[player] and now - lastPvpAt[player] < PVP_COOLDOWN then
		return { success = false, message = "Wait before starting another battle." }
	end

	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	local profile = DataService.Get(player)
	local targetProfile = target and DataService.Get(target)
	if not target or target == player or not profile or not targetProfile then
		return { success = false, message = "That player is not available for PvP." }
	end

	lastPvpAt[player] = now
	local playerPower = WorldService.GetProfilePower(profile)
	local targetPower = WorldService.GetProfilePower(targetProfile)
	local winner = playerPower >= targetPower and player or target
	local loser = winner == player and target or player
	local winnerProfile = DataService.Get(winner)
	winnerProfile.cash += 500
	winnerProfile.pvpWins += 1
	updateLeaderstats(winner)
	sync(winner)
	sync(loser)

	return {
		success = true,
		message = winner.Name .. " won the PvP battle and earned $500.",
		winnerUserId = winner.UserId,
		playerPower = playerPower,
		targetPower = targetPower,
		profile = DataService.PublicProfile(profile),
	}
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if profile then
				profile.cash += WorldService.GetProfileIncome(profile)
				updateLeaderstats(player)
				sync(player)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.Save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.Save(player)
	end
end)
-- Carry pose (holding an egg / monster): bend the arm joints on the
-- server so it shows in the real game and for everyone (players' screens
-- keep the arms still while it's on: see HoldPoseClient)
do
	local holdPoseRemote = getRemote("HoldPose", "RemoteEvent")
	local R = math.rad
	local R15 = {
		{ "RightUpperArm", "RightShoulder", CFrame.fromEulerAnglesYXZ(R(65), R(22), 0) },
		{ "LeftUpperArm", "LeftShoulder", CFrame.fromEulerAnglesYXZ(R(65), R(-22), 0) },
		{ "RightLowerArm", "RightElbow", CFrame.Angles(R(18), 0, 0) },
		{ "LeftLowerArm", "LeftElbow", CFrame.Angles(R(18), 0, 0) },
	}
	local R6 = {
		{ "Torso", "Right Shoulder", CFrame.Angles(0, 0, R(70)) },
		{ "Torso", "Left Shoulder", CFrame.Angles(0, 0, R(-70)) },
	}
	local function apply(player, on)
		local character = player.Character
		if not character then
			return
		end
		local list = character:FindFirstChild("UpperTorso") and R15 or R6
		for _, j in ipairs(list) do
			local holder = character:FindFirstChild(j[1])
			local joint = holder and holder:FindFirstChild(j[2])
			-- classic joints (Motor6D: C0) or new avatar joints
			-- (AnimationConstraint: its parent-side attachment)
			local target, prop
			if joint and joint:IsA("Motor6D") then
				target, prop = joint, "C0"
			elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
				target, prop = joint.Attachment0, "CFrame"
			end
			if target then
				local base = target:GetAttribute("BaseC0")
				if base == nil then
					base = target[prop]
					target:SetAttribute("BaseC0", base)
				end
				target[prop] = on and (base * j[3]) or base
			end
		end
		player:SetAttribute("Holding", on or nil)
	end
	holdPoseRemote.OnServerEvent:Connect(function(player, on)
		apply(player, on == true)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Holding", nil)
		end)
	end)
end

-- Guilds (Guild Hall stall)
local GuildService = require(game:GetService("ServerScriptService").MonsterRNG.GuildService)
GuildService.Start({
	DataService = DataService,
	sync = sync,
	getRemote = getRemote,
})
-- PvP (challenge posts, arena fights, credits, seasons)
require(script:FindFirstChild("MonsterRNG") and script.MonsterRNG.PvpService or game:GetService("ServerScriptService").MonsterRNG.PvpService).Start({
	DataService = DataService,
	sync = sync,
	getRemote = getRemote,
})
-- enemies + combat
EnemyService.Start({ sync = sync, updateLeaderstats = updateLeaderstats, fx = combatFxRemote })

--------------------------------------------------------------------
-- ADMIN (only the ids in ADMIN_IDS). Everything is checked here on the
-- server, so nobody else can use these remotes even if they fire them.
--   * Dev chat: a message goes to EVERY server (MessagingService) and
--     shows as a notification: [Dev]KaidenBYND : text
--   * Give: cash, rift shards, eggs, monsters, potions, items, gears to
--     one player or everyone in this server.
--------------------------------------------------------------------
do
	local MessagingService = game:GetService("MessagingService")
	local HttpServiceA = game:GetService("HttpService")
	local ADMIN_IDS = { [1165846861] = true }
	local DEV_TAG = "[Dev]KaidenBYND"
	local TOPIC = "MonsterRNG_DevChat"

	local adminRemote = getRemote("AdminAction", "RemoteFunction")
	local devAnnounce = getRemote("DevAnnounce", "RemoteEvent")

	local function isAdmin(player)
		return player and ADMIN_IDS[player.UserId] == true
	end

	local function showEverywhereHere(text)
		devAnnounce:FireAllClients({ kind = "dev", text = DEV_TAG .. " : " .. text })
	end

	-- messages from other servers (and this one)
	task.spawn(function()
		local ok = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(msg)
				local data = msg.Data
				if type(data) == "table" and type(data.text) == "string" then
					showEverywhereHere(data.text)
				end
			end)
		end)
		if not ok then
			warn("[Admin] dev chat: MessagingService not available here (Studio) - messages show in this server only")
		end
	end)

	local lastChat = 0
	local function pickSize(key)
		for _, v in ipairs(Config.SizeVariants) do
			if v.key == key then
				return v.key
			end
		end
		return Config.SizeVariants[1].key
	end
	local function pickFinish(key)
		for _, v in ipairs(Config.FinishVariants) do
			if v.key == key then
				return v.key
			end
		end
		return Config.FinishVariants[1].key
	end
	local function monstersOf(rarityKey)
		local list = {}
		for _, m in ipairs(Config.Monsters) do
			if m.rarity == rarityKey then
				table.insert(list, m)
			end
		end
		return list
	end

	-- put one gift into a profile (online OR offline); returns a short description or nil
	local function applyGive(profile, req)
		local n = math.clamp(math.floor(tonumber(req.amount) or 1), 1, 1e15)
		local kind, key = req.kind, req.key
		local what
		if kind == "cash" then
			profile.cash += n
			what = Config.FormatNumber(n) .. " Cash"
		elseif kind == "shards" then
			profile.riftShards = (profile.riftShards or 0) + n
			what = Config.FormatNumber(n) .. " Rift Shards"
		elseif kind == "egg" or kind == "monster" then
			n = math.min(n, 100)
			local size, finish = pickSize(req.size), pickFinish(req.finish)
			local monster = kind == "monster" and Config.GetMonster(key)
			if kind == "monster" and not monster then
				return nil
			end
			for _ = 1, n do
				local m = monster
				if kind == "egg" then
					local list = monstersOf(key)
					if #list == 0 then
						return nil
					end
					m = list[math.random(1, #list)]
				end
				local entry = {
					uid = HttpServiceA:GenerateGUID(false),
					monsterId = m.id,
					size = size,
					finish = finish,
					kg = Config.RollKg(m.id, size),
				}
				if kind == "egg" then
					entry.rarity = m.rarity
					table.insert(profile.eggs, entry)
				else
					entry.level = 1
					table.insert(profile.monsters, entry)
					profile.owned[m.id] = (profile.owned[m.id] or 0) + 1
				end
			end
			local label = kind == "egg" and (Config.GetRarity(key).name .. " Egg") or monster.name
			local extra = (size ~= "Normal" and (size .. " ") or "") .. (finish ~= "Normal" and (finish .. " ") or "")
			what = n .. "x " .. extra .. label
		elseif kind == "potion" then
			n = math.min(n, 1000)
			local found
			for _, p in ipairs(Config.Potions) do
				if p.key == key then
					found = p
				end
			end
			if not found then
				return nil
			end
			profile.potions[key] = (profile.potions[key] or 0) + n
			what = n .. "x " .. found.name
		elseif kind == "item" then
			n = math.min(n, 1000)
			local item = Config.Items[key]
			if not item then
				return nil
			end
			profile.items[key] = (profile.items[key] or 0) + n
			what = n .. "x " .. item.name
		elseif kind == "pass" then
			-- works like the real gamepass in this game (not owned on Roblox)
			local found
			for _, g in ipairs(Config.Gamepasses) do
				if g.key == key then
					found = g
				end
			end
			if not found then
				return nil
			end
			profile.adminPasses = profile.adminPasses or {}
			profile.adminPasses[key] = (not req.remove) or nil
			what = (req.remove and "Removed gamepass " or "gamepass ") .. found.name
		elseif kind == "tag" then
			if key ~= "admin" and key ~= "tester" and key ~= "beta" then
				return nil
			end
			profile.tags = profile.tags or {}
			profile.tags[key] = (not req.remove) or nil
			what = (req.remove and "Removed tag " or "tag ") .. Config.PassTags[key].text
		elseif kind == "gear" then
			n = math.min(n, 1000)
			local found
			for _, g in ipairs(Config.Gears) do
				if g.key == key then
					found = g
				end
			end
			if not found then
				return nil
			end
			profile.gears = profile.gears or {}
			profile.gears[key] = (profile.gears[key] or 0) + n
			what = n .. "x " .. found.name
		else
			return nil
		end
		return what
	end

	-- give to a player in THIS server
	local function giveTo(player, req)
		local profile = DataService.Get(player)
		if not profile then
			return nil
		end
		local what = applyGive(profile, req)
		if not what then
			return nil
		end
		if req.kind == "pass" or req.kind == "tag" then
			updatePassTag(player, profile)
			applyWalkSpeed(player, profile)
			WorldService.UpdateBase(player, profile)
		end
		updateLeaderstats(player)
		sync(player)
		task.spawn(DataService.Save, player)
		if not req.remove then
			devAnnounce:FireClient(player, { kind = "gift", text = "The Dev gave you " .. what .. "!" })
		end
		return what
	end

	----------------------------------------------------------------
	-- Global give: players in other servers or offline.
	-- Every gift goes into a "pending gifts" DataStore list for that
	-- userId. Whichever server the player is in claims it (atomically,
	-- so it's never given twice); if they're offline they get it the
	-- next time they join. A MessagingService ping makes it instant.
	----------------------------------------------------------------
	local GIFT_TOPIC = "MonsterRNG_AdminGift"
	local ACK_TOPIC = "MonsterRNG_AdminGiftAck"
	local giftStore
	pcall(function()
		giftStore = game:GetService("DataStoreService"):GetDataStore("MonsterRNG_PendingGifts")
	end)
	local acks = {} -- gift id -> "delivered text"

	local function claimGifts(player)
		if not giftStore or not DataService.Get(player) then
			return
		end
		local claimed = {}
		local ok = pcall(function()
			giftStore:UpdateAsync("u_" .. player.UserId, function(old)
				claimed = {}
				if type(old) ~= "table" or #old == 0 then
					return nil
				end
				for _, g in ipairs(old) do
					table.insert(claimed, g)
				end
				return {}
			end)
		end)
		if not ok then
			return
		end
		for _, g in ipairs(claimed) do
			if type(g) == "table" and type(g.req) == "table" then
				local what = giveTo(player, g.req)
				if what and g.id then
					pcall(function()
						MessagingService:PublishAsync(ACK_TOPIC, { id = g.id, text = what, name = player.Name })
					end)
				end
			end
		end
	end
	Players.PlayerAdded:Connect(function(player)
		for _ = 1, 40 do
			if DataService.Get(player) or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		task.wait(2)
		claimGifts(player)
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(GIFT_TOPIC, function(msg)
				local d = msg.Data
				if type(d) ~= "table" then
					return
				end
				if d.all and type(d.req) == "table" then
					for _, p in ipairs(Players:GetPlayers()) do
						giveTo(p, d.req)
					end
				else
					local p = Players:GetPlayerByUserId(tonumber(d.userId) or 0)
					if p then
						claimGifts(p)
					end
				end
			end)
		end)
		pcall(function()
			MessagingService:SubscribeAsync(ACK_TOPIC, function(msg)
				local d = msg.Data
				if type(d) == "table" and d.id then
					acks[d.id] = (d.name or "?") .. " got " .. tostring(d.text)
				end
			end)
		end)
	end)
	-- safety net in case a ping was missed
	task.spawn(function()
		while true do
			task.wait(90)
			for _, p in ipairs(Players:GetPlayers()) do
				local ok, list = pcall(function()
					return giftStore and giftStore:GetAsync("u_" .. p.UserId)
				end)
				if ok and type(list) == "table" and #list > 0 then
					claimGifts(p)
				end
			end
		end
	end)

	local function resolveUser(target)
		local id = tonumber(target)
		local name
		if not id and type(target) == "string" then
			local want = target:gsub("^@", ""):gsub("%s", "")
			local ok, uid = pcall(function()
				return Players:GetUserIdFromNameAsync(want)
			end)
			if ok and uid then
				id = uid
				name = want
			end
		end
		if id and not name then
			local ok, n = pcall(function()
				return Players:GetNameFromUserIdAsync(id)
			end)
			name = ok and n or tostring(id)
		end
		return id, name
	end

	-- a player in another server or offline
	local function giveRemote(userId, name, req)
		if not giftStore then
			return false, "DataStores are not available (turn on API access in Game Settings)."
		end
		-- check the gift is valid before saving it
		local test = applyGive(DataService.Sanitize and DataService.Sanitize(nil) or { cash = 0, eggs = {}, monsters = {}, owned = {}, potions = {}, items = {}, gears = {}, adminPasses = {}, tags = {} }, req)
		if not test then
			return false, "Could not give that."
		end
		local id = HttpServiceA:GenerateGUID(false)
		local ok = pcall(function()
			giftStore:UpdateAsync("u_" .. userId, function(old)
				old = type(old) == "table" and old or {}
				table.insert(old, { id = id, req = req, t = os.time() })
				return old
			end)
		end)
		if not ok then
			return false, "Could not save the gift, try again."
		end
		pcall(function()
			MessagingService:PublishAsync(GIFT_TOPIC, { userId = userId })
		end)
		for _ = 1, 16 do -- wait up to ~4s for the other server to say it got it
			if acks[id] then
				local t = acks[id]
				acks[id] = nil
				return true, t .. " (in another server)."
			end
			task.wait(0.25)
		end
		return true, (req.remove and (test .. " from ") or ("Sent " .. test .. " to ")) .. name .. ". They're offline - it applies when they join."
	end

	----------------------------------------------------------------
	-- Server-wide effects (luck / damage / health / income / exp,
	-- 1x-8x for a set time) in EVERY server. Saved in a DataStore so
	-- servers that start later get them too, and sent with
	-- MessagingService so running servers update right away.
	----------------------------------------------------------------
	local EFFECT_TOPIC = "MonsterRNG_GlobalBoosts"
	local effectStore
	pcall(function()
		effectStore = game:GetService("DataStoreService"):GetDataStore("MonsterRNG_Global")
	end)
	local holder = ReplicatedStorage:WaitForChild("MonsterRNG")
	local KIND = {}
	for _, k in ipairs(Config.GlobalBoostKinds) do
		KIND[k.key] = k
	end
	local function applyEffect(key, mult, ends)
		if not KIND[key] then
			return false
		end
		local was = Config.GlobalBoost(key)
		holder:SetAttribute("GB_" .. key .. "_m", mult)
		holder:SetAttribute("GB_" .. key .. "_e", ends)
		return was ~= Config.GlobalBoost(key)
	end
	local function applyAll(tbl)
		if type(tbl) ~= "table" then
			return
		end
		for key, v in pairs(tbl) do
			if type(v) == "table" and tonumber(v.m) and tonumber(v.e) then
				applyEffect(key, math.clamp(tonumber(v.m), 1, Config.GlobalBoostMax), tonumber(v.e))
			end
		end
	end
	local function fmtTime(sec)
		sec = math.max(0, math.floor(sec))
		if sec >= 86400 then
			return string.format("%dd %dh", sec // 86400, (sec % 86400) // 3600)
		elseif sec >= 3600 then
			return string.format("%dh %dm", sec // 3600, (sec % 3600) // 60)
		elseif sec >= 60 then
			return string.format("%dm", math.ceil(sec / 60))
		end
		return sec .. "s"
	end
	local function announceEffect(key, mult, ends)
		local k = KIND[key]
		if not k then
			return
		end
		local text
		if mult > 1 and ends > os.time() then
			text = string.format("[Dev] started %sx %s for %s in every server!", tostring(mult), k.name:upper(), fmtTime(ends - os.time()))
		else
			text = "[Dev] ended the " .. k.name:upper() .. " effect."
		end
		devAnnounce:FireAllClients({ kind = "dev", text = text })
	end
	-- load saved effects when this server starts + re-check every minute
	task.spawn(function()
		while true do
			if effectStore then
				local ok, data = pcall(function()
					return effectStore:GetAsync("boosts")
				end)
				if ok then
					applyAll(data)
				end
			end
			task.wait(60)
		end
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(EFFECT_TOPIC, function(msg)
				local d = msg.Data
				if type(d) == "table" and type(d.key) == "string" and tonumber(d.m) and tonumber(d.e) then
					applyEffect(d.key, math.clamp(tonumber(d.m), 1, Config.GlobalBoostMax), tonumber(d.e))
					announceEffect(d.key, tonumber(d.m), tonumber(d.e))
				end
			end)
		end)
	end)
	local function startEffect(key, mult, seconds)
		local ends = mult > 1 and (os.time() + seconds) or 0
		if effectStore then
			pcall(function()
				effectStore:UpdateAsync("boosts", function(old)
					old = type(old) == "table" and old or {}
					for k, v in pairs(old) do -- drop finished ones
						if type(v) ~= "table" or (tonumber(v.e) or 0) <= os.time() then
							old[k] = nil
						end
					end
					old[key] = ends > 0 and { m = mult, e = ends } or nil
					return old
				end)
			end)
		end
		local sent = pcall(function()
			MessagingService:PublishAsync(EFFECT_TOPIC, { key = key, m = mult, e = ends })
		end)
		if not sent then -- Studio: this server only
			applyEffect(key, mult, ends)
			announceEffect(key, mult, ends)
		end
		return sent
	end

	----------------------------------------------------------------
	-- Codes: the admin makes them in the Admin panel (CODES tab), players
	-- redeem them in the Shop. Saved in a DataStore so every server has
	-- them; a MessagingService ping makes new codes work right away.
	--   codes[CODE] = { rewards = { {kind,key,amount,size,finish} },
	--                   expires = unix time or nil, maxUses = n or nil }
	-- Each player can redeem a code once (profile.redeemedCodes).
	----------------------------------------------------------------
	local CODES_TOPIC = "MonsterRNG_CodesChanged"
	local CODE_KINDS = { cash = true, shards = true, egg = true, monster = true, potion = true, item = true, gear = true }
	local codeStore
	pcall(function()
		codeStore = game:GetService("DataStoreService"):GetDataStore("MonsterRNG_Codes")
	end)
	local codes = {}
	local codesLoadedAt = -math.huge
	local function loadCodes()
		if not codeStore then
			return
		end
		local ok, data = pcall(function()
			return codeStore:GetAsync("all")
		end)
		if ok then
			codes = type(data) == "table" and data or {}
			codesLoadedAt = os.clock()
		end
	end
	task.spawn(function()
		loadCodes()
		pcall(function()
			MessagingService:SubscribeAsync(CODES_TOPIC, function()
				loadCodes()
			end)
		end)
		while true do
			task.wait(60)
			loadCodes()
		end
	end)
	local function cleanCode(text)
		if type(text) ~= "string" then
			return nil
		end
		local c = text:upper():gsub("%s", "")
		if not c:match("^[%w_]+$") or #c < 2 or #c > 24 then
			return nil
		end
		return c
	end
	local function cleanRewards(list)
		local out = {}
		if type(list) ~= "table" then
			return out
		end
		for _, r in ipairs(list) do
			if #out >= 12 then
				break
			end
			if type(r) == "table" and CODE_KINDS[r.kind] then
				table.insert(out, {
					kind = r.kind,
					key = type(r.key) == "string" and r.key or nil,
					amount = math.clamp(math.floor(tonumber(r.amount) or 1), 1, 1e15),
					size = type(r.size) == "string" and r.size or "Normal",
					finish = type(r.finish) == "string" and r.finish or "Normal",
				})
			end
		end
		return out
	end
	local function editCodes(fn)
		if not codeStore then
			return false, "DataStore not available (turn on API access in Studio)."
		end
		local ok, err = pcall(function()
			codeStore:UpdateAsync("all", function(old)
				old = type(old) == "table" and old or {}
				fn(old)
				codes = old
				return old
			end)
		end)
		if ok then
			codesLoadedAt = os.clock()
			pcall(function()
				MessagingService:PublishAsync(CODES_TOPIC, { t = os.time() })
			end)
		end
		return ok, err
	end
	local function codeUses(code)
		if not codeStore then
			return 0
		end
		local ok, n = pcall(function()
			return codeStore:GetAsync("uses_" .. code)
		end)
		return ok and tonumber(n) or 0
	end
	local function handleCodes(action, req)
		if action == "codes_list" then
			local list = {}
			for code, c in pairs(codes) do
				table.insert(list, { code = code, rewards = c.rewards, expires = c.expires, maxUses = c.maxUses, uses = codeUses(code), created = c.created })
			end
			table.sort(list, function(a, b)
				return (a.created or 0) > (b.created or 0)
			end)
			return { success = true, codes = list, now = os.time() }
		elseif action == "code_save" and type(req) == "table" then
			local code = cleanCode(req.code)
			if not code then
				return { success = false, message = "Code: 2-24 letters / numbers, no spaces." }
			end
			local rewards = cleanRewards(req.rewards)
			if #rewards == 0 then
				return { success = false, message = "Add at least one reward (GIVE tab > + ADD TO CODE)." }
			end
			local hours = tonumber(req.hours)
			local maxUses = tonumber(req.maxUses)
			local ok, err = editCodes(function(all)
				local old = all[code]
				all[code] = {
					rewards = rewards,
					expires = (hours and hours > 0) and (os.time() + math.floor(hours * 3600)) or nil,
					maxUses = (maxUses and maxUses > 0) and math.floor(maxUses) or nil,
					created = old and old.created or os.time(),
				}
			end)
			if not ok then
				return { success = false, message = "Could not save: " .. tostring(err) }
			end
			return { success = true, message = "Code " .. code .. " saved! It works in every server." }
		elseif action == "code_delete" then
			local code = cleanCode(req)
			if not code then
				return { success = false, message = "Pick a code." }
			end
			local ok, err = editCodes(function(all)
				all[code] = nil
			end)
			return { success = ok, message = ok and ("Code " .. code .. " deleted.") or ("Could not delete: " .. tostring(err)) }
		end
		return { success = false, message = "Unknown code action." }
	end

	local redeemRemote = getRemote("RedeemCode", "RemoteFunction")
	local lastRedeem = {}
	redeemRemote.OnServerInvoke = function(player, text)
		local now = os.clock()
		if lastRedeem[player] and now - lastRedeem[player] < 2 then
			return { success = false, message = "Wait a moment before trying again." }
		end
		lastRedeem[player] = now
		local profile = DataService.Get(player)
		local code = cleanCode(text)
		if not profile or not code then
			return { success = false, message = "Type a code first." }
		end
		local c = codes[code]
		if not c and os.clock() - codesLoadedAt > 10 then
			loadCodes() -- maybe it was just made in another server
			c = codes[code]
		end
		if not c then
			return { success = false, message = "That code doesn't exist." }
		end
		if c.expires and os.time() > c.expires then
			return { success = false, message = "That code has expired." }
		end
		profile.redeemedCodes = profile.redeemedCodes or {}
		if profile.redeemedCodes[code] then
			return { success = false, message = "You already used this code." }
		end
		if c.maxUses then
			if not codeStore then
				return { success = false, message = "Codes aren't available right now." }
			end
			local full = false
			local ok = pcall(function()
				codeStore:UpdateAsync("uses_" .. code, function(old)
					old = tonumber(old) or 0
					if old >= c.maxUses then
						full = true
						return nil
					end
					full = false
					return old + 1
				end)
			end)
			if not ok then
				return { success = false, message = "Couldn't check the code. Try again." }
			end
			if full then
				return { success = false, message = "This code has been used up." }
			end
		elseif codeStore then
			task.spawn(function()
				pcall(function()
					codeStore:IncrementAsync("uses_" .. code, 1)
				end)
			end)
		end
		profile.redeemedCodes[code] = true
		local got = {}
		for _, r in ipairs(c.rewards or {}) do
			local what = applyGive(profile, r)
			if what then
				table.insert(got, what)
			end
		end
		updateLeaderstats(player)
		sync(player)
		task.spawn(DataService.Save, player)
		return { success = true, message = "Code redeemed! You got " .. (#got > 0 and table.concat(got, ", ") or "nothing") .. "!" }
	end
	Players.PlayerRemoving:Connect(function(p)
		lastRedeem[p] = nil
	end)

	adminRemote.OnServerInvoke = function(player, action, req)
		if not isAdmin(player) then
			return { success = false, message = "Not allowed." }
		end
		if action == "codes_list" or action == "code_save" or action == "code_delete" then
			return handleCodes(action, req)
		end
		if action == "chat" then
			local text = type(req) == "string" and req:sub(1, 200) or ""
			text = text:gsub("^%s+", ""):gsub("%s+$", "")
			if text == "" then
				return { success = false, message = "Type a message first." }
			end
			if os.clock() - lastChat < 2 then
				return { success = false, message = "Wait a moment before the next message." }
			end
			lastChat = os.clock()
			local ok, filtered = pcall(function()
				return game:GetService("TextService"):FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
			end)
			text = ok and filtered or text
			local sent = pcall(function()
				MessagingService:PublishAsync(TOPIC, { text = text })
			end)
			if not sent then
				showEverywhereHere(text) -- Studio / publish failed: at least this server
			end
			return { success = true, message = sent and "Sent to every server!" or "Sent (this server only)." }
		elseif action == "give" and type(req) == "table" then
			local targets = {}
			if req.target == "all" then
				targets = Players:GetPlayers()
			else
				local p = Players:GetPlayerByUserId(tonumber(req.target) or 0)
				if not p and type(req.target) == "string" then
					-- a typed username / display name (exact first, then starts-with)
					local want = req.target:lower():gsub("^@", "")
					for _, q in ipairs(Players:GetPlayers()) do
						if q.Name:lower() == want or q.DisplayName:lower() == want then
							p = q
						end
					end
				end
				if p then
					targets = { p }
				end
			end
			local clean = { kind = req.kind, key = req.key, amount = req.amount, size = req.size, finish = req.finish, remove = req.remove == true }
			if req.target == "all" then
				-- everyone here now + everyone in the other servers
				local what
				for _, p in ipairs(targets) do
					what = giveTo(p, clean) or what
				end
				if not what then
					return { success = false, message = "Could not give that." }
				end
				local sent = pcall(function()
					MessagingService:PublishAsync(GIFT_TOPIC, { all = true, req = clean })
				end)
				return { success = true, message = (clean.remove and (what .. " from everyone") or ("Gave " .. what .. " to everyone")) .. (sent and " in every server." or " in this server (Studio).") }
			end
			if #targets == 0 then
				-- not in this server: other server or offline
				local userId, name = resolveUser(req.target)
				if not userId and type(req.target) == "string" then
					-- not a real username: try the start of a name in this server
					local want = req.target:lower():gsub("^@", "")
					for _, q in ipairs(Players:GetPlayers()) do
						if q.Name:lower():sub(1, #want) == want or q.DisplayName:lower():sub(1, #want) == want then
							userId, name = q.UserId, q.Name
							break
						end
					end
				end
				if not userId then
					return { success = false, message = "No Roblox user named \"" .. tostring(req.target) .. "\"." }
				end
				local here = Players:GetPlayerByUserId(userId)
				if here then
					targets = { here }
				else
					local ok, msg = giveRemote(userId, name, clean)
					return { success = ok, message = msg }
				end
			end
			local what = giveTo(targets[1], clean)
			if not what then
				return { success = false, message = "Could not give that." }
			end
			return { success = true, message = (clean.remove and (what .. " from ") or ("Gave " .. what .. " to ")) .. targets[1].Name .. "." }
		elseif action == "effect" and type(req) == "table" then
			local key = req.key
			if not KIND[key] then
				return { success = false, message = "Pick an effect." }
			end
			local mult = math.clamp(math.floor(tonumber(req.mult) or 1), 1, Config.GlobalBoostMax)
			local seconds = math.clamp(math.floor(tonumber(req.seconds) or 0), 0, 7 * 86400)
			if mult > 1 and seconds < 10 then
				return { success = false, message = "Set a time first." }
			end
			local sent = startEffect(key, mult, seconds)
			local what = mult > 1 and (mult .. "x " .. KIND[key].name .. " for " .. fmtTime(seconds)) or (KIND[key].name .. " effect stopped")
			return { success = true, message = what .. (sent and " (every server)" or " (this server only - Studio)") }
		elseif action == "players" then
			local list = {}
			for _, p in ipairs(Players:GetPlayers()) do
				table.insert(list, { name = p.Name, display = p.DisplayName, userId = p.UserId })
			end
			return { success = true, players = list }
		end
		return { success = false, message = "Unknown action." }
	end
end

--------------------------------------------------------------------
-- DEVELOPER PRODUCTS (one ProcessReceipt for the whole game)
--   Hatch All: hatches every egg in the pen (incubating ones too)
--   Egg skip (1-24 hr): finishes the egg the player picked
--   Cash packs: % of the cash needed for the next rebirth
--------------------------------------------------------------------
do
	local eggSkipTarget = {} -- player -> base uid of the egg they want to skip
	local hatchAllRemote = getRemote("HatchAll", "RemoteFunction")
	local eggSkipRemote = getRemote("EggSkipTarget", "RemoteFunction")
	local purchaseNotice = getRemote("PurchaseNotice", "RemoteEvent")

	local function hatchEgg(player, uid)
		local ok, r = pcall(hatchRemote.OnServerInvoke, player, uid)
		return ok and r and r.success
	end
	local function readyAll(profile)
		local n = 0
		for _, e in ipairs(profile.base) do
			if e.kind == "egg" and not e.hatching and os.time() < (e.readyAt or 0) then
				e.readyAt = os.time()
				n += 1
			end
		end
		return n
	end

	-- free part of Hatch All: hatches every READY egg; tells the client how
	-- many are still incubating (so it can offer the Robux product)
	hatchAllRemote.OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		if not profile then
			return { success = false, message = "Not ready." }
		end
		local hatched, waiting = 0, 0
		local uids = {}
		for _, e in ipairs(profile.base) do
			if e.kind == "egg" and not e.hatching then
				if os.time() >= (e.readyAt or 0) then
					table.insert(uids, e.uid)
				else
					waiting += 1
				end
			end
		end
		for _, uid in ipairs(uids) do
			if hatchEgg(player, uid) then
				hatched += 1
			end
		end
		return { success = true, hatched = hatched, waiting = waiting, productId = Config.Products.hatchAll.id }
	end

	-- the player picked an egg to skip: returns which product to buy
	eggSkipRemote.OnServerInvoke = function(player, uid)
		local profile = DataService.Get(player)
		if not profile or type(uid) ~= "string" then
			return nil
		end
		for _, e in ipairs(profile.base) do
			if e.uid == uid and e.kind == "egg" and not e.hatching then
				local left = (e.readyAt or 0) - os.time()
				if left <= 0 then
					return { ready = true }
				end
				eggSkipTarget[player] = uid
				local tier = Config.EggSkipTier(left)
				return { productId = tier.id, hours = tier.hours, left = left }
			end
		end
		return nil
	end
	Players.PlayerRemoving:Connect(function(p)
		eggSkipTarget[p] = nil
	end)

	local handlers = {}
	handlers[Config.Products.hatchAll.id] = function(player, profile)
		readyAll(profile)
		local uids = {}
		for _, e in ipairs(profile.base) do
			if e.kind == "egg" and not e.hatching then
				table.insert(uids, e.uid)
			end
		end
		for _, uid in ipairs(uids) do
			hatchEgg(player, uid)
		end
		return "Hatching all your eggs!"
	end
	for _, tier in ipairs(Config.Products.eggSkip) do
		handlers[tier.id] = function(player, profile)
			local uid = eggSkipTarget[player]
			local target
			for _, e in ipairs(profile.base) do
				if e.kind == "egg" and not e.hatching and (e.uid == uid or (not uid and os.time() < (e.readyAt or 0))) then
					target = target or e
				end
			end
			if not target then -- the egg is gone: finish the egg with the most time left instead
				for _, e in ipairs(profile.base) do
					if e.kind == "egg" and not e.hatching and (not target or (e.readyAt or 0) > (target.readyAt or 0)) then
						target = e
					end
				end
			end
			eggSkipTarget[player] = nil
			if target then
				target.readyAt = os.time()
				hatchEgg(player, target.uid)
				return "Your egg is hatching!"
			end
			-- no egg at all: give the time back as cash so nothing is lost
			return "Egg skip used."
		end
	end
	-- guild: +member slots (only when a product id is set in Config.Guild)
	if (Config.Guild.slotProductId or 0) ~= 0 then
		handlers[Config.Guild.slotProductId] = function(player, profile)
			local msg = GuildService.AddSlots(player)
			if not msg then
				error("no guild to add slots to") -- not granted: Roblox tries again later
			end
			return msg
		end
	end
	for _, pack in ipairs(Config.Products.cash) do
		handlers[pack.id] = function(player, profile)
			local amount = Config.CashPackAmount(profile, pack.pct)
			profile.cash += amount
			return "+" .. Config.FormatNumber(amount) .. " Cash (" .. pack.name .. ")!"
		end
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local profile = player and DataService.Get(player)
		local handler = handlers[receipt.ProductId]
		if not player or not profile or not handler then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- never grant the same purchase twice
		profile.receipts = profile.receipts or {}
		if profile.receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local ok, msg = pcall(handler, player, profile)
		if not ok then
			warn("[Purchase] failed: " .. tostring(msg))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		profile.receipts[receipt.PurchaseId] = true
		updateLeaderstats(player)
		WorldService.UpdateBase(player, profile)
		sync(player)
		DataService.Save(player)
		purchaseNotice:FireClient(player, { text = msg })
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end
