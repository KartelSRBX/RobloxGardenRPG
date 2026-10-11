--!strict
-- Плоские иконки из примитивов интерфейса (без загрузки картинок).
-- Рисуются в сетке 24×24 внутри контейнера и масштабируются вместе с ним.
-- Каждая функция: (контейнер, основной цвет, дополнительный цвет?) -> Frame иконки.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Icons = {}

type Draw = {
	root: Frame,
	rect: (
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		props: { [string]: any }?
	) -> Frame,
	circle: (cx: number, cy: number, r: number, color: Color3, props: { [string]: any }?) -> Frame,
	ring: (cx: number, cy: number, r: number, thickness: number, color: Color3) -> Frame,
}

local U = 1 / 24

local function canvas(parent: Instance): Draw
	local root = Instance.new("Frame")
	root.Name = "Icon"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = root

	local function rect(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		props: { [string]: any }?
	): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale((x + w / 2) * U, (y + h / 2) * U)
		f.Size = UDim2.fromScale(w * U, h * U)
		local radius = props and props.radius
		if radius then
			local c = Instance.new("UICorner")
			c.CornerRadius = if radius >= 1 then UDim.new(1, 0) else UDim.new(radius, 0)
			c.Parent = f
		end
		for k, v in props or {} do
			if k ~= "radius" then
				(f :: any)[k] = v
			end
		end
		f.Parent = root
		return f
	end

	local function circle(
		cx: number,
		cy: number,
		r: number,
		color: Color3,
		props: { [string]: any }?
	): Frame
		local p = props or {}
		p.radius = 1
		return rect(cx - r, cy - r, r * 2, r * 2, color, p)
	end

	local function ring(cx: number, cy: number, r: number, thickness: number, color: Color3): Frame
		local f = circle(cx, cy, r, color, { BackgroundTransparency = 1 })
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness
		s.Parent = f
		return f
	end

	return { root = root, rect = rect, circle = circle, ring = ring }
end

