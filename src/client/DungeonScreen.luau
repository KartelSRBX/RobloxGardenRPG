--!strict
-- Панель «Dungeon» (лобби): сила от сада, правила забега, шансы добычи, кнопка входа.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local D = Config.Dungeon

local DungeonScreen = {}

function DungeonScreen.new(parent: Instance, ctx: any)
	local panel = UI.panel(parent, "", "Dungeon", UI.colors.purple, ctx.close)
	local scroll = UI.scroll(panel.content)
	UI.list(scroll, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	local function box(order: number, height: number, stroke: Color3?): Frame
		local f = UI.frame(scroll, { Size = UDim2.new(1, -8, 0, height), LayoutOrder = order })
		UI.corner(f, 14)
		if stroke then
			UI.stroke(f, stroke, 2)
		end
		UI.pad(f, 10)
		return f
	end

	-- Сила от сада
	local power = box(1, 96, UI.colors.green)
	UI.label(power, "Garden power", {
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local powerText = UI.label(power, "", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.colors.green,
	})

	local enter = UI.button(scroll, "ENTER DUNGEON", UI.colors.purple, {
		Size = UDim2.new(0.86, 0, 0, 74),
		LayoutOrder = 2,
	})
	enter.Activated:Connect(function()
		local res = Net.request("DungeonEnter")
		if res.ok then
			ctx.close()
		else
			ctx.toast(Net.errorText(res.error))
		end
	end)

	-- Правила
	local rules = box(3, 150, UI.colors.purple)
	local rulesList = UI.list(rules, 4)
	rulesList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	for i, line in
		{
			`{#D.waves} waves of monsters, boss at the end`,
			"Tap Attack when monsters are close",
			"Leave between waves and keep all loot",
			`If you fall: {D.revives} free revive, then keep {100 - D.deathLossPercent}% of loot`,
		}
	do
		UI.label(rules, line, {
			Size = UDim2.new(1, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		})
	end

	-- Шансы добычи за волну
	local loot = box(4, 96, UI.colors.gold)
	local lootList = UI.list(loot, 4)
	lootList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	for i, line in
		{
			"Loot per wave",
			`Coins: always · Fertilizer: {D.loot.fertilizerChance}% · Sprout: {D.loot.seedChance}%`,
			`Dungeon sprouts roll with x{D.loot.seedLuckMult} your luck`,
		}
	do
		UI.label(loot, line, {
			Size = UDim2.new(1, 0, 0, if i == 1 then 22 else 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if i == 1 then UI.colors.text else UI.colors.muted,
			Font = if i == 1 then UI.font else UI.fontRegular,
			LayoutOrder = i,
		})
	end

	local screen = {}

	function screen.refresh()
		local profile = State.profile
		if not profile then
			return
		end
		local hp, dmg = Garden.buffs(profile.plots)
		powerText.Text = `{D.player.hp + hp} HP · +{math.floor(dmg * 100)}% damage`
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

return DungeonScreen
