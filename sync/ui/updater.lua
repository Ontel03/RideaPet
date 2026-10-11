--[[
	UI Updater - Handles the update loop and button wiring.
	Refreshes UI state, reads stats, and handles button clicks.
]]

local Theme = ...
local Config = ...
local Stats = ...
local Pickup = ...

-- Readouts function (simplified)
local function readouts()
	local candies = Candy.getCandyList()
	local line1 = #candies > 0 and ("Next %s · %d left"):format(candies[1].instance.Name, #candies) or ("Waiting for candies in workspace." .. Config.CANDY_FOLDER_NAME)
	local line2 = ("Hold %s %.1fs · %.1fs per candy"):format("E", Config.keyHold, Config.cycleLength)
	return line1 .. "\n" .. line2, Stats.format()
end

-- Refresh run state
local function refreshRunState()
	local c = Config.running and Theme.running or Theme.stopped
	-- runButton.Text = Config.running and "Stop" or "Start"
	-- statusLabel.Text = Config.running and "Running" or "Stopped"
	-- statusDot.BackgroundColor3 = c
	-- TweenService:Create(runButton, TweenInfo.new(0.15), { BackgroundColor3 = c }):Play()
end

-- Refresh order
local function refreshOrder()
	-- orderButton.Text = Config.highestValueFirst and "Pickup order: highest" or "Pickup order: lowest"
end

-- Refresh mode
local function refreshMode() end

-- Wire buttons
local function wireButtons() end

-- Start update loop
local function startUpdateLoop() end

return {
	readouts = readouts,
	refreshRunState = refreshRunState,
	refreshOrder = refreshOrder,
	refreshMode = refreshMode,
	wireButtons = wireButtons,
	startUpdateLoop = startUpdateLoop,
}