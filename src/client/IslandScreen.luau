--!strict
-- Панель «Island»: грядки (таймер, сбор, прокачка за монеты, удобрение), запас ростков
-- для посадки и расширение острова (время в игре, монеты, ростки).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local IslandScreen = {}

local function seedTotal(profile: any): number
	local n = 0
	for _, c in profile.seeds do
		n += c
	end
	return n
end

function IslandScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "", "Island", UI.colors.green, ctx.close)
	local scroll = UI.scroll(panel.content)
	UI.list(scroll, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	-- Расширение острова
	local expand = UI.frame(scroll, { Size = UDim2.new(1, 0, 0, 176), LayoutOrder = 1 })
	UI.corner(expand, 8)
	UI.glass(expand)
	local expandTitle = UI.label(expand, "", {
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.fromOffset(14, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local reqRows: { { label: TextLabel, set: (number, Color3?) -> () } } = {}
	for i = 1, 3 do
		local y = 40 + (i - 1) * 30
		local label = UI.label(expand, "", {
			Size = UDim2.new(0.5, -14, 0, 16),
			Position = UDim2.fromOffset(14, y),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		local set = UI.bar(expand, {
			Size = UDim2.new(0.5, -14, 0, 8),
			Position = UDim2.new(0.5, 0, 0, y + 4),
		})
		reqRows[i] = { label = label, set = set }
	end
	local expandButton = UI.button(expand, "EXPAND", UI.colors.green, {
		Size = UDim2.new(1, -28, 0, 44),
		Position = UDim2.fromOffset(14, 124),
	})
	expandButton.Activated:Connect(function()
		local res = Net.request("Expand")
		if res.ok then
			ctx.toast("Island expanded! New plot unlocked")
			ctx.celebrate(UI.colors.green)
		else
			ctx.toast(Net.errorText(res.error))
		end
	end)

	-- Кнопки перемещения
	local travel = UI.frame(
		scroll,
		{ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 2 }
	)
	UI.list(travel, 8, true)
	for i, item in { { "HOME", "GoHome" }, { "HUB", "GoHub" } } do
		local b = UI.button(
			travel,
			item[1],
			UI.colors.panelLight,
			{ Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = i }
		)
		UI.glass(b)
		b.Activated:Connect(function()
			local res = Net.request(item[2])
			if res.ok then
				ctx.close()
			else
				ctx.toast(Net.errorText(res.error))
			end
		end)
	end

	local plotsHeader = UI.label(scroll, "", {
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
	})
	local grid = UI.frame(scroll, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	})
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.5, -5, 0, 168)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid

	-- Выбор ростка
	local picker = UI.frame(panel.root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.02,
		Visible = false,
		ZIndex = 20,
	})
	UI.corner(picker, 12)
	UI.label(picker, "CHOOSE A SPROUT", {
		Size = UDim2.new(1, -100, 0, 24),
		Position = UDim2.fromOffset(18, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	local pickerBack = UI.button(picker, "X", UI.colors.panelLight, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(44, 40),
		ZIndex = 22,
	})
	pickerBack.Activated:Connect(function()
		picker.Visible = false
	end)
	local pickerList = UI.scroll(picker, {
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -74),
		ZIndex = 21,
	})
	UI.list(pickerList, 6)

	local function openPicker(slot: number)
		local profile = State.profile
		for _, c in pickerList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		-- купленные эксклюзивы, которые ещё не посажены
		local planted: { [string]: boolean } = {}
		for _, plot in profile.plots do
			if plot.plantId then
				planted[plot.plantId] = true
			end
		end
		local premium = {}
		for _, pass in Config.GamePasses do
			local treeId = (pass :: any).treeId
			if treeId and State.passes[pass.key] and not planted[treeId] then
				table.insert(premium, treeId)
			end
		end
		for i, id in premium do
			local t = Garden.tree(id) :: any
			local palette = Garden.aura(id).palette
			local b = UI.button(pickerList, "", Color3.new(1, 1, 1), {
				Size = UDim2.new(1, -8, 0, 58),
				LayoutOrder = i,
				ZIndex = 22,
			})
			UI.paletteGradient(b, {
				palette[1]:Lerp(Color3.new(0, 0, 0), 0.55),
				palette[2]:Lerp(Color3.new(0, 0, 0), 0.65),
			}, 20)
			UI.shimmer(UI.paletteGradient(UI.stroke(b, Color3.new(1, 1, 1), 2), palette, 45), 1.2)
			UI.label(b, `{t.name} · EXCLUSIVE`, {
				Size = UDim2.new(0.65, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 23,
			})
			UI.label(b, `{UI.formatNumber(Garden.baseIncome(t))}/min`, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.35, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = palette[1],
				ZIndex = 23,
			})
			b.Activated:Connect(function()
				picker.Visible = false
				local res = Net.request("Plant", slot, id)
				if not res.ok then
					ctx.toast(Net.errorText(res.error))
				end
			end)
		end

		local ids = {}
		for id, count in profile.seeds do
			if count > 0 and Garden.tree(id) then
				table.insert(ids, id)
			end
		end
		if #ids == 0 and #premium == 0 then
			ctx.toast("No sprouts yet. Roll for one!")
			return
		end
		table.sort(ids, function(a, b)
			return (Garden.tree(a) :: Garden.Tree).n > (Garden.tree(b) :: Garden.Tree).n
		end)
		for k, id in ids do
			local i = #premium + k
			local t = Garden.tree(id) :: Garden.Tree
			local r = Garden.rarity(t.rarity)
			local b = UI.button(pickerList, "", UI.colors.panel, {
				Size = UDim2.new(1, -8, 0, 54),
				LayoutOrder = i,
				ZIndex = 22,
			})
			UI.stroke(b, r.color, 1.5, 0.2)
			UI.label(b, `{t.name}  x{profile.seeds[id]}`, {
				Size = UDim2.new(0.6, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 23,
			})
			UI.label(b, `{UI.formatNumber(Garden.baseIncome(t))}/min`, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = r.color,
				ZIndex = 23,
			})
			b.Activated:Connect(function()
				picker.Visible = false
				local res = Net.request("Plant", slot, id)
				if not res.ok then
					ctx.toast(Net.errorText(res.error))
				end
			end)
		end
		picker.Visible = true
	end

	local cards: { (number) -> () } = {}

	local function makeCard(slot: number): (number) -> ()
		local card = UI.frame(grid, { LayoutOrder = slot, BackgroundColor3 = UI.colors.panel })
		UI.corner(card, 8)
		local stroke = UI.stroke(card, UI.colors.line, 1, 0.88)
		local title = UI.label(card, "", {
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.fromOffset(10, 10),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local info = UI.label(card, "", {
			Size = UDim2.new(1, -20, 0, 14),
			Position = UDim2.fromOffset(10, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		local timer = UI.label(card, "", {
			Size = UDim2.new(1, -20, 0, 14),
			Position = UDim2.fromOffset(10, 54),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
		})
		local setBar =
			UI.bar(card, { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 74) })
		local main = UI.button(card, "", UI.colors.green, {
			Size = UDim2.new(1, -20, 0, 36),
			Position = UDim2.fromOffset(10, 88),
		})
		local upgrade = UI.button(card, "", UI.colors.blue, {
			Size = UDim2.new(0.5, -14, 0, 34),
			Position = UDim2.fromOffset(10, 128),
		})
		local fert = UI.button(card, "FERT", UI.colors.purple, {
			Size = UDim2.new(0.25, -6, 0, 34),
			Position = UDim2.new(0.5, 0, 0, 128),
		})
		local remove = UI.button(card, "X", UI.colors.panelLight, {
			Size = UDim2.new(0.25, -10, 0, 34),
			Position = UDim2.new(0.75, 0, 0, 128),
		})
		local confirmUntil = 0

		main.Activated:Connect(function()
			local plot = State.profile.plots[slot]
			if not plot.plantId then
				openPicker(slot)
				return
			end
			local res = Net.request("Harvest", slot)
			if not res.ok and res.error ~= "not_ready" then
				ctx.toast(Net.errorText(res.error))
			end
		end)
		upgrade.Activated:Connect(function()
			local res = Net.request("Upgrade", slot)
			if not res.ok then
				ctx.toast(Net.errorText(res.error))
			end
		end)
		fert.Activated:Connect(function()
			local res = Net.request("Fertilize", slot)
			ctx.toast(if res.ok then "Growth boosted" else Net.errorText(res.error))
		end)
		remove.Activated:Connect(function()
			-- выкопать можно только вторым нажатием
			if os.clock() > confirmUntil then
				confirmUntil = os.clock() + 3
				remove.Text = "SURE?"
				return
			end
			confirmUntil = 0
			local res = Net.request("Remove", slot)
			if not res.ok then
				ctx.toast(Net.errorText(res.error))
			end
		end)

		return function(now: number)
			local profile = State.profile
			local plot = profile.plots[slot]
			card.Visible = plot ~= nil
			if not plot then
				return
			end
			if os.clock() > confirmUntil then
				remove.Text = "X"
			end
			local tree = Garden.tree(plot.plantId)
			if not tree then
				stroke.Color = UI.colors.line
				stroke.Transparency = 0.88
				title.Text = "Empty plot"
				title.TextColor3 = UI.colors.muted
				info.Text = `{seedTotal(profile)} sprouts in storage`
				timer.Text = ""
				setBar(0)
				main.Text = "PLANT"
				main.BackgroundColor3 = UI.colors.green
				upgrade.Visible = false
				fert.Visible = false
				remove.Visible = false
				return
			end
			local r = Garden.rarity(tree.rarity)
			stroke.Color = r.color
			stroke.Transparency = 0.2
			title.Text = tree.name
			title.TextColor3 = r.color
			local m = Garden.mutation(plot.mutation)
			info.Text = `Lv {plot.level} · {UI.formatNumber(
				Garden.incomePerMinute(tree, plot.level)
			)}/min` .. (if m then ` · {m.name}` else "")
			local total = Garden.growTime(tree)
			local left = (Garden.readyAt(plot) :: number) - now
			local ready = left <= 0
			setBar(1 - left / total, if ready then UI.colors.gold else UI.colors.green)
			timer.Text = if ready
				then `Ready · {UI.formatNumber(
					Garden.harvestValue(tree, plot.level, plot.mutation)
				)} coins`
				else UI.formatTime(left)
			timer.TextColor3 = if ready then UI.colors.gold else UI.colors.text
			main.Text = if ready then "HARVEST" else "GROWING"
			main.BackgroundColor3 = if ready then UI.colors.gold else UI.colors.disabled
			main.TextColor3 = if ready then UI.colors.bg else UI.colors.text
			upgrade.Visible = true
			remove.Visible = true
			local fertilizer = profile.items.fertilizer or 0
			fert.Visible = not ready
			fert.Text = `F x{fertilizer}`
			fert.BackgroundColor3 = if fertilizer > 0 then UI.colors.purple else UI.colors.disabled
			local cost = Garden.upgradeCost(tree, plot.level)
			if cost then
				upgrade.Text = `UP {UI.formatNumber(cost)}`
				upgrade.BackgroundColor3 = if profile.coins >= cost
					then UI.colors.blue
					else UI.colors.disabled
			else
				upgrade.Text = "MAX"
				upgrade.BackgroundColor3 = UI.colors.disabled
			end
		end
	end

	local screen = {}

	function screen.refresh(now: number)
		local profile = State.profile
		if not profile or not panel.visible() then
			return
		end
		while #cards < #profile.plots do
			table.insert(cards, makeCard(#cards + 1))
		end
		for _, update in cards do
			update(now)
		end
		local income = 0
		for _, plot in profile.plots do
			local t = Garden.tree(plot.plantId)
			if t then
				income += Garden.incomePerMinute(t, plot.level)
			end
		end
		plotsHeader.Text = `PLOTS {#profile.plots} · {UI.formatNumber(income)} coins/min`

		local nextTier = Garden.nextIsland(profile.islandTier)
		if not nextTier then
			expandTitle.Text = `Island level {profile.islandTier} · max size`
			for _, row in reqRows do
				row.label.Text = ""
				row.set(1, UI.colors.green)
			end
			expandButton.Visible = false
			return
		end
		expandTitle.Text =
			`Island level {profile.islandTier} to {profile.islandTier + 1} · {nextTier.plots} plots`
		local minutes = profile.playSeconds / 60
		local seeds = seedTotal(profile)
		local reqs = {
			{
				`Time played {math.floor(minutes)}/{nextTier.minutes} min`,
				minutes / math.max(1, nextTier.minutes),
			},
			{
				`Coins {UI.formatNumber(profile.coins)}/{UI.formatNumber(nextTier.coins)}`,
				profile.coins / math.max(1, nextTier.coins),
			},
			{ `Sprouts {seeds}/{nextTier.seeds}`, seeds / math.max(1, nextTier.seeds) },
		}
		local all = true
		for i, req in reqs do
			local done = req[2] >= 1
			all = all and done
			reqRows[i].label.Text = req[1]
			reqRows[i].label.TextColor3 = if done then UI.colors.green else UI.colors.muted
			reqRows[i].set(req[2], if done then UI.colors.green else UI.colors.blue)
		end
		expandButton.Visible = true
		expandButton.BackgroundColor3 = if all then UI.colors.green else UI.colors.disabled
	end

	function screen.setVisible(v: boolean)
		panel.setVisible(v)
		if not v then
			picker.Visible = false
		else
			screen.refresh(workspace:GetServerTimeNow())
		end
	end

	screen.visible = panel.visible
	screen.openPicker = function(slot: number)
		if not panel.visible() then
			ctx.open("Island")
		end
		openPicker(slot)
	end
	return screen
end

return IslandScreen
