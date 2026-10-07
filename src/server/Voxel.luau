--!strict
-- Воксельная сетка: заполняем ячейки цветом, затем превращаем в детали.
-- Внутренние воксели (закрытые со всех 6 сторон) выкидываются, соседние воксели
-- одного цвета в ряду по X склеиваются в одну деталь — так модели остаются лёгкими.

export type Grid = {
	size: number,
	cells: { [number]: { color: Color3, material: Enum.Material?, alpha: number? } },
}

local Voxel = {}

-- Ключ ячейки: координаты в диапазоне [-512, 511].
local function key(x: number, y: number, z: number): number
	return (x + 512) * 1048576 + (y + 512) * 1024 + (z + 512)
end

local function unkey(k: number): (number, number, number)
	local z = k % 1024 - 512
	local y = (k // 1024) % 1024 - 512
	local x = k // 1048576 - 512
	return x, y, z
end

function Voxel.new(size: number): Grid
	return { size = size, cells = {} }
end

function Voxel.set(
	g: Grid,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material?,
	alpha: number?
)
	g.cells[key(x, y, z)] = { color = color, material = material, alpha = alpha }
end

function Voxel.has(g: Grid, x: number, y: number, z: number): boolean
	return g.cells[key(x, y, z)] ~= nil
end

function Voxel.clear(g: Grid, x: number, y: number, z: number)
	g.cells[key(x, y, z)] = nil
end

-- Оттенок цвета: шум квантуется до 3 ступеней, чтобы соседние воксели чаще совпадали.
function Voxel.shade(
	base: Color3,
	x: number,
	y: number,
	z: number,
	seed: number,
	amount: number?
): Color3
	local n = math.noise(x * 0.23 + seed, y * 0.23, z * 0.23 - seed)
	local step = math.clamp(math.floor((n + 0.5) * 3), 0, 2) - 1 -- -1, 0, 1
	local a = (amount or 0.12) * step
	if a > 0 then
		return base:Lerp(Color3.new(1, 1, 1), a)
	end
	return base:Lerp(Color3.new(0, 0, 0), -a)
end

local function sameLook(a: any, b: any): boolean
	return a.color == b.color and a.material == b.material and a.alpha == b.alpha
end

-- Строит детали в parent. origin — позиция центра ячейки (0,0,0).
function Voxel.build(
	g: Grid,
	parent: Instance,
	origin: CFrame,
	opts: { castShadow: boolean?, collide: boolean? }?
): number
	local s = g.size
	local cells = g.cells
	-- видимые ячейки
	local visible: { [number]: boolean } = {}
	for k in cells do
		local x, y, z = unkey(k)
		if
			not (
				cells[key(x + 1, y, z)]
				and cells[key(x - 1, y, z)]
				and cells[key(x, y + 1, z)]
				and cells[key(x, y - 1, z)]
				and cells[key(x, y, z + 1)]
				and cells[key(x, y, z - 1)]
			)
		then
			visible[k] = true
		end
	end
	local done: { [number]: boolean } = {}
	local count = 0
	local castShadow = if opts and opts.castShadow ~= nil then opts.castShadow else true
	local collide = if opts and opts.collide ~= nil then opts.collide else false
	for k in visible do
		if done[k] then
			continue
		end
		local x, y, z = unkey(k)
		local look = cells[k]
		-- найти начало ряда
		local x0 = x
		while
			visible[key(x0 - 1, y, z)]
			and not done[key(x0 - 1, y, z)]
			and sameLook(cells[key(x0 - 1, y, z)], look)
		do
			x0 -= 1
		end
		local x1 = x
		while
			visible[key(x1 + 1, y, z)]
			and not done[key(x1 + 1, y, z)]
			and sameLook(cells[key(x1 + 1, y, z)], look)
		do
			x1 += 1
		end
		for xi = x0, x1 do
			done[key(xi, y, z)] = true
		end
		local len = x1 - x0 + 1
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = collide
		p.CanQuery = collide
		p.CanTouch = false
		p.CastShadow = castShadow
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = look.material or Enum.Material.SmoothPlastic
		p.Color = look.color
		p.Transparency = look.alpha or 0
		p.Size = Vector3.new(len * s, s, s)
		p.CFrame = origin * CFrame.new((x0 + x1) / 2 * s, y * s, z * s)
		p.Parent = parent
		count += 1
	end
	return count
end

return Voxel
