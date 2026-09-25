-- Client side of the simulator: the coin and Flush counters, the shop, the rebirth
-- and pets menus, egg hatching, pets following players, pop-up messages, sounds,
-- the plunger animation and the glowing guide to the sell pad. The server owns all the numbers; this script only shows them and
-- asks the server when the player wants to buy something.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

print("Skibidi Simulator: GameClient is running")

-- If the game is set up wrong in Studio, show what to fix in big red text on
-- the screen (the Output window is easy to miss), then stop this script.
local function showSetupProblem(message: string): never
	local gui = Instance.new("ScreenGui")
	gui.Name = "SetupProblemClient"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 210) -- below the server's message, if there is one
	label.Size = UDim2.new(0.8, 0, 0, 120)
	label.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	label.Font = Enum.Font.FredokaOne
	label.Text = "SETUP PROBLEM (client)\n" .. message
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
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
	showSetupProblem("Config is an older version. Paste in the newest Config code too.")
end

-- The server makes the Remotes folder, so if it never shows up, GameServer isn't running.
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
	showSetupProblem(
		'GameServer isn\'t running. It must be a Script (not a LocalScript) inside ServerScriptService, with all of its code pasted in.'
	)
end
local buyRemote = Remotes:WaitForChild("BuyItem")
local rebirthRemote = Remotes:WaitForChild("Rebirth")
local notifyRemote = Remotes:WaitForChild("Notify")
local petRemote = Remotes:WaitForChild("PetAction", 10)
local hatchedRemote = Remotes:WaitForChild("Hatched", 10)
if not (petRemote and hatchedRemote) then
	showSetupProblem("GameServer is an older version. Paste in the newest GameServer code too.")
end

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local SOFT_WHITE = Color3.fromRGB(200, 205, 220)
local PANEL = Color3.fromRGB(28, 32, 46)
local PANEL_LIGHT = Color3.fromRGB(46, 52, 72)
local GREEN = Color3.fromRGB(60, 200, 90)
local RED = Color3.fromRGB(230, 70, 70)
local BLUE = Color3.fromRGB(60, 150, 255)
local PURPLE = Color3.fromRGB(160, 80, 255)
local GRAY = Color3.fromRGB(95, 100, 115)
local GOLD = Color3.fromRGB(255, 205, 60)
local ORANGE = Color3.fromRGB(255, 150, 50)

-- Reads one of the numbers the server puts on the player (Coins, Flushes, ...).
local function stat(name: string): number
	return player:GetAttribute(name) or 0
end

--------------------------------------------------------------------------------
-- UI building helpers
--------------------------------------------------------------------------------

-- Creates an Instance, sets its properties, and puts the children inside it.
local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function withDefaults(defaults: { [string]: any }, props: { [string]: any })
	local merged = table.clone(defaults)
	for key, value in props do
		merged[key] = value
	end
	return merged
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local newTween = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	newTween:Play()
	return newTween
end

local function rounded(radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function border(color: Color3?, thickness: number?)
	return make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
	})
end

local function textLabel(props: { [string]: any })
	return make(
		"TextLabel",
		withDefaults({
			BackgroundTransparency = 1,
			Font = FONT,
			TextColor3 = WHITE,
			TextScaled = true,
			TextStrokeTransparency = 0.7,
		}, props)
	)
end

