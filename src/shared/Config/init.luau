--!strict
-- Единая точка баланса: числа меняем здесь, не в логике.
return {
	Rarities = require(script.Rarities),
	Plants = require(script.Plants),
	Upgrade = {
		maxLevel = 10,
		costGrowth = 1.7, -- цена прокачки уровня n = upgradeBase * costGrowth^(n-1)
		priceBonusPerLevel = 0.25, -- +25% к цене плода за уровень
		timeCutPerLevel = 0.03, -- -3% ко времени роста за уровень
	},
	Mutations = {
		{ id = "big", name = "Гигантская", chance = 10, priceMult = 1.5 },
		{ id = "golden", name = "Золотая", chance = 3, priceMult = 2 },
		{ id = "rainbow", name = "Радужная", chance = 0.5, priceMult = 5 },
	},
	SpinCost = 100, -- монеты, заработанные игрой
	StartingPlots = 3,
	StartingCoins = 200,
}
