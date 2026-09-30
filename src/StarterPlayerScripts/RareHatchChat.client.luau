local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

--------------------------------------------------------------------
-- Rare hatch messages in the chat (sent to every server):
--   [Player] hatched a GIGANTIC GALAXY Void Dragon! (1 in 2.1M)
-- The monster's name is in its rarity color, the size / finish words
-- in their own colors (Rainbow is rainbow, letter by letter).
--------------------------------------------------------------------
local folder = ReplicatedStorage:WaitForChild("MonsterRNG")
local Config = require(folder:WaitForChild("Config"))
local remote = folder:WaitForChild("Remotes"):WaitForChild("RareHatch")

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function colored(text, c)
	return string.format('<font color="%s">%s</font>', hex(c), text)
end
local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function rainbowText(text)
	local out, i = {}, 0
	for ch in text:gmatch(".") do
		if ch == " " then
			table.insert(out, ch)
		else
			table.insert(out, colored(ch, Color3.fromHSV((i * 0.09) % 1, 0.75, 1)))
			i += 1
		end
	end
	return table.concat(out)
end

local SIZE_COLORS = {
	Big = Color3.fromRGB(150, 220, 255),
	Huge = Color3.fromRGB(190, 150, 255),
	Titan = Color3.fromRGB(255, 170, 60),
	Gigantic = Color3.fromRGB(255, 80, 80),
}
local FINISH_COLORS = {
	Gold = Color3.fromRGB(255, 205, 60),
	Silver = Color3.fromRGB(215, 225, 240),
	Diamond = Color3.fromRGB(170, 235, 255),
	Galaxy = Color3.fromRGB(170, 110, 255),
}

local function systemMessage(text)
	-- new chat
	local ok = pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if not general then
			error("no channel")
		end
		general:DisplaySystemMessage(text)
	end)
	if not ok then
		-- old chat
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", { Text = text:gsub("<[^>]+>", ""), Color = Color3.fromRGB(255, 220, 120), Font = Enum.Font.GothamBold })
		end)
	end
end

remote.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then
		return
	end
	local monster = Config.GetMonster(d.monsterId)
	if not monster then
		return
	end
	local rarity = Config.GetRarity(monster.rarity)
	local rarityColor = Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
	local words = {}
	if d.size and d.size ~= "Normal" then
		table.insert(words, colored("<b>" .. escape(d.size:upper()) .. "</b>", SIZE_COLORS[d.size] or rarityColor))
	end
	if d.finish and d.finish ~= "Normal" then
		if d.finish == "Rainbow" then
			table.insert(words, "<b>" .. rainbowText("RAINBOW") .. "</b>")
		else
			table.insert(words, colored("<b>" .. escape(d.finish:upper()) .. "</b>", FINISH_COLORS[d.finish] or rarityColor))
		end
	end
	table.insert(words, colored("<b>" .. escape(monster.name) .. "</b>", rarityColor))
	local text = string.format(
		"%s hatched a %s! %s %s",
		colored("<b>[" .. escape(d.name or "Someone") .. "]</b>", Color3.new(1, 1, 1)),
		table.concat(words, " "),
		colored("(" .. escape(rarity.name) .. ")", rarityColor),
		colored("(" .. Config.FormatOdds(tonumber(d.odds) or 0) .. ")", Color3.fromRGB(255, 225, 120))
	)
	systemMessage(text)
end)
