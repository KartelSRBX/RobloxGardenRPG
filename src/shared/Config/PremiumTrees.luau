--!strict
-- Эксклюзивные деревья за Robux: покупаются напрямую (геймпасс), без рандома.
-- В крутилке и коллекции шансов их нет. Владелец может посадить каждое дерево
-- на одну грядку и пересаживать сколько угодно.
-- income — монет в минуту на 1 уровне (дальше прокачка как у обычных деревьев),
-- grow — секунд до урожая, perk — особое свойство (все свойства детерминированы:
-- никаких бонусов к шансам, это требование правил платформы о платном рандоме).
-- Сила — на уровне легендарок: сильный старт, но мифики из крутилки сильнее.

export type PremiumTree = {
	id: string,
	name: string,
	rarity: string,
	income: number,
	grow: number,
	perk: string,
	perkText: string,
	pass: string, -- ключ из Config.GamePasses
	shape: string,
	leaf: Color3,
	trunk: Color3,
	fruit: Color3?,
	glow: boolean?,
	n: number, -- для сортировок; в крутилке не участвует
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Premium: { PremiumTree } = {
	{
		id = "aurora",
		name = "Aurora Crystal Tree",
		rarity = "exclusive",
		income = 2600,
		grow = 120,
		perk = "neighbors",
		perkText = "+30% coins for every tree next to it",
		pass = "tree_aurora",
		shape = "p_aurora",
		leaf = rgb(140, 240, 255),
		trunk = rgb(190, 160, 255),
		fruit = rgb(220, 255, 255),
		glow = true,
		n = 1e9,
	},
	{
		id = "chrono",
		name = "Chrono Clockwork Tree",
		rarity = "exclusive",
		income = 2000,
		grow = 30,
		perk = "fast",
		perkText = "Ripe every 30 seconds",
		pass = "tree_chrono",
		shape = "p_chrono",
		leaf = rgb(230, 190, 90),
		trunk = rgb(170, 110, 60),
		fruit = rgb(255, 230, 140),
		glow = true,
		n = 1e9,
	},
	{
		id = "hoard",
		name = "Dragon's Hoard Tree",
		rarity = "exclusive",
		income = 3200,
		grow = 300,
		perk = "golden",
		perkText = "Every harvest is Golden: x2 coins",
		pass = "tree_hoard",
		shape = "p_hoard",
		leaf = rgb(255, 200, 60),
		trunk = rgb(120, 24, 30),
		fruit = rgb(255, 60, 80),
		glow = true,
		n = 1e9,
	},
	{
		id = "nebula",
		name = "Starforge Nebula Tree",
		rarity = "exclusive",
		income = 3000,
		grow = 180,
		perk = "auto",
		perkText = "Harvests itself, even while you explore",
		pass = "tree_nebula",
		shape = "p_nebula",
		leaf = rgb(200, 110, 255),
		trunk = rgb(30, 30, 70),
		fruit = rgb(255, 255, 255),
		glow = true,
		n = 1e9,
	},
	{
		id = "kitsune",
		name = "Kitsune Spirit Sakura",
		rarity = "exclusive",
		income = 2300,
		grow = 150,
		perk = "fertilizer",
		perkText = "Every harvest gives 1 Fertilizer",
		pass = "tree_kitsune",
		shape = "p_kitsune",
		leaf = rgb(255, 196, 228),
		trunk = rgb(60, 40, 50),
		fruit = rgb(140, 210, 255),
		glow = true,
		n = 1e9,
	},
}

return Premium
