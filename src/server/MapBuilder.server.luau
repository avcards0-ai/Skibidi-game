-- Builds the starter map: a giant bathroom taken over by skibidi toilets.
--
-- Layout (players spawn in the middle, facing the title sign):
--   front: the sell drain and the SKIBIDI SIMULATOR sign
--   left:  the Plunger Shop          right: the Rebirth toilet
--   back:  the sink and mirror, a bathtub, soap and a toothbrush
--
-- Want to change the map by hand? Press Play, find "Map" in Workspace in the
-- Explorer, right-click > Copy, press Stop, then right-click Workspace > Paste Into.
-- When a Model named "Map" is already in Workspace, this script leaves it alone.

local TweenService = game:GetService("TweenService")

if workspace:FindFirstChild("Map") then
	return
end

local ROOM = 160 -- the bathroom is ROOM x ROOM studs
local HALF = ROOM / 2
local TILE = 10
local FLOOR = 0.5 -- height of the top of the floor tiles
local WALL_HEIGHT = 40
local WALL_THICKNESS = 4

local TILE_WHITE = Color3.fromRGB(245, 248, 255)
local TILE_BLUE = Color3.fromRGB(120, 190, 255)
local GROUT = Color3.fromRGB(170, 180, 195)
local WALL = Color3.fromRGB(230, 240, 250)
local STRIPE = Color3.fromRGB(60, 140, 230)
local PORCELAIN = Color3.fromRGB(250, 250, 252)
local SEAT = Color3.fromRGB(215, 218, 225)
local SKIN = Color3.fromRGB(255, 205, 160)
local BLACK = Color3.fromRGB(20, 20, 25)
local MOUTH = Color3.fromRGB(120, 20, 30)
local METAL = Color3.fromRGB(190, 195, 205)
local WOOD = Color3.fromRGB(160, 110, 60)
local PURPLE = Color3.fromRGB(160, 80, 255)
local SIGN_BACKGROUND = Color3.fromRGB(28, 32, 46)

-- Cylinders in Roblox lie along the X axis; this turns them to stand upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

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

-- An upright cylinder whose bottom sits at `bottom`.
local function pillar(parent: Instance, bottom: Vector3, height: number, diameter: number, color: Color3): Part
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = color,
		Parent = parent,
	})
end

-- Sticks `attached` to `base` so it moves along with it.
local function weld(base: BasePart, attached: BasePart)
	attached.Anchored = false
	attached.CanCollide = false
	local joint = Instance.new("Weld")
	joint.Part0 = base
	joint.Part1 = attached
	joint.C0 = base.CFrame:ToObjectSpace(attached.CFrame)
	joint.Parent = attached
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
	label.TextStrokeTransparency = 0
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

--------------------------------------------------------------------------------
-- Skibidi toilet
--------------------------------------------------------------------------------

local bobbingHeads: { { head: BasePart, scale: number } } = {}

