--[[
	Stats Module - Collected and laps tracking.
	Simple counter for farming statistics.
]]

local Stats = { collected = 0, laps = 0 }

-- Increment collected count
function Stats.incrementCollected() Stats.collected = Stats.collected + 1 end

-- Increment laps count
function Stats.incrementLaps() Stats.laps = Stats.laps + 1 end

-- Get current stats as a table
function Stats.get() return { collected = Stats.collected, laps = Stats.laps } end

-- Format stats for display
function Stats.format() return ("Collected %d  ·  Laps %d"):format(Stats.collected, Stats.laps) end

return Stats