-- Finds how many candies are held and what an egg costs, before wiring an auto-buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findRemote(name)
	for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
		for _, remote in ipairs(container:GetDescendants()) do
			if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and remote.Name == name then
				return remote
			end
		end
	end
	return nil
end

-- 1. How many candies are held right now.
local getState = findRemote("GetCandyState")
if getState then
	local ok, state = pcall(function()
		return getState:InvokeServer()
	end)
	if ok and type(state) == "table" then
		local total, shown = 0, 0
		for key, value in pairs(state) do
			if type(value) == "number" then
				total = total + value
				if shown < 8 then
					print(string.format("  %s = %d", tostring(key), value))
					shown = shown + 1
				end
			end
		end
		print("TOTAL CANDY = " .. tostring(total))
	else
		print("state bukan table: " .. type(state))
	end
else
	print("GetCandyState tidak ada")
end

-- 2. Egg cost, if any object advertises it.
local shown = 0
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant.Name:find("Egg") and shown < 4 then
		local attributes = descendant:GetAttributes()
		local parts = {}
		for attribute, value in pairs(attributes) do
			parts[#parts + 1] = attribute .. "=" .. tostring(value)
		end
		if #parts > 0 then
			print("EGG " .. descendant:GetFullName() .. " [" .. descendant.ClassName .. "]")
			print("  " .. table.concat(parts, ", "))
			shown = shown + 1
		end
	end
end