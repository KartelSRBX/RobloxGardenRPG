--!strict
-- Грядки: посадка, рост по серверному времени, мутация при созревании,
-- сбор урожая с автопродажей, прокачка дерева, удобрение, покупка грядок, выкапывание.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

local GardenService = {}

local rng = Random.new()

local function rollMutation(): string?
	local pick = rng:NextNumber() * 100
	local acc = 0
	for _, m in Config.Mutations do
		acc += m.chance
		if pick < acc then
			return m.id
		end
	end
	return nil
end

local function emptyPlot(): Garden.Plot
	return { level = 0, plantedAt = 0, mutationRolled = false }
end

-- Бросает мутацию на созревших грядках. true, если что-то изменилось.
function GardenService.tick(profile: Profile, now: number): boolean
	local changed = false
	for _, plot in profile.plots do
		local readyAt = Garden.readyAt(plot)
		if readyAt and now >= readyAt and not plot.mutationRolled then
			-- перк Dragon's Hoard: урожай всегда золотой (без броска)
			plot.mutation = if Garden.perk(plot.plantId) == "golden"
				then "golden"
				else rollMutation()
			plot.mutationRolled = true
			changed = true
		end
	end
	return changed
end

-- ownedPremium — эксклюзивные деревья, купленные игроком: { [treeId] = true }.
function GardenService.plant(
	profile: Profile,
	slot: number,
	plantId: string,
	ownedPremium: { [string]: boolean }?
): string?
	local plot = profile.plots[slot]
	if not plot then
		return "bad_slot"
	end
	if plot.plantId then
		return "occupied"
	end
	if not Garden.plant(plantId) then
		return "bad_plant"
	end
	if Garden.isPremium(plantId) then
		-- эксклюзив: семя не тратится, но на острове только одно такое дерево
		if not (ownedPremium and ownedPremium[plantId]) then
			return "not_owned"
		end
		for _, other in profile.plots do
			if other.plantId == plantId then
				return "already_planted"
			end
		end
		profile.found[plantId] = true
	else
		local count = profile.seeds[plantId] or 0
		if count <= 0 then
			return "no_seed"
		end
		profile.seeds[plantId] = if count > 1 then count - 1 else nil
	end
	plot.plantId = plantId
	plot.level = 1
	plot.plantedAt = os.time()
	plot.mutation = nil
	plot.mutationRolled = false
	if profile.tutorial == Tutorial.PLANT then
		profile.tutorial = Tutorial.SPIN
	end
	return nil
end

-- coinMult — множитель монет из геймпасса; на шансы не влияет.
function GardenService.harvest(profile: Profile, slot: number, coinMult: number): (number?, string?)
	local plot = profile.plots[slot]
	local plant = plot and plot.plantId and Garden.plant(plot.plantId)
	if not plot or not plant then
		return nil, "empty"
	end
	local now = os.time()
	local readyAt = Garden.readyAt(plot) :: number
	if now < readyAt then
		return nil, "not_ready"
	end
	GardenService.tick(profile, now)
	local value = math.floor(
		Garden.harvestValue(plant, plot.level, plot.mutation)
			* coinMult
			* Garden.neighborMult(profile.plots, slot)
	)
	profile.coins += value
	if Garden.perk(plot.plantId) == "fertilizer" then
		profile.items.fertilizer = (profile.items.fertilizer or 0) + 1
	end
	profile.stats.harvests = (profile.stats.harvests or 0) + 1
	plot.plantedAt = now
	plot.mutation = nil
	plot.mutationRolled = false
	if profile.tutorial < Tutorial.DONE then
		profile.tutorial = Tutorial.DONE
	end
	return value, nil
end

function GardenService.upgrade(profile: Profile, slot: number): string?
	local plot = profile.plots[slot]
	local plant = plot and plot.plantId and Garden.plant(plot.plantId)
	if not plot or not plant then
		return "empty"
	end
	local cost = Garden.upgradeCost(plant, plot.level)
	if not cost then
		return "max_level"
	end
	if profile.coins < cost then
		return "not_enough_coins"
	end
	profile.coins -= cost
	plot.level += 1
	return nil
end

function GardenService.fertilize(profile: Profile, slot: number): string?
	local plot = profile.plots[slot]
	local plant = plot and plot.plantId and Garden.plant(plot.plantId)
	if not plot or not plant then
		return "empty"
	end
	if plot.mutationRolled then
		return "already_ready"
	end
	local have = profile.items.fertilizer or 0
	if have <= 0 then
		return "no_fertilizer"
	end
	profile.items.fertilizer = if have > 1 then have - 1 else nil
	plot.plantedAt -= math.floor(Garden.growTime(plant, plot.level) * Config.Fertilizer.cut)
	return nil
end

-- Сколько ростков всего в запасе.
function GardenService.seedCount(profile: Profile): number
	local total = 0
	for _, n in profile.seeds do
		total += n
	end
	return total
end

-- Расширение острова: нужно время в игре, монеты и ростки (тратятся самые частые).
-- Грядок должно быть: уровень острова + бонус пропуска Bigger Island.
function GardenService.ensurePlots(profile: Profile, bonus: number)
	for _ = #profile.plots + 1, Garden.islandPlots(profile.islandTier) + bonus do
		table.insert(profile.plots, emptyPlot())
	end
end

function GardenService.expand(profile: Profile, bonus: number?): string?
	local nextTier = Garden.nextIsland(profile.islandTier)
	if not nextTier then
		return "max_island"
	end
	if profile.playSeconds < nextTier.minutes * 60 then
		return "need_time"
	end
	if profile.coins < nextTier.coins then
		return "not_enough_coins"
	end
	if GardenService.seedCount(profile) < nextTier.seeds then
		return "need_seeds"
	end
	profile.coins -= nextTier.coins
	local ids = {}
	for id in profile.seeds do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (Garden.tree(a) :: Garden.Tree).n < (Garden.tree(b) :: Garden.Tree).n
	end)
	local left = nextTier.seeds
	for _, id in ids do
		local take = math.min(left, profile.seeds[id])
		profile.seeds[id] -= take
		if profile.seeds[id] <= 0 then
			profile.seeds[id] = nil
		end
		left -= take
		if left <= 0 then
			break
		end
	end
	profile.islandTier += 1
	GardenService.ensurePlots(profile, bonus or 0)
	return nil
end

function GardenService.remove(profile: Profile, slot: number): string?
	local plot = profile.plots[slot]
	if not plot or not plot.plantId then
		return "empty"
	end
	profile.plots[slot] = emptyPlot()
	return nil
end

return GardenService
