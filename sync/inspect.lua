-- Source probe: finds the game's own code that calls CollectCandy and prints the
-- surrounding lines, so the real call signature is visible.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local NEEDLES = { "CollectCandy", "DropCandy" }
local CONTEXT = 350

local roots = {}
if player:FindFirstChild("PlayerScripts") then
	table.insert(roots, player.PlayerScripts)
end
table.insert(roots, game:GetService("ReplicatedStorage"))

local hits = 0
for _, root in ipairs(roots) do
	for _, script in ipairs(root:GetDescendants()) do
		if script:IsA("LocalScript") or script:IsA("ModuleScript") then
			local ok, source = pcall(function()
				return script.Source
			end)
			if ok and type(source) == "string" and #source > 0 then
				for _, needle in ipairs(NEEDS) do
					local at = source:find(needle, 1, true)
					if at and hits < 3 then
						hits = hits + 1
						local from = math.max(1, at - CONTEXT)
						print(("--- %s @ %s ---"):format(needle, script:GetFullName()))
						print(source:sub(from, at + CONTEXT):gsub("\n", " | "))
						print("")
					end
				end
			end
		end
	end
end

print("hits: " .. hits)