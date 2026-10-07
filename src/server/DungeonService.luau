--!strict
-- Подземелье: соло-забег по волнам на своей копии арены.
-- Весь бой на сервере: враги, урон, добыча. Смерть: часть добычи теряется,
-- остальное в сейфе; один бесплатный реквив за забег; выкупа за Robux нет.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DungeonConfig = require(ReplicatedStorage.Shared.Config.Dungeon)
local Garden = require(ReplicatedStorage.Shared.Garden)
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

type Enemy = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	hp: number,
	maxHp: number,
	damage: number,
	lastHit: number,
	bar: Frame,
}

type Loot = { coins: number, fertilizer: number, seeds: { string } }

type Run = {
	player: Player,
	arena: Model,
	slot: number,
	wave: number,
	enemies: { Enemy },
	loot: Loot,
	revivesLeft: number,
	state: string, -- "start" | "fight" | "pause" | "downed" | "over"
	lastAttack: number,
	damage: number,
	maxHp: number,
	conns: { RBXScriptConnection },
}

local D = Config.Dungeon
local DungeonService = {}

local runs: { [Player]: Run } = {}
local slotsUsed: { [number]: boolean } = {}
local rng = Random.new()

-- Колбэки, которые задаёт init: отправка состояния клиенту и возврат в сад.
DungeonService.send = function(_player: Player, _payload: { [string]: any }) end
DungeonService.fx = function(_player: Player, _payload: { [string]: any }) end
DungeonService.onEnd = function(_player: Player) end

local function rootOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function snapshot(run: Run, extra: { [string]: any }?): { [string]: any }
	local payload: { [string]: any } = {
		active = run.state ~= "over",
		state = run.state,
		wave = run.wave,
		waves = #D.waves,
		enemies = #run.enemies,
		revivesLeft = run.revivesLeft,
		loot = run.loot,
		maxHp = run.maxHp,
	}
	for k, v in extra or {} do
		payload[k] = v
	end
	return payload
end

local function push(run: Run, extra: { [string]: any }?)
	DungeonService.send(run.player, snapshot(run, extra))
end

-- Враги собираются из кубов в воксельном стиле.
local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function cube(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function makeEnemy(kind: string, wave: DungeonConfig.Wave, at: CFrame): Enemy
	local model = Instance.new("Model")
	model.Name = kind
	local size: Vector3
	local color: Color3
	if kind == "boss" then
		size = Vector3.new(9, 8, 9)
		color = Color3.fromRGB(130, 60, 200)
	elseif kind == "skeleton" then
		size = Vector3.new(2.6, 5, 2.2)
		color = Color3.fromRGB(225, 220, 205)
	else
		size = Vector3.new(4, 3.2, 4)
		color = Color3.fromRGB(90, 210, 110)
	end
	local root = cube(model, size, at + Vector3.new(0, size.Y / 2 + 0.1, 0), color)
	root.Name = "HumanoidRootPart"
	root.Massless = false
	root.CanCollide = true
	if kind ~= "skeleton" then
		root.Material = Enum.Material.Glass
		root.Transparency = 0.15
	end
	local face = root.CFrame
	-- глаза
	for _, side in { -1, 1 } do
		local eyeY = if kind == "skeleton" then size.Y * 0.32 else size.Y * 0.12
		local eye = cube(
			model,
			Vector3.new(0.6, 0.8, 0.2) * (if kind == "boss" then 2 else 1),
			face * CFrame.new(side * size.X * 0.2, eyeY, -size.Z / 2 - 0.05),
			if kind == "boss" then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(20, 20, 30),
			if kind == "boss" then Enum.Material.Neon else nil
		)
		weld(root, eye)
	end
	if kind == "boss" then
		for i = -1, 1 do
			local spike = cube(
				model,
				Vector3.new(1.2, 2, 1.2),
				face * CFrame.new(i * 2.6, size.Y / 2 + 1, 0),
				Color3.fromRGB(255, 205, 50),
				Enum.Material.Neon
			)
			weld(root, spike)
		end
	elseif kind == "skeleton" then
		local head =
			cube(model, Vector3.new(2.2, 2, 2.2), face * CFrame.new(0, size.Y / 2 + 1, 0), color)
		weld(root, head)
		for _, side in { -1, 1 } do
			local eye = cube(
				model,
				Vector3.new(0.5, 0.5, 0.1),
				face * CFrame.new(side * 0.5, size.Y / 2 + 1.2, -1.15),
				Color3.fromRGB(255, 80, 60),
				Enum.Material.Neon
			)
			weld(root, eye)
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 0.1
	humanoid.WalkSpeed = wave.speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model.PrimaryPart = root

	-- полоска здоровья
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 10)
	gui.StudsOffsetWorldSpace =
		Vector3.new(0, size.Y / 2 + (if kind == "skeleton" then 3.2 else 1.5), 0)
	gui.AlwaysOnTop = true
	gui.Parent = root
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	bar.BorderSizePixel = 0
	bar.Parent = bg

	return {
		model = model,
		root = root,
		humanoid = humanoid,
		hp = wave.hp,
		maxHp = wave.hp,
		damage = wave.damage,
		lastHit = 0,
		bar = bar,
	}
