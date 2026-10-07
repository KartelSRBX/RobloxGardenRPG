--!strict
-- Туториал и стрелка «что делать дальше»: луч от игрока к цели и прыгающий маркер над ней.
-- Во время туториала сверху висит короткая подсказка с номером шага.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Garden = require(ReplicatedStorage.Shared.Garden)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local WorldPlots = require(script.Parent.WorldPlots)

local player = Players.LocalPlayer

local Guide = {}

local enabled = true

function Guide.enabled(): boolean
	return enabled
end

function Guide.setEnabled(v: boolean)
	enabled = v
end

local function plotPart(slot: number): BasePart?
	local m = WorldPlots.find(slot)
	return m and m:FindFirstChild("Soil") :: BasePart?
end

local function machinePart(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local machine = map and map:FindFirstChild("SeedMachine")
	return machine and machine:FindFirstChild("Body") :: BasePart?
end

-- Куда сейчас вести игрока и что подсказать.
local function target(): (BasePart?, string?)
	local profile = State.profile
	if not profile or State.inRun() then
		return nil, nil
	end
	local now = workspace:GetServerTimeNow()
	local firstEmpty, firstReady, firstGrowing = nil, nil, nil
	for slot, plot in profile.plots do
		local readyAt = Garden.readyAt(plot)
		if not plot.plantId then
			firstEmpty = firstEmpty or slot
		elseif readyAt and now >= readyAt then
			firstReady = firstReady or slot
		else
			firstGrowing = firstGrowing or slot
		end
	end
	local seeds = 0
	for _, n in profile.seeds do
		seeds += n
	end

	if profile.tutorial == Tutorial.PLANT and firstEmpty then
		return plotPart(firstEmpty), Tutorial.text[Tutorial.PLANT]
	elseif profile.tutorial == Tutorial.SPIN then
		return machinePart(), Tutorial.text[Tutorial.SPIN]
	elseif profile.tutorial == Tutorial.HARVEST then
		local slot = firstReady or firstGrowing
		return slot and plotPart(slot), Tutorial.text[Tutorial.HARVEST]
	end
	-- После туториала: ближайшее полезное действие
	if firstReady then
		return plotPart(firstReady), nil
	elseif firstEmpty and seeds > 0 then
		return plotPart(firstEmpty), nil
	elseif firstEmpty and profile.coins >= Config.SpinCost then
		return machinePart(), nil
	end
	return nil, nil
end

function Guide.start(gui: ScreenGui)
	-- Плашка туториала
	local banner = UI.frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.new(0.7, 0, 0, 54),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 54)
	limit.Parent = banner
	UI.corner(banner, 27)
	UI.stroke(banner, UI.colors.gold, 3)
	local bannerText = UI.label(banner, "", {
		Size = UDim2.new(1, -24, 1, -14),
		Position = UDim2.fromOffset(12, 7),
	})

	-- Луч и маркер
	local beamColor = ColorSequence.new(UI.colors.gold)
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = workspace
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = beamColor
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Segments = 1
	beam.Parent = holder

	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(70, 70)
	marker.AlwaysOnTop = true
	marker.Adornee = holder
	marker.Parent = holder
	UI.label(marker, "⬇️", {})

	local current: BasePart? = nil
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and a0.Parent ~= root then
			a0.Parent = root
		end
		local show = enabled and current ~= nil and current.Parent ~= nil and root ~= nil
		beam.Enabled = show
		marker.Enabled = show
		if show then
			local part = current :: BasePart
			holder.Position = part.Position + Vector3.new(0, 7 + math.sin(t * 4) * 0.8, 0)
			-- рядом с целью луч не нужен
			beam.Enabled = ((root :: BasePart).Position - part.Position).Magnitude > 14
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.3)
			local part, text = target()
			current = part
			banner.Visible = text ~= nil
			if text then
				local step = (State.profile and State.profile.tutorial) or 1
				bannerText.Text = `{step}/3  {text}`
			end
		end
	end)
end

return Guide