-- Builds a skibidi toilet standing on `base` (a CFrame on the floor) and facing
-- the way `base` looks. `scale` 1 is about 4.5 studs tall.
local function skibidiToilet(parent: Instance, base: CFrame, scale: number, bodyColor: Color3, material: Enum.Material): Model
	local toilet = Instance.new("Model")
	toilet.Name = "SkibidiToilet"
	toilet.Parent = parent

	local function block(name: string, offset: Vector3, size: Vector3, color: Color3, tilt: CFrame?): Part
		return part({
			Name = name,
			Size = size * scale,
			CFrame = base * CFrame.new(offset * scale) * (tilt or CFrame.identity),
			Color = color,
			Material = material,
			Parent = toilet,
		})
	end
	local function disc(name: string, offset: Vector3, height: number, diameter: number, color: Color3): Part
		return part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, diameter, diameter) * scale,
			CFrame = base * CFrame.new(offset * scale) * UPRIGHT,
			Color = color,
			Material = material,
			Parent = toilet,
		})
	end
	local function ball(name: string, offset: Vector3, diameter: number, color: Color3): Part
		return part({
			Name = name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * diameter * scale,
			CFrame = base * CFrame.new(offset * scale),
			Color = color,
			Parent = toilet,
		})
	end

	-- The toilet. Its front is -Z (the way `base` looks), so the tank is at +Z.
	disc("Pedestal", Vector3.new(0, 0.6, 0), 1.2, 1.6, bodyColor)
	disc("Bowl", Vector3.new(0, 1.65, 0), 0.9, 2.6, bodyColor)
	disc("Seat", Vector3.new(0, 2.2, 0), 0.2, 2.8, SEAT)
	block("Tank", Vector3.new(0, 3.1, 1.4), Vector3.new(2.6, 2.2, 1), bodyColor)
	block("TankLid", Vector3.new(0, 4.3, 1.4), Vector3.new(2.8, 0.25, 1.2), bodyColor)
	block("FlushHandle", Vector3.new(-0.9, 3.8, 0.85), Vector3.new(0.5, 0.15, 0.15), METAL)

	-- The head sticking out of the bowl, with an angry face welded on so it moves with the head.
	local head = ball("Head", Vector3.new(0, 2.9, -0.1), 1.8, SKIN)
	head.CanCollide = false
	for _, side in { -1, 1 } do
		weld(head, ball("Eye", Vector3.new(0.35 * side, 3.1, -0.8), 0.3, BLACK))
		local tilt = CFrame.Angles(0, 0, math.rad(20 * side)) -- inner ends lower = angry
		weld(head, block("Eyebrow", Vector3.new(0.35 * side, 3.35, -0.72), Vector3.new(0.45, 0.1, 0.1), BLACK, tilt))
	end
	weld(head, block("Mouth", Vector3.new(0, 2.55, -0.82), Vector3.new(0.7, 0.22, 0.1), MOUTH))
	table.insert(bobbingHeads, { head = head, scale = scale })

	return toilet
end

--------------------------------------------------------------------------------
-- Floor, walls and title sign
--------------------------------------------------------------------------------

local floor = group("Floor")

-- The grout shows in the thin gaps between tiles.
part({
	Name = "Grout",
	Size = Vector3.new(ROOM, 1, ROOM),
	CFrame = CFrame.new(0, FLOOR - 0.7, 0),
	Color = GROUT,
	Parent = floor,
})

for x = -HALF + TILE / 2, HALF - TILE / 2, TILE do
	for z = -HALF + TILE / 2, HALF - TILE / 2, TILE do
		local isWhite = ((x + z) / TILE) % 2 == 0
		part({
			Name = "Tile",
			Size = Vector3.new(TILE - 0.3, 0.4, TILE - 0.3),
			CFrame = CFrame.new(x, FLOOR - 0.2, z),
			Color = if isWhite then TILE_WHITE else TILE_BLUE,
			Parent = floor,
		})
	end
end

local walls = group("Walls")
for _, side in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0) } do
	local runsAlongX = side.X == 0
	local length = ROOM + WALL_THICKNESS * 2

	part({
		Name = "Wall",
		Size = if runsAlongX
			then Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS)
			else Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length),
		CFrame = CFrame.new(side * (HALF + WALL_THICKNESS / 2) + Vector3.new(0, FLOOR + WALL_HEIGHT / 2, 0)),
		Color = WALL,
		Parent = walls,
	})

	-- Blue tile stripes along the inside of the wall.
	for _, height in { 8, 11 } do
		part({
			Name = "Stripe",
			Size = if runsAlongX then Vector3.new(ROOM, 1.5, 0.4) else Vector3.new(0.4, 1.5, ROOM),
			CFrame = CFrame.new(side * (HALF - 0.2) + Vector3.new(0, FLOOR + height, 0)),
			Color = STRIPE,
			Parent = walls,
		})
	end
end

-- The big sign on the front wall, facing the spawn.
local titleSign = part({
	Name = "TitleSign",
	Size = Vector3.new(80, 16, 1),
	CFrame = CFrame.new(0, FLOOR + 26, -HALF + 0.5),
	Color = SIGN_BACKGROUND,
	Parent = walls,
})
surfaceText(titleSign, Enum.NormalId.Back, "🚽 SKIBIDI SIMULATOR 🚽", Color3.fromRGB(255, 205, 60))

-- Use the place's spawn if it has one, otherwise add one in the middle.
if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, FLOOR + 0.5, 0)
	spawn.Color = STRIPE
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = map
end

--------------------------------------------------------------------------------
-- Sell drain (in front of the spawn)
--------------------------------------------------------------------------------

