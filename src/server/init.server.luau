--!strict
-- Точка входа сервера: запускает сервисы и обрабатывает запросы клиента.
-- Каждый запрос проверяется: загружен ли профиль, частота, типы и диапазоны.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.DataService)
local DungeonService = require(script.DungeonService)
local GardenService = require(script.GardenService)
local GardenWorld = require(script.GardenWorld)
local RateLimit = require(script.RateLimit)
local ShopService = require(script.ShopService)
local SpinService = require(script.SpinService)

type Profile = DataService.Profile
type Result = { ok: boolean, error: string?, [string]: any }

local stateEvent = Remotes.event("State")
local dungeonEvent = Remotes.event("Dungeon")
local fxEvent = Remotes.event("Fx")

-- Снимок профиля клиенту + перерисовка сада в мире.
local function pushState(player: Player)
	local profile = DataService.get(player)
	if profile then
		stateEvent:FireClient(player, profile, { passes = ShopService.ownedList(player) })
		GardenWorld.render(player, profile)
	end
end

local function validSlot(profile: Profile, slot: any): boolean
	return type(slot) == "number"
		and slot == math.floor(slot)
		and slot >= 1
		and slot <= #profile.plots
end

-- Общая обёртка: профиль, частота, затем действие; после успеха шлёт новое состояние.
local function handle(name: string, action: (Player, Profile, ...any) -> Result)
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

local function slotAction(fn: (Profile, number) -> string?)
	return function(_: Player, profile: Profile, slot: any): Result
		if not validSlot(profile, slot) then
			return { ok = false, error = "bad_args" }
		end
		local err = fn(profile, slot)
		return { ok = err == nil, error = err }
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

local function harvest(player: Player, profile: Profile, slot: number): Result
	local value, err = GardenService.harvest(profile, slot, ShopService.coinMult(player))
	if value then
		fxEvent:FireClient(
			player,
			{ kind = "coins", amount = value, pos = GardenWorld.plotPosition(player, slot) }
		)
	end
	return { ok = value ~= nil, error = err, coins = value }
end

handle("Harvest", function(player, profile, slot)
	if not validSlot(profile, slot) then
		return { ok = false, error = "bad_args" }
	end
	return harvest(player, profile, slot)
end)

handle("Upgrade", slotAction(GardenService.upgrade))
handle("Remove", slotAction(GardenService.remove))
handle("Fertilize", slotAction(GardenService.fertilize))

handle("BuyPlot", function(_, profile)
	local err = GardenService.buyPlot(profile)
	return { ok = err == nil, error = err }
end)

handle("GoHome", function(player)
	if DungeonService.isInRun(player) then
		return { ok = false, error = "in_run" }
	end
	GardenWorld.sendHome(player)
	return { ok = true }
end)

handle("DungeonEnter", function(player, profile)
	local err = DungeonService.enter(player, profile)
	return { ok = err == nil, error = err }
end)

-- Бой не меняет профиль, поэтому снимок не шлём (состояние забега идёт событием Dungeon).
Remotes.fn("DungeonAttack").OnServerInvoke = function(player: Player): Result
	if not RateLimit.allow(player, "DungeonAttack", Config.RateLimit.dungeonattack) then
		return { ok = false, error = "too_fast" }
	end
	local err = DungeonService.attack(player)
	return { ok = err == nil, error = err }
end

handle("DungeonRevive", function(player)
	local err = DungeonService.revive(player)
	return { ok = err == nil, error = err }
end)

handle("DungeonLeave", function(player)
	local err = DungeonService.leave(player)
	return { ok = err == nil, error = err }
end)

-- Начальный снимок по запросу клиента: событие могло прийти раньше, чем клиент подписался.
Remotes.fn("GetState").OnServerInvoke = function(player: Player)
	if not RateLimit.allow(player, "GetState", 1) then
		return nil
	end
	local profile = DataService.wait(player)
	return profile, { passes = ShopService.ownedList(player) }
end

DungeonService.send = function(player, payload)
	dungeonEvent:FireClient(player, payload)
end
DungeonService.fx = function(player, payload)
	fxEvent:FireClient(player, payload)
end
DungeonService.onEnd = function(player)
	pushState(player)
	task.delay(0.2, GardenWorld.sendHome, player)
end

-- Участок игрока и появление в своём саду.
local function onLoaded(player: Player)
	if not DataService.get(player) then
		return
	end
	GardenWorld.assign(player)
	pushState(player)
	GardenWorld.sendHome(player)
end

local function watchCharacter(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if DataService.get(player) and not DungeonService.isInRun(player) then
			GardenWorld.sendHome(player)
		end
	end)
end
Players.PlayerAdded:Connect(watchCharacter)
for _, p in Players:GetPlayers() do
	watchCharacter(p)
end

DataService.loaded:Connect(onLoaded)
ShopService.changed:Connect(pushState)
ShopService.start()
DungeonService.start()
DataService.start()

-- Созревание, мутации и авто-сбор (геймпасс) по серверному времени, раз в секунду.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if not profile then
				continue
			end
			local changed = GardenService.tick(profile, now)
			if ShopService.owns(player, "autoHarvest") then
				for slot, plot in profile.plots do
					if plot.mutationRolled then
						harvest(player, profile, slot)
						changed = true
					end
				end
			end
			if changed then
				pushState(player)
			end
		end
	end
end)

print("[Garden] server started")
