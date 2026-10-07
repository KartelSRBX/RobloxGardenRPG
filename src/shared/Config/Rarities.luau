--!strict
-- Редкость базового растения = его шанс в крутилке. Сумма шансов 100.
-- Мифические названия — это стадии прокачки (см. Plants.luau), а не отдельная редкость семян.

export type Rarity = {
	id: string,
	name: string,
	chance: number, -- в процентах
	order: number,
	color: Color3, -- рамка редкости в UI
}

local Rarities: { Rarity } = {
	{
		id = "common",
		name = "Common",
		chance = 50,
		order = 1,
		color = Color3.fromRGB(150, 150, 160),
	},
	{
		id = "uncommon",
		name = "Uncommon",
		chance = 30,
		order = 2,
		color = Color3.fromRGB(80, 200, 90),
	},
	{
		id = "rare",
		name = "Rare",
		chance = 14,
		order = 3,
		color = Color3.fromRGB(70, 140, 255),
	},
	{
		id = "epic",
		name = "Epic",
		chance = 5,
		order = 4,
		color = Color3.fromRGB(170, 80, 230),
	},
	{
		id = "legendary",
		name = "Legendary",
		chance = 1,
		order = 5,
		color = Color3.fromRGB(255, 190, 40),
	},
}

return Rarities
