-- Candy farm overlay: collects the Halloween candy set over the game's own remote when
-- one is found, otherwise by teleporting to each candy and holding the pickup key.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local CANDY_FOLDER = "HalloweenCandy"
local DROP_OFF = "CandyDropOff"
local PICKUP_KEY = Enum.KeyCode.E
local CANDY_HOVER = Vector3.new(0, 3, 0)
local PAD_HOVER = Vector3.new(0, 5, 0)

-- Discovery sends real calls to the server. It only probes remotes whose name matches
-- discoverKeywords, never one that matches denyKeywords, and stops at the first candy
-- that actually leaves the folder.
local Config = {
	running = false,
	useRemotePickup = true,
	standOnPad = false,
	highestValueFirst = true,
	keyTap = 0.12,
	arriveDelay = 0.5,
	afterPickupDelay = 3.5,
	afterPadDelay = 1.5,
	cycleLength = 3.0,
	probeDelay = 0.4,
	pickupAttempts = 3,
	discoverKeywords = {
		"candy", "sweet", "pick", "collect", "take", "grab", "drop",
		"submit", "reward", "item", "bag", "trick", "treat", "halloween", "ghost",
	},
	denyKeywords = { "buy", "shop", "purchase", "trade", "auction" },
}

local SHAPES = { "none", "candy", "pad+candy", "candy+player", "candy+pad+player" }

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")
end)

local stats = {
	collected = 0,
	laps = 0,
}

local pickup = {
	remote = nil,
	shape = nil,
	candidates = 0,
	scanned = 0,
}

local function getCandyFolder()
	return workspace:FindFirstChild(CANDY_FOLDER)
end

local function getDropOffPad()
	local dropOff = workspace:FindFirstChild(DROP_OFF)
	if not dropOff then
		return nil
	end
	return dropOff:FindFirstChild("Pad") or dropOff
end

local function getWorldPosition(object)
	if not object then
		return nil
	end
	if object:IsA("BasePart") then
		return object.Position
	end
	if object:IsA("Model") then
		local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
		return part and part.Position or nil
	end
	if object:IsA("Folder") then
		for _, child in ipairs(object:GetDescendants()) do
			if child:IsA("BasePart") then
				return child.Position
			end
		end
	end
	return nil
end

local function teleportTo(position)
	if not position or not rootPart then
		return false
	end
	return pcall(function()
		rootPart.CFrame = CFrame.new(position)
	end)
end

-- Documented input path (UserInputService:CreateVirtualInput). Returns nil when the
-- feature is unavailable, which is normal on many executors.
local virtualInput = nil
do
	local ok, created = pcall(function()
		return UserInputService:CreateVirtualInput()
	end)
	if ok and created then
		virtualInput = created
	end
end

-- Presses and releases a key through whichever input path this client exposes.
-- Returns which path was used, so the console can report what actually works.
local function pressKey(keyCode, holdSeconds)
	local duration = holdSeconds or Config.keyTap

	if virtualInput then
		local ok = pcall(function()
			virtualInput:SendKey(true, keyCode, false)
			task.wait(duration)
			virtualInput:SendKey(false, keyCode, false)
		end)
		if ok then
			return "virtual"
		end
	end

	local ok = pcall(function()
		VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		task.wait(duration)
		VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
	end)
	if ok then
		return "vim"
	end

	return nil
end

-- Reports the available input path once, so a silent failure is diagnosable.
local inputPathReported = false
local function reportInputPath(path)
	if inputPathReported then
		return
	end
	inputPathReported = true
	print("[farm] input path:", path == "virtual" and "VirtualInput (documented)"
		or path == "vim" and "VirtualInputManager (internal)"
		or "none")
end

-- A tap rather than a sustained hold: games that listen for a keypress fire immediately.
local function tapPickupKey()
	local path = pressKey(PICKUP_KEY, Config.keyTap)
	reportInputPath(path)
	return path
end

-- Roblox force-disconnects a player after roughly 20 minutes of no activity. There is
-- no documented way to reset that timer, so a harmless modifier keypress is fed through
-- the same input pipeline real activity uses.
do
	local keepAliveKey = Enum.KeyCode.LeftShift
	player.Idled:Connect(function()
		pressKey(keepAliveKey, 0.05)
	end)
end

