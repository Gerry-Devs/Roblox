--------------------------------------------------------------------
-- GuildService: guilds that work across every server.
--   * create (free for now: Config.Guild.createProductId = 0)
--   * join (open guilds) / invites (any player, online or not)
--   * owner: edit name, description, emblem (preset or image id),
--     open / invite only, kick, make officer, buy more member slots
--   * officers: invite players
--
-- Saved in DataStores:
--   MonsterRNG_Guilds   g_<id> = the guild, n_<name> = id (unique names)
--   MonsterRNG_GuildIndex (ordered) id = member count (for the list)
--   MonsterRNG_GuildInvites u_<userId> = invites waiting for a player
--------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))
local G = Config.Guild

local GuildService = {}
local deps
local guildRemote, guildEvent

local store, indexStore, inviteStore
pcall(function()
	store = DataStoreService:GetDataStore("MonsterRNG_Guilds")
	indexStore = DataStoreService:GetOrderedDataStore("MonsterRNG_GuildIndex")
	inviteStore = DataStoreService:GetDataStore("MonsterRNG_GuildInvites")
end)
local TOPIC = "MonsterRNG_Guild"

local memory = {} -- Studio fallback when DataStores are off: key -> value
local cache = {} -- id -> { data, at }
local busy = {} -- player -> true while an action runs

--------------------------------------------------------------------
-- storage helpers (DataStore, or memory in Studio without API access)
--------------------------------------------------------------------
local function dsGet(ds, key)
	if ds then
		local ok, v = pcall(function()
			return ds:GetAsync(key)
		end)
		if ok then
			return v
		end
	end
	return memory[tostring(ds) .. key]
end
-- fn(old) -> new (nil = no change). Returns ok, new value
local function dsUpdate(ds, key, fn)
	if ds then
		local result
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old)
				result = fn(old)
				return result
			end)
		end)
		if ok then
			return true, result
		end
		warn("[Guild] " .. tostring(err))
		return false
	end
	local k = tostring(ds) .. key
	local new = fn(memory[k])
	if new ~= nil then
		memory[k] = new
	end
	return true, new
end
local function dsRemove(ds, key)
	if ds then
		pcall(function()
			ds:RemoveAsync(key)
		end)
	end
	memory[tostring(ds) .. key] = nil
end

local function setIndex(id, count)
	if indexStore then
		task.spawn(function()
			pcall(function()
				if count > 0 then
					indexStore:SetAsync(id, count)
				else
					indexStore:RemoveAsync(id)
				end
			end)
		end)
	end
	memory["index"] = memory["index"] or {}
	memory["index"][id] = count > 0 and count or nil
end

--------------------------------------------------------------------
-- guild data
--------------------------------------------------------------------
local function countMembers(g)
	local n = 0
	for _ in pairs(g.members or {}) do
		n += 1
	end
	return n
end

local function loadGuild(id, fresh)
	if type(id) ~= "string" then
		return nil
	end
	local c = cache[id]
	if c and not fresh and os.clock() - c.at < 30 then
		return c.data
	end
	local g = dsGet(store, "g_" .. id)
	cache[id] = { data = g, at = os.clock() }
	return g
end

-- what the client sees
local function publicView(g)
	if not g then
		return nil
	end
	local members = {}
	for uid, m in pairs(g.members or {}) do
		table.insert(members, { userId = tonumber(uid), name = m.name, role = m.role, joined = m.joined, online = Players:GetPlayerByUserId(tonumber(uid) or 0) ~= nil })
	end
	local order = { owner = 1, officer = 2, member = 3 }
	table.sort(members, function(a, b)
		if order[a.role] ~= order[b.role] then
			return (order[a.role] or 9) < (order[b.role] or 9)
		end
		return (a.joined or 0) < (b.joined or 0)
	end)
	return {
		id = g.id,
		name = g.name,
		desc = g.desc,
		icon = g.icon,
		imageId = g.imageId,
		open = g.open,
		owner = g.owner,
		maxMembers = g.maxMembers or G.baseMembers,
		count = #members,
		members = members,
		created = g.created,
	}
end