-- A rounded button that grows a little when you hover over it and squishes when pressed.
local function button(text: string, color: Color3, props: { [string]: any })
	local newButton = make(
		"TextButton",
		withDefaults({
			BackgroundColor3 = color,
			Font = FONT,
			Text = text,
			TextColor3 = WHITE,
			TextScaled = true,
			TextStrokeTransparency = 0.6,
		}, props),
		{
			rounded(10),
			border(),
			make("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}
	)
	local scale = make("UIScale", { Parent = newButton })
	newButton.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.05 })
	end)
	newButton.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	newButton.MouseButton1Down:Connect(function()
		tween(scale, 0.08, { Scale = 0.92 })
	end)
	newButton.MouseButton1Up:Connect(function()
		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	return newButton
end

local gui = make("ScreenGui", {
	Name = "SimulatorUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Sounds built into Roblox, so nothing needs uploading.
local SPLASH_SOUND = "rbxasset://sounds/impact_water.mp3"
local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local function playSound(soundId: string, volume: number, speed: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.Parent = gui
	sound:Play()
	task.delay(3, function()
		sound:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Messages and "+5" pop-ups
--------------------------------------------------------------------------------

local notice = textLabel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0.8, 0, 0, 36),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ZIndex = 10,
	Parent = gui,
})

local noticeCount = 0
local function showNotice(message: string, success: boolean)
	noticeCount += 1
	local thisNotice = noticeCount
	notice.Text = message
	notice.TextColor3 = if success then GREEN else RED
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.3
	if success then
		playSound(PING_SOUND, 0.4)
	end

	task.delay(2.5, function()
		if thisNotice == noticeCount then -- a newer message hasn't replaced this one
			TweenService:Create(notice, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function showGainPopup(amount: number)
	local mouse = UserInputService:GetMouseLocation()
	local popup = textLabel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(mouse.X + math.random(-30, 30), mouse.Y - 20),
		Size = UDim2.fromOffset(140, 34),
		Rotation = math.random(-10, 10),
		Text = "+" .. Format.number(amount) .. " 🚽",
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.2,
		ZIndex = 10,
		Parent = gui,
	})
	local tween = TweenService:Create(popup, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position - UDim2.fromOffset(0, 70),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end

-- Asks the server to buy something or rebirth, shows its answer, and returns whether it worked.
local waitingForServer = false
local function askServer(remote: RemoteFunction, ...): boolean
	if waitingForServer then
		return false
	end
	waitingForServer = true
	local success, ok, message = pcall(remote.InvokeServer, remote, ...)
	waitingForServer = false

	if not success then
		showNotice("Something went wrong, try again.", false)
		return false
	end
	showNotice(message, ok)
	return ok
end

--------------------------------------------------------------------------------
-- Left sidebar: stats and menu buttons
--------------------------------------------------------------------------------

local sidebar = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(210, 316),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Shrink the sidebar on small (phone) screens so it doesn't cover the game.
local sidebarScale = make("UIScale", { Parent = sidebar })
local function fitSidebarToScreen()
	sidebarScale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 700, 0.6, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitSidebarToScreen)
fitSidebarToScreen()

-- A rounded box with text in it. The fill bar behind the text is used by the Flush meter.
local function statBox(color: Color3, order: number)
	local box = make("Frame", {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = sidebar,
	}, { rounded() })
	local outline = border(color, 2)
	outline.Parent = box

	local fill = make("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(0, 1),
		Parent = box,
	}, { rounded() })

	local text = textLabel({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = box,
	})
	return text, fill, outline
end

local coinsText, _, coinsOutline = statBox(GOLD, 1)
local flushText, flushFill = statBox(BLUE, 2)
local rebirthsText = statBox(PURPLE, 3)

local shopButton = button("🛒 Shop", GREEN, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 48), Parent = sidebar })
local petsButton = button("🐾 Pets", ORANGE, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 48), Parent = sidebar })
local rebirthButton = button("⭐ Rebirth", PURPLE, { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 48), Parent = sidebar })

--------------------------------------------------------------------------------
-- Pop-up windows
--------------------------------------------------------------------------------

local windows = {}
local windowScales = {}

local function makeWindow(title: string, color: Color3, maxSize: Vector2)
	local window = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundColor3 = PANEL,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}, {
		rounded(16),
		border(color, 3),
		make("UISizeConstraint", { MaxSize = maxSize }),
	})

	textLabel({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 38),
		Text = title,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})

	local close = button("X", RED, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(38, 38),
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)

	table.insert(windows, window)
	windowScales[window] = make("UIScale", { Parent = window })
	return window
end

-- Shows a window with a little pop, closing any other one.
local function openWindow(window: Frame)
	if window.Visible then
		return
	end
	for _, other in windows do
		other.Visible = false
	end
	window.Visible = true
	windowScales[window].Scale = 0.85
	tween(windowScales[window], 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Opens a window, or closes it if it's already open.
local function toggleWindow(window: Frame)
	if window.Visible then
		window.Visible = false
	else
		openWindow(window)
	end
end

--------------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------------

local shopWindow = makeWindow("🛒 Shop", GREEN, Vector2.new(500, 380))
local shopRows = {}

local tabBar = make("Frame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
	Parent = shopWindow,
}, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
})

