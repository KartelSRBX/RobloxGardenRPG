--!strict
-- Анимация выпадения ростка. Сила растёт с редкостью (Rarities.reveal):
-- quick — короткая карточка у кнопки (её показывает RollHud);
-- stars — звёзды цвета редкости сходятся в центр, вспышка, титр;
-- cinematic — плюс затемнение, лучи, всплеск частиц, толчок камеры;
-- epic — плюс полосы кадра, орбита звёзд перед схождением, долгий титр.
-- Тап по экрану пропускает анимацию. Найденное впервые всегда показывается полностью.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local RollReveal = {}

-- С какой редкости играть анимацию (порядок редкости). Меняется в настройках.
RollReveal.minOrder = 3

local gui: ScreenGui
local busy = false
local queue: { any } = {}
local skipRequested = false

local function tween(
	obj: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- Ожидание, которое прерывается пропуском.
local function pause(t: number)
	local start = os.clock()
	while os.clock() - start < t and not skipRequested do
		task.wait()
	end
end

local function diamond(parent: Instance, size: number, color: Color3): Frame
	local d = UI.frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		Rotation = 45,
		ZIndex = 103,
	})
	return d
end

-- Толчок камеры на короткое время.
local function shake(power: number, duration: number)
	local name = "RollRevealShake"
	local start = os.clock()
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - start
		if t > duration then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = power * (1 - t / duration)
		local cam = workspace.CurrentCamera
		cam.CFrame *= CFrame.Angles(
			math.rad((math.random() - 0.5) * k),
			math.rad((math.random() - 0.5) * k),
			math.rad((math.random() - 0.5) * k * 0.5)
		)
	end)
end

-- Всплеск сияния вокруг персонажа (видит только сам игрок; постоянную ауру видят все).
local function worldBurst(palette: { Color3 }, big: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = root.CFrame
	p.Parent = workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette[1]),
		ColorSequenceKeypoint.new(0.5, palette[2]),
		ColorSequenceKeypoint.new(1, palette[3] or palette[1]),
	})
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new(0.6, 0)
	pe.Speed = NumberRange.new(10, 22)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Drag = 3
	pe.Rate = 0
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.Parent = p
	pe:Emit(if big then 120 else 40)
	local light = Instance.new("PointLight")
	light.Color = palette[1]
	light.Range = if big then 28 else 14
	light.Brightness = 4
	light.Parent = p
	tween(light, 1.2, { Brightness = 0 })
	task.delay(2, function()
		p:Destroy()
	end)
end

