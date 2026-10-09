--!strict
-- Чистые формулы сада и острова: общие для сервера (расчёт) и клиента (отображение).
local Config = require(script.Parent.Config)
local Trees = require(script.Parent.Config.Trees)

export type Plot = {
	plantId: string?,
	level: number,
	plantedAt: number, -- os.time() начала текущего цикла роста
	mutation: string?,
	mutationRolled: boolean,
}

export type Tree = Trees.Tree

local Garden = {}

local byId: { [string]: Tree } = {}
for _, t in Config.Trees do
	byId[t.id] = t
end

function Garden.tree(id: string?): Tree?
	return if id then byId[id] else nil
end

-- Совместимость со старым названием.
Garden.plant = Garden.tree

function Garden.rarity(id: string)
	for _, r in Config.Rarities do
		if r.id == id then
			return r
		end
	end
	return Config.Rarities[1]
end

-- Сияние вида; если не задано — из цветов редкости.
function Garden.aura(id: string)
	local a = Config.Auras[id]
	if a then
		return a
	end
	local tree = Garden.tree(id)
	local r = Garden.rarity(if tree then tree.rarity else "common")
	return { palette = { r.color, r.color2, r.color }, particles = "motes" }
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

-- Монет в минуту на 1 уровне.
function Garden.baseIncome(tree: Tree): number
	local e = Config.Economy
	return e.incomeBase * tree.n ^ e.incomeExp
end

function Garden.yieldMult(level: number): number
	return 1 + Config.Upgrade.yieldPerLevel * (level - 1)
end

function Garden.incomePerMinute(tree: Tree, level: number): number
	return Garden.baseIncome(tree) * Garden.yieldMult(level)
end

function Garden.growTime(tree: Tree, _level: number?): number
	local e = Config.Economy
	return math.max(5, math.floor(e.growBase * tree.n ^ e.growExp))
end

-- Доход за один урожай с учётом мутации, целые монеты.
function Garden.harvestValue(tree: Tree, level: number, mutation: string?): number
	local m = Garden.mutation(mutation)
	local mult = if m then m.priceMult else 1
	local perHarvest = Garden.incomePerMinute(tree, level) * Garden.growTime(tree) / 60
	return math.max(1, math.floor(perHarvest * mult))
end

-- Цена прокачки с текущего уровня на следующий; nil, если уровень максимальный.
function Garden.upgradeCost(tree: Tree, level: number): number?
	local u = Config.Upgrade
	if level >= u.maxLevel then
		return nil
	end
	return math.floor(Garden.baseIncome(tree) * u.firstCostMinutes * u.costGrowth ^ (level - 1))
end

-- Визуальная стадия 1..6 (растёт каждые levelsPerStage уровней).
function Garden.stage(level: number): number
	return math.clamp(1 + level // Config.Upgrade.levelsPerStage, 1, 6)
end

function Garden.compostValue(tree: Tree): number
	return math.max(1, math.floor(Garden.baseIncome(tree) * Config.Economy.compostSeconds / 60))
end

function Garden.readyAt(plot: Plot): number?
	local tree = Garden.tree(plot.plantId)
	if not tree then
		return nil
	end
	return plot.plantedAt + Garden.growTime(tree)
end

-- Баффы подземелья: от корня суммы уровней посаженных деревьев.
function Garden.buffs(plots: { Plot }): (number, number)
	local levels = 0
	for _, plot in plots do
		if plot.plantId then
			levels += plot.level
		end
	end
	local b = Config.Dungeon.buffs
	local root = math.sqrt(levels)
	return math.floor(root * b.hpPerSqrtLevel), root * b.damagePerSqrtLevel
end

-- Остров
function Garden.islandPlots(tier: number): number
	local t = Config.Island[math.clamp(tier, 1, #Config.Island)]
	return t.plots
end

function Garden.nextIsland(tier: number)
	return Config.Island[tier + 1]
end

return Garden
