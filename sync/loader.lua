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
local TweenService = game:GetService("TweenService")
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

print("[CandyFarm] Loader started. Probing remotes...")