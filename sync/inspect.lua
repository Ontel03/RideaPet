-- CollectCandy likely takes the candy's name string, not the Instance. Verify by trying
-- the instance name against the live folder children.

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

local folder = workspace:FindFirstChild("HalloweenCandy")
local collect = findRemote("CollectCandy")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if not folder or #folder:GetChildren() == 0 or not collect then
	print("tidak ada candy atau remote")
	return
end

-- Names of the live candy folder, so we know what strings to try.
local names = {}
for index, candy in ipairs(folder:GetChildren()) do
	if index <= 5 then names[index] = candy.Name end
end
print("names: " .. table.concat(names, ", ") .. " (total " .. #folder:GetChildren() .. ")")

-- Try firing CollectCandy with the name string.
local target = folder:GetChildren()[1]
local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
if part and rootPart then
	rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
end
task.wait(1)

local before = #folder:GetChildren()
collect:FireServer(target.Name)
task.wait(2)
local after = #folder:GetChildren()
print(("byName: count %d -> %d, parent=%s"):format(before, after,
	tostring(target.Parent and target.Parent.Name or "nil")))