-- All of the game's numbers live here. Change them to rebalance the game.
-- This is a ModuleScript, so both the server and the client can read it.

local Config = {}

-- Where player saves are stored. Changing this name starts everyone over from scratch.
Config.DataStoreName = "SkibidiSimulator_v1"
Config.AutosaveSeconds = 60

-- Shortest time allowed between plunger clicks, in seconds (stops auto-clicker spam).
Config.ClickCooldown = 0.1

-- How many coins one Flush sells for.
Config.CoinsPerFlush = 1

-- What a brand-new player starts with. (A function, so every player gets their own pet list.)
function Config.newPlayerData()
	return {
		Coins = 0,
		Flushes = 0,
		Rebirths = 0,
		PlungerLevel = 1,
		TankLevel = 1,
		Pets = {}, -- each pet is { Name = "Cameraman", Equipped = true }
		SewerUnlocked = false,
	}
end

-- Plungers: how many Flushes each click gives. Color is the plunger cup (and its name in the shop).
Config.Plungers = {
	{ Name = "Wooden Plunger", Power = 1, Price = 0, Color = Color3.fromRGB(190, 120, 70) },
	{ Name = "Rubber Plunger", Power = 3, Price = 100, Color = Color3.fromRGB(230, 60, 60) },
	{ Name = "Golden Plunger", Power = 8, Price = 750, Color = Color3.fromRGB(255, 200, 40) },
	{ Name = "Diamond Plunger", Power = 20, Price = 5_000, Color = Color3.fromRGB(90, 220, 255) },
	{ Name = "Skibidi Plunger", Power = 60, Price = 40_000, Color = Color3.fromRGB(180, 90, 255) },
	{ Name = "Titan Plunger", Power = 200, Price = 300_000, Color = Color3.fromRGB(255, 130, 30) },
}

-- Tanks: the most Flushes you can carry before you have to go sell.
Config.Tanks = {
	{ Name = "Tiny Tank", Capacity = 20, Price = 0 },
	{ Name = "Small Tank", Capacity = 60, Price = 50 },
	{ Name = "Big Tank", Capacity = 200, Price = 400 },
	{ Name = "Huge Tank", Capacity = 750, Price = 3_000 },
	{ Name = "Mega Tank", Capacity = 2_500, Price = 25_000 },
	{ Name = "Skibidi Tank", Capacity = 10_000, Price = 200_000 },
}

-- Rebirthing resets your coins, plungers and tanks, but every rebirth
-- permanently multiplies the Flushes you get per click.
Config.RebirthBonus = 1 -- 0 rebirths = 1x, 1 rebirth = 2x, 2 rebirths = 3x, ...
Config.RebirthBaseCost = 50_000
Config.RebirthCostGrowth = 3 -- each rebirth costs this many times more than the last one

function Config.getMultiplier(rebirths: number): number
	return 1 + rebirths * Config.RebirthBonus
end

function Config.getRebirthCost(rebirths: number): number
	return math.floor(Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths)
end

-- Pets follow you around and boost your Flushes. Boosts from equipped pets add up:
-- a Boost of 0.5 means +50% Flushes per click. Pets are kept when you rebirth.
Config.MaxEquippedPets = 3
Config.MaxPets = 50

Config.Rarities = {
	Common = Color3.fromRGB(200, 200, 205),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
}

-- Scale makes a pet bigger or smaller than normal.
Config.Pets = {
	["Rubber Ducky"] = { Rarity = "Common", Boost = 0.1, Icon = "🦆" },
	["Soap Bunny"] = { Rarity = "Common", Boost = 0.15, Icon = "🐰" },
	["Plunger Pup"] = { Rarity = "Rare", Boost = 0.3, Icon = "🐶" },
	["Sewer Rat"] = { Rarity = "Rare", Boost = 0.4, Icon = "🐀" },
	["Cameraman"] = { Rarity = "Epic", Boost = 0.75, Icon = "📷" },
	["Speakerman"] = { Rarity = "Epic", Boost = 1, Icon = "🔊" },
	["TV Man"] = { Rarity = "Legendary", Boost = 2, Icon = "📺" },
	["Titan Cameraman"] = { Rarity = "Legendary", Boost = 4, Icon = "🎥", Scale = 1.5 },
}

-- Eggs, in the order they sit in the Egg Hatchery. Each egg's chances add up to 100.
Config.Eggs = {
	{
		Name = "Common Egg",
		Price = 2_500,
		Color = Color3.fromRGB(235, 232, 220),
		Pets = {
			{ Pet = "Rubber Ducky", Chance = 50 },
			{ Pet = "Soap Bunny", Chance = 35 },
			{ Pet = "Plunger Pup", Chance = 13 },
			{ Pet = "Cameraman", Chance = 2 },
		},
	},
	{
		Name = "Rare Egg",
		Price = 5_000,
		Color = Color3.fromRGB(80, 160, 255),
		Pets = {
			{ Pet = "Soap Bunny", Chance = 35 },
			{ Pet = "Plunger Pup", Chance = 35 },
			{ Pet = "Sewer Rat", Chance = 25 },
			{ Pet = "Speakerman", Chance = 5 },
		},
	},
	{
		Name = "Epic Egg",
		Price = 10_000,
		Color = Color3.fromRGB(180, 90, 255),
		Pets = {
			{ Pet = "Sewer Rat", Chance = 40 },
			{ Pet = "Cameraman", Chance = 35 },
			{ Pet = "Speakerman", Chance = 20 },
			{ Pet = "TV Man", Chance = 5 },
		},
	},
	{
		Name = "Legendary Egg",
		Price = 20_000,
		Color = Color3.fromRGB(255, 195, 50),
		Pets = {
			{ Pet = "Cameraman", Chance = 40 },
			{ Pet = "Speakerman", Chance = 30 },
			{ Pet = "TV Man", Chance = 25 },
			{ Pet = "Titan Cameraman", Chance = 5 },
		},
	},
}

function Config.getEgg(name: string)
	for _, egg in Config.Eggs do
		if egg.Name == name then
			return egg
		end
	end
	return nil
end

-- 1 plus the boosts of every equipped pet.
function Config.getPetMultiplier(pets: { any }): number
	local total = 1
	for _, pet in pets do
		local info = Config.Pets[pet.Name]
		if pet.Equipped and info then
			total += info.Boost
		end
	end
	return total
end

-- The Sewers: a second area under the map. Unlocking it costs coins once, and
-- every click down there gives extra Flushes.
Config.SewerUnlockPrice = 25_000
Config.SewerMultiplier = 2
Config.SewerDepth = -300 -- height of the sewer floor

return Config
