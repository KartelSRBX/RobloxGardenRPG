--!strict
-- Летающий воксельный остров: травяной верх с оттенками, слой земли, каменный низ конусом.
-- Верх ровный (на нём грядки), край рваный по шуму.
local Voxel = require(script.Parent.Voxel)

local IslandBuilder = {}

local V = 2 -- размер вокселя острова, studs

local GRASS = Color3.fromRGB(96, 150, 72)
local GRASS_LIGHT = Color3.fromRGB(122, 172, 84)
local DIRT = Color3.fromRGB(118, 86, 60)
local STONE = Color3.fromRGB(110, 110, 118)
local STONE_DARK = Color3.fromRGB(82, 82, 92)
local FLOWERS = {
	Color3.fromRGB(240, 220, 120),
	Color3.fromRGB(230, 120, 150),
	Color3.fromRGB(240, 240, 250),
	Color3.fromRGB(150, 130, 230),
}

-- center — точка на поверхности острова (верх травы). radius — в studs.
-- keepClear(x, z) -> true, если клетку нельзя украшать (грядки, дорожки).
function IslandBuilder.build(
	center: CFrame,
	radius: number,
	seed: number,
	keepClear: ((number, number) -> boolean)?
): Model
	local g = Voxel.new(V)
	local deco = Voxel.new(V / 2)
	local r = radius / V
	local depth = math.max(5, math.floor(r * 1.3))
	local rng = Random.new(seed)
	for x = -math.ceil(r + 2), math.ceil(r + 2) do
		for z = -math.ceil(r + 2), math.ceil(r + 2) do
			local edge = r + math.noise(x * 0.18 + seed, z * 0.18 - seed) * 2.2
			local d = math.sqrt(x * x + z * z)
			if d <= edge then
				-- трава сверху
				local t = math.noise(x * 0.12 - seed, 0.5, z * 0.12)
				local grass = if t > 0.15
					then GRASS_LIGHT
					elseif t < -0.2 then GRASS:Lerp(Color3.new(0, 0, 0), 0.08)
					else GRASS
				Voxel.set(g, x, 0, z, grass, Enum.Material.SmoothPlastic)
				-- столбик вниз: чем дальше от центра, тем короче
				local k = math.max(0, 1 - d / edge) ^ 0.9
				local h =
					math.max(1, math.floor(depth * k + math.noise(x * 0.3, z * 0.3, seed) * 3))
				for y = 1, h do
					local c
					if y <= 2 then
						c = DIRT
					elseif y <= 3 then
						c = DIRT:Lerp(STONE, 0.5)
					else
						c = if (x + z + y) % 3 == 0 then STONE_DARK else STONE
					end
					Voxel.set(g, x, -y, z, c, Enum.Material.SmoothPlastic)
				end
				-- трава и цветы на свободных клетках
				local wx, wz = x * V, z * V
				if d < edge - 1 and not (keepClear and keepClear(wx, wz)) then
					local roll = rng:NextNumber()
					if roll < 0.12 then
						Voxel.set(deco, x * 2, 0, z * 2, GRASS_LIGHT:Lerp(Color3.new(1, 1, 1), 0.1))
					elseif roll < 0.16 then
						Voxel.set(deco, x * 2 + 1, 1, z * 2, FLOWERS[rng:NextInteger(1, #FLOWERS)])
						Voxel.set(deco, x * 2 + 1, 0, z * 2, Color3.fromRGB(80, 130, 60))
					end
				end
			end
		end
	end
	local model = Instance.new("Model")
	model.Name = "Island"
	local terrain = Instance.new("Model")
	terrain.Name = "Terrain"
	terrain.Parent = model
	-- верх вокселей y=0 должен совпасть с поверхностью center
	Voxel.build(
		g,
		terrain,
		center * CFrame.new(0, -V / 2, 0),
		{ collide = true, castShadow = true }
	)
	Voxel.build(deco, model, center * CFrame.new(0, V / 4, 0), { castShadow = false })
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = center
	root.Parent = model
	model.PrimaryPart = root
	return model
end

return IslandBuilder
