--!strict
-- Подземелье: соло-забег из волн. ЧЕРНОВЫЕ числа для плейтеста.
-- Смерть: теряется deathLossPercent добычи забега, остальное — в сейфе;
-- revives бесплатных реквивов за забег. Потерянное за Robux не возвращается.

export type Wave = {
	count: number,
	hp: number,
	damage: number,
	speed: number,
	kind: string,
	coins: number, -- монеты за зачистку волны
}

return {
	revives = 1,
	deathLossPercent = 50,
	wavePause = 4, -- секунды между волнами
	maxRuns = 6, -- одновременно забегов на сервер (арен)
	waves = {
		{ count = 3, hp = 40, damage = 6, speed = 9, kind = "slime", coins = 25 },
		{ count = 5, hp = 50, damage = 6, speed = 10, kind = "slime", coins = 40 },
		{ count = 4, hp = 80, damage = 8, speed = 11, kind = "skeleton", coins = 70 },
		{ count = 5, hp = 90, damage = 9, speed = 12, kind = "skeleton", coins = 100 },
		{ count = 1, hp = 600, damage = 18, speed = 10, kind = "boss", coins = 300 },
	} :: { Wave },
	player = {
		hp = 100,
		damage = 20,
		attackRange = 12,
		attackCooldown = 0.45,
	},
	enemy = {
		touchRange = 5, -- враг бьёт, если ближе
		attackCooldown = 1.2,
	},
	-- Баффы из сада: за каждый уровень каждого посаженного дерева.
	buffs = {
		hpPerTreeLevel = 3,
		damagePerTreeLevel = 0.02, -- +2% урона
	},
	-- Добыча за зачищенную волну (шансы в процентах, показываются в лобби).
	loot = {
		fertilizerChance = 40,
		seedChance = 30,
		-- редкость выпавшего семени, сумма 100
		seedOdds = {
			{ rarity = "common", chance = 35 },
			{ rarity = "uncommon", chance = 30 },
			{ rarity = "rare", chance = 20 },
			{ rarity = "epic", chance = 11 },
			{ rarity = "legendary", chance = 4 },
		},
	},
}