local function summary(g)
	return { id = g.id, name = g.name, desc = g.desc, icon = g.icon, imageId = g.imageId, open = g.open, count = countMembers(g), maxMembers = g.maxMembers or G.baseMembers }
end

-- tell every server (and players here) this guild changed
local function changed(id)
	cache[id] = nil
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { id = id })
	end)
	local g = loadGuild(id, true)
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = deps.DataService.Get(p)
		if prof and prof.guildId == id then
			guildEvent:FireClient(p, { kind = "changed" })
		end
	end
	return g
end

local function roleOf(g, userId)
	local m = g and g.members and g.members[tostring(userId)]
	return m and m.role or nil
end

--------------------------------------------------------------------
-- text rules
--------------------------------------------------------------------
local function clean(text, maxLen)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")
	return text:sub(1, maxLen)
end
-- Roblox text filter; returns nil if it had to hide words
local function filtered(text, userId)
	if text == "" then
		return ""
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, userId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil
	end
	if result ~= text and result:find("#", 1, true) then
		return nil
	end
	return result
end
local function imageFrom(value)
	if type(value) == "number" then
		value = tostring(math.floor(value))
	end
	if type(value) ~= "string" then
		return ""
	end
	local digits = value:match("(%d+)")
	return digits and ("rbxassetid://" .. digits) or ""
end
local function validIcon(key)
	for _, p in ipairs(G.presets) do
		if p.key == key then
			return key
		end
	end
	return G.presets[1].key
end

--------------------------------------------------------------------
-- invites
--------------------------------------------------------------------
local function getInvites(userId)
	local list = dsGet(inviteStore, "u_" .. userId)
	local out = {}
	if type(list) == "table" then
		for _, inv in ipairs(list) do
			if os.time() - (inv.t or 0) < 7 * 86400 then -- invites last a week
				table.insert(out, inv)
			end
		end
	end
	return out
end
local function removeInvite(userId, guildId)
	dsUpdate(inviteStore, "u_" .. userId, function(old)
		old = type(old) == "table" and old or {}
		local keep = {}
		for _, inv in ipairs(old) do
			if inv.guildId ~= guildId and os.time() - (inv.t or 0) < 7 * 86400 then
				table.insert(keep, inv)
			end
		end
		return keep
	end)
end

--------------------------------------------------------------------
-- membership changes (all go through UpdateAsync on the guild)
--------------------------------------------------------------------
local function addMember(id, player, role)
	local reason
	local ok, g = dsUpdate(store, "g_" .. id, function(old)
		if type(old) ~= "table" then
			reason = "That guild doesn't exist anymore."
			return nil
		end
		if old.members[tostring(player.UserId)] then
			return old
		end
		if countMembers(old) >= (old.maxMembers or G.baseMembers) then
			reason = "That guild is full."
			return nil
		end
		old.members[tostring(player.UserId)] = { name = player.Name, role = role or "member", joined = os.time() }
		return old
	end)
	if not ok or not g then
		return false, reason or "Try again in a moment."
	end
	setIndex(id, countMembers(g))
	return true
end

local function removeMember(id, userId)
	local deleted = false
	local ok, g = dsUpdate(store, "g_" .. id, function(old)
		if type(old) ~= "table" then
			return nil
		end
		local key = tostring(userId)
		local leaving = old.members[key]
		if not leaving then
			return old
		end
		old.members[key] = nil
		if countMembers(old) == 0 then
			deleted = true
			old.deleted = true
			return old
		end
		if leaving.role == "owner" then
			-- the owner left: an officer (or the oldest member) takes over
			local best, bestKey
			for k, m in pairs(old.members) do
				local rank = (m.role == "officer" and 0 or 1) * 1e12 + (m.joined or 0)
				if not best or rank < best then
					best, bestKey = rank, k
				end
			end
			old.members[bestKey].role = "owner"
			old.owner = tonumber(bestKey)
		end
		return old
	end)
	if ok and g then
		if deleted then
			dsRemove(store, "g_" .. id)
			dsRemove(store, "n_" .. string.lower(g.name))
			setIndex(id, 0)
		else
			setIndex(id, countMembers(g))
		end
	end
	return ok
