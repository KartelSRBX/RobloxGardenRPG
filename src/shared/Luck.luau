--!strict
-- Удача и шансы крутилки. Один код для сервера (бросок) и клиента (таблица шансов).
-- Бросок: от самого редкого вида к частому, вид выпадает с шансом min(1, удача / n);
-- если не выпало ничего — самый частый вид. Поэтому сумма шансов всегда 100%.
local Config = require(script.Parent.Config)

local R = Config.Roll

local Luck = {}

export type Breakdown = {
	total: number,
	rolls: number,
	upgrade: number,
	index: number,
	nextMilestone: { number }?,
}

-- Порядок от редкого к частому.
local ordered = table.clone(Config.Trees)
table.sort(ordered, function(a, b)
	return a.n > b.n
end)

local function countKeys(t: { [string]: any }?): number
	local c = 0
	for _ in t or {} do
		c += 1
	end
	return c
end

-- Удача без множителя счастливой крутки.
function Luck.breakdown(profile: any): Breakdown
	local rolls = profile.rolls or 0
	local fromRolls = 0
	local nextMilestone = nil
	for _, m in R.milestones do
		if rolls >= m[1] then
			fromRolls += m[2]
		elseif not nextMilestone then
			nextMilestone = m
		end
	end
	local fromUpgrade = (profile.luckLevel or 0) * R.luckStep
	local fromIndex = countKeys(profile.found) * R.indexLuck
	return {
		total = 1 + fromRolls + fromUpgrade + fromIndex,
		rolls = fromRolls,
		upgrade = fromUpgrade,
		index = fromIndex,
		nextMilestone = nextMilestone,
	}
end

-- Номер крутки, начиная с 1, счастливый?
function Luck.isLucky(rollNumber: number): boolean
	return rollNumber % R.luckyEvery == 0
end

function Luck.cooldown(profile: any): number
	return math.max(R.minCooldown, R.cooldown - (profile.speedLevel or 0) * R.speedStep)
end

function Luck.roll(luck: number, rng: Random): string
	for _, t in ordered do
		if rng:NextNumber() < math.min(1, luck / t.n) then
			return t.id
		end
	end
	return ordered[#ordered].id
end

-- Итоговый шанс каждого вида при данной удаче (сумма 1).
function Luck.chances(luck: number): { [string]: number }
	local out: { [string]: number } = {}
	local miss = 1
	for i, t in ordered do
		local p = if i == #ordered then 1 else math.min(1, luck / t.n)
		out[t.id] = miss * p
		miss *= 1 - p
	end
	return out
end

-- «1 из X» при базовой удаче: то, что видит игрок как редкость вида.
local baseOneIn: { [string]: number } = {}
for id, p in Luck.chances(1) do
	baseOneIn[id] = if p > 0 then 1 / p else math.huge
end
function Luck.oneIn(treeId: string): number
	return baseOneIn[treeId] or math.huge
end

function Luck.luckCost(level: number): number?
	if level >= R.luckMaxLevel then
		return nil
	end
	return math.floor(R.luckCostBase * R.luckCostGrowth ^ level)
end

function Luck.speedCost(level: number): number?
	if R.cooldown - level * R.speedStep <= R.minCooldown + 1e-6 then
		return nil
	end
	return math.floor(R.speedCostBase * R.speedCostGrowth ^ level)
end

return Luck
