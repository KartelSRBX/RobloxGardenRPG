--!strict
-- Воксельное дерево: мелкие кубы 0.8 stud, у каждой формы своя «анатомия».
-- Размер растёт со стадией прокачки и с редкостью. Плоды видны, когда урожай созрел.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garden = require(ReplicatedStorage.Shared.Garden)
local Voxel = require(script.Parent.Voxel)

local TreeBuilder = {}

local V = 0.8 -- размер вокселя, studs
local MAX_R = 7.5 -- радиус кроны в вокселях (грядки стоят через 13 studs)

local RAINBOW = {
	Color3.fromRGB(230, 70, 70),
	Color3.fromRGB(240, 150, 50),
	Color3.fromRGB(240, 220, 70),
	Color3.fromRGB(90, 200, 100),
	Color3.fromRGB(70, 150, 240),
	Color3.fromRGB(150, 90, 230),
}

type Look = { color: Color3, material: Enum.Material?, alpha: number? }
type Blob = { x: number, y: number, z: number, r: number, ry: number }

local function round(n: number): number
	return math.floor(n + 0.5)
end

-- Ствол или ветка: линия от a до b толщиной w вокселей.
local function line(
	g: Voxel.Grid,
	a: Vector3,
	b: Vector3,
	w: number,
	look: (number, number, number) -> Look
)
	local steps = math.max(1, math.ceil((b - a).Magnitude * 2))
	local lo = -math.floor((w - 1) / 2)
	local hi = lo + w - 1
	for i = 0, steps do
		local p = a:Lerp(b, i / steps)
		for dx = lo, hi do
			for dz = lo, hi do
				local x, y, z = round(p.X) + dx, round(p.Y), round(p.Z) + dz
				local l = look(x, y, z)
				Voxel.set(g, x, y, z, l.color, l.material, l.alpha)
			end
		end
	end
end

-- Крона-эллипсоид с неровным краем.
local function blob(
	g: Voxel.Grid,
	b: Blob,
	seed: number,
	look: (number, number, number, number) -> Look
)
	local r, ry = b.r, b.ry
	for x = -math.ceil(r + 1), math.ceil(r + 1) do
		for y = -math.ceil(ry + 1), math.ceil(ry + 1) do
			for z = -math.ceil(r + 1), math.ceil(r + 1) do
				local d = (x / r) ^ 2 + (y / ry) ^ 2 + (z / r) ^ 2
				local n = math.noise(
					(b.x + x) * 0.35 + seed,
					(b.y + y) * 0.35,
					(b.z + z) * 0.35 - seed
				) * 0.45
				if d <= 1 + n then
					local gx, gy, gz = round(b.x + x), round(b.y + y), round(b.z + z)
					local l = look(gx, gy, gz, d)
					Voxel.set(g, gx, gy, gz, l.color, l.material, l.alpha)
				end
			end
		end
	end
end

