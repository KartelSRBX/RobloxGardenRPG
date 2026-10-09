--!strict
-- Сияние каждого вида: своя гамма из трёх цветов и стиль частиц.
-- Используется в анимации выпадения, карточках инвентаря и как косметическая аура
-- персонажа (выбирается в меню персонажа из открытых видов, на игру не влияет).
-- particles: motes (парящие точки), petals (падающие лепестки), embers (искры вверх),
-- sparkle (мерцание), frost (кристаллы), void (тёмный вихрь), stars (звёзды).
-- ring — орбита воксельных кубиков вокруг персонажа, rays — лучи, light — свечение.

export type Aura = {
	palette: { Color3 },
	particles: string,
	ring: boolean?,
	rays: boolean?,
	light: boolean?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Auras: { [string]: Aura } = {
	-- Common: мягкие природные тона
	oak = {
		palette = { rgb(110, 140, 86), rgb(186, 160, 108), rgb(236, 226, 196) },
		particles = "motes",
	},
	birch = {
		palette = { rgb(214, 220, 226), rgb(176, 198, 162), rgb(196, 222, 238) },
		particles = "motes",
	},
	apple = {
		palette = { rgb(232, 112, 112), rgb(140, 190, 110), rgb(250, 236, 214) },
		particles = "motes",
	},
	pine = {
		palette = { rgb(52, 104, 86), rgb(126, 196, 186), rgb(236, 244, 246) },
		particles = "frost",
	},
	maple = {
		palette = { rgb(232, 150, 64), rgb(196, 64, 52), rgb(246, 206, 120) },
		particles = "petals",
	},
	willow = {
		palette = { rgb(150, 186, 140), rgb(196, 220, 212), rgb(186, 176, 220) },
		particles = "motes",
	},
	-- Uncommon
	cherry = {
		palette = { rgb(150, 32, 60), rgb(236, 120, 150), rgb(255, 236, 242) },
		particles = "petals",
	},
	pear = {
		palette = { rgb(196, 214, 120), rgb(236, 206, 120), rgb(180, 232, 200) },
		particles = "motes",
	},
	lemon = {
		palette = { rgb(250, 224, 90), rgb(176, 226, 96), rgb(255, 250, 220) },
		particles = "sparkle",
	},
	plum = {
		palette = { rgb(110, 52, 120), rgb(210, 130, 180), rgb(196, 176, 240) },
		particles = "motes",
	},
	olive = {
		palette = { rgb(150, 156, 96), rgb(200, 208, 184), rgb(204, 160, 120) },
		particles = "motes",
	},
	peach = {
		palette = { rgb(252, 170, 130), rgb(250, 204, 150), rgb(240, 140, 150) },
		particles = "petals",
	},
	-- Rare
	orange = {
		palette = { rgb(255, 140, 40), rgb(240, 90, 80), rgb(255, 210, 110) },
		particles = "embers",
	},
	fig = {
		palette = { rgb(120, 70, 110), rgb(220, 150, 130), rgb(240, 220, 200) },
		particles = "motes",
	},
	mango = {
		palette = { rgb(255, 180, 60), rgb(250, 120, 100), rgb(120, 200, 120) },
		particles = "sparkle",
	},
	palm = {
		palette = { rgb(60, 200, 200), rgb(240, 220, 160), rgb(250, 140, 120) },
		particles = "motes",
	},
	pomegranate = {
		palette = { rgb(180, 30, 60), rgb(230, 70, 90), rgb(240, 190, 110) },
		particles = "sparkle",
	},
	cacao = {
		palette = { rgb(130, 84, 60), rgb(210, 150, 90), rgb(245, 225, 195) },
		particles = "motes",
	},
	-- Epic: появляется свечение
	sakura = {
		palette = { rgb(255, 183, 213), rgb(240, 140, 190), rgb(255, 245, 250) },
		particles = "petals",
		light = true,
	},
	ginkgo = {
		palette = { rgb(240, 200, 70), rgb(230, 150, 50), rgb(255, 240, 170) },
		particles = "petals",
		light = true,
	},
	baobab = {
		palette = { rgb(230, 170, 100), rgb(150, 100, 170), rgb(240, 130, 80) },
		particles = "motes",
		rays = true,
		light = true,
	},
	bluespruce = {
		palette = { rgb(120, 180, 220), rgb(80, 120, 170), rgb(220, 240, 255) },
		particles = "frost",
		light = true,
	},
	jacaranda = {
		palette = { rgb(150, 110, 220), rgb(170, 170, 255), rgb(220, 140, 230) },
		particles = "petals",
		light = true,
	},
	-- Legendary: орбита кубиков
	dragonblood = {
		palette = { rgb(190, 24, 48), rgb(50, 20, 34), rgb(255, 170, 60) },
		particles = "embers",
		ring = true,
		light = true,
	},
	rainboweuc = {
		palette = { rgb(255, 100, 110), rgb(90, 200, 255), rgb(170, 255, 120) },
		particles = "sparkle",
		ring = true,
		light = true,
	},
	goldenapple = {
		palette = { rgb(255, 210, 80), rgb(255, 240, 200), rgb(240, 170, 140) },
		particles = "sparkle",
		ring = true,
		rays = true,
		light = true,
	},
	crystalbirch = {
		palette = { rgb(180, 240, 255), rgb(120, 220, 240), rgb(190, 170, 255) },
		particles = "frost",
		ring = true,
		light = true,
	},
	-- Mythic: орбита, лучи, свет
	moonwillow = {
		palette = { rgb(200, 210, 255), rgb(70, 70, 150), rgb(230, 230, 245) },
		particles = "stars",
		ring = true,
		rays = true,
		light = true,
	},
	phoenix = {
		palette = { rgb(255, 120, 30), rgb(220, 40, 40), rgb(255, 230, 120) },
		particles = "embers",
		ring = true,
		rays = true,
		light = true,
	},
	worldtree = {
		palette = { rgb(60, 200, 120), rgb(80, 220, 210), rgb(255, 240, 170) },
		particles = "motes",
		ring = true,
		rays = true,
		light = true,
	},
	yggdrasil = {
		palette = { rgb(90, 220, 200), rgb(230, 250, 255), rgb(80, 60, 170) },
		particles = "stars",
		ring = true,
		rays = true,
		light = true,
	},
	-- Divine
	starfruit = {
		palette = { rgb(255, 240, 150), rgb(140, 90, 220), rgb(70, 90, 200) },
		particles = "stars",
		ring = true,
		rays = true,
		light = true,
	},
	celestial = {
		palette = { rgb(255, 200, 230), rgb(180, 240, 255), rgb(255, 230, 170) },
		particles = "petals",
		ring = true,
		rays = true,
		light = true,
	},
	voidoak = {
		palette = { rgb(150, 60, 255), rgb(40, 10, 70), rgb(220, 160, 255) },
		particles = "void",
		ring = true,
		rays = true,
		light = true,
	},
	genesis = {
		palette = { rgb(255, 255, 255), rgb(255, 200, 240), rgb(200, 240, 255) },
		particles = "stars",
		ring = true,
		rays = true,
		light = true,
	},
	-- Exclusive (за Robux)
	aurora = {
		palette = { rgb(140, 240, 255), rgb(190, 140, 255), rgb(255, 160, 230) },
		particles = "frost",
		ring = true,
		rays = true,
		light = true,
	},
	chrono = {
		palette = { rgb(255, 214, 120), rgb(200, 120, 50), rgb(255, 245, 200) },
		particles = "sparkle",
		ring = true,
		rays = true,
		light = true,
	},
	hoard = {
		palette = { rgb(255, 200, 60), rgb(255, 60, 80), rgb(80, 220, 140) },
		particles = "embers",
		ring = true,
		rays = true,
		light = true,
	},
	nebula = {
		palette = { rgb(255, 120, 220), rgb(140, 90, 255), rgb(90, 200, 255) },
		particles = "stars",
		ring = true,
		rays = true,
		light = true,
	},
	kitsune = {
		palette = { rgb(255, 196, 228), rgb(140, 210, 255), rgb(255, 255, 255) },
		particles = "petals",
		ring = true,
		rays = true,
		light = true,
	},
}

return Auras
