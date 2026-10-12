-- Watches one candy through a CollectCandy call and reports what actually happened to
-- it: destroyed, reparented, or untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

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

-- Log anything the game itself sends, so a manual pickup can be copied later.
local armed = {}
for _, container in ipairs({ ReplicatedStorage }) do
	for _, remote in ipairs(container:GetDescendants()) do
		if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and remote.Name:find("Candy") then
			armed[#armed + 1] = remote.Name
			for _, method in ipairs({ "FireServer", "InvokeServer" }) do
				local original = remote[method]
				remote[method] = function(self, ...)
					local parts = {}
					for index = 1, select("#", ...) do
						local value = select(index, ...)
						parts[index] = type(value) == "Instance" and ("<" .. value.ClassName .. ":" .. value:GetFullName() .. ">")
							or tostring(value)
					end
					print("[hook] " .. remote.Name .. ":" .. method .. " " .. table.concat(parts, ", "))
					return original(self, ...)
				end
			end
		end
	end
end
print("hooked: " .. table.concat(armed, ", "))

local collect = findRemote("CollectCandy")
local folder = workspace:FindFirstChild("HalloweenCandy")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if not collect or not folder or #folder:GetChildren() == 0 then
	print("gak ada candy / remote")
	return
end

local target = folder:GetChildren()[1]
local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
if part and rootPart then
	rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
end

task.wait(1)
print("before: parent=" .. tostring(target.Parent and target.Parent:GetFullName()) .. " inFolder=" .. tostring(target.Parent == folder))

pcall(function()
	if collect:IsA("RemoteFunction") then
		collect:InvokeServer(target)
	else
		collect:FireServer(target)
	end
end)

task.wait(2)
print("after: parent=" .. tostring(target.Parent and target.Parent:GetFullName()) .. " inFolder=" .. tostring(target.Parent == folder))
print("count now: " .. tostring(#folder:GetChildren()))