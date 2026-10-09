--!strict
-- Точка входа клиента: HUD (монеты, ростки, три главных экрана, меню, крутка),
-- панели, острова в мире, подсказки, эффекты и интерфейс подземелья.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AuraFx = require(script.AuraFx)
local DungeonHud = require(script.DungeonHud)
local DungeonScreen = require(script.DungeonScreen)
local Effects = require(script.Effects)
local Guide = require(script.Guide)
local Icons = require(script.Icons)
local IslandScreen = require(script.IslandScreen)
local MenuScreen = require(script.MenuScreen)
local Net = require(script.Net)
local OrbitFx = require(script.OrbitFx)
local ProfileScreen = require(script.ProfileScreen)
local RollHud = require(script.RollHud)
local RollReveal = require(script.RollReveal)
local RollScreen = require(script.RollScreen)
local ShopScreen = require(script.ShopScreen)
local State = require(script.State)
local Trailer = require(script.Trailer)
local TextChatService = game:GetService("TextChatService")
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local UI = require(script.UI)
local WorldPlots = require(script.WorldPlots)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GardenUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- HUD мира (прячется в подземелье)
local worldHud =
	UI.frame(gui, { Name = "WorldHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

-- Счётчики сверху: монеты и ростки
local stats = UI.frame(worldHud, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 54),
	Size = UDim2.fromOffset(280, 42),
	BackgroundColor3 = UI.colors.bg,
	BackgroundTransparency = 0.12,
})
UI.corner(stats, 21)
UI.glass(stats)
local statsScale = Instance.new("UIScale")
statsScale.Parent = stats
local coinIconHolder = UI.frame(stats, {
	Size = UDim2.fromOffset(22, 22),
	Position = UDim2.fromOffset(14, 10),
	BackgroundTransparency = 1,
})
Icons.make("coin", coinIconHolder, UI.colors.gold, UI.colors.goldDark)
local coinsLabel = UI.label(stats, "0", {
	Size = UDim2.new(0.5, -46, 0, 20),
	Position = UDim2.fromOffset(42, 11),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.colors.text,
})
UI.frame(stats, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 1, 0.5, 0),
	BackgroundColor3 = UI.colors.line,
	BackgroundTransparency = 0.8,
})
local sproutIconHolder = UI.frame(stats, {
	Size = UDim2.fromOffset(22, 22),
	Position = UDim2.new(0.5, 14, 0, 10),
	BackgroundTransparency = 1,
})
Icons.make("sprout", sproutIconHolder, UI.colors.green, Color3.fromRGB(120, 200, 110))
local seedsLabel = UI.label(stats, "0", {
	Size = UDim2.new(0.5, -46, 0, 20),
	Position = UDim2.new(0.5, 42, 0, 11),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.colors.text,
})

-- Кнопка с иконкой и подписью: стекло, тонкая рамка, акцентная полоска снизу.
local function iconButton(
	container: Instance,
	name: string,
	label: string,
	iconKey: string,
	accent: Color3,
	size: number,
	order: number
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name .. "Button"
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = UI.colors.bg
	b.BackgroundTransparency = 0.12
	b.LayoutOrder = order
	b.Parent = container
	UI.corner(b, 12)
	UI.glass(b)
	local holder = UI.frame(b, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, size * 0.14),
		Size = UDim2.fromOffset(size * 0.46, size * 0.46),
		BackgroundTransparency = 1,
	})
	Icons.make(iconKey, holder, accent, accent:Lerp(Color3.new(1, 1, 1), 0.35))
	UI.label(b, label, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -size * 0.1),
		Size = UDim2.new(1, -8, 0, size * 0.17),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.text,
	})
	local bar = UI.frame(b, {
		Name = "Accent",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.4, 0, 0, 2),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.4,
	})
	UI.corner(bar, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	return b
end

-- Тост
local toastLabel = UI.label(gui, "", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 158),
	Size = UDim2.new(0.8, 0, 0, 40),
	BackgroundTransparency = 0.1,
	BackgroundColor3 = UI.colors.bg,
	Font = UI.fontRegular,
	Visible = false,
	ZIndex = 40,
})
local toastLimit = Instance.new("UISizeConstraint")
toastLimit.MaxSize = Vector2.new(440, 40)
toastLimit.Parent = toastLabel
UI.corner(toastLabel, 8)
UI.glass(toastLabel)
local toastPad = Instance.new("UIPadding")
toastPad.PaddingTop = UDim.new(0, 10)
toastPad.PaddingBottom = UDim.new(0, 10)
toastPad.Parent = toastLabel
local toastId = 0
local function toast(text: string)
	toastId += 1
	local id = toastId
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(2.2, function()
		if toastId == id then
			toastLabel.Visible = false
		end
	end)