end

local function spawnWave(run: Run)
	local wave = D.waves[run.wave]
	local spawns = (run.arena:FindFirstChild("EnemySpawns") :: Folder):GetChildren()
	for i = 1, wave.count do
		local sp = spawns[(i - 1) % #spawns + 1] :: BasePart
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local enemy = makeEnemy(wave.kind, wave, CFrame.new(sp.Position + offset))
		enemy.model.Parent = run.arena
		enemy.root:SetNetworkOwner(nil)
		table.insert(run.enemies, enemy)
	end
	run.state = "fight"
	push(run)
end

local function rollSeed(): string
	local total = 0
	for _, o in D.loot.seedOdds do
		total += o.chance
	end
	local pick = rng:NextNumber() * total
	local acc = 0
	for _, o in D.loot.seedOdds do
		acc += o.chance
		if pick <= acc then
			local plant = Garden.plantForRarity(o.rarity)
			if plant then
				return plant.id
			end
		end
	end
	return Config.Plants[1].id
end

local function rarityOrder(plantId: string): number
	local plant = Garden.plant(plantId)
	return if plant then Garden.rarity(plant.rarity).order else 0
end

-- Начисляет сохранённую часть добычи в профиль. Возвращает сохранённое и потерянное.
local function bank(player: Player, loot: Loot, keepRatio: number): (Loot, Loot)
	local seeds = table.clone(loot.seeds)
	-- в сейф сначала попадают самые редкие семена
	table.sort(seeds, function(a, b)
		return rarityOrder(a) > rarityOrder(b)
	end)
	local keepSeeds = math.floor(#seeds * keepRatio + 1e-9)
	local kept: Loot = {
		coins = math.floor(loot.coins * keepRatio),
		fertilizer = math.floor(loot.fertilizer * keepRatio),
		seeds = {},
	}
	local lost: Loot = {
		coins = loot.coins - kept.coins,
		fertilizer = loot.fertilizer - kept.fertilizer,
		seeds = {},
	}
	for i, id in seeds do
		table.insert(if i <= keepSeeds then kept.seeds else lost.seeds, id)
	end
	local profile = DataService.get(player)
	if profile then
		profile.coins += kept.coins
		if kept.fertilizer > 0 then
			profile.items.fertilizer = (profile.items.fertilizer or 0) + kept.fertilizer
		end
		for _, id in kept.seeds do
			profile.seeds[id] = (profile.seeds[id] or 0) + 1
		end
	end
	return kept, lost
end

local function cleanup(run: Run)
	for _, c in run.conns do
		c:Disconnect()
	end
	run.arena:Destroy()
	slotsUsed[run.slot] = nil
	runs[run.player] = nil
	local hum = humanoidOf(run.player)
	if hum then
		hum.MaxHealth = 100
		hum.Health = 100
	end
	local root = rootOf(run.player)
	if root then
		root.Anchored = false
	end
end

-- result: "victory" | "left" | "death"
local function finish(run: Run, result: string)
	if run.state == "over" then
		return
	end
	run.state = "over"
	local keepRatio = if result == "death" then 1 - D.deathLossPercent / 100 else 1
	local kept, lost = bank(run.player, run.loot, keepRatio)
	local profile = DataService.get(run.player)
	if profile then
		profile.stats.runs = (profile.stats.runs or 0) + 1
		local cleared = if result == "victory" then #D.waves else run.wave - 1
		profile.stats.bestWave = math.max(profile.stats.bestWave or 0, cleared)
	end
	push(run, { result = result, kept = kept, lost = lost })
	cleanup(run)
	DungeonService.onEnd(run.player)
end

local function waveCleared(run: Run)
	local wave = D.waves[run.wave]
	local gained: Loot = { coins = wave.coins, fertilizer = 0, seeds = {} }
	if rng:NextNumber() * 100 < D.loot.fertilizerChance then
		gained.fertilizer = 1
	end
	if rng:NextNumber() * 100 < D.loot.seedChance then
		table.insert(gained.seeds, rollSeed())
	end
	run.loot.coins += gained.coins
	run.loot.fertilizer += gained.fertilizer
	for _, id in gained.seeds do
		table.insert(run.loot.seeds, id)
	end
	if run.wave >= #D.waves then
		finish(run, "victory")
		return
	end
	run.state = "pause"
	push(run, { gained = gained, nextIn = D.wavePause })
	task.delay(D.wavePause, function()
		if runs[run.player] == run and run.state == "pause" then
			run.wave += 1
			spawnWave(run)
		end
	end)
end

local function knockBack(run: Run)
	local spawns = (run.arena:FindFirstChild("EnemySpawns") :: Folder):GetChildren()
	for i, e in run.enemies do
		local sp = spawns[(i - 1) % #spawns + 1] :: BasePart
		e.model:PivotTo(CFrame.new(sp.Position + Vector3.new(0, e.root.Size.Y / 2 + 0.1, 0)))
	end
end

local function hurtPlayer(run: Run, amount: number)
	if run.state ~= "fight" then
		return
	end
	local hum = humanoidOf(run.player)
	if not hum then
		return
	end
	if hum.Health - amount <= 1 then
		hum.Health = 1
		run.state = "downed"
		local root = rootOf(run.player)
		if root then
			root.Anchored = true
		end
		for _, e in run.enemies do
			e.humanoid:MoveTo(e.root.Position)
		end
		push(run)
		if run.revivesLeft <= 0 then
			task.delay(1.5, function()
				if runs[run.player] == run and run.state == "downed" then
					finish(run, "death")
				end
			end)
		end
		return
	end
	hum.Health -= amount
	DungeonService.fx(run.player, { kind = "hurt", amount = amount })
end

-- Перемещение и атаки врагов.
local function step(run: Run, now: number)
	if run.state ~= "fight" then
		return
	end
	local root = rootOf(run.player)
	if not root then
		return
	end
	for _, e in run.enemies do
		local dist = (e.root.Position - root.Position).Magnitude
		e.humanoid:MoveTo(root.Position)
		if
			dist <= D.enemy.touchRange + e.root.Size.X / 2
			and now - e.lastHit >= D.enemy.attackCooldown
		then
			e.lastHit = now
			hurtPlayer(run, e.damage)
			if run.state ~= "fight" then
				return
			end
		end
	end
end

function DungeonService.isInRun(player: Player): boolean
	return runs[player] ~= nil
end

function DungeonService.enter(player: Player, profile: Profile): string?
	if runs[player] then
		return "in_run"
	end
	local hum = humanoidOf(player)
	local root = rootOf(player)
	if not hum or not root or hum.Health <= 0 then
		return "no_character"
	end
	local template = ServerStorage:FindFirstChild("DungeonArena") :: Model?
	if not template then
		return "no_arena"
	end
	local slot = 0
	for i = 1, D.maxRuns do
		if not slotsUsed[i] then
			slot = i
			break
		end
	end
	if slot == 0 then
		return "dungeon_full"
	end
	slotsUsed[slot] = true

	local arena = template:Clone()
	arena:PivotTo(CFrame.new(4000 + slot * 250, 400, 0))
	arena.Parent = workspace

	local hpBuff, dmgBuff = Garden.buffs(profile.plots)
	local run: Run = {
		player = player,
		arena = arena,
		slot = slot,
		wave = 1,
		enemies = {},
		loot = { coins = 0, fertilizer = 0, seeds = {} },
		revivesLeft = D.revives,
		state = "start",
		lastAttack = 0,
		damage = D.player.damage * (1 + dmgBuff),
		maxHp = D.player.hp + hpBuff,
		conns = {},
	}
	runs[player] = run
	hum.MaxHealth = run.maxHp
	hum.Health = run.maxHp
	local spawnPart = arena:FindFirstChild("PlayerSpawn") :: BasePart;
	(player.Character :: Model):PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))

	-- Сброс персонажа во время забега = смерть по обычному правилу.
	table.insert(
		run.conns,
		hum.Died:Connect(function()
			if runs[player] == run then
				finish(run, "death")
			end
		end)
	)
	push(run, { startIn = 3 })
	task.delay(3, function()
		if runs[player] == run then
			spawnWave(run)
		end
	end)
	return nil
end

function DungeonService.attack(player: Player): string?
	local run = runs[player]
	if not run or run.state ~= "fight" then
		return "no_fight"
	end
	local now = os.clock()
	if now - run.lastAttack < D.player.attackCooldown then
		return "cooldown"
	end
	run.lastAttack = now
	local root = rootOf(player)
	if not root then
		return "no_character"
	end
	local hits = 0
	for i = #run.enemies, 1, -1 do
		local e = run.enemies[i]
		local dist = (e.root.Position - root.Position).Magnitude - e.root.Size.X / 2
		if dist <= D.player.attackRange then
			hits += 1
			e.hp -= run.damage
			e.bar.Size = UDim2.fromScale(math.max(0, e.hp / e.maxHp), 1)
			DungeonService.fx(
				player,
				{ kind = "hit", pos = e.root.Position, amount = math.floor(run.damage) }
			)
			-- отбрасывание
			local away = (e.root.Position - root.Position) * Vector3.new(1, 0, 1)
			if away.Magnitude > 0.1 then
				e.root.AssemblyLinearVelocity = away.Unit * 40 + Vector3.new(0, 15, 0)
			end
			if e.hp <= 0 then
				DungeonService.fx(player, { kind = "kill", pos = e.root.Position })
				e.model:Destroy()
				table.remove(run.enemies, i)
			end
		end
	end
	DungeonService.fx(player, { kind = "swing", hits = hits })
	if #run.enemies == 0 then
		waveCleared(run)
	else
		push(run)
	end
	return nil
end

function DungeonService.revive(player: Player): string?
	local run = runs[player]
	if not run or run.state ~= "downed" then
		return "not_downed"
	end
	if run.revivesLeft <= 0 then
		return "no_revives"
	end
	run.revivesLeft -= 1
	local hum = humanoidOf(player)
	local root = rootOf(player)
	if hum then
		hum.Health = hum.MaxHealth
	end
	if root then
		root.Anchored = false
	end
	knockBack(run)
	run.state = "fight"
	push(run)
	return nil
end

-- Уйти можно между волнами (с полной добычей) или когда игрок повержен (сдаться).
function DungeonService.leave(player: Player): string?
	local run = runs[player]
	if not run then
		return "no_run"
	end
	if run.state == "pause" or run.state == "start" then
		finish(run, "left")
	elseif run.state == "downed" then
		finish(run, "death")
	else
		return "in_fight"
	end
	return nil
end

function DungeonService.start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, run in runs do
				step(run, now)
			end
		end
	end)
	-- Выход из игры посреди боя = смерть по обычному правилу (часть добычи в сейф).
	DataService.onRelease(function(player)
		local run = runs[player]
		if run then
			local result = if run.state == "pause" or run.state == "start" then "left" else "death"
			finish(run, result)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			cleanup(run)
		end
	end)
end

return DungeonService
