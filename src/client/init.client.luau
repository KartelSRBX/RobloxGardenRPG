--!strict
-- Точка входа клиента: HUD (монеты, ростки, три главных экрана, меню, крутка),
-- панели, острова в мире, подсказки, эффекты и интерфейс подземелья.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DungeonHud = require(script.DungeonHud)
local DungeonScreen = require(script.DungeonScreen)
local Effects = require(script.Effects)
local Guide = require(script.Guide)
local IslandScreen = require(script.IslandScreen)
local MenuScreen = require(script.MenuScreen)
local Net = require(script.Net)
local RollHud = require(script.RollHud)
local RollScreen = require(script.RollScreen)
local State = require(script.State)
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
	Size = UDim2.fromOffset(300, 44),
	BackgroundColor3 = UI.colors.bg,
	BackgroundTransparency = 0.15,
})
UI.corner(stats, 10)
UI.glass(stats)
local statsScale = Instance.new("UIScale")
statsScale.Parent = stats
UI.coinIcon(stats, 18, { Position = UDim2.fromOffset(14, 13) })
local coinsLabel = UI.label(stats, "0", {
	Size = UDim2.new(0.5, -44, 0, 22),
	Position = UDim2.fromOffset(40, 11),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.colors.gold,
})
local sproutDot = UI.frame(stats, {
	Size = UDim2.fromOffset(14, 14),
	Position = UDim2.new(0.5, 10, 0, 15),
	BackgroundColor3 = UI.colors.green,
	Rotation = 45,
})
UI.corner(sproutDot, 3)
local seedsLabel = UI.label(stats, "0", {
	Size = UDim2.new(0.5, -40, 0, 22),
	Position = UDim2.new(0.5, 34, 0, 11),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.colors.green,
})

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

-- Три главных экрана слева по центру: не мешают джойстику и прыжку
local nav = UI.frame(worldHud, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.45, 0),
	Size = UDim2.fromOffset(96, 3 * 66),
	BackgroundTransparency = 1,
})
UI.list(nav, 8)
for i, item in
	{
		{ "Island", UI.colors.green },
		{ "Roll", UI.colors.gold },
		{ "Dungeon", UI.colors.purple },
	}
do
	local name, color = item[1], item[2]
	local b = UI.button(nav, string.upper(name), UI.colors.bg, {
		Size = UDim2.fromOffset(96, 58),
		LayoutOrder = i,
		BackgroundTransparency = 0.15,
	})
	UI.glass(b)
	UI.frame(b, {
		Size = UDim2.new(0, 3, 0.5, 0),
		Position = UDim2.new(0, -6, 0.25, 0),
		BackgroundColor3 = color,
	})
	b.Activated:Connect(function()
		open(name)
	end)
	navButtons[name] = b
end

-- Меню и быстрые кнопки справа сверху
local right = UI.frame(worldHud, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 54),
	Size = UDim2.fromOffset(84, 3 * 48),
	BackgroundTransparency = 1,
})
UI.list(right, 6)
for i, item in { { "MENU", "Menu" }, { "HOME", "GoHome" }, { "HUB", "GoHub" } } do
	local b = UI.button(right, item[1], UI.colors.bg, {
		Size = UDim2.fromOffset(84, 42),
		LayoutOrder = i,
		BackgroundTransparency = 0.15,
	})
	UI.glass(b)
	b.Activated:Connect(function()
		if item[2] == "Menu" then
			open("Menu")
			return
		end
		local res = Net.request(item[2])
		if not res.ok then
			toast(Net.errorText(res.error))
		end
	end)
end

local rollHud = RollHud.new(worldHud, ctx)
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
