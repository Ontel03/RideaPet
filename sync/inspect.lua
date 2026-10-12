-- Finds the real collectible candy objects. The HalloweenCandy folder children are all
-- named Candy_01, which does not match the Candy1_9 style ids the server reports.

local seen = {}
local count = 0

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.Name:find("Candy") then
		count = count + 1
		local top = descendant
		while top.Parent and top.Parent ~= workspace do
			top = top.Parent
		end
		local key = descendant.Name
		if not seen[key] then
			seen[key] = true
			if count <= 15 then
				print(descendant:GetFullName() .. " [" .. descendant.ClassName .. "] in " .. top.Name)
				local attributes = descendant:GetAttributes()
				for attribute, value in pairs(attributes) do
					print("    " .. attribute .. " = " .. tostring(value))
				end
			end
		end
	end
end

print("total candy parts: " .. count)

local folders = {}
for _, child in ipairs(workspace:GetChildren()) do
	for _, descendant in ipairs(child:GetDescendants()) do
		if descendant:IsA("Folder") or descendant:IsA("Model") then
			local name = descendant.Name
			if name:find("Candy") then
				folders[name] = (folders[name] or 0) + 1
			end
		end
	end
end
for name, amount in pairs(folders) do
	print("folder " .. name .. " x" .. amount)
end