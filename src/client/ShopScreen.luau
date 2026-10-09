--!strict
-- Панель «Shop»: только предсказуемые покупки за Robux (геймпассы).
-- Эксклюзивные деревья, бусты, больше грядок. Цена видна сразу, рандома нет.
-- Пока пропуск не создан на сайте (id = 0): в Studio можно выдать себе для проверки,
-- в живой игре кнопка показывает «Soon».
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local ShopScreen = {}

local function darken(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

function ShopScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "", "Shop", Color3.fromRGB(120, 210, 255), ctx.close)
	local scroll = UI.scroll(panel.content)
	UI.list(scroll, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	local order = 0
	local function heading(text: string, sub: string?)
		order += 1
		UI.label(scroll, text, {
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		if sub then
			order += 1
			UI.label(scroll, sub, {
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = UI.fontRegular,
				TextColor3 = UI.colors.muted,
				LayoutOrder = order,
			})
		end
	end

	local prices: { [string]: number } = {}
	local refreshers: { () -> () } = {}

	local function buyButton(container: Instance, pass: any): TextButton
		local b = UI.button(container, "", UI.colors.green, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(130, 44),
		})
		b.Activated:Connect(function()
			if State.passes[pass.key] then
				return
			end
			if pass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			elseif RunService:IsStudio() then
				local res = Net.request("TestGrant", pass.key)
				ctx.toast(
					if res.ok
						then "Studio test: granted for this session"
						else Net.errorText(res.error)
				)
			else
				ctx.toast("Coming soon")
			end
		end)
		table.insert(refreshers, function()
			if State.passes[pass.key] then
				b.Text = "OWNED"
				b.BackgroundColor3 = UI.colors.greenDark
			elseif pass.id == 0 then
				b.Text = if RunService:IsStudio() then "TEST" else "SOON"
				b.BackgroundColor3 = UI.colors.panelLight
			else
				local price = prices[pass.key]
				b.Text = if price then `R$ {price}` else "..."
				b.BackgroundColor3 = UI.colors.green
			end
		end)
		if pass.id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(
					MarketplaceService.GetProductInfo,
					MarketplaceService,
					pass.id,
					Enum.InfoType.GamePass
				)
				if ok and info and info.PriceInRobux then
					prices[pass.key] = info.PriceInRobux
				end
			end)
		end
		return b
	end

	---------------------------------------------------------------- деревья
	heading("EXCLUSIVE TREES", "Buy once, keep forever. Plant one of each and replant any time.")
	for _, pass in Config.GamePasses do
		local treeId = (pass :: any).treeId
		if not treeId then
			continue
		end
		local tree = Garden.tree(treeId) :: any
		local palette = Garden.aura(treeId).palette
		order += 1
		local card = UI.frame(scroll, {
			Size = UDim2.new(1, 0, 0, 132),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = order,
		})
		UI.corner(card, 12)
		local bg = UI.paletteGradient(
			card,
			{ darken(palette[1], 0.55), darken(palette[2], 0.7), darken(palette[3], 0.6) },
			20
		)
		UI.shimmer(bg, 0.6)
		local edge = UI.stroke(card, Color3.new(1, 1, 1), 2)
		UI.shimmer(UI.paletteGradient(edge, palette, 45), 1.2)
		local name = UI.label(card, string.upper(tree.name), {
			Size = UDim2.new(1, -24, 0, 24),
			Position = UDim2.fromOffset(14, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
		})
		UI.shimmer(
			UI.paletteGradient(name, { Color3.new(1, 1, 1), palette[1], Color3.new(1, 1, 1) }),
			2
		)
		UI.label(card, tree.perkText, {
			Size = UDim2.new(1, -170, 0, 18),
			Position = UDim2.fromOffset(14, 42),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = palette[3]:Lerp(Color3.new(1, 1, 1), 0.4),
		})
		UI.label(
			card,
			`{UI.formatNumber(tree.income)} coins/min · ripe every {UI.formatTime(tree.grow)}`,
			{
				Size = UDim2.new(1, -170, 0, 14),
				Position = UDim2.fromOffset(14, 66),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = UI.fontRegular,
				TextColor3 = UI.colors.text,
			}
		)
		UI.label(card, "Glows, orbits and its own aura", {
			Size = UDim2.new(1, -170, 0, 14),
			Position = UDim2.fromOffset(14, 86),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		buyButton(card, pass)
	end

	---------------------------------------------------------------- бусты и остров
	heading("BOOSTS & ISLAND")
	for _, pass in Config.GamePasses do
		if (pass :: any).treeId then
			continue
		end
		order += 1
		local row = UI.frame(scroll, { Size = UDim2.new(1, 0, 0, 72), LayoutOrder = order })
		UI.corner(row, 10)
		UI.glass(row)
		UI.label(row, (pass :: any).name, {
			Size = UDim2.new(1, -170, 0, 20),
			Position = UDim2.fromOffset(14, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.label(row, (pass :: any).desc, {
			Size = UDim2.new(1, -170, 0, 14),
			Position = UDim2.fromOffset(14, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UI.fontRegular,
			TextColor3 = UI.colors.muted,
		})
		local b = buyButton(row, pass)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -12, 0.5, 0)
	end

	order += 1
	UI.label(scroll, "Everything here is a fixed item. No random rewards are sold for Robux.", {
		Size = UDim2.new(1, 0, 0, 28),
		TextWrapped = true,
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
		LayoutOrder = order,
	})

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _id, purchased)
		if who == player and purchased then
			ctx.toast("Thank you! Your purchase is ready")
			ctx.celebrate(Color3.fromRGB(120, 210, 255))
		end
	end)

	local screen = {}

	function screen.refresh()
		for _, fn in refreshers do
			fn()
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

return ShopScreen
