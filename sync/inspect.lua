-- The candy folder children carry a SpawnId attribute (Candy1_12 style). That is the
-- identity the server reports, so CollectCandy most likely wants it instead of Name.

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
local drop = findRemote("DropCandy")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if not folder or #folder:GetChildren() == 0 or not collect then
	print("tidak ada candy atau remote")
	return
end

local function try(label, fire)
	local candies = folder:GetChildren()
	if #candies == 0 then
		print(label .. " = NO CANDY")
		return false
	end
	local target = candies[1]
	local spawnId = target:GetAttribute("SpawnId")
	local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
	if part and rootPart then
		rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
	end
	task.wait(1)

	local before = #folder:GetChildren()
	fire(spawnId, target)
	task.wait(2)
	local gone = not target.Parent
	print(string.format("%s spawnId=%s count %d -> %d %s", label, tostring(spawnId), before, #folder:GetChildren(), gone and "OK" or "fail"))
	return gone
end

try("spawnId", function(spawnId, target)
	if spawnId then collect:FireServer(spawnId) else collect:FireServer(target.Name) end
end)

if drop and #folder:GetChildren() > 0 then
	try("spawnId+player", function(spawnId, target)
		if spawnId then collect:FireServer(spawnId, player) else collect:FireServer(target) end
	end)
end

-- Drop whatever was collected, in case the score only lands after DropCandy.
if drop then
	local pad
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "DoorCandyDrop" then
			pad = descendant
			break
		end
	end
	if pad and rootPart then
		rootPart.CFrame = CFrame.new(pad.Position + Vector3.new(0, 2, 0))
		task.wait(1)
		drop:FireServer()
		task.wait(2)
		print("drop fired")
	end
end