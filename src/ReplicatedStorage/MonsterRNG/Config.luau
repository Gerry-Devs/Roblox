local Config = {}

Config.GameName = "Monster RNG"
Config.BaseSlots = 6
Config.BackpackCap = 100
Config.PenEggCap = 5
Config.PenMonsterCap = 3
Config.PenPlacementMargin = 5 -- studs of buffer kept clear inside the fence line
Config.StartingCash = 250
Config.BossPower = 325
Config.BossReward = 750

-- Gamepass ID gating the "Sell All Eggs" backpack button. Leave at 0 to
-- keep the feature free for everyone (no Marketplace calls happen at
-- all); set it to a real gamepass ID from the Creator Dashboard once
-- you want to monetize it and both client and server will start
-- checking/prompting for ownership automatically.
Config.SellAllGamepassId = 0

-- How long one roll takes (animation + cooldown), in seconds. The Roll
-- Speed upgrade shortens it by its total % (see UpgradeStatInfo.rollSpeed).
-- Applies to hidden rolls and auto roll too, and the server enforces it.
Config.BaseRollDuration = 4.5

-- Hidden pity: every PityEvery-th roll gets PityLuckMultiplier x luck
-- (nothing is shown to the player).
Config.PityEvery = 25
Config.PityLuckMultiplier = 2
Config.MinRollDuration = 1.2

function Config.GetRollDuration(upgrades)
	local bonus = Config.GetUpgradeBonus and Config.GetUpgradeBonus(upgrades, "rollSpeed") or 0
	return math.max(Config.MinRollDuration, Config.BaseRollDuration * (1 - bonus / 100))
end
Config.PityThresholds = {
	rare = 40,
	epic = 80,
	legendary = 150,
}

Config.SizeVariants = {
	{
		key = "Normal",
		name = "Normal",
		weight = 85,
		incomeMultiplier = 1,
		powerMultiplier = 1,
		scale = 1,
	},
	{
		key = "Big",
		name = "Big",
		weight = 8,
		incomeMultiplier = 2.5,
		powerMultiplier = 1.8,
		scale = 1.2,
	},
	{
		key = "Huge",
		name = "Huge",
		weight = 5.8,
		incomeMultiplier = 5,
		powerMultiplier = 3,
		scale = 1.45,
	},
	{
		key = "Titan",
		name = "Titan",
		weight = 1,
		incomeMultiplier = 20,
		powerMultiplier = 8,
		scale = 2.1,
	},
	{
		key = "Gigantic",
		name = "Gigantic",
		weight = 0.2, -- ~1 in 500
		incomeMultiplier = 50,
		powerMultiplier = 15,
		scale = 2.6,
	},
}

Config.FinishVariants = {
	{
		key = "Normal",
		name = "Normal",
		weight = 90,
		incomeMultiplier = 1,
		powerMultiplier = 1,
	},
	{
		key = "Gold",
		name = "Gold",
		weight = 7,
		incomeMultiplier = 2.5,
		powerMultiplier = 1.5,
	},
	{
		key = "Silver",
		name = "Silver",
		weight = 2,
		incomeMultiplier = 4,
		powerMultiplier = 2,
	},
	{
		key = "Diamond",
		name = "Diamond",
		weight = 1.5, -- icy sparkly shine
		incomeMultiplier = 6,
		powerMultiplier = 3,
	},
	{
		key = "Rainbow",
		name = "Rainbow",
		weight = 1, -- keeps changing color
		incomeMultiplier = 10,
		powerMultiplier = 4,
	},
	{
		key = "Galaxy",
		name = "Galaxy",
		weight = 0.2, -- ~1 in 500; deep space colors that drift + stars
		incomeMultiplier = 25,
		powerMultiplier = 8,
	},
}

Config.ShopItems = {
	luckPotion = {
		name = "Luck Potion",
		cost = 250,
		description = "+1 permanent luck",
	},
	incomeBoost = {
		name = "Base Booster",
		cost = 1000,
		description = "+25% base income",
	},
}

Config.Rarities = {
	{
		name = "Common",
		key = "Common",
		weight = 60,
		tier = 1,
		color = { 155, 166, 180 },
	},
	{
		name = "Uncommon",
		key = "Uncommon",
		weight = 25,
		tier = 2,
		color = { 91, 205, 143 },
	},
	{
		name = "Rare",
		key = "Rare",
		weight = 10,
		tier = 3,
		color = { 75, 160, 255 },
	},
	{
		name = "Epic",
		key = "Epic",
		weight = 4,
		tier = 4,
		color = { 176, 102, 255 },
	},
	{
		name = "Legendary",
		key = "Legendary",
		weight = 0.9,
		tier = 5,
		color = { 255, 180, 67 },
	},
	{
		name = "Mythic",
		key = "Mythic",
		weight = 0.1,
		tier = 6,
		color = { 255, 82, 139 },
	},
	-- the 4 "wheel" rarities: tiny chance in normal rolls, much better
	-- from the WILD wheel (see Config.Wild)
	{
		name = "Secret",
		key = "Secret",
		weight = 0.01, -- ~1 in 10,000
		tier = 7,
		color = { 160, 150, 190 },
	},
	{
		name = "Celestial",
		key = "Celestial",
		weight = 0.002, -- ~1 in 50,000
		tier = 8,
		color = { 120, 215, 255 },
	},
	{
		name = "Divine",
		key = "Divine",
		weight = 0.0004, -- ~1 in 250,000
		tier = 9,
		color = { 255, 228, 130 },
	},
	{
		name = "Supreme",
		key = "Supreme",
		weight = 0.0001, -- ~1 in 1,000,000
		tier = 10,
		color = { 255, 70, 70 },
	},
}

Config.Monsters = {
	{
		id = "slime",
		name = "Moss Slime",
		rarity = "Common",
		power = 5,
		description = "A tiny explorer with a big appetite.",
	},
	{
		id = "bat",
		name = "Cave Bat",
		rarity = "Common",
		power = 8,
		description = "It knows every dark corner of the island.",
	},
	{
		id = "mushroom",
		name = "Glowcap",
		rarity = "Uncommon",
		power = 18,
		description = "Its spores light up the night.",
	},
	{
		id = "crab",
		name = "Ironclaw Crab",
		rarity = "Uncommon",
		power = 23,
		description = "Hard shell, harder attitude.",
	},
	{
		id = "wolf",
		name = "Frostfang Wolf",
		rarity = "Rare",
		power = 42,
		description = "A fast hunter from the frozen peaks.",
	},
	{
		id = "golem",
		name = "Runestone Golem",
		rarity = "Rare",
		power = 51,
		description = "Ancient runes pulse beneath its stone skin.",
	},
	{
		id = "phoenix",
		name = "Ember Phoenix",
		rarity = "Epic",
		power = 88,
		description = "A blazing bird that refuses to stay defeated.",
	},
	{
		id = "leviathan",
		name = "Storm Leviathan",
		rarity = "Legendary",
		power = 150,
		description = "The sea itself moves when it wakes.",
	},
	{
		id = "void-dragon",
		name = "Void Dragon",
		rarity = "Mythic",
		power = 300,
		description = "A monster from the space between worlds.",
	},
	{
		id = "wraith",
		name = "Shadow Wraith",
		rarity = "Secret",
		power = 700,
		description = "Nobody has seen its face and lived to tell.",
	},
	{
		id = "seraph",
		name = "Star Seraph",
		rarity = "Celestial",
		power = 1600,
		description = "Born from a falling star, it burns with holy light.",
	},
	{
		id = "titan",
		name = "Sun Titan",
		rarity = "Divine",
		power = 3800,
		description = "A giant of living gold with the sun in its chest.",
	},
	{
		id = "emperor",
		name = "Cosmic Emperor",
		rarity = "Supreme",
		power = 9000,
		description = "It wears the galaxy as a crown.",
	},
}

