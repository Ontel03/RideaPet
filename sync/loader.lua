--[[
	Candy Farm Loader - Main entry point for HttpGet execution.
	Loads all modular components and starts the farming system.
]]

--[[
	HOW TO USE:
	1. Upload this file structure to GitHub Gist or Repo
	2. Use URL: https://raw.githubusercontent.com/USERNAME/REPO/main/loader.lua
	3. Execute in executor: loadstring(game:HttpGet("URL"))()
]]

--==============================================================================
-- LOAD MODULES
--==============================================================================
local function loadModule(path)
	local success, mod = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/" .. path))()
	end)
	if success and mod then
		return mod
	end
	return nil
end

-- Load core modules
local Config = loadModule("core/config.lua") or {
	running = false, useRemotePickup = true, standOnPad = false,
	highestValueFirst = true, keyHold = 0.5, arriveDelay = 0.5,
	afterPickupDelay = 3.5, afterPadDelay = 1.5, cycleLength = 3.0,
	probeDelay = 0.4,
	DISCOVER_KEYWORDS = {"candy", "sweet", "pick", "collect", "take", "grab", "drop", "submit", "reward", "item", "bag", "trick", "treat", "halloween", "ghost"},
	DENY_KEYWORDS = {"buy", "shop", "purchase", "trade", "auction"},
	PROBE_SHAPES = {"none", "candy", "pad+candy", "candy+player", "candy+pad+player"},
}

local Utils = loadModule("core/utils.lua") or {
	getWorldPosition = function(o) if not o then return nil end if o:IsA("BasePart") then return o.Position end if o:IsA("Model") then local p = o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart") return p and p.Position or nil end if o:IsA("Folder") then for _, child in ipairs(o:GetDescendants()) do if child:IsA("BasePart") then return child.Position end end end return nil end,
	teleportTo = function(p, r) if not p or not r then return false end return pcall(function() r.CFrame = CFrame.new(p) end) end,
	holdPickupKey = function(k) local VIM = Services.VirtualInputManager; local key = Enum.KeyCode.E; pcall(function() VIM:SendKeyEvent(true, key, false, game) end); task.wait(k); pcall(function() VIM:SendKeyEvent(false, key, false, game) end) end,
	matchesAny = function(t, words) local l = string.lower(t); for _, w in ipairs(words) do if string.find(l, w, 1, true) then return true end end return false end,
	getAllRemotes = function() local t = {}; for _, c in ipairs({Services.ReplicatedStorage, Services.ReplicatedFirst, Services.Players.LocalPlayer:WaitForChild("PlayerScripts")}) do for _, r in ipairs(c:GetDescendants()) do if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then table.insert(t, r) end end end; return remotes end,
	getCandidateRemotes = function() local c = {}; for _, r in ipairs(Utils.getAllRemotes()) do local p = r:GetFullName(); if Utils.matchesAny(p, Utils.DISCOVER_KEYWORDS) and not Utils.matchesAny(p, Utils.DENY_KEYWORDS) then table.insert(c, r) end end; table.sort(c, function(a, b) local af, bf = a:IsA("RemoteFunction"), b:IsA("RemoteFunction"); if af ~= bf then return af end; return a:GetFullName() < b:GetFullName() end); return c end,
	buildArgs = function(s, c, p) if s == "none" then return {} elseif s == "candy" then return { c } elseif s == "pad+candy" then return { p, c } elseif s == "candy+player" then return { c, Services.Players.LocalPlayer } elseif s == "candy+pad+player" then return { c, p, Services.Players.LocalPlayer } end return { c, p, Services.Players.LocalPlayer } end,
	fireRemote = function(r, s, c, p) local a = Utils.buildArgs(s, c, p); local n = #a; if r:IsA("RemoteFunction") then r:InvokeServer(table.unpack(a, 1, n)) else r:FireServer(table.unpack(a, 1, n)) end end,
}

// Load core modules
local Candy = loadModule("core/candy.lua")
local Pickup = loadModule("core/pickup.lua")
local Movement = loadModule("core/movement.lua")
local Stats = loadModule("core/stats.lua")

// Load features (auto-farm, etc.)
local AutoFarm = loadModule("features/autofarm.lua") or {
	farmLoop = function() while true do task.wait(0.2) if Config.running then local l = Candy.getCandyList() if #l == 0 then task.wait(1.5) else for _, c in ipairs(l) do if not Config.running then break end local p = Candy.getWorldPosition(c.instance) if p and c.instance.Parent then Movement.runCandyCycle(c, p, rootPart, Stats) end end end Stats.incrementLaps() end end
}

