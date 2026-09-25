-- Client UI for the simulator: the coin and Flush counters, the shop, the rebirth
-- menu and pop-up messages. The server owns all the numbers; this script only
-- shows them and asks the server when the player wants to buy something.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

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

local function button(text: string, color: Color3, props: { [string]: any })
	return make(
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
end

local gui = make("ScreenGui", {
	Name = "SimulatorUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

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
	Size = UDim2.fromOffset(210, 260),
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
	}, { rounded(), border(color, 2) })

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
	return text, fill
end

local coinsText = statBox(GOLD, 1)
local flushText, flushFill = statBox(BLUE, 2)
local rebirthsText = statBox(PURPLE, 3)

local shopButton = button("🛒 Shop", GREEN, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 48), Parent = sidebar })
local rebirthButton = button("⭐ Rebirth", PURPLE, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 48), Parent = sidebar })

--------------------------------------------------------------------------------
-- Pop-up windows
--------------------------------------------------------------------------------

local windows = {}

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
	return window
end

-- Opens a window (closing any other one), or closes it if it's already open.
local function toggleWindow(window: Frame)
	local open = not window.Visible
	for _, other in windows do
		other.Visible = false
	end
	window.Visible = open
end

local function openWindow(window: Frame)
	for _, other in windows do
		other.Visible = other == window
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
-- Keeping everything up to date
--------------------------------------------------------------------------------

local function refreshSidebar()
	local flushes, capacity = stat("Flushes"), stat("Capacity")
	local full = capacity > 0 and flushes >= capacity

	coinsText.Text = "💰 " .. Format.number(stat("Coins"))
	rebirthsText.Text = ("⭐ %s Rebirths (%gx)"):format(Format.number(stat("Rebirths")), Config.getMultiplier(stat("Rebirths")))
	flushText.Text = if full
		then "🚽 FULL! Go sell"
		else ("🚽 %s / %s"):format(Format.number(flushes), Format.number(capacity))
	flushFill.Size = UDim2.fromScale(if capacity > 0 then math.clamp(flushes / capacity, 0, 1) else 0, 1)
	flushFill.BackgroundColor3 = if full then RED else BLUE
end

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
		end
		lastFlushes = flushes
	end
	refreshAll()
end)
refreshAll()

notifyRemote.OnClientEvent:Connect(showNotice)

shopButton.Activated:Connect(function()
	toggleWindow(shopWindow)
end)
rebirthButton.Activated:Connect(function()
	toggleWindow(rebirthWindow)
end)

-- The map's shop counter and rebirth toilet have "Press E" prompts that open these menus.
local menusByName = { Shop = shopWindow, Rebirth = rebirthWindow }
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local window = menusByName[prompt:GetAttribute("OpensMenu")]
	if window then
		openWindow(window)
	end
end)

-- A quick hint once the player's data has loaded.
task.spawn(function()
	if not player:GetAttribute("Loaded") then
		player:GetAttributeChangedSignal("Loaded"):Wait()
	end
	showNotice("Equip your plunger and click to collect Flushes!", true)
end)
