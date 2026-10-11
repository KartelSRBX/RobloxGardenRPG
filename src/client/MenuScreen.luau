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

	-- Настройки: хранятся в профиле, поэтому сохраняются между заходами
	heading("Settings")
	local settingToggles: { [string]: (any) -> () } = {}

	local function settingRow(title: string, key: string, kind: string)
		local row = box(64)
		UI.label(row, title, {
			Size = UDim2.new(0.55, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local b = UI.button(row, "", UI.colors.green, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0.38, 0, 0, 44),
		})
		local function show(value: any)
			if kind == "bool" then
				b.Text = if value then "ON" else "OFF"
				b.BackgroundColor3 = if value then UI.colors.green else Color3.fromRGB(150, 70, 70)
			elseif kind == "volume" then
				local v = value :: number
				b.Text = if v <= 0 then "OFF" else `{math.floor(v * 100 + 0.5)}%`
				b.BackgroundColor3 = if v <= 0 then Color3.fromRGB(150, 70, 70) else UI.colors.green
			else
				local r = Config.Rarities[value]
				b.Text = if r then string.upper(r.name) else "?"
				b.BackgroundColor3 = UI.colors.panelLight
			end
		end
		settingToggles[key] = show
		b.Activated:Connect(function()
			local current = (State.profile and State.profile.settings or {})[key]
			local nextValue: any
			if kind == "bool" then
				nextValue = not current
			elseif kind == "volume" then
				local steps = { 0, 0.33, 0.66, 1 }
				local idx = 1
				for i, v in steps do
					if math.abs(v - (current or 1)) < 0.05 then
						idx = i
					end
				end
				nextValue = steps[idx % #steps + 1]
			else
				-- Rare -> Epic -> Legendary -> Mythic -> Divine -> Rare
				nextValue = (current or 3) + 1
				if nextValue > 7 then
					nextValue = 3
				end
			end
			ctx.setSetting(key, nextValue)
			show(nextValue)
		end)
	end
	settingRow("Music and ambience", "music", "volume")
	settingRow("Sound effects", "sfx", "volume")
	settingRow("Hint arrow", "hints", "bool")
	settingRow("Roll animation from", "reveal", "rarity")

	local screen = {}

	function screen.refresh()
		for _, fn in shopRows do
			fn()
		end
		local profile = State.profile
		if profile then
			for key, show in settingToggles do
				show(profile.settings[key])
			end
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
