--!strict
-- Редкости деревьев. Шанс конкретного вида задаётся его n (Config.Trees),
-- редкость — только группа и цвет в интерфейсе.

export type Rarity = {
	id: string,
	name: string,
	order: number,
	color: Color3,
}

local Rarities: { Rarity } = {
	{ id = "common", name = "Common", order = 1, color = Color3.fromRGB(176, 182, 190) },
	{ id = "uncommon", name = "Uncommon", order = 2, color = Color3.fromRGB(110, 200, 120) },
	{ id = "rare", name = "Rare", order = 3, color = Color3.fromRGB(90, 150, 240) },
	{ id = "epic", name = "Epic", order = 4, color = Color3.fromRGB(176, 110, 240) },
	{ id = "legendary", name = "Legendary", order = 5, color = Color3.fromRGB(250, 190, 60) },
	{ id = "mythic", name = "Mythic", order = 6, color = Color3.fromRGB(240, 80, 110) },
	{ id = "divine", name = "Divine", order = 7, color = Color3.fromRGB(120, 240, 230) },
}

return Rarities
