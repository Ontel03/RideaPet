-- Fixed: only RemoteEvents get OnClientEvent. Also reads GetCandyState's return value,
-- which may reveal what CollectCandy expects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function describe(value, depth)
	depth = depth or 0
	local kind = type(value)
	if kind == "Instance" then
		return "<" .. value.ClassName .. ":" .. value:GetFullName() .. ">"
	elseif kind == "table" and depth < 2 then
		local parts = {}
		local count = 0
		for key, item in pairs(value) do
			count = count + 1
			if count > 12 then break end
			parts[#parts + 1] = tostring(key) .. "=" .. describe(item, depth + 1)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function eachCandyRemote(callback)
	for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
		for _, remote in ipairs(container:GetDescendants()) do
			if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and remote.Name:find("Candy") then
				callback(remote)
			end
		end
	end
end

local replyCount = 0
eachCandyRemote(function(remote)
	if remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(...)
			local parts = {}
			for index = 1, select("#", ...) do
				parts[index] = describe(select(index, ...))
			end
			replyCount = replyCount + 1
			print("[reply] " .. remote.Name .. " " .. table.concat(parts, ", "))
		end)
	else
		print("[func] " .. remote.Name)
	end
end)

local function findRemote(name)
	local found
	eachCandyRemote(function(remote)
		if remote.Name == name then found = remote end
	end)
	return found
end

local collect = findRemote("CollectCandy")
local getState = findRemote("GetCandyState")
local folder = workspace:FindFirstChild("HalloweenCandy")

if getState then
	for _, args in ipairs({ { }, { folder } }) do
		local ok, result = pcall(function()
			return getState:InvokeServer(table.unpack(args, 1, #args))
		end)
		print("GetCandyState(" .. #args .. ") ok=" .. tostring(ok) .. " -> " .. describe(result))
	end
end

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
collect:FireServer(target)
task.wait(2)
print("after parent=" .. tostring(target.Parent and target.Parent:GetFullName()) .. " count=" .. tostring(#folder:GetChildren()))
print("replies=" .. replyCount)