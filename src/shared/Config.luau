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

-- What a brand-new player starts with.
Config.StartingData = {
	Coins = 0,
	Flushes = 0,
	Rebirths = 0,
	PlungerLevel = 1,
	TankLevel = 1,
}

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

return Config
