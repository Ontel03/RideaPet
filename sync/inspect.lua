-- Verifies the candy total reader against the number shown in the game UI.
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

local function sumNumbers(value, depth)
	if type(value) == "number" then return value end
	if type(value) ~= "table" or (depth or 0) > 3 then return 0 end
	local total = 0
	for _, item in pairs(value) do
		total = total + sumNumbers(item, (depth or 0) + 1)
	end
	return total
end

local state = findRemote("GetCandyState")
local ok, result = pcall(function()
	return state:InvokeServer()
end)

if not ok then
	print("gagal baca state: " .. tostring(result))
	return
end

-- Top level only, for comparison with the recursive sum.
local flat = 0
local flatKeys = 0
for _, value in pairs(result) do
	if type(value) == "number" then
		flat = flat + value
		flatKeys = flatKeys + 1
	end
end

print("top-level keys=" .. flatKeys .. " sum=" .. flat)
print("recursive sum=" .. sumNumbers(result, 0))
print("UI lu bilang 376 -- cocoknya yang mana?")