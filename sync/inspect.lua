-- Captures the exact client-to-server calls the game makes during a manual pickup.
-- Instance property writes are blocked by Roblox, so the class metatable is wrapped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local TRACK = { CollectCandy = true, DropCandy = true, GetCandyState = true, HalloweenCandy = true }

local tracked = {}
for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
	for _, remote in ipairs(container:GetDescendants()) do
		if TRACK[remote.Name] and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
			tracked[remote] = true
		end
	end
end

local function describe(value)
	if type(value) == "Instance" then
		return "<" .. value.Name .. "/" .. value.ClassName .. ">"
	end
	return tostring(value)
end

local metatable = getmetatable(next(tracked))
local oldIndex = metatable.__index
metatable.__index = function(instance, key)
	local value = oldIndex(instance, key)
	if tracked[instance] and (key == "FireServer" or key == "InvokeServer") then
		return function(_, ...)
			local parts = {}
			for index = 1, select("#", ...) do
				parts[index] = describe((select(index, ...)))
			end
			print("[call] " .. instance.Name .. "(" .. table.concat(parts, ", ") .. ")")
			return value(instance, ...)
		end
	end
	return value
end
print("hooked, sekarang ambil candy MANUAL")

-- Also show how a candy identifies itself.
local folder = workspace:FindFirstChild("HalloweenCandy")
local candy = folder and folder:GetChildren()[1]
if candy then
	print("candy: " .. candy.Name .. " [" .. candy.ClassName .. "]")
	for attribute, value in pairs(candy:GetAttributes()) do
		print("  attr " .. attribute .. " = " .. tostring(value))
	end
	for index, child in ipairs(candy:GetChildren()) do
		if index > 4 then break end
		print("  child " .. child.Name .. " [" .. child.ClassName .. "]")
		for attribute, value in pairs(child:GetAttributes()) do
			print("    attr " .. attribute .. " = " .. tostring(value))
		end
	end
end