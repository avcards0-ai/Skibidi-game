-- Builds the map: a sunny grass field with a stone plaza where players spawn, and
-- the Sewers underneath it.
--
-- Layout (players spawn in the middle of the plaza, facing the title sign):
--   front:       the SELL pad with a big sign above it, and the SKIBIDI SIMULATOR sign behind
--   front-left:  the Egg Hatchery      front-right: the manhole down to the Sewers
--   left:        the Plunger Shop      right:       the Rebirth shrine
--   back:        a pond with reeds, lily pads and benches
-- Oak, pine and birch trees, flower patches, bushes, rocks and lamp posts fill in
-- the rest, and grassy hills (made of Terrain) with pine trees circle the area.
--
-- Want to change the map by hand? Press Play, find "Map" in Workspace in the
-- Explorer, right-click > Copy, press Stop, then right-click Workspace > Paste Into.
-- When a Model named "Map" is already in Workspace, this script doesn't build another.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local FLOOR = 0.2 -- height of the top of the grass

local GRASS = Color3.fromRGB(96, 168, 72)
local PATH = Color3.fromRGB(200, 190, 165)
local PLAZA = Color3.fromRGB(215, 210, 195)
local STONE = Color3.fromRGB(150, 150, 155)
local MARBLE = Color3.fromRGB(238, 234, 226)
local WOOD = Color3.fromRGB(165, 115, 70)
local WOOD_LIGHT = Color3.fromRGB(200, 160, 110)
local WOOD_DARK = Color3.fromRGB(95, 65, 40)
local ROOF = Color3.fromRGB(125, 60, 45)
local PURPLE = Color3.fromRGB(160, 80, 255)
local GOLD = Color3.fromRGB(255, 205, 60)
local WHITE = Color3.fromRGB(250, 250, 250)
local RED = Color3.fromRGB(230, 60, 60)
local DARK_METAL = Color3.fromRGB(40, 40, 45)
local LAMP_GLOW = Color3.fromRGB(255, 220, 150)
local SOIL = Color3.fromRGB(75, 55, 38)
local STEM = Color3.fromRGB(70, 130, 50)
local FLOWER_MIDDLE = Color3.fromRGB(255, 200, 40)

-- { shadow side, sunny side } leaf colors for each kind of tree.
local OAK_LEAVES = {
	{ Color3.fromRGB(45, 95, 40), Color3.fromRGB(100, 160, 60) },
	{ Color3.fromRGB(40, 90, 45), Color3.fromRGB(85, 150, 65) },
	{ Color3.fromRGB(55, 100, 35), Color3.fromRGB(115, 165, 55) },
}
local PINE_NEEDLES = {
	{ Color3.fromRGB(25, 65, 40), Color3.fromRGB(50, 105, 60) },
	{ Color3.fromRGB(30, 70, 45), Color3.fromRGB(60, 110, 55) },
}
local BIRCH_LEAVES = {
	{ Color3.fromRGB(80, 135, 50), Color3.fromRGB(150, 200, 80) },
}
local BUSH_LEAVES = {
	{ Color3.fromRGB(35, 80, 35), Color3.fromRGB(80, 140, 55) },
	{ Color3.fromRGB(45, 90, 40), Color3.fromRGB(95, 150, 60) },
}
local DAISY_COLORS = {
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(255, 215, 60),
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(170, 120, 255),
}
local TULIP_COLORS = {
	Color3.fromRGB(230, 40, 50),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 130, 40),
}
local TUFT_COLORS = {
	Color3.fromRGB(80, 150, 60),
	Color3.fromRGB(105, 170, 70),
	Color3.fromRGB(70, 135, 55),
}

-- Cylinders in Roblox lie along the X axis; this turns them to stand upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local TAU = math.pi * 2

-- Fixed seeds, so everything lands in the same spots every time.
local rng = Random.new(2024)
local hillRng = Random.new(7)

--------------------------------------------------------------------------------
-- Sky, lighting and hills. These run every time, even if you've saved your own
-- Map, but they don't replace anything you've already set up.
--------------------------------------------------------------------------------

Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
end
if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
	local colors = Instance.new("ColorCorrectionEffect")
	colors.Saturation = 0.12
	colors.Contrast = 0.05
	colors.Parent = Lighting
end

local terrain = workspace.Terrain
if not terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = terrain
end

-- Grassy hills around the edge. Only added if the place has no Terrain yet.
local hills = {}
for i = 1, 20 do
	local angle = (i / 20) * TAU + hillRng:NextNumber(-0.1, 0.1)
	local distance = hillRng:NextNumber(380, 460)
	local radius = hillRng:NextNumber(55, 95)
	table.insert(hills, {
		center = Vector3.new(math.cos(angle) * distance, FLOOR - radius * 0.45, math.sin(angle) * distance),
		radius = radius,
	})
end

local builtHills = terrain:CountCells() == 0
if builtHills then
	terrain:SetMaterialColor(Enum.Material.Grass, GRASS)
	for _, hill in hills do
		terrain:FillBall(hill.center, hill.radius, Enum.Material.Grass)
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

local function group(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent or map
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

-- For small decorations you should walk through, like flowers and leaves.
local function decor<T>(thing: T): T
	local basePart = thing :: any
	basePart.CanCollide = false
	basePart.CanTouch = false
	basePart.CanQuery = false
	basePart.CastShadow = false
	return thing
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

-- A cylinder running from one point to another, like a branch or a stem.
local function rod(parent: Instance, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	local offset = to - from
	local middle = (from + to) / 2
	local cframe = if Vector3.new(offset.X, 0, offset.Z).Magnitude < 0.05
		then CFrame.new(middle) * UPRIGHT
		else CFrame.lookAt(middle, to) * CFrame.Angles(0, math.rad(90), 0)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(offset.Magnitude, diameter, diameter),
		CFrame = cframe,
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

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
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

-- A "Press E" prompt that GameServer handles, like hatching an egg or going into the Sewers.
local function actionPrompt(target: BasePart, actionText: string, objectText: string, attribute: string, value: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(attribute, value)
	prompt.Parent = target
end

local function addLight(target: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = target
end

--------------------------------------------------------------------------------
-- Plants and rocks
--------------------------------------------------------------------------------

-- A daisy-style flower: stem, a leaf, five petals around a yellow middle.
local function daisy(parent: Instance, spot: Vector3, petalColor: Color3, scale: number)
	local stemHeight = rng:NextNumber(0.9, 1.5) * scale
	local head = spot + Vector3.new(rng:NextNumber(-0.12, 0.12), stemHeight, rng:NextNumber(-0.12, 0.12)) * Vector3.new(scale, 1, scale)
	decor(rod(parent, spot, head, 0.1 * scale, STEM))

	local turn = rng:NextNumber(0, TAU)
	decor(block(
		parent,
		CFrame.new(spot + Vector3.new(0, stemHeight * 0.35, 0)) * CFrame.Angles(0, turn, 0) * CFrame.new(0.2 * scale, 0, 0) * CFrame.Angles(0, 0, math.rad(25)),
		Vector3.new(0.45, 0.04, 0.18) * scale,
		STEM
	))

	for i = 1, 5 do
		local angle = turn + (i / 5) * TAU
		decor(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, 0.42, 0.42) * scale,
			CFrame = CFrame.new(head) * CFrame.Angles(0, angle, 0) * CFrame.new(0.22 * scale, 0, 0) * CFrame.Angles(0, 0, math.rad(75)),
			Color = petalColor,
			Parent = parent,
		}))
	end
	decor(ball(parent, head + Vector3.new(0, 0.04 * scale, 0), 0.26 * scale, FLOWER_MIDDLE))
end

-- A tulip: a tall stem with two long leaves and a cup of petals.
local function tulip(parent: Instance, spot: Vector3, color: Color3, scale: number)
	local stemHeight = rng:NextNumber(1.3, 1.9) * scale
	local head = spot + Vector3.new(0, stemHeight, 0)
	decor(rod(parent, spot, head, 0.1 * scale, STEM))

	local turn = rng:NextNumber(0, TAU)
	for _, side in { 0, math.pi } do
		decor(block(
			parent,
			CFrame.new(spot) * CFrame.Angles(0, turn + side, 0) * CFrame.Angles(0, 0, -math.rad(22)) * CFrame.new(0, 0.4 * scale, 0),
			Vector3.new(0.16, 0.8, 0.05) * scale,
			STEM
		))
	end

	decor(ball(parent, head + Vector3.new(0, 0.25 * scale, 0), 0.42 * scale, color))
	for i = 1, 3 do
		decor(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, 0.5, 0.5) * scale,
			CFrame = CFrame.new(head + Vector3.new(0, 0.3 * scale, 0))
				* CFrame.Angles(0, turn + (i / 3) * TAU, 0)
				* CFrame.new(0.17 * scale, 0, 0)
				* CFrame.Angles(0, 0, math.rad(12)),
			Color = color,
			Parent = parent,
		}))
	end
end