-- Дерево на островке
function Icons.island(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	local a = accent or color
	d.rect(3, 19, 18, 3, a, { radius = 1, BackgroundTransparency = 0.2 })
	d.rect(11, 12, 2, 8, color)
	d.circle(12, 9, 5.5, color)
	d.circle(7.5, 12, 3.5, color)
	d.circle(16.5, 12, 3.5, color)
	return d.root
end

-- Четырёхлистный клевер: удача
function Icons.clover(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	d.circle(9, 8, 3.6, color)
	d.circle(15, 8, 3.6, color)
	d.circle(9, 14, 3.6, color)
	d.circle(15, 14, 3.6, color)
	d.circle(12, 11, 1.4, accent or color)
	d.rect(11.2, 14, 1.6, 8, color, { Rotation = 18 })
	return d.root
end

-- Меч
function Icons.sword(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	local group = d.rect(0, 0, 24, 24, color, { BackgroundTransparency = 1, Rotation = 45 })
	local function part(x: number, y: number, w: number, h: number, c: Color3, radius: number?)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = c
		f.Position = UDim2.fromScale(x * U, y * U)
		f.Size = UDim2.fromScale(w * U, h * U)
		if radius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(radius, 0)
			corner.Parent = f
		end
		f.Parent = group
	end
	part(10.8, 1.5, 2.4, 14, color, 0.5)
	part(7, 15, 10, 2, accent or color, 0.5)
	part(11, 17, 2, 4, accent or color)
	part(10.5, 21, 3, 2.5, color, 1)
	return d.root
end

-- Человек
function Icons.person(parent: Instance, color: Color3): Frame
	local d = canvas(parent)
	d.circle(12, 8, 4.2, color)
	d.rect(5, 14, 14, 8, color, { radius = 0.45 })
	return d.root
end

-- Шестерёнка
function Icons.gear(parent: Instance, color: Color3, hole: Color3?): Frame
	local d = canvas(parent)
	for i = 0, 3 do
		d.rect(10.5, 2.5, 3, 19, color, { Rotation = i * 45, radius = 0.25 })
	end
	d.circle(12, 12, 6.5, color)
	d.circle(12, 12, 2.6, hole or Color3.fromRGB(20, 22, 30))
	return d.root
end

-- Дом
function Icons.home(parent: Instance, color: Color3, door: Color3?): Frame
	local d = canvas(parent)
	d.rect(6, 4.5, 12, 12, color, { Rotation = 45, radius = 0.12 })
	d.rect(5.5, 11, 13, 10.5, color, { radius = 0.1 })
	d.rect(10.5, 15, 3, 6.5, door or Color3.fromRGB(20, 22, 30), { radius = 0.3 })
	return d.root
end

-- Портал: кольцо и ядро
function Icons.portal(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	d.ring(12, 12, 8, 2.5, color)
	d.circle(12, 12, 4, accent or color, { BackgroundTransparency = 0.25 })
	d.circle(12, 12, 1.6, color)
	return d.root
end

-- Росток для медальона крутки
function Icons.sprout(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	local a = accent or color
	d.rect(11, 10, 2, 11, color, { radius = 0.5 })
	d.rect(3.5, 6.5, 9, 5, a, { Rotation = 30, radius = 1 })
	d.rect(11.5, 3.5, 9, 5, color, { Rotation = -35, radius = 1 })
	d.rect(7, 20, 10, 2, color, { radius = 1, BackgroundTransparency = 0.3 })
	return d.root
end

-- Монета
function Icons.coin(parent: Instance, color: Color3, inner: Color3?): Frame
	local d = canvas(parent)
	d.circle(12, 12, 10, color)
	d.ring(12, 12, 6.5, 2, inner or Color3.new(1, 1, 1))
	return d.root
end

-- Глаз (скрыть интерфейс)
function Icons.eye(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	d.rect(2, 7.5, 20, 9, color, { radius = 1 })
	d.circle(12, 12, 4.2, Color3.fromRGB(24, 26, 36))
	d.circle(12, 12, 2.2, accent or color)
	return d.root
end

-- Кристалл (магазин)
function Icons.gem(parent: Instance, color: Color3, accent: Color3?): Frame
	local d = canvas(parent)
	d.rect(6, 5, 12, 12, color, { Rotation = 45, radius = 0.12 })
	d.rect(4, 7.5, 16, 4, accent or color, { radius = 0.2 })
	return d.root
end

-- Повтор (авто-крутка): кольцо с разрывом и стрелкой
function Icons.repeat_(parent: Instance, color: Color3): Frame
	local d = canvas(parent)
	d.ring(12, 12, 7.5, 2.5, color)
	-- наконечник стрелки
	d.rect(15.5, 3, 5, 5, color, { Rotation = 45, radius = 0.15 })
	return d.root
end

-- Иконка по ключу: загруженная картинка, если её ID указан в Config.IconAssets,
-- иначе нарисованная из примитивов.
local fallback: { [string]: (Instance, Color3, Color3?) -> Frame } = {
	island = Icons.island,
	odds = Icons.clover,
	dungeon = Icons.sword,
	profile = Icons.person,
	menu = Icons.gear,
	home = Icons.home,
	hub = Icons.portal,
	shop = Icons.gem,
	eye = Icons.eye,
	coin = Icons.coin,
	sprout = Icons.sprout,
	auto = Icons.repeat_,
}

function Icons.make(key: string, parent: Instance, color: Color3, accent: Color3?): GuiObject
	local id = (Config.IconAssets :: any)[key]
	if type(id) == "string" and id ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = parent
		return img
	end
	local draw = fallback[key] or Icons.sprout
	return draw(parent, color, accent)
end

-- Есть ли у ключа загруженная картинка (тогда её цвет не перекрашиваем).
function Icons.hasImage(key: string): boolean
	local id = (Config.IconAssets :: any)[key]
	return type(id) == "string" and id ~= ""
end

return Icons