local sellArea = group("SellDrain")
local drainCenter = Vector3.new(0, FLOOR, -30)

pillar(sellArea, drainCenter, 0.4, 19, METAL).Material = Enum.Material.Metal

-- GameServer looks for a part named "SellPad" and sells your Flushes when you touch it.
local sellPad = pillar(sellArea, drainCenter, 0.7, 15, Color3.fromRGB(60, 220, 90))
sellPad.Name = "SellPad"
sellPad.Material = Enum.Material.Neon

-- Grate bars across the drain.
for offset = -5, 5, 2.5 do
	part({
		Name = "GrateBar",
		Size = Vector3.new(0.6, 0.25, 14),
		CFrame = CFrame.new(drainCenter + Vector3.new(offset, 0.8, 0)),
		Color = Color3.fromRGB(70, 75, 85),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanTouch = false,
		Parent = sellArea,
	})
end
floatingLabel(sellPad, "💰 SELL HERE 💰", Color3.fromRGB(120, 255, 140), 7)

--------------------------------------------------------------------------------
-- Plunger Shop (left of the spawn, facing it)
--------------------------------------------------------------------------------

local shop = group("PlungerShop")
local shopX = -46

part({
	Name = "ShopFloor",
	Size = Vector3.new(20, 0.6, 26),
	CFrame = CFrame.new(shopX, FLOOR + 0.3, 0),
	Color = Color3.fromRGB(70, 130, 220),
	Parent = shop,
})
part({
	Name = "BackWall",
	Size = Vector3.new(1.5, 16, 26),
	CFrame = CFrame.new(shopX - 9.25, FLOOR + 8.6, 0),
	Color = TILE_WHITE,
	Parent = shop,
})
for _, side in { -1, 1 } do
	part({
		Name = "SideWall",
		Size = Vector3.new(16, 16, 1.5),
		CFrame = CFrame.new(shopX - 1, FLOOR + 8.6, 12.25 * side),
		Color = TILE_WHITE,
		Parent = shop,
	})
end

-- Red and white striped awning.
for i = 0, 6 do
	part({
		Name = "Awning",
		Size = Vector3.new(22, 1.2, 4),
		CFrame = CFrame.new(shopX + 1, FLOOR + 17.2, -12 + i * 4),
		Color = if i % 2 == 0 then Color3.fromRGB(230, 60, 60) else PORCELAIN,
		Parent = shop,
	})
end

local shopSign = part({
	Name = "ShopSign",
	Size = Vector3.new(1, 5, 20),
	CFrame = CFrame.new(shopX + 10.5, FLOOR + 14, 0),
	Color = SIGN_BACKGROUND,
	Parent = shop,
})
surfaceText(shopSign, Enum.NormalId.Right, "🛒 PLUNGER SHOP", PORCELAIN)

local counter = part({
	Name = "Counter",
	Size = Vector3.new(3, 4, 16),
	CFrame = CFrame.new(shopX + 7, FLOOR + 2.6, 0),
	Color = WOOD,
	Material = Enum.Material.Wood,
	Parent = shop,
})
menuPrompt(counter, "Shop", "Open Shop", "Plunger Shop")
floatingLabel(counter, "🛒 SHOP", PORCELAIN, 17)

-- Plungers for sale hanging on the back wall.
local plungerColors = {
	Color3.fromRGB(230, 60, 60),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(90, 220, 255),
	Color3.fromRGB(180, 90, 255),
}
for i, color in plungerColors do
	local z = -7.5 + (i - 1) * 5
	pillar(shop, Vector3.new(shopX - 8, FLOOR + 5, z), 6, 0.5, WOOD)
	pillar(shop, Vector3.new(shopX - 8, FLOOR + 4, z), 1, 2.4, color)
end

-- A giant plunger standing outside the shop.
pillar(shop, Vector3.new(shopX + 9, FLOOR, 17), 3, 8, Color3.fromRGB(230, 60, 60))
pillar(shop, Vector3.new(shopX + 9, FLOOR + 3, 17), 16, 1.5, WOOD).Material = Enum.Material.Wood

--------------------------------------------------------------------------------
-- Rebirth toilet (right of the spawn, facing it)
--------------------------------------------------------------------------------

local rebirthArea = group("RebirthToilet")
local rebirthCenter = Vector3.new(46, FLOOR, 0)

