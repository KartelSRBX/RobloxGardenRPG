--!strict
-- 5 базовых растений (по одному на редкость). Каждое при прокачке меняет название:
-- уровни 1-2 -> stages[1], 3-4 -> stages[2], 5-6 -> stages[3], 7-8 -> stages[4], 9-10 -> stages[5].
-- ЧЕРНОВЫЕ числа для плейтеста. growTime — секунды, fruits — плодов за урожай,
-- fruitPrice — цена плода на уровне 1 (плоды продаются автоматически при сборе),
-- upgradeBase — цена первой прокачки (дальше по Config.Upgrade).

export type Plant = {
	id: string,
	rarity: string,
	growTime: number,
	fruits: number,
	fruitPrice: number,
	upgradeBase: number,
	stages: { string },
}

local Plants: { Plant } = {
	{
		id = "apple",
		rarity = "common",
		growTime = 60,
		fruits = 3,
		fruitPrice = 5,
		upgradeBase = 40,
		stages = {
			"Яблоня",
			"Яблоня Идуны",
			"Золотая яблоня Гесперид",
			"Древо Авалона",
			"Иггдрасиль",
		},
	},
	{
		id = "cherry",
		rarity = "uncommon",
		growTime = 120,
		fruits = 4,
		fruitPrice = 10,
		upgradeBase = 100,
		stages = {
			"Вишня",
			"Сакура Кодама",
			"Вишня Аматэрасу",
			"Сакура Кицунэ",
			"Древо Фусан",
		},
	},
	{
		id = "pear",
		rarity = "rare",
		growTime = 300,
		fruits = 5,
		fruitPrice = 25,
		upgradeBase = 300,
		stages = {
			"Груша",
			"Эльфийская груша",
			"Груша Алкиноя",
			"Груша Титанов",
			"Древо Мирового Света",
		},
	},
	{
		id = "peach",
		rarity = "epic",
		growTime = 900,
		fruits = 6,
		fruitPrice = 70,
		upgradeBase = 1000,
		stages = {
			"Персик",
			"Персик Сиванму",
			"Персик Бессмертия",
			"Персик Нефритового императора",
			"Древо Пэнлай",
		},
	},
	{
		id = "orange",
		rarity = "legendary",
		growTime = 3600,
		fruits = 8,
		fruitPrice = 200,
		upgradeBase = 5000,
		stages = {
			"Апельсин",
			"Апельсин Саламандры",
			"Огненный апельсин Феникса",
			"Солнечное древо Ра",
			"Древо Гелиоса",
		},
	},
}

return Plants
