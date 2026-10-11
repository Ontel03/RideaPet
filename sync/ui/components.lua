--[[
	UI Components - Reusable builders for panels, buttons, labels, etc.
	Used by the UI panel builder to create consistent UI elements.
]]

local Theme = ...

-- Helper: Create an Instance with properties
local function create(className, properties, parent)
	local inst = Instance.new(className)
	for k, v in pairs(properties) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

-- Helper: Round corners
local function round(p, r) return create("UICorner", { CornerRadius = UDim.new(0, r) }, p) end
local function stroke(p, c, t) return create("UIStroke", { Color = c, Thickness = t or 1 }, p) end

-- Helper: Make a Button with hover effects
local function mkBtn(props, parent)
	local b = create("TextButton", {
		Size = props.Size,
		BackgroundColor3 = props.BackgroundColor3 or Theme.surface,
		BorderSizePixel = 0,
		Text = props.Text,
		TextColor3 = props.TextColor3 or Theme.text,
		TextSize = props.TextSize or 14,
		Font = props.Font or Enum.Font.GothamMedium,
		Selectable = props.Selectable ~= false,
		Active = props.Active ~= false,
		LayoutOrder = props.LayoutOrder,
	}, parent)
	round(b, 8)
	if props.BackgroundColor3 then
		b.MouseEnter:Connect(function()
			if not b.Active then return end
			-- TweenService would be set by loader
		end)
		b.MouseLeave:Connect(function()
			-- TweenService would be set by loader
		end)
	end
	return b
end

-- Helper: Make a Label
local function mkLabel(props, parent)
	return create("TextLabel", {
		Size = props.Size,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		Text = props.Text,
		TextColor3 = props.TextColor3 or Theme.text,
		TextSize = props.TextSize or 14,
		Font = props.Font or Enum.Font.Gotham,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.TextWrapped or false,
		LayoutOrder = props.LayoutOrder,
	}, parent)
end

-- Helper: Make a Row (empty frame with layout)
local function mkRow(ord, parent)
	return create("Frame", { Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1, LayoutOrder = ord }, parent)
end

-- Helper: Make a Dot (colored circle)
local function mkDot(parent, color)
	local d = create("Frame", { Size = UDim2.fromOffset(9,9), Position = UDim2.fromOffset(1,6), BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
	round(d, 5); return d
end

-- Helper: Make a Divider
local function mkDiv(ord, parent)
	return create("Frame", { Size = UDim2.new(1,0,0,1), BackgroundColor3 = Theme.divider, BorderSizePixel = 0, LayoutOrder = ord }, parent)
end

-- Helper: Make a Stat Block (frame with text)
local function mkStatBlock(ord, parent)
	local f = create("Frame", { Size = UDim2.new(1,0,0,40), BackgroundColor3 = Theme.surface, BorderSizePixel = 0, LayoutOrder = ord }, parent)
	round(f, 8)
	return create("TextLabel", { Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "Collected 0  ·  Laps 0", TextColor3 = Theme.text, TextSize = 14, Font = Enum.Font.GothamMedium }, f)
end

return {
	create = create,
	round = round,
	stroke = stroke,
	mkBtn = mkBtn,
	mkLabel = mkLabel,
	mkRow = mkRow,
	mkDot = mkDot,
	mkDiv = mkDiv,
	mkStatBlock = mkStatBlock,
}