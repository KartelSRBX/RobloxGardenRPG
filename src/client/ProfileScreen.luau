--!strict
-- Панель «Profile»: персонаж и инвентарь.
-- Character — 3D-превью аватара, статистика, надетое сияние.
-- Auras — выбор сияния из открытых видов (косметика).
-- Sprouts — ростки в запасе, компост за монеты.
-- Items — удобрение и добыча из подземелья, продажа.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local ProfileScreen = {}

local byRarity = table.clone(Config.Trees)
table.sort(byRarity, function(a, b)
	return a.n > b.n
end)
-- в ауры попадают и эксклюзивные деревья (видны, если открыты)
local auraList = table.clone(byRarity)
for i, t in Config.PremiumTrees do
	table.insert(auraList, i, t :: any)
end

local function darken(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

function ProfileScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "", "Profile", UI.colors.blue, ctx.close)
	local content = panel.content

	local tabsRow = UI.frame(content, { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 })
	UI.list(tabsRow, 6, true)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local currentTab = "Character"
	local refreshers: { [string]: () -> () } = {}

	local function showTab(name: string)
		currentTab = name
		for k, page in pages do
			page.Visible = k == name
		end
		for k, b in tabButtons do
			b.BackgroundColor3 = if k == name then UI.colors.blue else UI.colors.panelLight
		end
		if refreshers[name] then
			refreshers[name]()
		end
	end
	for i, name in { "Character", "Auras", "Sprouts", "Items" } do
		local b = UI.button(tabsRow, string.upper(name), UI.colors.panelLight, {
			Name = name .. "Tab",
			Size = UDim2.new(0.25, -5, 1, 0),
			LayoutOrder = i,
		})
		b.Activated:Connect(function()
			showTab(name)
		end)
		tabButtons[name] = b
		local page = UI.scroll(content, {
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 1, -48),
			Visible = false,
		})
		local pad = Instance.new("UIPadding")
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = page
		pages[name] = page
	end

	local function grid(page: ScrollingFrame, cellH: number, cols: number): Frame
		local g = UI.frame(page, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(1 / cols, -6, 0, cellH)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = g
		return g
	end

	-- Карточка с фоном-градиентом сияния вида.
	local function auraCard(container: Instance, treeId: string, order: number): Frame
		local tree = Garden.tree(treeId) :: Garden.Tree
		local r = Garden.rarity(tree.rarity)
		local palette = Garden.aura(treeId).palette
		local card =
			UI.frame(container, { LayoutOrder = order, BackgroundColor3 = Color3.new(1, 1, 1) })
		UI.corner(card, 8)
		local dark = {}
		for i, c in palette do
			dark[i] = darken(c, 0.55)
		end
		UI.paletteGradient(card, dark, 35)
		local stroke = UI.stroke(card, r.color, 1.5, 0.2)
		UI.paletteGradient(stroke, { r.color, r.color2 }, 45)
		UI.label(card, tree.name, {
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.fromOffset(8, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local subText = if Garden.isPremium(treeId)
			then "Exclusive · Shop"
			else `{r.name} · {UI.oneIn(Luck.oneIn(treeId))}`
		local sub = UI.label(card, subText, {
			Size = UDim2.new(1, -16, 0, 13),
			Position = UDim2.fromOffset(8, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
		})
		UI.paletteGradient(sub, { r.color2, Color3.new(1, 1, 1) })
		return card
	end

	---------------------------------------------------------------- Character
	local charPage = pages.Character
	UI.list(charPage, 10)
	local top = UI.frame(
		charPage,
		{ Size = UDim2.new(1, 0, 0, 230), BackgroundTransparency = 1, LayoutOrder = 1 }
	)
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.new(0.42, 0, 1, 0)
	view.BackgroundColor3 = UI.colors.panel
	view.Ambient = Color3.fromRGB(170, 170, 185)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-1, -1, -0.5)
	view.Parent = top
	UI.corner(view, 10)
	local viewGradient: UIGradient? = nil
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = view
	view.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = view
	local preview: Model? = nil
	local angle = 0
	RunService.RenderStepped:Connect(function(dt)
		if not panel.visible() or currentTab ~= "Character" or not preview then
			return
		end
		angle += dt * 0.6
		local center = (preview :: Model):GetPivot().Position
		cam.CFrame = CFrame.lookAt(
			center + Vector3.new(math.sin(angle) * 9, 1.5, math.cos(angle) * 9),
			center
		)
	end)
	local function refreshPreview()
		if preview then
			preview:Destroy()
			preview = nil
		end
		local character = player.Character
		if not character then
			return
		end
		character.Archivable = true
		local clone = character:Clone()
		if not clone then
			return
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
				d:Destroy()
			end
		end
		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = world
		preview = clone
	end

	local info = UI.frame(top, {
		Position = UDim2.new(0.42, 10, 0, 0),
		Size = UDim2.new(0.58, -10, 1, 0),
		BackgroundTransparency = 1,
	})
	local infoList = UI.list(info, 4)
	infoList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	UI.label(info, player.DisplayName, {
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})
	local auraName = UI.label(info, "", {
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})
	local auraGradient: UIGradient? = nil
	local statLabels: { TextLabel } = {}
	for i = 1, 7 do
		statLabels[i] = UI.label(info, "", {
			Size = UDim2.new(1, 0, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
			LayoutOrder = 1 + i,
		})
	end
	local changeAura = UI.button(charPage, "CHANGE AURA", UI.colors.blue, {
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
	})
	changeAura.Activated:Connect(function()
		showTab("Auras")
	end)

	refreshers.Character = function()
		local profile = State.profile
		if not profile then
			return
		end
		refreshPreview()
		local auraTree = Garden.tree(profile.aura)
		if auraGradient then
			auraGradient:Destroy()
			auraGradient = nil
		end
		if viewGradient then
			viewGradient:Destroy()
			viewGradient = nil
		end
		if auraTree then
			local palette = Garden.aura(auraTree.id).palette
			auraName.Text = `Aura: {auraTree.name}`
			auraName.TextColor3 = Color3.new(1, 1, 1)
			auraGradient = UI.paletteGradient(auraName, palette)
			UI.shimmer(auraGradient :: UIGradient, 1.2)
			view.BackgroundColor3 = Color3.new(1, 1, 1)
			viewGradient =
				UI.paletteGradient(view, { darken(palette[1], 0.6), darken(palette[2], 0.75) }, 90)
		else
			auraName.Text = "No aura equipped"
			auraName.TextColor3 = UI.colors.muted
			view.BackgroundColor3 = UI.colors.panel
		end
		local best, bestN = nil, 0
		local found = 0
		for id in profile.found do
			found += 1
			local t = Garden.tree(id)
			if t and t.n > bestN then
				best, bestN = t, t.n
			end
		end
		local hours = profile.playSeconds / 3600
		local stats = profile.stats or {}
		local lines = {
			`Rolls: {UI.formatNumber(profile.rolls)}`,
			string.format("Luck: x%.2f", Luck.breakdown(profile).total),
			`Best find: {if best
				then best.name .. " (" .. UI.oneIn(Luck.oneIn(best.id)) .. ")"
				else "-"}`,
			`Index: {found}/{#Config.Trees}`,
			string.format("Time played: %.1f h", hours),
			`Harvests: {UI.formatNumber(stats.harvests or 0)}`,
			`Best dungeon wave: {stats.bestWave or 0}`,
		}
		for i, l in lines do
			statLabels[i].Text = l
		end
	end

	---------------------------------------------------------------- Auras
	local aurasPage = pages.Auras
	UI.list(aurasPage, 8)
	UI.label(aurasPage, "Wear the glow of any tree you found. Cosmetic only.", {
		Size = UDim2.new(1, 0, 0, 18),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})
	local auraGrid = grid(aurasPage, 86, 3)
	auraGrid.LayoutOrder = 1
	local auraButtons: { [string]: TextButton } = {}
	for i, t in auraList do
		local card = auraCard(auraGrid, t.id, i)
		local b = UI.button(card, "", UI.colors.panelLight, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 30),
		})
		b.Activated:Connect(function()
			local profile = State.profile
			local id: any = if profile and profile.aura == t.id then false else t.id
			local res = Net.request("EquipAura", id)
			if not res.ok then
				ctx.toast(Net.errorText(res.error))
			end
		end)
		auraButtons[t.id] = b
	end
	refreshers.Auras = function()
		local profile = State.profile
		if not profile then
			return
		end
		for id, b in auraButtons do
			local card = b.Parent :: Frame
			local found = profile.found[id] == true
			card.Visible = found
			if profile.aura == id then
				b.Text = "EQUIPPED"
				b.BackgroundColor3 = UI.colors.green
			else
				b.Text = "EQUIP"
				b.BackgroundColor3 = UI.colors.panelLight
			end
		end
	end

	---------------------------------------------------------------- Sprouts
	local sproutsPage = pages.Sprouts
	UI.list(sproutsPage, 8)
	local sproutsHeader = UI.label(sproutsPage, "", {
		Size = UDim2.new(1, 0, 0, 18),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})
	local sproutGrid = grid(sproutsPage, 110, 2)
	sproutGrid.LayoutOrder = 1
	local sproutCards: { [string]: { card: Frame, count: TextLabel, sell: TextButton } } = {}
	local confirmSell: { [string]: number } = {}
	for i, t in byRarity do
		local card = auraCard(sproutGrid, t.id, i)
		local count = UI.label(card, "", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.new(0.4, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		UI.label(card, `{UI.formatNumber(Garden.baseIncome(t))} coins/min planted`, {
			Size = UDim2.new(1, -16, 0, 13),
			Position = UDim2.fromOffset(8, 46),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		local each = math.max(1, math.floor(Garden.baseIncome(t) * Config.SellSeedSeconds / 60))
		local sell = UI.button(card, `COMPOST +{UI.formatNumber(each)}`, UI.colors.panelLight, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 32),
		})
		local rarityOrder = Garden.rarity(t.rarity).order
		sell.Activated:Connect(function()
			-- редкие ростки — только со вторым нажатием
			if rarityOrder >= 4 and (confirmSell[t.id] or 0) < os.clock() then
				confirmSell[t.id] = os.clock() + 3
				sell.Text = "TAP AGAIN"
				return
			end
			confirmSell[t.id] = 0
			local res = Net.request("SellSeed", t.id, 1)
			if res.ok then
				ctx.toast(`+{UI.formatNumber(res.coins)} coins`)
			else
				ctx.toast(Net.errorText(res.error))
			end
		end)
		sproutCards[t.id] = { card = card, count = count, sell = sell }
	end
	refreshers.Sprouts = function()
		local profile = State.profile
		if not profile then
			return
		end
		local total = 0
		for id, c in sproutCards do
			local n = profile.seeds[id] or 0
			total += n
			c.card.Visible = n > 0
			c.count.Text = `x{n}`
			if (confirmSell[id] or 0) < os.clock() then
				local t = Garden.tree(id) :: Garden.Tree
				local each =
					math.max(1, math.floor(Garden.baseIncome(t) * Config.SellSeedSeconds / 60))
				c.sell.Text = `COMPOST +{UI.formatNumber(each)}`
			end
		end
		sproutsHeader.Text =
			`{total} sprouts · up to {Config.Economy.seedCap} of each type are stored`
	end

	---------------------------------------------------------------- Items
	local itemsPage = pages.Items
	UI.list(itemsPage, 8)
	local itemsHeader = UI.label(itemsPage, "", {
		Size = UDim2.new(1, 0, 0, 18),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})
	local itemRows: { [string]: { row: Frame, count: TextLabel } } = {}
	local fert = UI.frame(itemsPage, { Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 1 })
	UI.corner(fert, 8)
	UI.glass(fert)
	UI.label(fert, "Fertilizer", {
		Size = UDim2.new(0.6, -12, 0, 20),
		Position = UDim2.fromOffset(12, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.colors.purple,
	})
	UI.label(fert, "Use on a growing tree: cuts half the time", {
		Size = UDim2.new(0.7, -12, 0, 14),
		Position = UDim2.fromOffset(12, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
	})
	local fertCount = UI.label(fert, "", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.3, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local itemIds = {}
	for id in Config.Items do
		table.insert(itemIds, id)
	end
	table.sort(itemIds, function(a, b)
		return Config.Items[a].value < Config.Items[b].value
	end)
	for i, id in itemIds do
		local item = Config.Items[id]
		local row = UI.frame(itemsPage, { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 1 + i })
		UI.corner(row, 8)
		UI.glass(row)
		local swatch = UI.frame(row, {
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromOffset(14, 23),
			BackgroundColor3 = item.color,
			Rotation = 45,
		})
		UI.corner(swatch, 3)
		UI.label(row, item.name, {
			Size = UDim2.new(0.45, -40, 0, 20),
			Position = UDim2.fromOffset(44, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = item.color,
		})
		local count = UI.label(row, "", {
			Size = UDim2.new(0.45, -40, 0, 14),
			Position = UDim2.fromOffset(44, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		local function sellButton(text: string, xScale: number, all: boolean)
			local b = UI.button(row, text, UI.colors.gold, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(xScale, -8, 0.5, 0),
				Size = UDim2.new(0.22, -8, 0, 40),
				TextColor3 = UI.colors.bg,
			})
			b.Activated:Connect(function()
				local profile = State.profile
				local have = profile and profile.items[id] or 0
				if have <= 0 then
					ctx.toast("Nothing to sell")
					return
				end
				local res = Net.request("SellItem", id, if all then have else 1)
				if res.ok then
					ctx.toast(`Sold for {UI.formatNumber(res.coins)} coins`)
				else
					ctx.toast(Net.errorText(res.error))
				end
			end)
		end
		sellButton("SELL 1", 0.78, false)
		sellButton("ALL", 1, true)
		itemRows[id] = { row = row, count = count }
	end
	refreshers.Items = function()
		local profile = State.profile
		if not profile then
			return
		end
		fertCount.Text = `x{profile.items.fertilizer or 0}`
		local worth = 0
		for id, r in itemRows do
			local n = profile.items[id] or 0
			local item = Config.Items[id]
			worth += n * item.value
			r.count.Text = `x{n} · {UI.formatNumber(item.value)} coins each`
		end
		itemsHeader.Text = `Dungeon loot worth {UI.formatNumber(worth)} coins`
	end

	local screen = {}

	function screen.refresh()
		if not panel.visible() then
			return
		end
		local fn = refreshers[currentTab]
		if fn and currentTab ~= "Character" then
			fn()
		end
	end

	function screen.setVisible(v: boolean)
		panel.setVisible(v)
		if v then
			showTab(currentTab)
		end
	end

	screen.visible = panel.visible
	return screen
end

return ProfileScreen
