-- Builds the starter map: a sunny grass field with a stone plaza where players spawn.
--
-- Layout (players spawn in the middle of the plaza, facing the title sign):
--   front: the SELL pad with a big sign above it, and the SKIBIDI SIMULATOR sign behind
--   left:  the Plunger Shop                right: the Rebirth shrine
--   back:  a pond with reeds, lily pads and benches
-- Oak, pine and birch trees, flower patches, bushes, rocks and lamp posts fill in
-- the rest, and grassy hills (made of Terrain) with pine trees circle the area.
--
-- Want to change the map by hand? Press Play, find "Map" in Workspace in the
-- Explorer, right-click > Copy, press Stop, then right-click Workspace > Paste Into.
-- When a Model named "Map" is already in Workspace, this script doesn't build another.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

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
	local distance = hillRng:NextNumber(230, 290)
	local radius = hillRng:NextNumber(40, 70)
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

local sellCenter = Vector3.new(0, FLOOR, -48)
local shopX = -60
local shrineCenter = Vector3.new(60, FLOOR, 0)
local titleZ = -88
local pondCenter = Vector3.new(0, FLOOR, 62)
local pondRadius = 17

-- Areas to keep clear so nothing grows on the buildings or paths.
local clearings = {
	{ center = Vector3.new(0, 0, 0), radius = 24 }, -- plaza
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
for _ = 1, 30 do
	local size = rng:NextNumber(8, 18)
	local spot = randomSpot(20, 200, size)
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

-- Stone paths from the plaza to the sell pad, shop, rebirth shrine and pond,
-- with little stones along their edges.
local paths = group("Paths", ground)
for _, path in {
	{ center = Vector3.new(0, 0, -28.5), size = Vector3.new(9, 0, 21) }, -- sell
	{ center = Vector3.new(0, 0, 32), size = Vector3.new(9, 0, 28) }, -- pond
	{ center = Vector3.new(-32, 0, 0), size = Vector3.new(28, 0, 9) }, -- shop
	{ center = Vector3.new(32, 0, 0), size = Vector3.new(28, 0, 9) }, -- rebirth
} do
	block(paths, CFrame.new(path.center + Vector3.new(0, FLOOR + 0.05, 0)), Vector3.new(path.size.X, 0.4, path.size.Z), PATH, Enum.Material.Cobblestone)

	local runsAlongZ = path.size.X < path.size.Z
	local length = if runsAlongZ then path.size.Z else path.size.X
	local halfWidth = (if runsAlongZ then path.size.X else path.size.Z) / 2 + 0.6
	for along = -length / 2 + 1.5, length / 2 - 1.5, 2.2 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.7 then
				local offset = if runsAlongZ then Vector3.new(side * halfWidth, 0, along) else Vector3.new(along, 0, side * halfWidth)
				local size = rng:NextNumber(0.7, 1.3)
				block(
					paths,
					CFrame.new(path.center + offset + Vector3.new(0, FLOOR + 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
					Vector3.new(size, 0.45, size * 0.8),
					darken(STONE, rng:NextNumber(0, 0.2)),
					Enum.Material.Rock
				)
			end
		end
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

local sellArea = group("SellArea")

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
	pillar(lamps, bottom, 0.8, 1.4, DARK_METAL, Enum.Material.Metal)
	pillar(lamps, bottom + Vector3.new(0, 0.8, 0), 8.4, 0.45, DARK_METAL, Enum.Material.Metal)
	local lanternGlass = block(lamps, CFrame.new(bottom + Vector3.new(0, 10, 0)), Vector3.new(1.3, 1.8, 1.3), Color3.fromRGB(255, 235, 190), Enum.Material.Glass)
	lanternGlass.Transparency = 0.4
	local bulb = decor(ball(lamps, bottom + Vector3.new(0, 10, 0), 0.7, LAMP_GLOW, Enum.Material.Neon))
	addLight(bulb, LAMP_GLOW, 18, 1.2)
	block(lamps, CFrame.new(bottom + Vector3.new(0, 11.1, 0)), Vector3.new(1.8, 0.35, 1.8), DARK_METAL, Enum.Material.Metal)
	ball(lamps, bottom + Vector3.new(0, 11.5, 0), 0.5, DARK_METAL, Enum.Material.Metal)
end

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
for _ = 1, 38 do
	local spot = randomSpot(75, 150, 6)
	if spot then
		plantTree(spot, rng:NextNumber(18, 28), true)
	end
end
for _ = 1, 10 do
	local spot = randomSpot(35, 75, 12)
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
	Vector3.new(-30, 0, 68),
	Vector3.new(30, 0, 68),
} do
	bush(nature, spot + Vector3.new(0, FLOOR, 0), rng:NextNumber(3.5, 5))
end

-- Flower patches: each patch is one kind and color of flower, like a real flower bed.
local flowers = group("Flowers", nature)
for _ = 1, 15 do
	local patch = randomSpot(24, 90, 2)
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
for _ = 1, 80 do
	local spot = randomSpot(12, 170, 0.5)
	if spot then
		grassTuft(tufts, spot, rng:NextNumber(0.9, 1.8))
	end
end

-- A few boulders, some with little plants around them.
for _ = 1, 10 do
	local spot = randomSpot(40, 140, 3)
	if spot then
		boulder(nature, spot, rng:NextNumber(3, 6), rng:NextNumber() < 0.3)
		grassTuft(nature, spot + Vector3.new(rng:NextNumber(2, 3.5), 0, rng:NextNumber(-2, 2)), 1.4)
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
