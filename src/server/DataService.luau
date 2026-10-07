--!strict
-- Профиль игрока в DataStore: загрузка с замком сессии, автосохранение,
-- сохранение при выходе и при остановке сервера.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)

export type Profile = {
	version: number,
	coins: number,
	seeds: { [string]: number }, -- ростки в запасе
	items: { [string]: number }, -- fertilizer
	plots: { Garden.Plot },
	tutorial: number, -- шаг туториала, Tutorial.DONE = пройден
	stats: { [string]: number }, -- harvests, runs, bestWave, composted
	rolls: number, -- всего круток
	luckLevel: number,
	speedLevel: number,
	found: { [string]: boolean }, -- открытые виды (коллекция)
	playSeconds: number, -- время в игре
	islandTier: number,
	autoRoll: boolean,
}

type Lock = { jobId: string, t: number }
type Record = { data: Profile, lock: Lock? }

local VERSION = 1
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio"

local DataService = {}

local profiles: { [Player]: Profile } = {}
local loadedSignal = Instance.new("BindableEvent")
-- В Studio без доступа к API работаем без сохранений, чтобы плейтест не падал.
local offline = false
local store: DataStore? = nil

local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.Data.storeName)
end)
if not ok then
	warn("[Data] DataStore недоступен:", err)
	offline = true
end

local function emptyPlot(): Garden.Plot
	return { level = 0, plantedAt = 0, mutationRolled = false }
end

local function newProfile(): Profile
	local plots: { Garden.Plot } = {}
	for _ = 1, Garden.islandPlots(1) do
		table.insert(plots, emptyPlot())
	end
	return {
		version = VERSION,
		coins = Config.StartingCoins,
		seeds = table.clone(Config.StartingSeeds),
		items = {},
		plots = plots,
		tutorial = 1,
		stats = {},
		rolls = 0,
		luckLevel = 0,
		speedLevel = 0,
		found = {},
		playSeconds = 0,
		islandTier = 1,
		autoRoll = false,
	}
end

local function field<T>(value: any, kind: string, default: T): T
	return if type(value) == kind then value else default
end

