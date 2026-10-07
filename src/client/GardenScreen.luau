--!strict
-- Экран «Сад»: карточки грядок, таймер роста, сбор, прокачка, посадка из семян.
-- Все действия — запросы к серверу; экран только показывает состояние.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local UI = require(script.Parent.UI)

type Callbacks = {
	request: (name: string, ...any) -> { [string]: any },
	toast: (text: string) -> (),
	openSpin: () -> (),
}

local rarityColor: { [string]: Color3 } = {}
for _, r in Config.Rarities do
	rarityColor[r.id] = r.color
end

local GardenScreen = {}

function GardenScreen.new(parent: Instance, cb: Callbacks)
	local root = UI.frame(parent, {
		Name = "Garden",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	local grid = Instance.new("ScrollingFrame")
	grid.Size = UDim2.fromScale(1, 1)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = root
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.48, 0, 0, 220)
	layout.CellPadding = UDim2.new(0.02, 0, 0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 6)
	gridPad.PaddingBottom = UDim.new(0, 6)
	gridPad.Parent = grid

	-- Выбор семени для пустой грядки.
	local picker = UI.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 10,
	})
	local pickerList = UI.frame(picker, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		ZIndex = 11,
	})
	UI.corner(pickerList, 16)
	local pickerLayout = Instance.new("UIListLayout")
	pickerLayout.Padding = UDim.new(0, 8)
	pickerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pickerLayout.Parent = pickerList
	local pickerPad = Instance.new("UIPadding")
	pickerPad.PaddingTop = UDim.new(0, 12)
	pickerPad.Parent = pickerList

	local profile: any = nil
	local cards: { { update: (now: number) -> () } } = {}

	local function openPicker(slot: number)
		for _, c in pickerList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local any = false
		for _, plant in Config.Plants do
			local count = profile.seeds[plant.id] or 0
			if count > 0 then
				any = true
				local b = UI.button(pickerList, `{plant.stages[1]}  x{count}`, UI.colors.bg, {
					Size = UDim2.new(0.9, 0, 0, 64),
					ZIndex = 12,
				})
				UI.stroke(b, rarityColor[plant.rarity])
				b.Activated:Connect(function()
					picker.Visible = false
					local res = cb.request("Plant", slot, plant.id)
					if not res.ok then
						cb.toast(res.error or "error")
					end
				end)
			end
		end
		if not any then
			cb.toast("No seeds yet. Spin to get one!")
			cb.openSpin()
			return
		end
		local close = UI.button(pickerList, "Back", UI.colors.red, {
			Size = UDim2.new(0.5, 0, 0, 56),
			LayoutOrder = 100,
			ZIndex = 12,
		})
		close.Activated:Connect(function()
			picker.Visible = false
		end)
		picker.Visible = true
	end

	local function makeCard(slot: number)
		local card = UI.frame(grid, { LayoutOrder = slot })
		UI.corner(card, 16)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Parent = card

		local title = UI.label(card, "", {
			Size = UDim2.new(1, -16, 0, 34),
			Position = UDim2.fromOffset(8, 8),
		})
		local info = UI.label(card, "", {
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 44),
			TextColor3 = UI.colors.muted,
		})
		local barBg = UI.frame(card, {
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.fromOffset(8, 76),
			BackgroundColor3 = UI.colors.bg,
		})
		UI.corner(barBg, 8)
		local bar =
			UI.frame(barBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.colors.green })
		UI.corner(bar, 8)
		local timer = UI.label(barBg, "", { ZIndex = 2 })

		local main = UI.button(card, "", UI.colors.green, {
			Size = UDim2.new(1, -16, 0, 52),
			Position = UDim2.fromOffset(8, 110),
		})
		local upgrade = UI.button(card, "", UI.colors.blue, {
			Size = UDim2.new(0.7, -12, 0, 44),
			Position = UDim2.new(0, 8, 0, 168),
		})
		local remove = UI.button(card, "X", UI.colors.red, {
			Size = UDim2.new(0.3, -8, 0, 44),
			Position = UDim2.new(0.7, 0, 0, 168),
		})

		local confirmRemoveUntil = 0

		main.Activated:Connect(function()
			local plot = profile.plots[slot]
			if not plot.plantId then
				openPicker(slot)
				return
			end
			local res = cb.request("Harvest", slot)
			if res.ok then
				cb.toast(`+{UI.formatNumber(res.coins)} coins`)
			elseif res.error ~= "not_ready" then
				cb.toast(res.error or "error")
			end
		end)
		upgrade.Activated:Connect(function()
			local res = cb.request("Upgrade", slot)
			if not res.ok then
				cb.toast(res.error or "error")
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
			local res = cb.request("Remove", slot)
			if not res.ok then
				cb.toast(res.error or "error")
			end
		end)

		local function update(now: number)
			local plot = profile.plots[slot]
			local plant = plot and plot.plantId and Garden.plant(plot.plantId)
			if os.clock() > confirmRemoveUntil then
				remove.Text = "X"
			end
			if not plant then
				stroke.Color = UI.colors.disabled
				title.Text = "Empty plot"
				info.Text = ""
				barBg.Visible = false
				main.Text = "Plant"
				main.BackgroundColor3 = UI.colors.green
				upgrade.Visible = false
				remove.Visible = false
				return
			end
			stroke.Color = rarityColor[plant.rarity]
			title.Text = Garden.stageName(plant, plot.level)
			local mutation = Garden.mutation(plot.mutation)
			local value = Garden.harvestValue(plant, plot.level, plot.mutation)
			info.Text = `Lv {plot.level}  ·  {UI.formatNumber(value)} coins`
				.. (if mutation then `  ·  {mutation.name}` else "")
			barBg.Visible = true
			upgrade.Visible = true
			remove.Visible = true

			local total = Garden.growTime(plant, plot.level)
			local left = (Garden.readyAt(plot) :: number) - now
			bar.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
			local ready = left <= 0
			timer.Text = if ready then "Ready!" else UI.formatTime(left)
			main.Text = if ready then "Harvest" else "Growing..."
			main.BackgroundColor3 = if ready then UI.colors.green else UI.colors.disabled

			local cost = Garden.upgradeCost(plant, plot.level)
			if cost then
				upgrade.Text = `Up {UI.formatNumber(cost)}`
				upgrade.BackgroundColor3 = if profile.coins >= cost
					then UI.colors.blue
					else UI.colors.disabled
			else
				upgrade.Text = "Max"
				upgrade.BackgroundColor3 = UI.colors.disabled
			end
		end

		return { update = update }
	end

	local screen = {}

	function screen.setProfile(p: any)
		profile = p
		while #cards < #p.plots do
			table.insert(cards, makeCard(#cards + 1))
		end
		screen.tick(workspace:GetServerTimeNow())
	end

	function screen.tick(now: number)
		if not profile then
			return
		end
		for _, card in cards do
			card.update(now)
		end
	end

	function screen.setVisible(v: boolean)
		root.Visible = v
		if not v then
			picker.Visible = false
		end
	end

	return screen
end

return GardenScreen