end

local function setProfileGuild(userId, id)
	local p = Players:GetPlayerByUserId(userId)
	local prof = p and deps.DataService.Get(p)
	if prof then
		prof.guildId = id
		deps.sync(p)
		task.spawn(deps.DataService.Save, p)
		guildEvent:FireClient(p, { kind = "changed" })
		return
	end
	-- not in this server: tell the others (their server fixes it), and
	-- the guild record is the truth anyway (checked when they join)
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { userId = userId, guildId = id or false })
	end)
end

--------------------------------------------------------------------
-- actions
--------------------------------------------------------------------
local A = {}

function A.get(player, profile)
	local g = profile.guildId and loadGuild(profile.guildId)
	if profile.guildId and (not g or g.deleted or not g.members[tostring(player.UserId)]) then
		-- kicked / guild removed while away
		profile.guildId = nil
		g = nil
	end
	return {
		success = true,
		guild = publicView(g),
		myRole = g and roleOf(g, player.UserId) or nil,
		invites = getInvites(player.UserId),
		createFree = (G.createProductId or 0) == 0 or (profile.guildCredits or 0) > 0,
		createProductId = G.createProductId,
		slotsForSale = (G.slotProductId or 0) ~= 0,
	}
end

local browseCache = { at = -math.huge, list = {} }
function A.browse(player, profile, arg)
	if type(arg) == "string" and arg ~= "" then
		-- search by exact name
		local id = dsGet(store, "n_" .. string.lower(clean(arg, G.nameMax)))
		local g = id and loadGuild(id)
		return { success = true, list = g and { summary(g) } or {} }
	end
	if os.clock() - browseCache.at < 30 then
		return { success = true, list = browseCache.list }
	end
	local ids = {}
	if indexStore then
		local ok, pages = pcall(function()
			return indexStore:GetSortedAsync(false, 30)
		end)
		if ok and pages then
			for _, item in ipairs(pages:GetCurrentPage()) do
				table.insert(ids, item.key)
			end
		end
	end
	for id in pairs(memory["index"] or {}) do
		if not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	local list = {}
	local pending = #ids
	for i, id in ipairs(ids) do
		task.spawn(function()
			local g = loadGuild(id)
			if g and not g.deleted then
				list[i] = summary(g)
			end
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 6 do
		task.wait(0.1)
	end
	local out = {}
	for i = 1, #ids do
		if list[i] then
			table.insert(out, list[i])
		end
	end
	browseCache = { at = os.clock(), list = out }
	return { success = true, list = out }
end

-- checks the create form; returns the cleaned form or an error result
local function checkForm(player, profile, arg)
	if profile.guildId and loadGuild(profile.guildId) then
		return nil, { success = false, message = "Leave your guild first." }
	end
	arg = type(arg) == "table" and arg or {}
	local name = clean(arg.name, G.nameMax)
	if #name < G.nameMin then
		return nil, { success = false, message = "The name needs at least " .. G.nameMin .. " letters." }
	end
	local desc = clean(arg.desc, G.descMax)
	local fName = filtered(name, player.UserId)
	if not fName then
		return nil, { success = false, message = "That name isn't allowed. Try another one." }
	end
	local fDesc = filtered(desc, player.UserId)
	if not fDesc then
		return nil, { success = false, message = "That description isn't allowed." }
	end
	return { name = fName, desc = fDesc, icon = validIcon(arg.icon), imageId = imageFrom(arg.imageId), open = arg.open ~= false }
end

local function makeGuild(player, profile, form)
	local fName = form.name
	local id = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 16)
	-- reserve the name (unique across every server)
	local taken = false
	dsUpdate(store, "n_" .. string.lower(fName), function(old)
		if old then
			taken = true
			return nil
		end
		return id
	end)
	if taken then
		return { success = false, message = "That name is already taken." }
	end
	local g = {
		id = id,
		name = fName,
		desc = form.desc,
		icon = form.icon,
		imageId = form.imageId,
		open = form.open,
		owner = player.UserId,
		maxMembers = G.baseMembers,
		created = os.time(),
		members = { [tostring(player.UserId)] = { name = player.Name, role = "owner", joined = os.time() } },
	}
	local ok = dsUpdate(store, "g_" .. id, function()
		return g
	end)
	if not ok then
		dsRemove(store, "n_" .. string.lower(fName))
		return { success = false, message = "Could not create the guild, try again." }
	end
	setIndex(id, 1)
	profile.guildId = id
	cache[id] = { data = g, at = os.clock() }
	browseCache.at = -math.huge
	deps.sync(player)
	task.spawn(deps.DataService.Save, player)
	return { success = true, message = "Guild \"" .. fName .. "\" created!" }
