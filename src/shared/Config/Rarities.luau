--!strict
-- Редкость базового растения = его шанс в крутилке. Сумма шансов 100.
-- Мифические названия — это стадии прокачки (см. Plants.luau), а не отдельная редкость семян.

export type Rarity = {
	id: string,
	name: string,
	chance: number, -- в процентах
	order: number,
}

local Rarities: { Rarity } = {
	{ id = "common", name = "Обычная", chance = 50, order = 1 },
	{ id = "uncommon", name = "Необычная", chance = 30, order = 2 },
	{ id = "rare", name = "Редкая", chance = 14, order = 3 },
	{ id = "epic", name = "Эпическая", chance = 5, order = 4 },
	{ id = "legendary", name = "Легендарная", chance = 1, order = 5 },
}

return Rarities