pillar(rebirthArea, rebirthCenter, 0.3, 27, PURPLE).Material = Enum.Material.Neon
pillar(rebirthArea, rebirthCenter, 0.6, 24, Color3.fromRGB(60, 30, 100))

local rebirthToilet = skibidiToilet(
	rebirthArea,
	CFrame.lookAt(rebirthCenter + Vector3.new(0, 0.6, 0), Vector3.new(0, FLOOR + 0.6, 0)),
	3.5,
	PURPLE,
	Enum.Material.Neon
)
local rebirthBowl = rebirthToilet:FindFirstChild("Bowl") :: BasePart
menuPrompt(rebirthBowl, "Rebirth", "Rebirth", "Rebirth Toilet")
floatingLabel(rebirthBowl, "⭐ REBIRTH ⭐", Color3.fromRGB(220, 170, 255), 16)
Instance.new("Sparkles").Parent = rebirthBowl

local glow = Instance.new("PointLight")
glow.Color = PURPLE
glow.Range = 24
glow.Brightness = 3
glow.Parent = rebirthBowl

--------------------------------------------------------------------------------
-- Decorations
--------------------------------------------------------------------------------

local decorations = group("Decorations")

-- Skibidi toilets around the room, all staring at the middle.
for _, spot in {
	Vector3.new(-35, FLOOR, -60),
	Vector3.new(35, FLOOR, -60),
	Vector3.new(-65, FLOOR, -30),
	Vector3.new(65, FLOOR, -30),
	Vector3.new(-65, FLOOR, 35),
	Vector3.new(65, FLOOR, 35),
} do
	skibidiToilet(decorations, CFrame.lookAt(spot, Vector3.new(0, FLOOR, 0)), 2.5, PORCELAIN, Enum.Material.SmoothPlastic)
end

-- Giant toilet paper rolls in the corners.
for _, corner in { Vector3.new(-65, FLOOR, -65), Vector3.new(65, FLOOR, -65), Vector3.new(-65, FLOOR, 65), Vector3.new(65, FLOOR, 65) } do
	pillar(decorations, corner, 24, 12, PORCELAIN).Material = Enum.Material.Fabric
	pillar(decorations, corner + Vector3.new(0, 24, 0), 0.2, 5, Color3.fromRGB(110, 75, 45))
end

-- Bathtub with water you can jump into, and a rubber duck.
local tubCenter = Vector3.new(30, FLOOR, 55)
local tubLength, tubWidth, tubHeight, tubSide = 36, 20, 6, 1.5
part({
	Name = "TubBottom",
	Size = Vector3.new(tubLength, 1, tubWidth),
	CFrame = CFrame.new(tubCenter + Vector3.new(0, 0.5, 0)),
	Color = PORCELAIN,
	Parent = decorations,
})
for _, side in { -1, 1 } do
	part({
		Name = "TubSide",
		Size = Vector3.new(tubLength, tubHeight, tubSide),
		CFrame = CFrame.new(tubCenter + Vector3.new(0, tubHeight / 2, side * (tubWidth - tubSide) / 2)),
		Color = PORCELAIN,
		Parent = decorations,
	})
	part({
		Name = "TubEnd",
		Size = Vector3.new(tubSide, tubHeight, tubWidth - tubSide * 2),
		CFrame = CFrame.new(tubCenter + Vector3.new(side * (tubLength - tubSide) / 2, tubHeight / 2, 0)),
		Color = PORCELAIN,
		Parent = decorations,
	})
end
part({
	Name = "Water",
	Size = Vector3.new(tubLength - tubSide * 2, tubHeight - 2, tubWidth - tubSide * 2),
	CFrame = CFrame.new(tubCenter + Vector3.new(0, 1 + (tubHeight - 2) / 2, 0)),
	Color = Color3.fromRGB(80, 170, 255),
	Material = Enum.Material.Glass,
	Transparency = 0.4,
	CanCollide = false,
	Parent = decorations,
})
pillar(decorations, tubCenter + Vector3.new(tubLength / 2 - 0.75, tubHeight, 0), 3, 1, METAL).Material = Enum.Material.Metal

