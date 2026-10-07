--!strict
-- Панель «Menu»: как играть, магазин (только предсказуемые покупки), статистика, настройки.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

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

	-- Магазин: цена видна сразу, рандома за Robux нет
	heading("Shop")
	local shopRows: { () -> () } = {}
	for _, pass in Config.GamePasses do
		local row = box(84)
		UI.label(row, pass.name, {
			Size = UDim2.new(0.62, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.label(row, pass.desc, {
			Size = UDim2.new(0.62, 0, 0, 24),
			Position = UDim2.fromOffset(0, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.colors.muted,
		})
		local buy = UI.button(row, "Soon", UI.colors.disabled, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0.36, 0, 0, 56),
		})
		local price: number? = nil
		buy.Activated:Connect(function()
			if pass.id ~= 0 and not State.passes[pass.key] then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
		local function refreshRow()
			if State.passes[pass.key] then
				buy.Text = "Owned "
				buy.BackgroundColor3 = UI.colors.greenDark
			elseif pass.id == 0 then
				buy.Text = "Soon"
				buy.BackgroundColor3 = UI.colors.disabled
			else
				buy.Text = if price then `R$ {price}` else "..."
				buy.BackgroundColor3 = UI.colors.green
			end
		end
		table.insert(shopRows, refreshRow)
		if pass.id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(
					MarketplaceService.GetProductInfo,
					MarketplaceService,
					pass.id,
					Enum.InfoType.GamePass
				)
				if ok and info and info.PriceInRobux then
					price = info.PriceInRobux
					refreshRow()
				end
			end)
		end
	end

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
