--!strict
-- Острова игроков: у каждого свой летающий воксельный остров вокруг хаба.
-- Остров растёт с уровнем (больше грядок — шире остров). На острове грядки и деревья
-- по профилю; данные для подсказок — в атрибутах модели грядки.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local IslandBuilder = require(script.Parent.IslandBuilder)
local TreeBuilder = require(script.Parent.TreeBuilder)
local Voxel = require(script.Parent.Voxel)

type Profile = any

local IslandWorld = {}

local SLOTS = 6
local RING = 190 -- расстояние островов от хаба
local HEIGHT = 40 -- высота поверхности островов и хаба

local slotOwner: { [number]: Player } = {}
local playerSlot: { [Player]: number } = {}
local builtTier: { [Player]: number } = {}
local builtPlots: { [Player]: number } = {}
local treeKeys: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local SOIL = Color3.fromRGB(92, 66, 48)
local SOIL_DARK = Color3.fromRGB(74, 52, 38)
local EDGE = Color3.fromRGB(140, 104, 70)

local function folder(): Folder
	local f = workspace:FindFirstChild("Islands")
	if not f then
		local created = Instance.new("Folder")
		created.Name = "Islands"
		created.Parent = workspace
		f = created
	end
	return f :: Folder
end

-- Центр острова слота: смотрит «лицом» на хаб.
local function slotCenter(slot: number): CFrame
	local a = (slot - 1) / SLOTS * math.pi * 2
	local pos = Vector3.new(math.cos(a) * RING, HEIGHT, math.sin(a) * RING)
	return CFrame.lookAt(pos, Vector3.new(0, HEIGHT, 0))
end

local function gridSize(plots: number): (number, number)
	local cols = math.min(Config.PlotLayout.columns, plots)
	local rows = math.ceil(plots / Config.PlotLayout.columns)
	return cols, rows
end

local function islandRadius(plots: number): number
	local cols, rows = gridSize(plots)
	local sp = Config.PlotLayout.spacing
	local hw, hd = cols * sp / 2, rows * sp / 2
	return math.max(26, math.sqrt(hw * hw + hd * hd) + 12)
end

-- Положение грядки относительно центра острова (локально: -Z к хабу).
local function plotOffset(slot: number, plots: number): Vector3
	local cols = Config.PlotLayout.columns
	local _, rows = gridSize(plots)
	local row = (slot - 1) // cols
	local col = (slot - 1) % cols
	local inRow = math.min(cols, plots - row * cols)
	local sp = Config.PlotLayout.spacing
	return Vector3.new((col - (inRow - 1) / 2) * sp, 0, (row - (rows - 1) / 2) * sp + 4)
end

local function makePlot(center: CFrame, offset: Vector3, slot: number, owner: Player): Model
	local m = Instance.new("Model")
	m.Name = "Plot" .. slot
	local size = Config.PlotLayout.size
	local cf = center * CFrame.new(offset)
	-- воксельная грядка: рамка и земля в два оттенка
	local g = Voxel.new(1)
	local half = math.floor(size / 2)
	for x = -half - 1, half + 1 do
		for z = -half - 1, half + 1 do
			if math.abs(x) == half + 1 or math.abs(z) == half + 1 then
				Voxel.set(
					g,
					x,
					0,
					z,
					Voxel.shade(EDGE, x, 0, z, slot, 0.08),
					Enum.Material.WoodPlanks
				)
			else
				Voxel.set(
					g,
					x,
					0,
					z,
					if (x * 3 + z * 7) % 5 == 0 then SOIL_DARK else SOIL,
					Enum.Material.SmoothPlastic
				)
			end
		end
	end
	Voxel.build(g, m, cf * CFrame.new(0, 0.5, 0), { collide = true })
	local soil = Instance.new("Part")
	soil.Name = "Soil"
	soil.Anchored = true
	soil.CanCollide = false
	soil.Transparency = 1
	soil.Size = Vector3.new(size, 1, size)
	soil.CFrame = cf * CFrame.new(0, 0.5, 0)
	soil.Parent = m
	m.PrimaryPart = soil
	m:SetAttribute("Owner", owner.UserId)
	m:SetAttribute("Slot", slot)
	return m
end

local function islandModel(player: Player): Model?
	local slot = playerSlot[player]
	return slot and folder():FindFirstChild("Island" .. slot) :: Model?
end

