-- The candy total in the UI likely comes from a player stat, not GetCandyState.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("== ATTRIBUTES ==")
local count = 0
for attribute, value in pairs(player:GetAttributes()) do
	print("  " .. attribute .. " = " .. tostring(value))
	count = count + 1
end
if count == 0 then print("  (tidak ada)") end

print("== LEADERSTATS ==")
local stats = player:FindFirstChild("leaderstats")
if not stats then
	print("  (tidak ada leaderstats)")
else
	for _, child in ipairs(stats:GetChildren()) do
		if child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue") then
			print("  " .. child.Name .. " = " .. tostring(child.Value))
		end
	end
end

print("== CANDY-ISH VALUES ==")
local found = 0
for _, descendant in ipairs(player:GetDescendants()) do
	if (descendant:IsA("IntValue") or descendant:IsA("NumberValue")) and descendant.Name:lower():find("cand") then
		print("  " .. descendant:GetFullName() .. " = " .. tostring(descendant.Value))
		found = found + 1
	end
end
if found == 0 then print("  (tidak ada nilai candy di player)") end