-- Probe: identifies the pickup mechanism, then writes the result to a file so it can
-- be read without copying console output by hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local lines = {}
local function add(text)
	lines[#lines + 1] = text
end

add("GAME: " .. game.PlaceId .. " / " .. game.Name)

add("")
add("== WORKSPACE ==")
for _, child in ipairs(workspace:GetChildren()) do
	add(child.Name .. "  [" .. child.ClassName .. "]")
end

local folder = workspace:FindFirstChild("HalloweenCandy")
add("")
add("== CANDY ==")
if not folder then
	add("HalloweenCandy: NOT FOUND")
else
	add("count: " .. #folder:GetChildren())
	local candy = folder:GetChildren()[1]
	if candy then
		add("first: " .. candy.Name .. " [" .. candy.ClassName .. "]")
		for _, descendant in ipairs(candy:GetDescendants()) do
			add("  child: " .. descendant.Name .. " [" .. descendant.ClassName .. "]")
		end
		for _, attribute in pairs(candy:GetAttributes()) do
			add("  attr: " .. attribute .. " = " .. tostring(candy:GetAttribute(attribute)))
		end
	end
end

local drop = workspace:FindFirstChild("CandyDropOff")
add("")
add("== DROPOFF ==")
if not drop then
	add("CandyDropOff: NOT FOUND")
else
	for _, descendant in ipairs(drop:GetDescendants()) do
		add(descendant.Name .. " [" .. descendant.ClassName .. "]")
	end
end

add("")
add("== REMOTES ==")
for _, container in ipairs({ ReplicatedStorage, game:GetService("ReplicatedFirst") }) do
	for _, remote in ipairs(container:GetDescendants()) do
		if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
			add(remote:GetFullName() .. "  [" .. remote.ClassName .. "]")
		end
	end
end

add("")
add("== BACKPACK ==")
local player = Players.LocalPlayer
for _, tool in ipairs(player.Backpack:GetChildren()) do
	add("backpack: " .. tool.Name)
end

local output = table.concat(lines, "\n")

local OUT_PATH = "E:/PUNYAROZI/Software/RobloxScript/candy_inspect.txt"
if type(writefile) == "function" then
	writefile(OUT_PATH, output)
	print("[inspect] ditulis ke " .. OUT_PATH)
else
	print("[inspect] writefile tidak tersedia, print manual:")
	print(output)
end