--------------------------------------------------------------------
-- More monsters, built from simple parts (MonsterModel "shapes"):
--   look.shape  blob / biped / beast / flyer / serpent / floater / bug
--   look.main / dark / accent = colors, look.eye = eye style,
--   look.extras = horns, ears, crown, halo, wings, tail, spikes, mane,
--                 orbs, cape, fins, antenna, shell, flame, crystal, gem,
--                 tusks, leaf, antlers, wings4
--   attack  = normal move:   bite, slam, spin, charge, slash, beam, tailwhip
--   crit    = critical move: pounce, tornado, frenzy, nova, quake, barrage, skybeam
--   element = attack effect colors: fire, ice, nature, water, shadow,
--             light, storm, poison, cosmic, earth, candy
--   weight  = how often it rolls inside its rarity (1 = normal,
--             2 = twice as common, 0.5 = twice as rare)
--------------------------------------------------------------------
for _, m in ipairs({
	-- Common (with Moss Slime + Cave Bat = 5)
	{ id = "pebble-pup", name = "Pebble Pup", rarity = "Common", power = 6, weight = 1.4, description = "It fetches shiny rocks and never gives them back.", element = "earth", attack = "bite", crit = "pounce",
		look = { shape = "beast", main = { 150, 142, 132 }, dark = { 104, 98, 92 }, accent = { 255, 200, 90 }, eye = "round", extras = { "ears", "tail" } } },
	{ id = "sparkfly", name = "Sparkfly", rarity = "Common", power = 7, weight = 1, description = "A tiny glowing bug that buzzes with static.", element = "storm", attack = "charge", crit = "tornado",
		look = { shape = "flyer", main = { 255, 222, 90 }, dark = { 210, 160, 40 }, accent = { 120, 230, 255 }, eye = "googly", extras = { "antenna" } } },
	{ id = "leaf-bug", name = "Leaf Bug", rarity = "Common", power = 9, weight = 0.6, description = "It hides in plain sight on any bush.", element = "nature", attack = "bite", crit = "frenzy",
		look = { shape = "bug", main = { 120, 200, 90 }, dark = { 70, 140, 60 }, accent = { 255, 230, 110 }, eye = "fish", extras = { "antenna", "leaf" } } },
	-- Uncommon (+ Glowcap, Ironclaw Crab = 5)
	{ id = "thorn-hog", name = "Thorn Hog", rarity = "Uncommon", power = 19, weight = 1.3, description = "Its back is a hedge of sharp thorns.", element = "nature", attack = "charge", crit = "pounce",
		look = { shape = "beast", main = { 150, 110, 80 }, dark = { 100, 70, 50 }, accent = { 120, 200, 80 }, eye = "brave", extras = { "spikes", "tusks", "ears" } } },
	{ id = "cinder-imp", name = "Cinder Imp", rarity = "Uncommon", power = 22, weight = 1, description = "A mischief-maker with a fire in its belly.", element = "fire", attack = "slash", crit = "barrage",
		look = { shape = "biped", main = { 230, 80, 60 }, dark = { 150, 40, 40 }, accent = { 255, 190, 60 }, eye = "slit", extras = { "horns", "tail", "flame" } } },
	{ id = "candy-puff", name = "Candy Puff", rarity = "Uncommon", power = 26, weight = 0.55, description = "Sweet, fluffy and surprisingly bouncy.", element = "candy", attack = "slam", crit = "quake",
		look = { shape = "blob", main = { 255, 170, 215 }, dark = { 220, 110, 170 }, accent = { 150, 230, 255 }, eye = "lash", extras = { "ears", "gem" } } },
	-- Rare (+ Frostfang Wolf, Runestone Golem = 5)
	{ id = "flame-fox", name = "Flame Fox", rarity = "Rare", power = 45, weight = 1.2, description = "Its tail burns brighter the happier it is.", element = "fire", attack = "bite", crit = "pounce",
		look = { shape = "beast", main = { 255, 130, 50 }, dark = { 200, 80, 30 }, accent = { 255, 230, 120 }, eye = "almond", extras = { "ears", "tail", "flame" } } },
	{ id = "frost-yeti", name = "Frost Yeti", rarity = "Rare", power = 52, weight = 0.8, description = "A shy giant from the snowy peaks.", element = "ice", attack = "slam", crit = "quake",
		look = { shape = "biped", main = { 235, 245, 255 }, dark = { 170, 200, 230 }, accent = { 120, 200, 255 }, eye = "round", extras = { "horns", "mane" } } },
	{ id = "jade-serpent", name = "Jade Serpent", rarity = "Rare", power = 58, weight = 0.5, description = "A graceful snake carved from living jade.", element = "nature", attack = "beam", crit = "tornado",
		look = { shape = "serpent", main = { 80, 200, 140 }, dark = { 40, 130, 90 }, accent = { 255, 215, 90 }, eye = "slit", extras = { "horns", "gem" } } },
	-- Epic (+ Ember Phoenix = 5)
	{ id = "thunder-lion", name = "Thunder Lion", rarity = "Epic", power = 85, weight = 1.2, description = "Its roar comes with a crack of thunder.", element = "storm", attack = "bite", crit = "pounce",
		look = { shape = "beast", main = { 255, 205, 70 }, dark = { 200, 140, 40 }, accent = { 120, 220, 255 }, eye = "brave", extras = { "mane", "tail", "ears" } } },
	{ id = "abyss-eel", name = "Abyss Eel", rarity = "Epic", power = 92, weight = 1, description = "It glows in the deepest, darkest water.", element = "water", attack = "beam", crit = "tornado",
		look = { shape = "serpent", main = { 40, 60, 120 }, dark = { 25, 35, 80 }, accent = { 90, 240, 255 }, eye = "glow", extras = { "fins", "crystal" } } },
	{ id = "inferno-bat", name = "Inferno Bat", rarity = "Epic", power = 98, weight = 0.8, description = "Every flap of its wings throws sparks.", element = "fire", attack = "charge", crit = "frenzy",
		look = { shape = "flyer", main = { 120, 40, 40 }, dark = { 70, 20, 25 }, accent = { 255, 140, 40 }, eye = "glow", extras = { "ears", "horns", "flame" } } },
	{ id = "ghost-lantern", name = "Ghost Lantern", rarity = "Epic", power = 105, weight = 0.5, description = "It lights the way for lost souls.", element = "shadow", attack = "beam", crit = "nova",
		look = { shape = "floater", main = { 120, 230, 220 }, dark = { 60, 140, 150 }, accent = { 200, 255, 250 }, eye = "dot", extras = { "orbs", "flame" } } },
	-- Legendary (+ Storm Leviathan = 5)
	{ id = "solar-griffin", name = "Solar Griffin", rarity = "Legendary", power = 145, weight = 1.2, description = "Half eagle, half lion, all sunshine.", element = "light", attack = "charge", crit = "skybeam",
		look = { shape = "flyer", main = { 255, 215, 100 }, dark = { 200, 150, 60 }, accent = { 255, 255, 220 }, eye = "brave", extras = { "crown", "tail" } } },
	{ id = "obsidian-behemoth", name = "Obsidian Behemoth", rarity = "Legendary", power = 160, weight = 1, description = "A walking mountain of black glass.", element = "earth", attack = "charge", crit = "quake",
		look = { shape = "beast", main = { 50, 45, 60 }, dark = { 30, 25, 40 }, accent = { 255, 90, 60 }, eye = "glow", extras = { "horns", "spikes", "crystal" } } },
	{ id = "frost-wyrm", name = "Frost Wyrm", rarity = "Legendary", power = 172, weight = 0.7, description = "Its breath freezes the air solid.", element = "ice", attack = "beam", crit = "skybeam",
		look = { shape = "serpent", main = { 170, 225, 255 }, dark = { 110, 170, 220 }, accent = { 255, 255, 255 }, eye = "almond", extras = { "horns", "spikes", "fins" } } },
	{ id = "thunder-djinn", name = "Thunder Djinn", rarity = "Legendary", power = 185, weight = 0.45, description = "A storm spirit that grants no wishes.", element = "storm", attack = "slash", crit = "nova",
		look = { shape = "floater", main = { 80, 120, 230 }, dark = { 40, 70, 160 }, accent = { 255, 230, 80 }, eye = "glow", extras = { "orbs", "horns", "cape" } } },
	-- Mythic (+ Void Dragon = 4)
	{ id = "chaos-chimera", name = "Chaos Chimera", rarity = "Mythic", power = 290, weight = 1.2, description = "Three beasts in one, and none of them agree.", element = "fire", attack = "bite", crit = "frenzy",
		look = { shape = "beast", main = { 190, 60, 50 }, dark = { 110, 30, 30 }, accent = { 255, 170, 40 }, eye = "slit", extras = { "horns", "mane", "wings", "tail" } } },
	{ id = "iron-colossus", name = "Iron Colossus", rarity = "Mythic", power = 320, weight = 0.8, description = "Ancient machinery, still running.", element = "storm", attack = "slam", crit = "quake",
		look = { shape = "biped", main = { 150, 160, 175 }, dark = { 90, 95, 110 }, accent = { 90, 230, 255 }, eye = "glow", extras = { "crown", "gem", "spikes" } } },
	{ id = "plague-wyvern", name = "Plague Wyvern", rarity = "Mythic", power = 345, weight = 0.5, description = "Where it flies, the grass turns grey.", element = "poison", attack = "beam", crit = "skybeam",
		look = { shape = "flyer", main = { 110, 150, 60 }, dark = { 60, 90, 40 }, accent = { 190, 255, 80 }, eye = "slit", extras = { "horns", "spikes", "tail" } } },
	-- Secret (+ Shadow Wraith = 4)
	{ id = "hollow-king", name = "Hollow King", rarity = "Secret", power = 650, weight = 1.2, description = "A crown with nobody inside it.", element = "shadow", attack = "slash", crit = "nova",
		look = { shape = "floater", main = { 50, 40, 70 }, dark = { 25, 20, 40 }, accent = { 255, 210, 80 }, eye = "glow", extras = { "crown", "cape", "orbs" } } },
	{ id = "glitch-beast", name = "Glitch Beast", rarity = "Secret", power = 720, weight = 0.8, description = "It should not exist. It does anyway.", element = "cosmic", attack = "charge", crit = "frenzy",
		look = { shape = "beast", main = { 255, 60, 220 }, dark = { 60, 30, 90 }, accent = { 60, 255, 220 }, eye = "glow", extras = { "spikes", "crystal", "tail" } } },
	{ id = "bone-dragon", name = "Bone Dragon", rarity = "Secret", power = 790, weight = 0.5, description = "Its bones rattle like thunder.", element = "shadow", attack = "beam", crit = "skybeam",
		look = { shape = "flyer", main = { 235, 230, 215 }, dark = { 170, 160, 145 }, accent = { 150, 90, 255 }, eye = "glow", extras = { "horns", "spikes", "tail" } } },
	-- Celestial (+ Star Seraph = 3)
	{ id = "astral-whale", name = "Astral Whale", rarity = "Celestial", power = 1500, weight = 1.2, description = "It swims between the stars.", element = "cosmic", attack = "beam", crit = "nova",
		look = { shape = "serpent", main = { 60, 70, 170 }, dark = { 30, 35, 100 }, accent = { 170, 230, 255 }, eye = "happy", extras = { "fins", "orbs", "halo" } } },
	{ id = "comet-pegasus", name = "Comet Pegasus", rarity = "Celestial", power = 1750, weight = 0.7, description = "It leaves a trail of stardust behind.", element = "light", attack = "charge", crit = "skybeam",
		look = { shape = "flyer", main = { 245, 245, 255 }, dark = { 190, 200, 235 }, accent = { 140, 220, 255 }, eye = "lash", extras = { "wings4", "horns", "mane", "tail" } } },
	-- Divine (+ Sun Titan = 3)
	{ id = "radiant-archangel", name = "Radiant Archangel", rarity = "Divine", power = 3600, weight = 1.1, description = "Its light can be seen from any island.", element = "light", attack = "slash", crit = "skybeam",
		look = { shape = "floater", main = { 255, 245, 220 }, dark = { 230, 200, 140 }, accent = { 255, 215, 90 }, eye = "happy", extras = { "wings4", "halo", "cape" } } },
	{ id = "gaia-colossus", name = "Gaia Colossus", rarity = "Divine", power = 4200, weight = 0.6, description = "Forests grow on its shoulders.", element = "nature", attack = "slam", crit = "quake",
		look = { shape = "biped", main = { 110, 170, 80 }, dark = { 90, 70, 50 }, accent = { 255, 150, 200 }, eye = "brave", extras = { "antlers", "leaf", "crown" } } },
	-- Supreme (+ Cosmic Emperor = 2)
	{ id = "infinity-dragon", name = "Infinity Dragon", rarity = "Supreme", power = 10500, weight = 0.6, description = "It has no beginning and no end.", element = "cosmic", attack = "beam", crit = "nova",
		look = { shape = "flyer", main = { 70, 30, 140 }, dark = { 30, 15, 70 }, accent = { 255, 120, 230 }, eye = "star", extras = { "wings4", "crown", "horns", "spikes", "tail" } } },
}) do
	table.insert(Config.Monsters, m)
end

--------------------------------------------------------------------
-- WILD rolls: each roll can land on WILD, which rolls again. Getting 3
-- WILDs in a row (chances multiplied together) spins the egg wheel.
-- 0.04 x 0.4 x 0.25 = 0.004 -> about 1 in 250 rolls gets 3 WILDs.
-- (1st WILD ~1 in 25 rolls, 2 WILDs ~1 in 63 rolls)
--------------------------------------------------------------------
Config.Wild = {
	chances = { 0.04, 0.4, 0.25 }, -- chance of the 1st WILD, then the 2nd, then the 3rd
	-- the egg wheel after 3 WILDs (weights = % chance). imageId = your
	-- picture on that slice ("rbxassetid://..."); "" = the drawn egg
	wheel = {
		{ rarity = "Mythic", weight = 50, imageId = "" },
		{ rarity = "Secret", weight = 25, imageId = "" },
		{ rarity = "Celestial", weight = 15, imageId = "" },
		{ rarity = "Divine", weight = 7, imageId = "" },
		{ rarity = "Supreme", weight = 3, imageId = "" },
	},
}

