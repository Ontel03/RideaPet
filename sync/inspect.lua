-- Sweeps many call shapes for BuyHalloweenEgg from the shop anchor. OpenHalloween does
-- not exist, so the purchase must be reachable directly.

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

local shop = workspace:FindFirstChild("HalloweenEggShop")
local anchor
if shop then
	for _, descendant in ipairs(shop:GetDescendants()) do
		if descendant.Name == "HalloweenHomeAnchor" then anchor = descendant end
	end
end

local buy = findRemote("BuyHalloweenEgg")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local saved = player:FindFirstChild("SavedData")
local holder = saved and saved:FindFirstChild("HalloweenCandy")

print("anchor=" .. tostring(anchor and anchor:GetFullName()))
print("buy=" .. tostring(buy and buy.ClassName))

if saved then
	for _, child in ipairs(saved:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") or child:IsA("BoolValue") then
			print("  SavedData." .. child.Name .. " = " .. tostring(child.Value))
		end
	end
end

if not (buy and anchor and rootPart) then
	print("STOP: ada yang null")
	return
end

rootPart.CFrame = CFrame.new(anchor.Position + Vector3.new(0, 2, 0))
task.wait(1)

local shapes = {
	{ "noargs", function() return buy:InvokeServer() end },
	{ "anchor", function() return buy:InvokeServer(anchor) end },
	{ "shop", function() return buy:InvokeServer(shop) end },
	{ "'Halloween'", function() return buy:InvokeServer("Halloween") end },
	{ "'HalloweenEgg'", function() return buy:InvokeServer("HalloweenEgg") end },
	{ "'Egg'", function() return buy:InvokeServer("Egg") end },
	{ "true", function() return buy:InvokeServer(true) end },
	{ "1,true", function() return buy:InvokeServer(1, true) end },
}

for _, shape in ipairs(shapes) do
	local before = holder and holder.Value
	local ok, reply = pcall(shape[2])
	task.wait(0.8)
	local after = holder and holder.Value
	print(string.format("%s ok=%s reply=%s candy %s -> %s", shape[1], tostring(ok),
		tostring(reply), tostring(before), tostring(after)))
end