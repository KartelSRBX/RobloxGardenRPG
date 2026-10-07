--!strict
-- Сад в мире на клиенте: таблички над грядками (видны всем) и кнопки-подсказки
-- у своих грядок (посадить, собрать, удобрить, прокачать, купить грядку).
-- Данные берутся из атрибутов модели грядки, которые ставит сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garden = require(ReplicatedStorage.Shared.Garden)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local WorldPlots = {}

type Entry = {
	model: Model,
	label: TextLabel,
	sub: TextLabel,
	gui: BillboardGui,
	main: ProximityPrompt?,
	upgrade: ProximityPrompt?,
}

function WorldPlots.start(ctx: any)
	local entries: { [Model]: Entry } = {}

	local function prompt(parent: BasePart, key: Enum.KeyCode, offsetY: number): ProximityPrompt
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = key
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 12
		pp.RequiresLineOfSight = false
		pp.UIOffset = Vector2.new(0, offsetY)
		pp.Parent = parent
		return pp
	end

	local function track(model: Model)
		if entries[model] or not model.Name:match("^Plot%d+$") then
			return
		end
		local soil = model:WaitForChild("Soil", 5) :: BasePart?
		if not soil then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 64)
		gui.StudsOffset = Vector3.new(0, 9, 0)
		gui.MaxDistance = 70
		gui.Adornee = soil
		gui.Parent = soil
		local label = UI.label(gui, "", { Size = UDim2.new(1, 0, 0.55, 0) })
		UI.textStroke(label, 2)
		local sub = UI.label(
			gui,
			"",
			{ Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.55) }
		)
		UI.textStroke(sub, 2)
		local e: Entry = { model = model, label = label, sub = sub, gui = gui }

		if model:GetAttribute("Owner") == player.UserId then
			local slot = model:GetAttribute("Slot") :: number
			local main = prompt(soil, Enum.KeyCode.E, 0)
			local upgrade = prompt(soil, Enum.KeyCode.R, 80)
			main.Triggered:Connect(function()
				if model:GetAttribute("ForSale") then
					local res = Net.request("BuyPlot")
					ctx.toast(if res.ok then "New plot unlocked!" else Net.errorText(res.error))
					return
				end
				local plantId = model:GetAttribute("PlantId")
				if not plantId then
					ctx.openPicker(slot)
					return
				end
				local readyAt = model:GetAttribute("ReadyAt") :: number?
				local ready = readyAt ~= nil and workspace:GetServerTimeNow() >= readyAt
				local res = Net.request(if ready then "Harvest" else "Fertilize", slot)
				if not res.ok then
					ctx.toast(Net.errorText(res.error))
				elseif not ready then
					ctx.toast("Growth boosted!")
				end
			end)
			upgrade.Triggered:Connect(function()
				local res = Net.request("Upgrade", slot)
				if res.ok then
					ctx.toast("Tree upgraded!")
				else
					ctx.toast(Net.errorText(res.error))
				end
			end)
			e.main = main
			e.upgrade = upgrade
		end
		entries[model] = e
		model.Destroying:Connect(function()
			entries[model] = nil
		end)
	end

	local function update(e: Entry, now: number)
		local m = e.model
		local mine = m:GetAttribute("Owner") == player.UserId
		local profile = State.profile
		if m:GetAttribute("ForSale") then
			local price = m:GetAttribute("Price") or 0
			e.gui.Enabled = mine
			e.label.Text = "➕ New plot"
			e.label.TextColor3 = UI.colors.gold
			e.sub.Text = `💰 {UI.formatNumber(price)}`
			e.sub.TextColor3 = UI.colors.text
			e.gui.StudsOffset = Vector3.new(0, 4, 0)
			if e.main then
				e.main.Enabled = true
				e.main.ActionText = "Buy plot"
				e.main.ObjectText = `💰 {UI.formatNumber(price)}`
			end
			if e.upgrade then
				e.upgrade.Enabled = false
			end
			return
		end
		e.gui.Enabled = true
		local plantId = m:GetAttribute("PlantId") :: string?
		local plant = plantId and Garden.plant(plantId)
		if not plant then
			e.label.Text = if mine then "🌱 Empty" else ""
			e.label.TextColor3 = UI.colors.text
			e.sub.Text = ""
			e.gui.StudsOffset = Vector3.new(0, 4, 0)
			if e.main then
				e.main.Enabled = true
				e.main.ActionText = "Plant"
				e.main.ObjectText = "Empty plot"
			end
			if e.upgrade then
				e.upgrade.Enabled = false
			end
			return
		end
		local level = (m:GetAttribute("Level") or 1) :: number
		local stage = math.clamp(math.ceil(level / 2), 1, 5)
		local readyAt = (m:GetAttribute("ReadyAt") or 0) :: number
		local mutation = Garden.mutation(m:GetAttribute("Mutation") :: string?)
		local ready = now >= readyAt
		e.gui.StudsOffset = Vector3.new(0, 9 + stage * 2, 0)
		e.label.Text = `{plant.icon} {Garden.stageName(plant, level)}`
		e.label.TextColor3 = Garden.rarity(plant.rarity).color
		if ready then
			e.sub.Text = if mutation then `✨ {mutation.name}! Ready!` else "✅ Ready!"
			e.sub.TextColor3 = if mutation then mutation.color else UI.colors.gold
		else
			e.sub.Text = `⏳ {UI.formatTime(readyAt - now)}`
			e.sub.TextColor3 = UI.colors.text
		end
		if e.main then
			local fert = profile and profile.items.fertilizer or 0
			e.main.Enabled = ready or fert > 0
			e.main.ActionText = if ready then "Harvest" else `Fertilize (🧪{fert})`
			e.main.ObjectText = Garden.stageName(plant, level)
		end
		if e.upgrade then
			local cost = Garden.upgradeCost(plant, level)
			e.upgrade.Enabled = cost ~= nil
			e.upgrade.ActionText = if cost then `Upgrade 💰{UI.formatNumber(cost)}` else ""
			e.upgrade.ObjectText = `Level {level}`
		end
	end

	local gardens = workspace:WaitForChild("Gardens")
	for _, d in gardens:GetDescendants() do
		if d:IsA("Model") then
			task.spawn(track, d)
		end
	end
	gardens.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.spawn(track, d)
		end
	end)

	-- Машина семян и портал
	local map = workspace:WaitForChild("Map")
	local machine = map:WaitForChild("SeedMachine")
	local spinPrompt = machine:FindFirstChild("SpinPrompt", true) :: ProximityPrompt?
	if spinPrompt then
		spinPrompt.Triggered:Connect(function()
			ctx.open("Spin")
		end)
	end
	local portal = map:WaitForChild("DungeonPortal")
	local dungeonPrompt = portal:FindFirstChild("DungeonPrompt", true) :: ProximityPrompt?
	if dungeonPrompt then
		dungeonPrompt.Triggered:Connect(function()
			ctx.open("Dungeon")
		end)
	end

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			for _, e in entries do
				update(e, now)
			end
		end
	end)
end

-- Своя грядка по номеру (для стрелки туториала).
function WorldPlots.find(slot: number): Model?
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then
		return nil
	end
	for _, d in gardens:GetDescendants() do
		if
			d:IsA("Model")
			and d:GetAttribute("Owner") == player.UserId
			and d:GetAttribute("Slot") == slot
		then
			return d
		end
	end
	return nil
end

return WorldPlots
