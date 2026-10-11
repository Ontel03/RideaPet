--[[
	Candy Farm Loader - Main entry point for HttpGet execution.
	Loads all components and starts the farming system.
	Works on executors: Synapse X, Fluxus, Electron, Krnl, dll.
]]

--[[
	HOW TO USE:
	1. Execute directly in executor:
	   loadstring(game:HttpGet("https://raw.githubusercontent.com/Ontel03/RideaPet/main/sync/loader.lua"))()
	2. Or load from local file:
	   loadfile("E:\\PUNYAROZI\\Software\\RobloxScript\\sync\\loader.lua")()
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

-- Config (self-contained, no external dependency)
local Config = {
	running = false,
	useRemotePickup = true,
	standOnPad = false,
	highestValueFirst = true,
	keyHold = 0.5,
	arriveDelay = 0.5,
	afterPickupDelay = 3.5,
	afterPadDelay = 1.5,
	cycleLength = 3.0,
	probeDelay = 0.4,

	discoverKeywords = {
		"candy", "sweet", "pick", "collect", "take", "grab", "drop",
		"submit", "reward", "item", "bag", "trick", "treat", "halloween", "ghost",
	},
	denyKeywords = { "buy", "shop", "purchase", "trade", "auction" },
	probeShapes = { "none", "candy", "pad+candy", "candy+player", "candy+pad+player" },
}

-- Stats state
local Stats = { collected = 0, laps = 0 }
function Stats.incrementCollected() Stats.collected = Stats.collected + 1 end
function Stats.incrementLaps() Stats.laps = Stats.laps + 1 end
function Stats.format() return ("Collected %d  ·  Laps %d"):format(Stats.collected, Stats.laps) end

-- Pickup state
local PickupState = { remote = nil, shape = nil, candidates = 0, scanned = 0 }

-- UI Setup (simple panel, no TweenService to avoid executor errors)
local function createUI()
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "CandyFarmUI"
	ScreenGui.ResetOnSpawn = false

	-- Try CoreGui, fallback to PlayerGui
	local guiParent = CoreGui
	pcall(function() guiParent = Players.LocalPlayer:WaitForChild("PlayerGui") end)

	ScreenGui.Parent = guiParent

	-- Main Frame
	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.new(0, 200, 0, 120)
	frame.Position = UDim2.new(0, 10, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(38, 32, 51)
	frame.BackgroundTransparency = 0.1
	frame.Parent = ScreenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(233, 229, 240)
	title.Text = "Candy Farm Panel"
	title.Parent = frame

-- Status Display
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0, 25)
	status.Position = UDim2.new(0, 0, 0, 35)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(33, 133, 84) -- green default
	status.Text = "Status: Stopped"
	status.Parent = frame

-- Stats Display
	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.Size = UDim2.new(1, 0, 0, 25)
	stats.Position = UDim2.new(0, 0, 0, 65)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 12
	stats.TextColor3 = Color3.fromRGB(170, 164, 188)
	stats.Text = Stats.format()
	stats.Parent = frame

-- Toggle Button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleBtn"
	toggleBtn.Size = UDim2.new(1, -20, 0, 30)
	toggleBtn.Position = UDim2.new(0, 10, 0, 95)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(28, 16, 6)
	toggleBtn.Font = Enum.Font.GothamMedium
	toggleBtn.TextSize = 12
	toggleBtn.TextColor3 = Color3.fromRGB(233, 229, 240)
	toggleBtn.Text = "Start Farm"
	toggleBtn.Parent = frame
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = toggleBtn

-- Toggle functionality
	local farmConnection
	toggleBtn.MouseButton1Click:Connect(function()
		Config.running = not Config.running
		if Config.running then
			toggleBtn.Text = "Stop Farm"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(33, 133, 84)
			status.Text = "Status: Running"
			status.TextColor3 = Color3.fromRGB(33, 133, 84)
			-- Print confirmation
			print("[CandyFarm] Farm started via UI toggle")
		else
			toggleBtn.Text = "Start Farm"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(28, 16, 6)
			status.Text = "Status: Stopped"
			status.TextColor3 = Color3.fromRGB(170, 164, 188)
			-- Print confirmation
			print("[CandyFarm] Farm stopped via UI toggle")
		end
	end)

-- Print UI init message
print("[CandyFarm] UI Panel created. Use the button to Start/Stop farm.")
end

-- Run UI setup
createUI()

-- Helpers
local function getWorldPosition(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object.Position end
	if object:IsA("Model") then
		local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
		return part and part.Position or nil
	end
	if object:IsA("Folder") then
		for _, child in ipairs(object:GetDescendants()) do
			if child:IsA("BasePart") then return child.Position end
		end
	end
	return nil
end

local function teleportTo(position, rootPart)
	if not position or not rootPart then return false end
	return pcall(function() rootPart.CFrame = CFrame.new(position) end)
end

local function holdPickupKey(keyHold)
	pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
	task.wait(keyHold)
	pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
end

local function matchesAny(text, words)
	local lower = string.lower(text)
	for _, w in ipairs(words) do
		if string.find(lower, w, 1, true) then return true end
	end
	return false
end

local function getAllRemotes()
	local containers = { ReplicatedStorage, game:GetService("ReplicatedFirst"), Players.LocalPlayer:WaitForChild("PlayerScripts") }
	local remotes = {}
	for _, c in ipairs(containers) do
		for _, r in ipairs(c:GetDescendants()) do
			if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then table.insert(remotes, r) end
		end
	end
	return remotes
end

local function getCandidateRemotes()
	local candidates = {}
	for _, remote in ipairs(getAllRemotes()) do
		local path = remote:GetFullName()
		if matchesAny(path, Config.discoverKeywords) and not matchesAny(path, Config.denyKeywords) then
			table.insert(candidates, remote)
		end
	end
	table.sort(candidates, function(a, b)
		local af, bf = a:IsA("RemoteFunction"), b:IsA("RemoteFunction")
		if af ~= bf then return af end
		return a:GetFullName() < b:GetFullName()
	end)
	return candidates
end

local function buildArgs(shape, candy, pad)
	if shape == "none" then return {}
	elseif shape == "candy" then return { candy }
	elseif shape == "pad+candy" then return { pad, candy }
	elseif shape == "candy+player" then return { candy, Players.LocalPlayer }
	elseif shape == "candy+pad+player" then return { candy, pad, Players.LocalPlayer }
	end
	return { candy, pad, Players.LocalPlayer }
end

local function fireRemote(remote, shape, candy, pad)
	local args = buildArgs(shape, candy, pad)
	local n = #args
	if remote:IsA("RemoteFunction") then remote:InvokeServer(table.unpack(args, 1, n))
	else remote:FireServer(table.unpack(args, 1, n)) end
end

local function getCandyFolder()
	return workspace:FindFirstChild("HalloweenCandy")
end

local function getDropOffPad()
	local dropOff = workspace:FindFirstChild("CandyDropOff")
	if not dropOff then return nil end
	return dropOff:FindFirstChild("Pad") or dropOff
end

local function getCandyList()
	local folder = getCandyFolder()
	if not folder then return {} end
	local list = {}
	for _, c in ipairs(folder:GetChildren()) do
		local v = tonumber(c.Name:match("%d+")) or 0
		table.insert(list, { instance = c, value = v })
	end
	table.sort(list, function(a, b) return Config.highestValueFirst and a.value > b.value or a.value < b.value end)
	return list
end

local function discoverRemote()
	local candidates = getCandidateRemotes()
	if #candidates == 0 then return nil, nil end
	local folder = getCandyFolder()
	if not folder then return nil, nil end
	for _, remote in ipairs(candidates) do
		for _, shape in ipairs(Config.probeShapes) do
			local children = folder:GetChildren()
			if #children == 0 then return nil, nil end
			local target = children[1]
			local pad = getDropOffPad() or target
			local ok = pcall(fireRemote, remote, shape, target, pad)
			task.wait(Config.probeDelay)
			if not target.Parent then
				PickupState.remote, PickupState.shape = remote, shape
				PickupState.scanned = 1
				return remote, shape
			elseif not ok then break end
		end
	end
	return nil, nil
end

local function sendPickup(candy, pad)
	if not PickupState.remote or not PickupState.shape then return false end
	return pcall(fireRemote, PickupState.remote, PickupState.shape, candy, pad)
end

local function runCandyCycle(candy, position, rootPart)
	local started = os.clock()
	local pad = getDropOffPad()

	if PickupState.remote and Config.useRemotePickup then
		if Config.standOnPad then
			local pp = getWorldPosition(pad)
			if pp then teleportTo(pp + Vector3.new(0, 5, 0), rootPart); task.wait(Config.afterPadDelay) end
		end
		task.wait(Config.arriveDelay)
		if sendPickup(candy.instance, pad) then Stats.incrementCollected() end
		local rem = Config.cycleLength - (os.clock() - started)
		if rem > 0 then task.wait(rem) end
		return
	end

	teleportTo(position + Vector3.new(0, 3, 0), rootPart)
	task.wait(Config.arriveDelay)
	holdPickupKey(Config.keyHold)
	Stats.incrementCollected()
	task.wait(Config.afterPickupDelay)

	local pp = getWorldPosition(pad)
	if pp then teleportTo(pp + Vector3.new(0, 5, 0), rootPart); task.wait(Config.afterPadDelay) end

	local rem = Config.cycleLength - (os.clock() - started)
	if rem > 0 then task.wait(rem) end
end

-- Character setup
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
player.CharacterAdded:Connect(function(c)
	character = c
	rootPart = c:WaitForChild("HumanoidRootPart")
end)

-- Main farm loop
task.spawn(function()
	while true do
		task.wait(0.2)
		if Config.running then
			local list = getCandyList()
			if #list == 0 then
				task.wait(1.5)
			else
				for _, candy in ipairs(list) do
					if not Config.running then break end
					local pos = getWorldPosition(candy.instance)
					if pos and candy.instance.Parent then
						runCandyCycle(candy, pos, rootPart)
					end
				end
				Stats.incrementLaps()
			end
		end
	end
end)

-- Remote discovery
task.spawn(function()
	discoverRemote()
end)

print("[CandyFarm] Loader started. Probing remotes... Use the UI button to Start/Stop farm.")