--!strict
-- Лобби-HUD по ТЗ: девять экранных зон с якорями (Z1 — системная панель Roblox, её не трогаем).
--   Z2 сверху по центру: уровень острова, готовность расширения, Luck и доход
--   Z3 сверху справа: круглые системные кнопки (профиль, меню, дом, хаб, скрыть интерфейс)
--   Z4 слева по центру: сетка 2xN IconButton с бейджами (остров, шансы, подземелье, магазин, оружие, индекс)
--   Z5 слева снизу: стек счётчиков (монеты, ростки, грядки, удобрение)
--   Z6 снизу по центру: крутка (RollHud)   Z7 справа снизу: индикаторы бустов (только чтение)
--   Z8 справа по центру: предложения за Robux (цена всегда видна, без таймеров)   Z9: тосты и подсказки
-- Скрытие интерфейса убирает слои L1–L3 (подписи мира, HUD); панели и Core UI остаются.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Components = require(script.Parent.Components)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Hud = {}

local function seedTotal(profile: any): number
	local n = 0
	for _, c in profile.seeds do
		n += c
	end
	return n
end

-- Готовность расширения острова 0..1 (минимум из времени, монет и ростков).
function Hud.islandReadiness(profile: any): number?
	local nextTier = Garden.nextIsland(profile.islandTier)
	if not nextTier then
		return nil
	end
	local time = profile.playSeconds / math.max(1, nextTier.minutes * 60)
	local coins = profile.coins / math.max(1, nextTier.coins)
	local seeds = seedTotal(profile) / math.max(1, nextTier.seeds)
	return math.clamp(math.min(time, coins, seeds), 0, 1)
end