-- Finds the candy's prompt and teleports into its exact activation range.
-- Returns nil when the candy has no prompt, so the caller can fall back to the key.
local function preparePromptPickup(candyInstance, position)
	local prompt = candyInstance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return nil
	end

	local anchor = prompt.Parent
	if anchor and anchor:IsA("BasePart") then
		-- Sit slightly in front of the candy and below its top so the prompt is in range.
		teleportTo(anchor.Position + Vector3.new(0, 1, 0))
	else
		teleportTo(position + Vector3.new(0, 1, 0))
	end

	-- The camera-facing check is the usual reason a prompt refuses to trigger from a
	-- spot that is technically in range, so clear it before attempting the pickup.
	pcall(function()
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 20)
	end)

	-- Retry the approach until the engine reports the prompt as usable from here.
	for attempt = 1, 4 do
		task.wait(Config.arriveDelay)
		local reachable = prompt.Enabled
		if reachable then
			local origin = rootPart and rootPart.Position
			local limit = math.max(prompt.MaxActivationDistance or 10, 0) + 4
			if not origin or not anchor or not anchor:IsA("BasePart") or (origin - anchor.Position).Magnitude <= limit then
				break
			end
		end
		if attempt == 4 then
			return nil
		end
		if anchor and anchor:IsA("BasePart") then
			teleportTo(anchor.Position + Vector3.new(0, 1, 0))
		else
			teleportTo(position + Vector3.new(0, 1, 0))
		end
	end

	return prompt
end

-- Fires the prompt directly, so no key press is simulated.
local function firePrompt(prompt)
	local ok = pcall(function()
		-- The hold timer runs client-side, so zeroing it fires Triggered instantly.
		prompt.HoldDuration = 0
		prompt:InputHoldBegin()
		prompt:InputHoldEnd()
	end)
	return ok
end

local function getCandyList()
	local folder = getCandyFolder()
	if not folder then
		return {}
	end

	local candies = {}
	for _, candy in ipairs(folder:GetChildren()) do
		table.insert(candies, {
			instance = candy,
			value = tonumber(candy.Name:match("%d+")) or 0,
		})
	end

	table.sort(candies, function(a, b)
		if Config.highestValueFirst then
			return a.value > b.value
		end
		return a.value < b.value
	end)

	return candies
end

local function matchesAny(text, words)
	local lower = string.lower(text)
	for _, word in ipairs(words) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

local function getAllRemotes()
	local containers = { ReplicatedStorage, playerScripts, game:GetService("ReplicatedFirst") }
	local remotes = {}
	for _, container in ipairs(containers) do
		for _, remote in ipairs(container:GetDescendants()) do
			if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
				table.insert(remotes, remote)
			end
		end
	end
	return remotes
end

local function getCandidates()
	local candidates = {}
	for _, remote in ipairs(getAllRemotes()) do
		local path = remote:GetFullName()
		if matchesAny(path, Config.discoverKeywords) and not matchesAny(path, Config.denyKeywords) then
			table.insert(candidates, remote)
		end
	end

	-- RemoteFunctions first: InvokeServer is where games tend to put authoritative actions.
	table.sort(candidates, function(a, b)
		local aFunction = a:IsA("RemoteFunction")
		local bFunction = b:IsA("RemoteFunction")
		if aFunction ~= bFunction then
			return aFunction
		end
		return a:GetFullName() < b:GetFullName()
	end)
	return candidates
end

local function buildArgs(shape, candy, pad)
	if shape == "none" then
		return {}
	elseif shape == "candy" then
		return { candy }
	elseif shape == "pad+candy" then
		return { pad, candy }
	elseif shape == "candy+player" then
		return { candy, player }
	end
	return { candy, pad, player }
end

local function fire(remote, shape, candy, pad)
	local args = buildArgs(shape, candy, pad)
	local count = #args
	if remote:IsA("RemoteFunction") then
		remote:InvokeServer(table.unpack(args, 1, count))
	else
		remote:FireServer(table.unpack(args, 1, count))
	end
end

local function discoverPickupRemote(candidates)
	local folder = getCandyFolder()
	if not folder then
		return nil
	end

	for _, remote in ipairs(candidates) do
		for _, shape in ipairs(SHAPES) do
			local children = folder:GetChildren()
			if #children == 0 then
				return nil
			end

			local target = children[1]
			local pad = getDropOffPad() or target
			local sent = pcall(fire, remote, shape, target, pad)
			task.wait(Config.probeDelay)

			if not target.Parent then
				return remote, shape
			elseif not sent then
				break
			end
		end
	end
	return nil