end

-- the form a player filled in before paying for the create product
local pendingCreate = {}
Players.PlayerRemoving:Connect(function(p)
	pendingCreate[p] = nil
end)

function A.create(player, profile, arg)
	local form, err = checkForm(player, profile, arg)
	if not form then
		return err
	end
	local paid = (G.createProductId or 0) ~= 0
	local credits = profile.guildCredits or 0
	if paid and credits <= 0 then
		-- check the name is free before the player pays
		if dsGet(store, "n_" .. string.lower(form.name)) then
			return { success = false, message = "That name is already taken." }
		end
		pendingCreate[player] = form
		return { success = false, message = "Buy the guild to finish making it!", productId = G.createProductId }
	end
	local r = makeGuild(player, profile, form)
	if r.success and paid then
		profile.guildCredits = math.max(0, credits - 1)
	end
	return r
end

-- called by ProcessReceipt when the create product is bought. The player
-- always gets a guild ticket; it's used right away on the form they filled
-- in. If that fails (name taken meanwhile...), the ticket stays and the
-- next CREATE GUILD is free.
function GuildService.CreatePaid(player, profile)
	profile.guildCredits = (profile.guildCredits or 0) + 1
	local form = pendingCreate[player]
	pendingCreate[player] = nil
	if form and not (profile.guildId and loadGuild(profile.guildId)) then
		local ok, r = pcall(makeGuild, player, profile, form)
		if ok and r and r.success then
			profile.guildCredits -= 1
			guildEvent:FireClient(player, { kind = "changed" })
			return r.message
		end
	end
	return "Guild ticket bought! Press CREATE GUILD again (it's free now)."
end

local function joinGuild(player, profile, id, viaInvite)
	if profile.guildId and loadGuild(profile.guildId) then
		return { success = false, message = "Leave your guild first." }
	end
	local g = loadGuild(id, true)
	if not g or g.deleted then
		return { success = false, message = "That guild doesn't exist anymore." }
	end
	if not g.open and not viaInvite then
		return { success = false, message = "That guild is invite only." }
	end
	local ok, reason = addMember(id, player)
	if not ok then
		return { success = false, message = reason }
	end
	removeInvite(player.UserId, id)
	profile.guildId = id
	deps.sync(player)
	task.spawn(deps.DataService.Save, player)
	changed(id)
	return { success = true, message = "You joined " .. g.name .. "!" }
end

function A.join(player, profile, id)
	return joinGuild(player, profile, id, false)
end

function A.accept(player, profile, id)
	local invited = false
	for _, inv in ipairs(getInvites(player.UserId)) do
		if inv.guildId == id then
			invited = true
		end
	end
	if not invited then
		return { success = false, message = "That invite is gone." }
	end
	return joinGuild(player, profile, id, true)
end

function A.decline(player, profile, id)
	removeInvite(player.UserId, id)
	return { success = true, message = "Invite declined." }
end

function A.leave(player, profile)
	local id = profile.guildId
	if not id then
		return { success = false, message = "You're not in a guild." }
	end
	removeMember(id, player.UserId)
	profile.guildId = nil
	deps.sync(player)
	task.spawn(deps.DataService.Save, player)
	browseCache.at = -math.huge
	changed(id)
	return { success = true, message = "You left the guild." }
end

local function myGuild(player, profile)
	local g = profile.guildId and loadGuild(profile.guildId, true)
	if not g or g.deleted then
		return nil
	end
	return g, roleOf(g, player.UserId)
