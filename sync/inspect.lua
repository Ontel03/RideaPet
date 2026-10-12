-- Listens to server replies instead of hooking methods (Roblox blocks property writes
-- on Instances). Reports both what the server sends back and what happens to the candy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local replies = {}
for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
	for _, remote in ipairs(container:GetDescendants()) do
		if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and remote.Name:find("Candy") then
			remote.OnClientEvent:Connect(function(...)
				local parts = {}
				for index = 1, select("#", ...) do
					local value = select(index, ...)
					parts[index] = type(value) == "Instance" and ("<" .. value.Name .. ">") or tostring(value)
				end
				local line = "[reply] " .. remote.Name .. " " .. table.concat(parts, ", ")
				replies[#replies + 1] = line
				print(line)
			end)
		end
	end
end
print("listening")

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

local collect = findRemote("CollectCandy")
local folder = workspace:FindFirstChild("HalloweenCandy")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if not collect or not folder or #folder:GetChildren() == 0 then
	print("tidak ada candy atau remote")
	return
end

local target = folder:GetChildren()[1]
local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
if part and rootPart then
	rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
end

task.wait(1)
print("before parent=" .. tostring(target.Parent and target.Parent:GetFullName()) .. " count=" .. tostring(#folder:GetChildren()))

pcall(function()
	if collect:IsA("RemoteFunction") then
		collect:InvokeServer(target)
	else
		collect:FireServer(target)
	end
end)

task.wait(2)
print("after parent=" .. tostring(target.Parent and target.Parent:GetFullName()) .. " count=" .. tostring(#folder:GetChildren()))
print("replies=" .. tostring(#replies))