end

local function sendPickup(candy, pad)
	local args = buildArgs(pickup.shape, candy, pad)
	local count = #args
	return pcall(function()
		if pickup.remote:IsA("RemoteFunction") then
			pickup.remote:InvokeServer(table.unpack(args, 1, count))
		else
			pickup.remote:FireServer(table.unpack(args, 1, count))
		end
	end)
end

local function finishCycle(startedAt, cycleLength)
	local remaining = cycleLength - (os.clock() - startedAt)
	if remaining > 0 then
		task.wait(remaining)
	end
end

local function runCandyCycle(candy, position)
	local startedAt = os.clock()

	if pickup.remote and Config.useRemotePickup then
		if Config.standOnPad then
			teleportTo(getWorldPosition(getDropOffPad()) + PAD_HOVER)
			task.wait(Config.afterPadDelay)
		end

		task.wait(Config.arriveDelay)
		if sendPickup(candy, getDropOffPad() or candy) then
			stats.collected = stats.collected + 1
		end
		finishCycle(startedAt, Config.cycleLength)
		return
	end

	-- Prompt path: stand inside activation range, fire, and confirm the candy left.
	local prompt = preparePromptPickup(candy.instance, position)
	if prompt then
		local collected = false
		for attempt = 1, Config.pickupAttempts do
			if firePrompt(prompt) and not candy.instance.Parent then
				collected = true
				break
			end
			-- Re-seat before retrying; the prompt range is tight and the camera angle matters.
			local anchor = prompt.Parent
			if anchor and anchor:IsA("BasePart") then
				teleportTo(anchor.Position + Vector3.new(0, 1, 0))
			end
			task.wait(Config.arriveDelay)
		end

		if collected then
			stats.collected = stats.collected + 1
			finishCycle(startedAt, Config.cycleLength)
			return
		end
	end

	-- Key fallback: sit next to the candy and tap the pickup key until it registers.
	teleportTo(position + CANDY_HOVER)
	for attempt = 1, Config.pickupAttempts do
		task.wait(Config.arriveDelay)
		tapPickupKey()
		task.wait(Config.keyTap + Config.arriveDelay)
		if not candy.instance.Parent then
			break
		end
	end

	if candy.instance.Parent then
		return
	end

	stats.collected = stats.collected + 1
	task.wait(Config.afterPickupDelay)

	local padPosition = getWorldPosition(getDropOffPad())
	if padPosition then
		teleportTo(padPosition + PAD_HOVER)
		task.wait(Config.afterPadDelay)
	end

	finishCycle(startedAt, Config.cycleLength)
end

-- Start remote discovery in background
task.spawn(function()
	local candidates = getCandidates()
	pickup.candidates = #candidates

	local remote, shape = discoverPickupRemote(candidates)
	if remote then
		pickup.remote = remote
		pickup.shape = shape
		pickup.scanned = 1
		print("[farm] pickup remote:", remote:GetFullName(), shape)
	else
		pickup.scanned = #candidates
		print("[farm] no pickup remote found, falling back to teleport + key")
	end
end)

-- Main farm loop
task.spawn(function()
	while true do
		task.wait(0.2)

		if Config.running then
			local candies = getCandyList()

			if #candies == 0 then
				task.wait(1.5)
			else
				for _, candy in ipairs(candies) do
					if not Config.running then
						break
					end
					-- Candy parts disappear the moment they are collected, so re-read the position.
					local position = getWorldPosition(candy.instance)
					if position and candy.instance.Parent then
						runCandyCycle(candy, position)
					end
				end

				stats.laps = stats.laps + 1
			end
		end
	end
end)

local Theme = {
	panel = Color3.fromRGB(10, 11, 14),
	sidebar = Color3.fromRGB(17, 18, 22),
	surface = Color3.fromRGB(29, 30, 35),
	divider = Color3.fromRGB(43, 44, 50),
	outline = Color3.fromRGB(229, 190, 41),
	headerInk = Color3.fromRGB(18, 18, 18),
	text = Color3.fromRGB(235, 237, 241),
	muted = Color3.fromRGB(145, 148, 157),
	running = Color3.fromRGB(26, 148, 81),
	stopped = Color3.fromRGB(67, 69, 76),
}

