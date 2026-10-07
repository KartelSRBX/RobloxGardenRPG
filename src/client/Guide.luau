--!strict
-- Туториал и подсказка «что делать дальше»: луч от игрока к нужной грядке и маркер над ней.
-- Во время туториала сверху короткая плашка с номером шага; на шаге крутки пульсирует кнопка ROLL.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local function plotPart(slot: number?): BasePart?
	local m = slot and WorldPlots.find(slot)
	return m and m:FindFirstChild("Soil") :: BasePart?
end

-- Цель подсказки, текст плашки и нужно ли подсветить кнопку крутки.
local function target(): (BasePart?, string?, boolean)
	local profile = State.profile
	if not profile or State.inRun() then
		return nil, nil, false
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
		return plotPart(firstEmpty), Tutorial.text[Tutorial.PLANT], false
	elseif profile.tutorial == Tutorial.SPIN then
		return nil, Tutorial.text[Tutorial.SPIN], true
	elseif profile.tutorial == Tutorial.HARVEST then
		return plotPart(firstReady or firstGrowing), Tutorial.text[Tutorial.HARVEST], false
	end
	if firstReady then
		return plotPart(firstReady), nil, false
	elseif firstEmpty and seeds > 0 then
		return plotPart(firstEmpty), nil, false
	end
	return nil, nil, false
end

function Guide.start(gui: ScreenGui, rollButton: GuiObject)
	local banner = UI.frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(0.7, 0, 0, 42),
		BackgroundColor3 = UI.colors.bg,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 42)
	limit.Parent = banner
	UI.corner(banner, 8)
	UI.stroke(banner, UI.colors.gold, 1.5)
	local bannerText = UI.label(banner, "", {
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
	})

	local a0 = Instance.new("Attachment")
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = workspace
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(UI.colors.gold)
	beam.Width0 = 0.3
	beam.Width1 = 0.3
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.35)
	beam.Parent = holder

	-- маркер: воксельная стрелка из трёх кубов
	local marker = Instance.new("Model")
	marker.Name = "GuideMarker"
	for i, size in { 1.4, 1, 0.6 } do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = UI.colors.gold
		p.Size = Vector3.new(size, 0.6, size)
		p.Name = "Step" .. i
		p.Parent = marker
	end
	marker.Parent = workspace

	local current: BasePart? = nil
	local stopPulse: (() -> ())? = nil
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and a0.Parent ~= root then
			a0.Parent = root
		end
		local part = current
		local show = enabled and part ~= nil and part.Parent ~= nil and root ~= nil
		local y = if show then (part :: BasePart).Position.Y + 6 + math.sin(t * 4) * 0.5 else -1000
		for i = 1, 3 do
			local step = marker:FindFirstChild("Step" .. i) :: BasePart
			if show then
				local p = (part :: BasePart).Position
				step.CFrame = CFrame.new(p.X, y - (i - 1) * 0.6, p.Z)
			else
				step.CFrame = CFrame.new(0, -1000, 0)
			end
		end
		if show then
			holder.Position = (part :: BasePart).Position + Vector3.new(0, 4, 0)
			beam.Enabled = ((root :: BasePart).Position - (part :: BasePart).Position).Magnitude
				> 14
		else
			beam.Enabled = false
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.3)
			local part, text, pulseRoll = target()
			current = part
			banner.Visible = text ~= nil
			if text then
				local step = (State.profile and State.profile.tutorial) or 1
				bannerText.Text = `{step}/3 · {text}`
			end
			if pulseRoll and not stopPulse then
				stopPulse = UI.pulse(rollButton)
			elseif not pulseRoll and stopPulse then
				stopPulse()
				stopPulse = nil
			end
		end
	end)
end

return Guide