-- A clump of grass blades.
local function grassTuft(parent: Instance, spot: Vector3, height: number)
	local color = pick(TUFT_COLORS)
	local turn = rng:NextNumber(0, TAU)
	for i = 1, 3 do
		local bladeHeight = height * rng:NextNumber(0.7, 1.1)
		local lean = math.rad(rng:NextNumber(-25, 25))
		decor(wedge(
			parent,
			CFrame.new(spot) * CFrame.Angles(0, turn + i * 2.1, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, bladeHeight / 2, 0),
			Vector3.new(0.08, bladeHeight, 0.35),
			darken(color, rng:NextNumber(0, 0.15)),
			Enum.Material.Grass
		))
	end
end

-- A bush made of leafy lumps, darker underneath. Some have red berries.
local function bush(parent: Instance, spot: Vector3, size: number)
	local model = group("Bush", parent)
	local colors = pick(BUSH_LEAVES)
	for _ = 1, rng:NextInteger(4, 6) do
		local lumpSize = size * rng:NextNumber(0.55, 0.9)
		local offset = Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0.1, 0.45), rng:NextNumber(-0.4, 0.4)) * size
		local sunlight = math.clamp(offset.Y / (size * 0.45), 0, 1)
		decor(ball(model, spot + offset + Vector3.new(0, lumpSize * 0.15, 0), lumpSize, colors[1]:Lerp(colors[2], sunlight), Enum.Material.LeafyGrass))
	end
	if rng:NextNumber() < 0.35 then
		for _ = 1, 6 do
			local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
			decor(ball(model, spot + Vector3.new(0, size * 0.4, 0) + direction * size * 0.5, 0.35, Color3.fromRGB(200, 30, 40)))
		end
	end
end

-- A lumpy, half-buried boulder made of a few rough pieces.
local function boulder(parent: Instance, spot: Vector3, size: number, mossy: boolean)
	local gray = rng:NextInteger(115, 150)
	local color = Color3.fromRGB(gray + 6, gray, gray - 8)
	if mossy then
		color = color:Lerp(Color3.fromRGB(85, 110, 60), 0.35)
	end
	for _ = 1, rng:NextInteger(2, 3) do
		local pieceSize = size * rng:NextNumber(0.6, 1)
		local offset = Vector3.new(rng:NextNumber(-0.3, 0.3) * size, pieceSize * 0.2, rng:NextNumber(-0.3, 0.3) * size)
		block(
			parent,
			CFrame.new(spot + offset) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, TAU), rng:NextNumber(-0.5, 0.5)),
			Vector3.new(pieceSize, pieceSize * 0.7, pieceSize * 0.85),
			darken(color, rng:NextNumber(0, 0.1)),
			Enum.Material.Rock
		)
	end
end

-- An oak: tapered, slightly leaning trunk with roots, branches, and clumps of
-- leaves at the branch tips (lighter on top where the sun hits).
local function oakTree(parent: Instance, spot: Vector3, height: number)
	local model = group("OakTree", parent)
	local bark = darken(Color3.fromRGB(100, 72, 50), rng:NextNumber(0, 0.15))
	local leaves = pick(OAK_LEAVES)
	local trunkHeight = height * 0.5
	local trunkWidth = height * 0.09
	local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, TAU), rng:NextNumber(-0.06, 0.06))
	local base = CFrame.new(spot) * lean

	local segments = 3
	for i = 0, segments - 1 do
		local width = trunkWidth * (1 - i * 0.1)
		local from = (base * CFrame.new(0, trunkHeight * i / segments - 0.3, 0)).Position
		local to = (base * CFrame.new(0, trunkHeight * (i + 1) / segments + 0.3, 0)).Position
		rod(model, from, to, width, bark, Enum.Material.Wood)
	end

	for i = 1, 4 do
		local outward = Vector3.new(math.cos(i * TAU / 4 + 0.4), 0, math.sin(i * TAU / 4 + 0.4))
		local rootSize = trunkWidth * 0.9
		local center = spot + outward * (trunkWidth * 0.3 + rootSize / 2) + Vector3.new(0, rootSize / 2 - 0.1, 0)
		wedge(model, CFrame.lookAt(center, center + outward), Vector3.new(trunkWidth * 0.35, rootSize, rootSize), bark, Enum.Material.Wood)
	end

	local top = (base * CFrame.new(0, trunkHeight, 0)).Position
	local clumps = { top + Vector3.new(0, height * 0.15, 0) }
	local branchCount = rng:NextInteger(3, 5)
	for i = 1, branchCount do
		local angle = (i / branchCount) * TAU + rng:NextNumber(-0.3, 0.3)
		local tilt = rng:NextNumber(0.6, 1)
		local direction = Vector3.new(math.cos(angle) * math.sin(tilt), math.cos(tilt), math.sin(angle) * math.sin(tilt))
		local start = (base * CFrame.new(0, trunkHeight * rng:NextNumber(0.75, 0.95), 0)).Position
		local tip = start + direction * height * rng:NextNumber(0.22, 0.32)
		rod(model, start, tip, trunkWidth * 0.4, bark, Enum.Material.Wood)
		table.insert(clumps, tip)
	end

	local leafSize = height * 0.3
	for _, clump in clumps do
		for _ = 1, 3 do
			local size = leafSize * rng:NextNumber(0.6, 0.9)
			local center = clump + Vector3.new(rng:NextNumber(-0.35, 0.35), rng:NextNumber(-0.1, 0.3), rng:NextNumber(-0.35, 0.35)) * leafSize
			local sunlight = math.clamp((center.Y - top.Y) / (height * 0.45), 0, 1)
			decor(ball(model, center, size, leaves[1]:Lerp(leaves[2], sunlight), Enum.Material.LeafyGrass)).CastShadow = true
		end
	end
end

-- A pine: straight trunk with layers of drooping branches, each layer made of
-- six wedges around the trunk, getting smaller toward the top.
local function pineTree(parent: Instance, spot: Vector3, height: number)
	local model = group("PineTree", parent)
	local needles = pick(PINE_NEEDLES)
	pillar(model, spot - Vector3.new(0, 0.5, 0), height * 0.85, height * 0.06, Color3.fromRGB(105, 70, 50), Enum.Material.Wood)

	local layers = 4
	local turn = rng:NextNumber(0, TAU)
	for layer = 0, layers - 1 do
		local progress = layer / layers
		local layerBottom = height * (0.2 + progress * 0.6)
		local radius = height * 0.27 * (1 - progress * 0.7)
		local layerHeight = height * 0.3 * (1 - progress * 0.35)
		local color = needles[1]:Lerp(needles[2], progress)
		for i = 1, 6 do
			local angle = turn + layer * 0.5 + (i / 6) * TAU
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local center = spot + Vector3.new(0, layerBottom + layerHeight / 2, 0) + outward * (radius / 2)
			wedge(model, CFrame.lookAt(center, center + outward), Vector3.new(radius * 1.05, layerHeight, radius), color, Enum.Material.LeafyGrass)
		end
	end
end

-- A birch: thin white trunk with dark marks and a light, airy crown.
local function birchTree(parent: Instance, spot: Vector3, height: number)
	local model = group("BirchTree", parent)
	local leaves = pick(BIRCH_LEAVES)
	local trunkHeight = height * 0.75
	local trunkWidth = height * 0.05
	local lean = CFrame.new(spot) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
	local top = (lean * CFrame.new(0, trunkHeight, 0)).Position
	rod(model, spot - Vector3.new(0, 0.5, 0), top, trunkWidth, Color3.fromRGB(228, 225, 215), Enum.Material.Wood)

	for _ = 1, 4 do
		local markHeight = rng:NextNumber(0.1, 0.9) * trunkHeight
		local mark = (lean * CFrame.new(0, markHeight, 0)).Position
		rod(model, mark, mark + (top - spot).Unit * 0.15, trunkWidth * 1.08, Color3.fromRGB(40, 38, 35))
	end

	for i = 1, 7 do
		local progress = i / 7
		local size = height * 0.24 * (1 - math.abs(progress - 0.45) * 0.8)
		local center = spot:Lerp(top, 0.45 + progress * 0.6)
			+ Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)) * size
		decor(ball(model, center, size, leaves[1]:Lerp(leaves[2], progress), Enum.Material.LeafyGrass)).CastShadow = true
	end
end

--------------------------------------------------------------------------------
-- Where things can go
--------------------------------------------------------------------------------

local sellCenter = Vector3.new(0, FLOOR, -80)
local shopX = -112
local shrineCenter = Vector3.new(110, FLOOR, 0)
local titleZ = -135
local pondCenter = Vector3.new(0, FLOOR, 105)
local pondRadius = 17
local hatcheryCenter = Vector3.new(-82, FLOOR, -82)
local sewerEntrance = Vector3.new(82, FLOOR, -82)
local PLAZA_CENTER = Vector3.new(0, FLOOR, 0)

-- A point `distance` studs from `from` in the direction of `to`, at ground level.
local function toward(from: Vector3, to: Vector3, distance: number): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return Vector3.new(from.X, 0, from.Z) + flat.Unit * distance
end

