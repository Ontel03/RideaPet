-- Compact probe: prints two short lines so the result fits in one screenshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = workspace:FindFirstChild("HalloweenCandy")
local candy = folder and folder:GetChildren()[1]

if candy then
	print(string.format("CANDY [%s] n=%d prompt=%s click=%s",
		candy.ClassName,
		#folder:GetChildren(),
		tostring(candy:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil),
		tostring(candy:FindFirstChildWhichIsA("ClickDetector", true) ~= nil)))
else
	print("CANDY: tidak ada")
end

local names = {}
for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
	if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
		names[#names + 1] = remote.Name
	end
end
print("REMOTE: " .. table.concat(names, ", "))