--!strict
-- HUD забега по ТЗ. Плотность максимальная (в лобби — минимальная):
-- Z2 сверху по центру: красная кнопка Back (выйти с добычей), заголовок WAVE n/5, строка врагов;
-- Z5 слева снизу: стек счётчиков добычи; Z6 снизу по центру: HP, урон, слот оружия, полоса волн;
-- Z7 справа снизу: круглая кнопка атаки (тап и удержание = автоатака); Z9: баннеры и итоги.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Components = require(script.Parent.Components)
local Icons = require(script.Parent.Icons)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local D = Config.Dungeon
local player = Players.LocalPlayer

local DungeonHud = {}

local weaponById: { [string]: any } = {}
for _, w in Config.Weapons do
	weaponById[w.id] = w
end

local function dropCount(loot: any): number
	local n = 0
	for _, c in loot and loot.drops or {} do
		n += c
	end
	return n
end

local function lootText(loot: any): string
	if not loot then
		return ""
	end
	return `Coins {UI.formatNumber(loot.coins)} · Fertilizer {loot.fertilizer} · Sprouts {#loot.seeds} · Loot {dropCount(
		loot
	)} · Weapons {#(loot.weapons or {})}`
end

local function names(list: { string }, lookup: (string) -> string?): string
	local parts = {}
	for _, id in list do
		local n = lookup(id)
		if n then
			table.insert(parts, n)
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
	local touch = UserInputService.TouchEnabled

	---------------------------------------------------------------- Z2: Back + заголовок
	local top = UI.frame(root, {
		Name = "Z2",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(320, 74),
		BackgroundTransparency = 1,
	})
	UI.autoScale(top)
	local back = UI.button(top, "BACK", UI.colors.red, {
		Name = "BackButton",
		Size = UDim2.fromOffset(86, 34),
	})
	local title = UI.label(top, "", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 20),
	})
	Components.outline(title, 0.9)
	local sub = UI.label(top, "", {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 14),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
	})
	Components.outline(sub, 0.8)
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, 0)

	---------------------------------------------------------------- Z5: счётчики добычи
	local lootStack = UI.frame(root, {
		Name = "Z5",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, if touch then -176 else -16),
		Size = UDim2.fromOffset(140, 5 * 38),
		BackgroundTransparency = 1,
	})
	local lootList = UI.list(lootStack, 4)
	lootList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	lootList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	UI.autoScale(lootStack)
	local cCoins =
		Components.counter(lootStack, { icon = "coin", color = UI.colors.gold, order = 1 })
	local cFert =
		Components.counter(lootStack, { icon = "odds", color = UI.colors.purple, order = 2 })
	local cSeeds =
		Components.counter(lootStack, { icon = "sprout", color = UI.colors.green, order = 3 })
	local cLoot = Components.counter(
		lootStack,
		{ icon = "shop", color = Color3.fromRGB(120, 210, 255), order = 4 }
	)
	local cWeapons =
		Components.counter(lootStack, { icon = "dungeon", color = UI.colors.red, order = 5 })

	---------------------------------------------------------------- Z6: HP, урон, слот, волны
	local bottom = UI.frame(root, {
		Name = "Z6",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(300, 150),
		BackgroundTransparency = 1,
	})
	UI.autoScale(bottom)
	local hp = Components.progress(bottom, {
		height = 22,
		color = UI.colors.red,
		left = "HP",
		position = UDim2.fromOffset(0, 0),
		size = UDim2.new(1, 0, 0, 22),
	})
	local damageLine = UI.label(bottom, "", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = Color3.fromRGB(120, 175, 255),
	})
	Components.outline(damageLine, 0.9)
	local slots = UI.frame(bottom, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
	})
	local slotList = UI.list(slots, 8, true)
	slotList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local weaponSlot = Components.slot(slots, { size = 62, icon = "dungeon", order = 1 })
	local extraSlot1 = Components.slot(slots, { size = 62, icon = "dungeon", order = 2 })
	local extraSlot2 = Components.slot(slots, { size = 62, icon = "dungeon", order = 3 })
	extraSlot1.frame.BackgroundTransparency = 0.5
	extraSlot2.frame.BackgroundTransparency = 0.5
	local waveBar = Components.progress(bottom, {
		height = 20,
		color = UI.colors.blue,
		left = "WAVE",
		position = UDim2.fromOffset(0, 120),
		size = UDim2.new(1, 0, 0, 20),
	})

	---------------------------------------------------------------- Z7: кнопка атаки
	local attackHolder = UI.frame(root, {
		Name = "Z7",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, if touch then -170 else -40),
		Size = UDim2.fromOffset(110, 128),
		BackgroundTransparency = 1,
	})
	UI.autoScale(attackHolder)
	local attack = Instance.new("TextButton")
	attack.Name = "AttackButton"
	attack.Text = ""
	attack.AutoButtonColor = false
	attack.Size = UDim2.fromOffset(110, 110)
	attack.BackgroundColor3 = UI.colors.bg
	attack.BackgroundTransparency = 0.08
	attack.Parent = attackHolder
	UI.corner(attack, 55)
	local attackRing = UI.stroke(attack, UI.colors.red, 3)
	local swordHolder = UI.frame(attack, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.55),
		BackgroundTransparency = 1,
	})
	Icons.make("dungeon", swordHolder, Color3.fromRGB(236, 238, 244), UI.colors.red)
	local attackScale = Instance.new("UIScale")
	attackScale.Parent = attack
	local attackLabel = UI.label(attackHolder, "HOLD = AUTO", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.fromOffset(110, 12),
		Font = UI.fontRegular,
		TextColor3 = UI.colors.muted,
	})
	Components.outline(attackLabel, 0.7)

	---------------------------------------------------------------- Z9: баннер и итоги
	local showBanner = Components.banner(root, UDim2.fromScale(0.5, 0.36), UDim2.new(0.8, 0, 0, 56))

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
	cardLimit.MaxSize = Vector2.new(460, 440)
	cardLimit.Parent = card
	UI.corner(card, 14)
	local cardStroke = UI.stroke(card, UI.colors.purple, 2)
	UI.pad(card, 16)
	UI.list(card, 10)
	local cardTitle =
		UI.label(card, "", { Size = UDim2.new(1, 0, 0, 40), ZIndex = 32, LayoutOrder = 1 })
	local cardText = UI.label(card, "", {
		Size = UDim2.new(1, 0, 0, 100),
		ZIndex = 32,
		LayoutOrder = 2,
		TextWrapped = true,
		TextColor3 = UI.colors.muted,
		Font = UI.fontRegular,
	})
	local primary = UI.button(
		card,
		"",
		UI.colors.green,
		{ Size = UDim2.new(1, 0, 0, 56), ZIndex = 32, LayoutOrder = 3 }
	)
	local secondary = UI.button(
		card,
		"",
		UI.colors.disabled,
		{ Size = UDim2.new(1, 0, 0, 48), ZIndex = 32, LayoutOrder = 4 }
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

	---------------------------------------------------------------- Атака: тап и удержание
	local weaponCooldown = D.player.attackCooldown
	local holding = false
	local function doAttack()
		if not root.Visible or overlay.Visible then
			return
		end
		local res = Net.request("DungeonAttack")
		if res.ok then
			attackRing.Transparency = 0.6
			attackScale.Scale = 0.92
			TweenService
				:Create(attackScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			task.delay(weaponCooldown, function()
				attackRing.Transparency = 0
			end)
		end
	end
	attack.MouseButton1Down:Connect(function()
		holding = true
		task.spawn(function()
			doAttack()
			while holding and root.Visible do
				task.wait(math.max(0.12, weaponCooldown))
				if holding then
					doAttack()
				end
			end
		end)
	end)
	local function stopHold()
		holding = false
	end
	attack.MouseButton1Up:Connect(stopHold)
	attack.MouseLeave:Connect(stopHold)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			doAttack()
		end
	end)

	back.Activated:Connect(function()
		local res = Net.request("DungeonLeave")
		if not res.ok then
			ctx.toast(Net.errorText(res.error))
		end
	end)

	local function weaponName(id: string): string?
		local w = weaponById[id]
		return w and w.name
	end

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
		if #kept.weapons > 0 then
			text ..= `\nNew weapons: {names(kept.weapons, weaponName)}`
		end
		if #kept.seeds > 0 then
			text ..= `\n{names(kept.seeds, function(id)
				local t = Garden.tree(id)
				return t and t.name
			end)}`
		end
		if
			lost
			and (
				lost.coins > 0
				or lost.fertilizer > 0
				or #lost.seeds > 0
				or #(lost.weapons or {}) > 0
				or next(lost.drops or {}) ~= nil
			)
		then
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

	local function refreshWeapon(id: string?)
		local w = id and weaponById[id]
		if not w then
			return
		end
		weaponCooldown = w.cooldown
		weaponSlot.set(w.name, w.edge, w.tier)
		damageLine.Text =
			`DMG x{w.damage}  ·  RNG {w.range}  ·  {string.format("%.2f", w.cooldown)}s`
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
		if d.weapon then
			refreshWeapon(d.weapon)
		end
		title.Text = `WAVE {d.wave}/{d.waves}`
		sub.Text = if d.state == "fight" then `Enemies left: {d.enemies}` else "Catch your breath"
		waveBar.setLabel(`WAVE {d.wave}`)
		waveBar.set(
			(d.wave - 1) / d.waves + (if d.state == "pause" then 1 / d.waves else 0),
			`{d.wave}/{d.waves}`
		)
		local loot = d.loot
		if loot then
			cCoins.set(UI.short(loot.coins))
			cFert.set(tostring(loot.fertilizer))
			cSeeds.set(tostring(#loot.seeds))
			cLoot.set(tostring(dropCount(loot)))
			cWeapons.set(tostring(#(loot.weapons or {})))
		end
		-- Back работает только между волнами
		local canLeave = d.state == "pause" or d.state == "start"
		back.BackgroundColor3 = if canLeave then UI.colors.red else UI.colors.disabled
		back.Text = if canLeave then "BACK" else "LOCKED"
		attack.Visible = d.state == "fight" or d.state == "start" or d.state == "pause"

		if d.result then
			showBanner("", nil, 0)
			showResult(d)
		elseif d.state == "downed" then
			showDowned(d)
		else
			overlay.Visible = false
			if d.startIn and d.state == "start" then
				showBanner(`Get ready! Wave 1 in {d.startIn}...`, nil, 3)
			elseif d.state == "fight" and lastState ~= "fight" then
				showBanner(
					if d.wave == d.waves then "BOSS WAVE!" else `Wave {d.wave}!`,
					UI.colors.red,
					1.5
				)
			elseif d.state == "pause" and d.gained then
				local g = d.gained
				local extra = ""
				if g.fertilizer > 0 then
					extra ..= " · Fertilizer +1"
				end
				if #g.seeds > 0 then
					extra ..= " · " .. names(g.seeds, function(id)
						local t = Garden.tree(id)
						return t and t.name
					end)
				end
				if g.weapons and #g.weapons > 0 then
					extra ..= " · " .. names(g.weapons, weaponName)
				end
				showBanner(`Wave cleared! +{g.coins}{extra}`, UI.colors.gold, 3)
			end
		end
		lastState = d.state
	end)

	-- Здоровье берём у своего персонажа
	RunService.Heartbeat:Connect(function()
		if not root.Visible then
			return
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
			hp.set(
				frac,
				`{math.ceil(hum.Health)} / {math.floor(hum.MaxHealth)}`,
				if frac < 0.3 then Color3.fromRGB(255, 90, 90) else UI.colors.red
			)
		end
	end)
	return {}
end

return DungeonHud
