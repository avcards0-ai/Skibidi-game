-- Builds the starter map: a sunny grass field with a stone plaza where players spawn.
--
-- Layout (players spawn in the middle of the plaza, facing the title sign):
--   front: the SELL pad with a big sign above it, and the SKIBIDI SIMULATOR sign behind
--   left:  the Plunger Shop                right: the Rebirth shrine
--   back:  a pond with benches
-- Trees, flowers, bushes and lamp posts are scattered around, and grassy hills
-- (made of Terrain) circle the whole area.
--
-- Want to change the map by hand? Press Play, find "Map" in Workspace in the
-- Explorer, right-click > Copy, press Stop, then right-click Workspace > Paste Into.
-- When a Model named "Map" is already in Workspace, this script doesn't build another.

local TweenService = game:GetService("TweenService")

local FLOOR = 0.2 -- height of the top of the grass

local GRASS = Color3.fromRGB(96, 168, 72)
local PATH = Color3.fromRGB(200, 190, 165)
local PATH_EDGE = Color3.fromRGB(140, 135, 125)
local PLAZA = Color3.fromRGB(215, 210, 195)
local STONE = Color3.fromRGB(150, 150, 155)
local MARBLE = Color3.fromRGB(238, 234, 226)
local WOOD = Color3.fromRGB(165, 115, 70)
local WOOD_LIGHT = Color3.fromRGB(200, 160, 110)
local WOOD_DARK = Color3.fromRGB(95, 65, 40)
local ROOF = Color3.fromRGB(185, 65, 55)
local PURPLE = Color3.fromRGB(160, 80, 255)
local GOLD = Color3.fromRGB(255, 205, 60)
local WHITE = Color3.fromRGB(250, 250, 250)
local RED = Color3.fromRGB(230, 60, 60)
local WATER = Color3.fromRGB(70, 160, 230)
local LAMP_GLOW = Color3.fromRGB(255, 220, 150)

local LEAF_COLORS = {
	Color3.fromRGB(70, 150, 60),
	Color3.fromRGB(60, 135, 55),
	Color3.fromRGB(90, 170, 70),
	Color3.fromRGB(55, 125, 65),
}
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(255, 140, 200),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 150, 60),
}

-- Cylinders in Roblox lie along the X axis; this turns them to stand upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- A fixed seed, so trees and flowers land in the same spots every time.
local rng = Random.new(2024)

--------------------------------------------------------------------------------
-- Grassy hills around the edge (Terrain). Skipped if the place already has Terrain.
--------------------------------------------------------------------------------

local terrain = workspace.Terrain
if terrain:CountCells() == 0 then
	terrain:SetMaterialColor(Enum.Material.Grass, GRASS)
	local hillCount = 20
	for i = 1, hillCount do
		local angle = (i / hillCount) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distance = rng:NextNumber(230, 290)
		local radius = rng:NextNumber(40, 70)
		local center = Vector3.new(math.cos(angle) * distance, FLOOR - radius * 0.45, math.sin(angle) * distance)
		terrain:FillBall(center, radius, Enum.Material.Grass)
	end
end

if workspace:FindFirstChild("Map") then
	return -- you've saved your own copy of the map
end

local map = Instance.new("Model")
map.Name = "Map"

--------------------------------------------------------------------------------
-- Building helpers
--------------------------------------------------------------------------------