-- One scrolling list of items for a shop category ("Plunger" or "Tank").
local function buildShopList(category: string, items, describe: (any) -> string)
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 100),
		Size = UDim2.new(1, -32, 1, -116),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		Visible = false,
		Parent = shopWindow,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	for level, item in items do
		local row = make("Frame", {
			BackgroundColor3 = PANEL_LIGHT,
			LayoutOrder = level,
			Size = UDim2.new(1, -10, 0, 56),
			Parent = list,
		}, { rounded(10) })

		textLabel({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.6, -12, 0, 24),
			Text = item.Name,
			TextColor3 = item.Color or WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		textLabel({
			Position = UDim2.fromOffset(12, 31),
			Size = UDim2.new(0.6, -12, 0, 19),
			Text = describe(item),
			TextColor3 = SOFT_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local buyButton = button("", GRAY, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.38, 0, 0, 40),
			Parent = row,
		})
		buyButton.Activated:Connect(function()
			askServer(buyRemote, category, level)
		end)

		table.insert(shopRows, { category = category, level = level, item = item, button = buyButton })
	end

	return list
end

local plungerList = buildShopList("Plunger", Config.Plungers, function(item)
	return ("+%s Flushes per click"):format(Format.number(item.Power))
end)
local tankList = buildShopList("Tank", Config.Tanks, function(item)
	return ("Holds %s Flushes"):format(Format.number(item.Capacity))
end)

local plungerTab = button("Plungers", BLUE, { Size = UDim2.new(0.5, -4, 1, 0), Parent = tabBar })
local tankTab = button("Tanks", PANEL_LIGHT, { Size = UDim2.new(0.5, -4, 1, 0), Parent = tabBar })

local function selectTab(list: ScrollingFrame)
	plungerList.Visible = list == plungerList
	tankList.Visible = list == tankList
	plungerTab.BackgroundColor3 = if list == plungerList then BLUE else PANEL_LIGHT
	tankTab.BackgroundColor3 = if list == tankList then BLUE else PANEL_LIGHT
end

plungerTab.Activated:Connect(function()
	selectTab(plungerList)
end)
tankTab.Activated:Connect(function()
	selectTab(tankList)
end)
selectTab(plungerList)

local function refreshShop()
	local coins = stat("Coins")
	for _, row in shopRows do
		local current = stat(row.category .. "Level")
		if row.level == current then
			row.button.Text = "Equipped"
			row.button.BackgroundColor3 = BLUE
		elseif row.level < current then
			row.button.Text = "Owned"
			row.button.BackgroundColor3 = GRAY
		elseif coins >= row.item.Price then
			row.button.Text = "Buy 💰" .. Format.number(row.item.Price)
			row.button.BackgroundColor3 = GREEN
		else
			row.button.Text = "💰" .. Format.number(row.item.Price)
			row.button.BackgroundColor3 = GRAY
		end
	end
end

--------------------------------------------------------------------------------
-- Rebirth menu
--------------------------------------------------------------------------------

local rebirthWindow = makeWindow("⭐ Rebirth", PURPLE, Vector2.new(420, 300))

textLabel({
	Position = UDim2.fromOffset(16, 58),
	Size = UDim2.new(1, -32, 0, 52),
	Text = "Rebirthing resets your coins, plungers and tanks, but you get more Flushes from every click forever!",
	TextColor3 = SOFT_WHITE,
	Parent = rebirthWindow,
})

local multiplierText = textLabel({
	Position = UDim2.fromOffset(16, 120),
	Size = UDim2.new(1, -32, 0, 34),
	TextColor3 = GOLD,
	Parent = rebirthWindow,
})

local rebirthCostText = textLabel({
	Position = UDim2.fromOffset(16, 158),
	Size = UDim2.new(1, -32, 0, 28),
	Parent = rebirthWindow,
})

local confirmRebirthButton = button("Rebirth!", GRAY, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0.6, 0, 0, 48),
	Parent = rebirthWindow,
})

confirmRebirthButton.Activated:Connect(function()
	if askServer(rebirthRemote) then
		rebirthWindow.Visible = false
	end
end)

local function refreshRebirth()
	local rebirths = stat("Rebirths")
	local cost = Config.getRebirthCost(rebirths)
	multiplierText.Text = ("Multiplier: %gx  (next: %gx)"):format(
		Config.getMultiplier(rebirths),
		Config.getMultiplier(rebirths + 1)
	)
	rebirthCostText.Text = "Cost: 💰" .. Format.number(cost)
	confirmRebirthButton.BackgroundColor3 = if stat("Coins") >= cost then GREEN else GRAY
end

--------------------------------------------------------------------------------
-- Pet models (built from parts, so nothing needs uploading)
--------------------------------------------------------------------------------

local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYLINDER = Enum.PartType.Cylinder
local FACE_FORWARD = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder to face the front
local STAND_UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder to stand upright
local PET_BLACK = Color3.fromRGB(20, 20, 25)
local SUIT = Color3.fromRGB(38, 38, 48)

