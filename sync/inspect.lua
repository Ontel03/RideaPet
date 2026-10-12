-- No ProximityPrompt exists, so the shop UI must be opened by a remote. Tests
-- OpenHalloween before the purchase, plus a ClickDetector fallback.

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
local anchor = shop and shop:FindFirstChild("HalloweenHomeAnchor")
local buy = findRemote("BuyHalloweenEgg")
local open = findRemote("OpenHalloween")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local saved = player:FindFirstChild("SavedData")
local holder = saved and saved:FindFirstChild("HalloweenCandy")

print("OpenHalloween = " .. tostring(open and open.ClassName))
print("BuyHalloweenEgg = " .. tostring(buy and buy.ClassName))

-- Any click detector on the shop parts?
for _, descendant in ipairs((shop or workspace):GetDescendants()) do
	if descendant:IsA("ClickDetector") then
		print("ClickDetector: " .. descendant:GetFullName())
	end
end

local function attempt(label)
	local before = holder and holder.Value
	local ok, reply = pcall(function()
		return buy:InvokeServer()
	end)
	task.wait(1)
	print(string.format("%s ok=%s reply=%s candy %s -> %s", label, tostring(ok), tostring(reply),
		tostring(before), tostring(holder and holder.Value)))
end

if not (buy and anchor and rootPart) then
	print("STOP: remote atau anchor tidak ada")
	return
end

rootPart.CFrame = CFrame.new(anchor.Position + Vector3.new(0, 2, 0))
task.wait(1)

if open then
	if open:IsA("RemoteFunction") then
		pcall(function() open:InvokeServer() end)
	else
		open:FireServer()
	end
	task.wait(2)
	attempt("setelahOpenHalloween")

	-- The UI may expect a second call to confirm the selection.
	local ok, reply = pcall(function()
		return buy:InvokeServer(anchor)
	end)
	task.wait(1)
	print("buy(anchor) ok=" .. tostring(ok) .. " reply=" .. tostring(reply)
		.. " candy=" .. tostring(holder and holder.Value))
else
	attempt("tanpaOpen")
end