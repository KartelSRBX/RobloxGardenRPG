--!strict
-- Единая точка баланса: числа меняем здесь, не в логике.
return {
	Rarities = require(script.Rarities),
	Trees = require(script.Trees),
	PremiumTrees = require(script.PremiumTrees),
	Auras = require(script.Auras),
	IconAssets = require(script.IconAssets),
	Dungeon = require(script.Dungeon),
	-- Доход и рост дерева из его n: монет/мин = incomeBase * n^incomeExp,
	-- время урожая = growBase * n^growExp секунд. Плоды продаются автоматически при сборе.
	Economy = {
		incomeBase = 30, -- крупные числа приятнее: всё в монетах ×10 к черновику
		incomeExp = 0.5,
		growBase = 25,
		growExp = 0.25,
		seedCap = 50, -- ростков одного вида в запасе, лишние уходят в компост
		compostSeconds = 15, -- компост = столько секунд дохода этого дерева
	},
	-- Прокачка дерева за монеты: +yieldPerLevel дохода за уровень,
	-- цена уровня n = firstCostMinutes минут дохода * costGrowth^(n-1).
	Upgrade = {
		maxLevel = 100,
		yieldPerLevel = 0.2,
		firstCostMinutes = 4,
		costGrowth = 1.15,
		levelsPerStage = 20, -- каждые 20 уровней дерево заметно растёт
	},
	-- Бесплатная крутилка. Шанс вида: от редкого к частому min(1, удача / n).
	Roll = {
		cooldown = 3,
		autoUnlockRolls = 250,
		luckyEvery = 10,
		luckyMult = 2,
		indexLuck = 0.01, -- +1% удачи за открытый вид
		-- бонус удачи за число круток: { крутки, +удача }
		milestones = {
			{ 100, 0.05 },
			{ 500, 0.1 },
			{ 1000, 0.1 },
			{ 2500, 0.15 },
			{ 5000, 0.2 },
			{ 10000, 0.25 },
			{ 25000, 0.3 },
			{ 50000, 0.4 },
			{ 100000, 0.5 },
			{ 250000, 0.75 },
			{ 500000, 1 },
			{ 1000000, 1.5 },
		},
		-- улучшения крутилки за монеты
		luckStep = 0.1,
		luckCostBase = 2000,
		luckCostGrowth = 1.5,
		luckMaxLevel = 60,
		speedStep = 0.1,
		speedCostBase = 1500,
		speedCostGrowth = 1.9,
		minCooldown = 1.5,
	},
	-- Остров: { грядок, минут в игре, монет, ростков } для каждого уровня.
	Island = {
		{ plots = 3, minutes = 0, coins = 0, seeds = 0 },
		{ plots = 4, minutes = 3, coins = 500, seeds = 8 },
		{ plots = 5, minutes = 10, coins = 3000, seeds = 20 },
		{ plots = 6, minutes = 30, coins = 20000, seeds = 50 },
		{ plots = 7, minutes = 90, coins = 120000, seeds = 120 },
		{ plots = 8, minutes = 240, coins = 600000, seeds = 300 },
		{ plots = 9, minutes = 600, coins = 3000000, seeds = 700 },
		{ plots = 10, minutes = 1200, coins = 15000000, seeds = 1500 },
		{ plots = 11, minutes = 2400, coins = 75000000, seeds = 3000 },
		{ plots = 12, minutes = 6000, coins = 400000000, seeds = 6000 },
	},
	-- chance в процентах; остаток до 100 = без мутации.
	Mutations = {
		{
			id = "big",
			name = "Giant",
			chance = 10,
			priceMult = 1.5,
			color = Color3.fromRGB(120, 220, 120),
		},
		{
			id = "golden",
			name = "Golden",
			chance = 3,
			priceMult = 2,
			color = Color3.fromRGB(255, 205, 50),
		},
		{
			id = "rainbow",
			name = "Rainbow",
			chance = 0.5,
			priceMult = 5,
			color = Color3.fromRGB(255, 120, 230),
		},
	},
	StartingCoins = 0,
	-- Добыча из подземелья: продаётся в инвентаре за монеты.
	-- drops: враг -> { предмет, шанс в процентах }.
	Items = {
		slimegel = { name = "Slime Gel", value = 60, color = Color3.fromRGB(110, 230, 140) },
		bone = { name = "Ancient Bone", value = 150, color = Color3.fromRGB(230, 222, 200) },
		soulgem = { name = "Soul Gem", value = 800, color = Color3.fromRGB(170, 110, 255) },
		crown = { name = "Shadow Crown", value = 2500, color = Color3.fromRGB(255, 196, 70) },
	},
	Drops = {
		slime = { { "slimegel", 45 } },
		skeleton = { { "bone", 40 }, { "soulgem", 3 } },
		boss = { { "crown", 100 }, { "soulgem", 30 } },
	},
	-- Компост ростков из инвентаря: столько секунд дохода этого дерева за штуку.
	SellSeedSeconds = 20,
	StartingSeeds = { oak = 1 }, -- для туториала: первая посадка до первой крутки
	Fertilizer = {
		cut = 0.5, -- срезает 50% полного времени роста текущего урожая
	},
	-- Раскладка грядок на острове: 4 колонки, ряды от центра (studs).
	PlotLayout = {
		columns = 4,
		spacing = 13,
		size = 9,
	},
	-- Предсказуемые покупки за Robux (геймпассы): цена видна, результат известен заранее.
	-- id = 0 — пропуск ещё не создан на сайте: в магазине «Soon», в Studio можно
	-- выдать себе для проверки. price — рекомендованная цена для страницы пропуска.
	-- Никаких бонусов к шансам и рандома за Robux (правила платформы).
	GamePasses = {
		{ key = "tree_aurora", id = 0, kind = "tree", treeId = "aurora", price = 399 },
		{ key = "tree_chrono", id = 0, kind = "tree", treeId = "chrono", price = 299 },
		{ key = "tree_hoard", id = 0, kind = "tree", treeId = "hoard", price = 499 },
		{ key = "tree_nebula", id = 0, kind = "tree", treeId = "nebula", price = 449 },
		{ key = "tree_kitsune", id = 0, kind = "tree", treeId = "kitsune", price = 349 },
		{
			key = "coins2x",
			id = 0,
			kind = "boost",
			name = "2x Coins",
			desc = "Double coins from every harvest",
			price = 249,
		},
		{
			key = "autoHarvest",
			id = 0,
			kind = "boost",
			name = "Auto Harvest",
			desc = "Ripe trees harvest themselves while you are in the game",
			price = 199,
		},
		{
			key = "plots2",
			id = 0,
			kind = "island",
			name = "Bigger Island",
			desc = "+2 plots on your island, forever",
			price = 299,
		},
	},
	-- Сколько грядок даёт пропуск Bigger Island.
	BonusPlots = 2,
	Data = {
		storeName = "PlayerData_v1",
		autosaveInterval = 60, -- секунды
		lockTimeout = 180, -- чужой замок старше этого считается брошенным
		loadRetries = 5,
	},
	-- Минимальный интервал между запросами одного игрока, секунды.
	RateLimit = {
		roll = 0.25, -- реальный откат — Roll.cooldown, проверяется отдельно
		autoroll = 0.5,
		buyluck = 0.2,
		buyspeed = 0.2,
		expand = 0.5,
		gohub = 1,
		plant = 0.2,
		harvest = 0.2,
		upgrade = 0.2,
		remove = 0.5,
		fertilize = 0.2,
		gohome = 1,
		dungeonenter = 1,
		dungeonattack = 0.1, -- реальная перезарядка атаки — Dungeon.player.attackCooldown
		dungeonrevive = 0.5,
		dungeonleave = 0.5,
		equipaura = 0.5,
		sellitem = 0.2,
		sellseed = 0.2,
		testgrant = 1,
	},
}