local function create(className, properties, parent)
	local instance = Instance.new(className)
	for property, value in pairs(properties) do
		instance[property] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local oldScreen = CoreGui:FindFirstChild("CandyFarmPanel")
if oldScreen then
	oldScreen:Destroy()
end

local screen = create("ScreenGui", {
	Name = "CandyFarmPanel",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, CoreGui)

local panel = create("Frame", {
	Size = UDim2.fromOffset(620, 420),
	Position = UDim2.new(0.5, -310, 0.5, -210),
	BackgroundColor3 = Theme.panel,
	BorderSizePixel = 0,
	Active = true,
	ClipsDescendants = true,
}, screen)
round(panel, 12)
create("UIStroke", { Color = Theme.divider, Thickness = 1 }, panel)

local sidebar = create("Frame", {
	Size = UDim2.new(0, 164, 1, 0),
	BackgroundColor3 = Theme.sidebar,
	BorderSizePixel = 0,
}, panel)

local brand = create("Frame", {
	Size = UDim2.new(1, -20, 0, 54),
	Position = UDim2.fromOffset(10, 10),
	BackgroundColor3 = Theme.surface,
	BorderSizePixel = 0,
}, sidebar)
round(brand, 8)

local brandMark = create("Frame", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.fromOffset(10, 12),
	BackgroundColor3 = Theme.outline,
	BorderSizePixel = 0,
}, brand)
round(brandMark, 6)

create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "E",
	TextColor3 = Theme.headerInk,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, brandMark)

create("TextLabel", {
	Size = UDim2.new(1, -54, 0, 18),
	Position = UDim2.fromOffset(48, 10),
	BackgroundTransparency = 1,
	Text = "EVENT FARM",
	TextColor3 = Theme.text,
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, brand)

create("TextLabel", {
	Size = UDim2.new(1, -54, 0, 14),
	Position = UDim2.fromOffset(48, 28),
	BackgroundTransparency = 1,
	Text = "Automation panel",
	TextColor3 = Theme.muted,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, brand)

local nav = create("Frame", {
	Size = UDim2.new(1, -20, 0, 138),
	Position = UDim2.fromOffset(10, 78),
	BackgroundTransparency = 1,
}, sidebar)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, nav)

local function createNavButton(label, layoutOrder)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.sidebar,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = layoutOrder,
		Selectable = true,
	}, nav)
	round(button, 7)

	local accent = create("Frame", {
		Size = UDim2.fromOffset(3, 20),
		Position = UDim2.fromOffset(1, 10),
		BackgroundColor3 = Theme.outline,
		BorderSizePixel = 0,
		Visible = false,
	}, button)
	round(accent, 2)

	local labelText = create("TextLabel", {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = Theme.muted,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, button)
	return button, accent, labelText
end

local homeTab, homeAccent, homeTabText = createNavButton("Home", 1)
local farmTab, farmAccent, farmTabText = createNavButton("Farm", 2)
local halloweenTab, halloweenAccent, halloweenTabText = createNavButton("Halloween", 3)

local sidebarStatus = create("Frame", {
	Size = UDim2.new(1, -20, 0, 28),
	Position = UDim2.new(0, 10, 1, -40),
	BackgroundTransparency = 1,
}, sidebar)

local sidebarStatusDot = create("Frame", {
	Size = UDim2.fromOffset(7, 7),
	Position = UDim2.fromOffset(2, 10),
	BackgroundColor3 = Theme.running,
	BorderSizePixel = 0,
}, sidebarStatus)
round(sidebarStatusDot, 4)

local sidebarStatusText = create("TextLabel", {
	Size = UDim2.new(1, -18, 1, 0),
	Position = UDim2.fromOffset(16, 0),
	BackgroundTransparency = 1,
	Text = "Panel is ready",
	TextColor3 = Theme.muted,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, sidebarStatus)

local header = create("Frame", {
	Size = UDim2.new(1, -180, 0, 54),
	Position = UDim2.fromOffset(178, 0),
	BackgroundTransparency = 1,
	Active = true,
}, panel)

local titleLabel = create("TextLabel", {
	Size = UDim2.new(1, -120, 0, 24),
	Position = UDim2.fromOffset(2, 9),
	BackgroundTransparency = 1,
	Text = "Home",
	TextColor3 = Theme.text,
	TextSize = 18,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local subtitleLabel = create("TextLabel", {
	Size = UDim2.new(1, -120, 0, 16),
	Position = UDim2.fromOffset(2, 31),
	BackgroundTransparency = 1,
	Text = "Overview and farming status",
	TextColor3 = Theme.muted,
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local minimizeButton = create("TextButton", {
	Size = UDim2.fromOffset(72, 28),
	Position = UDim2.new(1, -114, 0, 12),
	BackgroundColor3 = Theme.surface,
	BorderSizePixel = 0,
	Text = "Minimize",
	TextColor3 = Theme.text,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	Selectable = true,
}, header)
round(minimizeButton, 6)

local closeButton = create("TextButton", {
	Size = UDim2.fromOffset(26, 28),
	Position = UDim2.new(1, -36, 0, 12),
	BackgroundColor3 = Theme.surface,
	BorderSizePixel = 0,
	Text = "X",
	TextColor3 = Theme.muted,
	TextSize = 16,
	Font = Enum.Font.GothamMedium,
	Selectable = true,
}, header)
round(closeButton, 6)

local body = create("Frame", {
	Size = UDim2.new(1, -190, 1, -66),
	Position = UDim2.fromOffset(178, 58),
	BackgroundTransparency = 1,
}, panel)

local homePage = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, body)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, homePage)

local halloweenPage = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, body)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, halloweenPage)

local farmPage = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, body)

local comingSoonCard = create("Frame", {
	Size = UDim2.new(1, 0, 0, 112),
	Position = UDim2.new(0, 0, 0.5, -56),
	BackgroundColor3 = Theme.surface,
	BorderSizePixel = 0,
}, farmPage)
round(comingSoonCard, 8)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 28),
	Position = UDim2.fromOffset(12, 22),
	BackgroundTransparency = 1,
	Text = "EGG FARM",
	TextColor3 = Theme.text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
}, comingSoonCard)

