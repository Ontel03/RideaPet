--[[
	AutoHatch Feature - Slot for auto-hatching eggs/pets.
	Currently a placeholder - logic to be added later.
]]

-- Reference to services (set by loader)
local Config = ...
local Utils = ...

-- Function to start auto-hatch (to be implemented)
function Services.startAutoHatch() print("[Features] AutoHatch started (placeholder)") end

-- Function to stop auto-hatch (to be implemented)
function Services.stopAutoHatch() print("[Features] AutoHatch stopped (placeholder)") end

-- Check if auto-hatch should run (to be implemented in loader)
function Services.isAutoHatchEnabled() return false end

return Services