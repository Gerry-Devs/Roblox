local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))

-- [VIP] (gold) / [SUPPORTER] (violet) in front of chat messages.
-- The server sets each player's "Tag" attribute from their gamepasses.
TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local player = source and Players:GetPlayerByUserId(source.UserId)
	local key = player and player:GetAttribute("Tag")
	local info = key and Config.PassTags[key]
	if info then
		local hex = string.format("#%02x%02x%02x", info.color[1], info.color[2], info.color[3])
		props.PrefixText = string.format('<font color="%s">[%s]</font> ', hex, info.text) .. message.PrefixText
	end
	return props
end
