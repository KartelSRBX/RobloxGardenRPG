--!strict
-- Точка входа клиента: монеты сверху, три главных экрана снизу (Сад, Крутилка, Подземелье).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.UI)
local GardenScreen = require(script.GardenScreen)
local SpinScreen = require(script.SpinScreen)

local player = Players.LocalPlayer

-- Понятные тексты для кодов ошибок сервера.
local ERRORS: { [string]: string } = {
	not_enough_coins = "Not enough coins",
	not_loaded = "Loading...",
	too_fast = "Slow down!",
	not_ready = "Not ready yet",
	max_level = "Max level!",
	no_seed = "No seed",
	occupied = "Plot is busy",
}

local gui = Instance.new("ScreenGui")
gui.Name = "GardenUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Монеты.
local top = UI.frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.new(0, 220, 0, 52),
	BackgroundColor3 = UI.colors.bg,
})
UI.corner(top, 26)
UI.stroke(top, UI.colors.gold)
local coinsLabel = UI.label(top, "...", {
	Size = UDim2.new(1, -24, 1, -12),
	Position = UDim2.fromOffset(12, 6),
	TextColor3 = UI.colors.gold,
})

-- Область экранов.
local pages = UI.frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 108),
	Size = UDim2.new(1, -24, 1, -108 - 100),
	BackgroundTransparency = 1,
})
local maxWidth = Instance.new("UISizeConstraint")
maxWidth.MaxSize = Vector2.new(640, math.huge)
maxWidth.Parent = pages

-- Всплывающие сообщения.
local toastLabel = UI.label(gui, "", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -104),
	Size = UDim2.new(0.8, 0, 0, 44),
	BackgroundTransparency = 0.2,
	BackgroundColor3 = UI.colors.bg,
	Visible = false,
	ZIndex = 20,
})
UI.corner(toastLabel)
local toastId = 0
local function toast(text: string)
	toastId += 1
	local id = toastId
	toastLabel.Text = ERRORS[text] or text
	toastLabel.Visible = true
	task.delay(2, function()
		if toastId == id then
			toastLabel.Visible = false
		end
	end)
end

local function request(name: string, ...: any): { [string]: any }
	local ok, res = pcall(Remotes.fn(name).InvokeServer, Remotes.fn(name), ...)
	if ok and type(res) == "table" then
		return res
	end
	return { ok = false, error = "Connection problem" }
end

-- Нижняя панель: три главных экрана.
local nav = UI.frame(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -24, 0, 80),
	BackgroundTransparency = 1,
})
local navMax = Instance.new("UISizeConstraint")
navMax.MaxSize = Vector2.new(640, math.huge)
navMax.Parent = nav
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0.02, 0)
navLayout.Parent = nav

local screens: { [string]: { setVisible: (boolean) -> () } } = {}
local tabs: { [string]: TextButton } = {}

local function open(name: string)
	for key, screen in screens do
		screen.setVisible(key == name)
	end
	for key, tab in tabs do
		tab.BackgroundColor3 = if key == name then UI.colors.blue else UI.colors.panel
	end
end

local garden = GardenScreen.new(pages, {
	request = request,
	toast = toast,
	openSpin = function()
		open("Spin")
	end,
})
local spin = SpinScreen.new(pages, { request = request, toast = toast })
screens.Garden = garden
screens.Spin = spin

for i, name in { "Garden", "Spin", "Dungeon" } do
	local tab = UI.button(nav, name, UI.colors.panel, {
		Size = UDim2.fromScale(0.32, 1),
		LayoutOrder = i,
	})
	tabs[name] = tab
	tab.Activated:Connect(function()
		if name == "Dungeon" then
			toast("Dungeon is coming soon!")
			return
		end
		open(name)
	end)
end
tabs.Dungeon.TextTransparency = 0.5

local function onState(profile: any)
	coinsLabel.Text = UI.formatNumber(profile.coins) .. " coins"
	garden.setProfile(profile)
	spin.setProfile(profile)
end

Remotes.event("State").OnClientEvent:Connect(onState)
open("Garden")
task.spawn(function()
	local profile = Remotes.fn("GetState"):InvokeServer()
	if profile then
		onState(profile)
	end
end)

-- Таймеры роста по серверному времени.
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.2 then
		acc = 0
		garden.tick(workspace:GetServerTimeNow())
	end
end)

print("[Garden] client started")
