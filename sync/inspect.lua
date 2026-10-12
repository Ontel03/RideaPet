-- Arg-shape probe: tries every plausible way to call CollectCandy and reports which
-- one actually makes a candy leave the folder.

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

local function fire(remote, ...)
	local count = select("#", ...)
	local args = { ... }
	pcall(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer(table.unpack(args, 1, count))
		else
			remote:FireServer(table.unpack(args, 1, count))
		end
	end)
end

local collect = findRemote("CollectCandy")
local folder = workspace:FindFirstChild("HalloweenCandy")
print("REMOTE=" .. (collect and collect.ClassName or "NOT FOUND") .. " candies=" .. tostring(folder and #folder:GetChildren()))

local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local pad = workspace:FindFirstChild("CandyDropOff")

local function standOn(target, offset)
	local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
	if part and rootPart then
		rootPart.CFrame = CFrame.new(part.Position + offset)
	end
end

-- name -> builder(candy) returning a function that fires with those args
local shapes = {
	{ "noargs", function(c) return function() fire(collect) end end },
	{ "candy", function(c) return function() fire(collect, c) end end },
	{ "candyName", function(c) return function() fire(collect, c.Name) end end },
	{ "pad+candy", function(c) return function() fire(collect, pad or c, c) end end },
	{ "candy+pad", function(c) return function() fire(collect, c, pad or c) end end },
	{ "candy+player", function(c) return function() fire(collect, c, player) end end },
	{ "candyName+player", function(c) return function() fire(collect, c.Name, player) end end },
	{ "touch-only", function(c) return function() end end },
}

for _, shape in ipairs(shapes) do
	local candies = folder and folder:GetChildren()
	if not candies or #candies == 0 then
		print(shape[1] .. " = NO CANDY LEFT")
		break
	end

	local target = candies[1]
	local fireIt = shape[2](target)

	-- Stand right on the candy so any distance or touch check passes.
	standOn(target, Vector3.new(0, 1, 0))
	task.wait(1)

	fireIt()
	task.wait(1)

	print(string.format("%s = %s", shape[1], target.Parent and "fail" or "OK"))
end

print("candies left: " .. tostring(folder and #folder:GetChildren()))