create("TextLabel", {
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.fromOffset(12, 54),
	BackgroundTransparency = 1,
	Text = "Coming Soon",
	TextColor3 = Theme.outline,
	TextSize = 12,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Center,
}, comingSoonCard)

local statusRow = create("Frame", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
}, homePage)

local statusDot = create("Frame", {
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.fromOffset(1, 6),
	BackgroundColor3 = Theme.stopped,
	BorderSizePixel = 0,
}, statusRow)
round(statusDot, 4)

local statusLabel = create("TextLabel", {
	Size = UDim2.new(1, -18, 1, 0),
	Position = UDim2.fromOffset(16, 0),
	BackgroundTransparency = 1,
	Text = "Stopped",
	TextColor3 = Theme.muted,
	TextSize = 12,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, statusRow)

local runButton = create("TextButton", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = Theme.running,
	BorderSizePixel = 0,
	Text = "Start farming",
	TextColor3 = Theme.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	Selectable = true,
	LayoutOrder = 2,
}, halloweenPage)
round(runButton, 7)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Text = "FARM CONTROL",
	TextColor3 = Theme.outline,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
}, halloweenPage)

local farmInfo = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 42),
	BackgroundTransparency = 1,
	Text = "Start or stop the Halloween candy farming loop.",
	TextColor3 = Theme.muted,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 3,
}, halloweenPage)

local readoutCard = create("Frame", {
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundColor3 = Theme.surface,
	BorderSizePixel = 0,
	LayoutOrder = 3,
}, homePage)
round(readoutCard, 7)

local readoutLabel = create("TextLabel", {
	Size = UDim2.new(1, -24, 1, -16),
	Position = UDim2.fromOffset(12, 8),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Theme.text,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = true,
}, readoutCard)

local statsBlock = create("Frame", {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = Theme.surface,
	BorderSizePixel = 0,
	LayoutOrder = 4,
}, homePage)
round(statsBlock, 7)

local collectedValue = create("TextLabel", {
	Size = UDim2.new(0.5, 0, 0, 30),
	Position = UDim2.fromOffset(0, 7),
	BackgroundTransparency = 1,
	Text = "0",
	TextColor3 = Theme.text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
}, statsBlock)

