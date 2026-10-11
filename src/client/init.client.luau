--!strict
-- Точка входа клиента: собирает HUD по зонам (см. Hud.luau), панели, острова в мире,
-- подсказки, эффекты, звук и интерфейс подземелья.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AuraFx = require(script.AuraFx)
local CombatFx = require(script.CombatFx)
local DungeonHud = require(script.DungeonHud)
local DungeonScreen = require(script.DungeonScreen)
local Effects = require(script.Effects)
local Guide = require(script.Guide)
local Hud = require(script.Hud)
local IslandScreen = require(script.IslandScreen)
local MenuScreen = require(script.MenuScreen)
local Net = require(script.Net)
local OrbitFx = require(script.OrbitFx)
local ProfileScreen = require(script.ProfileScreen)
local RollHud = require(script.RollHud)
local RollReveal = require(script.RollReveal)
local RollScreen = require(script.RollScreen)
local Sfx = require(script.Sfx)
local ShopScreen = require(script.ShopScreen)
local State = require(script.State)
local Trailer = require(script.Trailer)
local UI = require(script.UI)
local WorldPlots = require(script.WorldPlots)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GardenUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- HUD мира (прячется в подземелье); сами зоны собирает Hud.new
local worldHud =
	UI.frame(gui, { Name = "WorldHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

-- Z9: короткие сообщения по центру
local toastLabel = UI.label(gui, "", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
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
local hud: any = nil
local rollHud: any = nil

local function close()
	for _, s in screens do
		s.setVisible(false)
	end
	current = nil
	if hud then
		hud.setActive(nil)
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
		if hud then
			hud.setActive(name)
		end
	end
end

local island: any = nil
local ctx: any = {
	toast = toast,
	open = open,
	close = close,
	celebrate = Effects.confetti,
	billboardsOn = true,
	setBillboards = function(v: boolean)
		ctx.billboardsOn = v
	end,
	setRollVisible = function(v: boolean)
		if rollHud then
			rollHud.setVisible(v)
		end
	end,
	setWorldHud = function(v: boolean)
		worldHud.Visible = v
	end,
	openPicker = function(slot: number)
		island.openPicker(slot)
	end,
	markSeen = function(_what: string) end,
}

-- Открыть вкладку панели напрямую (кнопки Weapons, Index, Odds)
local function openTab(panelName: string, tab: string)
	if State.inRun() then
		return
	end
	if current ~= panelName then
		close()
		screens[panelName].setVisible(true)
		current = panelName
	end
	screens[panelName].showTab(tab)
end

-- Настройка: сразу применяем у себя и отправляем серверу (сохранится в профиле).
function ctx.setSetting(key: string, value: any)
	local p = State.profile
	if p then
		p.settings[key] = value
		State.set(p)
	end
	task.spawn(Net.request, "SetSetting", key, value)
end

island = IslandScreen.new(panels, ctx)
screens.Island = island
screens.Roll = RollScreen.new(panels, ctx)
screens.Dungeon = DungeonScreen.new(panels, ctx)
screens.Menu = MenuScreen.new(panels, ctx)
screens.Profile = ProfileScreen.new(panels, ctx)
screens.Shop = ShopScreen.new(panels, ctx)

-- HUD по зонам
hud = Hud.new(worldHud, ctx)
for name, key in { Island = "Island", Dungeon = "Dungeon", Shop = "Shop" } do
	hud.menu[key].button.Activated:Connect(function()
		open(name)
	end)
end
hud.menu.Roll.button.Activated:Connect(function()
	openTab("Roll", "Odds")
end)
hud.menu.Weapons.button.Activated:Connect(function()
	openTab("Profile", "Weapons")
end)
hud.menu.Index.button.Activated:Connect(function()
	openTab("Roll", "Index")
	ctx.markSeen("index")
end)
hud.round.Profile.button.Activated:Connect(function()
	open("Profile")
end)
hud.round.Menu.button.Activated:Connect(function()
	open("Menu")
end)
for _, action in { "GoHome", "GoHub" } do
	hud.round[action].button.Activated:Connect(function()
		local res = Net.request(action)
		if not res.ok then
			toast(Net.errorText(res.error))
		end
	end)
end

RollReveal.init(gui)
rollHud = RollHud.new(worldHud, ctx)
UI.autoScale(rollHud.root)
AuraFx.start()
OrbitFx.start()
CombatFx.start()
Sfx.start()
Trailer.bind(gui, RollReveal.show) -- только в Studio, клавиша F8
DungeonHud.new(gui, ctx)
Effects.init(gui)

-- Настройки профиля -> клиент
local function applySettings(profile: any)
	local s = profile.settings
	if type(s) ~= "table" then
		return
	end
	if type(s.hints) == "boolean" then
		Guide.setEnabled(s.hints)
	end
	if type(s.reveal) == "number" then
		RollReveal.minOrder = s.reveal
	end
end

-- Состояние с сервера
local function onState(profile: any, meta: any?)
	if type(profile) ~= "table" then
		return
	end
	State.set(profile, meta)
	applySettings(profile)
	hud.refresh()
	for _, s in screens do
		if s.visible() and s.refresh then
			s.refresh(workspace:GetServerTimeNow())
		end
	end
end

Remotes.event("State").OnClientEvent:Connect(onState)
Remotes.event("Dungeon").OnClientEvent:Connect(State.setDungeon)
Remotes.event("Fx").OnClientEvent:Connect(function(payload: any)
	Effects.handle(payload)
	CombatFx.handle(payload)
end)

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
		Sfx.play("rbxassetid://9116395179", { volume = 0.3, speed = 1.3 })
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

-- Таймеры в панели острова и счётчики HUD по серверному времени
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.5 then
		acc = 0
		if island.visible() then
			island.refresh(workspace:GetServerTimeNow())
		end
		if State.profile and not State.inRun() then
			hud.refresh()
		end
	end
end)

print("[Garden] client started")
