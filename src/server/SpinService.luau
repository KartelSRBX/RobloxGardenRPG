--!strict
-- Серверный бросок крутилки. Клиент результат только показывает.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

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

return SpinService
