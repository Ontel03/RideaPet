-- Walks the whole auto-buy chain and reports where it breaks.

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

-- 1. Candy total, the same way the loader reads it.
local saved = player:FindFirstChild("SavedData")
print("SavedData = " .. tostring(saved and saved:GetFullName()))
local holder = saved and saved:FindFirstChild("HalloweenCandy")
print("HalloweenCandy = " .. tostring(holder and holder:GetFullName()) .. " class=" .. tostring(holder and holder.ClassName))
if holder then
	print("  value = " .. tostring(holder.Value) .. "  type=" .. type(holder.Value))
end

-- 2. The egg remote.
local buy = findRemote("BuyHalloweenEgg")
print("BuyHalloweenEgg = " .. tostring(buy and buy.ClassName))

if not buy or not holder then
	print("STOP: salah satu remote/variable tidak ada")
	return
end

-- 3. Try the call shapes and read each verdict.
local shapes = {
	{ "noargs", function() return buy:InvokeServer() end },
	{ "true", function() return buy:InvokeServer(true) end },
	{ "1", function() return buy:InvokeServer(1) end },
	{ "auto", function() return buy:InvokeServer("auto") end },
}

for _, shape in ipairs(shapes) do
	local before = holder.Value
	local ok, reply = pcall(shape[2])
	task.wait(1)
	local after = holder.Value
	print(string.format("%s ok=%s reply=%s candy %s -> %s", shape[1], tostring(ok),
		tostring(reply), tostring(before), tostring(after)))
end