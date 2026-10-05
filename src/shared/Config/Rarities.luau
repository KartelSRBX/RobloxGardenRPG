--!strict
-- Редкости семян и шансы выпадения крутилки. Сумма шансов должна быть 100.
-- Значения — стартовые, настраиваются на плейтестах.

export type Rarity = {
	id: string,
	name: string,
	chance: number, -- в процентах
	order: number,
}

local Rarities: { Rarity } = {
	{ id = "common", name = "Обычная", chance = 60, order = 1 },
	{ id = "uncommon", name = "Необычная", chance = 25, order = 2 },
	{ id = "rare", name = "Редкая", chance = 10, order = 3 },
	{ id = "epic", name = "Эпическая", chance = 4, order = 4 },
	{ id = "legendary", name = "Легендарная", chance = 0.9, order = 5 },
	{ id = "mythic", name = "Мифическая", chance = 0.1, order = 6 },
}

return Rarities
