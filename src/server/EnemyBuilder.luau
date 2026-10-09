--!strict
-- Воксельные враги подземелья: слизень, скелет, король слизней.
-- Тело собирается из вокселей 0.5 stud и приваривается к невидимому корню,
-- чтобы Humanoid мог двигать модель целиком.
local Voxel = require(script.Parent.Voxel)

local EnemyBuilder = {}

local V = 0.5

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function blob(
	g: Voxel.Grid,
	rx: number,
	ry: number,
	base: Color3,
	light: Color3,
	seed: number
)
	for x = -rx, rx do
		for y = 0, ry * 2 do
			for z = -rx, rx do
				local dy = (y - ry * 0.9) / ry
				-- приплюснутый купол: шире снизу
				local widen = 1 + math.max(0, -dy) * 0.25
				local d = (x / (rx * widen)) ^ 2 + dy ^ 2 + (z / (rx * widen)) ^ 2
				if d <= 1 and y >= 0 then
					local c = Voxel.shade(base, x, y, z, seed, 0.1)
					if y > ry * 1.3 and x < 0 and z < 0 then
						c = light -- блик
					end
					Voxel.set(g, x, y, z, c, Enum.Material.SmoothPlastic)
				end
			end
		end
	end
end

local function box(
	g: Voxel.Grid,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	c: Color3,
	m: Enum.Material?
)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do
				Voxel.set(g, x, y, z, c, m)
			end
		end
	end
end

-- Возвращает модель, корень (HumanoidRootPart) и размер корня.
function EnemyBuilder.build(kind: string, at: CFrame): (Model, BasePart, Vector3)
	local g = Voxel.new(V)
	local size: Vector3
	if kind == "boss" then
		size = Vector3.new(9, 8, 9)
		blob(g, 9, 8, Color3.fromRGB(120, 60, 190), Color3.fromRGB(210, 170, 255), 3)
		-- корона
		local gold = Color3.fromRGB(255, 196, 70)
		for a = 0, 11 do
			local ang = a / 12 * math.pi * 2
			local x, z = math.floor(math.cos(ang) * 5 + 0.5), math.floor(math.sin(ang) * 5 + 0.5)
			local h = if a % 2 == 0 then 3 else 1
			box(g, x, 15, z, x, 15 + h, z, gold, Enum.Material.SmoothPlastic)
		end
		box(g, -1, 17, -6, 0, 18, -5, Color3.fromRGB(255, 60, 90), Enum.Material.Neon)
		-- глаза и рот
		box(g, -5, 8, -10, -3, 10, -9, Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		box(g, 3, 8, -10, 5, 10, -9, Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		box(g, -3, 4, -10, 3, 5, -9, Color3.fromRGB(40, 10, 60))
	elseif kind == "skeleton" then
		size = Vector3.new(3, 6, 2)
		local bone = Color3.fromRGB(226, 220, 200)
		local dark = Color3.fromRGB(150, 144, 130)
		-- ноги
		box(g, -2, 0, -1, -1, 4, 0, bone)
		box(g, 1, 0, -1, 2, 4, 0, bone)
		-- таз и рёбра
		box(g, -2, 5, -1, 2, 5, 0, dark)
		box(g, 0, 6, -1, 0, 9, 0, bone)
		for y = 6, 9 do
			if y % 2 == 0 then
				box(g, -2, y, -1, 2, y, 0, bone)
			end
		end
		box(g, -2, 10, -1, 2, 10, 0, bone)
		-- руки
		box(g, -3, 6, -1, -3, 10, -1, bone)
		box(g, 3, 6, -1, 3, 10, -1, bone)
		box(g, -3, 6, -2, -3, 6, -2, dark)
		box(g, 3, 6, -2, 3, 6, -2, dark)
		-- череп
		box(g, -2, 11, -2, 2, 14, 1, bone)
		box(g, -1, 12, -3, -1, 12, -3, Color3.fromRGB(255, 70, 50), Enum.Material.Neon)
		box(g, 1, 12, -3, 1, 12, -3, Color3.fromRGB(255, 70, 50), Enum.Material.Neon)
		box(g, -1, 11, -3, 1, 11, -3, dark)
	else
		size = Vector3.new(4, 3.2, 4)
		blob(g, 4, 3, Color3.fromRGB(80, 200, 120), Color3.fromRGB(190, 255, 210), 7)
		box(g, -2, 3, -5, -1, 4, -5, Color3.fromRGB(20, 30, 30))
		box(g, 1, 3, -5, 2, 4, -5, Color3.fromRGB(20, 30, 30))
	end

	local model = Instance.new("Model")
	model.Name = kind
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = size
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = at + Vector3.new(0, size.Y / 2 + 0.1, 0)
	root.Parent = model
	model.PrimaryPart = root

	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = model
	-- нижний слой вокселей у подошвы корня
	Voxel.build(g, body, root.CFrame * CFrame.new(0, -size.Y / 2 + V / 2, 0), { castShadow = true })
	for _, p in body:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			weld(root, p)
		end
	end
	return model, root, size
end

return EnemyBuilder
