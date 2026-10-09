--!strict
-- Крутка внизу экрана.
-- Медальон с ростком: вращающееся кольцо, точки отката по кругу, подпись «счастливой» крутки.
-- Барабан: при каждой крутке над медальоном выезжает лента деревьев и тормозит на результате.
-- Ленту заполняют случайные виды с настоящими шансами (без подставных «почти выпало»).
-- После остановки — карточка результата, а у редких видов — большая анимация (RollReveal).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(script.Parent.Icons)
local Net = require(script.Parent.Net)
local RollReveal = require(script.Parent.RollReveal)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local R = Config.Roll

local RollHud = {}

local REEL_W = 360
local CARD_W = 96
local STEP = 102
local CARDS = 26
local RESULT_INDEX = 22

local GOLD =
	{ Color3.fromRGB(255, 214, 120), Color3.fromRGB(196, 140, 60), Color3.fromRGB(255, 238, 190) }

local function tween(
	obj: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- Случайный вид с настоящими шансами при текущей удаче.
local function randomTree(chances: { [string]: number }): string
	local pick = math.random()
	local acc = 0
	for id, p in chances do
		acc += p
		if pick <= acc then
			return id
		end
	end
	return Config.Trees[1].id
end

function RollHud.new(parent: Instance, ctx: any)
	local root = UI.frame(parent, {
		Name = "RollHud",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(REEL_W, 250),
		BackgroundTransparency = 1,
	})

	---------------------------------------------------------------- медальон
	-- мягкий ореол за медальоном, «дышит», когда крутка готова
	local halo = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(132, 132),
		BackgroundColor3 = GOLD[1],
		BackgroundTransparency = 1,
	})
	UI.corner(halo, 66)
	local medal = Instance.new("TextButton")
	medal.Name = "RollButton"
	medal.Text = ""
	medal.AutoButtonColor = false
	medal.AnchorPoint = Vector2.new(0.5, 1)
	medal.Position = UDim2.new(0.5, 0, 1, -36)
	medal.Size = UDim2.fromOffset(96, 96)
	medal.BackgroundColor3 = UI.colors.bg
	medal.BackgroundTransparency = 0.08
	medal.Parent = root
	UI.corner(medal, 48)
	local medalScale = Instance.new("UIScale")
	medalScale.Parent = medal
	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = medal
	local ringGradient = UI.paletteGradient(ring, GOLD)
	-- внутренний диск с мягким градиентом
	local disc = UI.frame(medal, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	UI.corner(disc, 40)
	UI.paletteGradient(disc, { Color3.fromRGB(40, 46, 60), Color3.fromRGB(22, 26, 36) }, 90)
	local iconHolder = UI.frame(disc, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
	})
	Icons.make("sprout", iconHolder, Color3.fromRGB(150, 220, 120), Color3.fromRGB(110, 190, 100))
	local iconScale = Instance.new("UIScale")
	iconScale.Parent = iconHolder

	-- точки отката по кругу
	local dots: { Frame } = {}
	local DOTS = 24
	for i = 1, DOTS do
		local a = (i - 1) / DOTS * math.pi * 2 - math.pi / 2
		local dot = UI.frame(medal, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * 55, 0.5, math.sin(a) * 55),
			Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = GOLD[1],
		})
		UI.corner(dot, 2)
		dots[i] = dot
	end

	local caption = UI.label(root, "ROLL", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -13),
		Size = UDim2.fromOffset(200, 14),
		TextColor3 = UI.colors.text,
		TextStrokeTransparency = 0.55,
	})
	local sub = UI.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(200, 11),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		TextStrokeTransparency = 0.6,
	})

	-- авто-крутка
	local auto = Instance.new("TextButton")
	auto.Name = "AutoButton"
	auto.Text = ""
	auto.AutoButtonColor = false
	auto.AnchorPoint = Vector2.new(0, 0.5)
	auto.Position = UDim2.new(0.5, 64, 1, -84)
	auto.Size = UDim2.fromOffset(48, 48)
	auto.BackgroundColor3 = UI.colors.bg
	auto.BackgroundTransparency = 0.1
	auto.Parent = root
	UI.corner(auto, 24)
	local autoStroke = UI.stroke(auto, UI.colors.line, 1.5, 0.8)
	local autoIconHolder = UI.frame(auto, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundTransparency = 1,
	})
	local autoIcon = Icons.make("auto", autoIconHolder, UI.colors.muted)
	local autoLabel = UI.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 88, 1, -56),
		Size = UDim2.fromOffset(70, 12),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		TextStrokeTransparency = 0.6,
	})

	---------------------------------------------------------------- барабан
	-- CanvasGroup: лента плавно проявляется и гаснет целиком
	local reel = Instance.new("CanvasGroup")
	reel.Name = "Reel"
	reel.AnchorPoint = Vector2.new(0.5, 1)
	reel.Position = UDim2.new(0.5, 0, 1, -138)
	reel.Size = UDim2.fromOffset(REEL_W, 72)
	reel.BackgroundColor3 = UI.colors.bg
	reel.BackgroundTransparency = 0.08
	reel.BorderSizePixel = 0
	reel.GroupTransparency = 1
	reel.Visible = false
	reel.Parent = root
	UI.corner(reel, 12)
	UI.glass(reel)
	-- затухание краёв ленты
	local strip = UI.frame(reel, {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(CARDS * STEP, 56),
		BackgroundTransparency = 1,
	})
	local fadeL = UI.frame(reel, {
		Size = UDim2.new(0, 60, 1, 0),
		BackgroundColor3 = UI.colors.bg,
		ZIndex = 3,
	})
	local fl = Instance.new("UIGradient")
	fl.Transparency = NumberSequence.new(0, 1)
	fl.Parent = fadeL
	local fadeR = UI.frame(reel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 60, 1, 0),
		BackgroundColor3 = UI.colors.bg,
		ZIndex = 3,
	})
	local fr = Instance.new("UIGradient")
	fr.Transparency = NumberSequence.new(1, 0)
	fr.Parent = fadeR
	-- метка центра
	local marker = UI.frame(reel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = GOLD[1],
		BackgroundTransparency = 0.35,
		ZIndex = 4,
	})
	for _, y in { 0, 1 } do
		UI.frame(reel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromOffset(10, 10),
			Rotation = 45,
			BackgroundColor3 = GOLD[1],
			ZIndex = 4,
		})
	end
	local markerScale = Instance.new("UIScale")
	markerScale.Parent = marker

	local cards: { Frame } = {}
	local function makeCard(i: number): Frame
		local card = UI.frame(strip, {
			Position = UDim2.fromOffset((i - 1) * STEP, 0),
			Size = UDim2.fromOffset(CARD_W, 56),
			BackgroundColor3 = UI.colors.panel,
		})
		UI.corner(card, 8)
		local top = UI.frame(card, {
			Name = "Stripe",
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
		})
		UI.corner(top, 2)
		UI.label(card, "", {
			Name = "TreeName",
			Size = UDim2.new(1, -10, 0, 18),
			Position = UDim2.fromOffset(5, 12),
		})
		UI.label(card, "", {
			Name = "Rarity",
			Size = UDim2.new(1, -10, 0, 12),
			Position = UDim2.fromOffset(5, 34),
			Font = UI.fontRegular,
		})
		local stroke = UI.stroke(card, UI.colors.line, 1, 0.9)
		stroke.Name = "Edge"
		return card
	end
	for i = 1, CARDS do
		cards[i] = makeCard(i)
	end

	local function setCard(card: Frame, treeId: string, found: boolean)
		local tree = Garden.tree(treeId) :: Garden.Tree
		local r = Garden.rarity(tree.rarity)
		local stripe = card:FindFirstChild("Stripe") :: Frame
		local g = stripe:FindFirstChildOfClass("UIGradient")
		if g then
			g:Destroy()
		end
		UI.paletteGradient(stripe, { r.color, r.color2 })
		local name = card:FindFirstChild("TreeName") :: TextLabel
		name.Text = if found then tree.name else "???"
		local rar = card:FindFirstChild("Rarity") :: TextLabel
		rar.Text = string.upper(r.name)
		rar.TextColor3 = r.color2
		local edge = card:FindFirstChild("Edge") :: UIStroke
		edge.Color = UI.colors.line
		edge.Transparency = 0.9
		edge.Thickness = 1
		card.BackgroundColor3 = UI.colors.panel
	end

	---------------------------------------------------------------- карточка результата
	local card = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -138),
		Size = UDim2.fromOffset(REEL_W, 64),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UI.corner(card, 12)
	local cardStroke = UI.stroke(card, UI.colors.gold, 1.5)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local cardStripe = UI.frame(card, {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	UI.corner(cardStripe, 2)
	local cardName = UI.label(card, "", {
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(24, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local cardInfo = UI.label(card, "", {
		Size = UDim2.new(1, -40, 0, 14),
		Position = UDim2.fromOffset(24, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
	})
	local stripeGradient: UIGradient? = nil
	local nameGradient: UIGradient? = nil
	local hideId = 0

	local function showCard(res: any)
		local tree = Garden.tree(res.treeId)
		if not tree then
			return
		end
		local r = Garden.rarity(tree.rarity)
		local palette = Garden.aura(tree.id).palette
		cardName.Text = (if res.isNew then "NEW · " else "") .. tree.name
		cardName.TextColor3 = Color3.new(1, 1, 1)
		if nameGradient then
			nameGradient:Destroy()
		end
		nameGradient = UI.paletteGradient(cardName, palette)
		if stripeGradient then
			stripeGradient:Destroy()
		end
		stripeGradient = UI.paletteGradient(cardStripe, { r.color, r.color2 }, 90)
		local info = `{r.name} · {UI.oneIn(Luck.oneIn(tree.id))}`
		if res.lucky then
			info ..= " · LUCKY ROLL"
		end
		if res.composted then
			info ..= ` · composted +{UI.formatNumber(res.composted)}`
		end
		cardInfo.Text = info
		cardStroke.Color = r.color
		card.Visible = true
		cardScale.Scale = 1.05
		tween(cardScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		hideId += 1
		local id = hideId
		task.delay(2.6, function()
			if hideId == id then
				card.Visible = false
			end
		end)
	end

	---------------------------------------------------------------- анимация барабана
	---------------------------------------------------------------- частицы крутки
	-- Цвет искр зависит от удачи игрока: чем выше удача, тем «дороже» цвет и гуще поток.
	-- В последние мгновения искры принимают цвет выпавшей редкости — подсказка, что сейчас будет.
	local fxLayer = UI.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
	local LUCK_TIERS = {
		{ 1.5, Color3.fromRGB(200, 210, 222), Color3.fromRGB(150, 230, 180) },
		{ 3, Color3.fromRGB(110, 230, 170), Color3.fromRGB(170, 255, 210) },
		{ 5, Color3.fromRGB(90, 160, 255), Color3.fromRGB(150, 220, 255) },
		{ 8, Color3.fromRGB(180, 110, 255), Color3.fromRGB(255, 140, 220) },
		{ math.huge, Color3.fromRGB(255, 196, 80), Color3.fromRGB(255, 240, 170) },
	}
	local function luckColors(luck: number): (Color3, Color3)
		for _, tier in LUCK_TIERS do
			if luck < tier[1] then
				return tier[2], tier[3]
			end
		end
		return GOLD[1], GOLD[3]
	end

	-- Одна искра: ромбик летит из точки и гаснет.
	local function spark(from: Vector2, color: Color3, power: number)
		local size = math.random(4, 7) + power
		local p = UI.frame(fxLayer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(from.X, from.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			Rotation = 45,
			ZIndex = 6,
		})
		local a = math.random() * math.pi * 2
		local dist = 30 + math.random() * 50 * (1 + power * 0.15)
		local to = from + Vector2.new(math.cos(a) * dist, math.sin(a) * dist * 0.7 - 20)
		tween(p, 0.6 + math.random() * 0.4, {
			Position = UDim2.fromOffset(to.X, to.Y),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
			Rotation = 45 + math.random(-180, 180),
		})
		task.delay(1.1, function()
			p:Destroy()
		end)
	end

	-- Точки вылета: кольцо медальона и края барабана (координаты внутри root).
	local function emitPoint(): Vector2
		local w = root.AbsoluteSize.X
		local h = root.AbsoluteSize.Y
		if math.random() < 0.55 then
			local a = math.random() * math.pi * 2
			return Vector2.new(w / 2 + math.cos(a) * 52, h - 84 + math.sin(a) * 52)
		end
		local side = if math.random() < 0.5 then -1 else 1
		return Vector2.new(w / 2 + side * (REEL_W / 2 - 6), h - 174 + math.random(-28, 28))
	end

	-- Частицы вокруг персонажа во время крутки (видит только сам игрок).
	local function characterSwirl(c1: Color3, c2: Color3, rate: number): (ParticleEmitter?, Part?)
		local character = game:GetService("Players").LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return nil, nil
		end
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(4, 0.2, 4)
		holder.CFrame = hrp.CFrame * CFrame.new(0, -2.6, 0)
		holder.Parent = workspace
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(c1, c2)
		pe.LightEmission = 0.9
		pe.Size = NumberSequence.new(0.25, 0)
		pe.Lifetime = NumberRange.new(0.8, 1.3)
		pe.Speed = NumberRange.new(2, 4)
		pe.SpreadAngle = Vector2.new(15, 15)
		pe.Acceleration = Vector3.new(0, 2, 0)
		pe.Rate = rate
		pe.Shape = Enum.ParticleEmitterShape.Disc
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		pe.Parent = holder
		return pe, holder
	end

	local spinning = false
	local pending: any = nil
	local readyAt = 0

	local function spinTo(res: any)
		local profile = State.profile
		if not profile then
			showCard(res)
			return
		end
		spinning = true
		card.Visible = false
		local chances = Luck.chances(Luck.breakdown(profile).total)
		local found = profile.found or {}
		for i, c in cards do
			if i == RESULT_INDEX then
				setCard(c, res.treeId, true)
			else
				local id = randomTree(chances)
				setCard(c, id, found[id] == true)
			end
		end
		local tree = Garden.tree(res.treeId) :: Garden.Tree
		local r = Garden.rarity(tree.rarity)
		local center = REEL_W / 2
		local startX = center - (2 * STEP + CARD_W / 2)
		local endX = center - ((RESULT_INDEX - 1) * STEP + CARD_W / 2) + math.random(-30, 30)
		strip.Position = UDim2.fromOffset(startX, 8)
		reel.Visible = true
		reel.GroupTransparency = 1
		reel.Position = UDim2.new(0.5, 0, 1, -128)
		tween(reel, 0.18, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, -138) })
		-- кольцо и росток крутятся
		iconScale.Scale = 0.85
		tween(iconScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		local duration = if r.order >= 3 then 1.5 else 1.1
		tween(strip, duration, { Position = UDim2.fromOffset(endX, 8) }, Enum.EasingStyle.Quint)
		-- поток искр: цвет и плотность от удачи, счастливая крутка — золото
		local luck = Luck.breakdown(profile).total * (if res.lucky then R.luckyMult else 1)
		local c1, c2 = luckColors(luck)
		if res.lucky then
			c1, c2 = GOLD[1], GOLD[3]
		end
		local rate = math.clamp(16 + luck * 6, 16, 70)
		local swirl, swirlHolder = characterSwirl(c1, c2, rate * 0.6)
		local hintFrom = duration * 0.7
		local started = os.clock()
		local sparking = true
		task.spawn(function()
			while sparking do
				local elapsed = os.clock() - started
				-- ближе к концу искры подсказывают редкость результата
				local hint = elapsed > hintFrom and r.order >= 3
				local col = if hint
					then (if math.random() < 0.5 then r.color else r.color2)
					elseif math.random() < 0.5 then c1
					else c2
				spark(emitPoint(), col, if hint then r.order else 1)
				if hint and swirl then
					swirl.Color = ColorSequence.new(r.color, r.color2)
				end
				task.wait(1 / rate)
			end
		end)
		-- щелчки метки, когда карточка проходит центр
		local lastIndex = -1
		local clicker = RunService.RenderStepped:Connect(function()
			local x = center - strip.Position.X.Offset
			local index = math.floor(x / STEP)
			if index ~= lastIndex then
				lastIndex = index
				markerScale.Scale = 1.6
				tween(markerScale, 0.08, { Scale = 1 })
			end
		end)
		task.wait(duration)
		clicker:Disconnect()
		sparking = false
		if swirl and swirlHolder then
			swirl.Enabled = false
			-- вспышка в цвет выпавшего вида, сильнее у редких
			local palette = Garden.aura(tree.id).palette
			swirl.Color = ColorSequence.new(palette[1], palette[2])
			swirl.Speed = NumberRange.new(4, 10)
			swirl.SpreadAngle = Vector2.new(60, 60)
			swirl:Emit(10 + r.order * 12)
			task.delay(2, function()
				swirlHolder:Destroy()
			end)
		end
		-- точная доводка на центр карточки результата
		local exact = center - ((RESULT_INDEX - 1) * STEP + CARD_W / 2)
		tween(strip, 0.18, { Position = UDim2.fromOffset(exact, 8) }, Enum.EasingStyle.Sine)
		local landed = cards[RESULT_INDEX]
		local edge = landed:FindFirstChild("Edge") :: UIStroke
		edge.Color = r.color2
		edge.Transparency = 0
		edge.Thickness = 2.5
		landed.BackgroundColor3 = r.color:Lerp(UI.colors.panel, 0.7)
		local landedScale = landed:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		landedScale.Parent = landed
		landedScale.Scale = 1.12
		tween(landedScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		-- всплеск искр вокруг выпавшей карточки
		local landedPalette = Garden.aura(tree.id).palette
		local cardCenter = Vector2.new(root.AbsoluteSize.X / 2, root.AbsoluteSize.Y - 174)
		for i = 1, 8 + r.order * 6 do
			spark(
				cardCenter + Vector2.new(math.random(-40, 40), math.random(-20, 20)),
				landedPalette[(i % #landedPalette) + 1],
				r.order
			)
		end
		task.wait(0.45)
		tween(reel, 0.18, { GroupTransparency = 1 })
		task.wait(0.18)
		reel.Visible = false
		landedScale.Scale = 1
		showCard(res)
		if RollReveal.wants(res) then
			RollReveal.show(res)
		end
		spinning = false
		if pending then
			local nextRes = pending
			pending = nil
			task.spawn(spinTo, nextRes)
		end
	end

	local function onResult(res: any)
		if spinning then
			-- держим только последний результат, чтобы не копить очередь
			pending = res
			return
		end
		task.spawn(spinTo, res)
	end

	local function doRoll()
		local profile = State.profile
		if not profile or os.clock() < readyAt then
			return
		end
		readyAt = os.clock() + Luck.cooldown(profile)
		medalScale.Scale = 0.92
		tween(medalScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		local res = Net.request("Roll")
		if res.ok and res.result then
			onResult(res.result)
		elseif res.error ~= "cooldown" then
			ctx.toast(Net.errorText(res.error))
		end
	end
	medal.Activated:Connect(doRoll)

	auto.Activated:Connect(function()
		local profile = State.profile
		if not profile then
			return
		end
		local res = Net.request("SetAutoRoll", not profile.autoRoll)
		if not res.ok then
			ctx.toast(Net.errorText(res.error))
		end
	end)

	Remotes.event("Rolled").OnClientEvent:Connect(function(res)
		local profile = State.profile
		readyAt = os.clock() + (if profile then Luck.cooldown(profile) else R.cooldown)
		onResult(res)
	end)

	---------------------------------------------------------------- живое состояние
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local profile = State.profile
		if not profile then
			return
		end
		local cd = Luck.cooldown(profile)
		local left = math.max(0, readyAt - os.clock())
		local progress = 1 - left / cd
		local ready = left <= 0
		-- кольцо крутится, быстрее во время крутки
		ringGradient.Rotation = (ringGradient.Rotation + dt * (if spinning then 360 else 60)) % 360
		ring.Transparency = if ready then 0 else 0.45
		local lit = math.floor(progress * DOTS + 0.5)
		for i, dot in dots do
			local on = ready or i <= lit
			dot.BackgroundTransparency = if on then 0 else 0.75
			dot.BackgroundColor3 = if ready and (math.floor(t * 8) % DOTS + 1) == i
				then Color3.new(1, 1, 1)
				else GOLD[1]
		end
		halo.BackgroundTransparency = if ready and not spinning
			then 0.86 + math.sin(t * 3) * 0.06
			else 0.94
		if ready and not spinning then
			iconHolder.Rotation = math.sin(t * 2) * 4
			medalScale.Scale = 1 + math.sin(t * 3) * 0.015
		else
			iconHolder.Rotation = 0
		end
		local toLucky = R.luckyEvery - (profile.rolls % R.luckyEvery)
		if toLucky == 1 then
			sub.Text = "NEXT ROLL IS LUCKY"
			sub.TextColor3 = GOLD[1]
		else
			sub.Text = `lucky in {toLucky}`
			sub.TextColor3 = UI.colors.muted
		end
		caption.Text = if profile.autoRoll then "AUTO ROLL" else "ROLL"
		local unlocked = profile.rolls >= R.autoUnlockRolls
		autoLabel.Text = if unlocked
			then (if profile.autoRoll then "ON" else "AUTO")
			else `{profile.rolls}/{R.autoUnlockRolls}`
		autoStroke.Color = if profile.autoRoll then UI.colors.green else UI.colors.line
		autoStroke.Transparency = if profile.autoRoll then 0 else 0.8
		autoIconHolder.Rotation = if profile.autoRoll
			then (autoIconHolder.Rotation + dt * 120) % 360
			else 0
		for _, f in autoIcon:GetDescendants() do
			if f:IsA("Frame") and f.BackgroundTransparency < 1 then
				f.BackgroundColor3 = if profile.autoRoll
					then UI.colors.green
					elseif unlocked then UI.colors.text
					else UI.colors.muted
			elseif f:IsA("UIStroke") then
				f.Color = if profile.autoRoll
					then UI.colors.green
					elseif unlocked then UI.colors.text
					else UI.colors.muted
			end
		end
	end)

	return {
		root = root,
		button = medal,
		setVisible = function(v: boolean)
			root.Visible = v
			if not v then
				card.Visible = false
				reel.Visible = false
			end
		end,
	}
end

return RollHud