-- Stone paths from the plaza out to each area (flat, at y = 0).
local PATH_WIDTH = 9
local pathSegments = {
	{ from = Vector3.new(0, 0, -18), to = toward(sellCenter, PLAZA_CENTER, 10) },
	{ from = Vector3.new(0, 0, 18), to = toward(pondCenter, PLAZA_CENTER, pondRadius) },
	{ from = Vector3.new(-18, 0, 0), to = Vector3.new(shopX + 16, 0, 0) },
	{ from = Vector3.new(18, 0, 0), to = toward(shrineCenter, PLAZA_CENTER, 14) },
	{ from = toward(PLAZA_CENTER, hatcheryCenter, 18), to = toward(hatcheryCenter, PLAZA_CENTER, 18) },
	{ from = toward(PLAZA_CENTER, sewerEntrance, 18), to = toward(sewerEntrance, PLAZA_CENTER, 11) },
}

-- Areas to keep clear so nothing grows on the buildings or paths.
local clearings = {
	{ center = Vector3.zero, radius = 24 }, -- plaza
	{ center = sellCenter, radius = 20 },
	{ center = Vector3.new(shopX + 2, 0, 0), radius = 26 },
	{ center = shrineCenter, radius = 17 },
	{ center = Vector3.new(0, 0, titleZ), radius = 32 },
	{ center = pondCenter, radius = pondRadius + 4 },
	{ center = hatcheryCenter, radius = 24 },
	{ center = sewerEntrance, radius = 18 },
}

local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local along = to - from
	local t = math.clamp((point - from):Dot(along) / along:Dot(along), 0, 1)
	return (point - (from + along * t)).Magnitude
end

local function isClear(spot: Vector3, margin: number): boolean
	local flat = Vector3.new(spot.X, 0, spot.Z)
	for _, clearing in clearings do
		local center = Vector3.new(clearing.center.X, 0, clearing.center.Z)
		if (flat - center).Magnitude < clearing.radius + margin then
			return false
		end
	end
	for _, segment in pathSegments do
		if distanceToSegment(flat, segment.from, segment.to) < PATH_WIDTH / 2 + 2.5 + margin then
			return false
		end
	end
	return true
end

-- Finds a random clear spot between two distances from the middle.
local function randomSpot(minDistance: number, maxDistance: number, margin: number): Vector3?
	for _ = 1, 50 do
		local angle = rng:NextNumber(0, TAU)
		local distance = rng:NextNumber(minDistance, maxDistance)
		local spot = Vector3.new(math.cos(angle) * distance, FLOOR, math.sin(angle) * distance)
		if isClear(spot, margin) then
			return spot
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Ground, plaza and paths
--------------------------------------------------------------------------------

local ground = group("Ground")

-- One huge grass part. It sits just above the default Baseplate so it covers it.
block(ground, CFrame.new(0, FLOOR - 1, 0), Vector3.new(2048, 2, 2048), GRASS, Enum.Material.Grass).Name = "Grass"

-- Soft lighter and darker patches so the grass isn't one flat color. Each patch is
-- a few overlapping circles, which makes a blobby, natural-looking shape.
for _ = 1, 40 do
	local size = rng:NextNumber(8, 18)
	local spot = randomSpot(20, 320, size)
	if spot then
		local target = pick({ Color3.fromRGB(80, 145, 60), Color3.fromRGB(120, 180, 80), Color3.fromRGB(115, 165, 70) })
		local shade = GRASS:Lerp(target, rng:NextNumber(0.25, 0.45))
		local height = rng:NextNumber(0.02, 0.1)
		for _ = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)) * size
			decor(pillar(ground, spot + offset - Vector3.new(0, 0.1, 0), 0.1 + height, size * rng:NextNumber(0.6, 1.1), shade, Enum.Material.Grass))
		end
	end
end

-- The round stone plaza where players spawn.
pillar(ground, Vector3.new(0, FLOOR - 0.2, 0), 0.5, 44, STONE, Enum.Material.Slate)
pillar(ground, Vector3.new(0, FLOOR - 0.2, 0), 0.6, 40, PLAZA, Enum.Material.Cobblestone)

-- Stone planters full of flowers on the plaza's corners.
for i = 0, 3 do
	local angle = math.rad(45 + i * 90)
	local spot = Vector3.new(math.cos(angle) * 15, FLOOR + 0.4, math.sin(angle) * 15)
	pillar(ground, spot, 1.2, 5, Color3.fromRGB(175, 170, 160), Enum.Material.Pavement)
	pillar(ground, spot + Vector3.new(0, 1.2, 0), 0.15, 4.3, SOIL, Enum.Material.Ground)
	local color = pick(TULIP_COLORS)
	tulip(ground, spot + Vector3.new(0, 1.3, 0), color, 1)
	for j = 1, 5 do
		local around = (j / 5) * TAU
		daisy(ground, spot + Vector3.new(math.cos(around) * 1.4, 1.3, math.sin(around) * 1.4), pick(DAISY_COLORS), 0.9)
	end
end

-- A lamp post with a glowing glass lantern.
local lamps = group("Lamps")
local function lampPost(spot: Vector3)
	local bottom = Vector3.new(spot.X, FLOOR, spot.Z)
	pillar(lamps, bottom, 0.8, 1.4, DARK_METAL, Enum.Material.Metal)
	pillar(lamps, bottom + Vector3.new(0, 0.8, 0), 8.4, 0.45, DARK_METAL, Enum.Material.Metal)
	local lanternGlass = block(lamps, CFrame.new(bottom + Vector3.new(0, 10, 0)), Vector3.new(1.3, 1.8, 1.3), Color3.fromRGB(255, 235, 190), Enum.Material.Glass)
	lanternGlass.Transparency = 0.4
	local bulb = decor(ball(lamps, bottom + Vector3.new(0, 10, 0), 0.7, LAMP_GLOW, Enum.Material.Neon))
	addLight(bulb, LAMP_GLOW, 18, 1.2)
	block(lamps, CFrame.new(bottom + Vector3.new(0, 11.1, 0)), Vector3.new(1.8, 0.35, 1.8), DARK_METAL, Enum.Material.Metal)
	ball(lamps, bottom + Vector3.new(0, 11.5, 0), 0.5, DARK_METAL, Enum.Material.Metal)
end

