--!strict
-- Воксельное дерево по растению, стадии и мутации. Каждая стадия заметно богаче:
-- 1 простое дерево, 2 цветы, 3 светящиеся плоды, 4 искры, 5 огромное дерево со светом.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Garden = require(ReplicatedStorage.Shared.Garden)

local TreeBuilder = {}

local WOOD = Color3.fromRGB(120, 80, 50)
local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 240, 80),
	Color3.fromRGB(90, 220, 110),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(180, 100, 255),
}

local function block(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

-- Модель стоит основанием в точке base. ready — показать плоды.
function TreeBuilder.build(
	plantId: string,
	level: number,
	ready: boolean,
	mutation: string?,
	base: CFrame
): Model
	local plant = Garden.plant(plantId) :: any
	local stage = math.clamp(math.ceil(level / 2), 1, 5)
	local s = 1 + (stage - 1) * 0.15
	local model = Instance.new("Model")
	model.Name = "Tree"

	-- Ствол
	local trunkH = 4.5 * s
	local trunk = block(
		model,
		"Trunk",
		Vector3.new(1.4, trunkH, 1.4) * math.sqrt(s),
		base * CFrame.new(0, trunkH / 2, 0),
		WOOD,
		Enum.Material.Wood
	)
	trunk.CanCollide = true
	model.PrimaryPart = trunk

	-- Крона: основной куб, верхний куб и боковые кубы на высоких стадиях
	local crownY = trunkH + 1.8 * s
	local leaf: Color3 = plant.leafColor
	local crown = block(
		model,
		"Leaves",
		Vector3.new(6, 3.6, 6) * s,
		base * CFrame.new(0, crownY, 0),
		leaf,
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"Leaves",
		Vector3.new(4, 2.4, 4) * s,
		base * CFrame.new(0, crownY + 2.8 * s, 0),
		leaf:Lerp(Color3.new(1, 1, 1), 0.12),
		Enum.Material.SmoothPlastic
	)
	if stage >= 3 then
		for _, d in
			{
				Vector3.new(1, 0, 0),
				Vector3.new(-1, 0, 0),
				Vector3.new(0, 0, 1),
				Vector3.new(0, 0, -1),
			}
		do
			block(
				model,
				"Leaves",
				Vector3.new(2.6, 2.6, 2.6) * s,
				base * CFrame.new(d * 3 * s + Vector3.new(0, crownY - 0.4 * s, 0)),
				leaf:Lerp(Color3.new(0, 0, 0), 0.08),
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Цветы со 2-й стадии
	if stage >= 2 then
		local rng = Random.new(#plantId + stage)
		for _ = 1, 4 + stage * 2 do
			local off = Vector3.new(
				rng:NextNumber(-3, 3),
				rng:NextNumber(-1, 2.5),
				rng:NextNumber(-3, 3)
			) * s
			block(
				model,
				"Blossom",
				Vector3.new(0.6, 0.6, 0.6),
				base * CFrame.new(Vector3.new(0, crownY, 0) + off),
				Color3.fromRGB(255, 235, 245)
			)
		end
	end

	-- Плоды: видны только у созревшего дерева
	if ready then
		local mut = Garden.mutation(mutation)
		local size = if mutation == "big" then 1.5 else 1
		local material = if stage >= 3 or mut
			then Enum.Material.Neon
			else Enum.Material.SmoothPlastic
		for i = 1, plant.fruits do
			local a = (i / plant.fruits) * math.pi * 2
			local r = (if stage >= 3 then 4.2 else 3.2) * s
			local pos = Vector3.new(math.cos(a) * r, -1.6 * s + (i % 2) * 0.8, math.sin(a) * r)
			local color: Color3 = plant.fruitColor
			if mutation == "golden" then
				color = Color3.fromRGB(255, 205, 50)
			elseif mutation == "rainbow" then
				color = RAINBOW[(i - 1) % #RAINBOW + 1]
			end
			local fruit = block(
				model,
				"Fruit",
				Vector3.new(1.4, 1.4, 1.4) * size * math.sqrt(s),
				base * CFrame.new(Vector3.new(0, crownY, 0) + pos),
				color,
				material
			)
			fruit.Shape = Enum.PartType.Ball
		end
		if mut then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Color = ColorSequence.new(mut.color)
			sparkle.LightEmission = 1
			sparkle.Rate = 8
			sparkle.Lifetime = NumberRange.new(0.8, 1.4)
			sparkle.Speed = NumberRange.new(1, 2)
			sparkle.Size = NumberSequence.new(0.5, 0)
			sparkle.Parent = crown
		end
	end

	-- Искры с 4-й стадии
	if stage >= 4 then
		local p = Instance.new("ParticleEmitter")
		p.Color = ColorSequence.new(plant.fruitColor:Lerp(Color3.new(1, 1, 1), 0.5))
		p.LightEmission = 0.8
		p.Rate = 6
		p.Lifetime = NumberRange.new(1.5, 2.5)
		p.Speed = NumberRange.new(0.5, 1.5)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Size = NumberSequence.new(0.35, 0)
		p.Parent = crown
	end

	-- Свет и лучи на 5-й стадии
	if stage >= 5 then
		local light = Instance.new("PointLight")
		light.Color = plant.fruitColor
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = crown
		-- парящие светящиеся кубы над кроной
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			block(
				model,
				"Orb",
				Vector3.new(0.9, 0.9, 0.9),
				base
					* CFrame.new(math.cos(a) * 4 * s, crownY + 5 * s, math.sin(a) * 4 * s)
					* CFrame.Angles(a, a, 0),
				plant.fruitColor:Lerp(Color3.new(1, 1, 1), 0.3),
				Enum.Material.Neon
			)
		end
	end

	return model
end

return TreeBuilder
