--!strict
-- Интерфейс забега: волна, здоровье, добыча, кнопка атаки, реквив и итоги.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local D = Config.Dungeon
local player = Players.LocalPlayer

local DungeonHud = {}

local function lootText(loot: any): string
	if not loot then
		return ""
	end
	return `Coins {UI.formatNumber(loot.coins)} · Fertilizer {loot.fertilizer} · Sprouts {#loot.seeds}`
end

local function seedIcons(seeds: { string }): string
	local parts = {}
	for _, id in seeds do
		local plant = Garden.plant(id)
		if plant then
			table.insert(parts, plant.name)
		end
	end
	return table.concat(parts, ", ")
end

function DungeonHud.new(gui: ScreenGui, ctx: any)
	local root = UI.frame(gui, {
		Name = "DungeonHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
	})

	-- Верх: волна, здоровье, добыча
	local top = UI.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.new(0.6, 0, 0, 104),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.15,
	})
	local topLimit = Instance.new("UISizeConstraint")
	topLimit.MaxSize = Vector2.new(420, 104)
	topLimit.MinSize = Vector2.new(260, 104)
	topLimit.Parent = top
	UI.corner(top, 16)
	UI.stroke(top, UI.colors.purple, 3)
	local waveLabel =
		UI.label(top, "", { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 6) })
	UI.textStroke(waveLabel)
	local hpBg = UI.frame(top, {
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 40),
		BackgroundColor3 = Color3.fromRGB(60, 20, 30),
	})
	UI.corner(hpBg, 10)
	local hpBar = UI.frame(hpBg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.colors.red })
	UI.corner(hpBar, 10)
	local hpText = UI.label(hpBg, "", { ZIndex = 3 })
	UI.textStroke(hpText, 1.5)
	local lootLabel = UI.label(top, "", {
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 72),
		TextColor3 = UI.colors.gold,
	})

	-- Сообщение по центру
	local banner = UI.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0.8, 0, 0, 56),
		Visible = false,
	})
	UI.textStroke(banner, 3)
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner

	-- Кнопка атаки справа (над кнопкой прыжка на телефоне)
	local attack = UI.button(root, "HIT", UI.colors.red, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -190),
		Size = UDim2.fromOffset(120, 120),
		TextSize = 60,
		TextScaled = false,
	})
	UI.corner(attack, 60)
	UI.stroke(attack, Color3.new(1, 1, 1), 4)
	local attackHint = UI.label(attack, "ATTACK", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(120, 24),
	})
	UI.textStroke(attackHint)

	local leave = UI.button(root, "Leave with loot", UI.colors.blue, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.44, 0),
		Size = UDim2.fromOffset(280, 64),
		Visible = false,
	})

	-- Оверлей «повержен» и итоги
	local overlay = UI.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 30,
	})
	local card = UI.frame(overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.colors.bg,
		ZIndex = 31,
	})
	local cardLimit = Instance.new("UISizeConstraint")
	cardLimit.MaxSize = Vector2.new(460, 400)
	cardLimit.Parent = card
	UI.corner(card, 20)
	local cardStroke = UI.stroke(card, UI.colors.purple, 4)
	UI.pad(card, 16)
	UI.list(card, 10)
	local cardTitle =
		UI.label(card, "", { Size = UDim2.new(1, 0, 0, 48), ZIndex = 32, LayoutOrder = 1 })
	UI.textStroke(cardTitle, 2)
	local cardText = UI.label(card, "", {
		Size = UDim2.new(1, 0, 0, 90),
		ZIndex = 32,
		LayoutOrder = 2,
		TextWrapped = true,
		TextColor3 = UI.colors.muted,
	})
	local primary = UI.button(
		card,
		"",
		UI.colors.green,
		{ Size = UDim2.new(1, 0, 0, 64), ZIndex = 32, LayoutOrder = 3 }
	)
	local secondary = UI.button(
		card,
		"",
		UI.colors.disabled,
		{ Size = UDim2.new(1, 0, 0, 52), ZIndex = 32, LayoutOrder = 4 }
	)
	local primaryAction: (() -> ())? = nil
	local secondaryAction: (() -> ())? = nil
	primary.Activated:Connect(function()
		if primaryAction then
			primaryAction()
		end
	end)
	secondary.Activated:Connect(function()
		if secondaryAction then
			secondaryAction()
		end
	end)

	local function showBanner(text: string, color: Color3?)
		banner.Text = text
		banner.TextColor3 = color or UI.colors.text
		banner.Visible = true
		bannerScale.Scale = 1.4
		TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end

	local function doAttack()
		if not root.Visible or overlay.Visible then
			return
		end
		local res = Net.request("DungeonAttack")
		if res.ok then
			attack.BackgroundColor3 = UI.colors.disabled
			task.delay(D.player.attackCooldown, function()
				attack.BackgroundColor3 = UI.colors.red
			end)
		end
	end
	attack.Activated:Connect(doAttack)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			doAttack()
		end
	end)

	leave.Activated:Connect(function()
		local res = Net.request("DungeonLeave")
		if not res.ok then
			ctx.toast(Net.errorText(res.error))
		end
	end)

	local function showResult(d: any)
		overlay.Visible = true
		local kept, lost = d.kept, d.lost
		if d.result == "victory" then
			cardTitle.Text = "Dungeon cleared!"
			cardTitle.TextColor3 = UI.colors.gold
			cardStroke.Color = UI.colors.gold
		elseif d.result == "left" then
			cardTitle.Text = "You escaped!"
			cardTitle.TextColor3 = UI.colors.green
			cardStroke.Color = UI.colors.green
		else
			cardTitle.Text = "You fell"
			cardTitle.TextColor3 = UI.colors.red
			cardStroke.Color = UI.colors.red
		end
		local text = `Kept: {lootText(kept)}`
		if #kept.seeds > 0 then
			text ..= `\n{seedIcons(kept.seeds)}`
		end
		if lost and (lost.coins > 0 or lost.fertilizer > 0 or #lost.seeds > 0) then
			text ..= `\nLost: {lootText(lost)}`
		end
		cardText.Text = text
		primary.Text = "Back to garden"
		primary.BackgroundColor3 = UI.colors.green
		primaryAction = function()
			overlay.Visible = false
			root.Visible = false
			State.setDungeon(nil)
		end
		secondary.Visible = false
	end

	local function showDowned(d: any)
		overlay.Visible = true
		cardTitle.Text = "You got knocked out!"
		cardTitle.TextColor3 = UI.colors.red
		cardStroke.Color = UI.colors.red
		if d.revivesLeft > 0 then
			cardText.Text = `Loot so far: {lootText(d.loot)}`
			primary.Text = "Revive (free)"
			primary.BackgroundColor3 = UI.colors.green
			primaryAction = function()
				local res = Net.request("DungeonRevive")
				if not res.ok then
					ctx.toast(Net.errorText(res.error))
				end
			end
			secondary.Visible = true
			secondary.Text = `Give up (keep {100 - D.deathLossPercent}%)`
			secondaryAction = function()
				Net.request("DungeonLeave")
			end
		else
			cardText.Text = "No revives left..."
			primary.Text = "..."
			primary.BackgroundColor3 = UI.colors.disabled
			primaryAction = nil
			secondary.Visible = false
		end
	end

	local lastState = ""
	State.dungeonChanged:Connect(function(d: any)
		if not d then
			root.Visible = false
			ctx.setWorldHud(true)
			return
		end
		root.Visible = true
		ctx.setWorldHud(false)
		ctx.close()
		waveLabel.Text = `Wave {d.wave}/{d.waves}`
			.. (if d.state == "fight" then `  ·  {d.enemies}` else "")
		lootLabel.Text = lootText(d.loot)
		leave.Visible = d.state == "pause"
		attack.Visible = d.state == "fight" or d.state == "start" or d.state == "pause"

		if d.result then
			banner.Visible = false
			showResult(d)
		elseif d.state == "downed" then
			showDowned(d)
		else
			overlay.Visible = false
			if d.startIn and d.state == "start" then
				showBanner(`Get ready! Wave 1 in {d.startIn}...`)
			elseif d.state == "fight" and lastState ~= "fight" then
				showBanner(
					if d.wave == d.waves then "BOSS WAVE!" else `Wave {d.wave}!`,
					UI.colors.red
				)
				task.delay(1.5, function()
					if lastState == "fight" then
						banner.Visible = false
					end
				end)
			elseif d.state == "pause" and d.gained then
				local g = d.gained
				local extra = ""
				if g.fertilizer > 0 then
					extra ..= " · Fertilizer +1"
				end
				if #g.seeds > 0 then
					extra ..= " · " .. seedIcons(g.seeds)
				end
				showBanner(`Wave cleared! +{g.coins}{extra}`, UI.colors.gold)
			end
		end
		lastState = d.state
	end)

	-- Здоровье берём у своего персонажа
	task.spawn(function()
		while true do
			task.wait(0.1)
			if root.Visible then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
					hpBar.Size = UDim2.fromScale(frac, 1)
					hpText.Text = `{math.ceil(hum.Health)} / {math.floor(hum.MaxHealth)}`
				end
			end
		end
	end)

	return {}
end

return DungeonHud
