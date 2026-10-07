--!strict
-- Грядки: посадка, рост по серверному времени, мутация при созревании,
-- сбор урожая с автопродажей, прокачка дерева, выкапывание.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
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

local function getPlot(profile: Profile, slot: number): Garden.Plot?
	return profile.plots[slot]
end

-- Бросает мутацию на созревших грядках. true, если что-то изменилось.
function GardenService.tick(profile: Profile, now: number): boolean
	local changed = false
	for _, plot in profile.plots do
		local readyAt = Garden.readyAt(plot)
		if readyAt and now >= readyAt and not plot.mutationRolled then
			plot.mutation = rollMutation()
			plot.mutationRolled = true
			changed = true
		end
	end
	return changed
end

function GardenService.plant(profile: Profile, slot: number, plantId: string): string?
	local plot = getPlot(profile, slot)
	if not plot then
		return "bad_slot"
	end
	if plot.plantId then
		return "occupied"
	end
	if not Garden.plant(plantId) then
		return "bad_plant"
	end
	local count = profile.seeds[plantId] or 0
	if count <= 0 then
		return "no_seed"
	end
	profile.seeds[plantId] = if count > 1 then count - 1 else nil
	plot.plantId = plantId
	plot.level = 1
	plot.plantedAt = os.time()
	plot.mutation = nil
	plot.mutationRolled = false
	return nil
end

function GardenService.harvest(profile: Profile, slot: number): (number?, string?)
	local plot = getPlot(profile, slot)
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
	local value = Garden.harvestValue(plant, plot.level, plot.mutation)
	profile.coins += value
	plot.plantedAt = now
	plot.mutation = nil
	plot.mutationRolled = false
	return value, nil
end

function GardenService.upgrade(profile: Profile, slot: number): string?
	local plot = getPlot(profile, slot)
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

function GardenService.remove(profile: Profile, slot: number): string?
	local plot = getPlot(profile, slot)
	if not plot or not plot.plantId then
		return "empty"
	end
	plot.plantId = nil
	plot.level = 0
	plot.plantedAt = 0
	plot.mutation = nil
	plot.mutationRolled = false
	return nil
end

return GardenService
