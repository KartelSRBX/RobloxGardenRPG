--!strict
-- Панель «Seed Spin»: шанс каждого исхода числом (сумма 100%), кнопка броска,
-- анимация барабана. Результат приходит с сервера, анимация лишь подводит к нему.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local SpinScreen = {}

function SpinScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "🎲", "Seed Spin", UI.colors.gold, ctx.close)
	local content = panel.content
	local scroll = UI.scroll(content)
	UI.list(scroll, 10)
	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingTop = UDim.new(0, 4)
	scrollPad.PaddingRight = UDim.new(0, 8)
	scrollPad.Parent = scroll

	-- Окно результата
	local reveal = UI.frame(scroll, {
		Size = UDim2.new(1, -8, 0, 120),
		BackgroundColor3 = UI.colors.panel,
		LayoutOrder = 1,
	})
	UI.corner(reveal, 18)
	local revealStroke = UI.stroke(reveal, UI.colors.disabled, 5)
	local revealScale = Instance.new("UIScale")
	revealScale.Parent = reveal
	local revealIcon = UI.label(reveal, "🎁", {
		Size = UDim2.new(0, 90, 1, -20),
		Position = UDim2.fromOffset(12, 10),
	})
	local revealText = UI.label(reveal, "Spin to get a seed!", {
		Size = UDim2.new(1, -120, 0, 50),
		Position = UDim2.fromOffset(110, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local revealSub = UI.label(reveal, "", {
		Size = UDim2.new(1, -120, 0, 30),
		Position = UDim2.fromOffset(110, 70),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.colors.muted,
	})

	local spinButton = UI.button(scroll, `SPIN  ·  💰 {Config.SpinCost}`, UI.colors.gold, {
		Size = UDim2.new(0.86, 0, 0, 74),
		LayoutOrder = 2,
	})

	-- Таблица шансов: каждый исход и его процент
	UI.label(scroll, "Chances", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		TextColor3 = UI.colors.muted,
	})
	local odds = UI.frame(scroll, {
		Size = UDim2.new(1, -8, 0, #Config.Rarities * 50 + 12),
		LayoutOrder = 4,
	})
	UI.corner(odds, 16)
	UI.list(odds, 6)
	local oddsPad = Instance.new("UIPadding")
	oddsPad.PaddingTop = UDim.new(0, 8)
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
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = UI.colors.bg,
			LayoutOrder = r.order,
		})
		UI.corner(row, 10)
		UI.stroke(row, r.color, 2)
		UI.label(row, if plant then `{plant.icon} {plant.stages[1]}` else r.name, {
			Size = UDim2.new(0.5, -10, 0.7, 0),
			Position = UDim2.new(0, 10, 0.15, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.label(row, r.name, {
			Size = UDim2.new(0.25, 0, 0.6, 0),
			Position = UDim2.fromScale(0.5, 0.2),
			TextColor3 = r.color,
		})
		-- Процент от суммы: если сумма в конфиге поедет, игрок всё равно увидит 100%.
		UI.label(row, UI.percent(r.chance / total * 100), {
			Size = UDim2.new(0.25, -10, 0.7, 0),
			Position = UDim2.fromScale(0.75, 0.15),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	UI.label(scroll, "Coins come only from playing. No Robux spins.", {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 5,
		TextColor3 = UI.colors.muted,
	})

	local spinning = false

	local function show(plantId: string, final: boolean)
		local plant = Garden.plant(plantId)
		if not plant then
			return
		end
		local r = Garden.rarity(plant.rarity)
		revealIcon.Text = plant.icon
		revealText.Text = plant.stages[1]
		revealText.TextColor3 = r.color
		revealSub.Text = if final then `{r.name} seed!` else ""
		revealStroke.Color = r.color
	end

	spinButton.Activated:Connect(function()
		if spinning then
			return
		end
		if (State.profile and State.profile.coins or 0) < Config.SpinCost then
			ctx.toast("Not enough coins. Harvest your trees!")
			return
		end
		spinning = true
		-- Перебор вариантов, пока ждём ответ сервера, затем остановка на результате.
		local stop = false
		task.spawn(function()
			local i = 0
			while not stop do
				i += 1
				show(Config.Plants[(i - 1) % #Config.Plants + 1].id, false)
				revealScale.Scale = 0.96
				task.wait(0.07 + math.min(i, 20) * 0.006)
			end
		end)
		local res = Net.request("Spin")
		task.wait(0.8)
		stop = true
		task.wait(0.1)
		if res.ok then
			show(res.plantId, true)
			revealScale.Scale = 1.25
			TweenService
				:Create(revealScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			ctx.celebrate(Garden.rarity((Garden.plant(res.plantId) :: any).rarity).color)
		else
			revealScale.Scale = 1
			revealIcon.Text = "🎁"
			revealText.Text = "Spin to get a seed!"
			revealText.TextColor3 = UI.colors.text
			revealSub.Text = ""
			revealStroke.Color = UI.colors.disabled
			ctx.toast(Net.errorText(res.error))
		end
		spinning = false
	end)

	local screen = {}

	function screen.refresh()
		local coins = State.profile and State.profile.coins or 0
		spinButton.BackgroundColor3 = if coins >= Config.SpinCost
			then UI.colors.gold
			else UI.colors.disabled
	end

	function screen.setVisible(v: boolean)
		panel.setVisible(v)
		if v then
			screen.refresh()
		end
	end

	screen.visible = panel.visible
	screen.spinButton = spinButton

	return screen
end

return SpinScreen