--------------------------------------------------------------------
-- Sounds + music (all from Roblox's licensed libraries; swap any id)
--------------------------------------------------------------------
Config.Sounds = {
	hatchRattle = "rbxassetid://9116420445", -- egg rattling while it hatches
	eggCrack = { "rbxassetid://9113959343", "rbxassetid://9113959071", "rbxassetid://9113958649" },
	hatchReveal = "rbxassetid://9116418035", -- the monster pops out
	wild = "rbxassetid://9125647212", -- WILD roll
	wheelTick = "rbxassetid://9113650981", -- the egg wheel ticking
	coin = "rbxasset://sounds/electronicpingshort.wav", -- "ching!" per cash bill (offline earnings); put a coin sound id here
	coinVolume = 0.4,
	music = { -- plays when you enter the biome
		forest = "rbxassetid://82900133335093", -- "Peaceful Breeze" (the birds were only a quiet 10s ambience)
		desert = "rbxassetid://1838819842",
		volcanic = "rbxassetid://1842089558",
		tundra = "rbxassetid://9046912294",
		candy = "rbxassetid://9048060259",
		atlantis = "rbxassetid://91587908006120",
	},
	town = { -- Monster Town: one of these plays now and then
		"rbxassetid://9119383479",
		"rbxassetid://9038472426",
		"rbxassetid://9038464849",
	},
	musicVolume = 0.35,
	townVolume = 0.4,
}

--------------------------------------------------------------------
-- Gamepasses (shown in the Shop). imageId = the icon shown on its card.
-- Perks stack (2x Cash + VIP = 2.4x cash).
--------------------------------------------------------------------
Config.Gamepasses = {
	{ key = "doubleRoll", id = 1999533030, name = "Double Roll", imageId = "rbxassetid://71391623130051", perks = { "Roll 2 eggs at the same time" } },
	{ key = "doubleCash", id = 1998645039, name = "2x Cash", imageId = "rbxassetid://102064029314139", perks = { "Double cash per second" } },
	{ key = "vip", id = 1998465046, name = "VIP", imageId = "rbxassetid://81291811946600", perks = { "VIP name tag + chat tag", "+20% cash", "+10% roll speed", "+15% walk speed", "Double daily rewards", "+10% offline earnings" } },
	{ key = "autoSell", id = 1998668994, name = "Auto Sell", imageId = "rbxassetid://119296484955284", perks = { "Sells eggs + monsters for you", "By rarity or by cash/s" } },
	{ key = "fastRoll", id = 1999971018, name = "Fast Roll", imageId = "rbxassetid://105094275388977", perks = { "Roll 30% faster" } },
	{ key = "moreDrops", id = 1997943032, name = "More Drops", imageId = "rbxassetid://72855230975729", perks = { "+25% enemy drop chance" } },
	{ key = "fastGrowth", id = 1997853055, name = "Fast Growth", imageId = "rbxassetid://101168030555227", perks = { "Eggs hatch 2x faster" } },
	{ key = "plusMonster", id = 1999821057, name = "+1 Monster", imageId = "rbxassetid://115233703785640", perks = { "Equip 1 more monster" } },
	{ key = "supporter", id = 1998483043, name = "Supporter", imageId = "rbxassetid://109467610783421", perks = { "Violet SUPPORTER chat tag", "+10% drop chance" } },
}
-- name / chat tags (a player with both picks one in Settings)
Config.PassTags = {
	dev = { text = "DEV", color = { 255, 70, 70 } },
	admin = { text = "ADMIN", color = { 255, 120, 40 } },
	tester = { text = "TESTER", color = { 70, 220, 140 } },
	beta = { text = "BETA", color = { 90, 180, 255 } },
	vip = { text = "VIP", color = { 255, 205, 60 } },
	supporter = { text = "SUPPORTER", color = { 170, 90, 255 } },
}
Config.TagOrder = { "dev", "admin", "tester", "beta", "vip", "supporter" }
Config.DevUserIds = { [1165846861] = true }
-- tags a player can pick: DEV (the developer), ADMIN / TESTER / BETA
-- (given from the admin panel, saved in profile.tags), VIP / SUPPORTER
-- (from their gamepasses)
function Config.OwnedTags(profile, userId)
	local list = {}
	for _, key in ipairs(Config.TagOrder) do
		local has
		if key == "dev" then
			has = Config.DevUserIds[userId or 0] == true
		elseif key == "vip" or key == "supporter" then
			has = Config.HasPass(profile, key)
		else
			has = profile ~= nil and profile.tags ~= nil and profile.tags[key] == true
		end
		if has then
			table.insert(list, key)
		end
	end
	return list
end
-- bought on Roblox (profile.passes) OR given by the admin (profile.adminPasses)
function Config.HasPass(profile, key)
	return profile ~= nil and ((profile.passes ~= nil and profile.passes[key] == true) or (profile.adminPasses ~= nil and profile.adminPasses[key] == true))
end

--------------------------------------------------------------------
-- Developer products
--------------------------------------------------------------------
Config.Products = {
	hatchAll = { id = 3715373678, name = "Hatch All", text = "Hatch every egg in your pen right now", imageId = "rbxassetid://130974608848145" },
	eggSkipImageId = "rbxassetid://92696344635446",
	-- skip an egg's timer: the smallest one that covers the time left
	eggSkip = {
		{ hours = 1, id = 3715373716 },
		{ hours = 2, id = 3715373757 },
		{ hours = 4, id = 3715373784 },
		{ hours = 8, id = 3715373853 },
		{ hours = 16, id = 3715373921 },
		{ hours = 24, id = 3715373963 },
	},
	-- cash packs: % of the cash needed for your NEXT rebirth (so they grow
	-- every time you rebirth). imageId = shop icon.
	cash = {
		{ key = "pile", id = 3715372817, name = "Pile of Cash", pct = 15, imageId = "rbxassetid://108795853438549" },
		{ key = "stack", id = 3715372907, name = "Stack of Cash", pct = 25, imageId = "rbxassetid://129937593396264" },
		{ key = "bag", id = 3715372954, name = "Bag of Cash", pct = 40, imageId = "rbxassetid://140614516823162" },
		{ key = "bucket", id = 3715373030, name = "Bucket of Cash", pct = 60, imageId = "rbxassetid://111008016370758" },
		{ key = "mountain", id = 3715373095, name = "Mountain of Cash", pct = 100, imageId = "rbxassetid://132031668570337" },
		{ key = "cargo", id = 3715373180, name = "Cargo of Cash", pct = 200, imageId = "rbxassetid://124099272667082" },
	},
}
function Config.EggSkipTier(secondsLeft)
	for _, tier in ipairs(Config.Products.eggSkip) do
		if secondsLeft <= tier.hours * 3600 then
			return tier
		end
	end
	return Config.Products.eggSkip[#Config.Products.eggSkip]
end
function Config.CashPackAmount(profile, pct)
	local cost = Config.GetRebirthCost(profile and profile.rebirths or 0)
	return math.floor(cost * pct / 100)
end
function Config.PassCashMultiplier(p)
	-- (also the Cash skills of your equipped monsters)
	return (Config.HasPass(p, "doubleCash") and 2 or 1) * (Config.HasPass(p, "vip") and 1.2 or 1) * Config.SkillCashMultiplier(p)
end
function Config.PassRollTimeMultiplier(p) -- lower = faster (+ Roll Speed skills)
	return (Config.HasPass(p, "fastRoll") and 0.7 or 1) * (Config.HasPass(p, "vip") and 0.9 or 1) * (1 - Config.Skill(p, "rollSpeed") / 100)
end
function Config.PassDropMultiplier(p)
	return (Config.HasPass(p, "moreDrops") and 1.25 or 1) * (Config.HasPass(p, "supporter") and 1.1 or 1)
end
function Config.PassHatchMultiplier(p) -- lower = faster (+ Hatch Speed skills)
	return (Config.HasPass(p, "fastGrowth") and 0.5 or 1) * (1 - Config.Skill(p, "hatch") / 100)
end
function Config.PassExtraMonsters(p)
	return Config.HasPass(p, "plusMonster") and 1 or 0
end
-- Critical hits: chance (0-1) and damage multiplier with upgrades
function Config.CritStats(profile)
	local C = Config.Combat
	local chance = (C.critChance + Config.GetUpgradeBonus(profile and profile.upgrades, "critChance") + Config.Skill(profile, "critChance")) / 100
	local mult = C.critMultiplier + (Config.GetUpgradeBonus(profile and profile.upgrades, "critDamage") + Config.Skill(profile, "critDamage")) / 100
	return math.clamp(chance, 0, 1), mult
end

-- Offline earnings: your pen keeps earning while you're away
Config.Offline = { baseHours = 2, rate = 0.2, vipBonus = 0.1, minSeconds = 60 } -- 20% of income (VIP 30%)
function Config.OfflineHours(profile)
	return Config.Offline.baseHours + Config.GetUpgradeBonus(profile and profile.upgrades, "offlineTime")
end
function Config.OfflineRate(profile)
	return (Config.Offline.rate + (Config.HasPass(profile, "vip") and Config.Offline.vipBonus or 0)) * (1 + Config.Skill(profile, "offline") / 100)
end
function Config.PassWalkMultiplier(p) -- VIP + Walk Speed skills
	return (Config.HasPass(p, "vip") and 1.15 or 1) * (1 + Config.Skill(p, "walk") / 100)
end
function Config.PassDailyMultiplier(p)
	return Config.HasPass(p, "vip") and 2 or 1
end

-- Auto Sell gamepass
Config.AutoSellGamepassId = 1998668994

function Config.GetRarity(rarityName)
	for _, rarity in ipairs(Config.Rarities) do
		if rarity.key == rarityName then
			return rarity
		end
	end
	return Config.Rarities[1]
end

function Config.GetMonster(monsterId)
	for _, monster in ipairs(Config.Monsters) do
		if monster.id == monsterId then
			return monster
		end
	end
	return nil
end

function Config.GetSizeVariant(sizeKey)
	for _, variant in ipairs(Config.SizeVariants) do
		if variant.key == sizeKey then
			return variant
		end
	end
	return Config.SizeVariants[1]
end

function Config.GetFinishVariant(finishKey)
	for _, variant in ipairs(Config.FinishVariants) do
		if variant.key == finishKey then
			return variant
		end
	end
	return Config.FinishVariants[1]
end

function Config.GetUpgradeCost(level)
	return math.floor(100 * (level or 1) ^ 1.65)
end

function Config.NextPityThreshold(pity)
	local thresholds = {
		{ value = Config.PityThresholds.rare, label = "Rare" },
		{ value = Config.PityThresholds.epic, label = "Epic" },
		{ value = Config.PityThresholds.legendary, label = "Legendary" },
	}
	for _, entry in ipairs(thresholds) do
		if pity < entry.value then
			return entry
		end
	end
	return thresholds[#thresholds]
end

Config.HatchDurations = {
	Common = 20,
	Uncommon = 45,
	Rare = 90,
	Epic = 180,
	Legendary = 360,
	Mythic = 720,
	Secret = 1440,
	Celestial = 2400,
	Divine = 3000,
	Supreme = 3600,
}

function Config.GetHatchDuration(rarityKey)
	return Config.HatchDurations[rarityKey] or 30
end

--------------------------------------------------------------------
-- Upgrade tree
--
-- Fully data-driven: to add a stat, add it to a branch below and give
-- it a base cost + per-tier value. To retune costs/values, just edit
-- the numbers here — nothing else in the codebase needs to change.
-- Each node has an `imageId` slot (blank by default) for a custom
-- uploaded hex icon; set it to "rbxassetid://..." once you have one.
--------------------------------------------------------------------

Config.UpgradeBranches = {
	{ key = "economy", name = "Economy", icon = "\240\159\146\176", stats = { "cash", "backpackCap", "offlineTime" } },
	{ key = "fortune", name = "Fortune", icon = "\240\159\141\128", stats = { "luck", "drops", "potionDrop", "crystal", "shardSurge" } },
	{ key = "combat", name = "Combat", icon = "\226\154\148\239\184\143", stats = { "health", "damage", "critChance", "critDamage" } },
	{ key = "variants", name = "Variants", icon = "\226\156\168", stats = { "mutation", "size" } },
	{ key = "capacity", name = "Capacity", icon = "\240\159\147\166", stats = { "monsterCap", "eggCap" } },
	{ key = "player", name = "Player", icon = "\240\159\143\131", stats = { "speed", "rollSpeed", "wildChance" } },
}

-- Shared hex-shaped background asset for every upgrade node in the UI.
-- Leave blank to use the built-in rounded-square fallback (still looks
-- clean with zero custom art); set to "rbxassetid://..." once you have
-- a hex frame you like and every node picks it up automatically.
Config.UpgradeHexImage = ""

-- Image slots for the big hexes (put "rbxassetid://..." when you make
-- one; "" = just the studded hexagon). The picture goes see-through on
-- top of the studded hexagon; the labels still show on top of it.
-- How see-through your pictures are on the studded hexes (0 = solid,
-- 1 = invisible). 0.35 lets the studs show through.
Config.UpgradeImageTransparency = 0.35
Config.UpgradeCenterImage = "" -- middle "UPGRADES" hex
Config.UpgradeBackImage = "" -- middle "BACK" hex inside a category
Config.UpgradeBranchImages = {
	economy = "",
	fortune = "",
	combat = "",
	variants = "",
	capacity = "",
	player = "",
}

-- Your own hexagon image for each upgrade (every tier of that upgrade uses
-- it, see-through over the studded hexagon). Leave "" for just the hexagon.
-- To give one single tier its own
-- image instead, set that node's imageId in Config.UpgradeNodes.
Config.UpgradeStatImages = {
	cash = "",
	backpackCap = "",
	offlineTime = "",
	luck = "",
	drops = "",
	potionDrop = "",
	crystal = "",
	shardSurge = "",
	health = "",
	damage = "",
	critChance = "",
	critDamage = "",
	mutation = "",
	size = "",
	monsterCap = "",
	eggCap = "",
	speed = "",
	rollSpeed = "",
	wildChance = "",
}

Config.UpgradeStatInfo = {
	cash = { name = "Cash", unit = "%", live = true },
	backpackCap = { name = "Backpack", unit = "", live = true },
	offlineTime = { name = "Offline Time", unit = "h", live = true }, -- longer offline earnings
	luck = { name = "Luck", unit = "", live = true },
	drops = { name = "Drops", unit = "%", live = true }, -- Rift Shard drop chance
	potionDrop = { name = "Potion Drop", unit = "%", live = true }, -- potion drop chance
	crystal = { name = "Rift Shards", unit = "%", live = true }, -- more shards per drop
	shardSurge = { name = "Shard Surge", unit = "%", live = true }, -- chance a shard drop is doubled
	health = { name = "Health", unit = "%", live = true },
	damage = { name = "Damage", unit = "%", live = true },
	critChance = { name = "Crit Chance", unit = "%", live = true },
	critDamage = { name = "Crit Damage", unit = "%", live = true },
	mutation = { name = "Mutation", unit = "%", live = true },
	size = { name = "Size", unit = "%", live = true },
	monsterCap = { name = "Monster Cap", unit = "", live = true },
	eggCap = { name = "Egg Cap", unit = "", live = true },
	speed = { name = "Speed", unit = "%", live = true },
	rollSpeed = { name = "Roll Speed", unit = "%", live = true },
	wildChance = { name = "Wild Chance", unit = "%", live = true }, -- more WILD rolls
}

-- upgrades paid with Rift Shards instead of cash (their costs below are
-- in shards and grow slower: SHARD_GROWTH per tier)
Config.UpgradeShardStats = { crystal = true, shardSurge = true, rollSpeed = true, wildChance = true }

-- Upgrades are permanent (they survive rebirth), so the tree is long:
-- tier 1 is cheap for new players, and each tier costs GROWTH x the one
-- before it (x3 by default -> tier 5 = 81x, tier 10 = ~19,700x the base).
-- The number of tiers of a stat = how many values are in TIER_VALUES.
local BASE_COST = {
	cash = 1000000, -- income: $1M -> $10M -> $100M -> $1B -> $10B ...
	backpackCap = 800,
	offlineTime = 50000, -- $50K -> $500K -> $5M ...
	luck = 1500,
	drops = 500000, -- Rift Shard drop chance: $500K -> $5M -> ...
	potionDrop = 2000,
	crystal = 50, -- SHARDS: Rift Shards per drop: 50 -> 100 -> 200 ...
	shardSurge = 100, -- SHARDS: chance to double a shard drop: 100 -> 200 -> ...
	health = 1000,
	damage = 1000,
	critChance = 5000,
	critDamage = 5000,
	mutation = 3000,
	size = 3000,
	monsterCap = 100000, -- only 3 tiers (3 -> 6 pets), very expensive
	eggCap = 2000,
	speed = 600,
	rollSpeed = 30, -- SHARDS: 30 -> 60 -> 120 ...
	wildChance = 150, -- SHARDS: 150 -> 300 -> 600 ...
}

local GROWTH = {
	monsterCap = 20, -- $100K -> $2M -> $40M
}
local DEFAULT_GROWTH = 10 -- each tier costs 10x the one before
local SHARD_GROWTH = 2 -- shard upgrades: each tier costs 2x the one before

local TIER_VALUES = {
	-- every upgrade is about 1.7x stronger than before (3% -> 5% per level)
	cash = { 8, 8, 8, 8, 15, 15, 15, 25, 25, 35 }, -- +162% income total
	backpackCap = { 40, 40, 40, 40, 40, 40, 40, 40, 40, 40 }, -- +400 slots
	offlineTime = { 1, 1, 1, 1, 1, 1 }, -- +1 hour each: 2h -> 8h
	luck = { 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5 },
	drops = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 }, -- +50% Rift Shard drop chance
	potionDrop = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 }, -- +50% potion drop chance
	crystal = { 15, 15, 15, 15, 15, 15, 15, 15, 15, 15 }, -- +150% shards per drop
	shardSurge = { 6, 6, 6, 6, 6, 6, 6, 6, 6, 6 }, -- up to 60% chance to double a shard drop
	health = { 15, 15, 15, 15, 25, 25, 25, 35, 35, 40 }, -- +265% pet health
	damage = { 15, 15, 15, 15, 25, 25, 25, 35, 35, 40 }, -- +265% pet damage
	critChance = { 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 }, -- +0.5% each: 5% base -> 10% chance to crit
	critDamage = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }, -- +2% each: 1.5x base -> 1.7x crit damage
	mutation = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	size = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	monsterCap = { 1, 1, 1 },
	eggCap = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }, -- 5 -> 25 eggs
	speed = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	rollSpeed = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 },
	wildChance = { 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 }, -- +100% WILD chance total (3 WILDs: 1 in 250 -> 1 in 125)
}

