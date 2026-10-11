--!strict
-- Звуковой движок клиента: группы громкости (музыка/эффекты/интерфейс), проигрывание
-- с тоном и слоями, 3D-звук в точке мира, амбиент острова и подземелья с плавным переходом.
-- Громкость берётся из настроек профиля (settings.music, settings.sfx).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local State = require(script.Parent.State)

local S = Config.Sounds

local Sfx = {}

-- Группы
local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name) :: SoundGroup?
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = volume
		g.Parent = SoundService
	end
	return g :: SoundGroup
end
local sfxGroup = group("GardenSfx", 1)
local uiGroup = group("GardenUi", 0.7)
local ambientGroup = group("GardenAmbient", 1)

local lastPlayed: { [string]: number } = {}
local rng = Random.new()

-- Применить настройки (0..1) к группам.
function Sfx.applySettings()
	local settings = State.profile and State.profile.settings or {}
	local sfx = if type(settings.sfx) == "number" then settings.sfx else 1
	local music = if type(settings.music) == "number" then settings.music else 1
	sfxGroup.Volume = sfx
	uiGroup.Volume = 0.7 * sfx
	ambientGroup.Volume = music
end

-- Проиграть звук. opts: volume, speed, group, pos (Vector3 для 3D), minGap (антиспам по id).
function Sfx.play(
	id: string,
	opts: {
		volume: number?,
		speed: number?,
		group: SoundGroup?,
		pos: Vector3?,
		minGap: number?,
		stopAfter: number?,
	}?
): Sound?
	local o = opts or {}
	local now = os.clock()
	local gap = o.minGap or 0.03
	if lastPlayed[id] and now - lastPlayed[id] < gap then
		return nil
	end
	lastPlayed[id] = now
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = o.volume or 0.6
	sound.PlaybackSpeed = o.speed or 1
	sound.SoundGroup = o.group or sfxGroup
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 20
	sound.RollOffMaxDistance = 140
	if o.pos then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = o.pos
		holder.Parent = workspace
		sound.Parent = holder
		Debris:AddItem(holder, 8)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 8)
	end
	sound:Play()
	if o.stopAfter then
		task.delay(o.stopAfter, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
			end
		end)
	end
	return sound
end