end

-- Панели
local panels = UI.frame(
	gui,
	{ Name = "Panels", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }
)
local screens: { [string]: any } = {}
local current: string? = nil
local navButtons: { [string]: TextButton } = {}

local function close()
	for _, s in screens do
		s.setVisible(false)
	end
	current = nil
	for _, b in navButtons do
		b.BackgroundColor3 = UI.colors.bg
		local accent = b:FindFirstChild("Accent") :: Frame?
		if accent then
			accent.Size = UDim2.new(0.4, 0, 0, 2)
			accent.BackgroundTransparency = 0.4
		end
	end
end

local function open(name: string)
	if State.inRun() then
		return
	end
	if current == name then
		close()
		return
	end
	close()
	local s = screens[name]
	if s then
		s.setVisible(true)
		current = name
		local b = navButtons[name]
		if b then
			b.BackgroundColor3 = UI.colors.panelLight
			local accent = b:FindFirstChild("Accent") :: Frame?
			if accent then
				accent.Size = UDim2.new(0.8, 0, 0, 3)
				accent.BackgroundTransparency = 0
			end
		end
	end
end

local island: any = nil
local ctx = {
	toast = toast,
	open = open,
	close = close,
	celebrate = Effects.confetti,
	hintsEnabled = Guide.enabled,
	revealFrom = function(): number
		return RollReveal.minOrder
	end,
	setRevealFrom = function(order: number)
		RollReveal.minOrder = order
	end,
	setHints = Guide.setEnabled,
	setWorldHud = function(v: boolean)
		worldHud.Visible = v
	end,
	openPicker = function(slot: number)
		island.openPicker(slot)
	end,
}

island = IslandScreen.new(panels, ctx)
screens.Island = island
screens.Roll = RollScreen.new(panels, ctx)
screens.Dungeon = DungeonScreen.new(panels, ctx)
screens.Menu = MenuScreen.new(panels, ctx)
screens.Profile = ProfileScreen.new(panels, ctx)
screens.Shop = ShopScreen.new(panels, ctx)

-- Три главных экрана слева по центру: не мешают джойстику и прыжку
local nav = UI.frame(worldHud, {
	Name = "Nav",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.45, 0),
	Size = UDim2.fromOffset(72, 3 * 80),
	BackgroundTransparency = 1,
})
UI.list(nav, 8)
for i, item in
	{
		{ "Island", "ISLAND", "island", Color3.fromRGB(120, 200, 130) },
		{ "Roll", "ODDS", "odds", Color3.fromRGB(236, 196, 100) },
		{ "Dungeon", "DUNGEON", "dungeon", Color3.fromRGB(170, 140, 240) },
	}
do
	local name = item[1] :: string
	local b = iconButton(nav, name, item[2] :: string, item[3] :: string, item[4] :: Color3, 72, i)
	b.Activated:Connect(function()
		open(name)
	end)
	navButtons[name] = b
end