Config.UpgradeNodes = {}
for _, branch in ipairs(Config.UpgradeBranches) do
	for _, statKey in ipairs(branch.stats) do
		local previousId = nil
		local shards = Config.UpgradeShardStats[statKey] == true
		local growth = GROWTH[statKey] or (shards and SHARD_GROWTH or DEFAULT_GROWTH)
		for tier, value in ipairs(TIER_VALUES[statKey]) do
			local id = statKey .. tier
			table.insert(Config.UpgradeNodes, {
				id = id,
				statKey = statKey,
				branch = branch.key,
				tier = tier,
				cost = math.floor(BASE_COST[statKey] * growth ^ (tier - 1)),
				value = value,
				requires = previousId,
				currency = shards and "shards" or "cash",
				imageId = "",
			})
			previousId = id
		end
	end
end

-- what a player has of the node's currency, and the price text
function Config.UpgradeFunds(profile, node)
	if node.currency == "shards" then
		return profile and profile.riftShards or 0
	end
	return profile and profile.cash or 0
end
function Config.UpgradePriceText(node)
	if node.currency == "shards" then
		return Config.FormatNumber(node.cost) .. " Shards"
	end
	return "$" .. Config.FormatNumber(node.cost)
end

function Config.GetUpgradeTierCount(statKey)
	return #(TIER_VALUES[statKey] or {})
end

function Config.GetUpgradeNode(id)
	for _, node in ipairs(Config.UpgradeNodes) do
		if node.id == id then
			return node
		end
	end
	return nil
end

-- Sum of `value` across every purchased node for a given stat. `upgrades`
-- is the profile's { [nodeId] = true } purchase table.
function Config.GetUpgradeBonus(upgrades, statKey)
	local total = 0
	if type(upgrades) ~= "table" then
		return total
	end
	for _, node in ipairs(Config.UpgradeNodes) do
		if node.statKey == statKey and upgrades[node.id] then
			total += node.value
		end
	end
	return total
end

-- Capacity limits including upgrades (the upgrade values were bought but
-- previously never applied — everything now goes through these).
function Config.GetBackpackCap(upgrades)
	return Config.BackpackCap + Config.GetUpgradeBonus(upgrades, "backpackCap")
end

function Config.GetPenMonsterCap(upgrades)
	return Config.PenMonsterCap + Config.GetUpgradeBonus(upgrades, "monsterCap")
end

function Config.GetPenEggCap(upgrades, profile)
	-- (+1 egg slot for each size completed in the Index)
	local index = profile and Config.IndexSizesDone(profile) * Config.IndexRewards.sizeEggSlots or 0
	return Config.PenEggCap + Config.GetUpgradeBonus(upgrades, "eggCap") + index
end

-- Hatching: the egg shakes for HatchShakeTime seconds, the monster pops
-- out, and its info floats above it for HatchInfoTime seconds.
Config.HatchShakeTime = 4.5
Config.HatchInfoTime = 2.5

-- Rare hatches are announced in the chat of EVERY server:
-- "[Player] hatched a GIGANTIC GALAXY Void Dragon! (1 in 2.1M)"
-- A hatch is announced if ANY of these is true:
Config.HatchAnnounce = {
	minOdds = 100000, -- its odds are 1 in 100,000 or rarer
	minTier = 8, -- Celestial, Divine or Supreme
	sizes = { Gigantic = true },
	finishes = { Galaxy = true },
}
function Config.IsAnnouncedHatch(entry)
	local m = Config.GetMonster(entry.monsterId)
	if not m then
		return false
	end
	local A = Config.HatchAnnounce
	if A.sizes[entry.size] or A.finishes[entry.finish] then
		return true
	end
	if (Config.GetRarity(m.rarity).tier or 1) >= A.minTier then
		return true
	end
	return Config.GetOdds(entry.monsterId, entry.size, entry.finish, entry.kg) >= A.minOdds
end

-- Base odds of rolling this exact monster + size + finish (no luck/pity),
-- e.g. Moss Slime ≈ 1 in 3, Huge Rainbow Moss Slime ≈ 1 in 5,000.
--------------------------------------------------------------------
-- Weight (kg). Each monster rolls a random kg; heavier = rarer. The kg
-- only raises the odds once it's heavier than about half of its kind.
--------------------------------------------------------------------
-- kg follows a long-tail curve: most monsters are near their base weight,
-- and heavier ones get rarer and rarer, up to MaxKg. Reaching 100,000 kg
-- is roughly 1 in millions.
Config.KgRarity = 1.4 -- higher = heavy monsters are rarer
Config.MaxKg = 100000

function Config.GetBaseKg(monsterId, sizeKey)
	local monster = Config.GetMonster(monsterId)
	local base = 1 + ((monster and monster.power) or 10) / 10
	local scale = Config.GetSizeVariant(sizeKey).scale or 1
	return base * scale * scale
end

function Config.RollKg(monsterId, sizeKey)
	local u = math.max(1e-12, math.random())
	local factor = u ^ (-1 / Config.KgRarity)
	local kg = Config.GetBaseKg(monsterId, sizeKey) * factor
	return math.min(Config.MaxKg, math.floor(kg * 10 + 0.5) / 10)
end

-- chance to roll at least this heavy = (kg / base) ^ -KgRarity
function Config.GetKgOddsMultiplier(monsterId, sizeKey, kg)
	if type(kg) ~= "number" then
		return 1
	end
	local f = kg / Config.GetBaseKg(monsterId, sizeKey)
	if f <= 1 then
		return 1
	end
	local chanceAtLeast = f ^ (-Config.KgRarity)
	return math.max(1, 0.5 / chanceAtLeast)
end

-- heavier monsters earn more cash/s: x (kg / base kg) ^ 0.5
function Config.GetKgIncomeMultiplier(entry)
	if type(entry.kg) ~= "number" or not entry.monsterId then
		return 1
	end
	local f = entry.kg / Config.GetBaseKg(entry.monsterId, entry.size)
	return math.max(1, f) ^ 0.5
end

function Config.FormatKg(kg)
	if type(kg) ~= "number" then
		return ""
	end
	if kg >= 1000 then
		return Config.FormatNumber(kg) .. " kg"
	end
	return string.format("%.1f kg", kg)
end

