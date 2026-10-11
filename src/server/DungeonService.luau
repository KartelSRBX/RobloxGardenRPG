--!strict
-- Подземелье: соло-забег по волнам на своей копии арены.
-- Весь бой на сервере: враги, урон, добыча. Смерть: часть добычи теряется,
-- остальное в сейфе; один бесплатный реквив за забег; выкупа за Robux нет.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponsConfig = require(ReplicatedStorage.Shared.Config.Weapons)
local DungeonConfig = require(ReplicatedStorage.Shared.Config.Dungeon)
local Garden = require(ReplicatedStorage.Shared.Garden)
local DataService = require(script.Parent.DataService)
local WeaponBuilder = require(script.Parent.WeaponBuilder)
local EnemyBuilder = require(script.Parent.EnemyBuilder)
local Luck = require(ReplicatedStorage.Shared.Luck)
local RollService = require(script.Parent.RollService)

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
	kind: string,
	bestDist: number, -- для защиты от застревания
	stuckSince: number,
}

type Loot = {
	coins: number,
	fertilizer: number,
	seeds: { string },
	drops: { [string]: number },
	weapons: { string },
}

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
	weapon: WeaponsConfig.Weapon,
	tool: Tool?,
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

-- Враги: воксельное тело (EnemyBuilder), Humanoid и полоска здоровья.
local function makeEnemy(kind: string, wave: DungeonConfig.Wave, at: CFrame): Enemy
	local model, root, size = EnemyBuilder.build(kind, at)
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
		kind = kind,
		bestDist = math.huge,
		stuckSince = os.clock(),
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
	DungeonService.fx(run.player, { kind = "wave", enemy = wave.kind, count = wave.count })
	push(run)
end

-- Росток из подземелья: крутка с удачей игрока, умноженной на seedLuckMult.
local function rollSeed(player: Player): string
	local profile = DataService.get(player)
	local luck = if profile then Luck.breakdown(profile).total else 1
	return Luck.roll(luck * D.loot.seedLuckMult, rng)
end

