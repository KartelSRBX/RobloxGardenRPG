--!strict
-- Типовые компоненты HUD по ТЗ: IconButton (с бейджем и состояниями), Counter, ProgressBar,
-- Badge, Toggle, PurchaseButton, Slot, TextBanner. Нажатие: масштаб 0.95 и звук клика.
-- Текст поверх 3D получает тонкую чёрную обводку, на плашках обводки нет.
local TweenService = game:GetService("TweenService")

local Icons = require(script.Parent.Icons)
local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local Components = {}

local RED = Color3.fromRGB(226, 70, 70)
local BLUE = Color3.fromRGB(70, 130, 235)
local GREEN = Color3.fromRGB(70, 190, 100)

-- Обводка текста для подписей над миром.
function Components.outline(label: TextLabel | TextButton, strength: number?)
	label.TextStrokeColor3 = Color3.fromRGB(8, 10, 16)
	label.TextStrokeTransparency = 1 - (strength or 0.65)
end

-- Нажатие: масштаб и звук.
local function pressable(b: TextButton, silent: boolean?)
	local scale = Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.95 }):Play()
		if not silent then
			Sfx.click()
		end
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
end
Components.pressable = pressable

---------------------------------------------------------------- Badge
export type BadgeKind = "red" | "blue" | "percent" | "new"

-- Угловой маркер. Возвращает функцию set(text, kind): nil или "" скрывает.
function Components.badge(parent: GuiObject): (string?, BadgeKind?) -> ()
	local b = UI.frame(parent, {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = RED,
		Visible = false,
		ZIndex = (parent.ZIndex or 1) + 5,
	})
	UI.corner(b, 11)
	UI.stroke(b, Color3.fromRGB(14, 16, 24), 2)
	local label = UI.label(b, "", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		ZIndex = b.ZIndex + 1,
	})
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = 13
	end
	return function(text: string?, kind: BadgeKind?)
		if not text or text == "" then
			b.Visible = false
			return
		end
		b.Visible = true
		label.Text = text
		local k = kind or "red"
		b.BackgroundColor3 = if k == "blue" then BLUE elseif k == "percent" then GREEN else RED
		b.Size = UDim2.fromOffset(if #text > 2 then 36 else 22, 22)
	end
end

---------------------------------------------------------------- IconButton
export type IconButton = {
	button: TextButton,
	setBadge: (string?, BadgeKind?) -> (),
	setLocked: (boolean) -> (),
	setActive: (boolean) -> (),
}

function Components.iconButton(
	parent: Instance,
	opts: {
		name: string,
		label: string,
		icon: string,
		accent: Color3,
		size: number,
		order: number?,
	}
): IconButton
	local size = opts.size
	local b = Instance.new("TextButton")
	b.Name = opts.name .. "Button"
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = UI.colors.bg
	b.BackgroundTransparency = 0.12
	b.LayoutOrder = opts.order or 0
	b.Parent = parent
	UI.corner(b, 12)
	UI.glass(b)
	local holder = UI.frame(b, {
		Name = "IconHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, size * 0.12),
		Size = UDim2.fromOffset(size * 0.5, size * 0.5),
		BackgroundTransparency = 1,
	})
	Icons.make(opts.icon, holder, opts.accent, opts.accent:Lerp(Color3.new(1, 1, 1), 0.35))
	local text = UI.label(b, opts.label, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -size * 0.08),
		Size = UDim2.new(1, -6, 0, size * 0.18),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.text,
	})
	Components.outline(text, 0.4)
	local bar = UI.frame(b, {
		Name = "Accent",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.4, 0, 0, 2),
		BackgroundColor3 = opts.accent,
		BackgroundTransparency = 0.4,
	})
	UI.corner(bar, 1)
	local lock = UI.label(b, "LOCKED", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.8, 0, 0, 14),
		Visible = false,
		ZIndex = 4,
	})
	Components.outline(lock)
	pressable(b)
	local badge = Components.badge(b)

	return {
		button = b,
		setBadge = badge,
		setLocked = function(locked: boolean)
			holder.Visible = not locked
			lock.Visible = locked
			b.BackgroundTransparency = if locked then 0.4 else 0.12
		end,
		setActive = function(active: boolean)
			b.BackgroundColor3 = if active then UI.colors.panelLight else UI.colors.bg
			bar.Size = if active then UDim2.new(0.8, 0, 0, 3) else UDim2.new(0.4, 0, 0, 2)
			bar.BackgroundTransparency = if active then 0 else 0.4
		end,
	}
end

