--!strict
-- Помощники UI в сдержанном стиле: тёмное стекло, тонкие обводки, плоские кнопки,
-- шрифт Gotham. Крупные зоны нажатия остаются (mobile-first).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.colors = {
	bg = Color3.fromRGB(16, 18, 24),
	panel = Color3.fromRGB(28, 31, 40),
	panelLight = Color3.fromRGB(40, 44, 56),
	line = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(236, 238, 244),
	muted = Color3.fromRGB(150, 156, 172),
	green = Color3.fromRGB(84, 182, 112),
	greenDark = Color3.fromRGB(56, 128, 80),
	blue = Color3.fromRGB(86, 136, 220),
	blueDark = Color3.fromRGB(58, 94, 160),
	red = Color3.fromRGB(206, 84, 84),
	redDark = Color3.fromRGB(150, 56, 56),
	gold = Color3.fromRGB(228, 184, 84),
	goldDark = Color3.fromRGB(170, 130, 50),
	purple = Color3.fromRGB(150, 112, 220),
	purpleDark = Color3.fromRGB(100, 72, 160),
	disabled = Color3.fromRGB(58, 62, 74),
}

UI.font = Enum.Font.GothamBold
UI.fontRegular = Enum.Font.GothamMedium

function UI.corner(parent: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

function UI.stroke(
	parent: GuiObject,
	color: Color3,
	thickness: number?,
	transparency: number?
): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Тонкая светлая рамка «стекла».
function UI.glass(parent: GuiObject)
	UI.stroke(parent, UI.colors.line, 1, 0.88)
end

-- Совместимость: в новом стиле обводки текста нет.
function UI.textStroke(_label: TextLabel | TextButton, _thickness: number?) end

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
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 30
	limit.Parent = l
	l.Parent = parent
	return l
end

-- Плоская кнопка с лёгким нажатием.
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
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.22, 0)
	pad.PaddingBottom = UDim.new(0.22, 0)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.96 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
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
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }
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

-- Модальная панель: заголовок, тонкая акцентная полоса, крестик, область содержимого.
function UI.panel(
	parent: Instance,
	_icon: string,
	title: string,
	accent: Color3,
	onClose: () -> ()
): Panel
	local root = UI.frame(parent, {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.new(0.92, 0, 0.76, 0),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.06,
		Visible = false,
		ZIndex = 5,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 660)
	limit.Parent = root
	UI.corner(root, 12)
	UI.glass(root)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	UI.label(root, string.upper(title), {
		Size = UDim2.new(1, -90, 0, 26),
		Position = UDim2.fromOffset(18, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	})
	UI.frame(root, {
		Size = UDim2.fromOffset(36, 3),
		Position = UDim2.fromOffset(18, 48),
		BackgroundColor3 = accent,
		ZIndex = 6,
	})
	local close = UI.button(root, "X", UI.colors.panelLight, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(44, 40),
		ZIndex = 7,
	})
	close.Activated:Connect(onClose)

	local content = UI.frame(root, {
		Name = "Content",
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -74),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})

	return {
		root = root,
		content = content,
		setVisible = function(v: boolean)
			if v and not root.Visible then
				scale.Scale = 0.96
				root.Visible = true
				TweenService
					:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 })
					:Play()
			elseif not v then
				root.Visible = false
			end
		end,
		visible = function()
			return root.Visible
		end,
	}
end

function UI.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Size = UDim2.fromScale(1, 1)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 4
	s.ScrollBarImageColor3 = UI.colors.muted
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	for k, v in props or {} do
		(s :: any)[k] = v
	end
	s.Parent = parent
	return s
end

-- Полоса прогресса: возвращает функцию установки доли 0..1 и цвета.
function UI.bar(parent: Instance, props: { [string]: any }?): (number, Color3?) -> ()
	local bg = UI.frame(parent, { BackgroundColor3 = UI.colors.panelLight })
	for k, v in props or {} do
		(bg :: any)[k] = v
	end
	UI.corner(bg, 4)
	local fill = UI.frame(bg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.colors.green })
	UI.corner(fill, 4)
	return function(frac: number, color: Color3?)
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		if color then
			fill.BackgroundColor3 = color
		end
	end