local function play(result: any)
	local tree = Garden.tree(result.treeId)
	if not tree then
		return
	end
	local rarity = Garden.rarity(tree.rarity)
	local aura = Garden.aura(tree.id)
	local palette = aura.palette
	local kind = rarity.reveal
	if kind == "quick" then
		kind = "stars" -- первая находка частого вида: короткая версия
	end
	local isEpic = kind == "epic"
	local isCine = kind == "cinematic" or isEpic
	skipRequested = false

	local root = UI.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,
	})
	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromScale(1, 1)
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.ZIndex = 120
	skip.Parent = root
	skip.Activated:Connect(function()
		skipRequested = true
	end)

	-- затемнение
	local dim = UI.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 4, 10),
		BackgroundTransparency = 1,
		ZIndex = 101,
	})
	if isCine then
		tween(dim, 0.4, { BackgroundTransparency = if isEpic then 0.15 else 0.35 })
	end
	-- полосы кадра
	local bars: { Frame } = {}
	if isEpic then
		for i, y in { 0, 1 } do
			local bar = UI.frame(root, {
				AnchorPoint = Vector2.new(0, y),
				Position = UDim2.fromScale(0, y),
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = Color3.new(0, 0, 0),
				ZIndex = 110,
			})
			bars[i] = bar
			tween(bar, 0.5, { Size = UDim2.new(1, 0, 0.11, 0) })
		end
	end

	-- звёзды: цвет подсказывает редкость
	local center = UDim2.fromScale(0.5, 0.42)
	local count = if isEpic then 16 elseif isCine then 10 else 6
	local travel = if isEpic then 1.6 elseif isCine then 1.1 else 0.7
	local stars: { Frame } = {}
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local r = 0.55 + math.random() * 0.2
		local star =
			diamond(root, math.random(8, 16), if i % 2 == 0 then rarity.color else rarity.color2)
		star.Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.42 + math.sin(a) * r * 0.9)
		star.BackgroundTransparency = 1
		tween(star, 0.25, { BackgroundTransparency = 0 })
		table.insert(stars, star)
	end
	if isEpic then
		-- орбита перед схождением
		local t0 = os.clock()
		while os.clock() - t0 < 1.2 and not skipRequested do
			local t = os.clock() - t0
			for i, star in stars do
				local a = (i / count) * math.pi * 2 + t * (1 + t * 2)
				local r = 0.32 - t * 0.12
				star.Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.42 + math.sin(a) * r)
				star.Rotation = 45 + t * 360
			end
			task.wait()
		end
	end
	for _, star in stars do
		tween(
			star,
			travel,
			{ Position = center, Size = UDim2.fromOffset(4, 4) },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)
	end
	pause(travel)
	for _, star in stars do
		star:Destroy()
	end

	-- вспышка
	local flash = UI.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if isCine then 0.1 else 0.6,
		ZIndex = 115,
	})
	tween(flash, 0.6, { BackgroundTransparency = 1 })
	worldBurst(palette, isCine)
	if isCine then
		shake(if isEpic then 2.2 else 1.2, if isEpic then 0.7 else 0.4)
		local cam = workspace.CurrentCamera
		local fov = cam.FieldOfView
		cam.FieldOfView = fov - 8
		tween(cam, 0.6, { FieldOfView = fov }, Enum.EasingStyle.Back)
	end

	-- лучи за титром
	local rays = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 102,
	})
	if isCine then
		-- каждый луч — полоса через центр: два луча в разные стороны
		for i = 1, 8 do
			local ray = UI.frame(rays, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(if i % 2 == 0 then 14 else 6, 900),
				BackgroundColor3 = palette[(i % #palette) + 1],
				Rotation = i * 22.5,
				ZIndex = 102,
			})
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.55),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.58, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = ray
		end
	end
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 12
	end)

	-- всплеск квадратиков
	for i = 1, if isCine then 28 else 12 do
		local a = math.random() * math.pi * 2
		local d = 0.12 + math.random() * 0.25
		local bit = diamond(root, math.random(5, 10), palette[(i % #palette) + 1])
		bit.Position = center
		tween(bit, 0.9, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * d, 0.42 + math.sin(a) * d),
			BackgroundTransparency = 1,
			Rotation = math.random(-180, 180),
		})
		task.delay(1, function()
			bit:Destroy()
		end)
	end

	-- титр
	local card = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(460, 150),
		BackgroundTransparency = 1,
		ZIndex = 105,
	})
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.4
	cardScale.Parent = card
	tween(cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local tags = {}
	if result.isNew then
		table.insert(tags, "NEW")
	end
	if result.lucky then
		table.insert(tags, "LUCKY ROLL")
	end
	UI.label(card, table.concat(tags, " · "), {
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = rarity.color2,
		ZIndex = 106,
	})
	local title = UI.label(card, string.upper(tree.name), {
		Size = UDim2.new(1, 0, 0, 62),
		Position = UDim2.fromOffset(0, 22),
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		ZIndex = 106,
	})
	local limit = title:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = 56
	end
	UI.shimmer(UI.paletteGradient(title, palette), 2)
	local sub = UI.label(card, `{string.upper(rarity.name)} · {UI.oneIn(Luck.oneIn(tree.id))}`, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 90),
		Font = UI.fontRegular,
		ZIndex = 106,
	})
	UI.paletteGradient(sub, { rarity.color, rarity.color2 })
	local hint = UI.label(card, "", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 120),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		ZIndex = 106,
	})
	if result.composted then
		hint.Text = `Storage full · composted for {UI.formatNumber(result.composted)} coins`
	end

	pause(if isEpic then 3.2 elseif isCine then 2.2 else 1.3)

	-- уход
	for _, d in root:GetDescendants() do
		if d:IsA("Frame") then
			tween(d, 0.35, { BackgroundTransparency = 1 })
		elseif d:IsA("TextLabel") then
			tween(d, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end
	for _, bar in bars do
		tween(bar, 0.35, { Size = UDim2.new(1, 0, 0, 0) })
	end
	task.wait(0.4)
	spin:Disconnect()
	root:Destroy()
end

local function pump()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		local result = table.remove(queue, 1)
		local ok, err = pcall(play, result)
		if not ok then
			warn("[RollReveal]", err)
		end
	end
	busy = false
end

function RollReveal.init(parent: ScreenGui)
	gui = parent
end

-- Нужна ли большая анимация для результата.
function RollReveal.wants(result: any): boolean
	local tree = Garden.tree(result.treeId)
	if not tree then
		return false
	end
	local order = Garden.rarity(tree.rarity).order
	return order >= RollReveal.minOrder or (result.isNew and order >= 2)
end

function RollReveal.show(result: any)
	-- при авто-крутке не копим длинную очередь
	if #queue >= 3 then
		return
	end
	table.insert(queue, result)
	task.spawn(pump)
end

function RollReveal.isBusy(): boolean
	return busy
end

return RollReveal