create("TextLabel", {
	Size = UDim2.new(0.5, 0, 0, 16),
	Position = UDim2.fromOffset(0, 38),
	BackgroundTransparency = 1,
	Text = "COLLECTED",
	TextColor3 = Theme.muted,
	TextSize = 9,
	Font = Enum.Font.GothamBold,
}, statsBlock)

create("Frame", {
	Size = UDim2.fromOffset(1, 42),
	Position = UDim2.new(0.5, 0, 0.5, -21),
	BackgroundColor3 = Theme.divider,
	BorderSizePixel = 0,
}, statsBlock)

local lapsValue = create("TextLabel", {
	Size = UDim2.new(0.5, 0, 0, 30),
	Position = UDim2.new(0.5, 0, 0, 7),
	BackgroundTransparency = 1,
	Text = "0",
	TextColor3 = Theme.text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
}, statsBlock)

create("TextLabel", {
	Size = UDim2.new(0.5, 0, 0, 16),
	Position = UDim2.new(0.5, 0, 0, 38),
	BackgroundTransparency = 1,
	Text = "LAPS",
	TextColor3 = Theme.muted,
	TextSize = 9,
	Font = Enum.Font.GothamBold,
}, statsBlock)

local settingsHeading = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Text = "HALLOWEEN OPTIONS",
	TextColor3 = Theme.outline,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
}, halloweenPage)

local function createSettingRow(parent, layoutOrder, title, description)
	local row = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.surface,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = layoutOrder,
		Selectable = true,
	}, parent)
	round(row, 7)

	create("TextLabel", {
		Size = UDim2.new(1, -72, 0, 20),
		Position = UDim2.fromOffset(11, 8),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.text,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	create("TextLabel", {
		Size = UDim2.new(1, -72, 0, 16),
		Position = UDim2.fromOffset(11, 30),
		BackgroundTransparency = 1,
		Text = description,
		TextColor3 = Theme.muted,
		TextSize = 9,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local track = create("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = Theme.stopped,
		BorderSizePixel = 0,
	}, row)
	round(track, 10)

	local knob = create("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Theme.text,
		BorderSizePixel = 0,
	}, track)
	round(knob, 7)
	return row, track, knob
end

local orderRow, orderTrack, orderKnob = createSettingRow(
	halloweenPage, 4, "Highest value first", "Collect higher-value candy before the rest"
)

local function setSwitch(track, knob, enabled)
	track.BackgroundColor3 = enabled and Theme.running or Theme.stopped
	knob.Position = enabled and UDim2.new(1, -17, 0, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Theme.text
end

local minimized = false
local expandedSize = panel.Size

minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	sidebar.Visible = not minimized
	panel.Size = minimized and UDim2.new(expandedSize.X.Scale, expandedSize.X.Offset, 0, 54) or expandedSize
	minimizeButton.Text = minimized and "Expand" or "Minimize"
end)

local dragging = false
local dragStart
local panelStart

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		panelStart = panel.Position
	end
end)

local dragEndConnection = UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local dragConnection = UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		panel.Position = UDim2.new(
			panelStart.X.Scale,
			panelStart.X.Offset + delta.X,
			panelStart.Y.Scale,
			panelStart.Y.Offset + delta.Y
		)
	end
end)

screen.Destroying:Connect(function()
	dragConnection:Disconnect()
	dragEndConnection:Disconnect()
end)

local function refreshRunState()
	local stateColor = Config.running and Theme.running or Theme.stopped

	runButton.Text = Config.running and "Stop farming" or "Start farming"
	statusLabel.Text = Config.running and "Running" or "Stopped"
	statusLabel.TextColor3 = Config.running and Theme.text or Theme.muted
	statusDot.BackgroundColor3 = stateColor
	sidebarStatusText.Text = Config.running and "Farm is running" or "Panel is ready"
	sidebarStatusDot.BackgroundColor3 = stateColor
	TweenService:Create(runButton, TweenInfo.new(0.15), { BackgroundColor3 = stateColor }):Play()
end

local function refreshOrder()
	setSwitch(orderTrack, orderKnob, Config.highestValueFirst)
end

