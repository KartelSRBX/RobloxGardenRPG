--!strict
-- Панель «Roll»: три вкладки.
-- Odds — итоговый шанс каждого вида при текущей удаче (сумма 100%), «1 из N».
-- Upgrades — удача и скорость крутилки за монеты, откуда берётся удача, следующая веха.
-- Index — коллекция видов (+1% удачи за каждый открытый).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local R = Config.Roll

local RollScreen = {}

-- Виды от частых к редким.
local sorted = table.clone(Config.Trees)
table.sort(sorted, function(a, b)
	return a.n < b.n
end)

function RollScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "", "Roll", UI.colors.gold, ctx.close)
	local content = panel.content

	-- Вкладки
	local tabsRow = UI.frame(content, { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
	UI.list(tabsRow, 8, true)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local currentTab = "Odds"
	local function showTab(name: string)
		currentTab = name
		for k, page in pages do
			page.Visible = k == name
		end
		for k, b in tabButtons do
			b.BackgroundColor3 = if k == name then UI.colors.gold else UI.colors.panelLight
			b.TextColor3 = if k == name then UI.colors.bg else UI.colors.text
		end
	end
	for i, name in { "Odds", "Upgrades", "Index" } do
		local b = UI.button(tabsRow, string.upper(name), UI.colors.panelLight, {
			Name = name .. "Tab",
			Size = UDim2.new(0.32, -6, 1, 0),
			LayoutOrder = i,
		})
		b.Activated:Connect(function()
			showTab(name)
		end)
		tabButtons[name] = b
		local page = UI.scroll(content, {
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 1, -50),
			Visible = false,
		})
		UI.list(page, 6)
		local pad = Instance.new("UIPadding")
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = page
		pages[name] = page
	end

	-- Odds
	local luckLine = UI.label(pages.Odds, "", {
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.colors.muted,
		Font = UI.fontRegular,
		LayoutOrder = 0,
	})
	local oddsRows: { [string]: { name: TextLabel, pct: TextLabel } } = {}
	for i, t in sorted do
		local r = Garden.rarity(t.rarity)
		local row = UI.frame(pages.Odds, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = i })
		UI.corner(row, 6)
		local stripe =
			UI.frame(row, { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1) })
		UI.paletteGradient(stripe, { r.color, r.color2 }, 90)
		local name = UI.label(row, "", {
			Size = UDim2.new(0.46, -14, 0, 18),
			Position = UDim2.fromOffset(14, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.label(row, `{r.name} · {UI.oneIn(Luck.oneIn(t.id))}`, {
			Size = UDim2.new(0.46, -14, 0, 13),
			Position = UDim2.fromOffset(14, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = r.color,
			Font = UI.fontRegular,
		})
		local pct = UI.label(row, "", {
			Size = UDim2.new(0.5, -12, 0, 20),
			Position = UDim2.new(0.5, 0, 0, 9),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		oddsRows[t.id] = { name = name, pct = pct }
	end
	UI.label(
		pages.Odds,
		"Odds include your current luck. Rolls are free, coins come only from playing.",
		{
			Size = UDim2.new(1, 0, 0, 30),
			TextWrapped = true,
			TextColor3 = UI.colors.muted,
			Font = UI.fontRegular,
			LayoutOrder = 100,
		}
	)

	-- Upgrades
	local function upgradeCard(
		order: number,
		title: string,
		onBuy: () -> ()
	): (TextLabel, TextLabel, TextButton)
		local card =
			UI.frame(pages.Upgrades, { Size = UDim2.new(1, 0, 0, 86), LayoutOrder = order })
		UI.corner(card, 8)
		UI.glass(card)
		UI.label(card, title, {
			Size = UDim2.new(0.6, -14, 0, 22),
			Position = UDim2.fromOffset(14, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local value = UI.label(card, "", {
			Size = UDim2.new(0.6, -14, 0, 18),
			Position = UDim2.fromOffset(14, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.colors.gold,
		})
		local nextLabel = UI.label(card, "", {
			Size = UDim2.new(0.6, -14, 0, 14),
			Position = UDim2.fromOffset(14, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.colors.muted,
			Font = UI.fontRegular,
		})
		local buy = UI.button(card, "", UI.colors.gold, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0.38, -12, 0, 52),
		})
		buy.Activated:Connect(onBuy)
		return value, nextLabel, buy
	end
	local function buy(name: string)
		return function()
			local res = Net.request(name)
			if not res.ok then
				ctx.toast(Net.errorText(res.error))
			end
		end
	end
	local luckValue, luckNext, luckBuy = upgradeCard(1, "Luck", buy("BuyLuck"))
	local speedValue, speedNext, speedBuy = upgradeCard(2, "Roll speed", buy("BuySpeed"))

	local sources = UI.frame(pages.Upgrades, { Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 3 })
	UI.corner(sources, 8)
	UI.glass(sources)
	UI.pad(sources, 12)
	local srcList = UI.list(sources, 6)
	srcList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local srcLabels: { TextLabel } = {}
	for i = 1, 5 do
		srcLabels[i] = UI.label(sources, "", {
			Size = UDim2.new(1, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = if i == 1 then UI.font else UI.fontRegular,
			TextColor3 = if i == 1 then UI.colors.text else UI.colors.muted,
			LayoutOrder = i,
		})
	end

	-- Index
	local indexHeader = UI.label(pages.Index, "", {
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})
	local grid = UI.frame(pages.Index, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.25, -6, 0, 70)
	gl.CellPadding = UDim2.fromOffset(6, 6)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local indexCells: { [string]: { frame: Frame, name: TextLabel } } = {}
	for i, t in sorted do
		local r = Garden.rarity(t.rarity)
		local cell = UI.frame(grid, { LayoutOrder = i, BackgroundColor3 = UI.colors.panel })
		UI.corner(cell, 6)
		UI.stroke(cell, r.color, 1.5, 0.3)
		local name = UI.label(cell, "", {
			Size = UDim2.new(1, -8, 0, 32),
			Position = UDim2.fromOffset(4, 8),
			TextWrapped = true,
		})
		UI.label(cell, UI.oneIn(Luck.oneIn(t.id)), {
			Size = UDim2.new(1, -8, 0, 14),
			Position = UDim2.new(0, 4, 1, -22),
			TextColor3 = r.color,
			Font = UI.fontRegular,
		})
		indexCells[t.id] = { frame = cell, name = name }
	end

	local screen = {}

	function screen.refresh()
		local profile = State.profile
		if not profile or not panel.visible() then
			return
		end
		local b = Luck.breakdown(profile)
		local chances = Luck.chances(b.total)
		local found = profile.found or {}
		luckLine.Text = string.format(
			"Luck x%.2f · every %dth roll x%d · roll #%d",
			b.total,
			R.luckyEvery,
			R.luckyMult,
			profile.rolls + 1
		)
		for id, row in oddsRows do
			local t = Garden.tree(id) :: Garden.Tree
			row.name.Text = if found[id] then t.name else "???"
			row.pct.Text = UI.percent(chances[id] * 100)
		end

		-- улучшения
		local luckCost = Luck.luckCost(profile.luckLevel)
		luckValue.Text = string.format(
			"Lv %d · +%d%% luck",
			profile.luckLevel,
			math.floor(b.upgrade * 100 + 0.5)
		)
		luckNext.Text = `+{math.floor(R.luckStep * 100)}% per level`
		luckBuy.Text = if luckCost then UI.formatNumber(luckCost) else "MAX"
		luckBuy.BackgroundColor3 = if luckCost and profile.coins >= luckCost
			then UI.colors.gold
			else UI.colors.disabled
		local speedCost = Luck.speedCost(profile.speedLevel)
		speedValue.Text = string.format("%.1fs per roll", Luck.cooldown(profile))
		speedNext.Text = string.format("-%.1fs per level, min %.1fs", R.speedStep, R.minCooldown)
		speedBuy.Text = if speedCost then UI.formatNumber(speedCost) else "MAX"
		speedBuy.BackgroundColor3 = if speedCost and profile.coins >= speedCost
			then UI.colors.gold
			else UI.colors.disabled
		srcLabels[1].Text = string.format("Total luck x%.2f", b.total)
		srcLabels[2].Text = string.format("Rolls milestones +%d%%", math.floor(b.rolls * 100 + 0.5))
		srcLabels[3].Text = string.format("Luck upgrade +%d%%", math.floor(b.upgrade * 100 + 0.5))
		srcLabels[4].Text = string.format("Index +%d%%", math.floor(b.index * 100 + 0.5))
		local nm = b.nextMilestone
		srcLabels[5].Text = if nm
			then string.format(
				"Next: %s rolls = +%d%% (%s to go)",
				UI.formatNumber(nm[1]),
				math.floor(nm[2] * 100),
				UI.formatNumber(nm[1] - profile.rolls)
			)
			else "All roll milestones reached"

		-- коллекция
		local count = 0
		for id, cell in indexCells do
			local t = Garden.tree(id) :: Garden.Tree
			if found[id] then
				count += 1
				cell.name.Text = t.name
				cell.name.TextColor3 = UI.colors.text
				cell.frame.BackgroundColor3 = Color3.new(1, 1, 1)
				if not cell.frame:FindFirstChild("Glow") then
					local dark = {}
					for k, c in Garden.aura(id).palette do
						dark[k] = c:Lerp(Color3.new(0, 0, 0), 0.55)
					end
					UI.paletteGradient(cell.frame, dark, 35).Name = "Glow"
				end
			else
				cell.name.Text = "???"
				cell.name.TextColor3 = UI.colors.muted
				cell.frame.BackgroundColor3 = UI.colors.panel
			end
		end
		indexHeader.Text =
			`Discovered {count}/{#Config.Trees} · +{math.floor(b.index * 100 + 0.5)}% luck`
	end

	function screen.setVisible(v: boolean)
		panel.setVisible(v)
		if v then
			showTab(currentTab)
			screen.refresh()
		end
	end

	screen.visible = panel.visible
	screen.showTab = function(name: string)
		showTab(name)
		screen.refresh()
	end
	return screen
end

return RollScreen
