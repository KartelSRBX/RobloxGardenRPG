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
	seeds: { [string]: number },
	items: { [string]: number }, -- fertilizer
	plots: { Garden.Plot },
	tutorial: number, -- шаг туториала, Tutorial.DONE = пройден
	stats: { [string]: number }, -- harvests, runs, bestWave
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

local function newProfile(): Profile
	local plots: { Garden.Plot } = {}
	for _ = 1, Config.StartingPlots do
		table.insert(plots, { level = 0, plantedAt = 0, mutationRolled = false })
	end
	return {
		version = VERSION,
		coins = Config.StartingCoins,
		seeds = table.clone(Config.StartingSeeds),
		items = {},
		plots = plots,
		tutorial = 1,
		stats = {},
	}
end

-- Дополняет старый профиль недостающими полями.
local function reconcile(data: any): Profile
	local fresh = newProfile()
	if type(data) ~= "table" then
		return fresh
	end
	local p: Profile = {
		version = VERSION,
		coins = if type(data.coins) == "number" then data.coins else fresh.coins,
		seeds = if type(data.seeds) == "table" then data.seeds else fresh.seeds,
		items = if type(data.items) == "table" then data.items else fresh.items,
		plots = if type(data.plots) == "table" then data.plots else fresh.plots,
		-- Профиль без поля туториала — игрок из ранней версии, туториал ему не нужен.
		tutorial = if type(data.tutorial) == "number" then data.tutorial else Tutorial.DONE,
		stats = if type(data.stats) == "table" then data.stats else fresh.stats,
	}
	for i = #p.plots + 1, Config.StartingPlots do
		p.plots[i] = fresh.plots[i]
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
