--!strict
-- Бесплатная крутилка: откат вместо цены, удача растёт от числа круток, улучшений
-- за монеты и коллекции. Каждая N-я крутка счастливая. Все броски на сервере.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

export type RollResult = {
	treeId: string,
	lucky: boolean,
	isNew: boolean,
	composted: number?, -- монеты, если запас этого вида полон
	luck: number,
	rolls: number,
}

local RollService = {}

local rng = Random.new()
local lastRoll: { [Player]: number } = {}

-- Добавляет росток в запас; лишнее уходит в компост. Возвращает монеты компоста.
function RollService.giveSeed(profile: Profile, treeId: string): number?
	local tree = Garden.tree(treeId) :: Garden.Tree
	local have = profile.seeds[treeId] or 0
	if have >= Config.Economy.seedCap then
		local value = Garden.compostValue(tree)
		profile.coins += value
		profile.stats.composted = (profile.stats.composted or 0) + 1
		return value
	end
	profile.seeds[treeId] = have + 1
	return nil
end

-- Одна крутка без проверки отката (её делает roll). luckMult — для добычи из подземелья.
function RollService.rollFor(profile: Profile, luckMult: number?): RollResult
	profile.rolls += 1
	local lucky = Luck.isLucky(profile.rolls)
	local luck = Luck.breakdown(profile).total
		* (if lucky then Config.Roll.luckyMult else 1)
		* (luckMult or 1)
	local treeId = Luck.roll(luck, rng)
	local isNew = not profile.found[treeId]
	profile.found[treeId] = true
	local composted = RollService.giveSeed(profile, treeId)
	return {
		treeId = treeId,
		lucky = lucky,
		isNew = isNew,
		composted = composted,
		luck = luck,
		rolls = profile.rolls,
	}
end

function RollService.roll(player: Player): (RollResult?, string?)
	local profile = DataService.get(player)
	if not profile then
		return nil, "not_loaded"
	end
	local now = os.clock()
	-- небольшой запас на сетевую задержку
	if lastRoll[player] and now - lastRoll[player] < Luck.cooldown(profile) - 0.15 then
		return nil, "cooldown"
	end
	lastRoll[player] = now
	local result = RollService.rollFor(profile)
	if profile.tutorial == Tutorial.SPIN then
		profile.tutorial = Tutorial.HARVEST
	end
	return result, nil
end

function RollService.setAutoRoll(profile: Profile, on: boolean): string?
	if on and profile.rolls < Config.Roll.autoUnlockRolls then
		return "auto_locked"
	end
	profile.autoRoll = on
	return nil
end

function RollService.buyLuck(profile: Profile): string?
	local cost = Luck.luckCost(profile.luckLevel)
	if not cost then
		return "max_level"
	end
	if profile.coins < cost then
		return "not_enough_coins"
	end
	profile.coins -= cost
	profile.luckLevel += 1
	return nil
end

function RollService.buySpeed(profile: Profile): string?
	local cost = Luck.speedCost(profile.speedLevel)
	if not cost then
		return "max_level"
	end
	if profile.coins < cost then
		return "not_enough_coins"
	end
	profile.coins -= cost
	profile.speedLevel += 1
	return nil
end

function RollService.forget(player: Player)
	lastRoll[player] = nil
end

return RollService