-- Builds a pet facing -Z, centered on an invisible root part.
local function buildPet(name: string): Model
	local info = Config.Pets[name]
	local scale = (info and info.Scale) or 1
	local model = Instance.new("Model")
	model.Name = name

	local function add(shape: Enum.PartType, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, turn: CFrame?): Part
		local piece = Instance.new("Part")
		piece.Shape = shape
		piece.Size = size * scale
		piece.CFrame = CFrame.new(position * scale) * (turn or CFrame.identity)
		piece.Color = color
		piece.Material = material or Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.Parent = model
		return piece
	end
	local function eyes(y: number, z: number, spread: number, size: number, color: Color3?)
		for _, x in { -spread, spread } do
			add(BALL, Vector3.one * size, Vector3.new(x, y, z), color or PET_BLACK)
		end
	end
	-- The body Cameraman, Speakerman and TV Man share: a little suit and tie.
	local function suit(tie: Color3)
		add(BLOCK, Vector3.new(1.2, 1.3, 0.75), Vector3.new(0, -0.35, 0), SUIT)
		add(BLOCK, Vector3.new(0.4, 0.55, 0.05), Vector3.new(0, -0.05, -0.39), Color3.new(1, 1, 1))
		add(BLOCK, Vector3.new(0.14, 0.5, 0.06), Vector3.new(0, -0.1, -0.42), tie)
		for _, x in { -0.72, 0.72 } do
			add(BLOCK, Vector3.new(0.3, 1.05, 0.35), Vector3.new(x, -0.4, 0), SUIT)
		end
		for _, x in { -0.28, 0.28 } do
			add(BLOCK, Vector3.new(0.4, 0.55, 0.45), Vector3.new(x, -1.25, 0), SUIT)
		end
	end

	local root = add(BLOCK, Vector3.one * 0.4, Vector3.zero, PET_BLACK)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	if name == "Rubber Ducky" then
		local yellow = Color3.fromRGB(255, 215, 40)
		add(BALL, Vector3.one * 1.8, Vector3.new(0, 0, 0.1), yellow)
		add(BALL, Vector3.one * 1.2, Vector3.new(0, 0.95, -0.45), yellow)
		add(BALL, Vector3.one * 0.6, Vector3.new(0, 0.35, 0.95), yellow)
		add(BLOCK, Vector3.new(0.55, 0.22, 0.55), Vector3.new(0, 0.85, -1.1), Color3.fromRGB(255, 140, 30))
		eyes(1.15, -0.95, 0.28, 0.2)
	elseif name == "Soap Bunny" then
		local fur = Color3.fromRGB(250, 220, 235)
		local pink = Color3.fromRGB(255, 150, 190)
		add(BALL, Vector3.one * 1.6, Vector3.new(0, 0, 0.15), fur)
		add(BALL, Vector3.one * 1.2, Vector3.new(0, 0.9, -0.35), fur)
		for _, side in { -1, 1 } do
			local tilt = CFrame.Angles(0, 0, -0.15 * side)
			add(BLOCK, Vector3.new(0.32, 1.1, 0.18), Vector3.new(0.28 * side, 1.85, -0.3), fur, nil, tilt)
			add(BLOCK, Vector3.new(0.16, 0.8, 0.05), Vector3.new(0.28 * side, 1.85, -0.4), pink, nil, tilt)
		end
		eyes(1, -0.88, 0.25, 0.18)
		add(BALL, Vector3.one * 0.16, Vector3.new(0, 0.82, -0.95), pink)
		-- soap bubbles
		add(BALL, Vector3.one * 0.5, Vector3.new(0.85, 1.5, 0.3), Color3.fromRGB(200, 235, 255), Enum.Material.Glass).Transparency = 0.5
		add(BALL, Vector3.one * 0.35, Vector3.new(-0.75, 1.9, 0.5), Color3.fromRGB(200, 235, 255), Enum.Material.Glass).Transparency = 0.5
	elseif name == "Plunger Pup" then
		local fur = Color3.fromRGB(175, 120, 70)
		add(BALL, Vector3.one * 1.5, Vector3.new(0, 0, 0.3), fur)
		add(BALL, Vector3.one * 1.25, Vector3.new(0, 0.75, -0.5), fur)
		add(BALL, Vector3.one * 0.55, Vector3.new(0, 0.6, -1.1), Color3.fromRGB(215, 170, 120))
		add(BALL, Vector3.one * 0.2, Vector3.new(0, 0.72, -1.36), PET_BLACK)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.3, 0.7, 0.15), Vector3.new(0.62 * side, 0.6, -0.45), Color3.fromRGB(110, 70, 40))
		end
		eyes(0.95, -1.02, 0.26, 0.17)
		add(BALL, Vector3.one * 0.35, Vector3.new(0, 0.35, 1.05), fur)
		-- a little plunger hat
		add(CYLINDER, Vector3.new(0.35, 0.9, 0.9), Vector3.new(0, 1.45, -0.5), Color3.fromRGB(230, 60, 60), Enum.Material.Rubber, STAND_UP)
		add(CYLINDER, Vector3.new(0.9, 0.15, 0.15), Vector3.new(0, 2.05, -0.5), Color3.fromRGB(150, 100, 60), Enum.Material.Wood, STAND_UP)
	elseif name == "Sewer Rat" then
		local fur = Color3.fromRGB(135, 130, 135)
		local pink = Color3.fromRGB(240, 160, 170)
		add(BALL, Vector3.one * 1.4, Vector3.new(0, 0, 0.2), fur)
		add(BALL, Vector3.one * 0.95, Vector3.new(0, 0.35, -0.75), fur)
		add(BALL, Vector3.one * 0.45, Vector3.new(0, 0.25, -1.2), fur)
		add(BALL, Vector3.one * 0.16, Vector3.new(0, 0.3, -1.42), pink)
		for _, side in { -1, 1 } do
			add(CYLINDER, Vector3.new(0.08, 0.55, 0.55), Vector3.new(0.35 * side, 0.85, -0.65), pink, nil, FACE_FORWARD)
		end
		eyes(0.5, -1.12, 0.2, 0.14, Color3.fromRGB(200, 30, 30))
		add(CYLINDER, Vector3.new(1.5, 0.12, 0.12), Vector3.new(0, 0.2, 1.3), pink, nil, FACE_FORWARD * CFrame.Angles(0, 0, 0.35))
	elseif name == "Cameraman" or name == "Titan Cameraman" then
		local titan = name == "Titan Cameraman"
		local gold = Color3.fromRGB(255, 195, 50)
		local headColor = if titan then gold else Color3.fromRGB(60, 60, 66)
		local headMaterial = if titan then Enum.Material.Foil else Enum.Material.SmoothPlastic
		suit(if titan then gold else Color3.fromRGB(200, 30, 40))
		add(BLOCK, Vector3.new(1.3, 0.95, 1), Vector3.new(0, 0.75, 0), headColor, headMaterial)
		add(BLOCK, Vector3.new(0.6, 0.15, 0.2), Vector3.new(0, 1.3, 0), headColor, headMaterial)
		add(CYLINDER, Vector3.new(0.45, 0.75, 0.75), Vector3.new(0, 0.75, -0.7), Color3.fromRGB(150, 150, 160), Enum.Material.Metal, FACE_FORWARD)
		add(
			CYLINDER,
			Vector3.new(0.06, 0.55, 0.55),
			Vector3.new(0, 0.75, -0.94),
			if titan then Color3.fromRGB(80, 220, 255) else PET_BLACK,
			if titan then Enum.Material.Neon else Enum.Material.Glass,
			FACE_FORWARD
		)
		add(BALL, Vector3.one * 0.18, Vector3.new(0.45, 1.1, -0.5), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		if titan then
			for _, side in { -1, 1 } do
				add(BLOCK, Vector3.new(0.5, 0.25, 0.8), Vector3.new(0.72 * side, 0.2, 0), gold, Enum.Material.Foil)
			end
		end
	elseif name == "Speakerman" then
		suit(Color3.fromRGB(40, 110, 230))
		add(BLOCK, Vector3.new(1.25, 1.45, 0.95), Vector3.new(0, 0.95, 0), Color3.fromRGB(25, 25, 28))
		for _, woofer in { { y = 1.25, size = 0.85 }, { y = 0.6, size = 0.5 } } do
			add(CYLINDER, Vector3.new(0.08, woofer.size, woofer.size), Vector3.new(0, woofer.y, -0.49), Color3.fromRGB(95, 95, 100), Enum.Material.Metal, FACE_FORWARD)
			add(CYLINDER, Vector3.new(0.1, woofer.size * 0.35, woofer.size * 0.35), Vector3.new(0, woofer.y, -0.53), PET_BLACK, nil, FACE_FORWARD)
		end
	elseif name == "TV Man" then
		suit(Color3.fromRGB(140, 60, 220))
		add(BLOCK, Vector3.new(1.7, 1.15, 0.9), Vector3.new(0, 0.85, 0), Color3.fromRGB(70, 70, 76))
		add(BLOCK, Vector3.new(1.4, 0.85, 0.05), Vector3.new(0, 0.85, -0.46), Color3.fromRGB(80, 200, 255), Enum.Material.Neon)
		for _, side in { -1, 1 } do
			add(CYLINDER, Vector3.new(0.8, 0.07, 0.07), Vector3.new(0.3 * side, 1.75, 0), PET_BLACK, nil, CFrame.Angles(0, 0, math.rad(90 - 25 * side)))
		end
	end

	if info and info.Rarity == "Legendary" then
		Instance.new("Sparkles").Parent = root
	end
	return model
end

local function buildEggModel(color: Color3): Part
	local egg = Instance.new("Part")
	egg.Size = Vector3.new(3, 3.9, 3)
	egg.Color = color
	egg.Material = Enum.Material.Neon
	egg.Anchored = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- stretches to the part's size, making an egg shape
	mesh.Parent = egg
	return egg
end

-- Reads a player's pet list, which the server stores on them as text.
local function readPets(owner: Player): { any }
	local raw = owner:GetAttribute("Pets")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, pets = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(pets) == "table" then pets else {}
end

-- 1.5 -> "1.5", 2 -> "2"
local function formatMultiplier(value: number): string
	local text = string.format("%.2f", value):gsub("%.?0+$", "")
	return text
end

--------------------------------------------------------------------------------
-- Pets menu
--------------------------------------------------------------------------------

local petsWindow = makeWindow("🐾 Pets", ORANGE, Vector2.new(560, 420))

local petsHeader = textLabel({
	Position = UDim2.fromOffset(16, 58),
	Size = UDim2.new(1, -180, 0, 28),
	TextColor3 = SOFT_WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = petsWindow,
})
local equipBestButton = button("⭐ Equip Best", GREEN, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 54),
	Size = UDim2.fromOffset(150, 36),
	Parent = petsWindow,
})
local petsList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 98),
	Size = UDim2.new(1, -32, 1, -114),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	Parent = petsWindow,
}, {
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(160, 112),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local noPetsText = textLabel({
	Position = UDim2.fromOffset(16, 150),
	Size = UDim2.new(1, -32, 0, 60),
	Text = "No pets yet! Hatch eggs at the 🐾 PETS sign, front-left of spawn.",
	TextColor3 = SOFT_WHITE,
	Parent = petsWindow,
})

local confirmingDelete: Instance? = nil

local function refreshPetsMenu()
	for _, child in petsList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local pets = readPets(player)
	local equipped = 0
	for _, pet in pets do
		if pet.Equipped then
			equipped += 1
		end
	end
	petsHeader.Text = ("Equipped %d/%d  •  Boost x%s  •  %d/%d pets"):format(
		equipped,
		Config.MaxEquippedPets,
		formatMultiplier(Config.getPetMultiplier(pets)),
		#pets,
		Config.MaxPets
	)
	noPetsText.Visible = #pets == 0

	-- Equipped pets first, then the strongest.
	local order = {}
	for index, pet in pets do
		if Config.Pets[pet.Name] then
			table.insert(order, index)
		end
	end
	table.sort(order, function(a, b)
		local petA, petB = pets[a], pets[b]
		if petA.Equipped ~= petB.Equipped then
			return petA.Equipped == true
		end
		local boostA, boostB = Config.Pets[petA.Name].Boost, Config.Pets[petB.Name].Boost
		if boostA ~= boostB then
			return boostA > boostB
		end
		return a < b
	end)

	for rank, index in order do
		local pet = pets[index]
		local info = Config.Pets[pet.Name]
		local rarityColor = Config.Rarities[info.Rarity]
		local cell = make("Frame", {
			BackgroundColor3 = PANEL_LIGHT,
			LayoutOrder = rank,
			Parent = petsList,
		}, {
			rounded(10),
			border(if pet.Equipped then GREEN else rarityColor, if pet.Equipped then 3 else 1.5),
		})
		textLabel({
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 26),
			Text = info.Icon .. " " .. pet.Name,
			TextColor3 = rarityColor,
			Parent = cell,
		})
		textLabel({
			Position = UDim2.fromOffset(8, 34),
			Size = UDim2.new(1, -16, 0, 20),
			Text = ("%s  •  +%d%%"):format(info.Rarity:upper(), math.floor(info.Boost * 100 + 0.5)),
			TextColor3 = SOFT_WHITE,
			Parent = cell,
		})

		local equipButton = button(if pet.Equipped then "Unequip" else "Equip", if pet.Equipped then GRAY else GREEN, {
			Position = UDim2.fromOffset(8, 64),
			Size = UDim2.new(1, -62, 0, 38),
			Parent = cell,
		})
		equipButton.Activated:Connect(function()
			askServer(petRemote, if pet.Equipped then "Unequip" else "Equip", index, pet.Name)
		end)

		local deleteButton = button("🗑", RED, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 64),
			Size = UDim2.fromOffset(44, 38),
			Parent = cell,
		})
		deleteButton.Activated:Connect(function()
			-- Press twice to delete, so you can't lose a pet by accident.
			if confirmingDelete ~= deleteButton then
				confirmingDelete = deleteButton
				deleteButton.Text = "Sure?"
				task.delay(2, function()
					if confirmingDelete == deleteButton then
						confirmingDelete = nil
						deleteButton.Text = "🗑"
					end
				end)
				return
			end
			confirmingDelete = nil
			askServer(petRemote, "Delete", index, pet.Name)
		end)
	end
