--!strict
-- Точка входа сервера: запускает сервисы и обрабатывает запросы клиента.
-- Каждый запрос проверяется: загружен ли профиль, частота, типы и диапазоны.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.DataService)
local DungeonService = require(script.DungeonService)
local GardenService = require(script.GardenService)
local IslandWorld = require(script.IslandWorld)
local RateLimit = require(script.RateLimit)
local InventoryService = require(script.InventoryService)
local RollService = require(script.RollService)
local ShopService = require(script.ShopService)

type Profile = DataService.Profile
type Result = { ok: boolean, error: string?, [string]: any }

local stateEvent = Remotes.event("State")
local dungeonEvent = Remotes.event("Dungeon")
local fxEvent = Remotes.event("Fx")
local rolledEvent = Remotes.event("Rolled")
local announceEvent = Remotes.event("Announce")

-- Редкая находка или первая находка легендарки и выше — сообщаем всему серверу.
local function announce(player: Player, result: any)
	local tree = Garden.tree(result.treeId)
	if not tree then
		return
	end
	local rarity = Garden.rarity(tree.rarity)
	if rarity.announce then
		announceEvent:FireAllClients({ name = player.DisplayName, treeId = result.treeId })
	end
end

-- Снимок профиля клиенту + перерисовка острова.
local function pushState(player: Player)
	local profile = DataService.get(player)
	if profile then
		stateEvent:FireClient(player, profile, { passes = ShopService.ownedList(player) })
		IslandWorld.render(player, profile)
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

local function simple(fn: (Profile) -> string?)
	return function(_: Player, profile: Profile): Result
		local err = fn(profile)
		return { ok = err == nil, error = err }
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

-- Крутилка
handle("Roll", function(player)
	local result, err = RollService.roll(player)
	if result then
		announce(player, result)
	end
	return { ok = result ~= nil, error = err, result = result }
end)

handle("SetAutoRoll", function(_, profile, on)
	if type(on) ~= "boolean" then
		return { ok = false, error = "bad_args" }
	end
	local err = RollService.setAutoRoll(profile, on)
	return { ok = err == nil, error = err }
end)

handle("BuyLuck", simple(RollService.buyLuck))
handle("BuySpeed", simple(RollService.buySpeed))

-- Инвентарь
handle("SellItem", function(_, profile, id, count)
	local value, err = InventoryService.sellItem(profile, id, count)
	return { ok = value ~= nil, error = err, coins = value }
end)

handle("SellSeed", function(_, profile, id, count)
	local value, err = InventoryService.sellSeed(profile, id, count)
	return { ok = value ~= nil, error = err, coins = value }
end)

handle("EquipWeapon", function(player, profile, id)
	if DungeonService.isInRun(player) then
		return { ok = false, error = "in_run" }
	end
	local err = InventoryService.equipWeapon(profile, id)
	return { ok = err == nil, error = err }
end)

handle("SetSetting", function(_, profile, key, value)
	local err = InventoryService.setSetting(profile, key, value)
	return { ok = err == nil, error = err }
end)

handle("EquipAura", function(player, profile, id)
	local err = InventoryService.equipAura(profile, id)
	if not err then
		InventoryService.applyAura(player, profile)
	end
	return { ok = err == nil, error = err }
end)

-- Сад
handle("Plant", function(player, profile, slot, treeId)
	if not validSlot(profile, slot) or type(treeId) ~= "string" or #treeId > 32 then
		return { ok = false, error = "bad_args" }
	end
	local err = GardenService.plant(profile, slot, treeId, ShopService.ownedTrees(player))
	return { ok = err == nil, error = err }
end)

