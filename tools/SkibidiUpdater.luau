-- Skibidi Updater: a Roblox Studio plugin that adds an "Update Game" button.
-- Clicking it downloads the newest Skibidi Simulator scripts from GitHub and
-- puts each one in the right place with the right name, so you never have to
-- copy and paste them again.
--
-- Install it once:
--   1. Put this code in a Script anywhere (ServerStorage is fine).
--   2. Right-click the Script > "Save as Local Plugin...", then click Save.
--   3. Delete the Script. The button is now in the Plugins tab.
-- The first time you click it, Studio asks if the plugin can use the internet. Click Allow.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local SOURCE_URL = "https://raw.githubusercontent.com/avcards0-ai/Skibidi-game/main/src/"

local GREEN = Color3.fromRGB(90, 220, 110)
local RED = Color3.fromRGB(255, 100, 100)
local WHITE = Color3.new(1, 1, 1)

-- Finds a folder by name, fixing wrong capital letters (like "shared"), or makes it.
local function findOrCreateFolder(parent: Instance, name: string): Instance
	local exact = parent:FindFirstChild(name)
	if exact and exact:IsA("Folder") then
		return exact
	end
	for _, child in parent:GetChildren() do
		if child:IsA("Folder") and child.Name:lower() == name:lower() then
			child.Name = name
			return child
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- StarterPlayerScripts is found by its type, so it still works if it got renamed.
local function getStarterPlayerScripts(): Instance
	local container = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	assert(container, "Can't find StarterPlayerScripts inside StarterPlayer.")
	container.Name = "StarterPlayerScripts"
	return container
end

local FILES = {
	{
		file = "shared/Config.luau",
		name = "Config",
		className = "ModuleScript",
		getParent = function()
			return findOrCreateFolder(ReplicatedStorage, "Shared")
		end,
	},
	{
		file = "shared/Format.luau",
		name = "Format",
		className = "ModuleScript",
		getParent = function()
			return findOrCreateFolder(ReplicatedStorage, "Shared")
		end,
	},
	{
		file = "server/GameServer.server.luau",
		name = "GameServer",
		className = "Script",
		getParent = function()
			return ServerScriptService
		end,
	},
	{
		file = "server/MapBuilder.server.luau",
		name = "MapBuilder",
		className = "Script",
		getParent = function()
			return ServerScriptService
		end,
	},
	{
		file = "client/GameClient.client.luau",
		name = "GameClient",
		className = "LocalScript",
		getParent = getStarterPlayerScripts,
	},
}

local function download(file: string): (boolean, string)
	-- The "?v=" on the end skips GitHub's cache, so you always get the newest version.
	local url = SOURCE_URL .. file .. "?v=" .. os.time()
	return pcall(function()
		return HttpService:GetAsync(url, true)
	end)
end

-- Puts the code into the right script, making the script (or fixing its type) if needed.
local function installScript(entry, source: string)
	local parent = entry.getParent()
	local existing = parent:FindFirstChild(entry.name)
	if existing and existing.ClassName ~= entry.className then
		existing.Parent = nil -- the wrong kind, like a LocalScript where a Script should be
		existing = nil
	end

	if existing then
		local ok = pcall(function()
			ScriptEditorService:UpdateSourceAsync(existing, function()
				return source
			end)
		end)
		if not ok then
			existing.Source = source
		end
	else
		local newScript = Instance.new(entry.className)
		newScript.Name = entry.name
		newScript.Source = source
		newScript.Parent = parent
	end
end

--------------------------------------------------------------------------------
-- The button and a little window that says how it went
--------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("Skibidi Simulator")
local button = toolbar:CreateButton("Update Game", "Download the newest game scripts from GitHub", "")
button.ClickableWhenViewportHidden = true

local window = plugin:CreateDockWidgetPluginGuiAsync(
	"SkibidiUpdater",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 340, 150, 240, 100)
)
window.Title = "Skibidi Updater"

local status = Instance.new("TextLabel")
status.Size = UDim2.fromScale(1, 1)
status.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
status.Font = Enum.Font.FredokaOne
status.TextSize = 20
status.TextWrapped = true
status.Parent = window

local function showStatus(text: string, color: Color3)
	status.Text = text
	status.TextColor3 = color
	window.Enabled = true
end

local updating = false

button.Click:Connect(function()
	button:SetActive(false)
	if updating then
		return
	end
	if RunService:IsRunning() then
		showStatus("Stop the game first, then click Update Game.", RED)
		return
	end

	updating = true
	showStatus("Downloading...", WHITE)

	-- Download everything first, so nothing changes if one download fails.
	local sources = {}
	for _, entry in FILES do
		local ok, result = download(entry.file)
		if not ok then
			updating = false
			showStatus(
				("Couldn't download %s. If Studio asked about internet access, click Allow and try again.\n\n%s"):format(
					entry.name,
					tostring(result)
				),
				RED
			)
			return
		end
		sources[entry] = result
	end

	-- Recording makes the whole update one step you can undo with Ctrl+Z.
	local recording = ChangeHistoryService:TryBeginRecording("Update Skibidi Simulator")
	local ok, err = pcall(function()
		for _, entry in FILES do
			installScript(entry, sources[entry])
		end
	end)
	if recording then
		local operation = if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		ChangeHistoryService:FinishRecording(recording, operation)
	end
	updating = false

	if ok then
		showStatus(("✅ Updated all %d scripts! Press Play to try it."):format(#FILES), GREEN)
	else
		showStatus("Something went wrong, so nothing was changed:\n\n" .. tostring(err), RED)
	end
end)