end

equipBestButton.Activated:Connect(function()
	askServer(petRemote, "EquipBest")
end)

--------------------------------------------------------------------------------
-- Hatching animation
--------------------------------------------------------------------------------

local hatchOverlay = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
})
local hatchView = make("ViewportFrame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(160, 160, 170),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-1, -2, 1),
	ZIndex = 21,
	Parent = hatchOverlay,
}, {
	make("UIAspectRatioConstraint", { AspectRatio = 1 }),
})
local hatchCamera = make("Camera", {
	FieldOfView = 40,
	CFrame = CFrame.lookAt(Vector3.new(0, 0.3, -8), Vector3.zero),
	Parent = hatchView,
})
hatchView.CurrentCamera = hatchCamera
local hatchTitle = textLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.66),
	Size = UDim2.fromScale(0.9, 0.08),
	TextStrokeTransparency = 0.3,
	ZIndex = 21,
	Parent = hatchOverlay,
})
local hatchInfo = textLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.75),
	Size = UDim2.fromScale(0.9, 0.05),
	TextColor3 = SOFT_WHITE,
	ZIndex = 21,
	Parent = hatchOverlay,
})
local hatchFlash = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 22,
	Parent = hatchOverlay,
})

local hatching = false
local function playHatch(eggName: string, petName: string)
	while hatching do
		task.wait(0.1)
	end
	hatching = true
	local egg = Config.getEgg(eggName)
	local info = Config.Pets[petName]
	for _, window in windows do
		window.Visible = false
	end

	hatchOverlay.Visible = true
	tween(hatchOverlay, 0.3, { BackgroundTransparency = 0.35 })
	hatchTitle.Text = ("Hatching %s..."):format(eggName)
	hatchTitle.TextColor3 = WHITE
	hatchInfo.Text = ""

	-- Shake the egg harder and harder...
	local eggModel = buildEggModel(if egg then egg.Color else WHITE)
	eggModel.Parent = hatchView
	local started = os.clock()
	while os.clock() - started < 1.8 do
		local t = os.clock() - started
		eggModel.CFrame = CFrame.Angles(0, 0, math.sin(t * (10 + t * 14)) * 0.08 * (1 + t * 1.5))
		RunService.RenderStepped:Wait()
	end
	eggModel:Destroy()

	-- ...then pop! Show the pet spinning around.
	hatchFlash.BackgroundTransparency = 0
	tween(hatchFlash, 0.5, { BackgroundTransparency = 1 })
	playSound(SPLASH_SOUND, 0.6, 1.6)
	playSound(PING_SOUND, 0.5)
	local pet = buildPet(petName)
	pet.Parent = hatchView
	if info then
		hatchTitle.Text = ("You hatched %s %s!"):format(info.Icon, petName)
		hatchTitle.TextColor3 = Config.Rarities[info.Rarity]
		hatchInfo.Text = ("%s  •  +%d%% Flushes"):format(info.Rarity:upper(), math.floor(info.Boost * 100 + 0.5))
	end
	started = os.clock()
	while os.clock() - started < 2.2 do
		pet:PivotTo(CFrame.Angles(0, (os.clock() - started) * 2, 0))
		RunService.RenderStepped:Wait()
	end

	pet:Destroy()
	tween(hatchOverlay, 0.25, { BackgroundTransparency = 1 })
	task.wait(0.25)
	hatchOverlay.Visible = false
	hatching = false
