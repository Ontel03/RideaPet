--[[
	AutoSell Feature - Slot for auto-selling items.
	Currently a placeholder - logic to be added later.
]]

-- Reference to services (set by loader)
local Config = ...
local Utils = ...

-- Function to start auto-sell (to be implemented)
function Services.startAutoSell() print("[Features] AutoSell started (placeholder)") end

-- Function to stop auto-sell (to be implemented)
function Services.stopAutoSell() print("[Features] AutoSell stopped (placeholder)") end

-- Check if auto-sell should run (to be implemented in loader)
function Services.isAutoSellEnabled() return false end

return Services