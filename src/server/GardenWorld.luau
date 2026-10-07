--!strict
-- Сад в мире: каждому игроку свой участок (Workspace.Gardens.LotN, построен в сцене),
-- на нём грядки и деревья по профилю. Данные для подсказок — в атрибутах модели грядки.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local TreeBuilder = require(script.Parent.TreeBuilder)

type Profile = any

local GardenWorld = {}

local lotOwner: { [Model]: Player } = {}
local playerLot: { [Player]: Model } = {}
local treeKeys: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local SOIL = Color3.fromRGB(110, 75, 50)
local SOIL_EDGE = Color3.fromRGB(150, 105, 70)

local function lots(): { Model }
	local folder = workspace:FindFirstChild("Gardens")
	local list: { Model } = {}
	if folder then
		for _, lot in folder:GetChildren() do
			if lot:IsA("Model") and lot.PrimaryPart then
				table.insert(list, lot)
			end
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	return list
end

local function setSign(lot: Model, text: string)
	local sign = lot:FindFirstChild("Sign")
	if not sign then
		return
	end
	for _, gui in sign:GetChildren() do
		local label = gui:FindFirstChild("Owner")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

local function slotCFrame(lot: Model, slot: number): CFrame
	local layout = Config.PlotLayout
	local col = (slot - 1) % #layout.columns + 1
	local row = (slot - 1) // #layout.columns + 1
	local base = (lot.PrimaryPart :: BasePart).CFrame
	local top = (lot.PrimaryPart :: BasePart).Size.Y / 2
	return base * CFrame.new(layout.columns[col], top, layout.rows[row])
end

local function makePlot(lot: Model, slot: number, owner: Player): Model
	local m = Instance.new("Model")
	m.Name = "Plot" .. slot
	local cf = slotCFrame(lot, slot)
	local size = Config.PlotLayout.size
	local edge = Instance.new("Part")
	edge.Name = "Edge"
	edge.Anchored = true
	edge.Size = Vector3.new(size + 1, 0.8, size + 1)
	edge.CFrame = cf * CFrame.new(0, 0.4, 0)
	edge.Color = SOIL_EDGE
	edge.Material = Enum.Material.WoodPlanks
	edge.TopSurface = Enum.SurfaceType.Smooth
	edge.Parent = m
	local soil = Instance.new("Part")
	soil.Name = "Soil"
	soil.Anchored = true
	soil.Size = Vector3.new(size, 0.9, size)
	soil.CFrame = cf * CFrame.new(0, 0.5, 0)
	soil.Color = SOIL
	soil.Material = Enum.Material.Ground
	soil.TopSurface = Enum.SurfaceType.Smooth
	soil.Parent = m
	m.PrimaryPart = soil
	m:SetAttribute("Owner", owner.UserId)
	m:SetAttribute("Slot", slot)
	return m
end

local function plotsFolder(lot: Model): Folder
	local f = lot:FindFirstChild("Plots")
	if not f then
		local created = Instance.new("Folder")
		created.Name = "Plots"
		created.Parent = lot
		f = created
	end
	return f :: Folder
end

function GardenWorld.lotOf(player: Player): Model?
	return playerLot[player]
end

function GardenWorld.assign(player: Player): Model?
	if playerLot[player] then
		return playerLot[player]
	end
	for _, lot in lots() do
		if not lotOwner[lot] then
			lotOwner[lot] = player
			playerLot[player] = lot
			setSign(lot, player.DisplayName .. "'s Garden")
			return lot
		end
	end
	warn("[GardenWorld] нет свободного участка для", player.Name)
	return nil
end

function GardenWorld.release(player: Player)
	local lot = playerLot[player]
	if not lot then
		return
	end
	local f = lot:FindFirstChild("Plots")
	if f then
		f:Destroy()
	end
	setSign(lot, "Free plot")
	lotOwner[lot] = nil
	playerLot[player] = nil
end

-- Перерисовывает грядки игрока. Дерево пересобирается, только если поменялся вид.
function GardenWorld.render(player: Player, profile: Profile)
	local lot = playerLot[player]
	if not lot then
		return
	end
	local folder = plotsFolder(lot)
	local now = os.time()
	local owned = #profile.plots
	for slot = 1, Config.MaxPlots do
		local name = "Plot" .. slot
		local model = folder:FindFirstChild(name) :: Model?
		local forSale = slot == owned + 1 and Garden.plotPrice(owned) ~= nil
		if slot > owned and not forSale then
			if model then
				model:Destroy()
			end
			continue
		end
		if not model then
			local created = makePlot(lot, slot, player)
			created.Parent = folder
			model = created
		end
		local m = model :: Model
		local soil = m:FindFirstChild("Soil") :: BasePart
		if forSale then
			m:SetAttribute("ForSale", true)
			m:SetAttribute("Price", Garden.plotPrice(owned))
			m:SetAttribute("PlantId", nil)
			soil.Transparency = 0.6
			soil.Color = Color3.fromRGB(150, 150, 150)
			local tree = m:FindFirstChild("Tree")
			if tree then
				tree:Destroy()
			end
			continue
		end
		m:SetAttribute("ForSale", nil)
		m:SetAttribute("Price", nil)
		soil.Transparency = 0
		soil.Color = SOIL

		local plot = profile.plots[slot]
		local readyAt = Garden.readyAt(plot)
		local ready = readyAt ~= nil and now >= readyAt and plot.mutationRolled
		m:SetAttribute("PlantId", plot.plantId)
		m:SetAttribute("Level", plot.level)
		m:SetAttribute("ReadyAt", readyAt)
		m:SetAttribute("Mutation", plot.mutation)

		local key = if plot.plantId
			then `{plot.plantId}|{plot.level}|{ready}|{plot.mutation}`
			else ""
		if treeKeys[m] ~= key then
			treeKeys[m] = key
			local old = m:FindFirstChild("Tree")
			if old then
				old:Destroy()
			end
			if plot.plantId then
				local tree = TreeBuilder.build(
					plot.plantId,
					plot.level,
					ready,
					plot.mutation,
					soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0)
				)
				tree.Parent = m
			end
		end
	end
end

-- Позиция над грядкой: для всплывающих монет.
function GardenWorld.plotPosition(player: Player, slot: number): Vector3?
	local lot = playerLot[player]
	if not lot then
		return nil
	end
	return slotCFrame(lot, slot).Position + Vector3.new(0, 6, 0)
end

function GardenWorld.sendHome(player: Player)
	local lot = playerLot[player]
	local character = player.Character
	if not lot or not character then
		return
	end
	local spawn = lot:FindFirstChild("Spawn") :: BasePart?
	if spawn then
		character:PivotTo(spawn.CFrame * CFrame.Angles(0, math.rad(180), 0) + Vector3.new(0, 4, 0))
	end
end

Players.PlayerRemoving:Connect(GardenWorld.release)

return GardenWorld
