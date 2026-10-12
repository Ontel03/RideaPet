-- Tests BuyHalloweenEgg with several call shapes and reports what the server answers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local replies = {}
local WATCH = { EggBroke = true, EggTimerPause = true, ResumeHatch = true, Hatch = true }

for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
	for _, remote in ipairs(container:GetDescendants()) do
		if remote:IsA("RemoteEvent") and WATCH[remote.Name] then
			remote.OnClientEvent:Connect(function(...)
				local parts = {}
				for index = 1, select("#", ...) do
					parts[index] = tostring(select(index, ...))
				end
				replies[#replies + 1] = remote.Name .. " " .. table.concat(parts, ", ")
				print("[reply] " .. replies[#replies])
			end)
		end
	end
end

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

local buy = findRemote("BuyHalloweenEgg")
local getState = findRemote("GetCandyState")
print("buy=" .. tostring(buy and buy.ClassName))

local function candyTotal()
	local ok, state = pcall(function()
		return getState:InvokeServer()
	end)
	if not ok or type(state) ~= "table" then return nil end
	local total = 0
	for _, value in pairs(state) do
		if type(value) == "number" then total = total + value end
	end
	return total
end

local before = candyTotal()
print("candy sebelum: " .. tostring(before))

-- Try the plain call first: most games buy one egg with no arguments.
pcall(function()
	if buy:IsA("RemoteFunction") then buy:InvokeServer() else buy:FireServer() end
end)
task.wait(2)

local after = candyTotal()
print("candy sesudah: " .. tostring(after))
print("selisih: " .. tostring((after or 0) - (before or 0)))
print("replies: " .. tostring(#replies))