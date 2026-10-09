--!strict
-- Инвентарь: продажа добычи из подземелья, компост лишних ростков за монеты,
-- выбор косметического сияния персонажа из открытых видов.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

local InventoryService = {}

local function validCount(count: any): boolean
	return type(count) == "number" and count == math.floor(count) and count >= 1 and count <= 100000
end

-- Возвращает выручку или ошибку.
function InventoryService.sellItem(profile: Profile, id: any, count: any): (number?, string?)
	if type(id) ~= "string" or not validCount(count) then
		return nil, "bad_args"
	end
	local item = Config.Items[id]
	if not item then
		return nil, "bad_item"
	end
	local have = profile.items[id] or 0
	if have < count then
		return nil, "not_enough"
	end
	local value = item.value * count
	profile.items[id] = if have > count then have - count else nil
	profile.coins += value
	return value, nil
end

function InventoryService.sellSeed(profile: Profile, id: any, count: any): (number?, string?)
	if type(id) ~= "string" or not validCount(count) then
		return nil, "bad_args"
	end
	local tree = Garden.tree(id)
	if not tree then
		return nil, "bad_item"
	end
	local have = profile.seeds[id] or 0
	if have < count then
		return nil, "not_enough"
	end
	local each = math.max(1, math.floor(Garden.baseIncome(tree) * Config.SellSeedSeconds / 60))
	profile.seeds[id] = if have > count then have - count else nil
	profile.coins += each * count
	return each * count, nil
end

function InventoryService.equipAura(profile: Profile, id: any): string?
	if id == false then
		profile.aura = nil
		return nil
	end
	if type(id) ~= "string" or not Garden.tree(id) then
		return "bad_args"
	end
	-- сияние эксклюзивного дерева — у тех, у кого оно посажено или куплено (found)
	if not profile.found[id] then
		return "not_found"
	end
	profile.aura = id
	return nil
end

-- Показать сияние на персонаже: клиенты рисуют его по атрибуту Aura.
function InventoryService.applyAura(player: Player, profile: Profile)
	local character = player.Character
	if character then
		character:SetAttribute("Aura", profile.aura)
	end
end

return InventoryService
