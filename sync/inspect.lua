-- The purchase is likely refused because the egg basket is full. Prints only the
-- egg-related saved fields and any basket container in the player tree.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local saved = player:FindFirstChild("SavedData")
if saved then
	for _, child in ipairs(saved:GetChildren()) do
		local lowered = string.lower(child.Name)
		if string.find(lowered, "egg", 1, true) or string.find(lowered, "basket", 1, true) then
			local kind = child.ClassName
			local value = ""
			if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then
				value = " = " .. tostring(child.Value)
			end
			print("SavedData." .. child.Name .. " [" .. kind .. "]" .. value)
			if child:IsA("StringValue") then
				print("   raw: " .. tostring(child.Value))
			end
			if child:IsA("Table") or child:IsA("Folder") then
				print("   children: " .. tostring(#child:GetChildren()))
			end
		end
	end
end

print("== keranjang di tree player ==")
for _, descendant in ipairs(player:GetDescendants()) do
	if string.find(string.lower(descendant.Name), "basket", 1, true)
		or string.find(string.lower(descendant.Name), "egg", 1, true) then
		print(descendant:GetFullName() .. " [" .. descendant.ClassName .. "]")
	end
end