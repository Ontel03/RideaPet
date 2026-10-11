--[[
	Core Utilities - Helper functions used across modules.
	Pure functions with no external dependencies.
]]

-- Services reference (will be set by loader)
local Services = {}

-- Utility: Get world position of an object
function Services.getWorldPosition(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object.Position end
	if object:IsA("Model") then
		local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
		return part and part.Position or nil
	end
	if object:IsA("Folder") then
		for _, child in ipairs(object:GetDescendants()) do
			if child:IsA("BasePart") then return child.Position end
		end
	end
	return nil
end

-- Utility: Teleport a part to a position
function Services.teleportTo(position, rootPart)
	if not position or not rootPart then return false end
	return pcall(function() rootPart.CFrame = CFrame.new(position) end)
end

-- Utility: Hold pickup key for a duration
function Services.holdPickupKey(keyHold)
	local VIM = Services.VirtualInputManager
	local key = Services.PICKUP_KEY
	pcall(function() VIM:SendKeyEvent(true, key, false, Services.game) end)
	task.wait(keyHold)
	pcall(function() VIM:SendKeyEvent(false, key, false, Services.game) end)
end

-- Utility: Matches any word in text
function Services.matchesAny(text, words)
	local lower = string.lower(text)
	for _, w in ipairs(words) do
		if string.find(lower, w, 1, true) then return true end
	end
	return false
end

-- Utility: Get all Remotes from containers
function Services.getAllRemotes()
	local containers = { Services.ReplicatedStorage, Services.ReplicatedFirst, Services.Players.LocalPlayer:WaitForChild("PlayerScripts") }
	local remotes = {}
	for _, c in ipairs(containers) do
		for _, r in ipairs(c:GetDescendants()) do
			if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
				table.insert(remotes, r)
			end
		end
	end
	return remotes
end

-- Utility: Get candidate remotes based on keywords
function Services.getCandidateRemotes()
	local candidates = {}
	for _, remote in ipairs(Services.getAllRemotes()) do
		local path = remote:GetFullName()
		if Services.matchesAny(path, Services.DISCOVER_KEYWORDS) and not Services.matchesAny(path, Services.DENY_KEYWORDS) then
			table.insert(candidates, remote)
		end
	end
	table.sort(candidates, function(a, b)
		local af, bf = a:IsA("RemoteFunction"), b:IsA("RemoteFunction")
		if af ~= bf then return af end
		return a:GetFullName() < b:GetFullName()
	end)
	return candidates
end

-- Utility: Build args for remote firing based on shape
function Services.buildArgs(shape, candy, pad)
	if shape == "none" then return {}
	elseif shape == "candy" then return { candy }
	elseif shape == "pad+candy" then return { pad, candy }
	elseif shape == "candy+player" then return { candy, Services.Players.LocalPlayer }
	elseif shape == "candy+pad+player" then return { candy, pad, Services.Players.LocalPlayer }
	end
	return { candy, pad, Services.Players.LocalPlayer }
end

-- Utility: Fire a remote with given args
function Services.fireRemote(remote, shape, candy, pad)
	local args = Services.buildArgs(shape, candy, pad)
	local n = #args
	if remote:IsA("RemoteFunction") then remote:InvokeServer(table.unpack(args, 1, n))
	else remote:FireServer(table.unpack(args, 1, n)) end
end

return Services