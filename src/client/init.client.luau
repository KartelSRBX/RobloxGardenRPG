--!strict
-- Точка входа клиента: HUD (монеты, три главных экрана, меню), панели, сад в мире,
-- подсказки, эффекты и интерфейс подземелья.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DungeonHud = require(script.DungeonHud)
local DungeonScreen = require(script.DungeonScreen)
local Effects = require(script.Effects)
local GardenScreen = require(script.GardenScreen)
local Guide = require(script.Guide)
local MenuScreen = require(script.MenuScreen)
local SpinScreen = require(script.SpinScreen)
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

-- Монеты
local coinsPill = UI.frame(worldHud, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(230, 54),
	BackgroundColor3 = UI.colors.bg,
	BackgroundTransparency = 0.05,
})
UI.corner(coinsPill, 27)
UI.stroke(coinsPill, UI.colors.gold, 3)
local coinsScale = Instance.new("UIScale")
coinsScale.Parent = coinsPill
local coinIcon = UI.label(
	coinsPill,
	"💰",
	{ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 5) }
)
coinIcon.TextScaled = true
local coinsLabel = UI.label(coinsPill, "...", {
	Size = UDim2.new(1, -64, 1, -14),
	Position = UDim2.fromOffset(54, 7),
	TextColor3 = UI.colors.gold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
UI.textStroke(coinsLabel, 2)

-- Тост
local toastLabel = UI.label(gui, "", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 176),
	Size = UDim2.new(0.8, 0, 0, 48),
	BackgroundTransparency = 0.1,
	BackgroundColor3 = UI.colors.bg,
	Visible = false,
	ZIndex = 40,
})
local toastLimit = Instance.new("UISizeConstraint")
toastLimit.MaxSize = Vector2.new(520, 48)
toastLimit.Parent = toastLabel
UI.corner(toastLabel, 24)
UI.stroke(toastLabel, UI.colors.blue, 2)
local toastPad = Instance.new("UIPadding")
toastPad.PaddingTop = UDim.new(0, 8)
toastPad.PaddingBottom = UDim.new(0, 8)
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
		b.BackgroundColor3 = b:GetAttribute("Color") :: Color3
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
			b.BackgroundColor3 = UI.colors.text
		end
	end
end

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
	openPicker = function(_slot: number) end,
}

local garden = GardenScreen.new(panels, ctx)
screens.Garden = garden
screens.Spin = SpinScreen.new(panels, ctx)
screens.Dungeon = DungeonScreen.new(panels, ctx)
screens.Menu = MenuScreen.new(panels, ctx)
ctx.openPicker = function(slot: number)
	close()
	garden.setVisible(true)
	current = "Garden"
	garden.openPicker(slot)
end

-- Три главных экрана: крупные кнопки слева по центру (не мешают джойстику и прыжку)
local nav = UI.frame(worldHud, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(92, 3 * 104),
	BackgroundTransparency = 1,
})
UI.list(nav, 10)
for i, item in
	{
		{ "Garden", "🌳", UI.colors.green },
		{ "Spin", "🎲", UI.colors.gold },
		{ "Dungeon", "⚔️", UI.colors.purple },
	}
do
	local name, icon, color = item[1], item[2], item[3]
	local b = UI.button(nav, "", color, { Size = UDim2.fromOffset(88, 88), LayoutOrder = i })
	b:SetAttribute("Color", color)
	UI.stroke(b, Color3.new(1, 1, 1), 3)
	local iconLabel = UI.label(b, icon, { Size = UDim2.new(1, 0, 0.7, 0) })
	iconLabel.TextScaled = true
	local text = UI.label(b, name, {
		Size = UDim2.new(1, 8, 0.38, 0),
		Position = UDim2.new(0, -4, 0.78, 0),
	})
	UI.textStroke(text, 2)
	b.Activated:Connect(function()
		open(name)
	end)
	navButtons[name] = b
end

-- Меню справа сверху
local menuButton = UI.button(worldHud, "⚙️", UI.colors.blue, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 52),
	Size = UDim2.fromOffset(64, 64),
	TextSize = 36,
	TextScaled = false,
})
UI.stroke(menuButton, Color3.new(1, 1, 1), 3)
menuButton.Activated:Connect(function()
	open("Menu")
end)

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
	if lastCoins and profile.coins > lastCoins then
		coinsScale.Scale = 1.2
		TweenService:Create(coinsScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
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

WorldPlots.start(ctx)
Guide.start(gui)

-- Таймеры в панели сада по серверному времени
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.25 then
		acc = 0
		if garden.visible() then
			garden.refresh(workspace:GetServerTimeNow())
		end
	end
end)

print("[Garden] client started")