-- Дополняет старый профиль недостающими полями и чинит устаревшие данные.
local function reconcile(data: any): Profile
	local fresh = newProfile()
	if type(data) ~= "table" then
		return fresh
	end
	local p: Profile = {
		version = VERSION,
		coins = field(data.coins, "number", fresh.coins),
		seeds = field(data.seeds, "table", fresh.seeds),
		items = field(data.items, "table", fresh.items),
		plots = field(data.plots, "table", fresh.plots),
		-- Профиль без поля туториала — игрок из ранней версии, туториал ему не нужен.
		tutorial = field(data.tutorial, "number", Tutorial.DONE),
		stats = field(data.stats, "table", fresh.stats),
		rolls = field(data.rolls, "number", 0),
		luckLevel = field(data.luckLevel, "number", 0),
		speedLevel = field(data.speedLevel, "number", 0),
		found = field(data.found, "table", {}),
		playSeconds = field(data.playSeconds, "number", 0),
		islandTier = field(data.islandTier, "number", 0),
		autoRoll = field(data.autoRoll, "boolean", false),
	}
	-- Уровень острова для старых профилей: не меньше, чем уже есть грядок.
	if p.islandTier < 1 then
		p.islandTier = 1
		while Garden.islandPlots(p.islandTier) < #p.plots and p.islandTier < #Config.Island do
			p.islandTier += 1
		end
	end
	p.islandTier = math.clamp(p.islandTier, 1, #Config.Island)
	-- Убрать неизвестные виды (старые версии) и дополнить грядки до размера острова.
	for id in p.seeds do
		if not Garden.tree(id) then
			p.seeds[id] = nil
		end
	end
	for i, plot in p.plots do
		if plot.plantId and not Garden.tree(plot.plantId) then
			p.plots[i] = emptyPlot()
		elseif plot.plantId then
			p.found[plot.plantId] = true
		end
	end
	for id in p.seeds do
		p.found[id] = true
	end
	for i = #p.plots + 1, Garden.islandPlots(p.islandTier) do
		p.plots[i] = emptyPlot()
	end
	-- Уже сажал деревья, но туториал на первом шаге: прошлые версии игры, пропускаем.
	if p.tutorial == Tutorial.PLANT then
		for _, plot in p.plots do
			if plot.plantId then
				p.tutorial = Tutorial.DONE
				break
			end
		end
	end
	return p
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function lockIsForeign(lock: Lock?, now: number): boolean
	return lock ~= nil and lock.jobId ~= JOB_ID and now - lock.t < Config.Data.lockTimeout
end

-- Загружает профиль и ставит замок. Ждёт, пока другой сервер отпустит замок,
-- после lockTimeout забирает его. nil при ошибке DataStore.
local function load(player: Player): Profile?
	if offline or not store then
		return newProfile()
	end
	local ds = store :: DataStore
	for attempt = 1, Config.Data.loadRetries do
		local result: Profile? = nil
		local busy = false
		local success, e = pcall(function()
			ds:UpdateAsync(key(player), function(old: Record?)
				local now = os.time()
				if old and lockIsForeign(old.lock, now) and attempt < Config.Data.loadRetries then
					busy = true
					return nil
				end
				local data = reconcile(old and old.data)
				result = data
				return { data = data, lock = { jobId = JOB_ID, t = now } }
			end)
		end)
		if success and result then
			return result
		end
		if not success then
			warn("[Data] загрузка не удалась:", player.Name, e)
		elseif busy then
			warn(
				"[Data] профиль занят другим сервером, ждём:",
				player.Name
			)
		end
		task.wait(2 ^ attempt)
		if not player.Parent then
			return nil
		end
	end
	return nil
end

local function save(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or offline or not store then
		return
	end
	local ds = store :: DataStore
	local success, e = pcall(function()
		ds:UpdateAsync(key(player), function(old: Record?)
			local now = os.time()
			-- Замок забрал другой сервер: не перетираем его данные.
			if old and lockIsForeign(old.lock, now) then
				return nil
			end
			return {
				data = profile,
				lock = if release then nil else { jobId = JOB_ID, t = now },
			}
		end)
	end)
	if not success then
		warn("[Data] сохранение не удалось:", player.Name, e)
	end
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

-- Профиль игрока; ждёт загрузки, nil если игрок ушёл.
function DataService.wait(player: Player): Profile?
	while player.Parent and not profiles[player] do
		loadedSignal.Event:Wait()
	end
	return profiles[player]
end

DataService.loaded = loadedSignal.Event

local function onPlayerAdded(player: Player)
	local profile = load(player)
	if not player.Parent then
		return
	end
	if not profile then
		player:Kick("Could not load your garden. Please rejoin.")
		return
	end
	profiles[player] = profile
	loadedSignal:Fire(player)
end

-- Колбэки перед финальным сохранением при выходе (например, закрыть забег).
local releaseHooks: { (Player, Profile) -> () } = {}
function DataService.onRelease(fn: (Player, Profile) -> ())
	table.insert(releaseHooks, fn)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		for _, fn in releaseHooks do
			local hookOk, e = pcall(fn, player, profile)
			if not hookOk then
				warn("[Data] onRelease:", e)
			end
		end
		save(player, true)
		profiles[player] = nil
	end
	loadedSignal:Fire(player)
end

function DataService.start()
	if RunService:IsStudio() and not offline then
		-- Проверяем, включён ли доступ Studio к API.
		local probe = pcall(function()
			(store :: DataStore):GetAsync("probe")
		end)
		if not probe then
			warn(
				"[Data] Studio без доступа к API: прогресс не сохраняется"
			)
			offline = true
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.Data.autosaveInterval)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return DataService
