--!strict
-- Редкости деревьев. Шанс конкретного вида задаётся его n (Config.Trees),
-- редкость — группа, градиент в интерфейсе (color → color2) и сила анимации выпадения.
-- reveal: quick (короткая карточка), stars (звёзды сходятся), cinematic (затемнение,
-- вспышка, лучи), epic (катсцена с полосами кадра). announce — сообщить всему серверу.

export type Rarity = {
	id: string,
	name: string,
	order: number,
	color: Color3,
	color2: Color3,
	reveal: string,
	announce: boolean,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Rarities: { Rarity } = {
	{
		id = "common",
		name = "Common",
		order = 1,
		color = rgb(176, 184, 196),
		color2 = rgb(226, 230, 236),
		reveal = "quick",
		announce = false,
	},
	{
		id = "uncommon",
		name = "Uncommon",
		order = 2,
		color = rgb(96, 204, 150),
		color2 = rgb(170, 236, 196),
		reveal = "quick",
		announce = false,
	},
	{
		id = "rare",
		name = "Rare",
		order = 3,
		color = rgb(70, 140, 255),
		color2 = rgb(126, 214, 255),
		reveal = "stars",
		announce = false,
	},
	{
		id = "epic",
		name = "Epic",
		order = 4,
		color = rgb(170, 92, 255),
		color2 = rgb(255, 120, 206),
		reveal = "cinematic",
		announce = false,
	},
	{
		id = "legendary",
		name = "Legendary",
		order = 5,
		color = rgb(255, 170, 60),
		color2 = rgb(255, 228, 140),
		reveal = "cinematic",
		announce = true,
	},
	{
		id = "mythic",
		name = "Mythic",
		order = 6,
		color = rgb(255, 64, 110),
		color2 = rgb(255, 160, 84),
		reveal = "epic",
		announce = true,
	},
	{
		id = "divine",
		name = "Divine",
		order = 7,
		color = rgb(120, 255, 236),
		color2 = rgb(255, 196, 255),
		reveal = "epic",
		announce = true,
	},
	-- Эксклюзивные деревья за Robux: в крутилке не выпадают.
	{
		id = "exclusive",
		name = "Exclusive",
		order = 8,
		color = rgb(255, 120, 240),
		color2 = rgb(120, 230, 255),
		reveal = "epic",
		announce = false,
	},
}

return Rarities
