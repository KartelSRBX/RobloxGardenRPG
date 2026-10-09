--!strict
-- Панель «Menu»: как играть, вход в магазин, статистика, настройки.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local MenuScreen = {}

function MenuScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "", "Menu", UI.colors.blue, ctx.close)
	local scroll = UI.scroll(panel.content)
	UI.list(scroll, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	local order = 0
	local function heading(text: string)
		order += 1
		local l = UI.label(scroll, text, {
			Size = UDim2.new(1, -8, 0, 34),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.textStroke(l)
	end
	local function box(height: number): Frame
		order += 1
		local f = UI.frame(scroll, { Size = UDim2.new(1, -8, 0, height), LayoutOrder = order })
		UI.corner(f, 14)
		UI.pad(f, 10)
		return f
	end

	-- Как играть
	heading("How to play")
	local how = box(4 * 34 + 20)
	local howList = UI.list(how, 6)
	howList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	for i, line in
		{
			"Roll for free to get tree sprouts",
			"Plant sprouts on your island",
			"Harvest for coins, upgrade trees and luck",
			"Expand your island, clear the Dungeon",
		}
	do
		UI.label(how, line, {
			Size = UDim2.new(1, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		})
	end

	-- Магазин переехал в отдельную панель (кнопка SHOP)
	heading("Shop")
	order += 1
	local openShop = UI.button(scroll, "OPEN SHOP", UI.colors.blue, {
		Size = UDim2.new(1, -8, 0, 48),
		LayoutOrder = order,
	})
	openShop.Activated:Connect(function()
		ctx.open("Shop")
	end)
	local shopRows: { () -> () } = {}

	-- Статистика
	heading("Stats")
	local stats = box(3 * 32 + 20)
	local statsList = UI.list(stats, 4)
	statsList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local statLabels: { [string]: TextLabel } = {}
	for i, s in
		{
			{ "harvests", "Harvests" },
			{ "runs", "Dungeon runs" },
			{ "bestWave", "Best wave" },
		}
	do
		statLabels[s[1]] = UI.label(stats, s[2], {
			Size = UDim2.new(1, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			Name = s[2],
		})
	end

	-- Настройки
	heading("Settings")
	local settings = box(76)
	UI.label(settings, "Hint arrow", {
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local hints = UI.button(settings, "ON", UI.colors.green, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0.36, 0, 0, 52),
	})
	hints.Activated:Connect(function()
		local on = not ctx.hintsEnabled()
		ctx.setHints(on)
		hints.Text = if on then "ON" else "OFF"
		hints.BackgroundColor3 = if on then UI.colors.green else UI.colors.disabled
	end)

	-- С какой редкости показывать большую анимацию выпадения (новые виды — всегда).
	local reveal = box(76)
	UI.label(reveal, "Roll animation from", {
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local revealButton = UI.button(reveal, "", UI.colors.panelLight, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0.36, 0, 0, 52),
	})
	local function revealText()
		local r = Config.Rarities[ctx.revealFrom()]
		revealButton.Text = if r then string.upper(r.name) else "OFF"
	end
	revealText()
	revealButton.Activated:Connect(function()
		-- Rare -> Epic -> Legendary -> Mythic -> Rare
		local nextOrder = ctx.revealFrom() + 1
		if nextOrder > 6 then
			nextOrder = 3
		end
		ctx.setRevealFrom(nextOrder)
		revealText()
	end)

	local screen = {}

	function screen.refresh()
		for _, fn in shopRows do
			fn()
		end
		local profile = State.profile
		if profile then
			local st = profile.stats or {}
			for key, label in statLabels do
				label.Text = `{label.Name}: {st[key] or 0}`
			end
		end
	end

	function screen.setVisible(v: boolean)
		panel.setVisible(v)
		if v then
			screen.refresh()
		end
	end

	screen.visible = panel.visible
	return screen
end

return MenuScreen
