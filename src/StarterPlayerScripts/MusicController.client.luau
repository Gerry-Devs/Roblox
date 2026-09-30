local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--------------------------------------------------------------------
-- Music: each biome has its own track (fades in when you walk in, fades
-- out when you leave). Monster Town plays one of its sounds every now
-- and then. The MUSIC switch in Settings turns it all off.
-- Sound ids: Config.Sounds
--------------------------------------------------------------------

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("MonsterRNG"):WaitForChild("Config"))
local S = Config.Sounds

local tracks = {}
local function getTrack(key)
	if tracks[key] then
		return tracks[key]
	end
	local id = S.music[key]
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	tracks[key] = s
	return s
end

local playing
local function fadeTo(key)
	if playing == key then
		return
	end
	-- fade out whatever is playing
	if playing and tracks[playing] then
		local old = tracks[playing]
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function()
			if playing ~= old.Name:sub(7) then
				old:Pause()
			end
		end)
	end
	playing = key
	local track = key and getTrack(key)
	if track then
		if not track.IsPlaying then
			track:Resume()
			if not track.IsPlaying then
				track:Play()
			end
		end
		TweenService:Create(track, TweenInfo.new(1.5), { Volume = S.musicVolume }):Play()
	end
end

local townSound = Instance.new("Sound")
townSound.Name = "TownAmbience"
townSound.Volume = S.townVolume
townSound.Parent = SoundService
local nextTown = os.clock() + 4

while true do
	local on = player:GetAttribute("MusicOn") ~= false
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local biome = root and Config.GetBiomeAt(root.Position.X, root.Position.Z)
	local key = biome and biome.key or "home"
	if not on then
		fadeTo(nil)
		townSound:Stop()
	elseif key ~= "home" and S.music[key] then
		fadeTo(key) -- biome music
		townSound:Stop()
	else
		fadeTo(nil) -- Monster Town: no music, random town sounds
		if os.clock() >= nextTown and not townSound.IsPlaying then
			townSound.SoundId = S.town[math.random(1, #S.town)]
			townSound:Play()
			nextTown = os.clock() + 25 + math.random() * 25
		end
	end
	task.wait(0.5)
end
