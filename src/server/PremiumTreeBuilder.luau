--!strict
-- Эксклюзивные деревья: крупнее обычных, светятся, вокруг вращается орбита
-- (папка Orbit, её крутит клиент), снизу — неоновое кольцо на грядке, вверх бьёт луч.
-- У каждого из пяти своя форма и гамма.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garden = require(ReplicatedStorage.Shared.Garden)
local Voxel = require(script.Parent.Voxel)

local PremiumTreeBuilder = {}

local V = 0.8

type Look = { color: Color3, material: Enum.Material?, alpha: number? }

local function round(n: number): number
	return math.floor(n + 0.5)
end

local function set(g: Voxel.Grid, x: number, y: number, z: number, l: Look)
	Voxel.set(g, round(x), round(y), round(z), l.color, l.material, l.alpha)
end

local function line(
	g: Voxel.Grid,
	a: Vector3,
	b: Vector3,
	w: number,
	look: (number, number, number) -> Look
)
	local steps = math.max(1, math.ceil((b - a).Magnitude * 2))
	local lo = -math.floor((w - 1) / 2)
	for i = 0, steps do
		local p = a:Lerp(b, i / steps)
		for dx = lo, lo + w - 1 do
			for dz = lo, lo + w - 1 do
				local x, y, z = round(p.X) + dx, round(p.Y), round(p.Z) + dz
				set(g, x, y, z, look(x, y, z))
			end
		end
	end
end

local function blob(
	g: Voxel.Grid,
	c: Vector3,
	r: number,
	ry: number,
	seed: number,
	look: (number, number, number, number) -> Look,
	shellOnly: boolean?
)
	for x = -math.ceil(r + 1), math.ceil(r + 1) do
		for y = -math.ceil(ry + 1), math.ceil(ry + 1) do
			for z = -math.ceil(r + 1), math.ceil(r + 1) do
				local d = (x / r) ^ 2 + (y / ry) ^ 2 + (z / r) ^ 2
				local n = math.noise((c.X + x) * 0.35 + seed, (c.Y + y) * 0.35, (c.Z + z) * 0.35)
					* 0.4
				if d <= 1 + n and not (shellOnly and d < 0.7) then
					set(g, c.X + x, c.Y + y, c.Z + z, look(c.X + x, c.Y + y, c.Z + z, d))
				end
			end
		end
	end
end

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function emitter(parent: Instance, c1: Color3, c2: Color3, props: { [string]: any })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(c1, c2)
	pe.LightEmission = 1
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(1.5, 3)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.35, 0)
	pe.Shape = Enum.ParticleEmitterShape.Box
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = parent
end

-- Луч света вверх между двумя точками.
local function beam(model: Model, from: CFrame, height: number, c1: Color3, c2: Color3)
	local a = part(model, Vector3.new(0.2, 0.2, 0.2), from, c1, Enum.Material.Neon)
	a.Transparency = 1
	local b = part(
		model,
		Vector3.new(0.2, 0.2, 0.2),
		from * CFrame.new(0, height, 0),
		c2,
		Enum.Material.Neon
	)
	b.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Parent = a
	local a1 = Instance.new("Attachment")
	a1.Parent = b
	local bm = Instance.new("Beam")
	bm.Attachment0 = a0
	bm.Attachment1 = a1
	bm.Color = ColorSequence.new(c1, c2)
	bm.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	bm.Width0 = 2.4
	bm.Width1 = 0.6
	bm.LightEmission = 1
	bm.FaceCamera = true
	bm.Parent = a
end

