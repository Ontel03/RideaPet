--[[
	Movement Module - Teleport, key hold, and cycle pacing.
	Handles teleportation to candies, holding the pickup key, and cycle timing.
]]

-- Reference to config, utils, and other services (set by loader)
local Config = ...
local Utils = ...
local Pickup = ...

-- Run one complete cycle for a candy (remote or teleport fallback)
function Services.runCandyCycle(candy, position, rootPart, Stats)
	local started = os.clock()
	local pad = Candy.getDropOffPad()

	if pickupState.remote and Config.useRemotePickup then
		-- Remote pickup mode
		if Config.standOnPad then
			local pp = Candy.getWorldPosition(pad)
			if pp then
				Utils.teleportTo(pp + Config.PAD_HOVER, rootPart)
				task.wait(Config.afterPadDelay)
			end
		end
		task.wait(Config.arriveDelay)
		if Pickup.sendPickup(candy.instance, pad) then Stats.incrementCollected() end
		local rem = Config.cycleLength - (os.clock() - started)
		if rem > 0 then task.wait(rem) end
		return
	end

	-- Fallback: teleport + key hold
	Utils.teleportTo(position + Config.CANDY_HOVER, rootPart)
	task.wait(Config.arriveDelay)
	Utils.holdPickupKey(Config.keyHold)
	Stats.incrementCollected()
	task.wait(Config.afterPickupDelay)

	local padPos = Candy.getWorldPosition(pad)
	if padPos then
		Utils.teleportTo(padPos + Config.PAD_HOVER, rootPart)
		task.wait(Config.afterPadDelay)
	end

	local rem = Config.cycleLength - (os.clock() - started)
	if rem > 0 then task.wait(rem) end
end

return Services