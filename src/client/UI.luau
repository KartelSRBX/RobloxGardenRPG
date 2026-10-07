--!strict
-- Мелкие помощники для UI: крупные кнопки и подписи под палец на телефоне.
local UI = {}

UI.colors = {
	bg = Color3.fromRGB(30, 34, 44),
	panel = Color3.fromRGB(45, 52, 66),
	text = Color3.fromRGB(245, 245, 250),
	muted = Color3.fromRGB(150, 158, 175),
	green = Color3.fromRGB(70, 190, 90),
	blue = Color3.fromRGB(60, 130, 230),
	red = Color3.fromRGB(210, 70, 70),
	gold = Color3.fromRGB(255, 200, 50),
	disabled = Color3.fromRGB(80, 86, 100),
}

function UI.corner(parent: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function UI.stroke(parent: GuiObject, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function UI.frame(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UI.colors.panel
	f.BorderSizePixel = 0
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function UI.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = UI.colors.text
	l.TextScaled = true
	l.Text = text
	l.Size = UDim2.fromScale(1, 1)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function UI.button(
	parent: Instance,
	text: string,
	color: Color3,
	props: { [string]: any }?
): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = UI.colors.text
	b.TextScaled = true
	b.Text = text
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	UI.corner(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.15, 0)
	pad.PaddingBottom = UDim.new(0.15, 0)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	b.Parent = parent
	return b
end

function UI.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function UI.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return UI
