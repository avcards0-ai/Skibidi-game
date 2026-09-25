-- Server side of the simulator: loads and saves player data, and handles plunger
-- clicks, selling, the shop, rebirths, egg hatching, pets and the Sewers. Every
-- change to a player's coins happens here, never on the client, so exploiters
-- can't give themselves money.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

print("Skibidi Simulator: GameServer is running")

-- If the game is set up wrong in Studio, show what to fix in big red text on
-- everyone's screen (the Output window is easy to miss), then stop this script.
local function showSetupProblem(message: string): never
	local gui = Instance.new("ScreenGui")
	gui.Name = "SetupProblem"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 80)
	label.Size = UDim2.new(0.8, 0, 0, 120)
	label.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	label.Font = Enum.Font.FredokaOne
	label.Text = "SETUP PROBLEM (server)\n" .. message
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Parent = gui

	gui.Parent = StarterGui -- players who spawn later get it from here
	for _, player in Players:GetPlayers() do
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			gui:Clone().Parent = playerGui
		end
	end
	error("SETUP PROBLEM: " .. message, 0)
end

-- Loads a ModuleScript from ReplicatedStorage > Shared, with a clear message if it's missing or broken.
local function requireShared(name: string)
	local shared = ReplicatedStorage:WaitForChild("Shared", 5)
	if not shared then
		showSetupProblem('Can\'t find a Folder named "Shared" inside ReplicatedStorage.')
	end
	local module = shared:WaitForChild(name, 5)
	if not (module and module:IsA("ModuleScript")) then
		showSetupProblem(('Can\'t find a ModuleScript named "%s" inside ReplicatedStorage > Shared.'):format(name))
	end
	local ok, result = pcall(require, module)
	if not ok then
		showSetupProblem(('The "%s" ModuleScript has an error. Delete its code and paste it in again.'):format(name))
	end
	return result
end

local Config = requireShared("Config")
local Format = requireShared("Format")
if not Config.Pets then
	showSetupProblem('Config is an old version. Paste in the newest Config code (it has pets in it).')
end

-- Saving only works in a published game. To test saving in Studio, turn on
-- Game Settings > Security > "Enable Studio Access to API Services".
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not storeOk then
	warn("DataStores are unavailable, so progress won't save:", store)
	store = nil
end

--------------------------------------------------------------------------------
-- Remotes (how the client talks to the server)
--------------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function makeRemote(className: string, name: string): any
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local buyRemote = makeRemote("RemoteFunction", "BuyItem")
local rebirthRemote = makeRemote("RemoteFunction", "Rebirth")
local petRemote = makeRemote("RemoteFunction", "PetAction")
local notifyRemote = makeRemote("RemoteEvent", "Notify")
local hatchedRemote = makeRemote("RemoteEvent", "Hatched")

remotes.Parent = ReplicatedStorage

--------------------------------------------------------------------------------
-- Player data
--------------------------------------------------------------------------------

-- One entry per player in this server: their saved data plus a few timers.
local profiles = {}

local function notify(player: Player, message: string, success: boolean)
	notifyRemote:FireClient(player, message, success)
end

local function getClickPower(data): number
	local power = Config.Plungers[data.PlungerLevel].Power
		* Config.getMultiplier(data.Rebirths)
		* Config.getPetMultiplier(data.Pets)
	return math.max(1, math.floor(power))
end

local function getCapacity(data): number
	return Config.Tanks[data.TankLevel].Capacity
end