---------------------------------------------------------------- Counter
export type Counter = {
	frame: Frame,
	set: (string) -> (),
	alert: (boolean) -> (),
	bump: () -> (),
}

-- Иконка + значение; тёмная плашка. alert(true) подсвечивает красным (переполнение).
function Components.counter(
	parent: Instance,
	opts: { icon: string, color: Color3, order: number?, width: number? }
): Counter
	local frame = UI.frame(parent, {
		Size = UDim2.fromOffset(opts.width or 132, 34),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.25,
		LayoutOrder = opts.order or 0,
	})
	UI.corner(frame, 17)
	local stroke = UI.stroke(frame, UI.colors.line, 1, 0.88)
	local iconHolder = UI.frame(frame, {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(8, 6),
		BackgroundTransparency = 1,
	})
	Icons.make(opts.icon, iconHolder, opts.color, opts.color:Lerp(Color3.new(1, 1, 1), 0.3))
	local value = UI.label(frame, "0", {
		Size = UDim2.new(1, -42, 0, 20),
		Position = UDim2.fromOffset(36, 7),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Components.outline(value, 0.6)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local alerting = false
	local counter: Counter = {
		frame = frame,
		set = function(text: string)
			value.Text = text
		end,
		alert = function(on: boolean)
			if on == alerting then
				return
			end
			alerting = on
			stroke.Color = if on then RED else UI.colors.line
			stroke.Transparency = if on then 0 else 0.88
			value.TextColor3 = if on then Color3.fromRGB(255, 150, 150) else UI.colors.text
			if on then
				task.spawn(function()
					while alerting and frame.Parent do
						TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0.7 })
							:Play()
						task.wait(0.4)
						TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0 }):Play()
						task.wait(0.4)
					end
				end)
			end
		end,
		bump = function()
			scale.Scale = 1.08
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
		end,
	}
	return counter
end

---------------------------------------------------------------- ProgressBar
export type Progress = {
	frame: Frame,
	set: (number, string?, Color3?) -> (),
	setLabel: (string) -> (),
}