local function group(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = map
	return model
end

-- Makes an anchored, smooth Part with the given properties.
local function part(props: { [string]: any }): Part
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.Material = Enum.Material.SmoothPlastic
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		newPart[key] = value
	end
	return newPart
end

local function block(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	return part({
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- An upright cylinder whose bottom sits at `bottom`.
local function pillar(parent: Instance, bottom: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function ball(parent: Instance, center: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	return part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- A WedgePart is tallest at its back (+Z) and slopes down to nothing at its front (-Z).
local function wedge(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material): WedgePart
	local newWedge = Instance.new("WedgePart")
	newWedge.Anchored = true
	newWedge.Size = size
	newWedge.CFrame = cframe
	newWedge.Color = color
	newWedge.Material = material
	newWedge.TopSurface = Enum.SurfaceType.Smooth
	newWedge.BottomSurface = Enum.SurfaceType.Smooth
	newWedge.Parent = parent
	return newWedge
end

-- Text floating above a part.
local function floatingLabel(adornee: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(16, 4) -- in studs
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.MaxDistance = 250
	billboard.LightInfluence = 0
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Parent = billboard
end

-- Text painted on one face of a part, like a sign.
local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = target

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
end

-- A "Press E" prompt. GameClient opens the menu named in the OpensMenu attribute.
local function menuPrompt(target: BasePart, menu: string, actionText: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensMenu", menu)
	prompt.Parent = target
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

--------------------------------------------------------------------------------
-- Ground, plaza and paths
--------------------------------------------------------------------------------

local ground = group("Ground")

-- One huge grass part. It sits just above the default Baseplate so it covers it.
block(ground, CFrame.new(0, FLOOR - 1, 0), Vector3.new(2048, 2, 2048), GRASS, Enum.Material.Grass).Name = "Grass"

-- The round stone plaza where players spawn.
pillar(ground, Vector3.new(0, FLOOR - 0.2, 0), 0.5, 44, STONE, Enum.Material.Slate)
pillar(ground, Vector3.new(0, FLOOR - 0.2, 0), 0.6, 40, PLAZA, Enum.Material.Cobblestone)

-- Stone paths from the plaza to the sell pad, shop, rebirth shrine and pond.
for _, path in {
	{ center = Vector3.new(0, 0, -28.5), size = Vector3.new(9, 0, 21) }, -- sell
	{ center = Vector3.new(0, 0, 32), size = Vector3.new(9, 0, 28) }, -- pond
	{ center = Vector3.new(-32, 0, 0), size = Vector3.new(28, 0, 9) }, -- shop
	{ center = Vector3.new(32, 0, 0), size = Vector3.new(28, 0, 9) }, -- rebirth
} do
	local runsAlongZ = path.size.X < path.size.Z
	local edgeSize = if runsAlongZ
		then Vector3.new(path.size.X + 2, 0.4, path.size.Z)
		else Vector3.new(path.size.X, 0.4, path.size.Z + 2)
	block(ground, CFrame.new(path.center + Vector3.new(0, FLOOR - 0.05, 0)), edgeSize, PATH_EDGE, Enum.Material.Slate)
	block(
		ground,
		CFrame.new(path.center + Vector3.new(0, FLOOR + 0.05, 0)),
		Vector3.new(path.size.X, 0.4, path.size.Z),
		PATH,
		Enum.Material.Cobblestone
	)
end

-- Use the place's spawn if it has one, otherwise add one in the middle of the plaza.
if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, FLOOR + 0.9, 0)
	spawn.Color = Color3.fromRGB(60, 140, 230)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = map
end

--------------------------------------------------------------------------------
-- Sell pad with a big sign above it (in front of the spawn)
--------------------------------------------------------------------------------

local sellArea = group("SellArea")
local sellCenter = Vector3.new(0, FLOOR, -48)

pillar(sellArea, sellCenter - Vector3.new(0, 0.2, 0), 0.7, 20, STONE, Enum.Material.Slate)

-- GameServer looks for a part named "SellPad" and sells your Flushes when you touch it.
local sellPad = pillar(sellArea, sellCenter - Vector3.new(0, 0.2, 0), 1, 16, Color3.fromRGB(70, 220, 100), Enum.Material.Neon)
sellPad.Name = "SellPad"

-- An arch over the pad with the SELL sign on it.
for _, side in { -1, 1 } do
	block(sellArea, CFrame.new(sellCenter + Vector3.new(11.5 * side, 7, 0)), Vector3.new(1.8, 14, 1.8), WOOD_DARK, Enum.Material.Wood)
	ball(sellArea, sellCenter + Vector3.new(11.5 * side, 16.2, 0), 2, GOLD, Enum.Material.Foil)
end
block(sellArea, CFrame.new(sellCenter + Vector3.new(0, 14.6, 0)), Vector3.new(27, 1.2, 2), WOOD_DARK, Enum.Material.Wood)
local sellSign = block(sellArea, CFrame.new(sellCenter + Vector3.new(0, 11.5, 0)), Vector3.new(21, 5, 1.2), Color3.fromRGB(40, 120, 60))
surfaceText(sellSign, Enum.NormalId.Back, "💰 SELL 💰", WHITE)
surfaceText(sellSign, Enum.NormalId.Front, "💰 SELL 💰", WHITE)

-- Piles of gold coins beside the pad.
for _, spot in { Vector3.new(-15, 0, 3), Vector3.new(15, 0, 3), Vector3.new(-14.5, 0, -4), Vector3.new(14.5, 0, -4) } do
	for i = 1, rng:NextInteger(4, 8) do
		local jitter = Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		pillar(sellArea, sellCenter + spot + jitter + Vector3.new(0, (i - 1) * 0.45, 0), 0.45, 2.4, GOLD, Enum.Material.Foil)
	end
end

--------------------------------------------------------------------------------
-- Plunger Shop (left of the spawn, facing it)
--------------------------------------------------------------------------------

local shop = group("PlungerShop")
local shopX = -60
local depth, width, wallHeight = 20, 24, 12 -- depth runs along X, width along Z
local floorTop = FLOOR + 0.6
local wallTop = floorTop + wallHeight
local front = shopX + depth / 2

-- Wooden floor with a porch out front.
block(shop, CFrame.new(shopX + 3, FLOOR + 0.3, 0), Vector3.new(depth + 6, 0.6, width + 2), WOOD_LIGHT, Enum.Material.WoodPlanks)

-- Walls: back, two sides, and a front with corner posts and a header beam.
block(shop, CFrame.new(shopX - depth / 2 + 0.5, floorTop + wallHeight / 2, 0), Vector3.new(1, wallHeight, width), WOOD, Enum.Material.WoodPlanks)
for _, side in { -1, 1 } do
	block(
		shop,
		CFrame.new(shopX + 0.5, floorTop + wallHeight / 2, side * (width / 2 - 0.5)),
		Vector3.new(depth - 1, wallHeight, 1),
		WOOD,
		Enum.Material.WoodPlanks
	)
	block(
		shop,
		CFrame.new(front - 0.6, floorTop + wallHeight / 2, side * (width / 2 - 0.6)),
		Vector3.new(1.2, wallHeight, 1.2),
		WOOD_DARK,
		Enum.Material.Wood
	)
end
block(shop, CFrame.new(front - 0.5, wallTop - 1.5, 0), Vector3.new(1, 3, width), WOOD_DARK, Enum.Material.Wood)

-- Sloped roof: two slabs meeting at a ridge, with triangle walls filling each end.
local roofAngle = math.rad(28)
local overhang = 1.5
local rise = (depth / 2) * math.tan(roofAngle)
local ridge = Vector3.new(shopX, wallTop + rise, 0)
local slabLength = (depth / 2 + overhang) / math.cos(roofAngle)
for _, side in { -1, 1 } do
	local downSlope = Vector3.new(side * math.cos(roofAngle), -math.sin(roofAngle), 0)
	block(
		shop,
		CFrame.new(ridge + downSlope * (slabLength / 2) + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, -side * roofAngle),
		Vector3.new(slabLength, 0.8, width + overhang * 2),
		ROOF,
		Enum.Material.Slate
	)
	for _, halfSide in { -1, 1 } do
		-- Each end triangle is two wedges, tallest under the ridge.
		local center = Vector3.new(shopX + halfSide * depth / 4, wallTop + rise / 2, side * (width / 2 - 0.5))
		wedge(
			shop,
			CFrame.fromMatrix(center, Vector3.new(0, 0, halfSide), Vector3.yAxis),
			Vector3.new(1, rise, depth / 2),
			WOOD,
			Enum.Material.WoodPlanks
		)
	end
end
block(shop, CFrame.new(ridge + Vector3.new(0, 0.6, 0)), Vector3.new(1, 1, width + overhang * 2 + 0.4), Color3.fromRGB(140, 45, 40), Enum.Material.Slate)

-- Sign above the counter.
local shopSign = block(shop, CFrame.new(front + 0.3, wallTop - 1.5, 0), Vector3.new(0.6, 2.6, width - 5), Color3.fromRGB(60, 40, 25))
surfaceText(shopSign, Enum.NormalId.Right, "🛒 PLUNGER SHOP", GOLD)

-- The counter you walk up to.
local counter = block(shop, CFrame.new(front - 2, floorTop + 1.8, 0), Vector3.new(2.4, 3.6, width - 6), WOOD, Enum.Material.Wood)
counter.Name = "Counter"
block(shop, CFrame.new(front - 2, floorTop + 3.8, 0), Vector3.new(3, 0.4, width - 5), WOOD_LIGHT, Enum.Material.Wood)
menuPrompt(counter, "Shop", "Open Shop", "Plunger Shop")
floatingLabel(counter, "🛒 SHOP", WHITE, 22)

-- Plungers for sale on the back wall.
for i, color in { RED, GOLD, Color3.fromRGB(90, 220, 255), PURPLE } do
	local z = -7.5 + (i - 1) * 5
	pillar(shop, Vector3.new(shopX - depth / 2 + 2, floorTop + 5, z), 6, 0.5, WOOD, Enum.Material.Wood)
	pillar(shop, Vector3.new(shopX - depth / 2 + 2, floorTop + 4, z), 1, 2.4, color)
end

-- A giant plunger and some crates out front.
pillar(shop, Vector3.new(front + 4, FLOOR, 17.5), 3, 7, RED)
pillar(shop, Vector3.new(front + 4, FLOOR + 3, 17.5), 14, 1.4, WOOD, Enum.Material.Wood)
block(shop, CFrame.new(front + 4, FLOOR + 2, -16), Vector3.new(4, 4, 4), WOOD_LIGHT, Enum.Material.WoodPlanks)
block(shop, CFrame.new(front + 4, FLOOR + 5.5, -16) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(3, 3, 3), WOOD_LIGHT, Enum.Material.WoodPlanks)

--------------------------------------------------------------------------------
-- Rebirth shrine with a floating crystal (right of the spawn)
--------------------------------------------------------------------------------

local rebirthArea = group("RebirthShrine")
local shrineCenter = Vector3.new(60, FLOOR, 0)
local below = Vector3.new(0, 0.2, 0)

-- A stepped marble platform with a glowing purple ring.
pillar(rebirthArea, shrineCenter - below, 1, 28, MARBLE, Enum.Material.Marble)
pillar(rebirthArea, shrineCenter - below, 1.1, 22, PURPLE, Enum.Material.Neon)
pillar(rebirthArea, shrineCenter - below, 1.2, 20, MARBLE, Enum.Material.Marble)

-- Marble columns around the edge.
for i = 1, 6 do
	local angle = (i / 6) * math.pi * 2
	local base = shrineCenter + Vector3.new(math.cos(angle) * 12, 0.8, math.sin(angle) * 12)
	pillar(rebirthArea, base, 12, 2, MARBLE, Enum.Material.Marble)
	pillar(rebirthArea, base + Vector3.new(0, 8, 0), 0.6, 2.3, PURPLE, Enum.Material.Neon)
	block(rebirthArea, CFrame.new(base + Vector3.new(0, 12.4, 0)), Vector3.new(3, 0.8, 3), MARBLE, Enum.Material.Marble)
end

-- The altar in the middle, where the "Press E to Rebirth" prompt is.
local altar = block(rebirthArea, CFrame.new(shrineCenter + Vector3.new(0, 2.5, 0)), Vector3.new(5, 3, 5), MARBLE, Enum.Material.Marble)
altar.Name = "Altar"
block(rebirthArea, CFrame.new(shrineCenter + Vector3.new(0, 4.2, 0)), Vector3.new(5.6, 0.4, 5.6), PURPLE, Enum.Material.Neon)
menuPrompt(altar, "Rebirth", "Rebirth", "Rebirth Shrine")
floatingLabel(altar, "⭐ REBIRTH ⭐", Color3.fromRGB(220, 170, 255), 17)

-- A glowing crystal balanced on one corner. It's welded to an invisible anchor:
-- the anchor bobs up and down, and turning the weld spins the crystal.
local crystalAnchor = part({
	Name = "CrystalAnchor",
	Size = Vector3.one,
	CFrame = CFrame.new(shrineCenter + Vector3.new(0, 10, 0)),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = rebirthArea,
})
local cornerUp = CFrame.fromAxisAngle(Vector3.new(-1, 0, 1).Unit, math.acos(1 / math.sqrt(3)))
local crystal = part({
	Name = "Crystal",
	Size = Vector3.one * 4.5,
	CFrame = crystalAnchor.CFrame * cornerUp,
	Color = PURPLE,
	Material = Enum.Material.Neon,
	Anchored = false,
	CanCollide = false,
	Parent = rebirthArea,
})
local crystalWeld = Instance.new("Weld")
crystalWeld.Part0 = crystalAnchor
crystalWeld.Part1 = crystal
crystalWeld.C0 = cornerUp
crystalWeld.Parent = crystal
Instance.new("Sparkles").Parent = crystal

local crystalLight = Instance.new("PointLight")
crystalLight.Color = PURPLE
crystalLight.Range = 26
crystalLight.Brightness = 3
crystalLight.Parent = crystal

--------------------------------------------------------------------------------
-- Title sign (behind the sell pad, facing the spawn)
--------------------------------------------------------------------------------

local titleArea = group("TitleSign")
local titleZ = -88
-- Tall enough to see over the SELL arch from the spawn.
for _, side in { -1, 1 } do
	block(titleArea, CFrame.new(side * 27, FLOOR + 19, titleZ), Vector3.new(2.2, 38, 2.2), WOOD_DARK, Enum.Material.Wood)
end
for _, y in { 23.4, 36.6 } do
	block(titleArea, CFrame.new(0, FLOOR + y, titleZ), Vector3.new(58, 1.2, 2.2), WOOD_DARK, Enum.Material.Wood)
end
local titleBoard = block(titleArea, CFrame.new(0, FLOOR + 30, titleZ), Vector3.new(52, 12, 1.5), Color3.fromRGB(90, 60, 35), Enum.Material.WoodPlanks)
surfaceText(titleBoard, Enum.NormalId.Back, "🚽 SKIBIDI SIMULATOR 🚽", GOLD)

--------------------------------------------------------------------------------
-- Pond with lily pads and benches (behind the spawn)
--------------------------------------------------------------------------------

local pondArea = group("Pond")
local pondCenter = Vector3.new(0, FLOOR, 62)
local pondRadius = 17

local water = pillar(pondArea, pondCenter - Vector3.new(0, 0.3, 0), 0.4, pondRadius * 2, WATER, Enum.Material.Glass)
water.Name = "Water"
water.Transparency = 0.1
water.Reflectance = 0.25

-- Rocks around the edge, leaving a gap where the path arrives.
local rockCount = 26
for i = 1, rockCount do
	local angle = (i / rockCount) * math.pi * 2
	local spot = pondCenter + Vector3.new(math.cos(angle) * (pondRadius + 0.5), 0.4, math.sin(angle) * (pondRadius + 0.5))
	if math.abs(spot.X) < 5 and spot.Z < pondCenter.Z then
		continue
	end
	local gray = rng:NextInteger(125, 165)
	block(
		pondArea,
		CFrame.new(spot) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
		Vector3.new(rng:NextNumber(2.5, 4), rng:NextNumber(1, 1.8), rng:NextNumber(2, 3)),
		Color3.fromRGB(gray, gray, gray + 5),
		Enum.Material.Slate
	)
end

-- Lily pads, a few with pink flowers.
for i = 1, 6 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(3, pondRadius - 4)
	local spot = pondCenter + Vector3.new(math.cos(angle) * distance, 0.1, math.sin(angle) * distance)
	pillar(pondArea, spot, 0.12, rng:NextNumber(2.5, 3.5), Color3.fromRGB(70, 160, 70))
	if i % 2 == 0 then
		ball(pondArea, spot + Vector3.new(0, 0.4, 0), 0.9, Color3.fromRGB(255, 150, 200))
	end
end

-- Wooden benches looking at the pond.
local function bench(spot: Vector3, lookAt: Vector3)
	local base = CFrame.lookAt(spot, Vector3.new(lookAt.X, spot.Y, lookAt.Z))
	block(pondArea, base * CFrame.new(0, 1.6, 0), Vector3.new(6, 0.4, 2), WOOD, Enum.Material.WoodPlanks)
	block(pondArea, base * CFrame.new(0, 2.9, 0.9), Vector3.new(6, 2, 0.3), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -0.7, 0.7 } do
			block(pondArea, base * CFrame.new(x, 0.7, z), Vector3.new(0.4, 1.4, 0.4), WOOD_DARK, Enum.Material.Wood)
		end
	end
end
bench(pondCenter + Vector3.new(-24, 0, 0), pondCenter)
bench(pondCenter + Vector3.new(24, 0, 0), pondCenter)

--------------------------------------------------------------------------------
-- Lamp posts along the paths
--------------------------------------------------------------------------------

local lamps = group("Lamps")
for _, spot in {
	Vector3.new(-7, 0, -28),
	Vector3.new(7, 0, -28),
	Vector3.new(-7, 0, 30),
	Vector3.new(7, 0, 30),
	Vector3.new(-34, 0, -7),
	Vector3.new(-34, 0, 7),
	Vector3.new(34, 0, -7),
	Vector3.new(34, 0, 7),
} do
	local bottom = spot + Vector3.new(0, FLOOR, 0)
	pillar(lamps, bottom, 9, 0.5, Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	local lantern = block(lamps, CFrame.new(bottom + Vector3.new(0, 9.9, 0)), Vector3.new(1.4, 1.8, 1.4), LAMP_GLOW, Enum.Material.Neon)
	block(lamps, CFrame.new(bottom + Vector3.new(0, 11, 0)), Vector3.new(1.9, 0.4, 1.9), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)

	local light = Instance.new("PointLight")
	light.Color = LAMP_GLOW
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = lantern
end

--------------------------------------------------------------------------------
-- Trees, bushes, flowers and rocks
--------------------------------------------------------------------------------

local nature = group("Nature")

-- Areas to keep clear so nothing grows on the buildings or paths.
local clearings = {
	{ center = Vector3.new(0, 0, 0), radius = 26 }, -- plaza
	{ center = sellCenter, radius = 20 },
	{ center = Vector3.new(-58, 0, 0), radius = 24 }, -- shop
	{ center = shrineCenter, radius = 17 },
	{ center = Vector3.new(0, 0, titleZ), radius = 30 },
	{ center = pondCenter, radius = pondRadius + 4 },
}

local function isClear(spot: Vector3, margin: number): boolean
	local flat = Vector3.new(spot.X, 0, spot.Z)
	for _, clearing in clearings do
		local center = Vector3.new(clearing.center.X, 0, clearing.center.Z)
		if (flat - center).Magnitude < clearing.radius + margin then
			return false
		end
	end
	local onPathToSellOrPond = math.abs(flat.X) < 7 + margin and flat.Z > -40 and flat.Z < 46
	local onPathToShopOrShrine = math.abs(flat.Z) < 7 + margin and flat.X > -48 and flat.X < 48
	return not (onPathToSellOrPond or onPathToShopOrShrine)
end

-- Finds a random clear spot between two distances from the middle.
local function randomSpot(minDistance: number, maxDistance: number, margin: number): Vector3?
	for _ = 1, 50 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(minDistance, maxDistance)
		local spot = Vector3.new(math.cos(angle) * distance, FLOOR, math.sin(angle) * distance)
		if isClear(spot, margin) then
			return spot
		end
	end
	return nil
end

local function tree(spot: Vector3, height: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = nature

	local trunkHeight = height * 0.5
	pillar(model, spot - Vector3.new(0, 0.5, 0), trunkHeight + 0.5, height * 0.12, Color3.fromRGB(110, 75, 45), Enum.Material.Wood)

	local leafSize = height * 0.45
	local leafColor = pick(LEAF_COLORS)
	for _, leaf in {
		{ offset = Vector3.new(0, 0.35, 0), size = 1 },
		{ offset = Vector3.new(0.35, 0.1, 0.2), size = 0.8 },
		{ offset = Vector3.new(-0.3, 0.15, -0.25), size = 0.8 },
		{ offset = Vector3.new(0.05, 0.75, -0.05), size = 0.7 },
	} do
		local center = spot + Vector3.new(0, trunkHeight, 0) + leaf.offset * leafSize
		ball(model, center, leafSize * leaf.size, leafColor:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)), Enum.Material.Grass)
	end

	-- Trees block this spot for other trees.
	table.insert(clearings, { center = spot, radius = 7 })
end

local function bush(spot: Vector3, size: number)
	local color = pick(LEAF_COLORS):Lerp(Color3.new(0, 0, 0), 0.15)
	ball(nature, spot + Vector3.new(0, size * 0.25, 0), size, color, Enum.Material.Grass)
	ball(nature, spot + Vector3.new(size * 0.35, size * 0.15, size * 0.2), size * 0.7, color, Enum.Material.Grass)
end

-- A ring of trees around the play area, then a few closer in.
for _ = 1, 40 do
	local spot = randomSpot(75, 150, 6)
	if spot then
		tree(spot, rng:NextNumber(16, 28))
	end
end
for _ = 1, 12 do
	local spot = randomSpot(35, 75, 6)
	if spot then
		tree(spot, rng:NextNumber(14, 20))
	end
end

-- Bushes around the buildings and signs.
for _, spot in {
	Vector3.new(-73, 0, -6),
	Vector3.new(-73, 0, 6),
	Vector3.new(-64, 0, -15),
	Vector3.new(-54, 0, -15),
	Vector3.new(-64, 0, 15),
	Vector3.new(-31, 0, titleZ),
	Vector3.new(31, 0, titleZ),
	Vector3.new(-22, 0, titleZ - 2),
	Vector3.new(22, 0, titleZ - 2),
	Vector3.new(70, 0, 13),
	Vector3.new(70, 0, -13),
	Vector3.new(78, 0, 0),
	Vector3.new(50, 0, 13),
	Vector3.new(50, 0, -13),
} do
	bush(spot + Vector3.new(0, FLOOR, 0), rng:NextNumber(3.5, 5))
end

-- Little patches of flowers in the grass.
local flowers = Instance.new("Model")
flowers.Name = "Flowers"
flowers.Parent = nature
for _ = 1, 20 do
	local patch = randomSpot(24, 80, 1)
	if patch then
		for _ = 1, rng:NextInteger(3, 6) do
			local spot = patch + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
			local stemHeight = rng:NextNumber(0.8, 1.4)
			block(flowers, CFrame.new(spot + Vector3.new(0, stemHeight / 2, 0)), Vector3.new(0.2, stemHeight, 0.2), Color3.fromRGB(60, 140, 50))
			ball(flowers, spot + Vector3.new(0, stemHeight + 0.3, 0), 0.9, pick(FLOWER_COLORS))
		end
	end
end

-- A few boulders.
for _ = 1, 8 do
	local spot = randomSpot(40, 130, 3)
	if spot then
		local size = rng:NextNumber(3, 6)
		block(
			nature,
			CFrame.new(spot + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)),
			Vector3.new(size, size * 0.8, size * 0.9),
			STONE,
			Enum.Material.Slate
		)
	end
end

--------------------------------------------------------------------------------
-- Put it in the world and start the crystal moving
--------------------------------------------------------------------------------

map.Parent = workspace

-- Bob up and down.
TweenService:Create(
	crystalAnchor,
	TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ CFrame = crystalAnchor.CFrame + Vector3.new(0, 1.5, 0) }
):Play()

-- Spin. A cube standing on its corner looks the same every third of a turn,
-- so repeating a 120-degree turn forever looks like one smooth spin.
TweenService:Create(
	crystalWeld,
	TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
	{ C0 = CFrame.Angles(0, math.pi * 2 / 3, 0) * cornerUp }
):Play()
