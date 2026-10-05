--!strict
-- Пул растений. ЧЕРНОВЫЕ числа для плейтеста, не финальный баланс.
-- growTime — секунды до созревания, fruits — плодов за урожай, fruitPrice — цена одного плода (монеты),
-- upgradeBase — цена первой прокачки (дальше растёт по Config.Upgrade).

export type Plant = {
	id: string,
	name: string,
	rarity: string,
	growTime: number,
	fruits: number,
	fruitPrice: number,
	upgradeBase: number,
}

local Plants: { Plant } = {
	{ id = "apple", name = "Яблоня", rarity = "common", growTime = 60, fruits = 3, fruitPrice = 5, upgradeBase = 40 },
	{ id = "cherry", name = "Вишня", rarity = "common", growTime = 90, fruits = 3, fruitPrice = 8, upgradeBase = 60 },
	{ id = "pear", name = "Груша", rarity = "uncommon", growTime = 120, fruits = 4, fruitPrice = 12, upgradeBase = 120 },
	{ id = "plum", name = "Слива", rarity = "uncommon", growTime = 180, fruits = 4, fruitPrice = 18, upgradeBase = 180 },
	{ id = "peach", name = "Персик", rarity = "rare", growTime = 300, fruits = 5, fruitPrice = 30, upgradeBase = 400 },
	{ id = "orange", name = "Апельсин", rarity = "rare", growTime = 420, fruits = 5, fruitPrice = 45, upgradeBase = 600 },
	{ id = "mango", name = "Манго", rarity = "epic", growTime = 600, fruits = 6, fruitPrice = 80, upgradeBase = 1500 },
	{ id = "melon", name = "Арбузное дерево", rarity = "epic", growTime = 900, fruits = 6, fruitPrice = 130, upgradeBase = 2500 },
	{ id = "gold_apple", name = "Золотая яблоня", rarity = "legendary", growTime = 1800, fruits = 6, fruitPrice = 400, upgradeBase = 8000 },
	{ id = "crystal_plum", name = "Кристальная слива", rarity = "legendary", growTime = 2700, fruits = 8, fruitPrice = 500, upgradeBase = 12000 },
	{ id = "rainbow", name = "Радужное дерево", rarity = "mythic", growTime = 3600, fruits = 10, fruitPrice = 1500, upgradeBase = 50000 },
	{ id = "moon", name = "Лунное дерево", rarity = "mythic", growTime = 5400, fruits = 10, fruitPrice = 2500, upgradeBase = 90000 },
}

return Plants
