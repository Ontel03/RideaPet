-- Pickup works with SpawnId. Now the collected candy becomes DroppedCandy_<uuid> that
-- must be carried to the drop-off. Tries the ways DropCandy might accept that identity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local deposits = 0
for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
	for _, remote in ipairs(container:GetDescendants()) do
		if remote:IsA("RemoteEvent") and remote.Name == "HalloweenCandyDeposited" then
			remote.OnClientEvent:Connect(function(...)
				deposits = deposits + 1
				local parts = {}
				for index = 1, select("#", ...) do
					parts[index] = tostring(select(index, ...))
				end
				print("[DEPOSITED] " .. table.concat(parts, ", "))
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

local collect = findRemote("CollectCandy")
local drop = findRemote("DropCandy")
local folder = workspace:FindFirstChild("HalloweenCandy")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

local pad
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.Name == "DoorCandyDrop" then
		pad = descendant
		break
	end
end

local function findDropped()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:find("DroppedCandy") then
			return descendant
		end
	end
	return nil
end

-- 1. Collect one candy.
local candies = folder and folder:GetChildren()
if not candies or #candies == 0 or not collect then
	print("tidak ada candy")
	return
end
local target = candies[1]
local spawnId = target:GetAttribute("SpawnId")
local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
if part and rootPart then
	rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
end
task.wait(1)
collect:FireServer(spawnId)
task.wait(2)

local carried = findDropped()
print("carried: " .. tostring(carried and carried.Name or "tidak ada") .. " deposits=" .. deposits)

if not drop or not carried then
	print("cuma bisa collect")
	return
end

-- 2. Stand at the drop-off.
if pad and rootPart then
	rootPart.CFrame = CFrame.new(pad.Position + Vector3.new(0, 2, 0))
end
task.wait(1)

local uuid = carried.Name:match("DroppedCandy_(.+)")
print("uuid=" .. tostring(uuid))

-- 3. Try deposit variants until the server confirms one.
local before = deposits
drop:FireServer(uuid)
task.wait(2)
if deposits > before then print("variant uuid = OK") end

before = deposits
drop:FireServer(carried)
task.wait(2)
if deposits > before then print("variant instance = OK") end

before = deposits
drop:FireServer()
task.wait(2)
if deposits > before then print("variant noargs = OK") end

print("total deposits: " .. deposits)