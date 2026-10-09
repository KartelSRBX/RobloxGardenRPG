--!strict
-- Кнопка крутки внизу экрана: бесплатно, с полосой отката, счётчиком до счастливой
-- крутки и переключателем авто-крутки. Над кнопкой — карточка последнего результата.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local RollReveal = require(script.Parent.RollReveal)
local UI = require(script.Parent.UI)

local R = Config.Roll

local RollHud = {}

function RollHud.new(parent: Instance, ctx: any)
	local root = UI.frame(parent, {
		Name = "RollHud",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(300, 74),
		BackgroundTransparency = 1,
	})

	local button = UI.button(root, "", UI.colors.gold, {
		Size = UDim2.new(1, -86, 1, 0),
		TextColor3 = UI.colors.bg,
	})
	UI.corner(button, 12)
	local title = UI.label(button, "ROLL", {
		Size = UDim2.new(1, 0, 0.55, 0),
		TextColor3 = UI.colors.bg,
		ZIndex = 3,
	})
	local sub = UI.label(button, "", {
		Size = UDim2.new(1, 0, 0.35, 0),
		Position = UDim2.fromScale(0, 0.62),
		TextColor3 = UI.colors.bg,
		Font = UI.fontRegular,
		ZIndex = 3,
	})
	-- полоса отката внизу кнопки
	local cdBar = UI.frame(button, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 12),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.6,
		ZIndex = 3,
	})
	UI.corner(cdBar, 2)

	local auto = UI.button(root, "AUTO", UI.colors.panelLight, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 76, 1, 0),
	})
	UI.corner(auto, 12)
	UI.glass(auto)

	-- Карточка результата
	local card = UI.frame(parent, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(300, 62),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	UI.corner(card, 10)
	local cardStroke = UI.stroke(card, UI.colors.gold, 1.5)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local cardName = UI.label(card, "", {
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local cardInfo = UI.label(card, "", {
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
	})

	local readyAt = 0
	local hideId = 0

	-- цветная полоска слева на карточке: градиент сияния вида
	local cardStripe = UI.frame(card, {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	UI.corner(cardStripe, 2)
	local stripeGradient: UIGradient? = nil
	local nameGradient: UIGradient? = nil

	local function showResult(res: any)
		local tree = Garden.tree(res.treeId)
		if not tree then
			return
		end
		local r = Garden.rarity(tree.rarity)
		local palette = Garden.aura(tree.id).palette
		cardName.Text = (if res.isNew then "NEW · " else "") .. tree.name
		cardName.TextColor3 = Color3.new(1, 1, 1)
		if nameGradient then
			nameGradient:Destroy()
		end
		nameGradient = UI.paletteGradient(cardName, palette)
		if stripeGradient then
			stripeGradient:Destroy()
		end
		stripeGradient = UI.paletteGradient(cardStripe, { r.color, r.color2 }, 90)
		local info = `{r.name} · {UI.oneIn(Luck.oneIn(tree.id))}`
		if res.lucky then
			info ..= " · LUCKY ROLL"
		end
		if res.composted then
			info ..= ` · composted +{UI.formatNumber(res.composted)}`
		end
		cardInfo.Text = info
		cardStroke.Color = r.color
		card.Visible = true
		cardScale.Scale = 1.06
		TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		if RollReveal.wants(res) then
			RollReveal.show(res)
		end
		hideId += 1
		local id = hideId
		task.delay(3, function()
			if hideId == id then
				card.Visible = false
			end
		end)
	end

	local function doRoll()
		local profile = State.profile
		if not profile or os.clock() < readyAt then
			return
		end
		readyAt = os.clock() + Luck.cooldown(profile)
		local res = Net.request("Roll")
		if res.ok and res.result then
			showResult(res.result)
		elseif res.error ~= "cooldown" then
			ctx.toast(Net.errorText(res.error))
		end
	end
	button.Activated:Connect(doRoll)

	auto.Activated:Connect(function()
		local profile = State.profile
		if not profile then
			return
		end
		local res = Net.request("SetAutoRoll", not profile.autoRoll)
		if not res.ok then
			ctx.toast(Net.errorText(res.error))
		end
	end)

	Remotes.event("Rolled").OnClientEvent:Connect(function(res)
		local profile = State.profile
		readyAt = os.clock() + (if profile then Luck.cooldown(profile) else R.cooldown)
		showResult(res)
	end)

	RunService.Heartbeat:Connect(function()
		local profile = State.profile
		if not profile then
			return
		end
		local cd = Luck.cooldown(profile)
		local left = math.max(0, readyAt - os.clock())
		cdBar.Size = UDim2.new(1 - left / cd, 0, 0, 4)
		local toLucky = R.luckyEvery - (profile.rolls % R.luckyEvery)
		sub.Text = if toLucky == 1 then "next roll is LUCKY" else `lucky in {toLucky}`
		button.BackgroundColor3 = if left > 0 then UI.colors.goldDark else UI.colors.gold
		title.Text = if profile.autoRoll then "AUTO ROLL" else "ROLL"
		local unlocked = profile.rolls >= R.autoUnlockRolls
		auto.Text = if not unlocked
			then `{profile.rolls}/{R.autoUnlockRolls}`
			elseif profile.autoRoll then "ON"
			else "AUTO"
		auto.BackgroundColor3 = if profile.autoRoll then UI.colors.green else UI.colors.panelLight
	end)

	return {
		root = root,
		button = button,
		setVisible = function(v: boolean)
			root.Visible = v
			if not v then
				card.Visible = false
			end
		end,
	}
end

return RollHud