local function harvest(player: Player, profile: Profile, slot: number): Result
	local value, err = GardenService.harvest(profile, slot, ShopService.coinMult(player))
	if value then
		fxEvent:FireClient(
			player,
			{ kind = "coins", amount = value, pos = IslandWorld.plotPosition(player, slot) }
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
handle("Expand", function(player, profile)
	local err = GardenService.expand(profile, ShopService.bonusPlots(player))
	return { ok = err == nil, error = err }
end)

-- Только в Studio: выдать пропуск для проверки (см. ShopService.testGrant).
handle("TestGrant", function(player, _, key)
	local err = ShopService.testGrant(player, key)
	return { ok = err == nil, error = err }
end)

-- Перемещение
handle("GoHome", function(player)
	if DungeonService.isInRun(player) then
		return { ok = false, error = "in_run" }
	end
	IslandWorld.sendHome(player)
	return { ok = true }
end)

handle("GoHub", function(player)
	if DungeonService.isInRun(player) then
		return { ok = false, error = "in_run" }
	end
	IslandWorld.sendHub(player)
	return { ok = true }
end)

-- Подземелье
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
	task.delay(0.2, IslandWorld.sendHome, player)
end

-- Сверка с покупками: бонусные грядки и эксклюзивные деревья только у владельцев
-- (например, после проверки через TEST в Studio дерево не остаётся навсегда).
local function syncPurchases(player: Player)
	local profile = DataService.get(player)
	if not profile or not ShopService.isLoaded(player) then
		return
	end
	GardenService.ensurePlots(profile, ShopService.bonusPlots(player))
	local ownedTrees = ShopService.ownedTrees(player)
	for i, plot in profile.plots do
		if plot.plantId and Garden.isPremium(plot.plantId) and not ownedTrees[plot.plantId] then
			profile.plots[i] = { level = 0, plantedAt = 0, mutationRolled = false }
		end
	end
	if profile.aura and Garden.isPremium(profile.aura) and not ownedTrees[profile.aura] then
		profile.aura = nil
		InventoryService.applyAura(player, profile)
	end
end

-- Свой остров и появление на нём.
local function onLoaded(player: Player)
	if not DataService.get(player) then
		return
	end
	IslandWorld.assign(player)
	syncPurchases(player)
	pushState(player)
	IslandWorld.sendHome(player)
	InventoryService.applyAura(player, DataService.get(player) :: Profile)
end

local function watchCharacter(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		local profile = DataService.get(player)
		if profile then
			InventoryService.applyAura(player, profile)
		end
		if profile and not DungeonService.isInRun(player) then
			IslandWorld.sendHome(player)
		end
	end)
end
Players.PlayerAdded:Connect(watchCharacter)
for _, p in Players:GetPlayers() do
	watchCharacter(p)
end
Players.PlayerRemoving:Connect(RollService.forget)

DataService.loaded:Connect(onLoaded)
-- пропуски загрузились или куплены: добавить бонусные грядки и обновить клиента
ShopService.changed:Connect(function(player)
	syncPurchases(player)
	pushState(player)
end)
ShopService.start()
DungeonService.start()
DataService.start()

-- Раз в секунду: время в игре, созревание и мутации, авто-сбор (геймпасс).
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if not profile then
				continue
			end
			profile.playSeconds += 1
			local changed = GardenService.tick(profile, now)
			local autoAll = ShopService.owns(player, "autoHarvest")
			do
				for slot, plot in profile.plots do
					-- авто-сбор: пропуск Auto Harvest или перк дерева Starforge Nebula
					if plot.mutationRolled and (autoAll or Garden.perk(plot.plantId) == "auto") then
						harvest(player, profile, slot)
						changed = true
					end
				end
			end
			-- время в игре влияет на кнопку расширения: обновляем раз в минуту
			if changed or profile.playSeconds % 60 == 0 then
				pushState(player)
			end
		end
	end
end)

-- Авто-крутка: сервер крутит сам, как только откат готов.
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if profile and profile.autoRoll and not DungeonService.isInRun(player) then
				local result = RollService.roll(player)
				if result then
					announce(player, result)
					rolledEvent:FireClient(player, result)
					pushState(player)
				end
			end
		end
	end
end)

print("[Garden] server started")
