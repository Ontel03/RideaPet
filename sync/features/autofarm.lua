--[[
	AutoFarm Feature - Main farming loop controller.
	Runs in the background and handles the candy collection cycle.
]]

-- Reference to services and state (set by loader)
local Config = ...
local Utils = ...
local Candy = ...
local Pickup = ...
local Movement = ...
local Stats = ...

-- Main farming loop (called from the loader's background task)
function Services.farmLoop()
	while true do
		task.wait(0.2)
		if Config.running then
			local list = Candy.getCandyList()
			if #list == 0 then
				task.wait(1.5)
			else
				for _, candy in ipairs(list) do
					if not Config.running then break end
					local pos = Candy.getWorldPosition(candy.instance)
					if pos and candy.instance.Parent then
						Movement.runCandyCycle(candy, pos, rootPart, Stats)
					end
				end
				Stats.incrementLaps()
			end
		end
	end
end

--[[
--[[
-- Function to stop the farm loop (called from UI)
--]]
function Services.stopFarm()
	Config.running = false
end

return Services