local function rarityOrder(treeId: string): number
	local tree = Garden.tree(treeId)
	return if tree then tree.n else 0
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
		drops = {},
		weapons = {},
	}
	local lost: Loot = {
		coins = loot.coins - kept.coins,
		fertilizer = loot.fertilizer - kept.fertilizer,
		seeds = {},
		drops = {},
		weapons = {},
	}
	-- оружие: в сейф идёт самое редкое
	local weapons = table.clone(loot.weapons)
	table.sort(weapons, function(a, b)
		local wa, wb = WeaponBuilder.byId(a), WeaponBuilder.byId(b)
		return (wa and wa.tier or 0) > (wb and wb.tier or 0)
	end)
	local keepWeapons = math.floor(#weapons * keepRatio + 1e-9)
	for i, id in weapons do
		table.insert(if i <= keepWeapons then kept.weapons else lost.weapons, id)
	end
	for id, count in loot.drops do
		local k = math.floor(count * keepRatio + 1e-9)
		kept.drops[id] = if k > 0 then k else nil
		lost.drops[id] = if count - k > 0 then count - k else nil
	end
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
			profile.found[id] = true
			RollService.giveSeed(profile, id)
		end
		for id, count in kept.drops do
			profile.items[id] = (profile.items[id] or 0) + count
		end
		for _, id in kept.weapons do
			if profile.weapons[id] then
				-- дубликат продаётся сразу
				local w = WeaponBuilder.byId(id)
				profile.coins += if w then w.value else 0
			else
				profile.weapons[id] = true
			end
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
	if run.tool then
		run.tool:Destroy()
		run.tool = nil
	end
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
	local gained: Loot =
		{ coins = wave.coins, fertilizer = 0, seeds = {}, drops = {}, weapons = {} }
	if rng:NextNumber() * 100 < D.loot.fertilizerChance then
		gained.fertilizer = 1
	end
	if rng:NextNumber() * 100 < D.loot.seedChance then
		table.insert(gained.seeds, rollSeed(run.player))
	end
	-- оружие: шанс за волну, босс всегда (тир по шансам волны)
	local isBoss = wave.kind == "boss"
	if isBoss or rng:NextNumber() * 100 < D.loot.weaponChance then
		local odds = D.loot.weaponTierOdds[math.min(run.wave, #D.loot.weaponTierOdds)]
		local pick = rng:NextNumber() * 100
		local acc, tier = 0, 1
		for t, chance in odds do
			acc += chance
			if pick <= acc and chance > 0 then
				tier = t
				break
			end
		end
		local pool = {}
		for _, w in WeaponsConfig do
			if w.tier == tier then
				table.insert(pool, w.id)
			end
		end
		if #pool > 0 then
			local id = pool[rng:NextInteger(1, #pool)]
			table.insert(run.loot.weapons, id)
			gained.weapons = { id }
		end
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

local function hurtPlayer(run: Run, amount: number, enemyKind: string?)
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
	DungeonService.fx(run.player, { kind = "hurt", amount = amount, enemy = enemyKind })
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
		-- застрял: сначала прыжок, потом переносим ближе к игроку
		if dist < e.bestDist - 1 then
			e.bestDist = dist
			e.stuckSince = now
		elseif dist > D.enemy.touchRange + e.root.Size.X and now - e.stuckSince > 2.5 then
			e.humanoid.Jump = true
			if now - e.stuckSince > 5 then
				local a = rng:NextNumber() * math.pi * 2
				local c = run.arena:GetPivot().Position
				local to = root.Position + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
				to = Vector3.new(
					math.clamp(to.X, c.X - 38, c.X + 38),
					to.Y,
					math.clamp(to.Z, c.Z - 38, c.Z + 38)
				)
				e.model:PivotTo(CFrame.new(to.X, root.Position.Y - 2 + e.root.Size.Y / 2, to.Z))
				e.bestDist = math.huge
				e.stuckSince = now
			end
		end
		if
			dist <= D.enemy.touchRange + e.root.Size.X / 2
			and now - e.lastHit >= D.enemy.attackCooldown
		then
			e.lastHit = now
			hurtPlayer(run, e.damage, e.kind)
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
	local weapon = WeaponBuilder.byId(profile.weapon)
		or WeaponBuilder.byId("wood_sword") :: WeaponsConfig.Weapon
	local run: Run = {
		player = player,
		arena = arena,
		slot = slot,
		wave = 1,
		enemies = {},
		loot = { coins = 0, fertilizer = 0, seeds = {}, drops = {}, weapons = {} },
		revivesLeft = D.revives,
		state = "start",
		lastAttack = 0,
		damage = D.player.damage * weapon.damage * (1 + dmgBuff),
		maxHp = D.player.hp + hpBuff,
		conns = {},
		weapon = weapon,
		tool = nil,
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
	-- оружие в руку
	local tool = WeaponBuilder.build(weapon.id)
	if tool then
		tool.Parent = player:FindFirstChildOfClass("Backpack")
		hum:EquipTool(tool)
		run.tool = tool
	end
	push(run, { startIn = 3, weapon = weapon.id })
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
	if now - run.lastAttack < run.weapon.cooldown - 0.05 then
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
		if dist <= run.weapon.range then
			hits += 1
			e.hp -= run.damage
			e.bar.Size = UDim2.fromScale(math.max(0, e.hp / e.maxHp), 1)
			DungeonService.fx(player, {
				kind = "hit",
				pos = e.root.Position,
				amount = math.floor(run.damage),
				enemy = e.kind,
				weapon = run.weapon.id,
			})
			-- отбрасывание
			local away = (e.root.Position - root.Position) * Vector3.new(1, 0, 1)
			if away.Magnitude > 0.1 then
				e.root.AssemblyLinearVelocity = away.Unit * 40 + Vector3.new(0, 15, 0)
			end
			if e.hp <= 0 then
				DungeonService.fx(player, { kind = "kill", pos = e.root.Position, enemy = e.kind })
				-- добыча с врага
				for _, drop in Config.Drops[e.kind] or {} do
					if rng:NextNumber() * 100 < drop[2] then
						run.loot.drops[drop[1]] = (run.loot.drops[drop[1]] or 0) + 1
						DungeonService.fx(
							player,
							{ kind = "drop", pos = e.root.Position, item = drop[1] }
						)
					end
				end
				e.model:Destroy()
				table.remove(run.enemies, i)
			end
		end
	end
	DungeonService.fx(player, { kind = "swing", hits = hits, weapon = run.weapon.id })
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
