--!strict
-- Экран «Крутилка»: шансы каждого исхода числом (сумма 100%), кнопка броска,
-- анимация. Результат приходит с сервера, анимация лишь подводит к нему.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local UI = require(script.Parent.UI)

type Callbacks = {
	request: (name: string, ...any) -> { [string]: any },
	toast: (text: string) -> (),
}

local SpinScreen = {}

function SpinScreen.new(parent: Instance, cb: Callbacks)
	local root = UI.frame(parent, {
		Name = "Spin",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	})

	-- Окно результата.
	local reveal = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.9, 0, 0, 110),
		BackgroundColor3 = UI.colors.bg,
	})
	UI.corner(reveal, 16)
	local revealStroke = Instance.new("UIStroke")
	revealStroke.Thickness = 5
	revealStroke.Color = UI.colors.disabled
	revealStroke.Parent = reveal
	local revealText = UI.label(reveal, "?", {
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
	})

	-- Таблица шансов: каждый исход и его процент.
	local odds = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.new(0.9, 0, 0, 5 * 46 + 8),
	})
	UI.corner(odds, 16)
	local oddsLayout = Instance.new("UIListLayout")
	oddsLayout.Padding = UDim.new(0, 6)
	oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	oddsLayout.Parent = odds
	local oddsPad = Instance.new("UIPadding")
	oddsPad.PaddingTop = UDim.new(0, 6)
	oddsPad.PaddingLeft = UDim.new(0, 12)
	oddsPad.PaddingRight = UDim.new(0, 12)
	oddsPad.Parent = odds

	local total = 0
	for _, r in Config.Rarities do
		total += r.chance
	end
	for _, r in Config.Rarities do
		local plant = Garden.plantForRarity(r.id)
		local row = UI.frame(odds, {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			LayoutOrder = r.order,
		})
		UI.label(row, if plant then plant.stages[1] else r.name, {
			Size = UDim2.fromScale(0.7, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = r.color,
		})
		-- Процент от суммы: если сумма в конфиге поедет, игрок всё равно увидит 100%.
		local pct = r.chance / total * 100
		UI.label(row, (string.format("%.1f", pct):gsub("%.0$", "")) .. "%", {
			Size = UDim2.fromScale(0.3, 1),
			Position = UDim2.fromScale(0.7, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	local spinButton = UI.button(root, `Spin  ·  {Config.SpinCost} coins`, UI.colors.gold, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124 + 5 * 46 + 20),
		Size = UDim2.new(0.8, 0, 0, 72),
		TextColor3 = UI.colors.bg,
	})

	local spinning = false
	local coins = 0

	local function show(plantId: string)
		local plant = Garden.plant(plantId)
		if not plant then
			return
		end
		local color = UI.colors.text
		for _, r in Config.Rarities do
			if r.id == plant.rarity then
				color = r.color
			end
		end
		revealText.Text = plant.stages[1]
		revealText.TextColor3 = color
		revealStroke.Color = color
	end

	spinButton.Activated:Connect(function()
		if spinning then
			return
		end
		if coins < Config.SpinCost then
			cb.toast("Not enough coins. Harvest your garden!")
			return
		end
		spinning = true
		-- Перебор вариантов, пока ждём ответ сервера, затем замедление на результате.
		local stop = false
		task.spawn(function()
			local i = 0
			while not stop do
				i += 1
				show(Config.Plants[(i - 1) % #Config.Plants + 1].id)
				task.wait(0.06)
			end
		end)
		local res = cb.request("Spin")
		task.wait(0.6)
		stop = true
		if res.ok then
			show(res.plantId)
			reveal.Size = UDim2.new(0.95, 0, 0, 120)
			TweenService:Create(reveal, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
				Size = UDim2.new(0.9, 0, 0, 110),
			}):Play()
			cb.toast(`Got a seed: {revealText.Text}`)
		else
			revealText.Text = "?"
			revealText.TextColor3 = UI.colors.text
			revealStroke.Color = UI.colors.disabled
			cb.toast(res.error or "error")
		end
		spinning = false
	end)

	local screen = {}

	function screen.setProfile(p: any)
		coins = p.coins
		spinButton.BackgroundColor3 = if coins >= Config.SpinCost
			then UI.colors.gold
			else UI.colors.disabled
	end

	function screen.setVisible(v: boolean)
		root.Visible = v
	end

	return screen
end

return SpinScreen
