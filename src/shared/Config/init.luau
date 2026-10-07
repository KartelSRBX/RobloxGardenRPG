--!strict
-- Единая точка баланса: числа меняем здесь, не в логике.
return {
	Rarities = require(script.Rarities),
	Plants = require(script.Plants),
	Dungeon = require(script.Dungeon),
	Upgrade = {
		maxLevel = 10,
		costGrowth = 1.7, -- цена прокачки с уровня n на n+1 = upgradeBase * costGrowth^(n-1)
		priceBonusPerLevel = 0.25, -- +25% к цене плода за уровень
		timeCutPerLevel = 0.03, -- -3% ко времени роста за уровень
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
	SpinCost = 100, -- монеты, заработанные игрой
	StartingCoins = 200,
	StartingSeeds = { apple = 1 }, -- для туториала: первая посадка без крутилки
	StartingPlots = 3,
	MaxPlots = 9,
	-- Цена 4-й, 5-й ... 9-й грядки за монеты.
	PlotPrices = { 500, 1500, 4000, 10000, 25000, 60000 },
	Fertilizer = {
		cut = 0.5, -- срезает 50% полного времени роста текущего урожая
	},
	-- Раскладка грядок на участке: 3x3, ряды от входа вглубь (studs от центра участка).
	PlotLayout = {
		columns = { -14, 0, 14 },
		rows = { -8, 6, 20 },
		size = 10,
	},
	-- Предсказуемые покупки за Robux. id = 0 — пропуск ещё не создан на сайте,
	-- в магазине показывается «скоро». Множитель монет не влияет на шансы.
	GamePasses = {
		{
			key = "coins2x",
			id = 0,
			name = "2x Coins",
			icon = "💰",
			desc = "Double coins from harvests",
		},
		{
			key = "autoHarvest",
			id = 0,
			name = "Auto Harvest",
			icon = "🤖",
			desc = "Ripe trees harvest themselves",
		},
	},
	Data = {
		storeName = "PlayerData_v1",
		autosaveInterval = 60, -- секунды
		lockTimeout = 180, -- чужой замок старше этого считается брошенным
		loadRetries = 5,
	},
	-- Минимальный интервал между запросами одного игрока, секунды.
	RateLimit = {
		spin = 0.5,
		plant = 0.2,
		harvest = 0.2,
		upgrade = 0.2,
		remove = 0.5,
		fertilize = 0.2,
		buyplot = 0.5,
		gohome = 1,
		dungeonenter = 1,
		dungeonattack = 0.1, -- реальная перезарядка атаки — Dungeon.player.attackCooldown
		dungeonrevive = 0.5,
		dungeonleave = 0.5,
	},
}
