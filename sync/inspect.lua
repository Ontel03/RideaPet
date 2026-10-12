-- Tries BuyHalloweenEgg from the NPC position, and reports the full player state the
-- server might be checking.

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

-- Locate the egg NPC.
local npcPart
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and (descendant.Name:find("Egg") or descendant.Name:find("NPC") or descendant.Name:find("Shop")) then
		npcPart = descendant
		print("NPC candidate: " .. descendant:GetFullName())
		break
	end
end

-- Report the saved-data state the server may check.
local saved = player:FindFirstChild("SavedData")
if saved then
	for _, child in ipairs(saved:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then
			print("SavedData." .. child.Name .. " = " .. tostring(child.Value))
		end
	end
end

local noSave = player:FindFirstChild("NoSaveData")
if noSave then
	for _, child in ipairs(noSave:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then
			print("NoSaveData." .. child.Name .. " = " .. tostring(child.Value))
		end
	end
end

local buy = findRemote("BuyHalloweenEgg")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local holder = saved and saved:FindFirstChild("HalloweenCandy")
local before = holder and holder.Value

-- Try from the NPC first, then from the pad.
for _, target in ipairs({ npcPart, workspace:FindFirstChild("CandyDropOff") }) do
	if target and rootPart then
		local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
		if part then
			rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
			task.wait(1)
			local ok, reply = pcall(function()
				return buy:InvokeServer()
			end)
			task.wait(1)
			print(string.format("from %s ok=%s reply=%s candy %s -> %s",
				part.Name, tostring(ok), tostring(reply),
				tostring(before), tostring(holder and holder.Value)))
		end
	end
end