function PremiumTreeBuilder.build(
	treeId: string,
	level: number,
	ready: boolean,
	base: CFrame
): Model
	local tree = Garden.tree(treeId) :: any
	local palette = Garden.aura(treeId).palette
	local stage = Garden.stage(level)
	local f = 1 + 0.08 * (stage - 1)
	local g = Voxel.new(V)
	local shape = tree.shape
	local seed = #treeId * 3.7

	local model = Instance.new("Model")
	model.Name = "Tree"
	local root = part(model, Vector3.new(1, 1, 1), base, Color3.new(), Enum.Material.SmoothPlastic)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	local crownCenter = Vector3.new(0, 12 * f, 0) -- в вокселях
	local orbitRadius = 5
	local orbitItems: { { size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType? } } =
		{}

	if shape == "p_aurora" then
		-- кристальный ствол и кристаллы-шипы вверх
		local function crystal(x: number, y: number, z: number): Look
			local t = (y % 6) / 6
			return {
				color = palette[1]:Lerp(palette[2], t),
				material = if (x + y + z) % 5 == 0 then Enum.Material.Neon else Enum.Material.Glass,
				alpha = 0.15,
			}
		end
		line(g, Vector3.zero, Vector3.new(0, 11 * f, 0), 2, crystal)
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2 + seed
			local tilt = if k == 0 then 0 else 0.55
			local len = (if k == 0 then 10 else 7) * f
			local dir = Vector3.new(math.cos(a) * tilt, 1, math.sin(a) * tilt).Unit
			local from = Vector3.new(0, 10 * f, 0)
			line(g, from, from + dir * len, if k == 0 then 2 else 1, crystal)
			set(
				g,
				(from + dir * (len + 1)).X,
				(from + dir * (len + 1)).Y,
				(from + dir * (len + 1)).Z,
				{
					color = palette[3],
					material = Enum.Material.Neon,
				}
			)
		end
		crownCenter = Vector3.new(0, 14 * f, 0)
		for i = 1, 10 do
			table.insert(orbitItems, {
				size = Vector3.new(0.5, 1.2, 0.5),
				color = palette[(i % 3) + 1],
				material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Glass,
			})
		end
	elseif shape == "p_chrono" then
		local brass = Color3.fromRGB(196, 150, 70)
		local copper = Color3.fromRGB(170, 100, 60)
		line(g, Vector3.zero, Vector3.new(0, 9 * f, 0), 2, function(_x, y, _z)
			return { color = if y % 3 == 0 then copper else brass, material = Enum.Material.Metal }
		end)
		-- циферблат: кольцо лицом вперёд
		local cy = 14 * f
		local R = 5.5 * f
		for a = 0, 63 do
			local ang = a / 64 * math.pi * 2
			set(
				g,
				math.cos(ang) * R,
				cy + math.sin(ang) * R,
				0,
				{ color = brass, material = Enum.Material.Metal }
			)
			set(g, math.cos(ang) * (R - 1), cy + math.sin(ang) * (R - 1), 0, {
				color = if a % 8 == 0 then palette[3] else copper,
				material = if a % 8 == 0 then Enum.Material.Neon else Enum.Material.Metal,
			})
		end
		line(g, Vector3.new(0, cy, -1), Vector3.new(0, cy + R * 0.7, -1), 1, function()
			return { color = palette[3], material = Enum.Material.Neon }
		end)
		line(g, Vector3.new(0, cy, -1), Vector3.new(R * 0.5, cy, -1), 1, function()
			return { color = palette[3], material = Enum.Material.Neon }
		end)
		-- золотая листва за циферблатом
		blob(g, Vector3.new(0, cy, 2.5), R * 0.9, R * 0.8, seed, function(x, y, z)
			return {
				color = Voxel.shade(tree.leaf, x, y, z, seed, 0.15),
				material = Enum.Material.SmoothPlastic,
			}
		end)
		crownCenter = Vector3.new(0, cy, 0)
		orbitRadius = 6
		for i = 1, 12 do
			table.insert(orbitItems, {
				size = Vector3.new(0.7, 0.7, 0.3),
				color = if i % 2 == 0 then brass else copper,
				material = Enum.Material.Metal,
			})
		end
	elseif shape == "p_hoard" then
		local red = tree.trunk
		line(g, Vector3.zero, Vector3.new(0, 8 * f, 0), 3, function(x, y, z)
			return {
				color = if (x + y * 2 + z) % 4 == 0
					then red:Lerp(Color3.new(0, 0, 0), 0.3)
					else red,
				material = Enum.Material.SmoothPlastic,
			}
		end)
		local cy = 12 * f
		blob(g, Vector3.new(0, cy, 0), 6 * f, 4.2 * f, seed, function(x, y, z, d)
			return {
				color = Voxel.shade(tree.leaf, x, y, z, seed, 0.12),
				material = if d < 0.8 and (x + y + z) % 3 == 0
					then Enum.Material.Neon
					else Enum.Material.Foil,
			}
		end)
		-- груда монет у корня
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local r = 3 + (k % 3)
			set(
				g,
				math.cos(a) * r,
				0,
				math.sin(a) * r,
				{ color = palette[1], material = Enum.Material.Neon }
			)
		end
		crownCenter = Vector3.new(0, cy, 0)
		for _ = 1, 10 do
			table.insert(orbitItems, {
				size = Vector3.new(0.25, 1.1, 1.1),
				color = Color3.fromRGB(255, 205, 70),
				material = Enum.Material.Neon,
				shape = Enum.PartType.Cylinder,
			})
		end
	elseif shape == "p_nebula" then
		line(g, Vector3.zero, Vector3.new(0, 10 * f, 0), 2, function(x, y, z)
			local star = (x * 7 + y * 13 + z * 5) % 9 == 0
			return {
				color = if star then Color3.new(1, 1, 1) else tree.trunk,
				material = if star then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			}
		end)
		local cy = 14 * f
		-- туманность: плотное ядро и полупрозрачная оболочка
		blob(g, Vector3.new(0, cy, 0), 4.5 * f, 3.8 * f, seed, function(_x, y, _z, d)
			local t = math.clamp((y - cy + 4) / 8, 0, 1)
			return {
				color = palette[1]:Lerp(palette[3], t),
				material = if d < 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			}
		end)
		blob(g, Vector3.new(0, cy, 0), 6.2 * f, 5 * f, seed + 1, function()
			return { color = palette[2], material = Enum.Material.Glass, alpha = 0.55 }
		end, true)
		crownCenter = Vector3.new(0, cy, 0)
		orbitRadius = 7
		for i = 1, 4 do
			table.insert(orbitItems, {
				size = Vector3.new(1, 1, 1) * (0.8 + i * 0.25),
				color = palette[(i % 3) + 1],
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
			})
		end
	else -- p_kitsune
		line(g, Vector3.zero, Vector3.new(0, 7 * f, 0), 2, function()
			return { color = tree.trunk, material = Enum.Material.SmoothPlastic }
		end)
		local cy = 11 * f
		local function petals(x: number, y: number, z: number, _d: number): Look
			local white = (x * 13 + y * 7 + z * 11) % 7 == 0
			return {
				color = if white
					then Color3.new(1, 1, 1)
					else Voxel.shade(tree.leaf, x, y, z, seed, 0.1),
				material = Enum.Material.SmoothPlastic,
			}
		end
		blob(g, Vector3.new(0, cy, 0), 5.5 * f, 3.4 * f, seed, petals)
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + 0.6
			line(
				g,
				Vector3.new(0, 6 * f, 0),
				Vector3.new(math.cos(a) * 4 * f, cy - 1, math.sin(a) * 4 * f),
				1,
				function()
					return { color = tree.trunk, material = Enum.Material.SmoothPlastic }
				end
			)
			blob(
				g,
				Vector3.new(math.cos(a) * 4.5 * f, cy - 1, math.sin(a) * 4.5 * f),
				3 * f,
				2.2 * f,
				seed + k,
				petals
			)
		end
		crownCenter = Vector3.new(0, cy, 0)
		orbitRadius = 6.5
		for _ = 1, 9 do
			table.insert(orbitItems, {
				size = Vector3.new(0.9, 0.9, 0.9),
				color = palette[2],
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
			})
		end
	end

	-- Плоды на созревшем дереве: яркие неоновые воксели вокруг кроны
	if ready and tree.fruit then
		local rng = Random.new(#treeId + stage)
		for i = 1, 10 + stage * 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(3, 5.5) * f
			local fruitColor = if shape == "p_hoard" then palette[(i % 3) + 1] else tree.fruit
			set(g, math.cos(a) * r, crownCenter.Y - rng:NextNumber(0, 3), math.sin(a) * r, {
				color = fruitColor,
				material = Enum.Material.Neon,
			})
		end
	end

	Voxel.build(g, model, base * CFrame.new(0, V / 2, 0))

	-- Неоновое кольцо на грядке
	local glowRing = part(
		model,
		Vector3.new(0.2, 10.4, 10.4),
		base * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		palette[1],
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	glowRing.Transparency = 0.55
	local ringCut = part(
		model,
		Vector3.new(0.25, 9.2, 9.2),
		base * CFrame.new(0, 0.13, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 50, 40),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	ringCut.Transparency = 0

	-- Центр кроны: свет, частицы, луч, орбита
	local centerCF = base * CFrame.new(crownCenter * V)
	local fx = part(model, Vector3.new(5, 5, 5), centerCF, palette[1], Enum.Material.SmoothPlastic)
	fx.Name = "Fx"
	fx.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = palette[1]
	light.Range = 22
	light.Brightness = 2.2
	light.Parent = fx
	local style = Garden.aura(treeId).particles
	emitter(fx, palette[1], palette[2], {
		Rate = 14,
		Acceleration = if style == "petals" then Vector3.new(0, -1.5, 0) else Vector3.new(0, 1, 0),
		Size = NumberSequence.new(0.45, 0),
	})
	emitter(
		fx,
		palette[3],
		palette[1],
		{ Rate = 5, Size = NumberSequence.new(0.9, 0), Lifetime = NumberRange.new(0.6, 1) }
	)
	beam(model, base * CFrame.new(0, 0.3, 0), 30 + stage * 3, palette[1], palette[2])

	local orbit = Instance.new("Model")
	orbit.Name = "Orbit"
	orbit:SetAttribute("Speed", if shape == "p_chrono" then 0.6 else 0.9)
	orbit:SetAttribute("Center", centerCF.Position)
	for i, item in orbitItems do
		local a = i / #orbitItems * math.pi * 2
		local y = if shape == "p_chrono" then 0 else math.sin(i * 1.7) * 1.2
		local p = part(
			orbit,
			item.size,
			CFrame.new(
				centerCF.Position
					+ Vector3.new(math.cos(a) * orbitRadius, y, math.sin(a) * orbitRadius)
			),
			item.color,
			item.material,
			item.shape
		)
		if item.material == Enum.Material.Glass then
			p.Transparency = 0.2
		end
	end
	orbit.Parent = model
	return model
end

return PremiumTreeBuilder