end

function A.invite(player, profile, username)
	local g, role = myGuild(player, profile)
	if not g then
		return { success = false, message = "You're not in a guild." }
	end
	if role ~= "owner" and role ~= "officer" then
		return { success = false, message = "Only the owner and officers can invite." }
	end
	if countMembers(g) >= (g.maxMembers or G.baseMembers) then
		return { success = false, message = "Your guild is full." }
	end
	username = clean(username, 40):gsub("^@", "")
	if username == "" then
		return { success = false, message = "Type a username." }
	end
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(username)
	end)
	if not ok or not userId then
		return { success = false, message = "No player named \"" .. username .. "\"." }
	end
	if g.members[tostring(userId)] then
		return { success = false, message = username .. " is already in your guild." }
	end
	dsUpdate(inviteStore, "u_" .. userId, function(old)
		old = type(old) == "table" and old or {}
		local keep = {}
		for _, inv in ipairs(old) do
			if inv.guildId ~= g.id and os.time() - (inv.t or 0) < 7 * 86400 then
				table.insert(keep, inv)
			end
		end
		table.insert(keep, { guildId = g.id, guildName = g.name, icon = g.icon, imageId = g.imageId, from = player.Name, t = os.time() })
		while #keep > 10 do
			table.remove(keep, 1)
		end
		return keep
	end)
	-- ping the player if they're online somewhere
	local here = Players:GetPlayerByUserId(userId)
	if here then
		guildEvent:FireClient(here, { kind = "invite", guildName = g.name, from = player.Name })
	else
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { invite = userId, guildName = g.name, from = player.Name })
		end)
	end
	return { success = true, message = "Invite sent to " .. username .. "!" }
end

function A.kick(player, profile, userId)
	local g, role = myGuild(player, profile)
	userId = tonumber(userId)
	if not g or role ~= "owner" or not userId or userId == player.UserId then
		return { success = false, message = "You can't do that." }
	end
	if not g.members[tostring(userId)] then
		return { success = false, message = "They're not in your guild." }
	end
	removeMember(g.id, userId)
	setProfileGuild(userId, nil)
	changed(g.id)
	return { success = true, message = "Removed from the guild." }
end

local function setRole(player, profile, userId, newRole)
	local g, role = myGuild(player, profile)
	userId = tonumber(userId)
	if not g or role ~= "owner" or not userId or userId == player.UserId then
		return { success = false, message = "You can't do that." }
	end
	local ok = dsUpdate(store, "g_" .. g.id, function(old)
		if type(old) ~= "table" or not old.members[tostring(userId)] then
			return nil
		end
		old.members[tostring(userId)].role = newRole
		return old
	end)
	changed(g.id)
	return { success = ok, message = newRole == "officer" and "They're an officer now." or "They're a member now." }
end
function A.promote(player, profile, userId)
	return setRole(player, profile, userId, "officer")
end
function A.demote(player, profile, userId)
	return setRole(player, profile, userId, "member")
end

function A.edit(player, profile, arg)
	local g, role = myGuild(player, profile)
	if not g or role ~= "owner" then
		return { success = false, message = "Only the owner can change the guild." }
	end
	arg = type(arg) == "table" and arg or {}
	local newName
	if arg.name ~= nil then
		local name = clean(arg.name, G.nameMax)
		if #name < G.nameMin then
			return { success = false, message = "The name needs at least " .. G.nameMin .. " letters." }
		end
		if string.lower(name) ~= string.lower(g.name) then
			local f = filtered(name, player.UserId)
			if not f then
				return { success = false, message = "That name isn't allowed. Try another one." }
			end
			local taken = false
			dsUpdate(store, "n_" .. string.lower(f), function(old)
				if old and old ~= g.id then
					taken = true
					return nil
				end
				return g.id
			end)
			if taken then
				return { success = false, message = "That name is already taken." }
			end
			newName = f
		elseif name ~= g.name then
			newName = name -- only the capital letters changed
		end
	end
	local newDesc
	if arg.desc ~= nil then
		newDesc = filtered(clean(arg.desc, G.descMax), player.UserId)
		if not newDesc then
			return { success = false, message = "That description isn't allowed." }
		end
	end
	local oldName = g.name
	dsUpdate(store, "g_" .. g.id, function(old)
		if type(old) ~= "table" then
			return nil
		end
		if newName then
			old.name = newName
		end
		if newDesc then
			old.desc = newDesc
		end
		if arg.icon ~= nil then
			old.icon = validIcon(arg.icon)
		end
		if arg.imageId ~= nil then
			old.imageId = imageFrom(arg.imageId)
		end
		if arg.open ~= nil then
			old.open = arg.open == true
		end
		return old
	end)
	if newName and string.lower(newName) ~= string.lower(oldName) then
		dsRemove(store, "n_" .. string.lower(oldName))
	end
	browseCache.at = -math.huge
	changed(g.id)
	return { success = true, message = "Guild saved!" }