local function pick(list: { string }): string
	return list[rng:NextInteger(1, #list)]
end

function Sfx.pick(list: { string }): string
	return pick(list)
end

function Sfx.click()
	Sfx.play(S.click, { volume = 0.35, speed = 1.7, group = uiGroup, minGap = 0.05 })
end

function Sfx.toggle(on: boolean)
	Sfx.play(
		S.click,
		{ volume = 0.35, speed = if on then 2.1 else 1.3, group = uiGroup, minGap = 0.05 }
	)
end

function Sfx.coins()
	Sfx.play(pick(S.coins), { volume = 0.5, speed = rng:NextNumber(0.95, 1.1) })
end

function Sfx.loot()
	Sfx.play(pick(S.loot), { volume = 0.5, speed = rng:NextNumber(1.2, 1.5) })
end

function Sfx.door()
	Sfx.play(S.door, { volume = 0.5, speed = 0.9 })
end

-- Пентатоника: полутонов от тоники.
local PENTA = { 0, 2, 4, 7, 9 }

local rarityOrderIndex: { [string]: number } = {}
for i, r in Config.Rarities do
	rarityOrderIndex[r.id] = i
end

-- Подпись вида: уникальная мелодия из трёх нот. Номер вида даёт пару разрядов в 5-ричной
-- системе, так что у любых двух видов (до 125) мелодии различаются.
local signatureIndex: { [string]: number } = {}
do
	local i = 0
	for _, t in Config.Trees do
		signatureIndex[t.id] = i
		i += 1
	end
	for _, t in Config.PremiumTrees do
		signatureIndex[t.id] = i
		i += 1
	end
end

-- Ноты вида (в полутонах относительно базового тона редкости).
function Sfx.melody(treeId: string): { number }
	local i = signatureIndex[treeId] or 0
	local n1 = PENTA[i % 5 + 1]
	local n2 = PENTA[(i // 5) % 5 + 1]
	local n3 = PENTA[(i // 25) % 5 + 1] + 12 * ((i // 5) % 2)
	return { n1, n2 + 5, n3 + 12 }
end

local function semitones(n: number): number
	return 2 ^ (n / 12)
end

-- Звук выпадения: слои растут с редкостью, а мелодия и тон уникальны для вида.
function Sfx.dropSting(treeId: string, lucky: boolean?, isNew: boolean?)
	local tree = Garden.tree(treeId)
	if not tree then
		return
	end
	local order = rarityOrderIndex[tree.rarity] or 1
	local chime = S.chime[tree.rarity] or S.chime.common
	local melody = Sfx.melody(treeId)
	-- базовый тон растёт с редкостью, каждый вид сдвинут своей первой нотой
	local base = (order - 1) * 1.5 + melody[1] * 0.5
	local vol = math.clamp(0.45 + order * 0.07, 0.45, 1)

	Sfx.play(chime, { volume = vol, speed = semitones(base) })
	-- мелодия поверх (arpeggio)
	if order >= 3 then
		for k, note in melody do
			task.delay(0.13 * k, function()
				Sfx.play(S.chime.common, {
					volume = 0.3 + order * 0.03,
					speed = semitones(note + 7) * 1.5,
					minGap = 0,
					stopAfter = 0.35,
				})
			end)
		end
	end
	-- тяжёлый удар: для эпик и выше свой из четырёх, у каждого вида свой тон
	if order >= 4 then
		local boom = S.boom[(signatureIndex[treeId] or 0) % #S.boom + 1]
		Sfx.play(boom, { volume = 0.55 + order * 0.05, speed = semitones(-6 + melody[2] * 0.6) })
	end
	if order >= 6 then
		Sfx.play(pick(S.riser), { volume = 0.6, speed = semitones(melody[3] * 0.3 - 2) })
		task.delay(0.35, function()
			Sfx.play(S.boom[4], { volume = 0.9, speed = semitones(-9), minGap = 0 })
		end)
	end
	if lucky then
		task.delay(0.2, function()
			Sfx.play(S.chime.legendary, { volume = 0.4, speed = 1.5, minGap = 0 })
		end)
	end
	if isNew then
		task.delay(0.45, function()
			Sfx.play(S.chime.rare, { volume = 0.35, speed = 1.8, minGap = 0 })
		end)
	end
end

-- Старт крутки и щелчки барабана.
function Sfx.rollStart()
	Sfx.play(pick(S.whooshUp), { volume = 0.45, speed = 0.9 })
end

function Sfx.rollTick(progress: number)
	-- тон растёт к финалу, к концу щелчки реже и громче
	Sfx.play(pick(S.tick), {
		volume = 0.22 + progress * 0.22,
		speed = 1.5 + progress * 0.9,
		minGap = 0.02,
	})
end

-- Враги подземелья. event: spawn | hit | die | attack
function Sfx.enemy(kind: string, event: string, pos: Vector3?)
	if kind == "slime" then
		if event == "spawn" then
			Sfx.play(S.slime.move, { volume = 0.45, speed = 1.1, pos = pos })
		elseif event == "hit" then
			Sfx.play(S.slime.hit, { volume = 0.55, speed = rng:NextNumber(1.1, 1.4), pos = pos })
		elseif event == "die" then
			Sfx.play(S.slime.hit, { volume = 0.7, speed = 0.7, pos = pos })
			Sfx.play(S.slime.move, { volume = 0.5, speed = 0.7, pos = pos })
		else
			Sfx.play(S.slime.move, { volume = 0.5, speed = 0.8, pos = pos })
		end
	elseif kind == "skeleton" then
		if event == "spawn" then
			Sfx.play(S.skeleton.rattle, { volume = 0.5, speed = 1.3, pos = pos, stopAfter = 1.6 })
		elseif event == "hit" then
			Sfx.play(
				pick(S.skeleton.crack),
				{ volume = 0.6, speed = rng:NextNumber(0.95, 1.25), pos = pos }
			)
		elseif event == "die" then
			Sfx.play(S.skeleton.crackLong, { volume = 0.75, speed = 0.9, pos = pos })
			Sfx.play(S.skeleton.rattle, { volume = 0.4, speed = 1.6, pos = pos, stopAfter = 1 })
		else
			Sfx.play(S.skeleton.wood, { volume = 0.5, speed = 1.2, pos = pos })
		end
	else -- boss
		if event == "spawn" then
			Sfx.play(S.boom[4], { volume = 1, speed = 0.55 })
			Sfx.play(S.dungeonAmbience[2].id, { volume = 0.7, speed = 0.9, stopAfter = 3 })
		elseif event == "hit" then
			Sfx.play(S.hit.stone[1], { volume = 0.7, speed = 0.7, pos = pos })
		elseif event == "die" then
			Sfx.play(S.boom[3], { volume = 1, speed = 0.6 })
			Sfx.play(S.chime.divine, { volume = 0.7, speed = 1 })
		else
			Sfx.play(S.boom[1], { volume = 0.7, speed = 1.2, pos = pos })
		end
	end
end

function Sfx.playerHurt()
	Sfx.play(S.hit.stone[2], { volume = 0.6, speed = 0.65 })
end

function Sfx.swing(key: string, speed: number?)
	local list = S.swing[key] or S.swing.whoosh
	Sfx.play(
		pick(list),
		{ volume = 0.55, speed = speed or rng:NextNumber(0.95, 1.15), minGap = 0.04 }
	)
end

function Sfx.weaponHit(key: string, pos: Vector3?)
	local list = S.hit[key] or S.hit.metal
	Sfx.play(
		pick(list),
		{ volume = 0.55, speed = rng:NextNumber(0.95, 1.15), pos = pos, minGap = 0.03 }
	)
end

-- Амбиент: слои зациклены, остров и подземелье плавно перетекают друг в друга.
local ambience: { [string]: { Sound } } = {}
local function startAmbience(name: string, layers: { { id: string, volume: number } })
	local list = {}
	for i, layer in layers do
		local sound = Instance.new("Sound")
		sound.Name = `Ambience_{name}_{i}`
		sound.SoundId = layer.id
		sound.Looped = true
		sound.Volume = 0
		sound:SetAttribute("Target", layer.volume)
		sound.SoundGroup = ambientGroup
		sound.Parent = SoundService
		-- слои стартуют с разных мест, чтобы не совпадать по фазе
		sound.TimePosition = 0
		sound:Play()
		table.insert(list, sound)
	end
	ambience[name] = list
end

local current = ""
function Sfx.setAmbience(name: string)
	if name == current then
		return
	end
	current = name
	for key, list in ambience do
		for _, sound in list do
			local target = if key == name then sound:GetAttribute("Target") :: number else 0
			TweenService:Create(sound, TweenInfo.new(2), { Volume = target }):Play()
		end
	end
end

function Sfx.start()
	startAmbience("island", S.islandAmbience)
	startAmbience("dungeon", S.dungeonAmbience)
	Sfx.setAmbience("island")
	State.changed:Connect(Sfx.applySettings)
	State.dungeonChanged:Connect(function()
		Sfx.setAmbience(if State.inRun() then "dungeon" else "island")
	end)
	Sfx.applySettings()
end

return Sfx
