--!strict
-- Чистые формулы сада: общие для сервера (расчёт) и клиента (отображение).
local Config = require(script.Parent.Config)
local Plants = require(script.Parent.Config.Plants)

export type Plot = {
	plantId: string?,
	level: number,
	plantedAt: number, -- os.time() начала текущего цикла роста
	mutation: string?,
	mutationRolled: boolean,
}

local Garden = {}

local byId: { [string]: Plants.Plant } = {}
local byRarity: { [string]: Plants.Plant } = {}
for _, p in Config.Plants do
	byId[p.id] = p
	byRarity[p.rarity] = p
end

function Garden.plant(id: string): Plants.Plant?
	return byId[id]
end

function Garden.plantForRarity(rarity: string): Plants.Plant?
	return byRarity[rarity]
end

function Garden.mutation(id: string?)
	if id == nil then
		return nil
	end
	for _, m in Config.Mutations do
		if m.id == id then
			return m
		end
	end
	return nil
end

function Garden.stageName(plant: Plants.Plant, level: number): string
	local idx = math.clamp(math.ceil(level / 2), 1, #plant.stages)
	return plant.stages[idx]
end

function Garden.growTime(plant: Plants.Plant, level: number): number
	local mult = 1 - Config.Upgrade.timeCutPerLevel * (level - 1)
	return math.max(1, math.floor(plant.growTime * mult))
end

function Garden.fruitPrice(plant: Plants.Plant, level: number): number
	return plant.fruitPrice * (1 + Config.Upgrade.priceBonusPerLevel * (level - 1))
end

-- Доход за урожай с учётом мутации, целые монеты.
function Garden.harvestValue(plant: Plants.Plant, level: number, mutation: string?): number
	local m = Garden.mutation(mutation)
	local mult = if m then m.priceMult else 1
	return math.floor(plant.fruits * Garden.fruitPrice(plant, level) * mult)
end

-- Цена прокачки с текущего уровня на следующий; nil, если уровень максимальный.
function Garden.upgradeCost(plant: Plants.Plant, level: number): number?
	if level >= Config.Upgrade.maxLevel then
		return nil
	end
	return math.floor(plant.upgradeBase * Config.Upgrade.costGrowth ^ (level - 1))
end

-- Цена следующей грядки за монеты; nil, если куплены все.
function Garden.plotPrice(owned: number): number?
	if owned >= Config.MaxPlots then
		return nil
	end
	return Config.PlotPrices[owned - Config.StartingPlots + 1]
end

function Garden.rarity(id: string)
	for _, r in Config.Rarities do
		if r.id == id then
			return r
		end
	end
	return Config.Rarities[1]
end

-- Баффы подземелья от сада: сумма уровней посаженных деревьев.
function Garden.buffs(plots: { Plot }): (number, number)
	local levels = 0
	for _, plot in plots do
		if plot.plantId then
			levels += plot.level
		end
	end
	local b = Config.Dungeon.buffs
	return levels * b.hpPerTreeLevel, levels * b.damagePerTreeLevel
end

function Garden.readyAt(plot: Plot): number?
	local plant = plot.plantId and byId[plot.plantId]
	if not plant then
		return nil
	end
	return plot.plantedAt + Garden.growTime(plant, plot.level)
end

return Garden