-- Точка на поверхности одной из крон (для плодов).
local function surfacePoint(blobs: { Blob }, rng: Random): Vector3
	local b = blobs[rng:NextInteger(1, #blobs)]
	local theta = rng:NextNumber(0, math.pi * 2)
	local phi = rng:NextNumber(math.rad(60), math.rad(160)) -- больше сбоку и снизу
	return Vector3.new(
		b.x + math.sin(phi) * math.cos(theta) * (b.r + 0.6),
		b.y + math.cos(phi) * (b.ry + 0.6),
		b.z + math.sin(phi) * math.sin(theta) * (b.r + 0.6)
	)
end

function TreeBuilder.build(
	treeId: string,
	level: number,
	ready: boolean,
	mutation: string?,
	base: CFrame
): Model
	local tree = Garden.tree(treeId) :: Garden.Tree
	local rarity = Garden.rarity(tree.rarity)
	local stage = Garden.stage(level)
	local f = (0.7 + 0.1 * stage) * (1 + 0.05 * (rarity.order - 1))
	local seed = #treeId * 7.13 + rarity.order
	local rng = Random.new(#treeId * 31 + stage)
	local g = Voxel.new(V)
	local blobs: { Blob } = {}

	local leafBase = tree.leaf
	if mutation == "golden" then
		leafBase = leafBase:Lerp(Color3.fromRGB(255, 205, 60), 0.35)
	end
	local glowLeaf = tree.glow == true
	local shape = tree.shape

	local function bark(x: number, y: number, z: number): Look
		local c = Voxel.shade(tree.trunk, x, y, z, seed, 0.1)
		if shape == "birch" or shape == "crystal" then
			-- тёмные отметины берёзы
			if (y * 7 + x * 3 + z * 5) % 9 == 0 then
				c = Color3.fromRGB(40, 40, 44)
			end
		elseif shape == "rainbow" then
			c = RAINBOW[(y + x + z) % #RAINBOW + 1]:Lerp(tree.trunk, 0.35)
		end
		if shape == "crystal" then
			return { color = c, material = Enum.Material.Glass, alpha = 0.15 }
		end
		return { color = c, material = Enum.Material.SmoothPlastic }
	end

	local function leaves(x: number, y: number, z: number, d: number): Look
		local c = Voxel.shade(leafBase, x, y, z, seed, 0.14)
		if shape == "flame" then
			-- от горячего центра к краю
			local hot = if treeId == "voidoak"
				then Color3.fromRGB(200, 120, 255)
				else Color3.fromRGB(255, 230, 120)
			c = hot:Lerp(leafBase, math.clamp(d, 0, 1))
			return {
				color = c,
				material = if d < 0.75 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			}
		elseif shape == "crystal" then
			return { color = c, material = Enum.Material.Glass, alpha = 0.25 }
		elseif shape == "blossom" and (x * 13 + y * 7 + z * 11) % 11 == 0 then
			c = Color3.fromRGB(255, 245, 250)
		end
		if glowLeaf and (x * 5 + y * 11 + z * 3) % 17 == 0 then
			return { color = c:Lerp(Color3.new(1, 1, 1), 0.3), material = Enum.Material.Neon }
		end
		return { color = c, material = Enum.Material.SmoothPlastic }
	end

	local function leafLine(x: number, y: number, z: number): Look
		return leaves(x, y, z, 0.6)
	end

	local function addBlob(x: number, y: number, z: number, r: number, ry: number)
		local b: Blob = { x = x, y = y, z = z, r = math.min(r, MAX_R), ry = ry }
		table.insert(blobs, b)
		blob(g, b, seed, leaves)
	end

	local tw = if f > 1.15 then 2 else 1
	if shape == "conical" then
		local h = round(14 * f)
		line(g, Vector3.zero, Vector3.new(0, h, 0), tw, bark)
		for y = round(2 * f), h + 1 do
			local t = (y - 2 * f) / (h - 2 * f)
			local r = (1 - t) * 5 * f + 0.6 - (if y % 3 == 0 then 0.8 else 0)
			for x = -math.ceil(r + 1), math.ceil(r + 1) do
				for z = -math.ceil(r + 1), math.ceil(r + 1) do
					local n = math.noise(x * 0.4 + seed, y * 0.4, z * 0.4) * 0.8
					if x * x + z * z <= (r + n) ^ 2 then
						local l = leaves(x, y, z, 0.5)
						Voxel.set(g, x, y, z, l.color, l.material, l.alpha)
					end
				end
			end
		end
		table.insert(blobs, { x = 0, y = h * 0.35, z = 0, r = 4 * f, ry = h * 0.3 })
	elseif shape == "palm" then
		local h = round(11 * f)
		local top = Vector3.zero
		for i = 0, h do
			local p = Vector3.new((i / h) ^ 2 * 2.5 * f, i, 0)
			line(g, p, p, 1, function(x, y, z)
				local l = bark(x, y, z)
				if y % 2 == 0 then
					l.color = l.color:Lerp(Color3.new(0, 0, 0), 0.15)
				end
				return l
			end)
			top = p
		end
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local len = 5 * f
			local prev = top
			for i = 1, round(len * 2) do
				local t = i / (len * 2)
				local p = top
					+ Vector3.new(
						math.cos(a) * len * t,
						1 - (t ^ 2) * 3.5 * f,
						math.sin(a) * len * t
					)
				line(g, prev, p, 1, leafLine)
				prev = p
			end
		end
		table.insert(blobs, { x = top.X, y = top.Y - 1, z = 0, r = 1.2, ry = 1 })
	elseif shape == "baobab" then
		local h = round(7 * f)
		for y = 0, h do
			local w = if y > 1 and y < h - 1 then 4 else 3
			line(g, Vector3.new(0, y, 0), Vector3.new(0, y, 0), w, bark)
		end
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + 0.4
			local tip = Vector3.new(math.cos(a) * 3.5 * f, h + 2.5 * f, math.sin(a) * 3.5 * f)
			line(g, Vector3.new(0, h, 0), tip, 1, bark)
			addBlob(tip.X, tip.Y + 0.5, tip.Z, 2 * f, 1.3 * f)
		end
	elseif shape == "umbrella" then
		local h = round(5 * f)
		line(g, Vector3.zero, Vector3.new(0, h, 0), tw + 1, bark)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			line(
				g,
				Vector3.new(0, h, 0),
				Vector3.new(math.cos(a) * 3.2 * f, h + 3 * f, math.sin(a) * 3.2 * f),
				1,
				bark
			)
		end
		addBlob(0, h + 4 * f, 0, 5.2 * f, 1.6 * f)
	elseif shape == "world" then
		local h = round(7 * f)
		line(g, Vector3.zero, Vector3.new(0, h, 0), 3, bark)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			line(
				g,
				Vector3.new(0, 1, 0),
				Vector3.new(math.cos(a) * 3.5 * f, 0, math.sin(a) * 3.5 * f),
				1,
				bark
			)
			if k % 2 == 0 then
				local tip = Vector3.new(math.cos(a) * 3 * f, h + 2 * f, math.sin(a) * 3 * f)
				line(g, Vector3.new(0, h - 1, 0), tip, 1, bark)
				addBlob(tip.X, tip.Y + 1, tip.Z, 3 * f, 2.2 * f)
			end
		end
		addBlob(0, h + 4 * f, 0, 3.6 * f, 2.6 * f)
	elseif shape == "birch" or shape == "crystal" then
		local h = round(9 * f)
		line(g, Vector3.zero, Vector3.new(0, h, 0), 1, bark)
		addBlob(0, h + 1, 0, 2.6 * f, 4.2 * f)
		addBlob(1.2, h - 3 * f, 0.6, 1.8 * f, 2 * f)
	elseif shape == "willow" then
		local h = round(5 * f)
		line(g, Vector3.zero, Vector3.new(0, h, 0), tw, bark)
		addBlob(0, h + 2 * f, 0, 4.4 * f, 2.6 * f)
		-- свисающие ветви
		for k = 0, 17 do
			local a = k / 18 * math.pi * 2
			local r = 3.8 * f
			local x, z = math.cos(a) * r, math.sin(a) * r
			local len = rng:NextNumber(3, 6) * f
			line(
				g,
				Vector3.new(x, h + 1.5 * f, z),
				Vector3.new(x * 1.1, h + 1.5 * f - len, z * 1.1),
				1,
				leafLine
			)
		end
	else
		-- round, blossom, rainbow, flame: ствол, ветви и несколько крон
		local h = round((if shape == "rainbow" then 8 else 5) * f)
		line(g, Vector3.zero, Vector3.new(0, h, 0), tw, bark)
		local cy = h + 2.6 * f
		addBlob(0, cy, 0, (if shape == "blossom" then 4.6 else 4) * f, 3 * f)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2 + seed
			local bx, bz = math.cos(a) * 2.6 * f, math.sin(a) * 2.6 * f
			line(g, Vector3.new(0, h - 1, 0), Vector3.new(bx, cy - 1, bz), 1, bark)
			addBlob(bx, cy - 0.8 * f, bz, 2.6 * f, 2.2 * f)
		end
	end

	-- Плоды или бутоны на созревшем дереве
	if ready then
		local count = 4 + stage * 2
		for i = 1, count do
			local p = surfacePoint(blobs, rng)
			local color = tree.fruit or leafBase:Lerp(Color3.new(1, 1, 1), 0.6)
			if mutation == "golden" then
				color = Color3.fromRGB(255, 205, 60)
			elseif mutation == "rainbow" then
				color = RAINBOW[(i - 1) % #RAINBOW + 1]
			end
			local material = if tree.glow or mutation
				then Enum.Material.Neon
				else Enum.Material.SmoothPlastic
			local size = if mutation == "big" then 1 else 0
			for dx = 0, size do
				for dy = 0, size do
					for dz = 0, size do
						Voxel.set(
							g,
							round(p.X) + dx,
							round(p.Y) - dy,
							round(p.Z) + dz,
							color,
							material
						)
					end
				end
			end
		end
	end

	local model = Instance.new("Model")
	model.Name = "Tree"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = base
	root.Parent = model
	model.PrimaryPart = root
	Voxel.build(g, model, base * CFrame.new(0, V / 2, 0))

	-- Свет и частицы у редких деревьев и мутаций
	local top = blobs[1]
	local center = if top then base * CFrame.new(top.x * V, top.y * V, top.z * V) else base
	local fx: Part? = nil
	local function anchorPart(): Part
		if fx then
			return fx
		end
		local p = Instance.new("Part")
		p.Name = "Fx"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.new(4, 4, 4)
		p.CFrame = center
		p.Parent = model
		fx = p
		return p
	end
	if tree.glow then
		local light = Instance.new("PointLight")
		light.Color = tree.fruit or tree.leaf
		light.Range = 10 + rarity.order * 2
		light.Brightness = 1.2
		light.Parent = anchorPart()
	end
	if rarity.order >= 4 or shape == "blossom" then
		local p = Instance.new("ParticleEmitter")
		p.Color =
			ColorSequence.new(if shape == "blossom" then leafBase else (tree.fruit or tree.leaf))
		p.LightEmission = if tree.glow then 0.8 else 0
		p.Rate = if shape == "blossom" then 3 else 4
		p.Lifetime = NumberRange.new(2, 3.5)
		p.Speed = NumberRange.new(0.5, 1.5)
		p.Acceleration = if shape == "blossom"
			then Vector3.new(0, -1.5, 0)
			else Vector3.new(0, 0.5, 0)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Size = NumberSequence.new(0.25, 0.1)
		p.Shape = Enum.ParticleEmitterShape.Box
		p.Parent = anchorPart()
	end
	if shape == "flame" then
		local fire = Instance.new("Fire")
		fire.Color = tree.leaf
		fire.SecondaryColor = if treeId == "voidoak"
			then Color3.fromRGB(20, 0, 40)
			else Color3.fromRGB(255, 220, 80)
		fire.Size = 4
		fire.Heat = 4
		fire.Parent = anchorPart()
	end
	local m = Garden.mutation(mutation)
	if m then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(m.color)
		sparkle.LightEmission = 1
		sparkle.Rate = 6
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Shape = Enum.ParticleEmitterShape.Box
		sparkle.Parent = anchorPart()
	end
	return model
end

return TreeBuilder