-- The stone paths, with little stones along their edges and lamp posts every so often.
local paths = group("Paths", ground)
for _, segment in pathSegments do
	local from, to = segment.from, segment.to
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local sideways = Vector3.new(-direction.Z, 0, direction.X)
	local middle = (from + to) / 2
	block(
		paths,
		CFrame.lookAt(middle, to) + Vector3.new(0, FLOOR + 0.05, 0),
		Vector3.new(PATH_WIDTH, 0.4, length),
		PATH,
		Enum.Material.Cobblestone
	)

	for along = 1.5, length - 1.5, 2.2 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.55 then
				local size = rng:NextNumber(0.7, 1.3)
				local spot = from + direction * along + sideways * (side * (PATH_WIDTH / 2 + 0.6))
				block(
					paths,
					CFrame.new(spot + Vector3.new(0, FLOOR + 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
					Vector3.new(size, 0.45, size * 0.8),
					darken(STONE, rng:NextNumber(0, 0.2)),
					Enum.Material.Rock
				)
			end
		end
	end

	local lampSide = 1
	for along = 12, length - 6, 26 do
		lampPost(from + direction * along + sideways * (lampSide * (PATH_WIDTH / 2 + 2.5)))
		lampSide = -lampSide
	end
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

-- A glowing sell pad under an arch with the SELL sign on it. `base` sits on the floor.
-- GameServer sells your Flushes when you touch any part named "SellPad".
local function sellStation(parent: Instance, base: CFrame, withCoins: boolean)
	local center = base.Position
	pillar(parent, center - Vector3.new(0, 0.2, 0), 0.7, 20, STONE, Enum.Material.Slate)
	local pad = pillar(parent, center - Vector3.new(0, 0.2, 0), 1, 16, Color3.fromRGB(70, 220, 100), Enum.Material.Neon)
	pad.Name = "SellPad"

	for _, side in { -1, 1 } do
		block(parent, base * CFrame.new(11.5 * side, 7, 0), Vector3.new(1.8, 14, 1.8), WOOD_DARK, Enum.Material.Wood)
		ball(parent, (base * CFrame.new(11.5 * side, 16.2, 0)).Position, 2, GOLD, Enum.Material.Foil)
	end
	block(parent, base * CFrame.new(0, 14.6, 0), Vector3.new(27, 1.2, 2), WOOD_DARK, Enum.Material.Wood)
	local sign = block(parent, base * CFrame.new(0, 11.5, 0), Vector3.new(21, 5, 1.2), Color3.fromRGB(40, 120, 60))
	surfaceText(sign, Enum.NormalId.Back, "💰 SELL 💰", WHITE)
	surfaceText(sign, Enum.NormalId.Front, "💰 SELL 💰", WHITE)

	-- Piles of gold coins beside the pad.
	if withCoins then
		for _, spot in { Vector3.new(-15, 0, 3), Vector3.new(15, 0, 3), Vector3.new(-14.5, 0, -4), Vector3.new(14.5, 0, -4) } do
			for i = 1, rng:NextInteger(4, 8) do
				local jitter = Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
				local bottom = (base * CFrame.new(spot + jitter)).Position + Vector3.new(0, (i - 1) * 0.45, 0)
				pillar(parent, bottom, 0.45, 2.4, GOLD, Enum.Material.Foil)
			end
		end
	end
end

sellStation(group("SellArea"), CFrame.new(sellCenter), true)

--------------------------------------------------------------------------------
-- Plunger Shop (left of the spawn, facing it)
--------------------------------------------------------------------------------

local shop = group("PlungerShop")
local depth, width, wallHeight = 20, 24, 12 -- depth runs along X, width along Z
local floorTop = FLOOR + 0.6
local wallTop = floorTop + wallHeight
local front = shopX + depth / 2

-- Wooden floor with a porch out front.
block(shop, CFrame.new(shopX + 3, FLOOR + 0.3, 0), Vector3.new(depth + 6, 0.6, width + 2), WOOD_LIGHT, Enum.Material.WoodPlanks)

-- Walls: back, two sides, and a front with corner posts and a header beam.
block(shop, CFrame.new(shopX - depth / 2 + 0.5, floorTop + wallHeight / 2, 0), Vector3.new(1, wallHeight, width), WOOD, Enum.Material.WoodPlanks)
for _, side in { -1, 1 } do
	local wallZ = side * (width / 2 - 0.5)
	block(shop, CFrame.new(shopX + 0.5, floorTop + wallHeight / 2, wallZ), Vector3.new(depth - 1, wallHeight, 1), WOOD, Enum.Material.WoodPlanks)
	block(
		shop,
		CFrame.new(front - 0.6, floorTop + wallHeight / 2, side * (width / 2 - 0.6)),
		Vector3.new(1.2, wallHeight, 1.2),
		WOOD_DARK,
		Enum.Material.Wood
	)

	-- A window with a wooden frame and a flower box on the outside of each side wall.
	local outside = wallZ + side * 0.55
	local windowCenter = Vector3.new(shopX, floorTop + 6.5, outside)
	local glass = block(shop, CFrame.new(windowCenter), Vector3.new(6, 4, 0.1), Color3.fromRGB(170, 210, 235), Enum.Material.Glass)
	glass.Transparency = 0.3
	glass.Reflectance = 0.2
	for _, frame in {
		{ offset = Vector3.new(0, 2.1, 0), size = Vector3.new(6.6, 0.4, 0.3) },
		{ offset = Vector3.new(0, -2.1, 0), size = Vector3.new(6.6, 0.4, 0.3) },
		{ offset = Vector3.new(3.1, 0, 0), size = Vector3.new(0.4, 4.2, 0.3) },
		{ offset = Vector3.new(-3.1, 0, 0), size = Vector3.new(0.4, 4.2, 0.3) },
		{ offset = Vector3.zero, size = Vector3.new(0.2, 4, 0.25) },
		{ offset = Vector3.zero, size = Vector3.new(6, 0.2, 0.25) },
	} do
		block(shop, CFrame.new(windowCenter + frame.offset), frame.size, WOOD_DARK, Enum.Material.Wood)
	end
	local boxTop = windowCenter + Vector3.new(0, -2.4, side * 0.5)
	block(shop, CFrame.new(boxTop - Vector3.new(0, 0.5, 0)), Vector3.new(6.4, 1, 1.2), WOOD, Enum.Material.WoodPlanks)
	for x = -2.4, 2.4, 1.2 do
		daisy(shop, boxTop + Vector3.new(x, 0, 0), pick(DAISY_COLORS), 0.6)
	end
end
block(shop, CFrame.new(front - 0.5, wallTop - 1.5, 0), Vector3.new(1, 3, width), WOOD_DARK, Enum.Material.Wood)

-- Sloped shingle roof: two slabs meeting at a ridge, with triangle walls filling each end.
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
		Enum.Material.RoofShingles
	)
	for _, halfSide in { -1, 1 } do
		-- Each end triangle is two wedges, tallest under the ridge.
		local center = Vector3.new(shopX + halfSide * depth / 4, wallTop + rise / 2, side * (width / 2 - 0.5))
		wedge(shop, CFrame.fromMatrix(center, Vector3.new(0, 0, halfSide), Vector3.yAxis), Vector3.new(1, rise, depth / 2), WOOD, Enum.Material.WoodPlanks)
	end
end
block(shop, CFrame.new(ridge + Vector3.new(0, 0.6, 0)), Vector3.new(1, 1, width + overhang * 2 + 0.4), darken(ROOF, 0.25), Enum.Material.RoofShingles)

-- Sign above the counter.
local shopSign = block(shop, CFrame.new(front + 0.3, wallTop - 1.5, 0), Vector3.new(0.6, 2.6, width - 5), Color3.fromRGB(60, 40, 25))
surfaceText(shopSign, Enum.NormalId.Right, "🛒 PLUNGER SHOP", GOLD)

-- The counter you walk up to.
local counter = block(shop, CFrame.new(front - 2, floorTop + 1.8, 0), Vector3.new(2.4, 3.6, width - 6), WOOD, Enum.Material.Wood)
counter.Name = "Counter"
block(shop, CFrame.new(front - 2, floorTop + 3.8, 0), Vector3.new(3, 0.4, width - 5), WOOD_LIGHT, Enum.Material.Wood)
menuPrompt(counter, "Shop", "Open Shop", "Plunger Shop")
floatingLabel(counter, "🛒 SHOP", WHITE, 22)

-- Lanterns on the front posts.
for _, side in { -1, 1 } do
	local lanternCenter = Vector3.new(front + 0.4, floorTop + 8, side * (width / 2 - 0.6))
	local lanternGlass = block(shop, CFrame.new(lanternCenter), Vector3.new(0.8, 1.1, 0.8), Color3.fromRGB(255, 235, 190), Enum.Material.Glass)
	lanternGlass.Transparency = 0.4
	local bulb = decor(ball(shop, lanternCenter, 0.4, LAMP_GLOW, Enum.Material.Neon))
	addLight(bulb, LAMP_GLOW, 12, 1)
	block(shop, CFrame.new(lanternCenter + Vector3.new(0, 0.65, 0)), Vector3.new(1, 0.2, 1), DARK_METAL, Enum.Material.Metal)
end

-- Plungers for sale on the back wall.
for i, color in { RED, GOLD, Color3.fromRGB(90, 220, 255), PURPLE } do
	local z = -7.5 + (i - 1) * 5
	pillar(shop, Vector3.new(shopX - depth / 2 + 2, floorTop + 5, z), 6, 0.5, WOOD, Enum.Material.Wood)
	pillar(shop, Vector3.new(shopX - depth / 2 + 2, floorTop + 4, z), 1, 2.4, color, Enum.Material.Rubber)
end

-- A giant plunger, crates and a barrel out front.
ball(shop, Vector3.new(front + 4, FLOOR, 17.5), 7.5, RED, Enum.Material.Rubber) -- half sunk into the ground, so it's a dome
pillar(shop, Vector3.new(front + 4, FLOOR + 3, 17.5), 14, 1.4, WOOD, Enum.Material.Wood)
block(shop, CFrame.new(front + 4, FLOOR + 2, -16), Vector3.new(4, 4, 4), WOOD_LIGHT, Enum.Material.WoodPlanks)
block(shop, CFrame.new(front + 4, FLOOR + 5.5, -16) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(3, 3, 3), WOOD_LIGHT, Enum.Material.WoodPlanks)
local barrelSpot = Vector3.new(front + 4, FLOOR, -20.5)
pillar(shop, barrelSpot, 4, 3, Color3.fromRGB(130, 85, 50), Enum.Material.Wood)
for _, bandHeight in { 0.7, 3 } do
	pillar(shop, barrelSpot + Vector3.new(0, bandHeight, 0), 0.3, 3.1, DARK_METAL, Enum.Material.Metal)
end

--------------------------------------------------------------------------------
-- Rebirth shrine with a floating crystal (right of the spawn)
--------------------------------------------------------------------------------

local rebirthArea = group("RebirthShrine")
local below = Vector3.new(0, 0.2, 0)

-- A stepped marble platform with a glowing purple ring.
pillar(rebirthArea, shrineCenter - below, 1, 28, MARBLE, Enum.Material.Marble)
pillar(rebirthArea, shrineCenter - below, 1.1, 22, PURPLE, Enum.Material.Neon)
pillar(rebirthArea, shrineCenter - below, 1.2, 20, MARBLE, Enum.Material.Marble)

-- Marble columns around the edge.
for i = 1, 6 do
	local angle = (i / 6) * TAU
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
addLight(crystal, PURPLE, 26, 3)

--------------------------------------------------------------------------------
-- Title sign (behind the sell pad, facing the spawn)
--------------------------------------------------------------------------------

local titleArea = group("TitleSign")
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
-- Pond with reeds, lily pads and benches (behind the spawn)
--------------------------------------------------------------------------------

local pondArea = group("Pond")

-- A muddy bank, a darker deep middle, and see-through water over both.
pillar(pondArea, pondCenter - Vector3.new(0, 0.1, 0), 0.14, pondRadius * 2 + 2, Color3.fromRGB(95, 85, 60), Enum.Material.Ground)
pillar(pondArea, pondCenter - Vector3.new(0, 0.1, 0), 0.16, pondRadius * 1.3, Color3.fromRGB(30, 60, 55), Enum.Material.Mud)
local water = pillar(pondArea, pondCenter + Vector3.new(0, 0.07, 0), 0.08, pondRadius * 2, Color3.fromRGB(60, 140, 200), Enum.Material.Glass)
water.Name = "Water"
water.Transparency = 0.35
water.Reflectance = 0.3

-- Rocks around the edge (some mossy), leaving a gap where the path arrives.
local rockCount = 22
for i = 1, rockCount do
	local angle = (i / rockCount) * TAU
	local spot = pondCenter + Vector3.new(math.cos(angle) * (pondRadius + 0.8), 0, math.sin(angle) * (pondRadius + 0.8))
	if not (math.abs(spot.X) < 5 and spot.Z < pondCenter.Z) then
		boulder(pondArea, spot, rng:NextNumber(1.8, 3), rng:NextNumber() < 0.4)
	end
end

-- Reeds and cattails growing in the shallow water on the far side.
for _, degrees in { 35, 70, 110, 145, 215, 325 } do
	local angle = math.rad(degrees)
	local cluster = pondCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (pondRadius - 1.5)
	for _ = 1, 5 do
		local base = cluster + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		local reedHeight = rng:NextNumber(2.5, 4.5)
		local tip = base + Vector3.new(rng:NextNumber(-0.3, 0.3), reedHeight, rng:NextNumber(-0.3, 0.3))
		decor(rod(pondArea, base, tip, 0.14, Color3.fromRGB(95, 130, 60)))
		if rng:NextNumber() < 0.5 then
			decor(rod(pondArea, base:Lerp(tip, 0.72), base:Lerp(tip, 0.92), 0.35, Color3.fromRGB(100, 65, 40)))
		end
	end
end

-- Lily pads, some with flowers.
for i = 1, 7 do
	local angle = rng:NextNumber(0, TAU)
	local distance = rng:NextNumber(3, pondRadius - 4)
	local spot = pondCenter + Vector3.new(math.cos(angle) * distance, 0.15, math.sin(angle) * distance)
	decor(pillar(pondArea, spot, 0.06, rng:NextNumber(2.2, 3.4), Color3.fromRGB(70, 150, 65)))
	if i % 2 == 0 then
		daisy(pondArea, spot + Vector3.new(0, -0.8, 0), pick({ WHITE, Color3.fromRGB(255, 170, 210) }), 1.3)
	end
end

-- Wooden benches looking at the pond.
local function bench(spot: Vector3, lookAt: Vector3)
	local base = CFrame.lookAt(spot, Vector3.new(lookAt.X, spot.Y, lookAt.Z))
	block(pondArea, base * CFrame.new(0, 1.6, 0), Vector3.new(6, 0.4, 2), WOOD, Enum.Material.WoodPlanks)
	block(pondArea, base * CFrame.new(0, 2.9, 0.9), Vector3.new(6, 2, 0.3), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -0.7, 0.7 } do
			block(pondArea, base * CFrame.new(x, 0.7, z), Vector3.new(0.4, 1.4, 0.4), DARK_METAL, Enum.Material.Metal)
		end
	end
end
bench(pondCenter + Vector3.new(-24, 0, 0), pondCenter)
bench(pondCenter + Vector3.new(24, 0, 0), pondCenter)

--------------------------------------------------------------------------------
-- Egg Hatchery (front-left of the spawn): one egg on a stand for each egg in Config
--------------------------------------------------------------------------------

local hatchery = group("EggHatchery")
local hatcheryBase = CFrame.lookAt(hatcheryCenter, PLAZA_CENTER) -- its front (-Z) faces the plaza
local bobbingEggs: { BasePart } = {}

pillar(hatchery, hatcheryCenter - Vector3.new(0, 0.2, 0), 0.6, 38, STONE, Enum.Material.Slate)
pillar(hatchery, hatcheryCenter - Vector3.new(0, 0.2, 0), 0.7, 35, Color3.fromRGB(235, 225, 205), Enum.Material.Pavement)

for i, egg in Config.Eggs do
	-- Right to left in the stand's own view, so players walking up read them left to right.
	local spot = hatcheryBase * CFrame.new(((#Config.Eggs + 1) / 2 - i) * 7.5, 0.5, 2)
	local stand = block(hatchery, spot * CFrame.new(0, 1.5, 0), Vector3.new(5, 3, 5), MARBLE, Enum.Material.Marble)
	stand.Name = egg.Name .. " Stand"
	block(hatchery, spot * CFrame.new(0, 3.2, 0), Vector3.new(5.4, 0.4, 5.4), egg.Color, Enum.Material.Neon)

	-- A plain egg that glows its color. A sphere mesh stretches to fill the part,
	-- so a tall part makes an egg shape.
	local eggPart = part({
		Name = egg.Name,
		Size = Vector3.new(3.4, 4.4, 3.4),
		CFrame = spot * CFrame.new(0, 5.6, 0),
		Color = egg.Color,
		Material = Enum.Material.Neon,
		Parent = hatchery,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = eggPart
	addLight(eggPart, egg.Color, 14, 2)

	actionPrompt(stand, "Hatch", ("%s (%s coins)"):format(egg.Name, Format.number(egg.Price)), "Egg", egg.Name)
	floatingLabel(stand, ("%s\n💰 %s"):format(egg.Name, Format.number(egg.Price)), egg.Color:Lerp(WHITE, 0.3), 9.5)
	table.insert(bobbingEggs, eggPart)
end

-- The sign behind the eggs.
local hatcherySign = hatcheryBase * CFrame.new(0, 0, 10)
for _, side in { -1, 1 } do
	block(hatchery, hatcherySign * CFrame.new(16 * side, 8, 0), Vector3.new(1.8, 16, 1.8), WOOD_DARK, Enum.Material.Wood)
end
block(hatchery, hatcherySign * CFrame.new(0, 16.4, 0), Vector3.new(34, 1.2, 2), WOOD_DARK, Enum.Material.Wood)
local hatcheryBoard = block(hatchery, hatcherySign * CFrame.new(0, 13, 0), Vector3.new(30, 5.5, 1.2), Color3.fromRGB(250, 240, 215), Enum.Material.WoodPlanks)
surfaceText(hatcheryBoard, Enum.NormalId.Front, "🥚 EGG HATCHERY 🥚", Color3.fromRGB(255, 150, 50))

--------------------------------------------------------------------------------
-- Sewer entrance (front-right of the spawn): a glowing manhole with pipes
--------------------------------------------------------------------------------

local SLUDGE = Color3.fromRGB(110, 190, 50)
local RUST = Color3.fromRGB(125, 85, 55)
local BRICK_RED = Color3.fromRGB(130, 75, 60)
local METAL = Color3.fromRGB(95, 100, 105)

local entrance = group("SewerEntrance")
local entranceBase = CFrame.lookAt(sewerEntrance, PLAZA_CENTER) -- its front (-Z) faces the plaza
local entranceBottom = sewerEntrance - Vector3.new(0, 0.2, 0)

pillar(entrance, entranceBottom, 2, 18, BRICK_RED, Enum.Material.Brick)
pillar(entrance, entranceBottom, 2.02, 14.5, METAL, Enum.Material.DiamondPlate)
pillar(entrance, entranceBottom, 2.05, 13, Color3.fromRGB(15, 20, 15)).Name = "SewerHole"
local sewerGlow = pillar(entrance, entranceBottom, 2.1, 9, SLUDGE, Enum.Material.Neon)
sewerGlow.Name = "SewerGlow"
actionPrompt(
	sewerGlow,
	"Enter the Sewers",
	("Unlock once: %s coins"):format(Format.number(Config.SewerUnlockPrice)),
	"TeleportTo",
	"Sewer"
)
floatingLabel(sewerGlow, "☣️ SEWERS", Color3.fromRGB(160, 255, 110), 11)

-- Green fumes rising out of the hole. (The cylinder is lying on its side and
-- turned upright, so its "Right" face is the one pointing up.)
local fumes = Instance.new("ParticleEmitter")
fumes.EmissionDirection = Enum.NormalId.Right
fumes.Color = ColorSequence.new(Color3.fromRGB(140, 255, 100))
fumes.LightEmission = 0.5
fumes.Size = NumberSequence.new(1.6, 0)
fumes.Transparency = NumberSequence.new(0.4, 1)
fumes.Lifetime = NumberRange.new(1.5, 2.5)
fumes.Rate = 10
fumes.Speed = NumberRange.new(3, 6)
fumes.SpreadAngle = Vector2.new(15, 15)
fumes.Parent = sewerGlow

-- The manhole cover, leaning against nothing in particular.
part({
	Name = "ManholeCover",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.6, 9, 9),
	CFrame = entranceBase * CFrame.new(-11.5, 4.4, 1) * CFrame.Angles(0, 0, math.rad(12)),
	Color = METAL,
	Material = Enum.Material.DiamondPlate,
	Parent = entrance,
})

-- Rusty pipes coming out of the ground.
for _, pipe in { { x = 11, height = 9, reach = -6 }, { x = 14, height = 5, reach = 5 } } do
	local bottom = (entranceBase * CFrame.new(pipe.x, -1, 4)).Position
	local bend = (entranceBase * CFrame.new(pipe.x, pipe.height, 4)).Position
	local tip = (entranceBase * CFrame.new(pipe.x, pipe.height, 4 + pipe.reach)).Position
	rod(entrance, bottom, bend, 3, RUST, Enum.Material.CorrodedMetal)
	ball(entrance, bend, 3.3, RUST, Enum.Material.CorrodedMetal)
	rod(entrance, bend, tip, 3, RUST, Enum.Material.CorrodedMetal)
	rod(entrance, tip - (tip - bend).Unit * 0.4, tip + (tip - bend).Unit * 0.2, 3.6, darken(RUST, 0.3), Enum.Material.CorrodedMetal)
end

-- Toxic puddles.
for _ = 1, 4 do
	local spot = (entranceBase * CFrame.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-12, -8))).Position
	decor(pillar(entrance, spot - Vector3.new(0, 0.1, 0), 0.16, rng:NextNumber(1.5, 3.5), SLUDGE, Enum.Material.Glass)).Transparency = 0.2
end

-- The sign.
local entranceSign = entranceBase * CFrame.new(0, 0, 11)
for _, side in { -1, 1 } do
	block(entrance, entranceSign * CFrame.new(8.5 * side, 6, 0), Vector3.new(1.2, 12, 1.2), DARK_METAL, Enum.Material.Metal)
end
local entranceBoard = block(entrance, entranceSign * CFrame.new(0, 10, 0), Vector3.new(16, 4, 0.8), Color3.fromRGB(35, 45, 30), Enum.Material.Metal)
surfaceText(entranceBoard, Enum.NormalId.Front, "☣️ THE SEWERS ☣️", Color3.fromRGB(160, 255, 110))
local entranceInfo = block(entrance, entranceSign * CFrame.new(0, 7.1, 0), Vector3.new(14, 1.8, 0.6), Color3.fromRGB(35, 45, 30), Enum.Material.Metal)
surfaceText(
	entranceInfo,
	Enum.NormalId.Front,
	("%gx Flushes • Unlock: %s"):format(Config.SewerMultiplier, Format.number(Config.SewerUnlockPrice)),
	WHITE
)

-- Where players appear when they climb out of the Sewers.
part({
	Name = "SurfaceArrival",
	Size = Vector3.new(4, 1, 4),
	CFrame = entranceBase * CFrame.new(0, 1, -13),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = entrance,
})

--------------------------------------------------------------------------------
-- The Sewers, deep underground: a big room in the middle with a sludge channel
-- running through it and four long tunnels. Clicks down here give extra Flushes.
--------------------------------------------------------------------------------

local sewer = group("Sewers")
local SEWER_Y = Config.SewerDepth -- height of the walkways
local HUB = 40 -- the middle room is 80 x 80
local HUB_HEIGHT = 36
local TUNNEL_LENGTH = 120
local TUNNEL_HALF = 18 -- tunnels are 36 wide
local TUNNEL_HEIGHT = 26
local CHANNEL_HALF = 6 -- the sludge channel is 12 wide
local BRICK = Color3.fromRGB(88, 92, 80)
local CONCRETE = Color3.fromRGB(100, 104, 96)
local MOSS = Color3.fromRGB(70, 95, 50)
local SEWER_LIGHT = Color3.fromRGB(210, 255, 170)

local function at(x: number, y: number, z: number): Vector3
	return Vector3.new(x, SEWER_Y + y, z)
end

-- A concrete walkway whose top is the sewer floor. Only X and Z of `center` and `size` are used.
local function walkway(center: Vector3, size: Vector3)
	block(sewer, CFrame.new(at(center.X, -2.5, center.Z)), Vector3.new(size.X, 5, size.Z), CONCRETE, Enum.Material.Concrete)
end

-- A stretch of channel: a muddy bed with see-through green sludge you can wade through.
local function channel(center: Vector3, size: Vector3)
	block(sewer, CFrame.new(at(center.X, -4, center.Z)), Vector3.new(size.X, 2, size.Z), Color3.fromRGB(40, 48, 32), Enum.Material.Mud)
	local sludge = block(sewer, CFrame.new(at(center.X, -1.4, center.Z)), Vector3.new(size.X, 0.4, size.Z), SLUDGE, Enum.Material.Glass)
	sludge.Name = "Sludge"
	sludge.Transparency = 0.15
	sludge.CanCollide = false
end

local function wallLamp(position: Vector3, facing: Vector3)
	block(sewer, CFrame.lookAt(position, position + facing), Vector3.new(1.4, 1.8, 0.6), DARK_METAL, Enum.Material.Metal)
	local bulb = decor(ball(sewer, position + facing * 0.6, 0.9, SEWER_LIGHT, Enum.Material.Neon))
	addLight(bulb, SEWER_LIGHT, 26, 1.6)
end

local function toxicBarrel(bottom: Vector3)
	pillar(sewer, bottom, 3.6, 2.6, Color3.fromRGB(55, 75, 45), Enum.Material.Metal)
	pillar(sewer, bottom + Vector3.new(0, 1.4, 0), 0.5, 2.7, SLUDGE, Enum.Material.Neon)
	pillar(sewer, bottom + Vector3.new(0, 3.6, 0), 0.15, 2.3, Color3.fromRGB(40, 50, 35), Enum.Material.Metal)
end

local function rat(spot: Vector3, facing: Vector3)
	local base = CFrame.lookAt(spot, spot + facing)
	local fur = Color3.fromRGB(110, 105, 110)
	local pink = Color3.fromRGB(240, 160, 170)
	decor(ball(sewer, (base * CFrame.new(0, 0.5, 0)).Position, 1.1, fur))
	decor(ball(sewer, (base * CFrame.new(0, 0.6, -0.7)).Position, 0.7, fur))
	decor(ball(sewer, (base * CFrame.new(0, 0.55, -1.05)).Position, 0.2, pink))
	decor(rod(sewer, (base * CFrame.new(0, 0.4, 0.5)).Position, (base * CFrame.new(0.3, 0.3, 1.7)).Position, 0.1, pink))
end

-- The middle room's floor: four walkways around a cross of sludge channels.
local corner = (CHANNEL_HALF + HUB) / 2
for _, x in { -corner, corner } do
	for _, z in { -corner, corner } do
		walkway(Vector3.new(x, 0, z), Vector3.new(HUB - CHANNEL_HALF, 0, HUB - CHANNEL_HALF))
	end
end
channel(Vector3.zero, Vector3.new(CHANNEL_HALF * 2, 0, HUB * 2))
for _, x in { -corner, corner } do
	channel(Vector3.new(x, 0, 0), Vector3.new(HUB - CHANNEL_HALF, 0, CHANNEL_HALF * 2))
end

-- Metal bridges over the channels, with railings.
for _, bridge in {
	{ center = Vector3.new(0, 0, corner), spansX = true },
	{ center = Vector3.new(0, 0, -corner), spansX = true },
	{ center = Vector3.new(corner, 0, 0), spansX = false },
	{ center = Vector3.new(-corner, 0, 0), spansX = false },
} do
	local deck = if bridge.spansX then Vector3.new(CHANNEL_HALF * 2 + 2, 0.6, 7) else Vector3.new(7, 0.6, CHANNEL_HALF * 2 + 2)
	block(sewer, CFrame.new(at(bridge.center.X, 0, bridge.center.Z)), deck, METAL, Enum.Material.DiamondPlate)
	for _, side in { -3.2, 3.2 } do
		local offset = if bridge.spansX then Vector3.new(0, 0, side) else Vector3.new(side, 0, 0)
		local railCenter = bridge.center + offset
		local halfSpan = if bridge.spansX then Vector3.new(CHANNEL_HALF + 1, 0, 0) else Vector3.new(0, 0, CHANNEL_HALF + 1)
		rod(sewer, at(railCenter.X, 3, railCenter.Z) - halfSpan, at(railCenter.X, 3, railCenter.Z) + halfSpan, 0.25, SLUDGE, Enum.Material.Metal)
		for _, post in { -1, 1 } do
			local postSpot = railCenter + halfSpan * post
			pillar(sewer, at(postSpot.X, 0.3, postSpot.Z), 2.8, 0.3, DARK_METAL, Enum.Material.Metal)
		end
	end
end

-- The middle room's walls (with openings for the tunnels), ceiling and corner pillars.
for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
	local along = Vector3.new(side.Z, 0, -side.X)
	local wallLine = side * (HUB + 1)
	local function wallSize(length: number, height: number): Vector3
		return if side.X ~= 0 then Vector3.new(2, height, length) else Vector3.new(length, height, 2)
	end
	for _, s in { -1, 1 } do
		local center = wallLine + along * (s * (TUNNEL_HALF + (HUB + 2 - TUNNEL_HALF) / 2))
		block(sewer, CFrame.new(at(center.X, (HUB_HEIGHT - 5) / 2, center.Z)), wallSize(HUB + 2 - TUNNEL_HALF, HUB_HEIGHT + 5), BRICK, Enum.Material.Brick)
	end
	-- above the tunnel opening
	block(sewer, CFrame.new(at(wallLine.X, (TUNNEL_HEIGHT + HUB_HEIGHT) / 2, wallLine.Z)), wallSize(TUNNEL_HALF * 2, HUB_HEIGHT - TUNNEL_HEIGHT), BRICK, Enum.Material.Brick)
	-- moss along the bottom of the walls
	local mossLine = side * (HUB - 0.05)
	for _, s in { -1, 1 } do
		local center = mossLine + along * (s * (TUNNEL_HALF + (HUB - TUNNEL_HALF) / 2))
		local mossSize = if side.X ~= 0 then Vector3.new(0.3, 3, HUB - TUNNEL_HALF) else Vector3.new(HUB - TUNNEL_HALF, 3, 0.3)
		block(sewer, CFrame.new(at(center.X, 1.5, center.Z)), mossSize, MOSS, Enum.Material.LeafyGrass)
	end
	-- lamps on the walls either side of the opening
	for _, s in { -1, 1 } do
		local spot = side * (HUB - 0.3) + along * (s * (TUNNEL_HALF + 8))
		wallLamp(at(spot.X, 10, spot.Z), -side)
	end
end
block(sewer, CFrame.new(at(0, HUB_HEIGHT + 1, 0)), Vector3.new(HUB * 2 + 4, 2, HUB * 2 + 4), darken(CONCRETE, 0.2), Enum.Material.Concrete)
for _, x in { -1, 1 } do
	for _, z in { -1, 1 } do
		block(sewer, CFrame.new(at(x * (HUB - 3), (HUB_HEIGHT - 5) / 2, z * (HUB - 3))), Vector3.new(6, HUB_HEIGHT + 5, 6), darken(BRICK, 0.15), Enum.Material.Brick)
	end
end

-- Big lamps hanging from the ceiling.
for _, x in { -corner, corner } do
	for _, z in { -corner, corner } do
		rod(sewer, at(x, HUB_HEIGHT, z), at(x, 25, z), 0.3, DARK_METAL, Enum.Material.Metal)
		block(sewer, CFrame.new(at(x, 24.6, z)), Vector3.new(3.2, 0.8, 3.2), DARK_METAL, Enum.Material.Metal)
		local bulb = decor(ball(sewer, at(x, 23.8, z), 1.4, SEWER_LIGHT, Enum.Material.Neon))
		addLight(bulb, SEWER_LIGHT, 45, 2.2)
	end
end

-- The four tunnels.
for _, direction in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
	local across = Vector3.new(direction.Z, 0, -direction.X)
	local function size(along: number, side: number, height: number): Vector3
		return if direction.X ~= 0 then Vector3.new(along, height, side) else Vector3.new(side, height, along)
	end
	local middle = direction * (HUB + TUNNEL_LENGTH / 2)

	channel(middle, size(TUNNEL_LENGTH, CHANNEL_HALF * 2, 0))
	for _, s in { -1, 1 } do
		walkway(middle + across * (s * (CHANNEL_HALF + TUNNEL_HALF) / 2), size(TUNNEL_LENGTH, TUNNEL_HALF - CHANNEL_HALF, 0))

		local wallCenter = middle + across * (s * (TUNNEL_HALF + 1))
		block(sewer, CFrame.new(at(wallCenter.X, (TUNNEL_HEIGHT - 5) / 2, wallCenter.Z)), size(TUNNEL_LENGTH, 2, TUNNEL_HEIGHT + 5), BRICK, Enum.Material.Brick)
		local mossCenter = middle + across * (s * (TUNNEL_HALF - 0.05))
		block(sewer, CFrame.new(at(mossCenter.X, 1.5, mossCenter.Z)), size(TUNNEL_LENGTH, 0.3, 3), MOSS, Enum.Material.LeafyGrass)

		-- Slanted pieces in the top corners make the tunnel look rounded.
		local inward = across * -s
		local cornerTop = middle + across * (s * TUNNEL_HALF)
		wedge(
			sewer,
			CFrame.fromMatrix(at(cornerTop.X, TUNNEL_HEIGHT - 2.5, cornerTop.Z) + inward * 2.5, Vector3.yAxis:Cross(inward), -Vector3.yAxis),
			Vector3.new(TUNNEL_LENGTH, 5, 5),
			CONCRETE,
			Enum.Material.Concrete
		)

		-- A rusty pipe along the wall.
		local pipeLine = middle + across * (s * (TUNNEL_HALF - 1.8))
		local pipeStart = at(pipeLine.X, TUNNEL_HEIGHT - 8, pipeLine.Z) - direction * (TUNNEL_LENGTH / 2)
		rod(sewer, pipeStart, pipeStart + direction * TUNNEL_LENGTH, 2.4, RUST, Enum.Material.CorrodedMetal)
		for ring = 1, 5 do
			local ringSpot = pipeStart + direction * (ring * TUNNEL_LENGTH / 6)
			rod(sewer, ringSpot - direction * 0.4, ringSpot + direction * 0.4, 2.9, darken(RUST, 0.3), Enum.Material.CorrodedMetal)
		end
	end
	block(sewer, CFrame.new(at(middle.X, TUNNEL_HEIGHT + 1, middle.Z)), size(TUNNEL_LENGTH, TUNNEL_HALF * 2 + 4, 2), darken(CONCRETE, 0.2), Enum.Material.Concrete)

	-- The far end: a brick wall with a big pipe pouring sludge into the channel.
	local farEnd = direction * (HUB + TUNNEL_LENGTH)
	local endWall = farEnd + direction
	block(sewer, CFrame.new(at(endWall.X, (TUNNEL_HEIGHT - 5) / 2, endWall.Z)), size(2, TUNNEL_HALF * 2 + 4, TUNNEL_HEIGHT + 5), BRICK, Enum.Material.Brick)
	local pipeMouth = at(farEnd.X, 9, farEnd.Z) - direction * 4
	rod(sewer, at(farEnd.X, 9, farEnd.Z), pipeMouth, 7, RUST, Enum.Material.CorrodedMetal)
	rod(sewer, pipeMouth, pipeMouth - direction * 0.6, 7.8, darken(RUST, 0.3), Enum.Material.CorrodedMetal)
	local pour = block(sewer, CFrame.new(at(farEnd.X, 2.4, farEnd.Z) - direction * 4.6), size(1.2, 4, 7.4), SLUDGE, Enum.Material.Neon)
	pour.Transparency = 0.25
	pour.CanCollide = false

	-- Lamps along the walls, and some junk on the walkways.
	for k = 1, 5 do
		local s = if k % 2 == 0 then 1 else -1
		local spot = middle + direction * ((k - 3) * 22) + across * (s * (TUNNEL_HALF - 0.3))
		wallLamp(at(spot.X, 9, spot.Z), across * -s)
	end
	for _ = 1, 3 do
		local s = if rng:NextNumber() < 0.5 then 1 else -1
		local spot = middle + direction * rng:NextNumber(-50, 50) + across * (s * rng:NextNumber(10, 15))
		if rng:NextNumber() < 0.6 then
			toxicBarrel(at(spot.X, 0, spot.Z))
		else
			block(sewer, CFrame.new(at(spot.X, 1.5, spot.Z)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), Vector3.new(3, 3, 3), WOOD, Enum.Material.WoodPlanks)
		end
	end
	local ratSpot = middle + direction * rng:NextNumber(-40, 40) + across * (rng:NextNumber(8, 16) * (if rng:NextNumber() < 0.5 then 1 else -1))
	rat(at(ratSpot.X, 0, ratSpot.Z), direction)
end

-- Bubbles and a lost rubber duck floating in the sludge.
for _ = 1, 24 do
	local alongZ = rng:NextNumber() < 0.5
	local distance = rng:NextNumber(-HUB - TUNNEL_LENGTH + 10, HUB + TUNNEL_LENGTH - 10)
	local offset = rng:NextNumber(-CHANNEL_HALF + 1, CHANNEL_HALF - 1)
	local spot = if alongZ then Vector3.new(offset, 0, distance) else Vector3.new(distance, 0, offset)
	decor(ball(sewer, at(spot.X, -1.2, spot.Z), rng:NextNumber(0.4, 0.9), Color3.fromRGB(150, 220, 80), Enum.Material.Glass)).Transparency = 0.3
end
local duckSpot = at(2, -1.2, 14)
local duckYellow = Color3.fromRGB(255, 215, 40)
decor(ball(sewer, duckSpot, 1.8, duckYellow))
decor(ball(sewer, duckSpot + Vector3.new(0, 1, -0.5), 1.2, duckYellow))
decor(block(sewer, CFrame.new(duckSpot + Vector3.new(0, 0.9, -1.15)), Vector3.new(0.55, 0.22, 0.5), Color3.fromRGB(255, 140, 30)))

-- The sell pad down here, in one corner of the middle room.
sellStation(sewer, CFrame.lookAt(at(-corner, 0, -corner), at(0, 0, 0)), false)

-- Where players arrive, in the opposite corner.
part({
	Name = "SewerArrival",
	Size = Vector3.new(4, 1, 4),
	CFrame = CFrame.lookAt(at(corner, 1, corner), at(0, 1, 0)),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = sewer,
})

-- The way back up: a ladder to a hole in the ceiling, with an EXIT sign.
local ladderSpot = at(30, HUB_HEIGHT / 2, HUB - 1)
local ladder = Instance.new("TrussPart")
ladder.Anchored = true
ladder.Size = Vector3.new(2, HUB_HEIGHT, 2)
ladder.CFrame = CFrame.new(ladderSpot)
ladder.Color = DARK_METAL
ladder.Material = Enum.Material.Metal
ladder.Parent = sewer
pillar(sewer, at(30, HUB_HEIGHT - 0.2, HUB - 1), 0.25, 5, Color3.fromRGB(10, 10, 10))
local skylight = decor(pillar(sewer, at(30, HUB_HEIGHT - 14, HUB - 1), 14, 3.5, Color3.fromRGB(255, 250, 220), Enum.Material.Neon))
skylight.Transparency = 0.88
local exitSign = block(sewer, CFrame.new(at(35.5, 5, HUB - 0.2)), Vector3.new(6, 2.5, 0.4), Color3.fromRGB(30, 130, 60), Enum.Material.SmoothPlastic)
exitSign.Name = "ExitSign"
surfaceText(exitSign, Enum.NormalId.Front, "⬆ EXIT", WHITE)
actionPrompt(exitSign, "Climb Out", "Back to the surface", "TeleportTo", "Surface")

-- Signs over the tunnel openings.
local northSign = block(sewer, CFrame.new(at(0, TUNNEL_HEIGHT + 5, -HUB + 0.5)), Vector3.new(32, 6, 1), Color3.fromRGB(35, 45, 30), Enum.Material.Metal)
surfaceText(northSign, Enum.NormalId.Back, "☣️ THE SEWERS ☣️", Color3.fromRGB(160, 255, 110))
local southSign = block(sewer, CFrame.new(at(0, TUNNEL_HEIGHT + 5, HUB - 0.5)), Vector3.new(32, 6, 1), Color3.fromRGB(35, 45, 30), Enum.Material.Metal)
surfaceText(southSign, Enum.NormalId.Front, ("%gx FLUSHES DOWN HERE!"):format(Config.SewerMultiplier), Color3.fromRGB(255, 220, 90))

-- Toxic barrels, crates and a big valve pipe in the middle room.
for _, spot in { at(corner + 6, 0, -corner - 8), at(corner + 9, 0, -corner - 5), at(corner + 5, 0, -corner - 3) } do
	toxicBarrel(spot)
end
for _, spot in { at(-corner - 8, 0, corner + 6), at(-corner - 5, 0, corner + 9) } do
	toxicBarrel(spot)
end
block(sewer, CFrame.new(at(-corner + 8, 1.5, corner + 10)), Vector3.new(3, 3, 3), WOOD, Enum.Material.WoodPlanks)
block(sewer, CFrame.new(at(-corner + 8, 4.5, corner + 10)) * CFrame.Angles(0, 0.4, 0), Vector3.new(3, 3, 3), WOOD, Enum.Material.WoodPlanks)
local valvePipe = at(-HUB + 7, 0, HUB - 7)
pillar(sewer, valvePipe, HUB_HEIGHT, 3.2, RUST, Enum.Material.CorrodedMetal)
local wheelCenter = valvePipe + Vector3.new(1.9, 5, 0)
part({
	Name = "ValveWheel",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.3, 3, 3),
	CFrame = CFrame.new(wheelCenter),
	Color = Color3.fromRGB(180, 40, 40),
	Material = Enum.Material.Metal,
	Parent = sewer,
})
rat(at(corner + 2, 0, -corner + 12), Vector3.new(-1, 0, 0))
rat(at(-corner + 10, 0, corner - 3), Vector3.new(0, 0, -1))

--------------------------------------------------------------------------------
-- Trees, bushes, flowers, grass and rocks
--------------------------------------------------------------------------------

local nature = group("Nature")

local function plantTree(spot: Vector3, height: number, allowPine: boolean)
	local roll = rng:NextNumber()
	if allowPine and roll < 0.4 then
		pineTree(nature, spot, height * 1.1)
	elseif roll < 0.8 then
		oakTree(nature, spot, height)
	else
		birchTree(nature, spot, height * 0.9)
	end
	-- Keep other trees from growing into this one, and give it some grass at its feet.
	table.insert(clearings, { center = spot, radius = 7 })
	grassTuft(nature, spot + Vector3.new(rng:NextNumber(1.5, 2.5), 0, rng:NextNumber(-2, 2)), rng:NextNumber(1, 1.6))
end

-- A ring of trees around the play area, then a few closer in. The closer ones are
-- never pines and stay well away from the paths, so they don't block the view.
for _ = 1, 42 do
	local spot = randomSpot(150, 260, 6)
	if spot then
		plantTree(spot, rng:NextNumber(18, 28), true)
	end
end
for _ = 1, 14 do
	local spot = randomSpot(45, 140, 12)
	if spot then
		plantTree(spot, rng:NextNumber(15, 21), false)
	end
end

-- Pine trees on top of the hills.
if builtHills then
	for i, hill in hills do
		if i % 3 ~= 0 then
			local spot = hill.center + Vector3.new(0, hill.radius - 1.5, 0)
			pineTree(nature, spot, rng:NextNumber(30, 42))
		end
	end
end

-- Bushes around the buildings and signs.
for _, spot in {
	Vector3.new(shopX - 13, 0, -6),
	Vector3.new(shopX - 13, 0, 6),
	Vector3.new(shopX - 4, 0, -15),
	Vector3.new(shopX + 6, 0, -15),
	Vector3.new(shopX - 4, 0, 15),
	Vector3.new(-31, 0, titleZ),
	Vector3.new(31, 0, titleZ),
	Vector3.new(-22, 0, titleZ - 2),
	Vector3.new(22, 0, titleZ - 2),
	Vector3.new(shrineCenter.X + 10, 0, 13),
	Vector3.new(shrineCenter.X + 10, 0, -13),
	Vector3.new(shrineCenter.X + 18, 0, 0),
	Vector3.new(shrineCenter.X - 10, 0, 13),
	Vector3.new(shrineCenter.X - 10, 0, -13),
	Vector3.new(-30, 0, pondCenter.Z + 6),
	Vector3.new(30, 0, pondCenter.Z + 6),
	(CFrame.lookAt(hatcheryCenter, PLAZA_CENTER) * CFrame.new(-20, 0, 9)).Position,
	(CFrame.lookAt(hatcheryCenter, PLAZA_CENTER) * CFrame.new(20, 0, 9)).Position,
	(CFrame.lookAt(hatcheryCenter, PLAZA_CENTER) * CFrame.new(-13, 0, 14)).Position,
	(CFrame.lookAt(hatcheryCenter, PLAZA_CENTER) * CFrame.new(13, 0, 14)).Position,
} do
	bush(nature, Vector3.new(spot.X, FLOOR, spot.Z), rng:NextNumber(3.5, 5))
end

-- Flower patches: each patch is one kind and color of flower, like a real flower bed.
local flowers = group("Flowers", nature)
for _ = 1, 18 do
	local patch = randomSpot(30, 170, 2)
	if patch then
		local isTulip = rng:NextNumber() < 0.4
		local color = if isTulip then pick(TULIP_COLORS) else pick(DAISY_COLORS)
		for _ = 1, rng:NextInteger(4, 7) do
			local spot = patch + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			if isTulip then
				tulip(flowers, spot, color, rng:NextNumber(0.9, 1.2))
			else
				daisy(flowers, spot, color, rng:NextNumber(0.9, 1.2))
			end
		end
		grassTuft(flowers, patch + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), 1.2)
	end
end

-- Grass tufts scattered everywhere.
local tufts = group("GrassTufts", nature)
for _ = 1, 90 do
	local spot = randomSpot(12, 280, 0.5)
	if spot then
		grassTuft(tufts, spot, rng:NextNumber(0.9, 1.8))
	end
end

-- A few boulders, some with little plants around them.
for _ = 1, 14 do
	local spot = randomSpot(50, 240, 3)
	if spot then
		boulder(nature, spot, rng:NextNumber(3, 6), rng:NextNumber() < 0.3)
		grassTuft(nature, spot + Vector3.new(rng:NextNumber(2, 3.5), 0, rng:NextNumber(-2, 2)), 1.4)
	end
end

--------------------------------------------------------------------------------
-- Put it in the world and start things moving
--------------------------------------------------------------------------------

map.Parent = workspace

-- The eggs gently bob up and down, each a little after the last.
for i, egg in bobbingEggs do
	local bob = TweenService:Create(
		egg,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = egg.CFrame + Vector3.new(0, 0.6, 0) }
	)
	task.delay(i * 0.35, function()
		bob:Play()
	end)
end

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