end

-- Круглая «монета» для счётчика.
function UI.coinIcon(parent: Instance, size: number, props: { [string]: any }?): Frame
	local c =
		UI.frame(parent, { Size = UDim2.fromOffset(size, size), BackgroundColor3 = UI.colors.gold })
	for k, v in props or {} do
		(c :: any)[k] = v
	end
	UI.corner(c, size)
	UI.stroke(c, UI.colors.goldDark, 2)
	return c
end

-- Градиент из палитры (2–3 цвета).
function UI.paletteGradient(
	parent: GuiObject | UIStroke,
	palette: { Color3 },
	rotation: number?
): UIGradient
	local g = Instance.new("UIGradient")
	local keys = {}
	for i, c in palette do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #palette - 1), c))
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

-- Переливание градиента: смещение бегает по кругу. Все градиенты обновляются одним циклом.
local shimmering: { [UIGradient]: number } = setmetatable({}, { __mode = "k" }) :: any
local shimmerClock = 0
RunService.RenderStepped:Connect(function(dt)
	shimmerClock += dt
	for g, speed in shimmering do
		if g.Parent then
			g.Offset = Vector2.new(math.sin(shimmerClock * speed) * 0.5, 0)
		end
	end
end)
function UI.shimmer(g: UIGradient, speed: number?)
	shimmering[g] = speed or 1.5
end

-- Масштаб HUD под маленькие экраны (телефон в горизонтали ~390 точек по высоте).
-- Кластер сжимается вокруг своей AnchorPoint, поэтому остаётся прижатым к краю.
local scaled: { UIScale } = {}
local function screenScale(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(vp.Y / 620, vp.X / 1100), 0.72, 1)
end
local function rescaleAll()
	local k = screenScale()
	for _, s in scaled do
		s.Scale = k
	end
end
task.spawn(function()
	while not workspace.CurrentCamera do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	end
	local cam = workspace.CurrentCamera :: Camera
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleAll)
	rescaleAll()
end)
function UI.autoScale(obj: GuiObject)
	local found = obj:FindFirstChild("AutoScale")
	local s: UIScale
	if found and found:IsA("UIScale") then
		s = found
	else
		s = Instance.new("UIScale")
		s.Name = "AutoScale"
		s.Parent = obj
	end
	table.insert(scaled, s)
	s.Scale = screenScale()
end

-- Цвет в hex для rich text.
function UI.hex(c: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(c.R * 255),
		math.floor(c.G * 255),
		math.floor(c.B * 255)
	)
end

function UI.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function UI.formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e5 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- «1 / 2.5M»
-- Короткая запись больших чисел: 250K, 2.5M, 100M.
function UI.short(n: number): string
	local function trim(x: number, suffix: string): string
		local str = string.format("%.1f", x):gsub("%.0$", "")
		return str .. suffix
	end
	if n >= 1e9 then
		return trim(n / 1e9, "B")
	elseif n >= 1e6 then
		return trim(n / 1e6, "M")
	elseif n >= 1e4 then
		return trim(n / 1e3, "K")
	end
	return UI.formatNumber(n)
end

-- «1 in 250K»
function UI.oneIn(n: number): string
	-- до двух значащих цифр: 5 001 -> 5 000, 251 -> 250
	if n >= 100 then
		local p = 10 ^ (math.floor(math.log10(n)) - 1)
		n = math.floor(n / p + 0.5) * p
	end
	return "1 in " .. UI.short(math.floor(n + 0.5))
end

function UI.percent(p: number): string
	if p >= 10 then
		return string.format("%.1f%%", p)
	elseif p >= 0.01 then
		return (string.format("%.2f", p):gsub("0+$", ""):gsub("%.$", "")) .. "%"
	end
	return string.format("%.1e%%", p)
end

return UI