local duckSpot = tubCenter + Vector3.new(-4, tubHeight - 1, 0)
local duckYellow = Color3.fromRGB(255, 220, 40)
part({ Name = "DuckBody", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, CFrame = CFrame.new(duckSpot), Color = duckYellow, Parent = decorations })
part({ Name = "DuckHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = CFrame.new(duckSpot + Vector3.new(-1.3, 2.2, 0)), Color = duckYellow, Parent = decorations })
part({ Name = "DuckBeak", Size = Vector3.new(1.2, 0.5, 1), CFrame = CFrame.new(duckSpot + Vector3.new(-2.8, 2, 0)), Color = Color3.fromRGB(255, 140, 30), Parent = decorations })
for _, side in { -1, 1 } do
	part({ Name = "DuckEye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, CFrame = CFrame.new(duckSpot + Vector3.new(-2.2, 2.6, 0.6 * side)), Color = BLACK, Parent = decorations })
end

-- Giant sink and mirror on the back wall.
local sinkX = -30
part({
	Name = "SinkCabinet",
	Size = Vector3.new(30, 10, 12),
	CFrame = CFrame.new(sinkX, FLOOR + 5, HALF - 6),
	Color = PORCELAIN,
	Parent = decorations,
})
pillar(decorations, Vector3.new(sinkX, FLOOR + 10, HALF - 6), 0.3, 9, Color3.fromRGB(200, 215, 230))
pillar(decorations, Vector3.new(sinkX, FLOOR + 10, HALF - 1.5), 4, 1.2, METAL).Material = Enum.Material.Metal
part({
	Name = "Faucet",
	Size = Vector3.new(1, 1, 3.5),
	CFrame = CFrame.new(sinkX, FLOOR + 13.5, HALF - 3),
	Color = METAL,
	Material = Enum.Material.Metal,
	Parent = decorations,
})
part({
	Name = "MirrorFrame",
	Size = Vector3.new(30, 20, 0.3),
	CFrame = CFrame.new(sinkX, FLOOR + 23, HALF - 0.15),
	Color = METAL,
	Material = Enum.Material.Metal,
	Parent = decorations,
})
part({
	Name = "Mirror",
	Size = Vector3.new(28, 18, 0.3),
	CFrame = CFrame.new(sinkX, FLOOR + 23, HALF - 0.45),
	Color = Color3.fromRGB(190, 225, 255),
	Material = Enum.Material.Glass,
	Reflectance = 0.5,
	Parent = decorations,
})

-- A giant toothbrush lying on the floor.
local brushSpot = Vector3.new(-38, FLOOR, 45)
part({
	Name = "ToothbrushHandle",
	Size = Vector3.new(32, 1.6, 3),
	CFrame = CFrame.new(brushSpot + Vector3.new(0, 0.8, 0)),
	Color = Color3.fromRGB(60, 200, 200),
	Parent = decorations,
})
part({
	Name = "Bristles",
	Size = Vector3.new(6, 2.5, 3),
	CFrame = CFrame.new(brushSpot + Vector3.new(12.5, 2.85, 0)),
	Color = PORCELAIN,
	Material = Enum.Material.Fabric,
	Parent = decorations,
})
part({
	Name = "Toothpaste",
	Size = Vector3.new(5, 1.2, 2.4),
	CFrame = CFrame.new(brushSpot + Vector3.new(12.5, 4.7, 0)),
	Color = Color3.fromRGB(140, 220, 255),
	Parent = decorations,
})

-- A giant bar of soap you can jump on.
local soap = part({
	Name = "Soap",
	Size = Vector3.new(10, 3, 6),
	CFrame = CFrame.new(0, FLOOR + 1.5, 45),
	Color = Color3.fromRGB(255, 150, 200),
	Parent = decorations,
})
surfaceText(soap, Enum.NormalId.Top, "SOAP", PORCELAIN)

--------------------------------------------------------------------------------
-- Put it in the world and start the skibidi head bobbing
--------------------------------------------------------------------------------

map.Parent = workspace

for _, toilet in bobbingHeads do
	local head = toilet.head
	local up = head.CFrame * CFrame.new(0, 0.5 * toilet.scale, 0) * CFrame.Angles(0, math.rad(25), 0)
	local bob = TweenService:Create(
		head,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = up }
	)
	-- Start each head at a slightly different time so they don't all move together.
	task.delay(math.random() * 1.5, function()
		bob:Play()
	end)
end