function Hud.new(worldHud: Frame, ctx: any)
	local touch = UserInputService.TouchEnabled
	local zones: { [string]: Frame } = {}
	local function zone(name: string, props: { [string]: any }): Frame
		local f = UI.frame(worldHud, props)
		f.Name = name
		f.BackgroundTransparency = 1
		zones[name] = f
		return f
	end

	---------------------------------------------------------------- Z2: статус-центр
	local z2 = zone("Z2", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(340, 60),
	})
	UI.autoScale(z2)
	local islandBar = Components.progress(z2, {
		height = 22,
		color = UI.colors.green,
		left = "ISLAND Lv 1",
		position = UDim2.fromOffset(0, 0),
		size = UDim2.new(1, 0, 0, 22),
	})
	local metrics = UI.label(z2, "", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 16),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.text,
	})
	Components.outline(metrics, 0.8)

	---------------------------------------------------------------- Z3: системные круглые кнопки
	local z3 = zone("Z3", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(3 * 52 + 12, 2 * 52 + 6),
	})
	UI.autoScale(z3)
	local z3Grid = Instance.new("UIGridLayout")
	z3Grid.CellSize = UDim2.fromOffset(52, 52)
	z3Grid.CellPadding = UDim2.fromOffset(6, 6)
	z3Grid.SortOrder = Enum.SortOrder.LayoutOrder
	z3Grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	z3Grid.Parent = z3

	local round: { [string]: Components.IconButton } = {}
	local function roundButton(
		name: string,
		label: string,
		icon: string,
		accent: Color3,
		order: number
	)
		local b = Components.iconButton(
			z3,
			{ name = name, label = label, icon = icon, accent = accent, size = 52, order = order }
		)
		round[name] = b
		return b
	end
	roundButton("Profile", "BAG", "profile", Color3.fromRGB(130, 170, 240), 1)
	roundButton("Menu", "MENU", "menu", Color3.fromRGB(190, 196, 210), 2)
	roundButton("GoHome", "HOME", "home", Color3.fromRGB(120, 200, 130), 3)
	roundButton("GoHub", "HUB", "hub", Color3.fromRGB(170, 140, 240), 4)

	-- «Скрыть интерфейс» живёт отдельно: остаётся на экране, когда всё остальное скрыто
	local hideHolder = UI.frame(worldHud, {
		Name = "HideZone",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 190),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		ZIndex = 8,
	})
	UI.autoScale(hideHolder)
	local hide = Components.iconButton(hideHolder, {
		name = "Hide",
		label = "HIDE",
		icon = "eye",
		accent = Color3.fromRGB(190, 196, 210),
		size = 52,
	})

	---------------------------------------------------------------- Z4: сетка меню 2xN
	local z4 = zone("Z4", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 6),
		Size = UDim2.fromOffset(2 * 66 + 6, 3 * 66 + 12),
	})
	UI.autoScale(z4)
	local z4Grid = Instance.new("UIGridLayout")
	z4Grid.CellSize = UDim2.fromOffset(66, 66)
	z4Grid.CellPadding = UDim2.fromOffset(6, 6)
	z4Grid.SortOrder = Enum.SortOrder.LayoutOrder
	z4Grid.Parent = z4
	local menu: { [string]: Components.IconButton } = {}
	for i, item in
		{
			{ "Island", "ISLAND", "island", Color3.fromRGB(120, 200, 130) },
			{ "Dungeon", "DUNGEON", "dungeon", Color3.fromRGB(170, 140, 240) },
			{ "Roll", "ODDS", "odds", Color3.fromRGB(236, 196, 100) },
			{ "Shop", "SHOP", "shop", Color3.fromRGB(120, 210, 255) },
			{ "Weapons", "WEAPONS", "dungeon", Color3.fromRGB(230, 120, 110) },
			{ "Index", "INDEX", "sprout", Color3.fromRGB(150, 220, 130) },
		}
	do
		menu[item[1]] = Components.iconButton(z4, {
			name = item[1],
			label = item[2],
			icon = item[3],
			accent = item[4],
			size = 66,
			order = i,
		})
	end

	---------------------------------------------------------------- Z5: счётчики ресурсов
	local z5 = zone("Z5", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, if touch then -176 else -16),
		Size = UDim2.fromOffset(150, 4 * 38),
	})
	UI.autoScale(z5)
	local z5List = UI.list(z5, 4)
	z5List.HorizontalAlignment = Enum.HorizontalAlignment.Left
	z5List.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local cCoins =
		Components.counter(z5, { icon = "coin", color = UI.colors.gold, order = 1, width = 150 })
	local cSprouts =
		Components.counter(z5, { icon = "sprout", color = UI.colors.green, order = 2, width = 150 })
	local cPlots = Components.counter(
		z5,
		{ icon = "island", color = Color3.fromRGB(120, 200, 130), order = 3, width = 150 }
	)
	local cFert =
		Components.counter(z5, { icon = "odds", color = UI.colors.purple, order = 4, width = 150 })

	---------------------------------------------------------------- Z7: индикаторы бустов
	local z7 = zone("Z7", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, if touch then -150 else -16),
		Size = UDim2.fromOffset(150, 4 * 30),
	})
	UI.autoScale(z7)
	local z7List = UI.list(z7, 4)
	z7List.HorizontalAlignment = Enum.HorizontalAlignment.Right
	z7List.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local function chip(order: number, color: Color3): (string) -> ()
		local f = UI.frame(z7, {
			Size = UDim2.fromOffset(132, 26),
			BackgroundColor3 = UI.colors.bg,
			BackgroundTransparency = 0.3,
			LayoutOrder = order,
			Visible = false,
		})
		UI.corner(f, 13)
		UI.stroke(f, color, 1, 0.5)
		local l = UI.label(f, "", {
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			TextColor3 = color,
		})
		Components.outline(l, 0.6)
		return function(text: string)
			f.Visible = text ~= ""
			l.Text = text
		end
	end
	local chipLuck = chip(1, Color3.fromRGB(150, 200, 255))
	local chipCoins = chip(2, UI.colors.gold)
	local chipAuto = chip(3, UI.colors.green)

	---------------------------------------------------------------- Z8: предложения за Robux
	local z8 = zone("Z8", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 80),
		Size = UDim2.fromOffset(196, 2 * 58),
	})
	UI.autoScale(z8)
	local z8List = UI.list(z8, 4)
	z8List.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local offers: { { pass: any, button: TextButton, setPrice: (string) -> () } } = {}
	local prices: { [string]: number } = {}

	local function buyPass(pass: any)
		if State.passes[pass.key] then
			return
		end
		if pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(game.Players.LocalPlayer, pass.id)
		else
			ctx.open("Shop")
		end
	end

	local function makeOffer(pass: any, order: number)
		local treeId = pass.treeId
		local tree = treeId and Garden.tree(treeId) :: any
		local title = if tree then tree.name else pass.name
		local icon = if tree then "shop" else "coin"
		local accent = if tree then Garden.aura(treeId).palette[1] else UI.colors.gold
		local sub = if tree then "Exclusive tree" else pass.desc
		local button, setPrice = Components.purchase(z8, {
			icon = icon,
			title = title,
			sub = sub,
			price = `R${pass.price}`,
			accent = accent,
			rainbow = tree ~= nil,
			order = order,
		})
		button.Activated:Connect(function()
			buyPass(pass)
		end)
		table.insert(offers, { pass = pass, button = button, setPrice = setPrice })
		if pass.id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(
					MarketplaceService.GetProductInfo,
					MarketplaceService,
					pass.id,
					Enum.InfoType.GamePass
				)
				if ok and info and info.PriceInRobux then
					prices[pass.key] = info.PriceInRobux
				end
			end)
		end
	end
	-- Первая невладеемая эксклюзивная покупка и множитель монет.
	local featured: any = nil
	for _, pass in Config.GamePasses do
		if pass.treeId and not featured then
			featured = pass
		end
	end
	if featured then
		makeOffer(featured, 1)
	end
	for _, pass in Config.GamePasses do
		if pass.key == "coins2x" then
			makeOffer(pass, 2)
		end
	end

	---------------------------------------------------------------- Скрыть интерфейс
	local hidden = false
	local function setHidden(v: boolean)
		hidden = v
		for _, z in zones do
			z.Visible = not v
		end
		ctx.setBillboards(not v)
		ctx.setRollVisible(not v)
		hide.setActive(v)
	end
	hide.button.Activated:Connect(function()
		setHidden(not hidden)
	end)

	---------------------------------------------------------------- Бейджи: «новое»
	-- Показываем, сколько оружия и видов появилось с момента последнего открытия окна.
	local seenWeapons: { [string]: boolean }? = nil
	local seenFound: { [string]: boolean }? = nil
	local function count(a: { [string]: boolean }, seen: { [string]: boolean }): number
		local n = 0
		for id in a do
			if not seen[id] then
				n += 1
			end
		end
		return n
	end

	function ctx.markSeen(what: string)
		local p = State.profile
		if not p then
			return
		end
		if what == "weapons" then
			seenWeapons = table.clone(p.weapons)
		elseif what == "index" then
			seenFound = table.clone(p.found)
		end
		Hud.refresh()
	end

	---------------------------------------------------------------- Обновление
	local lastCoins: number? = nil
	function Hud.refresh()
		local p = State.profile
		if not p then
			return
		end
		-- первые данные считаем уже просмотренными
		if not seenWeapons then
			seenWeapons = table.clone(p.weapons)
		end
		if not seenFound then
			seenFound = table.clone(p.found)
		end

		-- Z2
		local readiness = Hud.islandReadiness(p)
		islandBar.setLabel(`ISLAND Lv {p.islandTier}`)
		if readiness then
			islandBar.set(
				readiness,
				`{math.floor(readiness * 100)}%`,
				if readiness >= 1 then UI.colors.gold else UI.colors.green
			)
		else
			islandBar.set(1, "MAX", UI.colors.gold)
		end
		local income = 0
		for slot, plot in p.plots do
			local t = Garden.tree(plot.plantId)
			if t then
				income += Garden.incomePerMinute(t, plot.level) * Garden.neighborMult(p.plots, slot)
			end
		end
		metrics.Text =
			string.format("Luck x%.2f  ·  %s coins/min", Luck.breakdown(p).total, UI.short(income))

		-- Z4 бейджи
		if readiness and readiness >= 1 then
			menu.Island.setBadge("!", "red")
		elseif readiness and readiness > 0 then
			menu.Island.setBadge(`{math.floor(readiness * 100)}%`, "percent")
		else
			menu.Island.setBadge(nil)
		end
		local newWeapons = count(p.weapons, seenWeapons :: any)
		menu.Weapons.setBadge(if newWeapons > 0 then tostring(newWeapons) else nil, "red")
		round.Profile.setBadge(if newWeapons > 0 then tostring(newWeapons) else nil, "red")
		local newSpecies = count(p.found, seenFound :: any)
		menu.Index.setBadge(if newSpecies > 0 then tostring(newSpecies) else nil, "red")

		-- Z5
		cCoins.set(UI.short(p.coins))
		cSprouts.set(UI.short(seedTotal(p)))
		local used = 0
		for _, plot in p.plots do
			if plot.plantId then
				used += 1
			end
		end
		cPlots.set(`{used}/{#p.plots}`)
		cFert.set(UI.short(p.items.fertilizer or 0))
		-- переполнение запаса: любой вид у предела (лишнее уходит в компост)
		local full = false
		for _, n in p.seeds do
			if n >= Config.Economy.seedCap then
				full = true
			end
		end
		cSprouts.alert(full)
		if lastCoins and p.coins > lastCoins then
			cCoins.bump()
		end
		lastCoins = p.coins

		-- Z7
		chipLuck(string.format("LUCK x%.2f", Luck.breakdown(p).total))
		chipCoins(if State.passes.coins2x then "COINS x2" else "")
		chipAuto(if p.autoRoll then "AUTO ROLL" else "")

		-- Z8: купленное скрываем, цену берём с сайта, если пропуск уже создан
		for _, o in offers do
			o.button.Visible = State.passes[o.pass.key] ~= true
			local price = prices[o.pass.key]
			if price then
				o.setPrice(`R${price}`)
			end
		end
	end

	-- Подсветка активного окна
	function Hud.setActive(name: string?)
		for key, b in menu do
			b.setActive(key == name)
		end
		for key, b in round do
			b.setActive(key == name)
		end
	end

	return {
		menu = menu,
		round = round,
		hide = hide,
		zones = zones,
		setHidden = setHidden,
		isHidden = function()
			return hidden
		end,
		refresh = Hud.refresh,
		setActive = Hud.setActive,
	}
end

return Hud