-- Горизонтальная полоса: слева подпись (уровень), справа текст (cur/max).
function Components.progress(
	parent: Instance,
	opts: {
		height: number?,
		color: Color3,
		left: string?,
		size: UDim2?,
		position: UDim2?,
	}
): Progress
	local h = opts.height or 18
	local frame = UI.frame(parent, {
		Size = opts.size or UDim2.new(1, 0, 0, h),
		Position = opts.position or UDim2.new(),
		BackgroundColor3 = Color3.fromRGB(10, 12, 18),
		BackgroundTransparency = 0.2,
	})
	UI.corner(frame, h // 2)
	UI.stroke(frame, UI.colors.line, 1, 0.85)
	local fill = UI.frame(frame, {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	UI.corner(fill, h // 2)
	local gradient =
		UI.paletteGradient(fill, { opts.color:Lerp(Color3.new(1, 1, 1), 0.25), opts.color }, 90)
	local left = UI.label(frame, opts.left or "", {
		Size = UDim2.new(0.5, -10, 1, -4),
		Position = UDim2.fromOffset(8, 2),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Components.outline(left, 0.7)
	local right = UI.label(frame, "", {
		Size = UDim2.new(0.5, -10, 1, -4),
		Position = UDim2.new(0.5, 2, 0, 2),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	Components.outline(right, 0.7)
	return {
		frame = frame,
		set = function(frac: number, rightText: string?, color: Color3?)
			fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
			right.Text = rightText or ""
			if color then
				gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
			end
		end,
		setLabel = function(text: string)
			left.Text = text
		end,
	}
end

---------------------------------------------------------------- Toggle
export type Toggle = { button: TextButton, set: (boolean) -> () }

-- Кнопка ON/OFF: цвет и подпись меняются парой.
function Components.toggle(
	parent: Instance,
	opts: { label: string, size: UDim2, onColor: Color3?, order: number? }
): Toggle
	local b = UI.button(
		parent,
		"",
		UI.colors.disabled,
		{ Size = opts.size, LayoutOrder = opts.order or 0 }
	)
	local onColor = opts.onColor or GREEN
	local function set(on: boolean)
		b.Text = `{opts.label} {if on then "ON" else "OFF"}`
		b.BackgroundColor3 = if on then onColor else Color3.fromRGB(150, 70, 70)
	end
	set(false)
	return { button = b, set = set }
end

---------------------------------------------------------------- PurchaseButton
-- Плашка покупки: иконка товара, название, зелёная цена с иконкой R$.
-- rainbow = переливающаяся рамка (premium-предложения).
function Components.purchase(
	parent: Instance,
	opts: {
		icon: string,
		title: string,
		sub: string?,
		price: string,
		accent: Color3,
		rainbow: boolean?,
		width: number?,
		order: number?,
	}
): TextButton
	local w = opts.width or 196
	local b = Instance.new("TextButton")
	b.Name = "Offer"
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(w, 54)
	b.BackgroundColor3 = UI.colors.bg
	b.BackgroundTransparency = 0.18
	b.LayoutOrder = opts.order or 0
	b.Parent = parent
	UI.corner(b, 12)
	if opts.rainbow then
		local stroke = UI.stroke(b, Color3.new(1, 1, 1), 2)
		UI.shimmer(
			UI.paletteGradient(stroke, {
				Color3.fromRGB(255, 120, 120),
				Color3.fromRGB(255, 220, 110),
				Color3.fromRGB(120, 240, 160),
				Color3.fromRGB(110, 190, 255),
				Color3.fromRGB(200, 130, 255),
			}, 0),
			1.4
		)
	else
		UI.glass(b)
	end
	local iconHolder = UI.frame(b, {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
	})
	Icons.make(opts.icon, iconHolder, opts.accent, opts.accent:Lerp(Color3.new(1, 1, 1), 0.35))
	local title = UI.label(b, opts.title, {
		Size = UDim2.new(1, -112, 0, 16),
		Position = UDim2.fromOffset(52, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Components.outline(title, 0.5)
	if opts.sub then
		local sub = UI.label(b, opts.sub, {
			Size = UDim2.new(1, -112, 0, 12),
			Position = UDim2.fromOffset(52, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		Components.outline(sub, 0.4)
	end
	local price = UI.frame(b, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(58, 30),
		BackgroundColor3 = Color3.fromRGB(34, 120, 62),
	})
	UI.corner(price, 8)
	local priceLabel = UI.label(price, opts.price, {
		Size = UDim2.new(1, -6, 1, -8),
		Position = UDim2.fromOffset(3, 4),
		TextColor3 = Color3.fromRGB(190, 255, 200),
	})
	pressable(b)
	return b, function(text: string)
		priceLabel.Text = text
	end
end

---------------------------------------------------------------- Slot
export type Slot = { frame: Frame, set: (name: string?, accent: Color3?, tier: number?) -> () }

-- Квадратная ячейка предмета: иконка и подпись в две строки; пустая — приглушённая.
function Components.slot(
	parent: Instance,
	opts: { size: number, icon: string, order: number? }
): Slot
	local s = opts.size
	local frame = UI.frame(parent, {
		Size = UDim2.fromOffset(s, s),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.2,
		LayoutOrder = opts.order or 0,
	})
	UI.corner(frame, 12)
	local stroke = UI.stroke(frame, UI.colors.line, 1.5, 0.8)
	local holder = UI.frame(frame, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, s * 0.1),
		Size = UDim2.fromOffset(s * 0.5, s * 0.5),
		BackgroundTransparency = 1,
	})
	local iconRoot: GuiObject? = nil
	local label = UI.label(frame, "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0, s * 0.3),
		Font = UI.fontRegular,
		TextWrapped = true,
	})
	Components.outline(label, 0.5)
	return {
		frame = frame,
		set = function(name: string?, accent: Color3?, tier: number?)
			if iconRoot then
				iconRoot:Destroy()
				iconRoot = nil
			end
			if name then
				iconRoot = Icons.make(
					opts.icon,
					holder,
					Color3.fromRGB(236, 238, 244),
					accent or UI.colors.red
				)
				label.Text = name
				stroke.Color = accent or UI.colors.line
				stroke.Transparency = 0.1
				stroke.Thickness = 1.5 + (tier or 1) * 0.3
			else
				label.Text = ""
				stroke.Color = UI.colors.line
				stroke.Transparency = 0.8
			end
		end,
	}
end

---------------------------------------------------------------- TextBanner
-- Контурный текст без плашки: заголовки событий и подсказки. show(text, color?, seconds?).
function Components.banner(
	parent: Instance,
	position: UDim2,
	size: UDim2
): (string, Color3?, number?) -> ()
	local label = UI.label(parent, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Visible = false,
		ZIndex = 20,
	})
	Components.outline(label, 0.9)
	local scale = Instance.new("UIScale")
	scale.Parent = label
	local id = 0
	return function(text: string, color: Color3?, seconds: number?)
		id += 1
		local mine = id
		label.Text = text
		label.TextColor3 = color or UI.colors.text
		label.Visible = true
		scale.Scale = 1.3
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(seconds or 2, function()
			if id == mine then
				label.Visible = false
			end
		end)
	end
end

return Components
