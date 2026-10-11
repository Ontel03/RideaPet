--[[
	Core Configuration - Candy Farm
	All tunable values live here.
]]

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
}

-- Discovery keywords for remote finding
Config.DISCOVER_KEYWORDS = {
	"candy", "sweet", "pick", "collect", "take", "grab", "drop",
	"submit", "reward", "item", "bag", "trick", "treat", "halloween", "ghost",
}

-- Deny keywords (remotes to avoid)
Config.DENY_KEYWORDS = { "buy", "shop", "purchase", "trade", "auction" }

-- Probe shapes for remote discovery
Config.PROBE_SHAPES = {
	"none",
	"candy",
	"pad+candy",
	"candy+player",
	"candy+pad+player",
}

return Config