-- Профиль, меню и перемещение справа сверху
local right = UI.frame(worldHud, {
	Name = "Right",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 54),
	Size = UDim2.fromOffset(2 * 64 + 6, 3 * 64 + 12),
	BackgroundTransparency = 1,
})
local rightGrid = Instance.new("UIGridLayout")
rightGrid.CellSize = UDim2.fromOffset(64, 64)
rightGrid.CellPadding = UDim2.fromOffset(6, 6)
rightGrid.SortOrder = Enum.SortOrder.LayoutOrder
rightGrid.Parent = right
for i, item in
	{
		{ "Shop", "SHOP", "shop", Color3.fromRGB(120, 210, 255) },
		{ "Profile", "PROFILE", "profile", Color3.fromRGB(130, 170, 240) },
		{ "Menu", "MENU", "menu", Color3.fromRGB(190, 196, 210) },
		{ "GoHome", "HOME", "home", Color3.fromRGB(120, 200, 130) },
		{ "GoHub", "HUB", "hub", Color3.fromRGB(170, 140, 240) },
	}
do
	local action = item[1] :: string
	local b =
		iconButton(right, action, item[2] :: string, item[3] :: string, item[4] :: Color3, 64, i)
	b.Activated:Connect(function()
		if action == "Menu" or action == "Profile" or action == "Shop" then
			open(action)
			return
		end
		local res = Net.request(action)
		if not res.ok then
			toast(Net.errorText(res.error))
		end
	end)
	navButtons[action] = if action == "Menu"
			or action == "Profile"
			or action == "Shop"
		then b
		else nil
end

RollReveal.init(gui)
local rollHud = RollHud.new(worldHud, ctx)
-- компактнее на телефонах
UI.autoScale(nav)
UI.autoScale(right)
UI.autoScale(rollHud.root)
AuraFx.start()
OrbitFx.start()
Trailer.bind(gui, RollReveal.show) -- только в Studio, клавиша F8
DungeonHud.new(gui, ctx)
Effects.init(gui)

-- Состояние с сервера
local lastCoins: number? = nil
local function onState(profile: any, meta: any?)
	if type(profile) ~= "table" then
		return
	end
	State.set(profile, meta)
	coinsLabel.Text = UI.formatNumber(profile.coins)
	local seeds = 0
	for _, n in profile.seeds do
		seeds += n
	end
	seedsLabel.Text = UI.formatNumber(seeds)
	if lastCoins and profile.coins > lastCoins then
		statsScale.Scale = 1.06
		TweenService:Create(statsScale, TweenInfo.new(0.2), { Scale = 1 }):Play()
	end
	lastCoins = profile.coins
	for _, s in screens do
		if s.visible() and s.refresh then
			s.refresh(workspace:GetServerTimeNow())
		end
	end
end

Remotes.event("State").OnClientEvent:Connect(onState)
Remotes.event("Dungeon").OnClientEvent:Connect(State.setDungeon)
Remotes.event("Fx").OnClientEvent:Connect(Effects.handle)

-- Объявления о редких находках: в чат и короткой плашкой.
Remotes.event("Announce").OnClientEvent:Connect(function(data: any)
	local tree = Garden.tree(data and data.treeId)
	if not tree then
		return
	end
	local r = Garden.rarity(tree.rarity)
	local text = `{data.name} found {tree.name} ({r.name}, {UI.oneIn(Luck.oneIn(tree.id))})!`
	pcall(function()
		local channel = TextChatService:FindFirstChild("TextChannels")
			and TextChatService.TextChannels:FindFirstChild("RBXSystem") :: TextChannel?
		if channel then
			channel:DisplaySystemMessage(`<font color="{UI.hex(r.color2)}">{text}</font>`)
		end
	end)
	if data.name ~= player.DisplayName then
		toast(text)
	end
end)

task.spawn(function()
	local profile, meta = Remotes.fn("GetState"):InvokeServer()
	if profile then
		onState(profile, meta)
	end
end)

task.spawn(WorldPlots.start, ctx)
Guide.start(gui, rollHud.button)

-- Таймеры в панели острова по серверному времени
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.25 then
		acc = 0
		if island.visible() then
			island.refresh(workspace:GetServerTimeNow())
		end
	end
end)

print("[Garden] client started")