-- Строит или перестраивает остров под текущий уровень.
local function buildIsland(player: Player, profile: Profile)
	local slot = playerSlot[player]
	if not slot then
		return
	end
	local old = folder():FindFirstChild("Island" .. slot)
	if old then
		old:Destroy()
	end
	local center = slotCenter(slot)
	local plots = #profile.plots
	local radius = islandRadius(plots)
	local cols, rows = gridSize(plots)
	local sp = Config.PlotLayout.spacing
	local function keepClear(x: number, z: number): boolean
		return math.abs(x) < cols * sp / 2 + 2
			and z > -(rows * sp / 2) + 1
			and z < rows * sp / 2 + 7
	end
	local island = IslandBuilder.build(center, radius, slot * 17 + profile.islandTier, keepClear)
	island.Name = "Island" .. slot
	island:SetAttribute("Owner", player.UserId)
	island:SetAttribute("Tier", profile.islandTier)

	-- точка появления у края, ближе к хабу
	local spawn = Instance.new("Part")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = center * CFrame.new(0, 0.5, -(radius - 8)) * CFrame.Angles(0, math.pi, 0)
	spawn.Parent = island

	-- табличка владельца
	local sign = Instance.new("BillboardGui")
	sign.Name = "OwnerSign"
	sign.Size = UDim2.fromOffset(260, 56)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	sign.MaxDistance = 400
	sign.Adornee = spawn
	sign.Parent = spawn
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.TextStrokeTransparency = 0.5
	label.Text = `{player.DisplayName}'s Island · Lv {profile.islandTier}`
	label.Parent = sign

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = island
	for i = 1, plots do
		makePlot(center, plotOffset(i, plots), i, player).Parent = plotsFolder
	end
	island.Parent = folder()
	builtTier[player] = profile.islandTier
	builtPlots[player] = #profile.plots
end

function IslandWorld.assign(player: Player): boolean
	if playerSlot[player] then
		return true
	end
	for i = 1, SLOTS do
		if not slotOwner[i] then
			slotOwner[i] = player
			playerSlot[player] = i
			return true
		end
	end
	warn("[IslandWorld] нет свободного острова для", player.Name)
	return false
end

function IslandWorld.release(player: Player)
	local slot = playerSlot[player]
	if not slot then
		return
	end
	local island = folder():FindFirstChild("Island" .. slot)
	if island then
		island:Destroy()
	end
	slotOwner[slot] = nil
	playerSlot[player] = nil
	builtTier[player] = nil
	builtPlots[player] = nil
end

-- Перерисовывает остров и деревья. Остров пересобирается только при смене уровня.
function IslandWorld.render(player: Player, profile: Profile)
	if not playerSlot[player] then
		return
	end
	-- пересобрать при новом уровне или другом числе грядок (пропуск Bigger Island)
	if
		builtTier[player] ~= profile.islandTier
		or builtPlots[player] ~= #profile.plots
		or not islandModel(player)
	then
		buildIsland(player, profile)
	end
	local island = islandModel(player)
	local plotsFolder = island and island:FindFirstChild("Plots")
	if not plotsFolder then
		return
	end
	local now = os.time()
	for slot, plot in profile.plots do
		local m = plotsFolder:FindFirstChild("Plot" .. slot) :: Model?
		if not m then
			continue
		end
		local soil = m:FindFirstChild("Soil") :: BasePart
		local readyAt = Garden.readyAt(plot)
		local ready = readyAt ~= nil and now >= readyAt and plot.mutationRolled
		m:SetAttribute("PlantId", plot.plantId)
		m:SetAttribute("Level", plot.level)
		m:SetAttribute("ReadyAt", readyAt)
		m:SetAttribute("Mutation", plot.mutation)
		local key = if plot.plantId
			then `{plot.plantId}|{Garden.stage(plot.level)}|{ready}|{plot.mutation}`
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

function IslandWorld.plotPosition(player: Player, slot: number): Vector3?
	local island = islandModel(player)
	local plotsFolder = island and island:FindFirstChild("Plots")
	local m = plotsFolder and plotsFolder:FindFirstChild("Plot" .. slot) :: Model?
	return m and m:GetPivot().Position + Vector3.new(0, 6, 0)
end

function IslandWorld.sendHome(player: Player)
	local island = islandModel(player)
	local character = player.Character
	local spawn = island and island:FindFirstChild("Spawn") :: BasePart?
	if character and spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

function IslandWorld.sendHub(player: Player)
	local map = workspace:FindFirstChild("Map")
	local hubSpawn = map and map:FindFirstChild("HubSpawn") :: BasePart?
	local character = player.Character
	if character and hubSpawn then
		character:PivotTo(hubSpawn.CFrame + Vector3.new(0, 4, 0))
	end
end

Players.PlayerRemoving:Connect(IslandWorld.release)
folder() -- папка нужна клиентам сразу, ещё до загрузки первого профиля

-- Упал с острова — вернуть домой.
task.spawn(function()
	while true do
		task.wait(0.5)
		for player in playerSlot do
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- арены подземелья далеко по X, их не трогаем
			if root and root.Position.Y < HEIGHT - 60 and root.Position.X < 3000 then
				IslandWorld.sendHome(player)
			end
		end
	end
end)

return IslandWorld
