--!strict
-- 5 базовых растений (по одному на редкость). Каждое при прокачке меняет название:
-- уровни 1-2 -> stages[1], 3-4 -> stages[2], 5-6 -> stages[3], 7-8 -> stages[4], 9-10 -> stages[5].
-- ЧЕРНОВЫЕ числа для плейтеста. growTime — секунды, fruits — плодов за урожай,
-- fruitPrice — цена плода на уровне 1 (плоды продаются автоматически при сборе),
-- upgradeBase — цена первой прокачки (дальше по Config.Upgrade).
-- Названия на английском (основной язык UI); русские — в «Визуал и экономика растений.md»,
-- пойдут в таблицу локализации. Цвета — для воксельной модели дерева.

export type Plant = {
	id: string,
	rarity: string,
	growTime: number,
	fruits: number,
	fruitPrice: number,
	upgradeBase: number,
	stages: { string },
	icon: string,
	fruitColor: Color3,
	leafColor: Color3,
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
			"Apple Tree",
			"Idun's Apple",
			"Golden Apple of Hesperides",
			"Tree of Avalon",
			"Yggdrasil",
		},
		icon = "🍎",
		fruitColor = Color3.fromRGB(230, 50, 50),
		leafColor = Color3.fromRGB(80, 170, 70),
	},
	{
		id = "cherry",
		rarity = "uncommon",
		growTime = 120,
		fruits = 4,
		fruitPrice = 10,
		upgradeBase = 100,
		stages = {
			"Cherry Tree",
			"Kodama Sakura",
			"Amaterasu Cherry",
			"Kitsune Sakura",
			"Fusang Tree",
		},
		icon = "🍒",
		fruitColor = Color3.fromRGB(180, 20, 50),
		leafColor = Color3.fromRGB(255, 170, 200),
	},
	{
		id = "pear",
		rarity = "rare",
		growTime = 300,
		fruits = 5,
		fruitPrice = 25,
		upgradeBase = 300,
		stages = {
			"Pear Tree",
			"Elven Pear",
			"Pear of Alcinous",
			"Titan Pear",
			"Tree of World Light",
		},
		icon = "🍐",
		fruitColor = Color3.fromRGB(190, 220, 70),
		leafColor = Color3.fromRGB(60, 150, 90),
	},
	{
		id = "peach",
		rarity = "epic",
		growTime = 900,
		fruits = 6,
		fruitPrice = 70,
		upgradeBase = 1000,
		stages = {
			"Peach Tree",
			"Xiwangmu Peach",
			"Peach of Immortality",
			"Jade Emperor's Peach",
			"Penglai Tree",
		},
		icon = "🍑",
		fruitColor = Color3.fromRGB(255, 160, 120),
		leafColor = Color3.fromRGB(110, 180, 80),
	},
	{
		id = "orange",
		rarity = "legendary",
		growTime = 3600,
		fruits = 8,
		fruitPrice = 200,
		upgradeBase = 5000,
		stages = {
			"Orange Tree",
			"Salamander Orange",
			"Phoenix Fire Orange",
			"Sun Tree of Ra",
			"Tree of Helios",
		},
		icon = "🍊",
		fruitColor = Color3.fromRGB(255, 140, 20),
		leafColor = Color3.fromRGB(50, 140, 60),
	},
}

return Plants
