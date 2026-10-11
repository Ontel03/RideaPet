--[[
	Pickup Module - Remote discovery and sending pickup calls.
	Finds the correct remote for collecting candy and sends the collection request.
]]

-- Reference to config, utils, and other services (set by loader)
local Config = ...
local Utils = ...
local Candy = ...

-- Internal state for pickup
local pickupState = { remote = nil, shape = nil, candidates = 0, scanned = 0 }

-- Discover the correct pickup remote by probing candidates
function Services.discoverRemote()
	local candidates = Utils.getCandidateRemotes()
	pickupState.candidates = #candidates
	if #candidates == 0 then
		print("[CandyFarm] No candidate remotes")
		pickupState.scanned = 0
		return nil, nil
	end
	local folder = Candy.getCandyFolder()
	if not folder then
		print("[CandyFarm] Candy folder not found during discovery")
		pickupState.scanned = #candidates
		return nil, nil
	end
	print(("[CandyFarm] Probing %d candidate remotes..."):format(#candidates))
	for _, remote in ipairs(candidates) do
		for _, shape in ipairs(Config.PROBE_SHAPES) do
			local children = folder:GetChildren()
			if #children == 0 then
				pickupState.scanned = #candidates
				return nil, nil
			end
			local target = children[1]
			local pad = Candy.getDropOffPad() or target
			local ok = pcall(Utils.fireRemote, remote, shape, target, pad)
			task.wait(Config.probeDelay)
			if not target.Parent then
				-- Candy disappeared = pickup succeeded
				pickupState.remote, pickupState.shape = remote, shape
				pickupState.scanned = 1
				print(("[CandyFarm] Found pickup remote: %s (%s)"):format(remote:GetFullName(), shape))
				return remote, shape
			elseif not ok then
				break -- Remote errored, try next shape
			end
		end
	end
	pickupState.scanned = #candidates
	print("[CandyFarm] No working remote found, falling back to teleport + key")
	return nil, nil
end

-- Send a pickup call for a specific candy
function Services.sendPickup(candy, pad)
	if not pickupState.remote or not pickupState.shape then return false end
	return pcall(Utils.fireRemote, pickupState.remote, pickupState.shape, candy, pad)
end

-- Get the current pickup state
function Services.getState()
	return pickupState
end

-- Refresh the mode button UI text based on current remote status
function Services.refreshModeUI(btn, Theme)
	if not pickupState.remote then
		btn.Text, btn.TextColor3, btn.Active = "Pickup: teleport + key", Theme.muted, false
	elseif Config.useRemotePickup then
		btn.Text, btn.TextColor3, btn.Active = "Pickup: " .. pickupState.remote.Name, Theme.text, true
	else
		btn.Text, btn.TextColor3, btn.Active = "Pickup: teleport + key", Theme.text, true
	end
end

return Services