-- Minimal probe: prints only what is needed to identify the pickup mechanism.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = workspace:FindFirstChild("HalloweenCandy")
local candy = folder and folder:GetChildren()[1]

if not candy then
	print("CANDY: tidak ada")
else
	local hasPrompt = candy:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
	local hasClick = candy:FindFirstChildWhichIsA("ClickDetector", true) ~= nil
	local hasTool = candy:FindFirstChildWhichIsA("Tool", true) ~= nil
	print(string.format("CANDY: %s [%s] jml=%d prompt=%s click=%s tool=%s",
		candy.Name, candy.ClassName, #folder:GetChildren(),
		tostring(hasPrompt), tostring(hasClick), tostring(hasTool)))
end

local names = {}
for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
	if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
		names[#names + 1] = remote.Name
	end
end
print("REMOTE(" .. #names .. "): " .. table.concat(names, ", "))

local drop = workspace:FindFirstChild("CandyDropOff")
print("DROPOFF: " .. (drop and drop.Name or "tidak ada"))