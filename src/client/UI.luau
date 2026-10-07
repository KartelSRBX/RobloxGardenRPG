--!strict
-- Помощники UI: тема, крупные кнопки под палец, панели с анимацией появления.
local TweenService = game:GetService("TweenService")

local UI = {}

UI.colors = {
	bg = Color3.fromRGB(28, 32, 46),
	panel = Color3.fromRGB(44, 50, 70),
	panelLight = Color3.fromRGB(62, 70, 96),
	text = Color3.fromRGB(250, 250, 255),
	muted = Color3.fromRGB(170, 178, 200),
	green = Color3.fromRGB(76, 200, 96),
	greenDark = Color3.fromRGB(46, 140, 64),
	blue = Color3.fromRGB(66, 140, 240),
	blueDark = Color3.fromRGB(40, 96, 180),
	red = Color3.fromRGB(226, 76, 76),
	redDark = Color3.fromRGB(160, 44, 44),
	gold = Color3.fromRGB(255, 205, 60),
	goldDark = Color3.fromRGB(200, 140, 20),
	purple = Color3.fromRGB(150, 90, 240),
	purpleDark = Color3.fromRGB(96, 50, 170),
	disabled = Color3.fromRGB(96, 102, 120),
}

UI.font = Enum.Font.FredokaOne

function UI.corner(parent: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = parent
end

function UI.stroke(parent: GuiObject, color: Color3, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UI.textStroke(label: TextLabel | TextButton, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(20, 20, 30)
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
end

function UI.gradient(parent: GuiObject, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

function UI.pad(parent: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

function UI.list(parent: GuiObject, padding: number, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
	return l
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
	l.Font = UI.font
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

-- Кнопка «с объёмом»: светлый верх, тёмный низ, обводка текста, лёгкое нажатие.
function UI.button(
	parent: Instance,
	text: string,
	color: Color3,
	props: { [string]: any }?
): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = UI.font
	b.TextColor3 = UI.colors.text
	b.TextScaled = true
	b.Text = text
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	UI.corner(b)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	g.Rotation = 90
	g.Parent = b
	UI.textStroke(b, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	b.Parent = parent
	return b
end

-- Пульсация, чтобы подсказать, куда нажать.
function UI.pulse(obj: GuiObject): () -> ()
	local scale = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = obj
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.1 }
	)
	tween:Play()
	return function()
		tween:Cancel()
		scale.Scale = 1
	end
end

export type Panel = {
	root: Frame,
	content: Frame,
	setVisible: (boolean) -> (),
	visible: () -> boolean,
}

-- Модальная панель: заголовок с иконкой, крестик, область содержимого.
function UI.panel(
	parent: Instance,
	icon: string,
	title: string,
	accent: Color3,
	onClose: () -> ()
): Panel
	local root = UI.frame(parent, {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.new(0.92, 0, 0.74, 0),
		BackgroundColor3 = UI.colors.bg,
		Visible = false,
		ZIndex = 5,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, 640)
	limit.Parent = root
	UI.corner(root, 20)
	UI.stroke(root, accent, 4)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local header = UI.frame(root, {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = accent,
		ZIndex = 5,
	})
	UI.corner(header, 20)
	UI.gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	-- нижние углы шапки прямые
	UI.frame(header, {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = accent,
		ZIndex = 5,
	})
	local titleLabel = UI.label(header, `{icon}  {title}`, {
		Size = UDim2.new(1, -90, 0, 40),
		Position = UDim2.fromOffset(16, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	})
	UI.textStroke(titleLabel, 2)
	local close = UI.button(header, "X", UI.colors.red, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 42),
		ZIndex = 7,
	})
	close.Activated:Connect(onClose)

	local content = UI.frame(root, {
		Name = "Content",
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})

	local panel: Panel = {
		root = root,
		content = content,
		setVisible = function(v: boolean)
			if v and not root.Visible then
				scale.Scale = 0.85
				root.Visible = true
				TweenService
					:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
					:Play()
			elseif not v then
				root.Visible = false
			end
		end,
		visible = function()
			return root.Visible
		end,
	}
	return panel
end

function UI.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Size = UDim2.fromScale(1, 1)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	for k, v in props or {} do
		(s :: any)[k] = v
	end
	s.Parent = parent
	return s
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

function UI.percent(p: number): string
	return (string.format("%.1f", p):gsub("%.0$", "")) .. "%"
end

return UI
