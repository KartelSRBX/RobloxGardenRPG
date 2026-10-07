--!strict
-- Серверный бросок крутилки. Клиент результат только показывает.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local DataService = require(script.Parent.DataService)

local SpinService = {}

local rng = Random.new()

function SpinService.roll(): string
	local total = 0
	for _, r in Config.Rarities do
		total += r.chance
	end
	local pick = rng:NextNumber() * total
	local acc = 0
	for _, r in Config.Rarities do
		acc += r.chance
		if pick <= acc then
			return r.id
		end
	end
	return Config.Rarities[1].id
end

-- Списывает монеты и выдаёт семя. Возвращает id растения или ошибку.
function SpinService.spin(player: Player): (string?, string?)
	local profile = DataService.get(player)
	if not profile then
		return nil, "not_loaded"
	end
	if profile.coins < Config.SpinCost then
		return nil, "not_enough_coins"
	end
	local plant = Garden.plantForRarity(SpinService.roll())
	if not plant then
		return nil, "config"
	end
	profile.coins -= Config.SpinCost
	profile.seeds[plant.id] = (profile.seeds[plant.id] or 0) + 1
	return plant.id, nil
end

return SpinService
