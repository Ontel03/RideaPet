--[[
	Candy Module - Detection and folder management.
	Handles finding candies, sorting by value, and world positions.
]]

-- Reference to config and utilities (set by loader)
local Config = ...
local Utils = ...

-- Get the candy folder from workspace
function Services.getCandyFolder()
	return workspace:FindFirstChild(Config.CANDY_FOLDER_NAME)
end

-- Get the drop-off pad (looks for "Pad" child, else the folder itself)
function Services.getDropOffPad()
	local dropOff = workspace:FindFirstChild(Config.DROP_OFF_NAME)
	if not dropOff then return nil end
	return dropOff:FindFirstChild("Pad") or dropOff
end

-- Get a sorted list of candies with their values
function Services.getCandyList()
	local folder = Services.getCandyFolder()
	if not folder then return {} end
	local list = {}
	for _, c in ipairs(folder:GetChildren()) do
		local v = tonumber(c.Name:match("%d+")) or 0
		table.insert(list, { instance = c, value = v })
	end
	table.sort(list, function(a, b)
		return Config.highestValueFirst and a.value > b.value or a.value < b.value
	end)
	return list
end

-- Get world position of an object (BasePart, Model, or Folder)
function Services.getWorldPosition(obj)
	return Utils.getWorldPosition(obj)
end

return Services