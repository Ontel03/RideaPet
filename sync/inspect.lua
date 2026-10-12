-- The egg shop needs its prompt opened first, and the drop-off is a zone rather than a
-- part. Reports both structures and retries the purchase after opening the prompt.

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

local shop, prompt, bounds, anchor
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant.Name == "HalloweenEggShop" then shop = descendant end
	if descendant.Name == "HalloweenDropOffZoneBounds" then bounds = descendant end
	if descendant.Name == "HalloweenHomeAnchor" then anchor = descendant end
end
for _, descendant in ipairs((shop or workspace):GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then prompt = descendant end
end

print("shop=" .. tostring(shop and shop:GetFullName()))
print("prompt=" .. tostring(prompt and prompt.Name) .. " parent=" .. tostring(prompt and prompt.Parent:GetFullName()))
print("bounds=" .. tostring(bounds and bounds.ClassName))
print("anchor=" .. tostring(anchor and anchor.ClassName))

if bounds then
	for attribute, value in pairs(bounds:GetAttributes()) do
		print("  bounds." .. attribute .. " = " .. tostring(value))
	end
end

local buy = findRemote("BuyHalloweenEgg")
local saved = player:FindFirstChild("SavedData")
local holder = saved and saved:FindFirstChild("HalloweenCandy")
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

local target = anchor or (shop and shop:FindFirstChildWhichIsA("BasePart"))
if not (buy and target and rootPart) then
	print("STOP: tidak ada remote / titik acuan")
	return
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

-- Stand at the shop, then try without opening anything.
rootPart.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
task.wait(1)
attempt("dariPosisi")

-- Open the shop prompt, then try again.
if prompt then
	pcall(function()
		prompt.HoldDuration = 0
		prompt:InputHoldBegin()
		prompt:InputHoldEnd()
	end)
	task.wait(2)
	attempt("setelahPrompt")
end