-- Copies a player's data onto their leaderstats and attributes so the UI can show it.
local function updateStats(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = data.Coins
		leaderstats.Rebirths.Value = data.Rebirths
	end

	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Flushes", data.Flushes)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("PlungerLevel", data.PlungerLevel)
	player:SetAttribute("TankLevel", data.TankLevel)
	player:SetAttribute("ClickPower", getClickPower(data))
	player:SetAttribute("Capacity", getCapacity(data))
	player:SetAttribute("PetMultiplier", Config.getPetMultiplier(data.Pets))
	-- Every client reads this to show the pets menu and the pets following each player.
	player:SetAttribute("Pets", HttpService:JSONEncode(data.Pets))
	player:SetAttribute("SewerUnlocked", data.SewerUnlocked)
	player:SetAttribute("Loaded", true)
end

local function dataKey(player: Player): string
	return "Player_" .. player.UserId
end

-- Keeps only real pets, and no more equipped than allowed.
local function cleanPets(saved: any): { any }
	local pets = {}
	local equipped = 0
	if type(saved) ~= "table" then
		return pets
	end
	for _, pet in saved do
		if type(pet) == "table" and Config.Pets[pet.Name] and #pets < Config.MaxPets then
			local isEquipped = pet.Equipped == true and equipped < Config.MaxEquippedPets
			if isEquipped then
				equipped += 1
			end
			table.insert(pets, { Name = pet.Name, Equipped = isEquipped })
		end
	end
	return pets
end

-- Returns the player's data, and whether it's safe to save over their old save.
local function loadData(player: Player)
	local data = Config.newPlayerData()
	if not store then
		return data, false
	end

	-- In Studio, don't make you wait through retries if API access is turned off.
	local attempts = if RunService:IsStudio() then 1 else 3
	for attempt = 1, attempts do
		local ok, saved = pcall(function()
			return store:GetAsync(dataKey(player))
		end)
		if ok then
			if type(saved) == "table" then
				-- Only copy known fields, so new fields get their starting value.
				for key, value in saved do
					if type(value) == type(data[key]) then
						data[key] = value
					end
				end
			end
			-- In case items were removed from Config since this save was made.
			data.PlungerLevel = math.clamp(data.PlungerLevel, 1, #Config.Plungers)
			data.TankLevel = math.clamp(data.TankLevel, 1, #Config.Tanks)
			data.Pets = cleanPets(data.Pets)
			return data, true
		end
		warn(("Loading %s's data failed (attempt %d): %s"):format(player.Name, attempt, tostring(saved)))
		if attempt < attempts then
			task.wait(attempt * 2)
		end
	end

	-- Never save over a player's real data if we couldn't read it.
	return data, false
end

local function saveData(player: Player)
	local profile = profiles[player]
	if not (store and profile and profile.canSave) then
		return
	end

	local data = table.clone(profile.data)
	data.Pets = table.clone(data.Pets)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(dataKey(player), data, { player.UserId })
		end)
		if ok then
			return
		end
		warn(("Saving %s's data failed (attempt %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(1)
	end
end

--------------------------------------------------------------------------------
-- The plunger tool
--------------------------------------------------------------------------------

local function buildPlunger(cupColor: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Plunger"
	tool.ToolTip = "Click to collect Flushes!"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0.8, 0) -- hold it near the top of the stick

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 3, 0.3)
	handle.Color = Color3.fromRGB(150, 100, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local cup = Instance.new("Part")
	cup.Name = "Cup"
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(0.6, 1.3, 1.3)
	cup.Color = cupColor
	cup.Material = Enum.Material.SmoothPlastic
	cup.CanCollide = false
	cup.Massless = true
	cup.Parent = tool

	-- Stick the cup to the bottom of the handle. Cylinders run along X, so turn it upright.
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = cup
	weld.C0 = CFrame.new(0, -1.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	weld.Parent = handle

	return tool
end

local function findPlunger(player: Player): Tool?
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	return (character and character:FindFirstChild("Plunger"))
		or (backpack and backpack:FindFirstChild("Plunger"))
		or nil
end

-- Gives the player a plunger if they're alive and don't have one.
local function ensurePlunger(player: Player)
	local profile = profiles[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (profile and humanoid and humanoid.Health > 0 and backpack) or findPlunger(player) then
		return
	end
	buildPlunger(Config.Plungers[profile.data.PlungerLevel].Color).Parent = backpack
end

-- Makes the plunger cup match the player's current plunger upgrade.
local function paintPlunger(player: Player, tool: Tool?)
	local profile = profiles[player]
	local cup = tool and tool:FindFirstChild("Cup")
	if profile and cup then
		cup.Color = Config.Plungers[profile.data.PlungerLevel].Color
	end
end

local function isInSewer(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root.Position.Y < Config.SewerDepth + 100
end

local function onPlungerClick(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	local now = os.clock()
	if now - profile.lastClick < Config.ClickCooldown then
		return
	end
	profile.lastClick = now

	local data = profile.data
	local capacity = getCapacity(data)
	if data.Flushes >= capacity then
		if now - profile.lastFullWarning > 2 then
			profile.lastFullWarning = now
			notify(player, "Your tank is full! Go sell on the green pad.", false)
		end
		return
	end

	local gain = getClickPower(data)
	if isInSewer(player) then
		gain *= Config.SewerMultiplier
	end
	data.Flushes = math.min(data.Flushes + gain, capacity)
	updateStats(player)
end

-- Tools that we've already hooked up. Weak keys let destroyed tools be cleaned up.
local hookedPlungers = setmetatable({}, { __mode = "k" })

-- Runs whenever something is added to a character, which is what happens when a tool is equipped.
local function onCharacterChildAdded(player: Player, child: Instance)
	if not (child:IsA("Tool") and child.Name == "Plunger") then
		return
	end
	paintPlunger(player, child)
	if hookedPlungers[child] then
		return
	end
	hookedPlungers[child] = true
	child.Activated:Connect(function()
		onPlungerClick(player)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		onCharacterChildAdded(player, child)
	end)
	character:WaitForChild("Humanoid", 10)
	player:WaitForChild("Backpack", 10)
	ensurePlunger(player)
end

--------------------------------------------------------------------------------
-- Selling
--------------------------------------------------------------------------------

local function sell(player: Player)
	local profile = profiles[player]
	if not profile or profile.data.Flushes <= 0 then
		return
	end

	local data = profile.data
	local sold = data.Flushes
	local earned = sold * Config.CoinsPerFlush
	data.Coins += earned
	data.Flushes = 0
	updateStats(player)
	notify(player, ("Sold %s Flushes for %s coins!"):format(Format.number(sold), Format.number(earned)), true)
end

-- Every part named "SellPad" sells your Flushes when you touch it (the map has
-- one up top and one in the Sewers).
local sellPads = {}
local function connectSellPad(pad: Instance)
	if not (pad.Name == "SellPad" and pad:IsA("BasePart")) or sellPads[pad] then
		return
	end
	sellPads[pad] = true
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			sell(player)
		end
	end)
end

workspace.DescendantAdded:Connect(connectSellPad)
for _, descendant in workspace:GetDescendants() do
	connectSellPad(descendant)
end

-- If there's no map with a sell pad after a few seconds, make a simple one.
task.delay(3, function()
	if next(sellPads) then
		return
	end
	local pad = Instance.new("Part")
	pad.Name = "SellPad"
	pad.Anchored = true
	pad.Size = Vector3.new(12, 1, 12)
	pad.Position = Vector3.new(0, 0.5, -25) -- players spawn facing -Z, so this is in front of them
	pad.Color = Color3.fromRGB(60, 220, 90)
	pad.Material = Enum.Material.Neon

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 3) -- in studs
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 150
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "💰 SELL 💰"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	pad.Parent = workspace
end)

--------------------------------------------------------------------------------
-- Shop and rebirths
--------------------------------------------------------------------------------

local SHOP = {
	Plunger = { items = Config.Plungers, levelKey = "PlungerLevel" },
	Tank = { items = Config.Tanks, levelKey = "TankLevel" },
}

buyRemote.OnServerInvoke = function(player: Player, category: any, level: any)
	local profile = profiles[player]
	if not profile then
		return false, "Your data is still loading..."
	end

	local shop = SHOP[category]
	local item = shop and type(level) == "number" and shop.items[level]
	if not item then
		return false, "That item doesn't exist."
	end

	local data = profile.data
	if level <= data[shop.levelKey] then
		return false, "You already have that!"
	end
	if data.Coins < item.Price then
		return false, ("You need %s more coins."):format(Format.number(item.Price - data.Coins))
	end

	data.Coins -= item.Price
	data[shop.levelKey] = level
	updateStats(player)
	if category == "Plunger" then
		paintPlunger(player, findPlunger(player))
	end
	return true, ("You got the %s!"):format(item.Name)
end

rebirthRemote.OnServerInvoke = function(player: Player)
	local profile = profiles[player]
	if not profile then
		return false, "Your data is still loading..."
	end

	local data = profile.data
	local cost = Config.getRebirthCost(data.Rebirths)
	if data.Coins < cost then
		return false, ("You need %s more coins to rebirth."):format(Format.number(cost - data.Coins))
	end

	-- Pets and the Sewers stay unlocked.
	data.Rebirths += 1
	data.Coins = 0
	data.Flushes = 0
	data.PlungerLevel = 1
	data.TankLevel = 1
	updateStats(player)
	paintPlunger(player, findPlunger(player))
	return true, ("Rebirthed! You now get %gx Flushes."):format(Config.getMultiplier(data.Rebirths))
end

--------------------------------------------------------------------------------
-- Eggs and pets
--------------------------------------------------------------------------------

local function countEquipped(pets: { any }): number
	local count = 0
	for _, pet in pets do
		if pet.Equipped then
			count += 1
		end
	end
	return count
end

local petRandom = Random.new()
local function rollPet(egg): string
	local total = 0
	for _, option in egg.Pets do
		total += option.Chance
	end
	local roll = petRandom:NextNumber(0, total)
	for _, option in egg.Pets do
		roll -= option.Chance
		if roll <= 0 then
			return option.Pet
		end
	end
	return egg.Pets[#egg.Pets].Pet
end

local HATCH_SECONDS = 3.5 -- how long the hatching animation takes

local function hatchEgg(player: Player, eggName: string)
	local profile = profiles[player]
	local egg = Config.getEgg(eggName)
	if not (profile and egg) then
		return
	end
	local now = os.clock()
	if now - profile.lastHatch < HATCH_SECONDS then
		return
	end

	local data = profile.data
	if #data.Pets >= Config.MaxPets then
		notify(player, ("Your pet inventory is full (%d)! Delete some pets first."):format(Config.MaxPets), false)
		return
	end
	if data.Coins < egg.Price then
		notify(player, ("You need %s more coins for the %s."):format(Format.number(egg.Price - data.Coins), egg.Name), false)
		return
	end

	profile.lastHatch = now
	data.Coins -= egg.Price
	local petName = rollPet(egg)
	table.insert(data.Pets, { Name = petName, Equipped = countEquipped(data.Pets) < Config.MaxEquippedPets })
	updateStats(player)
	hatchedRemote:FireClient(player, egg.Name, petName)
end

-- The pets menu asks for these: "Equip", "Unequip", "Delete" (with the pet's
-- number and name, so a stale menu can't change the wrong pet), or "EquipBest".
petRemote.OnServerInvoke = function(player: Player, action: any, index: any, petName: any)
	local profile = profiles[player]
	if not profile then
		return false, "Your data is still loading..."
	end
	local pets = profile.data.Pets

	if action == "EquipBest" then
		local order = {}
		for i in pets do
			table.insert(order, i)
		end
		table.sort(order, function(a, b)
			return Config.Pets[pets[a].Name].Boost > Config.Pets[pets[b].Name].Boost
		end)
		for rank, i in order do
			pets[i].Equipped = rank <= Config.MaxEquippedPets
		end
		updateStats(player)
		return true, "Equipped your best pets!"
	end

	local pet = type(index) == "number" and pets[index]
	if not pet or pet.Name ~= petName then
		return false, "That pet isn't there anymore."
	end

	if action == "Equip" then
		if not pet.Equipped and countEquipped(pets) >= Config.MaxEquippedPets then
			return false, ("You can only equip %d pets at once."):format(Config.MaxEquippedPets)
		end
		pet.Equipped = true
		updateStats(player)
		return true, ("Equipped %s!"):format(pet.Name)
	elseif action == "Unequip" then
		pet.Equipped = false
		updateStats(player)
		return true, ("Unequipped %s."):format(pet.Name)
	elseif action == "Delete" then
		table.remove(pets, index)
		updateStats(player)
		return true, ("Deleted %s."):format(pet.Name)
	end
	return false, "That doesn't work."
end

--------------------------------------------------------------------------------
-- The Sewers
--------------------------------------------------------------------------------

-- Moves a player to the part named "SewerArrival" or "SurfaceArrival" in the map.
local function teleport(player: Player, destination: string)
	local profile = profiles[player]
	if not profile then
		return
	end

	local data = profile.data
	if destination == "Sewer" and not data.SewerUnlocked then
		if data.Coins < Config.SewerUnlockPrice then
			notify(
				player,
				("The Sewers cost %s coins to unlock. You need %s more."):format(
					Format.number(Config.SewerUnlockPrice),
					Format.number(Config.SewerUnlockPrice - data.Coins)
				),
				false
			)
			return
		end
		data.Coins -= Config.SewerUnlockPrice
		data.SewerUnlocked = true
		updateStats(player)
	end

	local target = workspace:FindFirstChild(destination .. "Arrival", true)
	local character = player.Character
	if not (target and target:IsA("BasePart") and character) then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(target.Position)
	end)
	character:PivotTo(target.CFrame + Vector3.new(0, 4, 0))
	if destination == "Sewer" then
		notify(player, ("Welcome to the Sewers! Clicks down here give %gx Flushes."):format(Config.SewerMultiplier), true)
	end
end

--------------------------------------------------------------------------------
-- "Press E" prompts in the map: eggs and sewer doors
--------------------------------------------------------------------------------

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local eggName = prompt:GetAttribute("Egg")
	if type(eggName) == "string" then
		hatchEgg(player, eggName)
	end
	local destination = prompt:GetAttribute("TeleportTo")
	if destination == "Sewer" or destination == "Surface" then
		teleport(player, destination)
	end
end)

--------------------------------------------------------------------------------
-- Joining and leaving
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Coins", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	local data, canSave = loadData(player)
	if player.Parent == nil then
		return -- they left while their data was loading
	end

	profiles[player] = {
		data = data,
		canSave = canSave,
		lastClick = 0,
		lastFullWarning = 0,
		lastHatch = 0,
	}
	updateStats(player)

	if store and not canSave then
		notify(player, "Couldn't load your save, so progress won't save this time. Try rejoining!", false)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Catch anyone who joined before this script started (this happens in Studio).
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	profiles[player] = nil
end)

-- Every few seconds, give a plunger to anyone who somehow doesn't have one.
task.spawn(function()
	while true do
		task.wait(3)
		for player in profiles do
			ensurePlunger(player)
		end
	end
end)

-- Save everyone when the server shuts down.
game:BindToClose(function()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			saveData(player)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)

-- Autosave in case the server crashes.
task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		for player in profiles do
			task.spawn(saveData, player)
		end
	end
end)
