--!strict
-- Панель «My Garden»: запасы, карточки грядок (таймер, сбор, прокачка, удобрение),
-- покупка новой грядки, возврат домой. Все действия — запросы к серверу.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local GardenScreen = {}

function GardenScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "🌳", "My Garden", UI.colors.green, ctx.close)
	local content = panel.content

	-- Верхняя строка: запасы и кнопка домой
	local top = UI.frame(content, { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 })
	local stock = UI.label(top, "", {
		Size = UDim2.new(1, -140, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.colors.muted,
	})
	local home = UI.button(top, "🏠 Home", UI.colors.blue, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 130, 1, 0),
	})
	home.Activated:Connect(function()
		local res = Net.request("GoHome")
		if res.ok then
			ctx.close()
		else
			ctx.toast(Net.errorText(res.error))
		end
	end)

	local grid =
		UI.scroll(content, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56) })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.485, 0, 0, 236)
	layout.CellPadding = UDim2.new(0.03, 0, 0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingBottom = UDim.new(0, 8)
	gridPad.PaddingLeft = UDim.new(0, 4)
	gridPad.PaddingRight = UDim.new(0, 10)
	gridPad.Parent = grid

	-- Выбор семени
	local picker = UI.frame(panel.root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 20,
	})
	UI.corner(picker, 20)
	local pickerBox = UI.frame(picker, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		ZIndex = 21,
	})
	UI.corner(pickerBox, 16)
	UI.pad(pickerBox, 12)
	UI.list(pickerBox, 8)

	local cards: { (number) -> () } = {}
	local buyCard: Frame? = nil

	local function openPicker(slot: number)
		local profile = State.profile
		for _, c in pickerBox:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		UI.label(pickerBox, "Choose a seed", { Size = UDim2.new(1, 0, 0, 36), ZIndex = 22 })
		local any = false
		for _, plant in Config.Plants do
			local count = profile.seeds[plant.id] or 0
			if count > 0 then
				any = true
				local r = Garden.rarity(plant.rarity)
				local b = UI.button(
					pickerBox,
					`{plant.icon} {plant.stages[1]}  x{count}`,
					UI.colors.panelLight,
					{
						Size = UDim2.new(1, 0, 0, 60),
						ZIndex = 22,
					}
				)
				UI.stroke(b, r.color, 3)
				b.Activated:Connect(function()
					picker.Visible = false
					local res = Net.request("Plant", slot, plant.id)
					if not res.ok then
						ctx.toast(Net.errorText(res.error))
					end
				end)
			end
		end
		if not any then
			ctx.toast("No seeds yet. Spin the Seed Machine!")
			ctx.open("Spin")
			return
		end
		local back = UI.button(pickerBox, "Back", UI.colors.red, {
			Size = UDim2.new(0.5, 0, 0, 52),
			LayoutOrder = 100,
			ZIndex = 22,
		})
		back.Activated:Connect(function()
			picker.Visible = false
		end)
		if not panel.visible() then
			ctx.open("Garden")
		end
		picker.Visible = true
	end

	local function makeCard(slot: number): (number) -> ()
		local card = UI.frame(grid, { LayoutOrder = slot, BackgroundColor3 = UI.colors.panel })
		UI.corner(card, 16)
		local stroke = UI.stroke(card, UI.colors.disabled, 4)

		local title = UI.label(card, "", {
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 8),
		})
		local info = UI.label(card, "", {
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 40),
			TextColor3 = UI.colors.muted,
		})
		local barBg = UI.frame(card, {
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.fromOffset(8, 68),
			BackgroundColor3 = UI.colors.bg,
		})
		UI.corner(barBg, 10)
		local bar =
			UI.frame(barBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.colors.green })
		UI.corner(bar, 10)
		local timer = UI.label(barBg, "", { ZIndex = 2 })
		UI.textStroke(timer, 1.5)

		local main = UI.button(card, "", UI.colors.green, {
			Size = UDim2.new(1, -16, 0, 54),
			Position = UDim2.fromOffset(8, 102),
		})
		local upgrade = UI.button(card, "", UI.colors.blue, {
			Size = UDim2.new(0.5, -10, 0, 44),
			Position = UDim2.new(0, 8, 0, 162),
		})
		local fert = UI.button(card, "🧪", UI.colors.purple, {
			Size = UDim2.new(0.25, -6, 0, 44),
			Position = UDim2.new(0.5, 2, 0, 162),
		})
		local remove = UI.button(card, "X", UI.colors.red, {
			Size = UDim2.new(0.25, -10, 0, 44),
			Position = UDim2.new(0.75, 2, 0, 162),
		})
		local fertCount = UI.label(card, "", {
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.fromOffset(8, 210),
			TextColor3 = UI.colors.muted,
		})

		local confirmRemoveUntil = 0

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
			if res.ok then
				ctx.toast("Growth boosted!")
			else
				ctx.toast(Net.errorText(res.error))
			end
		end)
		remove.Activated:Connect(function()
			-- Выкопать дерево можно только вторым нажатием, чтобы не потерять его случайно.
			if os.clock() > confirmRemoveUntil then
				confirmRemoveUntil = os.clock() + 3
				remove.Text = "Sure?"
				return
			end
			confirmRemoveUntil = 0
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
			local plant = plot.plantId and Garden.plant(plot.plantId)
			if os.clock() > confirmRemoveUntil then
				remove.Text = "X"
			end
			local fertilizer = profile.items.fertilizer or 0
			if not plant then
				stroke.Color = UI.colors.disabled
				title.Text = "🌱 Empty plot"
				info.Text = "Plant a seed here"
				info.TextColor3 = UI.colors.muted
				barBg.Visible = false
				main.Text = "Plant"
				main.BackgroundColor3 = UI.colors.green
				upgrade.Visible = false
				fert.Visible = false
				remove.Visible = false
				fertCount.Text = ""
				return
			end
			local rarity = Garden.rarity(plant.rarity)
			stroke.Color = rarity.color
			title.Text = `{plant.icon} {Garden.stageName(plant, plot.level)}`
			local mutation = Garden.mutation(plot.mutation)
			local value = Garden.harvestValue(plant, plot.level, plot.mutation)
			info.Text = `Lv {plot.level} · 💰 {UI.formatNumber(value)}`
				.. (if mutation then ` · ✨{mutation.name}` else "")
			info.TextColor3 = if mutation then mutation.color else UI.colors.muted
			barBg.Visible = true
			upgrade.Visible = true
			remove.Visible = true

			local total = Garden.growTime(plant, plot.level)
			local left = (Garden.readyAt(plot) :: number) - now
			bar.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
			local ready = left <= 0
			bar.BackgroundColor3 = if ready then UI.colors.gold else UI.colors.green
			timer.Text = if ready then "Ready!" else "⏳ " .. UI.formatTime(left)
			main.Text = if ready then "Harvest" else "Growing..."
			main.BackgroundColor3 = if ready then UI.colors.gold else UI.colors.disabled
			fert.Visible = not ready
			fert.BackgroundColor3 = if fertilizer > 0 then UI.colors.purple else UI.colors.disabled
			fertCount.Text = if not ready and fertilizer > 0
				then `🧪 x{fertilizer}: speeds up growth`
				else ""

			local cost = Garden.upgradeCost(plant, plot.level)
			if cost then
				upgrade.Text = `⬆ {UI.formatNumber(cost)}`
				upgrade.BackgroundColor3 = if profile.coins >= cost
					then UI.colors.blue
					else UI.colors.disabled
			else
				upgrade.Text = "MAX"
				upgrade.BackgroundColor3 = UI.colors.disabled
			end
		end
	end

	local function ensureBuyCard(): Frame
		if buyCard then
			return buyCard
		end
		local card = UI.frame(grid, { LayoutOrder = 1000, BackgroundColor3 = UI.colors.panel })
		UI.corner(card, 16)
		UI.stroke(card, UI.colors.gold, 3)
		UI.label(
			card,
			"➕ New plot",
			{ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 20) }
		)
		UI.label(card, "More trees, more coins!", {
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 60),
			TextColor3 = UI.colors.muted,
		})
		local buy = UI.button(card, "", UI.colors.gold, {
			Name = "Buy",
			Size = UDim2.new(1, -16, 0, 60),
			Position = UDim2.fromOffset(8, 110),
		})
		buy.Activated:Connect(function()
			local res = Net.request("BuyPlot")
			if res.ok then
				ctx.toast("New plot unlocked!")
			else
				ctx.toast(Net.errorText(res.error))
			end
		end)
		buyCard = card
		return card
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
		local seeds = 0
		for _, n in profile.seeds do
			seeds += n
		end
		stock.Text = `🌱 Seeds: {seeds}    🧪 {profile.items.fertilizer or 0}`
		local price = Garden.plotPrice(#profile.plots)
		if price then
			local card = ensureBuyCard()
			card.Visible = true
			local buy = card:FindFirstChild("Buy") :: TextButton
			buy.Text = `💰 {UI.formatNumber(price)}`
			buy.BackgroundColor3 = if profile.coins >= price
				then UI.colors.gold
				else UI.colors.disabled
		elseif buyCard then
			buyCard.Visible = false
		end
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
	screen.openPicker = openPicker

	return screen
end

return GardenScreen
