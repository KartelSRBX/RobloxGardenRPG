--!strict
-- Точка входа сервера: запускает сервисы и обрабатывает запросы клиента.
-- Каждый запрос проверяется: загружен ли профиль, частота, типы и диапазоны.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.DataService)
local GardenService = require(script.GardenService)
local RateLimit = require(script.RateLimit)
local SpinService = require(script.SpinService)

type Result = { ok: boolean, error: string?, [string]: any }

local stateEvent = Remotes.event("State")

local function pushState(player: Player)
	local profile = DataService.get(player)
	if profile then
		stateEvent:FireClient(player, profile)
	end
end

local function validSlot(profile: DataService.Profile, slot: any): boolean
	return type(slot) == "number"
		and slot == math.floor(slot)
		and slot >= 1
		and slot <= #profile.plots
end

-- Общая обёртка: профиль, частота, затем действие; после успеха шлёт новое состояние.
local function handle(name: string, action: (Player, DataService.Profile, ...any) -> Result)
	Remotes.fn(name).OnServerInvoke = function(player: Player, ...: any): Result
		local profile = DataService.get(player)
		if not profile then
			return { ok = false, error = "not_loaded" }
		end
		local interval = (Config.RateLimit :: any)[string.lower(name)] or 0.2
		if not RateLimit.allow(player, name, interval) then
			return { ok = false, error = "too_fast" }
		end
		local result = action(player, profile, ...)
		if result.ok then
			pushState(player)
		end
		return result
	end
end

handle("Spin", function(player)
	local plantId, err = SpinService.spin(player)
	return { ok = plantId ~= nil, error = err, plantId = plantId }
end)

handle("Plant", function(_, profile, slot, plantId)
	if not validSlot(profile, slot) or type(plantId) ~= "string" or #plantId > 32 then
		return { ok = false, error = "bad_args" }
	end
	local err = GardenService.plant(profile, slot, plantId)
	return { ok = err == nil, error = err }
end)

handle("Harvest", function(_, profile, slot)
	if not validSlot(profile, slot) then
		return { ok = false, error = "bad_args" }
	end
	local value, err = GardenService.harvest(profile, slot)
	return { ok = value ~= nil, error = err, coins = value }
end)

handle("Upgrade", function(_, profile, slot)
	if not validSlot(profile, slot) then
		return { ok = false, error = "bad_args" }
	end
	local err = GardenService.upgrade(profile, slot)
	return { ok = err == nil, error = err }
end)

handle("Remove", function(_, profile, slot)
	if not validSlot(profile, slot) then
		return { ok = false, error = "bad_args" }
	end
	local err = GardenService.remove(profile, slot)
	return { ok = err == nil, error = err }
end)

-- Начальный снимок по запросу клиента: событие могло прийти раньше, чем клиент подписался.
Remotes.fn("GetState").OnServerInvoke = function(player: Player)
	if not RateLimit.allow(player, "GetState", 1) then
		return nil
	end
	return DataService.wait(player)
end

DataService.loaded:Connect(function(player: Player)
	pushState(player)
end)
DataService.start()

-- Созревание и мутации по серверному времени, раз в секунду.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if profile and GardenService.tick(profile, now) then
				pushState(player)
			end
		end
	end
end)

print("[Garden] server started")