end

hatchedRemote.OnClientEvent:Connect(function(eggName, petName)
	task.spawn(playHatch, eggName, petName)
end)

--------------------------------------------------------------------------------
-- Pets following players around (everyone's pets are drawn on your screen)
--------------------------------------------------------------------------------

local petFolder = Instance.new("Folder")
petFolder.Name = "PetVisuals"
petFolder.Parent = workspace

type PetVisual = { key: string, models: { Model }, spots: { CFrame } }
local petVisuals: { [Player]: PetVisual } = {}

local function removeFollowers(owner: Player)
	local visual = petVisuals[owner]
	if visual then
		for _, model in visual.models do
			model:Destroy()
		end
	end
	petVisuals[owner] = nil
end

local function refreshFollowers(owner: Player)
	local names = {}
	for _, pet in readPets(owner) do
		if pet.Equipped and Config.Pets[pet.Name] then
			table.insert(names, pet.Name)
		end
	end
	local key = table.concat(names, ",")
	local visual = petVisuals[owner]
	if visual and visual.key == key then
		return
	end

	removeFollowers(owner)
	local models = {}
	for _, name in names do
		local model = buildPet(name)
		model.Parent = petFolder
		table.insert(models, model)
	end
	petVisuals[owner] = { key = key, models = models, spots = {} }
end

local function watchPets(owner: Player)
	owner:GetAttributeChangedSignal("Pets"):Connect(function()
		refreshFollowers(owner)
	end)
	refreshFollowers(owner)
end
Players.PlayerAdded:Connect(watchPets)
for _, other in Players:GetPlayers() do
	watchPets(other)
end
Players.PlayerRemoving:Connect(removeFollowers)

RunService.RenderStepped:Connect(function(deltaTime)
	local now = os.clock()
	local smoothing = 1 - math.exp(-deltaTime * 8)
	for owner, visual in petVisuals do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local count = #visual.models
		for i, model in visual.models do
			if root then
				-- Line up behind the player, bobbing up and down.
				local across = (i - (count + 1) / 2) * 3.5
				local target = root.CFrame * CFrame.new(across, -1 + math.sin(now * 3 + i) * 0.35, 5 + math.abs(across) * 0.3)
				local spot = visual.spots[i]
				-- Glide toward the target, or jump straight there after a teleport.
				spot = if spot and (spot.Position - target.Position).Magnitude < 60 then spot:Lerp(target, smoothing) else target
				visual.spots[i] = spot
				model:PivotTo(spot)
			end
			local shouldShow = root ~= nil
			if (model.Parent ~= nil) ~= shouldShow then
				model.Parent = if shouldShow then petFolder else nil
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Keeping everything up to date
--------------------------------------------------------------------------------

-- Finds the closest sell pad (there's one up top and one in the Sewers).
-- Searching the whole map is slow, so the pads are remembered after the first search.
local knownSellPads: { BasePart } = {}
local function nearestSellPad(position: Vector3): BasePart?
	local pads = {}
	for _, pad in knownSellPads do
		if pad.Parent then
			table.insert(pads, pad)
		end
	end
	if #pads == 0 then
		for _, descendant in workspace:GetDescendants() do
			if descendant.Name == "SellPad" and descendant:IsA("BasePart") then
				table.insert(pads, descendant)
			end
		end
	end
	knownSellPads = pads

	local nearest, nearestDistance = nil, math.huge
	for _, pad in pads do
		local distance = (pad.Position - position).Magnitude
		if distance < nearestDistance then
			nearest, nearestDistance = pad, distance
		end
	end
	return nearest
end

-- A glowing line from you to the nearest sell pad while your tank is full.
local sellGuide: Beam? = nil
local padAttachments: { [BasePart]: Attachment } = {}
local tankFull = false
local function updateSellGuide(show: boolean)
	local guide = sellGuide
	if not show then
		if guide then
			guide.Enabled = false
		end
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pad = nearestSellPad(root.Position)
	if not pad then
		return
	end

	local target = padAttachments[pad]
	if not target or target.Parent ~= pad then
		target = Instance.new("Attachment")
		target.Name = "SellGuideTarget"
		target.Parent = pad
		target.WorldPosition = pad.Position + Vector3.new(0, 1, 0)
		padAttachments[pad] = target
	end

	if not guide or guide.Parent ~= root then
		local start = Instance.new("Attachment")
		start.Name = "SellGuideStart"
		start.Parent = root

		guide = Instance.new("Beam")
		guide.Attachment0 = start
		guide.Color = ColorSequence.new(Color3.fromRGB(90, 255, 120))
		guide.Transparency = NumberSequence.new(0.2, 0.6)
		guide.Width0 = 0.6
		guide.Width1 = 0.6
		guide.FaceCamera = true
		guide.LightEmission = 1
		guide.Parent = root
		sellGuide = guide
	end
	guide.Attachment1 = target
	guide.Enabled = true
end

local lastCoins = stat("Coins")
local function refreshSidebar()
	local flushes, capacity = stat("Flushes"), stat("Capacity")
	local full = capacity > 0 and flushes >= capacity
	local coins = stat("Coins")

	-- Flash the coin box when you earn coins.
	if player:GetAttribute("Loaded") and coins > lastCoins then
		coinsOutline.Thickness = 6
		coinsOutline.Color = Color3.new(1, 1, 1)
		tween(coinsOutline, 0.5, { Thickness = 2, Color = GOLD })
	end
	lastCoins = coins

	coinsText.Text = "💰 " .. Format.number(coins)
	rebirthsText.Text = ("⭐ %s Rebirths (%gx)"):format(Format.number(stat("Rebirths")), Config.getMultiplier(stat("Rebirths")))
	flushText.Text = if full
		then "🚽 FULL! Go sell"
		else ("🚽 %s / %s"):format(Format.number(flushes), Format.number(capacity))
	tween(flushFill, 0.15, { Size = UDim2.fromScale(if capacity > 0 then math.clamp(flushes / capacity, 0, 1) else 0, 1) })
	flushFill.BackgroundColor3 = if full then RED else BLUE
	tankFull = full and player:GetAttribute("Loaded") == true
	updateSellGuide(tankFull)
	petsButton.Text = "🐾 Pets  x" .. formatMultiplier(player:GetAttribute("PetMultiplier") or 1)
end

-- Keep the guide pointing at the closest pad as you move around (or go down to the Sewers).
task.spawn(function()
	while true do
		task.wait(0.5)
		if tankFull then
			updateSellGuide(true)
		end
	end
end)

local function refreshAll()
	refreshSidebar()
	refreshShop()
	refreshRebirth()
end

local lastFlushes = stat("Flushes")
player.AttributeChanged:Connect(function(name)
	if name == "Flushes" then
		local flushes = stat("Flushes")
		-- "Loaded" check skips the pop-up when your saved Flushes first arrive.
		if player:GetAttribute("Loaded") and flushes > lastFlushes then
			showGainPopup(flushes - lastFlushes)
			playSound(SPLASH_SOUND, 0.35, 1.1 + math.random() * 0.4)
		end
		lastFlushes = flushes
	elseif name == "Pets" then
		refreshPetsMenu()
	end
	refreshAll()
end)
refreshAll()
refreshPetsMenu()

notifyRemote.OnClientEvent:Connect(showNotice)

shopButton.Activated:Connect(function()
	toggleWindow(shopWindow)
end)
rebirthButton.Activated:Connect(function()
	toggleWindow(rebirthWindow)
end)
petsButton.Activated:Connect(function()
	toggleWindow(petsWindow)
end)

-- The map's shop counter and rebirth toilet have "Press E" prompts that open these menus.
local menusByName = { Shop = shopWindow, Rebirth = rebirthWindow }
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local window = menusByName[prompt:GetAttribute("OpensMenu")]
	if window then
		openWindow(window)
	end
end)

-- Push the plunger down and back up on every click (only you see this).
local hookedPlungers = setmetatable({}, { __mode = "k" })
local function hookPlunger(tool: Instance)
	if not (tool:IsA("Tool") and tool.Name == "Plunger") or hookedPlungers[tool] then
		return
	end
	hookedPlungers[tool] = true
	local rest = tool.Grip
	local plunging: Tween? = nil
	tool.Activated:Connect(function()
		if plunging then
			plunging:Cancel()
		end
		tool.Grip = rest
		local push = TweenService:Create(
			tool,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Grip = rest * CFrame.new(0, 0.9, 0) }
		)
		plunging = push
		push:Play()
	end)
end

local function onCharacterAdded(character: Model)
	for _, child in character:GetChildren() do
		hookPlunger(child)
	end
	character.ChildAdded:Connect(hookPlunger)
	-- The guide line is attached to your body, so rebuild it after respawning.
	character:WaitForChild("HumanoidRootPart")
	refreshSidebar()
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

-- A quick hint once the player's data has loaded.
task.spawn(function()
	if not player:GetAttribute("Loaded") then
		player:GetAttributeChangedSignal("Loaded"):Wait()
	end
	showNotice("Equip your plunger and click to collect Flushes!", true)
end)
