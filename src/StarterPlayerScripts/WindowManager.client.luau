local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------
-- One window at a time: when any window opens, every other window
-- closes (shop, daily, settings, backpack, upgrades, stalls, pen
-- panels, admin, guild, pvp...). Windows are listed below by
-- ScreenGui name + frame name ("*" = every child of that folder).
--------------------------------------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local closeAllBridge = ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("ClientBridge"):WaitForChild("CloseAll")

local WINDOWS = {
	{ gui = "HUD", path = { "Panels", "*" }, key = "hud" },
	{ gui = "Backpack", path = { "Main" }, key = "backpack" },
	{ gui = "UpgradeTree", path = { "Dim" }, key = "upgrades" },
	{ gui = "SellShop", path = { "Main" }, key = "sell" },
	{ gui = "DiceShop", path = { "Main" }, key = "dice" },
	{ gui = "PenPanel", path = { "EggPanel" }, key = "pen" },
	{ gui = "PenPanel", path = { "MonsterPanel" }, key = "pen" },
	{ gui = "PenPanel", path = { "WarpPanel" }, key = "pen" },
	{ gui = "Gift", path = { "Main" }, key = "gift" },
	{ gui = "GearShop", path = { "Main" }, key = "gear" },
	{ gui = "AutoSell", path = { "Main" }, key = "autosell" },
	{ gui = "AdminPanel", path = { "Main" }, key = "admin" },
	{ gui = "GuildUI", path = { "Main" }, key = "guild" },
}

local tracked = {} -- frame -> key
local busy = false

local function onOpened(frame)
	if busy then
		return
	end
	local key = tracked[frame]
	local others = {}
	for f, k in pairs(tracked) do
		if f ~= frame and k ~= key and f.Parent and f.Visible then
			table.insert(others, f)
		end
	end
	if #others == 0 then
		return
	end
	busy = true
	closeAllBridge:Fire(key) -- windows with their own close logic close themselves
	task.defer(function()
		for _, f in ipairs(others) do
			if f.Parent and f.Visible then
				f.Visible = false -- anything that didn't listen
			end
		end
		busy = false
	end)
end

local function track(frame, key)
	if tracked[frame] or not frame:IsA("GuiObject") then
		return
	end
	tracked[frame] = key
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			onOpened(frame)
		end
	end)
	frame.Destroying:Connect(function()
		tracked[frame] = nil
	end)
end

local function watch(def)
	task.spawn(function()
		local node = playerGui:WaitForChild(def.gui, 60)
		if not node then
			return
		end
		for i, name in ipairs(def.path) do
			if name == "*" then
				for _, c in ipairs(node:GetChildren()) do
					track(c, def.key)
				end
				node.ChildAdded:Connect(function(c)
					track(c, def.key)
				end)
				return
			end
			node = node:WaitForChild(name, 60)
			if not node then
				return
			end
		end
		track(node, def.key)
	end)
end

for _, def in ipairs(WINDOWS) do
	watch(def)
end

-- a ScreenGui can be re-made (ResetOnSpawn): watch again when it comes back
playerGui.ChildAdded:Connect(function(g)
	for _, def in ipairs(WINDOWS) do
		if def.gui == g.Name then
			watch(def)
		end
	end
end)
