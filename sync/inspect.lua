-- Candy inspector: one-time dump of what the event actually exposes.
-- Paste in the executor. Everything prints to the console.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("== WORKSPACE ==")
for _, child in ipairs(workspace:GetChildren()) do
	print("  " .. child.Name .. " [" .. child.ClassName .. "]")
end

print("== HalloweenCandy ==")
local folder = workspace:FindFirstChild("HalloweenCandy")
if not folder then
	print("  NOT FOUND")
else
	print("  count: " .. #folder:GetChildren())
	for index, candy in ipairs(folder:GetChildren()) do
		if index > 2 then
			print("  ...more")
			break
		end
		print("  " .. candy.Name .. " [" .. candy.ClassName .. "]")
		for _, descendant in ipairs(candy:GetDescendants()) do
			print("    - " .. descendant.Name .. " [" .. descendant.ClassName .. "]")
		end
	end
end

print("== Remotes ==")
for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
	if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
		print("  " .. remote:GetFullName())
	end
end

print("== Tools ==")
local player = Players.LocalPlayer
for _, tool in ipairs(player.Backpack:GetChildren()) do
	print("  backpack: " .. tool.Name)
end