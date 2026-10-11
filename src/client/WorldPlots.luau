--!strict
-- Острова на клиенте: таблички над грядками (видны всем) и кнопки у своих грядок
-- (посадить, собрать, удобрить, прокачать). Данные — из атрибутов модели грядки.
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
		pp.MaxActivationDistance = 11
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
		gui.Size = UDim2.fromOffset(200, 46)
		gui.StudsOffset = Vector3.new(0, 9, 0)
		gui.MaxDistance = 60
		gui.Adornee = soil
		gui.Parent = soil
		local label =
			UI.label(gui, "", { Size = UDim2.new(1, 0, 0.55, 0), TextStrokeTransparency = 0.6 })
		local sub = UI.label(gui, "", {
			Size = UDim2.new(1, 0, 0.45, 0),
			Position = UDim2.fromScale(0, 0.55),
			Font = UI.fontRegular,
			TextStrokeTransparency = 0.6,
		})
		local e: Entry = { model = model, label = label, sub = sub, gui = gui }

		if model:GetAttribute("Owner") == player.UserId then
			local slot = model:GetAttribute("Slot") :: number
			local main = prompt(soil, Enum.KeyCode.E, 0)
			local upgrade = prompt(soil, Enum.KeyCode.R, 80)
			main.Triggered:Connect(function()
				local treeId = model:GetAttribute("PlantId")
				if not treeId then
					ctx.openPicker(slot)
					return
				end
				local readyAt = model:GetAttribute("ReadyAt") :: number?
				local ready = readyAt ~= nil and workspace:GetServerTimeNow() >= readyAt
				local res = Net.request(if ready then "Harvest" else "Fertilize", slot)
				if not res.ok then
					ctx.toast(Net.errorText(res.error))
				elseif not ready then
					ctx.toast("Growth boosted")
				end
			end)
			upgrade.Triggered:Connect(function()
				local res = Net.request("Upgrade", slot)
				ctx.toast(if res.ok then "Tree upgraded" else Net.errorText(res.error))
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
		e.gui.Enabled = ctx.billboardsOn ~= false
		local m = e.model
		local mine = m:GetAttribute("Owner") == player.UserId
		local profile = State.profile
		local tree = Garden.tree(m:GetAttribute("PlantId") :: string?)
		if not tree then
			e.label.Text = if mine then "Empty plot" else ""
			e.label.TextColor3 = UI.colors.muted
			e.sub.Text = ""
			e.gui.StudsOffset = Vector3.new(0, 3, 0)
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
		local readyAt = (m:GetAttribute("ReadyAt") or 0) :: number
		local mutation = Garden.mutation(m:GetAttribute("Mutation") :: string?)
		local ready = now >= readyAt
		e.gui.StudsOffset = Vector3.new(0, 8 + Garden.stage(level) * 1.2, 0)
		e.label.Text = `{tree.name} · Lv {level}`
		e.label.TextColor3 = Garden.rarity(tree.rarity).color
		if ready then
			e.sub.Text = if mutation then `{mutation.name} · Ready` else "Ready"
			e.sub.TextColor3 = if mutation then mutation.color else UI.colors.gold
		else
			e.sub.Text = UI.formatTime(readyAt - now)
			e.sub.TextColor3 = UI.colors.text
		end
		if e.main then
			local fert = profile and profile.items.fertilizer or 0
			e.main.Enabled = ready or fert > 0
			e.main.ActionText = if ready then "Harvest" else `Fertilize ({fert})`
			e.main.ObjectText = tree.name
		end
		if e.upgrade then
			local cost = Garden.upgradeCost(tree, level)
			e.upgrade.Enabled = cost ~= nil
			e.upgrade.ActionText = if cost then `Upgrade · {UI.formatNumber(cost)}` else ""
			e.upgrade.ObjectText = `Level {level}`
		end
	end

	local islands = workspace:WaitForChild("Islands")
	for _, d in islands:GetDescendants() do
		if d:IsA("Model") then
			task.spawn(track, d)
		end
	end
	islands.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.spawn(track, d)
		end
	end)

	-- Портал в подземелье на хабе
	local map = workspace:WaitForChild("Map")
	local dungeonPrompt =
		map:WaitForChild("DungeonPortal"):FindFirstChild("DungeonPrompt", true) :: ProximityPrompt?
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

-- Своя грядка по номеру (для стрелки подсказки).
function WorldPlots.find(slot: number): Model?
	local islands = workspace:FindFirstChild("Islands")
	if not islands then
		return nil
	end
	for _, d in islands:GetDescendants() do
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