end

function A.slots(player, profile)
	local g, role = myGuild(player, profile)
	if not g or role ~= "owner" then
		return { success = false, message = "Only the owner can buy member slots." }
	end
	if (g.maxMembers or G.baseMembers) >= G.maxMembers then
		return { success = false, message = "Your guild has the most slots already." }
	end
	if (G.slotProductId or 0) == 0 then
		return { success = false, message = "More member slots are coming soon!" }
	end
	return { success = true, productId = G.slotProductId }
end

-- called by ProcessReceipt when the slot product is bought
function GuildService.AddSlots(player)
	local profile = deps.DataService.Get(player)
	local g = profile and profile.guildId and loadGuild(profile.guildId, true)
	if not g then
		return nil
	end
	local ok = dsUpdate(store, "g_" .. g.id, function(old)
		if type(old) ~= "table" then
			return nil
		end
		old.maxMembers = math.min(G.maxMembers, (old.maxMembers or G.baseMembers) + G.slotStep)
		return old
	end)
	if not ok then
		return nil
	end
	changed(g.id)
	return "+" .. G.slotStep .. " guild member slots!"
end

--------------------------------------------------------------------
function GuildService.Start(d)
	deps = d
	guildRemote = d.getRemote("GuildAction", "RemoteFunction")
	guildEvent = d.getRemote("GuildEvent", "RemoteEvent")
	guildRemote.OnServerInvoke = function(player, action, arg)
		local profile = deps.DataService.Get(player)
		local fn = A[action]
		if not profile or not fn then
			return { success = false, message = "Loading..." }
		end
		if busy[player] then
			return { success = false, message = "One moment..." }
		end
		busy[player] = true
		local ok, r = pcall(fn, player, profile, arg)
		busy[player] = nil
		if not ok then
			warn("[Guild] " .. tostring(r))
			return { success = false, message = "Something went wrong, try again." }
		end
		return r
	end
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(msg)
				local m = msg.Data
				if type(m) ~= "table" then
					return
				end
				if m.id then
					cache[m.id] = nil
					for _, p in ipairs(Players:GetPlayers()) do
						local prof = deps.DataService.Get(p)
						if prof and prof.guildId == m.id then
							guildEvent:FireClient(p, { kind = "changed" })
						end
					end
				end
				if m.userId then
					local p = Players:GetPlayerByUserId(m.userId)
					local prof = p and deps.DataService.Get(p)
					if prof then
						prof.guildId = m.guildId or nil
						deps.sync(p)
						guildEvent:FireClient(p, { kind = "changed" })
					end
				end
				if m.invite then
					local p = Players:GetPlayerByUserId(m.invite)
					if p then
						guildEvent:FireClient(p, { kind = "invite", guildName = m.guildName, from = m.from })
					end
				end
			end)
		end)
	end)
	-- players who were kicked while away lose the guild when they join
	Players.PlayerAdded:Connect(function(player)
		for _ = 1, 40 do
			if deps.DataService.Get(player) or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		local profile = deps.DataService.Get(player)
		if profile and profile.guildId then
			local g = loadGuild(profile.guildId, true)
			if not g or g.deleted or not g.members[tostring(player.UserId)] then
				profile.guildId = nil
				deps.sync(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return GuildService