function Config.GetOdds(monsterId, sizeKey, finishKey, kg, gradeKey)
	local monster = Config.GetMonster(monsterId)
	if not monster then
		return 0
	end
	local totalRarity = 0
	for _, r in ipairs(Config.Rarities) do
		totalRarity += r.weight
	end
	-- this monster's share of its rarity (monster.weight, 1 = normal)
	local sameRarity = 0
	for _, m in ipairs(Config.Monsters) do
		if m.rarity == monster.rarity then
			sameRarity += m.weight or 1
		end
	end
	sameRarity /= (monster.weight or 1)
	local function variantChance(list, key)
		local total, weight = 0, 0
		for _, v in ipairs(list) do
			total += v.weight
			if v.key == key then
				weight = v.weight
			end
		end
		return total > 0 and weight / total or 0
	end
	local rarity = Config.GetRarity(monster.rarity)
	local p = (rarity.weight / totalRarity) / math.max(1e-9, sameRarity)
		* variantChance(Config.SizeVariants, sizeKey or "Normal")
		* variantChance(Config.FinishVariants, finishKey or "Normal")
	p = p / Config.GetKgOddsMultiplier(monsterId, sizeKey, kg)
	-- (a hatched pet's grade counts too; nil = leave the grade out)
	if gradeKey then
		p *= Config.GradeChance(gradeKey)
	end
	if p <= 0 then
		return 0
	end
	return math.max(1, math.floor(1 / p + 0.5))
end

-- Hatch time of a specific egg, based on the cash/s the monster inside
-- will make (which already includes rarity, size, finish and kg):
-- ~6 $/s -> 25s, ~25 $/s -> 2 min, ~60 $/s -> 5.5 min, capped at 1 hour.
Config.HatchTimeBase = 3.5
Config.HatchTimeExponent = 1.1
Config.HatchTimeMin = 15
Config.HatchTimeMax = 3600

function Config.GetEggHatchDuration(egg)
	local income = Config.GetEntryIncome(egg)
	if not income or income <= 0 then
		return Config.GetHatchDuration(egg.rarity)
	end
	return math.floor(math.clamp(Config.HatchTimeBase * income ^ Config.HatchTimeExponent, Config.HatchTimeMin, Config.HatchTimeMax))
end

function Config.FormatDuration(secs)
	secs = math.max(0, math.ceil(secs))
	if secs >= 3600 then
		return string.format("%dh %dm", secs // 3600, (secs % 3600) // 60)
	elseif secs >= 60 then
		return string.format("%dm %ds", secs // 60, secs % 60)
	end
	return secs .. "s"
end

function Config.FormatOdds(n)
	n = math.max(1, math.floor((n or 1) + 0.5))
	if n < 10000 then
		return "1 in " .. tostring(n)
	end
	-- 12.5K, 583.7B, 1.2T ... (one decimal, no "583728M")
	local suffixes = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }
	local i, v = 0, n
	while v >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	local s = string.format("%.1f", math.floor(v * 10) / 10):gsub("%.0$", "")
	return "1 in " .. s .. suffixes[i]
end

--------------------------------------------------------------------
-- Index collection rewards
--   * every monster of a rarity found: +luck% and +cash% (forever)
--   * every monster found as a finish (Gold...): a pen in that finish
--   * every monster found as a size (Big...): the plot grows +3 studs a
--     side and +1 egg slot, for each size completed
--------------------------------------------------------------------
Config.IndexRewards = {
	rarity = {
		Common = { luck = 2, cash = 2 },
		Uncommon = { luck = 2, cash = 3 },
		Rare = { luck = 3, cash = 3 },
		Epic = { luck = 3, cash = 4 },
		Legendary = { luck = 4, cash = 5 },
		Mythic = { luck = 5, cash = 5 },
		Secret = { luck = 5, cash = 6 },
		Celestial = { luck = 6, cash = 7 },
		Divine = { luck = 7, cash = 8 },
		Supreme = { luck = 8, cash = 10 },
	},
	sizeStuds = 3, -- plot grows this much on each side per completed size
	sizeEggSlots = 1, -- + egg slots per completed size
	-- best first: the pen takes the best finish you completed
	finishOrder = { "Galaxy", "Rainbow", "Diamond", "Gold", "Silver" },
	sizeOrder = { "Big", "Huge", "Titan", "Gigantic" },
}
-- did the player find every monster of this rarity?
function Config.IndexRarityDone(profile, rarityKey)
	local any = false
	for _, m in ipairs(Config.Monsters) do
		if m.rarity == rarityKey then
			any = true
			if not (profile and profile.owned and profile.owned[m.id] ~= nil) then
				return false
			end
		end
	end
	return any
end
-- every monster found as this size / finish?
function Config.IndexVariantDone(profile, field, key)
	local stats = profile and profile.indexStats
	if not stats then
		return false
	end
	for _, m in ipairs(Config.Monsters) do
		local rec = stats[m.id]
		if not (rec and rec[field] and rec[field][key]) then
			return false
		end
	end
	return #Config.Monsters > 0
end
-- luck% and cash% from completed rarities
function Config.IndexBonus(profile)
	local luck, cash = 0, 0
	for key, r in pairs(Config.IndexRewards.rarity) do
		if Config.IndexRarityDone(profile, key) then
			luck += r.luck
			cash += r.cash
		end
	end
	return luck, cash
end
-- the pen's finish (nil = normal wood) and how many sizes are complete
function Config.IndexPenFinish(profile)
	for _, f in ipairs(Config.IndexRewards.finishOrder) do
		if Config.IndexVariantDone(profile, "finishes", f) then
			return f
		end
	end
	return nil
end
function Config.IndexSizesDone(profile)
	local n = 0
	for _, sz in ipairs(Config.IndexRewards.sizeOrder) do
		if Config.IndexVariantDone(profile, "sizes", sz) then
			n += 1
		end
	end
	return n
end

--------------------------------------------------------------------
-- Day / night + weather, by the real clock (the same in every server;
-- server and players work it out themselves from the time).
--   Night: the first 3 minutes of every hour (eggs grow 1.5x faster)
--   Weather: 70% of hours, starts at a random minute (8-52), 5 minutes
--------------------------------------------------------------------
Config.WorldEvents = {
	nightSeconds = 180,
	nightEggSpeed = 1.5,
	weatherChance = 0.7,
	weatherSeconds = 300,
	weatherStartMin = 8,
	weatherStartMax = 52,
	weathers = {
		{ key = "starfall", name = "STARFALL", text = "Galaxy 3x more common", weight = 25, finishes = { Galaxy = 3 }, color = { 190, 150, 255 } },
		{ key = "golden", name = "GOLDEN HOUR", text = "Gold 3x more common", weight = 25, finishes = { Gold = 3 }, color = { 255, 205, 60 } },
		{ key = "storm", name = "GIANT STORM", text = "Big sizes 3x more common", weight = 25, sizes = { Big = 3, Huge = 3, Titan = 3, Gigantic = 3 }, color = { 140, 170, 210 } },
		{ key = "lucky", name = "LUCKY WIND", text = "2x luck", weight = 15, luck = 2, color = { 110, 230, 120 } },
		{ key = "rainbow", name = "RAINBOW SKY", text = "Rainbow 3x more common", weight = 10, finishes = { Rainbow = 3 }, color = { 255, 140, 220 } },
	},
}
-- what's happening at time t (seconds, os.time / GetServerTimeNow):
-- { night = bool, nightEnds = t, weather = def or nil, weatherEnds = t }
function Config.WorldEventAt(t)
	local W = Config.WorldEvents
	local hour = math.floor(t / 3600)
	local hourStart = hour * 3600
	local ev = { night = t - hourStart < W.nightSeconds, nightEnds = hourStart + W.nightSeconds, hour = hour }
	local rng = Random.new(hour * 7919 + 13)
	if rng:NextNumber() < W.weatherChance then
		local start = hourStart + rng:NextInteger(W.weatherStartMin, W.weatherStartMax) * 60
		local total = 0
		for _, w in ipairs(W.weathers) do
			total += w.weight
		end
		local pick = rng:NextNumber() * total
		local chosen = W.weathers[#W.weathers]
		for _, w in ipairs(W.weathers) do
			pick -= w.weight
			if pick <= 0 then
				chosen = w
				break
			end
		end
		if t >= start and t < start + W.weatherSeconds then
			ev.weather, ev.weatherEnds = chosen, start + W.weatherSeconds
		end
		ev.nextWeather, ev.nextWeatherAt = chosen, start
	end
	return ev
end

--------------------------------------------------------------------
-- Grades (E lowest ... SSS highest). Rolled when an egg hatches: low
-- grades are common, high ones very rare. Each grade above E: +10% cash,
-- damage and health. Fusion: 3 of the same monster + grade (+ a Fusion
-- Ticket) -> 1 of the next grade (best size / finish of the three).
--------------------------------------------------------------------
Config.Grades = {
	{ key = "E", weight = 60, color = { 170, 175, 190 } },
	{ key = "D", weight = 25, color = { 110, 220, 110 } },
	{ key = "C", weight = 10, color = { 80, 170, 255 } },
	{ key = "B", weight = 4, color = { 180, 110, 255 } },
	{ key = "A", weight = 0.9, color = { 255, 205, 60 } },
	{ key = "S", weight = 0.09, color = { 255, 110, 60 } },
	{ key = "SS", weight = 0.009, color = { 255, 90, 200 } },
	{ key = "SSS", weight = 0.001, color = { 90, 255, 230 } },
}
Config.GradeBonus = 10 -- % cash / damage / health per grade above E
function Config.GradeIndex(key)
	for i, g in ipairs(Config.Grades) do
		if g.key == key then
			return i
		end
	end
	return 1
end
function Config.GetGrade(key)
	return Config.Grades[Config.GradeIndex(key)]
end
function Config.GradeColor(key)
	local c = Config.GetGrade(key).color
	return Color3.fromRGB(c[1], c[2], c[3])
end
function Config.GradeMultiplier(key)
	return 1 + (Config.GradeIndex(key) - 1) * Config.GradeBonus / 100
end
-- chance of rolling this grade (for the odds)
function Config.GradeChance(key)
	local total = 0
	for _, g in ipairs(Config.Grades) do
		total += g.weight
	end
	return Config.GetGrade(key).weight / total
end
function Config.RollGrade(rng)
	local total = 0
	for _, g in ipairs(Config.Grades) do
		total += g.weight
	end
	local pick = (rng and rng:NextNumber() or math.random()) * total
	for _, g in ipairs(Config.Grades) do
		pick -= g.weight
		if pick <= 0 then
			return g.key
		end
	end
	return "E"
end

-- Friends: +10% income for each friend in your server (max +30%).
-- Group: +5% luck for members of the game's group (0 = off for now).
Config.FriendBonus = { perFriend = 10, max = 30 }
Config.Group = { id = 0, luck = 5 }

-- extra income from the Index + friends (server and HUD use the same)
function Config.ExtraIncomeMultiplier(profile)
	local _, indexCash = Config.IndexBonus(profile)
	local friends = math.min(Config.FriendBonus.max, (profile and profile.friendBonus) or 0)
	return (1 + indexCash / 100) * (1 + friends / 100)
end

-- Luck (softer): only half of your extra luck counts, so 2x luck rolls
-- like 1.5x and 21x like 11x. Rolls then divide every rarity's odds by it.
Config.Luck = { soft = 0.5 }
function Config.SoftLuck(m)
	return 1 + math.max(0, (m or 1) - 1) * Config.Luck.soft
end

-- an egg's name with its size + finish: "Gigantic Rainbow Supreme Egg"
function Config.EggDisplayName(egg)
	local rarity = Config.GetRarity(egg and egg.rarity or "Common")
	return Config.BuildDisplayName(rarity.name .. " Egg", egg and egg.size, egg and egg.finish)
end
-- the real odds of this egg: its rarity x its size x its finish
function Config.GetEggOdds(rarityKey, sizeKey, finishKey)
	local total = 0
	for _, r in ipairs(Config.Rarities) do
		total += r.weight
	end
	local rarity = Config.GetRarity(rarityKey or "Common")
	local odds = total / math.max(1e-12, rarity.weight)
	local function chance(list, key)
		local t, w = 0, 0
		for _, v in ipairs(list) do
			t += v.weight
			if v.key == (key or "Normal") then
				w = v.weight
			end
		end
		return (t > 0 and w > 0) and (w / t) or 1
	end
	return odds / chance(Config.SizeVariants, sizeKey) / chance(Config.FinishVariants, finishKey)
end

--------------------------------------------------------------------
-- Dice (sold at the Dice Shop stall). The equipped dice multiplies the
-- chance of every rarity above Common by (1 + luck%). imageId is a
-- slot for your own dice icon.
--------------------------------------------------------------------
Config.Dice = {
	{ key = "common", name = "Common Dice", luck = 0, cost = 0, color = { 155, 166, 180 }, imageId = "" },
	{ key = "uncommon", name = "Uncommon Dice", luck = 1, cost = 200000, color = { 91, 205, 143 }, imageId = "rbxassetid://123743310892109" },
	{ key = "rare", name = "Rare Dice", luck = 2, cost = 4000000, color = { 75, 160, 255 }, imageId = "rbxassetid://118515790782413" },
	{ key = "epic", name = "Epic Dice", luck = 3, cost = 60000000, color = { 176, 102, 255 }, imageId = "rbxassetid://121811100357188" },
	{ key = "legendary", name = "Legendary Dice", luck = 5, cost = 800000000, color = { 255, 180, 67 }, imageId = "rbxassetid://89543967956550" },
	{ key = "mythic", name = "Mythic Dice", luck = 7, cost = 12000000000, color = { 255, 82, 139 }, imageId = "rbxassetid://121229103557418" },
	{ key = "secret", name = "Secret Dice", luck = 10, cost = 200000000000, color = { 160, 150, 190 }, imageId = "rbxassetid://72694947695527" },
	{ key = "celestial", name = "Celestial Dice", luck = 14, cost = 4000000000000, color = { 120, 215, 255 }, imageId = "rbxassetid://71725518426639" },
	{ key = "divine", name = "Divine Dice", luck = 19, cost = 80000000000000, color = { 255, 228, 130 }, imageId = "rbxassetid://130366771307960" },
	{ key = "supreme", name = "Supreme Dice", luck = 25, cost = 2000000000000000, color = { 255, 90, 60 }, imageId = "rbxassetid://99080298269341" },
}

function Config.FindDice(key)
	for _, d in ipairs(Config.Dice) do
		if d.key == key then
			return d
		end
	end
	return nil
end

function Config.GetDice(key)
	return Config.FindDice(key) or Config.Dice[1]
end

-- 500001 -> "500K", 1250000 -> "1.2M"
function Config.FormatNumber(n)
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	local suffixes = { "K", "M", "B", "T", "Qd", "Qn" }
	local i, v = 0, n
	while v >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	local s
	if v >= 100 then
		s = tostring(math.floor(v))
	else
		s = string.format("%.1f", math.floor(v * 10) / 10):gsub("%.0$", "")
	end
	return s .. suffixes[i]
end

-- Cash per second of one monster (same formula the server uses).
function Config.GetEntryIncome(entry)
	local monster = Config.GetMonster(entry.monsterId)
	if not monster then
		return 0
	end
	local rarity = Config.GetRarity(monster.rarity)
	local size = Config.GetSizeVariant(entry.size)
	local finish = Config.GetFinishVariant(entry.finish)
	local levelMultiplier = math.max(1, entry.level or 1) ^ 1.25
	return math.max(1, math.floor((rarity.tier * 5 + monster.power * 0.25) * size.incomeMultiplier * finish.incomeMultiplier * levelMultiplier * Config.GetKgIncomeMultiplier(entry) * Config.GradeMultiplier(entry.grade)))
end

--------------------------------------------------------------------
-- Biomes. Each is the size of the home map (480 x 400 studs), laid out
-- in a 3 x 2 grid in front of it. center = (X, Z). imageId is a slot for
-- an icon shown on the "you entered" banner. tiles = checker colors.
--------------------------------------------------------------------
local BIOME_SIZE = Vector2.new(480, 400)
-- In a straight line going out from the lobby's front edge (z = -140):
-- Forest -> Desert -> Volcanic -> Tundra -> Candy Land -> Atlantis.
-- mountain = colors of the side mountains (dirt/body + cap), 2 shades each.
Config.Biomes = {
	{ key = "home", name = "Home", subtitle = "Monster Town", center = Vector2.new(0, 60), size = BIOME_SIZE, color = { 255, 205, 93 }, imageId = "" },
	{ key = "forest", cost = 25000, name = "Whispering Woods", subtitle = "Forest", center = Vector2.new(0, -340), size = BIOME_SIZE, color = { 120, 220, 110 }, imageId = "",
		tiles = { { 70, 150, 60 }, { 58, 132, 52 } },
		mountain = { dirt = { { 135, 90, 52 }, { 118, 78, 45 } }, cap = { { 70, 150, 60 }, { 58, 132, 52 } } } },
	{ key = "desert", cost = 250000, name = "Scorched Dunes", subtitle = "Desert", center = Vector2.new(0, -740), size = BIOME_SIZE, color = { 255, 200, 110 }, imageId = "",
		tiles = { { 236, 206, 142 }, { 222, 190, 124 } },
		mountain = { dirt = { { 205, 160, 100 }, { 190, 145, 88 } }, cap = { { 236, 206, 142 }, { 222, 190, 124 } } } },
	{ key = "volcanic", cost = 2000000, name = "Obsidian Crags", subtitle = "Volcanic", center = Vector2.new(0, -1140), size = BIOME_SIZE, color = { 255, 110, 50 }, imageId = "",
		tiles = { { 64, 58, 64 }, { 50, 46, 54 } },
		mountain = { dirt = { { 50, 45, 52 }, { 40, 36, 44 } }, cap = { { 95, 82, 88 }, { 78, 68, 74 } } } },
	{ key = "tundra", cost = 15000000, name = "Frostbite Steppes", subtitle = "Tundra", center = Vector2.new(0, -1540), size = BIOME_SIZE, color = { 170, 230, 255 }, imageId = "",
		tiles = { { 240, 246, 255 }, { 222, 234, 246 } },
		mountain = { dirt = { { 120, 125, 140 }, { 105, 110, 125 } }, cap = { { 245, 250, 255 }, { 228, 238, 248 } } } },
	{ key = "candy", cost = 100000000, name = "Confection Kingdom", subtitle = "Candy Land", center = Vector2.new(0, -1940), size = BIOME_SIZE, color = { 255, 140, 200 }, imageId = "",
		tiles = { { 255, 182, 215 }, { 255, 160, 200 } },
		mountain = { dirt = { { 110, 65, 40 }, { 95, 55, 35 } }, cap = { { 255, 170, 210 }, { 255, 150, 195 } } } },
	{ key = "atlantis", cost = 750000000, name = "Sunken Abyss", subtitle = "Atlantis", center = Vector2.new(0, -2340), size = BIOME_SIZE, color = { 90, 200, 255 }, imageId = "",
		tiles = { { 72, 170, 182 }, { 60, 152, 168 } },
		mountain = { dirt = { { 90, 120, 130 }, { 78, 106, 118 } }, cap = { { 72, 170, 182 }, { 60, 152, 168 } } } },
}

function Config.GetBiomeAt(x, z)
	for _, b in ipairs(Config.Biomes) do
		if math.abs(x - b.center.X) <= b.size.X / 2 and math.abs(z - b.center.Y) <= b.size.Y / 2 then
			return b
		end
	end
	return nil
end

-- Icon shown before the shop name floating above each stall
-- ("rbxassetid://..."). Leave blank for text only.
Config.StallIcons = {
	SellStall = "",
	DiceStall = "",
	GearStall = "",
	GuildStall = "",
}

--------------------------------------------------------------------
-- Currencies, potions, items, rebirth and daily rewards
--------------------------------------------------------------------
Config.CashImage = "rbxassetid://83763596751604"
Config.RiftShardImage = "rbxassetid://75633089538163"
-- Stud texture for the cartoony studded windows (assets/ui/studs_tile.png
-- uploaded to Roblox). Leave "" until it's uploaded: windows still get the
-- new look, just without the studs.
Config.UIStudsImage = "rbxassetid://139993005514116"
-- Hexagon of studs for the Upgrade tree tiles (assets/ui/studs_hex.png
-- uploaded to Roblox). Leave "" until it's uploaded.
Config.UIHexStudsImage = "rbxassetid://98151350777131"

-- Egg pictures (Backpack, EGGS window, roll animation). The loading
-- screen keeps its own copy of these ids (it runs before Config loads).
Config.EggIcons = {
	Common = "rbxassetid://89065974622258",
	Uncommon = "rbxassetid://127482163109698",
	Rare = "rbxassetid://110319386910427",
	Epic = "rbxassetid://128903214440900",
	Legendary = "rbxassetid://104500738290331",
	Mythic = "rbxassetid://128239034591198",
	Secret = "rbxassetid://129812693239921",
	Celestial = "rbxassetid://92395625284904",
	Divine = "rbxassetid://76982835466807",
	Supreme = "rbxassetid://96209352033929",
}

-- duration in seconds (0 = instant)
Config.Potions = {
	{ key = "luck", name = "Luck Potion", imageId = "rbxassetid://110066320591030", duration = 120, text = "2x roll luck for 2 min" },
	{ key = "health", name = "Health Potion", imageId = "rbxassetid://78622291412983", duration = 180, text = "+50% pet health for 3 min" },
	{ key = "damage", name = "Damage Potion", imageId = "rbxassetid://73334192671687", duration = 180, text = "+50% pet damage for 3 min" },
	{ key = "cash", name = "Cash Potion", imageId = "rbxassetid://77742735052898", duration = 120, text = "2x cash income for 2 min" },
	{ key = "level", name = "XP Potion", imageId = "rbxassetid://87122184597982", duration = 180, text = "2x pet XP for 3 min" },
	{ key = "revive", name = "Revive Potion", imageId = "rbxassetid://92173666140969", duration = 0, text = "Revives a defeated pet" },
}
function Config.GetPotion(key)
	for _, p in ipairs(Config.Potions) do
		if p.key == key then
			return p
		end
	end
	return nil
end

Config.Items = {
	warpRemote = { name = "Warp Remote", imageId = "rbxassetid://80619965977171", text = "Use one to warp", button = "IN WARP" },
	fusionTicket = { name = "Fusion Ticket", imageId = "", text = "Fuse 3 of the same pet + grade into the next grade (Fusion Machine, Desert)" },
	giftCard = { name = "Gift Card", imageId = "rbxassetid://119686941815919", text = "Gift to players (Rebirth 3+)", button = "GIFT" },
}

-- Rebirth: costs cash + Rift Shards. Resets cash and unlocked biomes
-- (they must be bought again); keeps inventory, pen and upgrades.
Config.Rebirth = {
	baseCash = 2500000,
	baseShards = 100,
	growth = 2.2, -- the cash cost x2.2 every rebirth
	shardGrowth = 1.6, -- the shard cost x1.6 every rebirth
	cashBonus = 25, -- +% cash income per rebirth
	luckBonus = 10, -- +% luck per rebirth
	shardBonus = 25, -- +% Rift Shards from enemies per rebirth
	biomeShardBonus = 20, -- +% Rift Shards per biome after the first (harder biomes drop more)
}
-- how far along a biome is (Forest = 0, the next one = 1, ...)
function Config.BiomeStep(biomeKey)
	local step = -1
	for _, b in ipairs(Config.Biomes) do
		if b.key ~= "home" then
			step += 1
			if b.key == biomeKey then
				return step
			end
		end
	end
	return 0
end
function Config.GetRebirthCost(rebirths)
	local R = Config.Rebirth
	local n = rebirths or 0
	return math.floor(R.baseCash * R.growth ^ n), math.floor(R.baseShards * (R.shardGrowth or R.growth) ^ n)
end

--------------------------------------------------------------------
-- Daily quests (calendar window): every UTC day you get 2 easy, 2 medium
-- and 1 hard quest from these lists. Finish (claim) all 5 on 7 days in a
-- row for the big weekly bonus. "stat" is what gets counted.
--------------------------------------------------------------------
Config.DailyQuests = {
	easy = {
		{ id = "roll50", stat = "rolls", target = 50, text = "Roll the dice %d times" },
		{ id = "hatch3", stat = "hatches", target = 3, text = "Hatch %d eggs" },
		{ id = "kill15", stat = "kills", target = 15, text = "Defeat %d enemies" },
		{ id = "sell10", stat = "sells", target = 10, text = "Sell %d eggs or monsters" },
		{ id = "crit10", stat = "crits", target = 10, text = "Land %d critical hits" },
	},
	medium = {
		{ id = "roll250", stat = "rolls", target = 250, text = "Roll the dice %d times" },
		{ id = "hatch10", stat = "hatches", target = 10, text = "Hatch %d eggs" },
		{ id = "kill75", stat = "kills", target = 75, text = "Defeat %d enemies" },
		{ id = "crit50", stat = "crits", target = 50, text = "Land %d critical hits" },
		{ id = "upgrade2", stat = "upgrades", target = 2, text = "Buy %d upgrades" },
		{ id = "potion2", stat = "potions", target = 2, text = "Use %d potions" },
	},
	hard = {
		{ id = "roll750", stat = "rolls", target = 750, text = "Roll the dice %d times" },
		{ id = "kill250", stat = "kills", target = 250, text = "Defeat %d enemies" },
		{ id = "hatch25", stat = "hatches", target = 25, text = "Hatch %d eggs" },
		{ id = "crit200", stat = "crits", target = 200, text = "Land %d critical hits" },
	},
}
Config.DailyQuestOrder = { "easy", "easy", "medium", "medium", "hard" }
Config.DailyQuestRewards = {
	easy = { shards = 20 },
	medium = { shards = 50, potions = { luck = 1 } },
	hard = { shards = 150, potions = { luck = 1, cash = 1 } },
}
Config.DailyQuestWeekBonus = {
	shards = 1500,
	potions = { revive = 3, luck = 3, cash = 3, damage = 2, health = 2, level = 2 },
	items = { warpRemote = 5 },
	gears = { reviveFeather = 3 },
}

-- 7-day streak (miss a day and it starts over at day 1)
Config.DailyRewards = {
	{ cash = 5000 },
	{ shards = 25 },
	{ potions = { luck = 1 } },
	{ cash = 50000 },
	{ potions = { cash = 1 }, shards = 50 },
	{ items = { warpRemote = 2 } },
	{ potions = { revive = 1 }, shards = 200, cash = 250000 },
}

--------------------------------------------------------------------
-- Play-time milestones (per session: they start over when you rejoin).
-- Only time you're active counts: no input / movement for afkAfter
-- seconds pauses the timer until you're back.
--   cashPct = % of the cash needed for your next rebirth
--   egg = a random egg of at least that rarity
--------------------------------------------------------------------
Config.Playtime = {
	afkAfter = 300, -- 5 min
	milestones = {
		{ minutes = 30, cashPct = 5, potions = { luck = 1 } },
		{ minutes = 60, egg = "Rare", shards = 50 },
		{ minutes = 90, cashPct = 10, potions = { damage = 1, health = 1 } },
		{ minutes = 120, egg = "Epic", potions = { luck = 2 } },
		{ minutes = 180, shards = 200, potions = { cash = 2 } },
		{ minutes = 240, egg = "Legendary" },
		{ minutes = 300, cashPct = 25, potions = { luck = 2, level = 2 } },
		{ minutes = 360, egg = "Legendary", shards = 400 },
		{ minutes = 480, egg = "Mythic", shards = 1000, potions = { luck = 3 } },
	},
}

-- Combat setting: "menu" (tap opens the attack window), "quick" (tap
-- sends all your pets), "auto" (pets attack the nearest enemy on their
-- own; unlocked at autoRebirths)
Config.CombatModes = {
	order = { "menu", "quick", "auto" },
	names = { menu = "MENU", quick = "QUICK", auto = "AUTO" },
	default = "quick",
	autoRebirths = 3,
}

--------------------------------------------------------------------
-- Combat. Pets that follow you fight enemies near you automatically.
-- Enemy HP = 110-120% of a same-level pet, enemy damage = 90%.
--------------------------------------------------------------------
-- Loot on the ground (Rift Shards / potions from enemies): it flies out
-- of the enemy and lands around it; walk within pickupRange studs and it
-- flies into your backpack. Gone after lifetime seconds.
Config.Loot = {
	lifetime = 90,
	pickupRange = 8,
	pickupCheck = 40, -- server: max distance from where the enemy died
}

Config.Combat = {
	petBaseHealth = 100,
	petHealthPerLevel = 0.15, -- +15% per level
	petBaseDamage = 10,
	petDamagePerLevel = 0.12, -- +12% per level
	enemyHealthMin = 2.5, -- (buffed a little: was 2.2 - 2.6 HP, 1.1 damage)
	enemyHealthMax = 2.95,
	enemyDamage = 1.25,
	enemyLevelScaling = 0.08, -- extra enemy HP per level (half of it for damage)
	reviveBase = 60, -- defeated pets recover on their own: 60s + 30s per pet level (max 30 min)
	revivePerLevel = 30,
	reviveMax = 1800,
	petAttackInterval = 1.0,
	enemyAttackInterval = 1.2,
	critChance = 5, -- % chance every monster hit is a critical hit
	critMultiplier = 1.5, -- critical hits do this much damage
	aggroRange = 24, -- "tap an enemy to attack" hint shows when you're this close to one
	orderRange = 35, -- you must be this close to an enemy to tap it and send your pets
	leashRange = 80, -- walk further than this from the enemy and your pets come back
	rangedExtra = 6, -- ranged pets (Config.RangedPets) fight this much further back; enemies still reach them
	regenDelay = 5, -- seconds out of combat before pets heal
	regenPerSecond = 0.05, -- 5% of max health per second
	xpBase = 25,
	xpExponent = 1.35,
	maxLevel = 100,
	respawnTime = 10,
	shardChance = 0.35,
	potionChance = 0.04,
	warpRemoteChance = 0, -- Warp Remotes are sold in the Gear Shop now (not dropped)
	-- (Gift Cards are sold in the Gear Shop now, Rebirth 3+, not dropped)
	potionWeights = { luck = 25, health = 20, damage = 20, cash = 20, level = 13, revive = 8 }, -- revive: ~1 in 330 kills
}
Config.RarityPower = { 1, 1.2, 1.45, 1.75, 2.1, 2.5 }
Config.PetSizePower = { Normal = 1, Big = 1.15, Huge = 1.3, Titan = 1.7, Gigantic = 2.1 }
Config.PetFinishPower = { Normal = 1, Gold = 1.15, Silver = 1.25, Diamond = 1.35, Rainbow = 1.5, Galaxy = 1.8 }

-- special enemies: much tougher, more XP and loot (mult applies to all)
-- pets that attack from a little further away (fire / breath attacks)
Config.RangedPets = { phoenix = true, ["void-dragon"] = true }

Config.EnemySizes = {
	{ key = "Titanic", chance = 0.01, mult = 5, scale = 2.3 },
	{ key = "Huge", chance = 0.05, mult = 2.5, scale = 1.6 },
	{ key = "Big", chance = 0.15, mult = 1.5, scale = 1.25 },
}
Config.EnemyFinishes = {
	{ key = "Rainbow", chance = 0.005, mult = 3 },
	{ key = "Gold", chance = 0.03, mult = 1.8 },
	{ key = "Silver", chance = 0.08, mult = 1.3 },
}
-- per biome: level range, how many at once, which monsters
Config.EnemySpawns = {
	forest = { min = 1, max = 5, count = 18, monsters = { "slime", "bat", "mushroom" } },
	desert = { min = 6, max = 10, count = 18, monsters = { "crab", "bat", "wolf" } },
	volcanic = { min = 11, max = 15, count = 18, monsters = { "golem", "phoenix", "wolf" } },
	tundra = { min = 16, max = 20, count = 18, monsters = { "wolf", "golem", "crab" } },
	candy = { min = 21, max = 25, count = 18, monsters = { "slime", "mushroom", "phoenix" } },
	atlantis = { min = 26, max = 30, count = 18, monsters = { "leviathan", "crab", "void-dragon" } },
}

function Config.GetReviveTime(level)
	local C = Config.Combat
	return math.min(C.reviveMax, C.reviveBase + C.revivePerLevel * math.max(1, level or 1))
end

function Config.XpForLevel(level)
	return math.floor(40 * level ^ 1.6)
end

function Config.EnemyXp(level, mult)
	return math.floor(Config.Combat.xpBase * level ^ Config.Combat.xpExponent * (mult or 1))
end

function Config.IsBoostActive(profile, key, now)
	return profile ~= nil and profile.activeBoosts ~= nil and (profile.activeBoosts[key] or 0) > (now or os.time())
end

-- Server-wide effects the Dev starts from the admin panel (every server,
-- every player): 1x-8x, for a set time. The server keeps them as
-- attributes on ReplicatedStorage.MonsterRNG (GB_<key>_m = multiplier,
-- GB_<key>_e = end time), so the client sees them too.
-- imageId = the icon shown on screen while the effect is on. Put your
-- own image id here, e.g. imageId = "rbxassetid://1234567890"
Config.GlobalBoostKinds = {
	{ key = "luck", name = "Luck", imageId = "", color = { 80, 220, 110 }, text = "Better rolls for everyone" },
	{ key = "damage", name = "Damage", imageId = "", color = { 255, 90, 80 }, text = "Monsters hit harder" },
	{ key = "health", name = "Health", imageId = "", color = { 255, 110, 170 }, text = "Monsters have more health" },
	{ key = "income", name = "Income", imageId = "", color = { 255, 205, 60 }, text = "More cash from your monsters" },
	{ key = "exp", name = "EXP", imageId = "", color = { 110, 170, 255 }, text = "More EXP from enemies" },
	{ key = "speed", name = "Speed", imageId = "", color = { 90, 230, 230 }, text = "Everyone runs faster" },
	{ key = "drops", name = "Drops", imageId = "", color = { 190, 130, 255 }, text = "More drops from enemies" },
}
Config.GlobalSpeedCap = 3 -- walking faster than 3x breaks the map, so the speed effect stops there
Config.GlobalBoostMax = 16
function Config.GlobalBoost(key, now)
	local holder = game:GetService("ReplicatedStorage"):FindFirstChild("MonsterRNG")
	if not holder then
		return 1
	end
	local m, e = holder:GetAttribute("GB_" .. key .. "_m"), holder:GetAttribute("GB_" .. key .. "_e")
	if type(m) == "number" and type(e) == "number" and e > (now or os.time()) then
		return math.clamp(m, 1, Config.GlobalBoostMax)
	end
	return 1
end

-- a same-level baseline (Common, Normal, no upgrades)
function Config.BaseCombatStats(level)
	local C = Config.Combat
	local l = math.max(1, level or 1)
	return C.petBaseHealth * (1 + C.petHealthPerLevel * (l - 1)), C.petBaseDamage * (1 + C.petDamagePerLevel * (l - 1))
end

-- max health + damage of one pet, including upgrades and active potions
function Config.GetPetStats(entry, profile, now)
	local monster = Config.GetMonster(entry.monsterId)
	local tier = monster and Config.GetRarity(monster.rarity).tier or 1
	local power = (Config.RarityPower[tier] or 1) * (Config.PetSizePower[entry.size] or 1) * (Config.PetFinishPower[entry.finish] or 1) * Config.GradeMultiplier(entry.grade)
	local hp, dmg = Config.BaseCombatStats(entry.level)
	local upgrades = profile and profile.upgrades
	hp *= power * (1 + (Config.GetUpgradeBonus(upgrades, "health") + Config.Skill(profile, "health")) / 100)
	dmg *= power * (1 + Config.GetUpgradeBonus(upgrades, "damage") / 100) * Config.SkillDamageMultiplier(profile, now)
	if Config.IsBoostActive(profile, "health", now) then
		hp *= 1.5
	end
	if Config.IsBoostActive(profile, "damage", now) then
		dmg *= 1.5
	end
	hp *= Config.GlobalBoost("health", now)
	dmg *= Config.GlobalBoost("damage", now)
	return math.floor(hp), math.floor(dmg)
end

-- Gifting (needs a Gift Card). Not a trade: one player gives, the other
-- accepts. Both players need Rebirth 3+ and a 30+ day old account, and
-- must be in the same server.
Config.Gifting = {
	minRebirth = 3,
	minAccountAge = 30, -- days
	giftsPerDay = 3, -- per sender, per UTC day
	maxItemsPerGift = 5, -- pets + eggs + potions + items
	cashShare = 0.5, -- max cash = 50% of the receiver's current rebirth cost
	offerSeconds = 60, -- time the receiver has to accept
}

--------------------------------------------------------------------
-- Gear Shop (Kurt). Every GearRestockSeconds each player gets a new
-- stock: each gear is rolled with its chance; every hit rolls again for
-- one more (same chance), up to GearMaxStock of each.
-- Bought with Cash: cashPct = % of the cash for your next rebirth, so
-- prices grow as you rebirth. Goes to the backpack (ITEMS) to use later.
--------------------------------------------------------------------
Config.GearRestockSeconds = 300
Config.GearMaxStock = 5
Config.Gears = {
	{ key = "speedBoots", name = "Speed Boots", imageId = "rbxassetid://117951493575646", cashPct = 2, chance = 0.5, duration = 180, boost = true, color = { 90, 200, 255 }, text = "+40% walk speed for 3 min" },
	{ key = "tauntTotem", name = "Taunt Totem", imageId = "rbxassetid://85760759986031", cashPct = 4.5, chance = 0.3, duration = 30, color = { 235, 90, 70 }, text = "Enemies attack it instead of your pets (30s)" },
	{ key = "healingSpring", name = "Healing Spring", imageId = "rbxassetid://131193150650112", cashPct = 3.5, chance = 0.2, duration = 60, color = { 80, 220, 160 }, text = "Your pets near it heal fast (60s)" },
	{ key = "campfire", name = "Campfire", imageId = "rbxassetid://115564759046466", cashPct = 6, chance = 0.05, duration = 300, boost = true, color = { 255, 150, 50 }, text = "Defeated pets recover 2x faster (5 min)" },
	{ key = "warpRemote", name = "Warp Remote", imageId = "rbxassetid://80619965977171", cashPct = 0.75, chance = 0.75, item = true, color = { 120, 190, 255 }, text = "Warp to any biome you unlocked (WARP menu)" },
	{ key = "giftCard", name = "Gift Card", imageId = Config.Items.giftCard.imageId, cashPct = 20, chance = 0.03, item = true, minRebirth = 3, color = { 255, 120, 200 }, text = "Gift pets / items to a player (Rebirth 3+)" },
	{ key = "reviveFeather", name = "Revive Feather", imageId = "rbxassetid://112794123950752", cashPct = 9, chance = 0.04, color = { 255, 215, 90 }, text = "Instantly revives one defeated pet" },
}
-- a gear's price in cash for this player (rounded to 2 digits)
function Config.GearPrice(profile, gear)
	local cost = Config.GetRebirthCost(profile and profile.rebirths or 0)
	local v = math.max(1000, cost * (gear.cashPct or 1) / 100)
	local mag = 10 ^ math.max(0, math.floor(math.log10(v)) - 1)
	return math.floor(v / mag + 0.5) * mag
end
function Config.GetGear(key)
	for _, g in ipairs(Config.Gears) do
		if g.key == key then
			return g
		end
	end
	return nil
end

-- every biome you've unlocked: +5% roll luck and +10% enemy drop chance
Config.BiomeBonus = { luck = 5, drops = 10 }
function Config.GetBiomeBonusCount(profile)
	local n = 0
	for key, on in pairs((profile and profile.unlockedBiomes) or {}) do
		if on and key ~= "home" then
			n += 1
		end
	end
	return n
end

function Config.BuildDisplayName(monsterName, sizeKey, finishKey)
	local parts = {}
	if sizeKey and sizeKey ~= "Normal" then
		table.insert(parts, sizeKey)
	end
	if finishKey and finishKey ~= "Normal" then
		table.insert(parts, finishKey)
	end
	table.insert(parts, monsterName)
	return table.concat(parts, " ")
end

--------------------------------------------------------------------
-- PvP (from the PVP button). Post a challenge, anyone in ANY server can
-- take it; the teams (monsters in your pen) fight in the arena.
-- Credits only show in the PvP window. Seasons are one calendar month.
--------------------------------------------------------------------
Config.Pvp = {
	postMinutes = 30, -- a challenge post stays up this long
	maxTeam = 6, -- strongest monsters in your pen that fight
	winCredits = 25, -- you took a challenge and won
	lossCredits = 5,
	defendWinCredits = 15, -- your post was taken and your team won
	defendLossCredits = 3,
	winPoints = 25, -- season points (leaderboard)
	lossPoints = 10, -- taken away (never below 0)
	defendWinPoints = 15,
	defendLossPoints = 5,
	cooldown = 10, -- seconds between fights
	-- season rewards (none yet): top 1-3, 4-10, 11-100
	rewardTiers = {
		{ from = 1, to = 3, name = "TOP 3", color = { 255, 205, 60 }, rewards = "Coming soon" },
		{ from = 4, to = 10, name = "TOP 10", color = { 200, 210, 230 }, rewards = "Coming soon" },
		{ from = 11, to = 100, name = "TOP 100", color = { 205, 140, 90 }, rewards = "Coming soon" },
	},
}
-- "2026-09" style key of the current season (UTC month)
function Config.PvpSeason(t)
	local d = DateTime.fromUnixTimestamp(t or os.time()):ToUniversalTime()
	return string.format("%d-%02d", d.Year, d.Month)
end
-- seconds until the season ends
function Config.PvpSeasonLeft(t)
	t = t or os.time()
	local d = DateTime.fromUnixTimestamp(t):ToUniversalTime()
	local y, m = d.Year, d.Month + 1
	if m > 12 then
		y, m = y + 1, 1
	end
	return DateTime.fromUniversalTime(y, m, 1, 0, 0, 0).UnixTimestamp - t
end
-- a team's total power (shown on posts)
function Config.TeamPower(team)
	local p = 0
	for _, m in ipairs(team or {}) do
		p += (m.hp or 0) / 10 + (m.dmg or 0)
	end
	return math.floor(p)
end

--------------------------------------------------------------------
-- Guilds (the Guild stall in town)
--------------------------------------------------------------------
Config.Guild = {
	createProductId = 3715742515, -- developer product to make a guild (0 = free)
	baseMembers = 10,
	slotStep = 5, -- +5 members each time the owner buys more slots
	maxMembers = 50,
	slotProductId = 0, -- developer product for +5 members (0 = not for sale yet)
	nameMin = 3,
	nameMax = 20,
	descMax = 120,
	-- preset emblems: a color + a symbol (or put an image id in the guild settings)
	presets = {
		{ key = "star", symbol = "⭐", color = { 255, 200, 60 } },
		{ key = "crown", symbol = "👑", color = { 255, 150, 40 } },
		{ key = "sword", symbol = "⚔️", color = { 200, 60, 60 } },
		{ key = "skull", symbol = "💀", color = { 80, 80, 100 } },
		{ key = "heart", symbol = "❤️", color = { 240, 80, 140 } },
		{ key = "bolt", symbol = "⚡", color = { 90, 170, 255 } },
		{ key = "moon", symbol = "🌙", color = { 120, 90, 220 } },
		{ key = "fire", symbol = "🔥", color = { 255, 120, 40 } },
		{ key = "dragon", symbol = "🐉", color = { 50, 60, 80 } },
		{ key = "diamond", symbol = "💎", color = { 60, 200, 220 } },
		{ key = "clover", symbol = "🍀", color = { 60, 190, 90 } },
		{ key = "shield", symbol = "🛡️", color = { 150, 100, 60 } },
	},
}
function Config.GuildPreset(key)
	for _, p in ipairs(Config.Guild.presets) do
		if p.key == key then
			return p
		end
	end
	return Config.Guild.presets[1]
end

--------------------------------------------------------------------
-- Graphics quality (Settings > GRAPHICS). Everything that draws the
-- world reads these: monsters (RigSkinner), biomes (BiomeLoader) and
-- effects / lighting (HUD).
--   rigs        = which monster pieces (always the full model: MonsterRigs)
--   monsterCull = monsters further than this are not drawn (nil = never)
--   biomeNear   = biomes show only this close to their edge (nil = always)
--------------------------------------------------------------------
Config.Graphics = {
	order = { "SuperLow", "Low", "Mid", "High", "SuperHigh" },
	tiers = {
		SuperLow = { label = "S.LOW", rigs = "MonsterRigs", monsterCull = 60, biomeNear = 60, particles = 0, lights = false, neon = false, shadows = false, bloom = false, props = false },
		Low = { label = "LOW", rigs = "MonsterRigs", monsterCull = 100, biomeNear = 160, particles = 0.3, lights = false, neon = false, shadows = false, bloom = false, props = false },
		Mid = { label = "MID", rigs = "MonsterRigs", monsterCull = 180, biomeNear = 160, particles = 0.65, lights = true, neon = true, shadows = false, bloom = true, props = true },
		High = { label = "HIGH", rigs = "MonsterRigs", particles = 1, lights = true, neon = true, shadows = true, bloom = true, props = true },
		SuperHigh = { label = "S.HIGH", rigs = "MonsterRigs", particles = 1, lights = true, neon = true, shadows = true, bloom = true, props = true, extra = true },
	},
}
function Config.GraphicsTier(name)
	return Config.Graphics.tiers[name or "High"] or Config.Graphics.tiers.High
end

--------------------------------------------------------------------
-- MONSTER SKILLS: every monster equipped in your pen gives its skill.
-- A skill grows from lv1 (at level 1) to lv100 (at level 100), and is
-- boosted by the monster's size and finish. The same stat from several
-- monsters adds up, up to the stat's max (cap).
--------------------------------------------------------------------
Config.SkillsIconImage = "rbxassetid://89154708883558" -- picture for the SKILLS button (right side, under WARP)
Config.SkillSizeBoost = { Normal = 1, Big = 1.1, Huge = 1.2, Titan = 1.5, Gigantic = 1.8 }
Config.SkillFinishBoost = { Normal = 1, Gold = 1.1, Silver = 1.2, Diamond = 1.25, Rainbow = 1.35, Galaxy = 1.6 }

-- stat -> how it shows + its max. text = what it does (for the list)
Config.SkillStats = {
	jump = { name = "Jump Height", unit = "%", cap = 30 },
	walk = { name = "Walk Speed", unit = "%", cap = 40 },
	shardChance = { name = "Shard Drop Chance", unit = "%", cap = 20 },
	rollSpeed = { name = "Roll Speed", unit = "%", cap = 35 },
	regen = { name = "Pet Healing", unit = "%", cap = 40 },
	luck = { name = "Luck", unit = "", cap = 15 },
	health = { name = "Pet Health", unit = "%", cap = 60 },
	thorns = { name = "Thorns", unit = "%", cap = 30 },
	damage = { name = "Pet Damage", unit = "%", cap = 60 },
	cash = { name = "Cash", unit = "%", cap = 80 },
	critChance = { name = "Crit Chance", unit = "%", cap = 5 },
	critDamage = { name = "Crit Damage", unit = "%", cap = 40 },
	chill = { name = "Enemy Attack Slow", unit = "%", cap = 35 },
	potionDrop = { name = "Potion Drops", unit = "%", cap = 40 },
	revive = { name = "Instant Revive", unit = "%", cap = 30 },
	offline = { name = "Offline Earnings", unit = "%", cap = 50 },
	burn = { name = "Burn Damage", unit = "%", cap = 25 },
	xp = { name = "Pet XP", unit = "%", cap = 60 },
	doubleHit = { name = "Double Hit", unit = "%", cap = 25 },
	armor = { name = "Less Damage Taken", unit = "%", cap = 35 },
	freeze = { name = "Freeze Chance", unit = "%", cap = 20 },
	hatch = { name = "Hatch Speed", unit = "%", cap = 50 },
	shardAmount = { name = "Shards Per Drop", unit = "%", cap = 60 },
	chaos = { name = "Chaos Buff", unit = "s", cap = 90 },
	venom = { name = "Poison", unit = "%/s", cap = 6 },
	doubleLoot = { name = "Double Loot", unit = "%", cap = 30 },
	sell = { name = "Sell Price", unit = "%", cap = 75 },
	glitch = { name = "Double Egg", unit = "%", cap = 10 },
	undying = { name = "Faster Revive", unit = "%", cap = 60 },
	luckMult = { name = "Luck Multiplier", unit = "%", cap = 60 },
	wild = { name = "WILD Chance", unit = "%", cap = 60 },
	mutation = { name = "Mutation + Size", unit = "%", cap = 60 },
	aura = { name = "All Skills", unit = "%", cap = 40 },
	infinity = { name = "Cash, Luck + Damage", unit = "%", cap = 80 },
}

-- monster -> its skill (name, stat, value at level 1 and at level 100)
Config.MonsterSkills = {
	slime = { name = "Bouncy", stat = "jump", lv1 = 2, lv100 = 5, text = "Jump higher" },
	bat = { name = "Night Wings", stat = "walk", lv1 = 2, lv100 = 5, text = "Walk faster" },
	["pebble-pup"] = { name = "Fetch", stat = "shardChance", lv1 = 1, lv100 = 3, text = "More Rift Shard drops" },
	sparkfly = { name = "Static", stat = "rollSpeed", lv1 = 2, lv100 = 5, text = "Roll faster" },
	["leaf-bug"] = { name = "Photosynthesis", stat = "regen", lv1 = 2, lv100 = 6, text = "Pets heal faster" },
	mushroom = { name = "Spore Luck", stat = "luck", lv1 = 1, lv100 = 3, text = "More luck" },
	crab = { name = "Hard Shell", stat = "health", lv1 = 3, lv100 = 8, text = "Pets have more health" },
	["thorn-hog"] = { name = "Thorns", stat = "thorns", lv1 = 3, lv100 = 8, text = "Hits your pets take are hit back" },
	["cinder-imp"] = { name = "Kindling", stat = "damage", lv1 = 3, lv100 = 8, text = "Pets deal more damage" },
	["candy-puff"] = { name = "Sugar Rush", stat = "cash", lv1 = 3, lv100 = 8, text = "More cash per second" },
	wolf = { name = "Swift Paws", stat = "walk", lv1 = 5, lv100 = 10, text = "Walk faster" },
	golem = { name = "Rune Armor", stat = "health", lv1 = 5, lv100 = 12, text = "Pets have more health" },
	["flame-fox"] = { name = "Fox Fire", stat = "critChance", lv1 = 0.5, lv100 = 1.5, text = "More critical hits" },
	["frost-yeti"] = { name = "Chill", stat = "chill", lv1 = 5, lv100 = 12, text = "The enemy you fight attacks slower" },
	["jade-serpent"] = { name = "Jade Fortune", stat = "potionDrop", lv1 = 4, lv100 = 10, text = "More potion drops" },
	phoenix = { name = "Rebirth Flame", stat = "revive", lv1 = 5, lv100 = 12, text = "Chance a defeated pet revives right away" },
	["thunder-lion"] = { name = "Roar", stat = "critDamage", lv1 = 5, lv100 = 12, text = "Critical hits hit harder" },
	["abyss-eel"] = { name = "Deep Pockets", stat = "offline", lv1 = 5, lv100 = 15, text = "More offline earnings" },
	["inferno-bat"] = { name = "Burn", stat = "burn", lv1 = 3, lv100 = 8, text = "Your hits make the enemy burn" },
	["ghost-lantern"] = { name = "Spirit Light", stat = "xp", lv1 = 5, lv100 = 15, text = "Pets get more XP" },
	leviathan = { name = "Double Wave", stat = "doubleHit", lv1 = 3, lv100 = 8, text = "Chance an attack hits twice" },
	["solar-griffin"] = { name = "Sky Luck", stat = "luck", lv1 = 3, lv100 = 8, text = "More luck" },
	["obsidian-behemoth"] = { name = "Unbreakable", stat = "armor", lv1 = 5, lv100 = 12, text = "Pets take less damage" },
	["frost-wyrm"] = { name = "Freeze", stat = "freeze", lv1 = 3, lv100 = 7, text = "Chance to freeze the enemy for 2s" },
	["thunder-djinn"] = { name = "Wish", stat = "hatch", lv1 = 5, lv100 = 15, text = "Eggs hatch faster" },
	["void-dragon"] = { name = "Void Rift", stat = "shardAmount", lv1 = 8, lv100 = 20, text = "More Rift Shards per drop" },
	["chaos-chimera"] = { name = "Chaos", stat = "chaos", lv1 = 30, lv100 = 60, text = "Every 5 min: x2 cash, luck or damage for a while" },
	["iron-colossus"] = { name = "Overdrive", stat = "damage", lv1 = 8, lv100 = 20, text = "Pets deal more damage" },
	["plague-wyvern"] = { name = "Venom Bite", stat = "venom", lv1 = 1, lv100 = 3, text = "Hits poison the enemy (max HP per second, 3s)" },
	wraith = { name = "Soul Harvest", stat = "doubleLoot", lv1 = 5, lv100 = 12, text = "Chance a kill drops double loot" },
	["hollow-king"] = { name = "Royal Tax", stat = "sell", lv1 = 10, lv100 = 25, text = "Sell for more" },
	["glitch-beast"] = { name = "Glitch", stat = "glitch", lv1 = 1, lv100 = 3, text = "Chance a roll gives 2 eggs" },
	["bone-dragon"] = { name = "Undying", stat = "undying", lv1 = 15, lv100 = 35, text = "Defeated pets come back faster" },
	seraph = { name = "Blessing", stat = "luckMult", lv1 = 10, lv100 = 25, text = "Multiplies your luck" },
	["astral-whale"] = { name = "Star Tide", stat = "wild", lv1 = 10, lv100 = 25, text = "More WILD rolls" },
	["comet-pegasus"] = { name = "Comet Speed", stat = "rollSpeed", lv1 = 10, lv100 = 20, text = "Roll faster" },
	titan = { name = "Solar Core", stat = "cash", lv1 = 15, lv100 = 35, text = "More cash per second" },
	["radiant-archangel"] = { name = "Guardian", stat = "block", lv1 = 10, lv100 = 20, text = "Chance a pet blocks a hit" },
	["gaia-colossus"] = { name = "Nature's Gift", stat = "mutation", lv1 = 10, lv100 = 25, text = "More mutations and bigger sizes" },
	emperor = { name = "Emperor's Aura", stat = "aura", lv1 = 10, lv100 = 25, text = "All your other skills are stronger" },
	["infinity-dragon"] = { name = "Infinity", stat = "infinity", lv1 = 20, lv100 = 40, text = "More cash, luck and pet damage" },
}
Config.SkillStats.block = { name = "Block Chance", unit = "%", cap = 30 }

-- this monster's skill and how strong it is right now
function Config.GetEntrySkill(entry)
	local sk = entry and Config.MonsterSkills[entry.monsterId]
	if not sk then
		return nil, 0
	end
	local lvl = math.clamp(entry.level or 1, 1, 100)
	local v = sk.lv1 + (sk.lv100 - sk.lv1) * (lvl - 1) / 99
	v *= (Config.SkillSizeBoost[entry.size] or 1) * (Config.SkillFinishBoost[entry.finish] or 1)
	return sk, v
end

-- "+3.2% Jump Height" style text
function Config.FormatSkill(stat, v)
	local info = Config.SkillStats[stat] or { name = stat, unit = "" }
	local num = v >= 10 and string.format("%.0f", v) or string.format("%.1f", v)
	num = num:gsub("%.0$", "")
	if info.unit == "s" then
		return num .. "s " .. info.name
	end
	return "+" .. num .. info.unit .. " " .. info.name
end

-- totals of every equipped (pen) monster's skill, each capped at its max.
-- returns totals (capped), raw (before the cap). Cached for a moment.
local skillCache = setmetatable({}, { __mode = "k" })
function Config.GetSkillTotals(profile)
	if type(profile) ~= "table" then
		return {}, {}
	end
	local c = skillCache[profile]
	local now = os.clock()
	if c and now - c.at < 0.5 then
		return c.totals, c.raw
	end
	local raw = {}
	for _, entry in ipairs(profile.base or {}) do
		if entry.kind == "monster" then
			local sk, v = Config.GetEntrySkill(entry)
			if sk then
				raw[sk.stat] = (raw[sk.stat] or 0) + v
			end
		end
	end
	local auraCap = Config.SkillStats.aura.cap
	local aura = math.min(auraCap, raw.aura or 0)
	local totals = {}
	for stat, v in pairs(raw) do
		local cap = (Config.SkillStats[stat] or {}).cap or math.huge
		local boosted = stat == "aura" and v or v * (1 + aura / 100)
		raw[stat] = boosted
		totals[stat] = math.min(cap, boosted)
	end
	skillCache[profile] = { at = now, totals = totals, raw = raw }
	return totals, raw
end

-- one stat's total (0 if none)
function Config.Skill(profile, stat)
	local totals = Config.GetSkillTotals(profile)
	return totals[stat] or 0
end

-- Chaos: every 5 minutes, x2 cash, luck or damage for its seconds
Config.ChaosKinds = { "cash", "luck", "damage" }
function Config.ChaosBuff(profile, now)
	local secs = Config.Skill(profile, "chaos")
	if secs <= 0 then
		return nil
	end
	now = now or os.time()
	if now % 300 >= secs then
		return nil
	end
	return Config.ChaosKinds[(math.floor(now / 300) % #Config.ChaosKinds) + 1]
end

-- multipliers used around the game
function Config.SkillCashMultiplier(profile, now)
	local m = 1 + (Config.Skill(profile, "cash") + Config.Skill(profile, "infinity")) / 100
	if Config.ChaosBuff(profile, now) == "cash" then
		m *= 2
	end
	return m
end
function Config.SkillDamageMultiplier(profile, now)
	local m = 1 + (Config.Skill(profile, "damage") + Config.Skill(profile, "infinity")) / 100
	if Config.ChaosBuff(profile, now) == "damage" then
		m *= 2
	end
	return m
end
function Config.SkillLuckMultiplier(profile, now)
	local m = 1 + (Config.Skill(profile, "luckMult") + Config.Skill(profile, "infinity")) / 100
	if Config.ChaosBuff(profile, now) == "luck" then
		m *= 2
	end
	return m
end

return Config