local function showTab(tabName)
	local isHome = tabName == "Home"
	local isFarm = tabName == "Farm"
	homePage.Visible = isHome
	farmPage.Visible = isFarm
	halloweenPage.Visible = not isHome and not isFarm

	titleLabel.Text = tabName
	subtitleLabel.Text = isHome and "Overview and farming status"
		or (isFarm and "Egg farming — coming soon" or "Halloween candy farm controls")
	homeTab.BackgroundColor3 = isHome and Theme.surface or Theme.sidebar
	homeAccent.Visible = isHome
	homeTabText.TextColor3 = isHome and Theme.text or Theme.muted
	farmTab.BackgroundColor3 = isFarm and Theme.surface or Theme.sidebar
	farmAccent.Visible = isFarm
	farmTabText.TextColor3 = isFarm and Theme.text or Theme.muted
	halloweenTab.BackgroundColor3 = not isHome and not isFarm and Theme.surface or Theme.sidebar
	halloweenAccent.Visible = not isHome and not isFarm
	halloweenTabText.TextColor3 = not isHome and not isFarm and Theme.text or Theme.muted
end

local function readouts()
	local candies = getCandyList()
	local firstLine
	if #candies > 0 then
		firstLine = ("Next %s · %d left"):format(candies[1].instance.Name, #candies)
	else
		firstLine = ("Waiting for candies in workspace.%s"):format(CANDY_FOLDER)
	end

	local timing = ("Tap %s %.2fs · %.1fs per candy"):format(PICKUP_KEY.Name, Config.keyTap, Config.cycleLength)
	local statsText = ("Collected %d  ·  Laps %d"):format(stats.collected, stats.laps)
	return firstLine .. "\n" .. timing, statsText
end

runButton.MouseButton1Click:Connect(function()
	Config.running = not Config.running
	refreshRunState()
end)

orderRow.MouseButton1Click:Connect(function()
	Config.highestValueFirst = not Config.highestValueFirst
	refreshOrder()
end)

homeTab.MouseButton1Click:Connect(function()
	showTab("Home")
end)

farmTab.MouseButton1Click:Connect(function()
	showTab("Farm")
end)

halloweenTab.MouseButton1Click:Connect(function()
	showTab("Halloween")
end)

closeButton.MouseButton1Click:Connect(function()
	Config.running = false
	screen:Destroy()
end)

for _, tab in ipairs({ homeTab, farmTab, halloweenTab }) do
	tab.MouseEnter:Connect(function()
		local active = (tab == homeTab and homePage.Visible)
			or (tab == farmTab and farmPage.Visible)
			or (tab == halloweenTab and halloweenPage.Visible)
		if not active then
			TweenService:Create(tab, TweenInfo.new(0.12), { BackgroundColor3 = Theme.surface }):Play()
		end
	end)
	tab.MouseLeave:Connect(function()
		local active = (tab == homeTab and homePage.Visible)
			or (tab == farmTab and farmPage.Visible)
			or (tab == halloweenTab and halloweenPage.Visible)
		TweenService:Create(tab, TweenInfo.new(0.12), {
			BackgroundColor3 = active and Theme.surface or Theme.sidebar,
		}):Play()
	end)
end

for _, row in ipairs({ orderRow }) do
	row.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), {
			BackgroundColor3 = Theme.surface:Lerp(Color3.new(1, 1, 1), 0.08),
		}):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = Theme.surface }):Play()
	end)
end

closeButton.MouseEnter:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.12), { TextColor3 = Theme.text }):Play()
end)

closeButton.MouseLeave:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.12), { TextColor3 = Theme.muted }):Play()
end)

minimizeButton.MouseEnter:Connect(function()
	TweenService:Create(minimizeButton, TweenInfo.new(0.12), { BackgroundColor3 = Theme.divider }):Play()
end)

minimizeButton.MouseLeave:Connect(function()
	TweenService:Create(minimizeButton, TweenInfo.new(0.12), { BackgroundColor3 = Theme.surface }):Play()
end)

-- UI update loop
task.spawn(function()
	local shownReadout, shownStats = "", ""
	refreshRunState()
	refreshOrder()
	showTab("Home")

	while screen.Parent do
		local readout, statsText = readouts()
		if readout ~= shownReadout then
			readoutLabel.Text = readout
			shownReadout = readout
		end
		if statsText ~= shownStats then
			collectedValue.Text = tostring(stats.collected)
			lapsValue.Text = tostring(stats.laps)
			shownStats = statsText
		end

		task.wait(0.3)
	end
end)

print(("[CandyFarm] Panel ready. Probing %d keyword names for a pickup remote."):format(#Config.discoverKeywords))