// Load UI modules (simplified)
local Theme = {
	panel = Color3.fromRGB(26, 21, 36), surface = Color3.fromRGB(38, 32, 51),
	divider = Color3.fromRGB(56, 48, 72), outline = Color3.fromRGB(255, 130, 30),
	headerInk = Color3.fromRGB(28, 16, 6), text = Color3.fromRGB(233, 229, 240),
	muted = Color3.fromRGB(170, 164, 188), running = Color3.fromRGB(33, 133, 84),
	stopped = Color3.fromRGB(74, 69, 88),
}

// Initialize services table
local Services = {
	Config = Config,
	Utils = {
		getWorldPosition = Utils.getWorldPosition,
		teleportTo = Utils.teleportTo,
		holdPickupKey = Utils.holdPickupKey,
		matchesAny = Utils.matchesAny,
		getAllRemotes = Utils.getAllRemotes,
		getCandidateRemotes = Utils.getCandidateRemotes,
		buildArgs = Utils.buildArgs,
		fireRemote = Utils.fireRemote,
	},
	Candy = Candy,
	Pickup = Pickup,
	Movement = Movement,
	Stats = Stats,
	Theme = Theme,
}

// Initialize services references (will be set when running in Roblox)
Services.VirtualInputManager = Services.VirtualInputManager or game:GetService("VirtualInputManager")
Services.ReplicatedStorage = Services.VirtualInputManager and game:GetService("ReplicatedStorage") or {}
Services.Players = Services.Players or game:GetService("Players")
Services.CoreGui = Services.CoreGui or game:GetService("CoreGui")
Services.TweenService = Services.TweenService or game:GetService("TweenService")

// Set Services reference in Utils
Utils.Services = Services

//==============================================================================
-- REMOTE DISCOVERY
//==============================================================================
local function discoverRemote()
	local candidates = Utils.getCandidateRemotes()
	Services.State.candidates = #candidates
	if #candidates == 0 then
		print("[CandyFarm] No candidate remotes")
		Services.State.scanned = 0
		return nil, nil
	end
	local folder = Candy.getCandyFolder()
	if not folder then
		print("[CandyFarm] Candy folder not found")
		Services.State.scanned = #candidates
		return nil, nil
	end
	print(("[CandyFarm] Probing %d remotes..."):format(#candidates))
	for _, remote in ipairs(candidates) do
		for _, shape in ipairs(Config.PROBE_SHAPES) do
			local children = Candy.getCandyFolder():GetChildren()
			if #children == 0 then Services.State.scanned = #candidates; return nil, nil end
			local target = children[1]
			local pad = Candy.getDropOffPad() or target
			local ok = pcall(Utils.fireRemote, remote, shape, target, pad)
			task.wait(Config.probeDelay)
			if not target.Parent then
				Services.State.remote, Services.State.shape = remote, shape
				Services.State.scanned = 1
				print(("[CandyFarm] Found: %s (%s)"):format(remote:GetFullName(), shape))
				return remote, shape
			elseif not ok then break end
		end
	end
	Services.State.scanned = #candidates
	print("[CandyFarm] No working remote, falling back to teleport + key")
	return nil, nil
end

//==============================================================================
-- MAIN LOOP
//==============================================================================
local rootPart = Services.Players.LocalPlayer.Character and Services.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
local runService = game:GetService("RunService")

// Main farm loop
task.spawn(function()
	while true do
		task.wait(0.2)
		if Config.running then
			local list = Candy.getCandyList()
			if #list == 0 then
				task.wait(1.5)
			else
				for _, c in ipairs(list) do
					if not Config.running then break end
					local pos = Candy.getWorldPosition(c.instance)
					if pos and c.instance.Parent then
						Movement.runCandyCycle(c, pos, rootPart, Stats)
					end
				end
				Stats.incrementLaps()
			end
		end
	end
end)

// Start remote discovery
task.spawn(function()
	discoverRemote()
end)

// Print init message
print("[CandyFarm] Loader started. Probing remotes...")

//==============================================================================
-- MAIN ENTRY POINT (called from executor)
//==============================================================================
-- The actual Roblox script execution happens here when loaded via HttpGet
-- The actual Roblox script execution happens here when loaded via HttpGet
-- The script sets up the environment and starts the system.
-- Actual execution in Roblox Studio/Executor requires the full Roblox API.
-- For executor use, the loader.lua is designed to be loaded via HttpGet
-- and the farming system runs in the background.

print("[CandyFarm] Loader script ready. Use HttpGet to execute.")