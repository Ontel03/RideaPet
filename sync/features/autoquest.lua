--[[
	AutoQuest Feature - Slot for auto-completing quests.
	Currently a placeholder - logic to be added later.
]]

-- Reference to services (set by loader)
local Config = ...
local Utils = ...

-- Function to start auto-quest (to be implemented)
function Services.startAutoQuest() print("[Features] AutoQuest started (placeholder)") end

-- Function to stop auto-quest (to be implemented)
function Services.stopAutoQuest() print("[Features] AutoQuest stopped (placeholder)") end

-- Check if auto-quest should run (to be implemented in loader)
function Services.isAutoQuestEnabled() return false end

return Services